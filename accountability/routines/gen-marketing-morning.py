#!/usr/bin/env python3
"""
gen-marketing-morning.py — deterministic helper for marketing-morning.

Replaces the LLM-driven posting loop in marketing-morning.md. Reads all the
inputs the morning routine needs, computes per-crew task lists with enrichment
attached, and posts everything to Slack via the Web API. Writes the JSON
sentinel + morning-tasks.md snapshot. Exits 0 on success, non-zero on failure.

Usage:
  python3 gen-marketing-morning.py            # post for real
  python3 gen-marketing-morning.py --dry-run  # print plan, no Slack posts

Why this exists: the LLM-driven posting loop is unreliable at multi-crew scale
(~30+ tasks, 80+ posts). At that size the LLM silently drops the enrichment
step and rationalizes success. Python loop = no skipping, no hallucinating.
"""

import argparse
import datetime
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
CHANNEL_ID = "C0ASK9520JG"   # #tasks (was #marketing-automation C0BBQ7PV34N until 2026-07-02).
                             # Used only for the crew-summary header post; per-task creation
                             # goes through tasks.sh which uses its own #tasks default.
TOKEN_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach-slack-bot-token"
DB_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach.sqlite"
TASKS_SH = PROJECT_DIR / ".claude" / "skills" / "tasks" / "bin" / "tasks.sh"

# Product roster (matches products/ dir + strategies/ dir). Order = iteration order.
PRODUCT_SLUGS = ("rapidnative", "applighter", "letsdeployit")
PRODUCT_DISPLAY = {"rapidnative": "RapidNative", "applighter": "Applighter", "letsdeployit": "LetsDeployIt"}
PRODUCT_TAG = {"rapidnative": "[RN]", "applighter": "[AL]", "letsdeployit": "[LDI]"}
# Normalized sprint sub-heading → product slug
SPRINT_HEADING_TO_PRODUCT = {
    "rapidnative": "rapidnative",
    "applighter": "applighter",
    "letsdeployit": "letsdeployit",
    "lets deploy it": "letsdeployit",
    "lets deployit": "letsdeployit",
}


# ─────────────────────────── DATES + GUARDS ───────────────────────────


def today_ist() -> str:
    if v := os.environ.get("TODAY_OVERRIDE"):
        return v
    tz = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    return datetime.datetime.now(tz).strftime("%Y-%m-%d")


def shift_days(date_str: str, days: int) -> str:
    d = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    return (d + datetime.timedelta(days=days)).strftime("%Y-%m-%d")


def is_weekend(date_str: str) -> bool:
    d = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    return d.weekday() >= 5  # 5=Sat, 6=Sun


def is_holiday(date_str: str) -> bool:
    if not DB_PATH.exists():
        return False
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            "SELECT 1 FROM holidays WHERE date=? AND status='upcoming' LIMIT 1",
            (date_str,),
        )
        return cur.fetchone() is not None


def is_on_leave(slack_id: str, date_str: str) -> bool:
    if not DB_PATH.exists():
        return False
    sid = slack_id.strip("<>@`")
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            "SELECT 1 FROM leave_entries WHERE slack_id=? AND status='active' "
            "AND ? BETWEEN start_date AND end_date LIMIT 1",
            (sid, date_str),
        )
        return cur.fetchone() is not None


def week_of_month(date_str: str) -> int:
    d = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    return ((d.day - 1) // 7) + 1


def week_label(date_str: str) -> str:
    d = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    return f"w{week_of_month(date_str)}-{d.strftime('%B')}"


# ─────────────────────────── SLACK API ───────────────────────────


def get_token() -> str:
    return TOKEN_PATH.read_text().strip()


def slack_post(text: str, thread_ts: Optional[str] = None) -> Optional[str]:
    """Post to #tasks (default). Returns ts on success, None on failure."""
    payload: dict = {"channel": CHANNEL_ID, "text": text, "mrkdwn": True}
    if thread_ts:
        payload["thread_ts"] = thread_ts
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {get_token()}",
            "Content-Type": "application/json; charset=utf-8",
        },
    )
    try:
        r = json.load(urllib.request.urlopen(req))
        if r.get("ok"):
            return r["ts"]
        print(f"  [slack-err] {r.get('error')}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  [slack-exc] {e}", file=sys.stderr)
        return None


# ─────────────────────────── FILE PARSERS ───────────────────────────


def parse_team() -> list:
    """Return [{slack_id, handle, active, products}]. Crew handles come from accounts.md
    `## @handle` headings; Slack IDs come from definitions/people.md. Each member's
    `products` list comes from the `products: [slug, slug, ...]` line under their
    heading; defaults to ['rapidnative'] if the line is absent (backward compat)."""
    accounts_path = PROJECT_DIR / ".claude" / "skills" / "growth-marketing" / "social-engagement" / "references" / "accounts.md"
    people_path = PROJECT_DIR / "definitions" / "people.md"

    handles = []
    products_by_handle: dict = {}
    current_handle = None
    for line in accounts_path.read_text().splitlines():
        stripped = line.strip()
        m = re.match(r"^## (@\w+)", stripped)
        if m:
            current_handle = m.group(1)
            handles.append(current_handle)
            continue
        if current_handle:
            pm = re.match(r"^products:\s*\[(.*)\]", stripped)
            if pm:
                items = [s.strip() for s in pm.group(1).split(",") if s.strip()]
                products_by_handle[current_handle] = items

    slack_id_by_handle: dict = {}
    for line in people_path.read_text().splitlines():
        m = re.match(r"^\|\s*`(@\w+)`\s*\|[^|]*\|[^|]*\|[^|]*\|\s*`([A-Z0-9]+)`\s*\|", line)
        if m:
            slack_id_by_handle[m.group(1)] = m.group(2)

    out = []
    for h in handles:
        sid = slack_id_by_handle.get(h)
        if not sid:
            print(f"WARN: {h} in accounts.md has no Slack ID in definitions/people.md — skipping", file=sys.stderr)
            continue
        products = products_by_handle.get(h, ["rapidnative"])
        out.append({"slack_id": sid, "handle": h, "active": True, "products": products})
    return out


def parse_sprint(date_str: str) -> dict:
    """Return {product_slug: [TPL-IDs]} for today's section in sprint.md.

    Handles two formats:
    - New (per-product): `## YYYY-MM-DD` followed by `### RapidNative / ### Applighter /
      ### LetsDeployIt` sub-headings. Only known sub-headings are collected.
    - Legacy (flat): `## YYYY-MM-DD` followed directly by `- TPL-*` lines with no `###`
      sub-heading in between. Templates get bucketed as {'rapidnative': [...]}.

    Empty dict if today's date isn't found. A date with all-empty product blocks
    returns {} too (caller nudges).
    """
    path = PROJECT_DIR / ".claude" / "skills" / "growth-marketing" / "social-engagement" / "references" / "sprint.md"
    if not path.exists():
        return {}

    in_today = False
    current_product = None
    result: dict = {}
    for raw in path.read_text().splitlines():
        stripped = raw.strip()
        # Match today's date heading
        if re.match(rf"^## {re.escape(date_str)}\b", stripped):
            in_today = True
            current_product = None
            continue
        # Break out on the next `## ` date heading (but NOT `### ` sub-headings)
        if in_today and stripped.startswith("## ") and not stripped.startswith("### "):
            break
        if not in_today:
            continue
        # Product sub-heading
        if stripped.startswith("### "):
            name = stripped[4:].strip().lower()
            current_product = SPRINT_HEADING_TO_PRODUCT.get(name)
            if current_product:
                result.setdefault(current_product, [])
            continue
        # Template ID
        m = re.match(r"^- (TPL-[A-Z0-9-]+)", stripped)
        if m:
            tpl_id = m.group(1)
            if current_product is None:
                # Legacy flat format — bucket to rapidnative
                result.setdefault("rapidnative", []).append(tpl_id)
            else:
                result[current_product].append(tpl_id)
    # Drop empty product buckets so callers can `if not result:` cleanly
    return {p: v for p, v in result.items() if v}


def parse_accounts() -> dict:
    """Return {@handle: [persona_name, ...]} — named-account lists, 1-indexed by list order.
    accounts.md format: per-crew '## @handle' section followed by a numbered list:
      1. Anna
      2. Peter
      ...
    These named personas are used across ALL platforms.
    """
    path = PROJECT_DIR / ".claude" / "skills" / "growth-marketing" / "social-engagement" / "references" / "accounts.md"
    out: dict = {}
    current = None
    for line in path.read_text().splitlines():
        m = re.match(r"^## (@\w+)", line.strip())
        if m:
            current = m.group(1)
            out[current] = []
            continue
        if current is None:
            continue
        # Numbered list item: "1. Anna" or " 2. Peter "
        m = re.match(r"^\d+\.\s+(.+)$", line.strip())
        if m:
            out[current].append(m.group(1).strip())
    return out


def parse_rotation_offsets() -> dict:
    """Return {platform: int_offset}."""
    path = PROJECT_DIR / ".claude" / "skills" / "growth-marketing" / "social-engagement" / "references" / "rotation.md"
    out = {}
    in_table = False
    for line in path.read_text().splitlines():
        if "Per-platform offsets" in line:
            in_table = True
            continue
        if in_table and line.strip().startswith("##"):
            break
        m = re.match(r"^\| ([A-Za-z. ]+) \| ([+-]?\d+) \|", line.strip())
        if m and in_table:
            platform = m.group(1).strip()
            if platform != "Platform":
                out[platform] = int(m.group(2))
    return out


def parse_carryover(crew_by_handle: dict) -> dict:
    """Return {slack_id: [bullet_text, ...]} from yesterday's Carryover queue."""
    path = PROJECT_DIR / "marketing" / "evening-tasks.md"
    if not path.exists():
        return {}
    text = path.read_text()
    if "Carryover queue" not in text:
        return {}
    section = text.split("Carryover queue", 1)[1]
    out: dict = {}
    current = None
    for line in section.splitlines():
        m = re.match(r"^### (@\w+)", line.strip())
        if m:
            current = m.group(1)
            continue
        if current is None:
            continue
        m = re.match(r"^- \[ \] T\d+ · (.+)", line.strip())
        if m:
            sid = crew_by_handle.get(current)
            if sid:
                out.setdefault(sid, []).append(m.group(1))
    return out


def load_recon(date_str: str) -> dict:
    """Return {product_slug: recon_block}. Handles two shapes:
    - New (per-product): top-level keys are product slugs (rapidnative / applighter / letsdeployit),
      each value is {findings, original_posts, article_drafts}.
    - Legacy (single-product): {findings, original_posts, article_drafts} at top level —
      wrapped as {'rapidnative': <data>} for backward compat.
    Empty dict if the cache file doesn't exist.
    """
    path = PROJECT_DIR / "marketing" / ".state" / f"recon-{date_str}.json"
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if any(k in PRODUCT_SLUGS for k in data.keys()):
        # New shape — pass through
        return {k: v for k, v in data.items() if k in PRODUCT_SLUGS}
    if "findings" in data or "original_posts" in data or "article_drafts" in data:
        # Legacy shape — wrap
        return {"rapidnative": data}
    return {}


def add_task_via_hook(task: dict, member: dict, today: str, dry_run: bool) -> tuple:
    """Route a marketing task through the centralized `tasks.sh add` hook.

    tasks.sh is the single write path for the tasks system: it composes the
    is_on_leave / is_working_day guards, inserts the sqlite row, and posts a
    notification to #tasks. This function is a thin subprocess wrapper.

    Returns (sqlite_id: Optional[int], ok: bool).
    In --dry-run mode, prints the intended command and returns (None, True).
    """
    product = task.get("product") or "rapidnative"
    if product not in PRODUCT_SLUGS:
        product = "rapidnative"
    tpl_id = task.get("template_id") or "unknown"
    # Route per §"Task-channel routing" in .claude/skills/tasks/SKILL.md:
    # marketing-morning:* → #rn-coach-social (C0B6Q8TUVL2), regardless of product.
    cmd = [
        str(TASKS_SH),
        "add",
        member["slack_id"],
        today,
        task["bullet"],
        "--category", "marketing",
        "--product", product,
        "--source", f"marketing-morning:{today}:{tpl_id}",
        "--notify",
        "--channel", "C0B6Q8TUVL2",
        "--json",
    ]
    if dry_run:
        title_preview = task["bullet"][:70] + ("…" if len(task["bullet"]) > 70 else "")
        print(f"  [DRY] tasks.sh add {member['handle']} {today} '{title_preview}' --category=marketing --product={product} --channel=C0B6Q8TUVL2 --notify")
        return None, True
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        print(f"  [FAIL] tasks.sh add timed out for {member['handle']}", file=sys.stderr)
        return None, False
    except Exception as e:
        print(f"  [FAIL] tasks.sh add exception for {member['handle']}: {e}", file=sys.stderr)
        return None, False
    if result.returncode != 0:
        stderr_head = (result.stderr or "").strip().splitlines()[:3]
        print(f"  [FAIL] tasks.sh add exit={result.returncode} for {member['handle']} :: {' | '.join(stderr_head)}", file=sys.stderr)
        return None, False
    try:
        row = json.loads(result.stdout)
        return row.get("id"), True
    except json.JSONDecodeError:
        print(f"  [FAIL] tasks.sh add returned non-JSON: {result.stdout[:200]}", file=sys.stderr)
        return None, False


def load_blog_cache(date_str: str) -> Optional[dict]:
    path = PROJECT_DIR / "marketing" / ".state" / f"blog-amplification-{date_str}.md"
    if not path.exists():
        return None
    text = path.read_text()
    m = re.match(r"^---\n(.*?)\n---\n(.*)", text, re.DOTALL)
    if not m:
        return None
    fm_text, rest = m.group(1), m.group(2).lstrip("\n")
    fm = {}
    for line in fm_text.splitlines():
        k, _, v = line.partition(":")
        fm[k.strip()] = v.strip()
    if "---BODY---" in rest:
        caption, body = rest.split("---BODY---", 1)
    else:
        caption, body = rest, ""
    return {
        "title": fm.get("title", ""),
        "slug": fm.get("slug", ""),
        "url": fm.get("url", ""),
        "caption": caption.strip(),
        "body": body.strip(),
    }


# ─────────────────────────── TEMPLATES ───────────────────────────


TEMPLATE_DEFS = {
    # Shape A: singular action (article submission)
    "TPL-GFG-ARTICLE":      {"shape": "A", "platform": "GeeksForGeeks", "action": "article"},
    "TPL-MEDIUM-ARTICLE":   {"shape": "A", "platform": "Medium", "action": "article"},
    "TPL-SUBSTACK-POST":    {"shape": "A", "platform": "Substack", "action": "post"},
    "TPL-HASHNODE-ARTICLE": {"shape": "A", "platform": "Hashnode", "action": "article"},
    "TPL-DEVTO-ARTICLE":    {"shape": "A", "platform": "dev.to", "action": "article"},
    "TPL-VOCAL-STORY":      {"shape": "A", "platform": "Vocal", "action": "story"},
    "TPL-LINKEDIN-POST":    {"shape": "A", "platform": "LinkedIn", "action": "post"},
    # Shape B: community postings (single-target engagement)
    "TPL-HN-POST":          {"shape": "B", "platform": "Hackernews"},
    "TPL-REDDIT-POST":      {"shape": "B", "platform": "Reddit"},
    "TPL-QUORA-POST":       {"shape": "B", "platform": "Quora"},
    "TPL-FB-POST":          {"shape": "B", "platform": "Facebook"},
    "TPL-TWITTER-POST":     {"shape": "B", "platform": "Twitter"},
    # Shape C: community engagement (multi-target)
    "TPL-HN-ENGAGE":        {"shape": "C", "platform": "Hackernews"},
    "TPL-REDDIT-ENGAGE":    {"shape": "C", "platform": "Reddit"},
    "TPL-QUORA-ENGAGE":     {"shape": "C", "platform": "Quora"},
    "TPL-LINKEDIN-ENGAGE":  {"shape": "C", "platform": "LinkedIn"},
    "TPL-TWITTER-ENGAGE":   {"shape": "C", "platform": "Twitter"},
    "TPL-COMMUNITY-ENGAGE": {"shape": "C", "platform": "Community forums"},
    # Shape D: personal-account post (original)
    "TPL-QUORA-PERSONAL":   {"shape": "D", "platform": "Quora"},
    "TPL-LINKEDIN-PERSONAL":{"shape": "D", "platform": "LinkedIn"},
    "TPL-TWITTER-PERSONAL": {"shape": "D", "platform": "Twitter"},
    # Shape E: quota
    "TPL-DISTRO-6":         {"shape": "E", "quota": 6},
    "TPL-DISTRO-3":         {"shape": "E", "quota": 3},
    "TPL-DISTRO-10":        {"shape": "E", "quota": 10},
    # Shape F: distro of a published blog. No platform / no persona rotation —
    # the bullet is intentionally static; task-assist thread reply fetches the
    # live blog title + source thread URL from #ai-blogs (RN) or
    # #applighter-ai-blogs (AL) at reply time and posts variants for the crew.
    "TPL-DISTRO-ARTICLE":   {"shape": "F"},
}


def infer_template_from_bullet(bullet: str) -> Optional[str]:
    """For carryover bullets that don't carry a TPL-ID, sniff platform + shape."""
    b = bullet.lower()
    # Article submissions (Shape A)
    if "submit 1 article to geeksforgeeks" in b: return "TPL-GFG-ARTICLE"
    if "submit 1 article to medium" in b: return "TPL-MEDIUM-ARTICLE"
    if "submit 1 article to hashnode" in b: return "TPL-HASHNODE-ARTICLE"
    if "submit 1 article to dev.to" in b: return "TPL-DEVTO-ARTICLE"
    if "submit 1 post to substack" in b: return "TPL-SUBSTACK-POST"
    if "submit 1 story to vocal" in b: return "TPL-VOCAL-STORY"
    # Community postings (Shape B)
    if "hackernews community postings" in b: return "TPL-HN-POST"
    if "reddit community postings" in b: return "TPL-REDDIT-POST"
    if "quora community postings" in b: return "TPL-QUORA-POST"
    if "facebook community postings" in b: return "TPL-FB-POST"
    if "twitter community postings" in b: return "TPL-TWITTER-POST"
    # Community engagement (Shape C)
    if "hackernews community engagement" in b: return "TPL-HN-ENGAGE"
    if "reddit community engagement" in b: return "TPL-REDDIT-ENGAGE"
    if "quora community engagement" in b: return "TPL-QUORA-ENGAGE"
    if "linkedin community engagement" in b: return "TPL-LINKEDIN-ENGAGE"
    if "twitter community engagement" in b: return "TPL-TWITTER-ENGAGE"
    if "community forums" in b and "engagement" in b: return "TPL-COMMUNITY-ENGAGE"
    # Personal account (Shape D)
    if "post from quora account (from personal accounts)" in b: return "TPL-QUORA-PERSONAL"
    if "post from linkedin account (from personal accounts)" in b: return "TPL-LINKEDIN-PERSONAL"
    if "post from twitter account (from personal accounts)" in b: return "TPL-TWITTER-PERSONAL"
    # Quota (Shape E)
    if "write 6 articles for distribution" in b: return "TPL-DISTRO-6"
    if "write 3 articles for distribution" in b: return "TPL-DISTRO-3"
    if "write 10 articles for distribution" in b: return "TPL-DISTRO-10"
    # Distro of published blog (Shape F)
    if "distribute today's blog" in b: return "TPL-DISTRO-ARTICLE"
    # Blog task (synthetic — matches any product)
    if re.search(r"publish a blog for (rapidnative|applighter|letsdeployit)", b): return "BLOG-TASK"
    return None


def compute_pool(W: int, offset: int, account_names: list) -> tuple:
    """Return (pool_names, clamped). pool_names is a tuple of persona names picked from
    account_names by 1-indexed positions [W+1+offset, W+2+offset, W+3+offset], clamped
    to list length and de-duped preserving order.
    """
    if not account_names:
        return (), False
    owned = len(account_names)
    raw_positions = [W + 1 + offset, W + 2 + offset, W + 3 + offset]
    clamped_positions = [min(p, owned) for p in raw_positions]
    seen = set()
    unique_positions = [p for p in clamped_positions if not (p in seen or seen.add(p))]
    clamped = unique_positions != raw_positions
    # Map 1-indexed positions to names
    pool_names = tuple(account_names[p - 1] for p in unique_positions)
    return pool_names, clamped


def render_bullet(template_id: str, pool, week_lbl: str, clamped=False) -> str:
    """Render a bullet using named accounts. `pool` is a tuple of persona names like
    ('Élodie', 'Amélie', 'Chloé'). The 'nth' account is pool[-1] (last name in the window).
    """
    tpl = TEMPLATE_DEFS.get(template_id, {})
    shape = tpl.get("shape", "?")
    platform = tpl.get("platform", "?")
    pool_str = ", ".join(pool) if pool else "?"
    last_name = pool[-1] if pool else "?"
    clamp = f" [clamped: only {len(pool)} accounts available]" if clamped else ""

    if shape == "A":
        action = tpl["action"]
        return f"Submit 1 {action} to {platform} from {last_name} account - ({pool_str} for {week_lbl}){clamp}"
    if shape == "B":
        return f"{platform} community postings using {last_name} account - ({pool_str} for {week_lbl}){clamp}"
    if shape == "C":
        return f"{platform} community engagement - ({pool_str} for {week_lbl}){clamp}"
    if shape == "D":
        return f"{platform} ({pool_str}) Post from {platform} account (from personal accounts){clamp}"
    if shape == "E":
        return f"Write {tpl['quota']} articles for Distribution"
    if shape == "F":
        return "Distribute today's blog to a platform of choice"
    return f"<unknown template {template_id}>"


# ─────────────────────────── ENRICHMENT ───────────────────────────


def split_for_slack(text: str, max_chars: int = 35000) -> list:
    """Split text into chunks Slack will accept. Tries to break on paragraph boundaries."""
    if len(text) <= max_chars:
        return [text]
    out = []
    while len(text) > max_chars:
        # Try to break on \n\n
        cut = text.rfind("\n\n", 0, max_chars)
        if cut < max_chars // 2:
            cut = text.rfind("\n", 0, max_chars)
        if cut < max_chars // 2:
            cut = max_chars
        out.append(text[:cut])
        text = text[cut:].lstrip("\n")
    if text:
        out.append(text)
    return out


def render_enrichment_engagement_single(finding: dict) -> str:
    return (
        f"🔗 <{finding['url']}> — \"{finding.get('title','')}\""
        + (f" ({finding['context']})" if finding.get("context") else "")
        + f"\n💬 Suggested draft: \"{finding.get('draft','(no draft)')}\""
    )


def render_enrichment_engagement_multi(findings: list) -> str:
    """List 3-4 findings as a numbered list with URL + brief draft."""
    if not findings:
        return ""
    out = ["Top to engage on (pick 1-2 to comment, others to upvote):\n"]
    for i, f in enumerate(findings[:4], 1):
        block = f"\n{i}. 🔗 <{f['url']}> — \"{f.get('title','')}\""
        if f.get("context"):
            block += f" ({f['context']})"
        if f.get("draft"):
            block += f"\n   💬 Suggested: \"{f['draft']}\""
        out.append(block)
    return "".join(out)


def render_enrichment_personal(template_id: str, draft: dict) -> str:
    """Personal-account: compose URL + draft."""
    platform_map = {
        "TPL-LINKEDIN-PERSONAL": "LinkedIn",
        "TPL-TWITTER-PERSONAL": "Twitter",
        "TPL-QUORA-PERSONAL": "Quora",
    }
    platform = platform_map.get(template_id, "?")
    draft_text = draft.get("draft", "")
    angle = draft.get("topic_angle", "")
    # Compose URL
    if platform == "Twitter":
        compose_url = "https://twitter.com/intent/tweet?text=" + urllib.parse.quote(draft_text)
        url_line = f"🔗 Compose (pre-filled): <{compose_url}>"
    elif platform == "LinkedIn":
        url_line = "🔗 Compose: <https://www.linkedin.com/feed/?shareActive=true&mini=true> (LinkedIn won't pre-fill; copy the draft below first)"
    elif platform == "Quora":
        q_url = draft.get("linked_question_url", "https://www.quora.com/")
        url_line = f"🔗 Answer this question: <{q_url}>"
    else:
        url_line = "🔗 (no compose URL)"
    return (
        f"{url_line}\n"
        f"📝 Suggested post (adapt before publishing) — angle: {angle}\n"
        f"\"{draft_text}\""
    )


def render_enrichment_article(draft: dict) -> str:
    topic = draft.get("topic", "")
    outline = draft.get("outline", [])
    body = draft.get("draft_body", "")
    outline_lines = "\n".join(f"{i}. {o}" for i, o in enumerate(outline, 1))
    return (
        f"📰 Suggested article (adapt + ship — ~10-15 min review):\n\n"
        f"*Topic:* {topic}\n\n"
        f"*Outline:*\n{outline_lines}\n\n"
        f"*Draft body:*\n\n{body}"
    )


def render_enrichment_blog(task: dict) -> str:
    return (
        f"🔗 Published at: <{task['blog_url']}>\n\n"
        f"📝 Suggested social caption (LinkedIn / Twitter — adapt before posting):\n"
        f"\"{task['blog_caption']}\"\n\n"
        f"---\n\n"
        f"📰 *Full blog content* (read here, then ship the assets below):\n\n"
        f"{task['blog_body']}\n\n"
        f"---\n\n"
        f"*Asset checklist:*\n"
        f"• Cover image (1200×630 OG, 1080×1080 IG, 1500×500 X banner)\n"
        f"• Video cut (60s vertical for Reels/Shorts, 2-3 min landscape for YouTube)\n"
        f"• Short-form social post adapted from the caption above (post from personal LinkedIn/X)\n\n"
        f"Drop rendered assets in this thread when ready, or reply 'done' / react ✅."
    )


# ─────────────────────────── BUILD TASK LIST ───────────────────────────


def build_task_list(member: dict, product: str, product_templates: list, accounts: dict, offsets: dict, W: int, wlabel: str) -> list:
    """Build [{id, template_id, product, bullet, section, platform, pool}] for one
    crew member × one product. Called once per product per member; caller concatenates."""
    handle = member["handle"]
    names = accounts.get(handle, [])
    tasks = []
    for tpl_id in product_templates:
        tpl = TEMPLATE_DEFS.get(tpl_id)
        if not tpl:
            continue
        shape = tpl["shape"]
        if shape in ("E", "F"):
            # E: quota task (e.g. "Write 6 articles for Distribution")
            # F: distro of published blog — bullet is static; task-assist fetches
            #    the live blog title + variants URL at reply time.
            tasks.append({
                "template_id": tpl_id,
                "product": product,
                "bullet": render_bullet(tpl_id, None, wlabel),
                "section": "new today",
                "platform": None,
                "pool": None,
            })
        else:
            platform = tpl["platform"]
            if not names:
                continue  # crew has no named accounts (shouldn't happen)
            offset = offsets.get(platform, 0)
            pool, clamped = compute_pool(W, offset, names)
            if not pool:
                continue
            tasks.append({
                "template_id": tpl_id,
                "product": product,
                "bullet": render_bullet(tpl_id, pool, wlabel, clamped),
                "section": "new today",
                "platform": platform,
                "pool": pool,
            })
    return tasks


def attach_carryover(tasks: list, carryover_bullets: list, accounts: dict, handle: str, offsets: dict, W: int, wlabel: str) -> list:
    """Prepend carryover tasks (parsed from yesterday's evening-tasks.md). Infer
    template_id + product. Carryover text may or may not carry a product tag;
    if not, sniff for "publish a blog for <slug>" or default to rapidnative.
    """
    names = accounts.get(handle, [])
    out = []
    for bullet_text in carryover_bullets:
        tpl_id = infer_template_from_bullet(bullet_text)
        platform = None
        pool = None
        if tpl_id:
            tpl = TEMPLATE_DEFS.get(tpl_id, {})
            platform = tpl.get("platform")
            if platform and names:
                offset = offsets.get(platform, 0)
                pool, _ = compute_pool(W, offset, names)
        # Sniff product from bullet text; default rapidnative for legacy carryovers
        product = "rapidnative"
        low = bullet_text.lower()
        for slug in PRODUCT_SLUGS:
            tag = PRODUCT_TAG.get(slug, "").lower()
            if tag and tag in low:
                product = slug
                break
            if f"for {slug}" in low:
                product = slug
                break
        out.append({
            "template_id": tpl_id,
            "product": product,
            "bullet": bullet_text,
            "section": "carryover",
            "platform": platform,
            "pool": pool,
        })
    return out + tasks


def distribute_engagement_findings(all_tasks_by_crew: dict, recon_by_product: dict):
    """Round-robin single-target findings across crew, multi-target gets full list.
    Now product-aware: a task tagged product=X only draws from recon[X]. Cross-product
    URL dedupe: first product to claim a URL keeps it; later products skip that URL.
    """
    display_to_recon_key = {
        "Hackernews": "HN",
        "Reddit": "Reddit",
        "Quora": "Quora",
        "LinkedIn": "LinkedIn",
        "Twitter": "Twitter",
        "Facebook": "Facebook",
    }
    # Build {(product, plat): [findings]} with URL dedupe across products
    findings_by_key: dict = {}
    seen_urls: set = set()
    for product in PRODUCT_SLUGS:
        block = recon_by_product.get(product, {})
        for plat, sub in block.get("findings", {}).items():
            if sub.get("status") != "ok":
                continue
            deduped = []
            for f in sub.get("findings", []):
                url = f.get("url", "")
                if url and url in seen_urls:
                    continue
                if url:
                    seen_urls.add(url)
                deduped.append(f)
            findings_by_key[(product, plat)] = deduped

    # Single-target distribution: group by (product, platform)
    single_targets: dict = {}
    for sid, tasks in all_tasks_by_crew.items():
        for t in tasks:
            tpl = TEMPLATE_DEFS.get(t["template_id"], {})
            if tpl.get("shape") == "B":
                plat = display_to_recon_key.get(tpl["platform"], tpl["platform"])
                key = (t.get("product", "rapidnative"), plat)
                single_targets.setdefault(key, []).append(t)
    for key, tasks in single_targets.items():
        findings = findings_by_key.get(key, [])
        if not findings:
            continue
        for i, t in enumerate(tasks):
            t["recon_finding"] = findings[i % len(findings)]

    # Multi-target: every C-shape task gets its (product, platform) findings list
    for sid, tasks in all_tasks_by_crew.items():
        for t in tasks:
            tpl = TEMPLATE_DEFS.get(t["template_id"], {})
            if tpl.get("shape") == "C":
                plat = display_to_recon_key.get(tpl["platform"], tpl["platform"])
                key = (t.get("product", "rapidnative"), plat)
                findings = findings_by_key.get(key, [])
                if findings:
                    t["recon_findings_list"] = findings


def attach_personal_drafts(all_tasks_by_crew: dict, recon_by_product: dict):
    """Per (crew × product × personal template), attach matching original_posts draft."""
    template_to_platform_key = {
        "TPL-LINKEDIN-PERSONAL": "LinkedIn",
        "TPL-TWITTER-PERSONAL": "Twitter",
        "TPL-QUORA-PERSONAL": "Quora",
    }
    # Build {(product, platform_key, sid): draft}
    draft_map: dict = {}
    for product in PRODUCT_SLUGS:
        op = recon_by_product.get(product, {}).get("original_posts", {})
        for plat_key, block in op.items():
            if block.get("status") != "ok":
                continue
            for d in block.get("drafts", []):
                draft_map[(product, plat_key, d["intended_for"])] = d

    for sid, tasks in all_tasks_by_crew.items():
        for t in tasks:
            tpl_id = t["template_id"]
            if tpl_id not in template_to_platform_key:
                continue
            plat_key = template_to_platform_key[tpl_id]
            product = t.get("product", "rapidnative")
            if d := draft_map.get((product, plat_key, sid)):
                t["personal_draft"] = d


def attach_article_drafts(all_tasks_by_crew: dict, recon_by_product: dict):
    """Per (crew × product × article template), attach matching article_drafts."""
    # Build {(product, tpl_id, sid): draft}
    draft_map: dict = {}
    for product in PRODUCT_SLUGS:
        ad = recon_by_product.get(product, {}).get("article_drafts", {})
        for tpl_id, block in ad.items():
            if block.get("status") != "ok":
                continue
            for d in block.get("drafts", []):
                draft_map[(product, tpl_id, d["intended_for"])] = d

    for sid, tasks in all_tasks_by_crew.items():
        for t in tasks:
            product = t.get("product", "rapidnative")
            if d := draft_map.get((product, t["template_id"], sid)):
                t["article_draft"] = d


def append_blog_task(all_tasks_by_crew: dict, working: list, blog_cache: Optional[dict], wlabel: str):
    """Append a single synthetic BLOG-TASK to @russel (preferred) or @famitha.
    Product defaults to rapidnative if blog_cache doesn't carry a `product` field."""
    if not blog_cache:
        return
    product = blog_cache.get("product") or "rapidnative"
    if product not in PRODUCT_SLUGS:
        product = "rapidnative"
    assignee = None
    for handle in ("@russel", "@famitha"):
        for m in working:
            if m["handle"] == handle:
                assignee = m
                break
        if assignee:
            break
    if not assignee and working:
        assignee = working[0]
    if not assignee:
        return
    # If assignee doesn't cover this product, silently promote — blogs are cross-crew work
    sid = assignee["slack_id"]
    all_tasks_by_crew[sid].append({
        "template_id": "BLOG-TASK",
        "product": product,
        "bullet": f"Publish a blog for {product} — {blog_cache['title']}",
        "section": "new today",
        "platform": None,
        "pool": None,
        "blog_url": blog_cache["url"],
        "blog_title": blog_cache["title"],
        "blog_caption": blog_cache["caption"],
        "blog_body": blog_cache["body"],
    })


def number_tasks(tasks: list) -> list:
    for i, t in enumerate(tasks, 1):
        t["id"] = f"T{i:02d}"
    return tasks


# ─────────────────────────── POST LOOP ───────────────────────────


def post_for_crew(member: dict, tasks: list, wlabel: str, today: str, dry_run: bool) -> dict:
    """Post a per-crew summary header, then route every task through `tasks.sh add`.

    tasks.sh is the SINGLE write path for the tasks system — it inserts the
    sqlite row AND posts a #tasks notification. This function is now a thin
    orchestrator: header (a summary, not a task) via direct slack_post; each
    task via subprocess to tasks.sh.

    Enrichment thread replies (draft post text / thread suggestions) are
    intentionally NOT posted from here anymore — the enrichment data still
    lives in the recon cache and can be attached to tasks in a follow-up
    phase (via the sqlite metadata column, exposed by `tasks.sh get <id>`).

    Returns {handle, header_ts, task_ids, posted, failed}.
    """
    sid = member["slack_id"]
    handle = member["handle"]
    carry_n = sum(1 for t in tasks if t["section"] == "carryover")
    new_n = sum(1 for t in tasks if t["section"] == "new today")
    total = len(tasks)

    # Per-product breakdown line (only shown if >1 product represented, else silent)
    product_counts: dict = {}
    for t in tasks:
        p = t.get("product", "rapidnative")
        product_counts[p] = product_counts.get(p, 0) + 1
    breakdown_line = ""
    if len(product_counts) > 1:
        parts = [f"{PRODUCT_DISPLAY.get(p, p)}: {c}" for p, c in product_counts.items()]
        breakdown_line = f"_{' · '.join(parts)}_\n\n"

    header_body = (
        f"<@{sid}> — {handle} · {total} tasks today ({carry_n} carryover, {new_n} new)\n\n"
        f"{breakdown_line}"
        f"_Each task is created via `tasks.sh add` and lands as its own top-level "
        f"post below. Task ids are sqlite row ids — use `tasks.sh get <id>` for full detail._"
    )

    if dry_run:
        print(f"  [DRY] would post header for {handle} (total={total}, carry={carry_n}, new={new_n})")
        header_ts = f"DRY-HEADER-{sid}"
    else:
        header_ts = slack_post(header_body)
        if not header_ts:
            return {"handle": handle, "header_ts": None, "task_ids": [], "posted": 0, "failed": 1}
        time.sleep(0.3)

    result = {"handle": handle, "header_ts": header_ts, "task_ids": [], "posted": 0, "failed": 0}

    for task in tasks:
        sqlite_id, ok = add_task_via_hook(task, member, today, dry_run)
        if ok:
            result["posted"] += 1
            if sqlite_id is not None:
                result["task_ids"].append(sqlite_id)
        else:
            result["failed"] += 1
        # Space out subprocess + Slack calls so we don't trip slack.com's tier-1 rate limit
        if not dry_run:
            time.sleep(0.3)
    return result


# ─────────────────────────── SNAPSHOT ───────────────────────────


def write_snapshot(sentinel: dict, today: str, wlabel: str, on_leave: list):
    """Write marketing/morning-tasks.md (human-readable)."""
    out = [f"# Morning tasks — {today} ({wlabel})", ""]
    out.append(f"_Generated by gen-marketing-morning.py at {datetime.datetime.now().strftime('%H:%M IST')}. "
               f"Edit `.claude/skills/growth-marketing/social-engagement/references/sprint.md` or `.claude/skills/growth-marketing/social-engagement/references/rotation.md` and rerun to regenerate._")
    out.append("")
    out.append("## Skipped (on leave)")
    out.append("")
    if on_leave:
        for m in on_leave:
            out.append(f"- <@{m['slack_id']}> {m['handle']} — covered by sqlite leave_entries")
    else:
        out.append("- _nobody_")
    out.append("")
    out.append("---")
    out.append("")
    for sid, info in sentinel["crews"].items():
        out.append(f"### {info['handle']}")
        out.append("")
        # We don't easily have the carry/new split here in the sentinel; skip the section markers
        for row_id in info.get("task_ids", []):
            out.append(f"- [ ] #{row_id} · (see `tasks.sh get {row_id}`)")
        out.append("")
    path = PROJECT_DIR / "marketing" / "morning-tasks.md"
    path.write_text("\n".join(out))


# ─────────────────────────── MAIN ───────────────────────────


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Compute + print plan; don't post to Slack or write sentinel.")
    args = ap.parse_args()

    today = today_ist()
    yesterday = shift_days(today, -1)

    # Guards
    if is_weekend(today):
        print(f"weekend ({today}); skipping", file=sys.stderr)
        return 0
    if is_holiday(today):
        print(f"holiday ({today}); skipping", file=sys.stderr)
        return 0

    sentinel_path = PROJECT_DIR / "marketing" / ".state" / f"morning-ts-{today}.json"
    if sentinel_path.exists() and not args.dry_run:
        print(f"already posted today (sentinel exists): {sentinel_path}", file=sys.stderr)
        return 0

    # Parse inputs — templates and recon are now product-keyed dicts
    today_templates_by_product = parse_sprint(today)
    if not today_templates_by_product:
        msg = f"🟠 *marketing-morning skipped* — sprint.md has no section (or is empty) for {today}. Edit .claude/skills/growth-marketing/social-engagement/references/sprint.md and rerun: accountability/routines/gen-marketing-morning.py"
        if not args.dry_run:
            slack_post(msg)
        print(f"sprint has no section for {today}; posted nudge", file=sys.stderr)
        return 0

    team_all = parse_team()
    crew_by_handle = {m["handle"]: m["slack_id"] for m in team_all}
    accounts = parse_accounts()
    offsets = parse_rotation_offsets()
    carryover_by_sid = parse_carryover(crew_by_handle)
    recon = load_recon(today)  # {product_slug: block}
    blog_cache = load_blog_cache(today) or load_blog_cache(yesterday)

    # Filter to working (active + not on leave)
    working = []
    on_leave = []
    for m in team_all:
        if not m["active"]:
            continue
        if is_on_leave(m["slack_id"], today):
            on_leave.append(m)
        else:
            working.append(m)
    if not working:
        if not args.dry_run:
            slack_post(f"🟠 *marketing-morning* — everyone is on leave today ({today}). No tasks posted.")
        print("everyone on leave; exiting", file=sys.stderr)
        return 0

    W = week_of_month(today)
    wlabel = week_label(today)

    # Build per-crew task lists — fan out across (member × product × template)
    all_tasks_by_crew: dict = {}
    for m in working:
        sid = m["slack_id"]
        member_products = set(m.get("products") or ["rapidnative"])
        new_tasks: list = []
        for product, product_templates in today_templates_by_product.items():
            if product not in member_products:
                continue
            new_tasks.extend(build_task_list(m, product, product_templates, accounts, offsets, W, wlabel))
        full_list = attach_carryover(new_tasks, carryover_by_sid.get(sid, []), accounts, m["handle"], offsets, W, wlabel)
        all_tasks_by_crew[sid] = full_list

    # Append blog task to one crew (russel preferred)
    append_blog_task(all_tasks_by_crew, working, blog_cache, wlabel)

    # Attach enrichment from recon (product-aware)
    distribute_engagement_findings(all_tasks_by_crew, recon)
    attach_personal_drafts(all_tasks_by_crew, recon)
    attach_article_drafts(all_tasks_by_crew, recon)

    # Number tasks T01, T02, ...
    for sid in all_tasks_by_crew:
        number_tasks(all_tasks_by_crew[sid])

    # Post — every task routes through tasks.sh (sqlite + #tasks notify) via the hook
    sentinel = {"version": 3, "date": today, "crews": {}}
    print(f"=== gen-marketing-morning {today} ({wlabel}) ===")
    print(f"working: {[m['handle'] for m in working]}")
    print(f"on leave: {[m['handle'] for m in on_leave]}")
    print(f"templates today: {today_templates_by_product}")
    print(f"recon products: {list(recon.keys())}, blog: {bool(blog_cache)}")
    print()
    total_posted = 0
    total_failed = 0
    all_task_ids: list = []
    for m in working:
        sid = m["slack_id"]
        tasks = all_tasks_by_crew[sid]
        if not tasks:
            continue
        print(f">>> posting for {m['handle']} ({len(tasks)} tasks) via tasks.sh add")
        result = post_for_crew(m, tasks, wlabel, today, args.dry_run)
        sentinel["crews"][sid] = {
            "handle": result["handle"],
            "header_ts": result["header_ts"],
            "task_ids": result["task_ids"],
        }
        total_posted += result["posted"]
        total_failed += result["failed"]
        all_task_ids.extend(result["task_ids"])
        print(f"    posted={result['posted']}, task_ids captured={len(result['task_ids'])}, failed={result['failed']}")

    if args.dry_run:
        print()
        print("=== DRY-RUN SUMMARY ===")
        print(f"would call tasks.sh add {total_posted} times, {total_failed} would fail")
        return 0

    # Write sentinel atomically
    sentinel_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = sentinel_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(sentinel, indent=2))
    tmp.rename(sentinel_path)
    print(f"\nsentinel: {sentinel_path}")

    write_snapshot(sentinel, today, wlabel, on_leave)
    print(f"snapshot: {PROJECT_DIR / 'marketing' / 'morning-tasks.md'}")

    # ─── Enrich every task's thread via the task-assistance module ────
    # Fires task-assist.sh for each sqlite id created above. task-assist reads
    # the daily recon cache + Slack blog channels and posts platform-specific
    # thread content (article drafts, HN thread suggestions, personal-post
    # drafts, distro-article variant files). --silent-on-empty means we don't
    # post noise when recon has nothing for a given task (e.g. quota tasks
    # like TPL-DISTRO-6 or platforms with no recon-scraped data).
    enrich_ok, enrich_silent, enrich_fail = 0, 0, 0
    task_assist_sh = str(PROJECT_DIR / "accountability" / "routines" / "task-assist.sh")
    for tid in all_task_ids:
        try:
            r = subprocess.run(
                [task_assist_sh, str(tid), "--silent-on-empty"],
                capture_output=True, text=True, timeout=45,
            )
            if r.returncode == 0:
                if r.stdout.startswith("SILENT"):
                    enrich_silent += 1
                else:
                    enrich_ok += 1
            else:
                enrich_fail += 1
                print(f"  [enrich-fail] T{tid}: {(r.stderr or '').strip()[:120]}", file=sys.stderr)
        except Exception as e:
            enrich_fail += 1
            print(f"  [enrich-exc] T{tid}: {e}", file=sys.stderr)
        # Rate limit to stay under Slack tier-1 limits (~1 write/sec).
        time.sleep(0.5)
    print(f"task-assist enrichment: {enrich_ok} posted · {enrich_silent} silent (no data) · {enrich_fail} failed")

    print()
    print("=== RUN SUMMARY ===")
    print(f"crews posted:      {len(sentinel['crews'])}")
    print(f"tasks.sh calls OK: {total_posted}")
    print(f"sqlite ids saved:  {len(all_task_ids)}")
    print(f"failures:          {total_failed}")
    print(f"enrichment:        {enrich_ok} posted, {enrich_silent} silent, {enrich_fail} failed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
