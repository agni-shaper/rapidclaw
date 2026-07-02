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
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
CHANNEL_ID = "C0ASK9520JG"   # #tasks (was #marketing-automation C0BBQ7PV34N until 2026-07-02)
TOKEN_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach-slack-bot-token"
DB_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach.sqlite"

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


def insert_task_sqlite(task: dict, member: dict, today: str, wlabel: str, task_ts: Optional[str]) -> Optional[int]:
    """Persist a marketing-morning-generated task row into sqlite `tasks` — the
    centralized task DB. Every task the helper posts to Slack also lands here as
    an `open` row so the evening routine (and any other consumer) can query it
    via `tasks.sh list --category marketing --due <today>`.

    Fields:
      - title:    the human-readable bullet
      - assignee: crew member's Slack ID
      - status:   'open'
      - priority: 'normal' (uniform for now; future: derive from template shape)
      - category: 'marketing'
      - product:  the fan-out product tag ('rapidnative' | 'applighter' | 'letsdeployit')
      - source:   'marketing-morning:<YYYY-MM-DD>:<TPL-ID>'
      - due_date: today (same-day social distribution)
      - metadata: JSON — template_id, platform, pool, section, week_label,
                        slack_thread_ts (for evening reconciliation)

    Returns the new row id on success, None on failure. Never raises — Slack
    posting continues even if sqlite is down.
    """
    if not DB_PATH.exists():
        return None
    product = task.get("product") or "rapidnative"
    if product not in PRODUCT_SLUGS:
        product = "rapidnative"
    tpl_id = task.get("template_id") or "unknown"
    metadata = {
        "template_id": tpl_id,
        "platform": task.get("platform"),
        "pool": list(task["pool"]) if task.get("pool") else None,
        "section": task.get("section"),
        "week_label": wlabel,
        "slack_thread_ts": task_ts,
    }
    try:
        with sqlite3.connect(DB_PATH) as conn:
            cur = conn.execute(
                "INSERT INTO tasks (title, assignee, status, priority, category, product, source, due_date, metadata) "
                "VALUES (?, ?, 'open', 'normal', 'marketing', ?, ?, ?, ?)",
                (
                    task["bullet"],
                    member["slack_id"],
                    product,
                    f"marketing-morning:{today}:{tpl_id}",
                    today,
                    json.dumps(metadata),
                ),
            )
            return cur.lastrowid
    except Exception as e:
        print(f"  [sqlite-err] insert failed for {member['handle']}: {e}", file=sys.stderr)
        return None


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
        if shape == "E":
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
    """Post header + all tasks (with enrichment) for one crew member; also
    persist each task to sqlite `tasks` (the centralized DB) so downstream
    consumers (evening routine, task-list.sh, etc.) can see them.

    Returns {handle, header_ts, tasks: {Tid: ts}, posted, enriched, failed, sqlite_rows}.
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
        f"_Each task is posted as its own top-level message below. "
        f"Open a task's thread, do the work, then reply 'done' or react :white_check_mark: in that task's thread to mark it complete. "
        f"The 19:30 IST routine reads each task's thread and rolls unfinished tasks into tomorrow._"
    )

    if dry_run:
        print(f"  [DRY] would post header for {handle} (total={total}, carry={carry_n}, new={new_n})")
        header_ts = f"DRY-HEADER-{sid}"
    else:
        header_ts = slack_post(header_body)
        if not header_ts:
            return {"handle": handle, "header_ts": None, "tasks": {}, "posted": 0, "enriched": 0, "failed": 1}
        time.sleep(0.3)

    result = {"handle": handle, "header_ts": header_ts, "tasks": {}, "posted": 0, "enriched": 0, "failed": 0, "sqlite_rows": 0}

    for task in tasks:
        tid = task["id"]
        section = task["section"]
        bullet = task["bullet"]
        product_tag = PRODUCT_TAG.get(task.get("product", "rapidnative"), "")
        # Only prepend the tag when >1 product is in play; on RN-only days keep the old shape
        tag_prefix = f"{product_tag} " if product_tag and len(product_counts) > 1 else ""
        task_body = (
            f"{tid} · {tag_prefix}*{bullet}*\n"
            f"_{section} · {wlabel}_\n\n"
            f"_Reply 'done' in this thread when complete, or react :white_check_mark:._"
        )
        if dry_run:
            print(f"  [DRY] would post {tid} for {handle}")
            task_ts = f"DRY-{sid}-{tid}"
        else:
            task_ts = slack_post(task_body)
            if not task_ts:
                result["failed"] += 1
                print(f"  [FAIL] task {tid} for {handle}", file=sys.stderr)
                continue
            time.sleep(0.3)

        result["tasks"][tid] = task_ts
        result["posted"] += 1

        # Persist to sqlite `tasks` (the centralized DB) — skip in dry-run
        if not dry_run:
            row_id = insert_task_sqlite(task, member, today, wlabel, task_ts)
            if row_id:
                result["sqlite_rows"] += 1
                task["sqlite_id"] = row_id

        # Enrichment
        enrichment = build_enrichment(task)
        if not enrichment:
            continue
        chunks = split_for_slack(enrichment)
        all_ok = True
        for chunk in chunks:
            if dry_run:
                print(f"  [DRY] would post enrichment for {tid} ({len(chunk)} chars)")
            else:
                rts = slack_post(chunk, thread_ts=task_ts)
                if not rts:
                    print(f"  [FAIL] enrichment chunk for {tid}", file=sys.stderr)
                    all_ok = False
                time.sleep(0.3)
        if all_ok:
            result["enriched"] += 1
    return result


def build_enrichment(task: dict) -> str:
    """Pick the right enrichment renderer for the task's template + attached data."""
    template_id = task["template_id"]
    tpl = TEMPLATE_DEFS.get(template_id, {})
    shape = tpl.get("shape")

    # Engagement single-target
    if shape == "B" and task.get("recon_finding"):
        return render_enrichment_engagement_single(task["recon_finding"])
    # Engagement multi-target
    if shape == "C" and task.get("recon_findings_list"):
        return render_enrichment_engagement_multi(task["recon_findings_list"])
    # Personal-account
    if shape == "D" and task.get("personal_draft"):
        return render_enrichment_personal(template_id, task["personal_draft"])
    # Article submission
    if shape == "A" and task.get("article_draft"):
        return render_enrichment_article(task["article_draft"])
    # Blog task
    if template_id == "BLOG-TASK":
        return render_enrichment_blog(task)
    return ""


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
        for tid in sorted(info["tasks"]):
            out.append(f"- [ ] {tid} · (see Slack thread)")
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

    # Post
    sentinel = {"version": 2, "date": today, "crews": {}}
    print(f"=== gen-marketing-morning {today} ({wlabel}) ===")
    print(f"working: {[m['handle'] for m in working]}")
    print(f"on leave: {[m['handle'] for m in on_leave]}")
    print(f"templates today: {today_templates_by_product}")
    print(f"recon products: {list(recon.keys())}, blog: {bool(blog_cache)}")
    print()
    total_posted = 0
    total_enriched = 0
    total_failed = 0
    for m in working:
        sid = m["slack_id"]
        tasks = all_tasks_by_crew[sid]
        if not tasks:
            continue
        print(f">>> posting for {m['handle']} ({len(tasks)} tasks)")
        result = post_for_crew(m, tasks, wlabel, today, args.dry_run)
        sentinel["crews"][sid] = {
            "handle": result["handle"],
            "header_ts": result["header_ts"],
            "tasks": result["tasks"],
        }
        total_posted += result["posted"]
        total_enriched += result["enriched"]
        total_failed += result["failed"]
        total_sqlite = locals().get("total_sqlite", 0) + result.get("sqlite_rows", 0)
        print(f"    posted={result['posted']}, enriched={result['enriched']}, sqlite_rows={result.get('sqlite_rows', 0)}, failed={result['failed']}")

    if args.dry_run:
        print()
        print("=== DRY-RUN SUMMARY ===")
        print(f"would post: {total_posted} tasks, {total_enriched} with enrichment, {total_failed} failed")
        return 0

    # Write sentinel atomically
    sentinel_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = sentinel_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(sentinel, indent=2))
    tmp.rename(sentinel_path)
    print(f"\nsentinel: {sentinel_path}")

    write_snapshot(sentinel, today, wlabel, on_leave)
    print(f"snapshot: {PROJECT_DIR / 'marketing' / 'morning-tasks.md'}")

    print()
    print("=== RUN SUMMARY ===")
    print(f"crews posted:  {len(sentinel['crews'])}")
    print(f"tasks posted:  {total_posted}")
    print(f"sqlite rows:   {locals().get('total_sqlite', 0)}")
    print(f"enrichments:   {total_enriched}")
    print(f"failures:      {total_failed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
