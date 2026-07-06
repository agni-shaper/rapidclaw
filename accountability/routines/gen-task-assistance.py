#!/usr/bin/env python3
"""
gen-task-assistance.py — build a Markdown assistance block for one task.

Reads a task from sqlite, classifies it by title pattern, looks up matching
data in today's marketing-recon cache, and prints the formatted block to
stdout. Empty output means "no assistance available" — the shell wrapper
still posts a graceful "no assist" line in that case.

Usage:
  python3 gen-task-assistance.py <task_id>              # print markdown to stdout
  python3 gen-task-assistance.py <task_id> --json       # print structured JSON

Exit codes:
  0  success (may print empty text — no matching data)
  1  usage / task not found / bad JSON
"""

import argparse
import datetime
import json
import re
import sqlite3
import sys
import urllib.request
from pathlib import Path
from typing import Optional, Tuple

PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
DB_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach.sqlite"
SLACK_TOKEN_PATH = Path.home() / ".config" / "claude" / "rapidnative-coach-slack-bot-token"

# Blog-source channels per product, for TPL-DISTRO-ARTICLE lookups.
# Each entry: (channel_id, [(text_pattern, blog_type), ...]) — patterns tried in
# order; first match wins. `external` preferred over `internal` per user's ask.
DISTRO_BLOG_SOURCES = {
    "rapidnative": ("C0AMG7SE1FF", [
        ("External blog ready for review", "external"),
        ("Internal blog published",         "internal"),
    ]),
    "applighter":  ("C0B24QUSDSA", [
        ("New blog ready for cross-posting", "external"),
    ]),
    # LDI intentionally omitted — no distro-article pipeline yet.
}


def today_ist() -> str:
    tz = datetime.timezone(datetime.timedelta(hours=5, minutes=30))
    return datetime.datetime.now(tz).strftime("%Y-%m-%d")


def load_task(task_id: int) -> Optional[dict]:
    if not DB_PATH.exists():
        return None
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def load_recon(date_str: str) -> dict:
    path = PROJECT_DIR / "marketing" / ".state" / f"recon-{date_str}.json"
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


# ─────────────────────────── CLASSIFY ───────────────────────────

# Detect platform + template kind from the task title.
# Marketing task titles come from render_bullet in gen-marketing-morning.py.
def classify(title: str) -> dict:
    """Return {'kind': 'engagement'|'personal'|'article'|'blog'|'distro-article'|'quota'|'unknown',
                'platform': str,
                'template_id': str (only for article),
                'evidence': str}."""
    t = title.lower()

    # Blog task (synthetic — created by append_blog_task)
    if t.startswith("publish a blog for"):
        return {"kind": "blog", "platform": "Blog", "evidence": "title starts with 'Publish a blog for'"}

    # Distro of published blog (Shape F, TPL-DISTRO-ARTICLE)
    if t.startswith("distribute today's blog"):
        return {"kind": "distro-article", "platform": None, "template_id": "TPL-DISTRO-ARTICLE",
                "evidence": "title starts with 'Distribute today's blog'"}

    # Quota — no platform, no target
    if "write" in t and "articles for distribution" in t:
        return {"kind": "quota", "platform": None, "evidence": "quota template"}

    # Article submission templates (Shape A) — matches BOTH the marketing-morning
    # canonical form ("Submit 1 article to Hashnode from …") AND the natural-
    # language variants the LLM Slack listener produces ("Write a blog on
    # Hashnode", "Write an article on Medium", "Post on dev.to").
    article_intent = (
        "submit 1 article to" in t
        or "submit 1 post to" in t
        or "submit 1 story to" in t
        or "write a blog on" in t
        or "write a blog for" in t
        or "write an article on" in t
        or "write an article for" in t
        or "post on" in t
        or "post an article on" in t
    )
    if article_intent:
        # Map platform → TPL-* template id (recon.article_drafts is keyed by TPL)
        if "geeksforgeeks" in t or "gfg" in t:
            return {"kind": "article", "platform": "GeeksForGeeks", "template_id": "TPL-GFG-ARTICLE", "evidence": "GFG article"}
        if "medium" in t:
            return {"kind": "article", "platform": "Medium", "template_id": "TPL-MEDIUM-ARTICLE", "evidence": "Medium article"}
        if "hashnode" in t:
            return {"kind": "article", "platform": "Hashnode", "template_id": "TPL-HASHNODE-ARTICLE", "evidence": "Hashnode article"}
        if "dev.to" in t or "devto" in t:
            return {"kind": "article", "platform": "dev.to", "template_id": "TPL-DEVTO-ARTICLE", "evidence": "dev.to article"}
        if "substack" in t:
            return {"kind": "article", "platform": "Substack", "template_id": "TPL-SUBSTACK-POST", "evidence": "Substack post"}
        if "vocal" in t:
            return {"kind": "article", "platform": "Vocal", "template_id": "TPL-VOCAL-STORY", "evidence": "Vocal story"}
        if "linkedin" in t:
            return {"kind": "article", "platform": "LinkedIn", "template_id": "TPL-LINKEDIN-POST", "evidence": "LinkedIn post"}
        # "post on quora" is engagement, not article — fall through to the
        # engagement matcher below.

    # Personal-account posts (Shape D):
    #   "LinkedIn (Emily, Antoine, Théo) Post from LinkedIn account (from personal accounts)"
    if "post from linkedin account" in t and "personal accounts" in t:
        return {"kind": "personal", "platform": "LinkedIn", "evidence": "personal LinkedIn post"}
    if "post from twitter account" in t and "personal accounts" in t:
        return {"kind": "personal", "platform": "Twitter", "evidence": "personal Twitter post"}
    if "post from quora account" in t and "personal accounts" in t:
        return {"kind": "personal", "platform": "Quora", "evidence": "personal Quora post"}

    # Community postings (Shape B — single-target engagement) & engagement (Shape C — multi-target):
    #   "Hackernews community postings using Lucas account - (…)"
    #   "Hackernews community engagement - (…)"
    for plat_word, plat_key in [
        ("hackernews", "HN"),
        ("reddit", "Reddit"),
        ("quora", "Quora"),
        ("linkedin", "LinkedIn"),
        ("twitter", "Twitter"),
        ("facebook", "Facebook"),
        ("community forums", "Community"),
    ]:
        if plat_word in t and ("community postings" in t or "community engagement" in t):
            return {"kind": "engagement", "platform": plat_key, "evidence": f"{plat_key} community"}

    return {"kind": "unknown", "platform": None, "evidence": "no title pattern matched"}


# ─────────────────────────── FORMAT ───────────────────────────


def fmt_engagement_findings(findings: list, platform: str) -> str:
    """Format a list of engagement thread findings as Markdown for Slack."""
    if not findings:
        return ""
    lines = [f"*Suggested {platform} threads* — pick 1–2 to reply to (skim the rest for context):\n"]
    for i, f in enumerate(findings[:4], 1):
        url = f.get("url", "")
        title = f.get("title", "")
        context = f.get("context", "")
        draft = f.get("draft", "")
        lines.append(f"\n*{i}.* <{url}|{title}>")
        if context:
            lines.append(f"    _{context}_")
        if draft:
            lines.append(f"    💬 *Suggested reply:* \"{draft}\"")
    return "\n".join(lines)


def fmt_personal_draft(draft: dict, platform: str) -> str:
    """Format a single personal-account draft."""
    angle = draft.get("topic_angle", "")
    body = draft.get("draft", "")
    lines = [f"*Suggested {platform} post* — adapt before publishing:\n"]
    if angle:
        lines.append(f"*Angle:* {angle}")
    if body:
        lines.append(f"\n\"{body}\"")
    if platform == "Quora" and draft.get("linked_question_url"):
        lines.append(f"\n🔗 *Answer this question:* <{draft['linked_question_url']}>")
    return "\n".join(lines)


def fmt_article_draft(draft: dict, platform: str) -> str:
    """Format a full article draft (topic + outline + body)."""
    topic = draft.get("topic", "")
    outline = draft.get("outline", [])
    body = draft.get("draft_body", "")
    lines = [f"*Suggested {platform} article* — polish and ship:\n"]
    if topic:
        lines.append(f"*Topic:* {topic}")
    if outline:
        lines.append("\n*Outline:*")
        for i, o in enumerate(outline, 1):
            lines.append(f"  {i}. {o}")
    if body:
        # Slack has a 40k message limit; truncate very long bodies with a note.
        trimmed = body if len(body) < 30000 else body[:30000] + "\n\n_[…truncated for Slack; full draft is in the recon cache]_"
        lines.append(f"\n*Draft body:*\n\n{trimmed}")
    return "\n".join(lines)


def fmt_blog_amp(blog: dict, task_title: str) -> str:
    """Format the day's blog for amplification tasks."""
    url = blog.get("url", "")
    title = blog.get("title", "")
    caption = blog.get("caption", "")
    lines = [f"*Blog to amplify:*\n"]
    if url:
        lines.append(f"🔗 <{url}|{title or url}>")
    if caption:
        lines.append(f"\n📝 *Suggested caption:*\n\"{caption}\"")
    return "\n".join(lines)


# ─────────────────────────── LOOKUP ───────────────────────────


def _slack_get(url: str) -> dict:
    """Call Slack Web API; return parsed JSON or {}. Silent on failure — the
    caller renders a graceful fallback."""
    if not SLACK_TOKEN_PATH.exists():
        return {}
    token = SLACK_TOKEN_PATH.read_text().strip()
    try:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req, timeout=6) as r:
            return json.loads(r.read())
    except Exception:
        return {}


def _slack_download_file(url_private: str) -> Optional[str]:
    """Download a Slack-private file's contents as UTF-8 text using the bot token.
    Returns None on any failure."""
    if not SLACK_TOKEN_PATH.exists():
        return None
    token = SLACK_TOKEN_PATH.read_text().strip()
    try:
        req = urllib.request.Request(url_private, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.read().decode("utf-8", errors="replace")
    except Exception:
        return None


def _fetch_thread_variants_raw(channel_id: str, parent_ts: str) -> list:
    """Return the raw list of file attachments in the source thread, preserving
    their Slack-assigned titles + order. Each entry:
    {name, title, url_private, size, ts_ordinal (for ordering)}.
    Filter out the parent-message files (there aren't any in practice — files
    are in reply messages) and skip any files without a title fallback."""
    api = f"https://slack.com/api/conversations.replies?channel={channel_id}&ts={parent_ts}&limit=30"
    resp = _slack_get(api)
    if not resp.get("ok"):
        return []
    out: list = []
    for m in resp.get("messages", []):
        # skip the parent (it typically has no files anyway, but be defensive)
        if m.get("ts") == parent_ts and not m.get("files"):
            continue
        for f in m.get("files", []):
            out.append({
                "name":        f.get("name") or "",
                "title":       (f.get("title") or f.get("name") or "").strip(),
                "url_private": f.get("url_private"),
                "size":        f.get("size", 0),
                "ts":          m.get("ts", ""),
            })
    return out


def _fetch_thread_variants(channel_id: str, parent_ts: str, product: str) -> dict:
    """Fetch source-thread files. Format differs by product:

    - AL / applighter (this bot posts): files named "NN-{canonical,medium,devto,
      hashnode,seo}.md" — one file per platform variant. Extractor returns
      {canonical, medium, devto, hashnode, seo}.

    - RN / rapidnative (ContentWriterBot posts): blog is split into
      "<slug>-section-N.md" (typically 5 sections) plus a
      "publishing-plan-<date>.md" (SEO/distribution plan). Canonical body =
      concatenation of section-1..N in order. No per-platform variants; the
      crew adapts the canonical to each platform themselves. Extractor returns
      {canonical (a synthesized entry with url_private=None), sections (list),
      seo (the publishing-plan file, mapped as 'seo' for consistency)}.

    Return shape (both products): dict keyed by variant name → {name, permalink,
    url_private, size, sections (only for RN canonical: list of section files
    in order — the caller downloads + concatenates)}.
    """
    api = f"https://slack.com/api/conversations.replies?channel={channel_id}&ts={parent_ts}&limit=30"
    resp = _slack_get(api)
    if not resp.get("ok"):
        return {}
    variants: dict = {}

    if product == "applighter":
        for m in resp.get("messages", []):
            for f in m.get("files", []):
                name = (f.get("name") or "").lower()
                for token, key in (
                    ("canonical", "canonical"),
                    ("medium",    "medium"),
                    ("devto",     "devto"),
                    ("dev.to",    "devto"),
                    ("hashnode",  "hashnode"),
                    ("seo",       "seo"),
                ):
                    if token in name and key not in variants:
                        variants[key] = {
                            "name":        f.get("name"),
                            "permalink":   f.get("permalink"),
                            "url_private": f.get("url_private"),
                            "size":        f.get("size", 0),
                        }
                        break

    elif product == "rapidnative":
        section_re = re.compile(r"-section-(\d+)\.md$", re.IGNORECASE)
        sections: list = []
        for m in resp.get("messages", []):
            for f in m.get("files", []):
                name = f.get("name") or ""
                lname = name.lower()
                mm = section_re.search(name)
                if mm:
                    sections.append({
                        "n":           int(mm.group(1)),
                        "name":        name,
                        "permalink":   f.get("permalink"),
                        "url_private": f.get("url_private"),
                        "size":        f.get("size", 0),
                    })
                elif lname.startswith("publishing-plan"):
                    variants["seo"] = {
                        "name":        name,
                        "permalink":   f.get("permalink"),
                        "url_private": f.get("url_private"),
                        "size":        f.get("size", 0),
                    }
        if sections:
            sections.sort(key=lambda s: s["n"])
            total_size = sum(s["size"] for s in sections)
            variants["canonical"] = {
                "name":        sections[0]["name"].split("-section-")[0] + "-canonical.md",
                "permalink":   sections[0]["permalink"],  # link to section-1 as the anchor
                "url_private": None,  # signal: caller must concat sections, not download a single file
                "size":        total_size,
                "sections":    sections,
            }

    return variants


def _download_rn_canonical(sections: list) -> str:
    """RN's canonical body is spread across section files; download + concat."""
    parts: list = []
    for s in sections:
        if not s.get("url_private"):
            continue
        body = _slack_download_file(s["url_private"])
        if body:
            parts.append(body)
    return "\n\n".join(parts)


def _slack_permalink(channel_id: str, ts: str) -> str:
    """Compute a stable Slack permalink from channel + ts (no API call)."""
    return f"https://shaper-studio.slack.com/archives/{channel_id}/p{ts.replace('.', '')}"


def _parse_blog_message(text: str, product: str) -> dict:
    """Product-specific extraction of {title, canonical_url, generated_date}
    from a source-channel message body. Channels use different formats:
      - RN #ai-blogs (ContentWriterBot): title is on a `:page_facing_up: *<title>*` line;
        canonical URL only present for 'Internal blog published' (as a bare URL below `:link:`).
      - AL #applighter-ai-blogs (this bot): title follows 'cross-posting — ' on the
        header line, OR appears as 'Topic: <title>' below. No canonical URL.
    """
    out = {"title": "", "canonical_url": "", "generated_date": ""}

    if product == "rapidnative":
        title_m = re.search(r":page_facing_up:\s*\*([^*\n]{5,200})\*", text)
        if title_m:
            out["title"] = title_m.group(1).strip()
        # Canonical URL only for 'Internal blog published' — bare rapidnative.com/blogs URL.
        url_m = re.search(r"https?://[^\s|>]*rapidnative\.com/blogs/[^\s|>)]+", text)
        if url_m:
            out["canonical_url"] = url_m.group(0).rstrip(">.,;")
    elif product == "applighter":
        # Try header line: "New blog ready for cross-posting — <title>"
        header_m = re.search(r"cross-posting\s*[—–-]\s*([^\n]{5,200})", text)
        if header_m:
            out["title"] = header_m.group(1).strip().rstrip("*")
        # Fallback: "Topic: <title>" line
        if not out["title"]:
            topic_m = re.search(r"^Topic:\s*(.+)$", text, re.MULTILINE)
            if topic_m:
                out["title"] = topic_m.group(1).strip()
        # Applighter posts don't carry a canonical URL (external drafts only).

    gen_m = re.search(r":calendar:\s*(\d{4}-\d{2}-\d{2})", text)
    if not gen_m:
        gen_m = re.search(r"^Generated:\s*(\d{4}-\d{2}-\d{2})", text, re.MULTILINE)
    if gen_m:
        out["generated_date"] = gen_m.group(1)
    return out


def fetch_latest_distro_blog(product: str) -> Optional[dict]:
    """Fetch the latest blog message from the product's source channel + thread
    variants + inline the canonical body.

    Returns {title, canonical_url, blog_type, source_thread_url, generated_date,
             variants: dict, canonical_body: str, canonical_truncated: bool}
    or None if no matching message in the last 20."""
    src = DISTRO_BLOG_SOURCES.get(product)
    if not src:
        return None
    channel_id, patterns = src
    api = f"https://slack.com/api/conversations.history?channel={channel_id}&limit=20"
    resp = _slack_get(api)
    if not resp.get("ok"):
        return None
    messages = resp.get("messages", [])
    for pattern, blog_type in patterns:
        for m in messages:
            text = m.get("text", "")
            if pattern in text:
                parsed = _parse_blog_message(text, product)
                parent_ts = m["ts"]
                raw_variants = _fetch_thread_variants_raw(channel_id, parent_ts)
                return {
                    "title":               parsed["title"],
                    "canonical_url":       parsed["canonical_url"],
                    "blog_type":           blog_type,
                    "source_thread_url":   _slack_permalink(channel_id, parent_ts),
                    "generated_date":      parsed["generated_date"],
                    "raw_variants":        raw_variants,
                }
    return None


_AL_TITLE_MAP = {
    "canonical":  "Canonical (master)",
    "medium":     "Medium Adaptation",
    "devto":      "Dev.to Adaptation",
    "hashnode":   "Hashnode Adaptation",
    "seo":        "SEO Brief",
}


def _prettify_title(original_title: str, original_name: str) -> str:
    """AL's #applighter-ai-blogs files have title=filename (e.g. '01-canonical.md').
    Map those to descriptive titles. RN's #ai-blogs files already have rich titles
    ('Section 1: CANONICAL BLOG POST'), so leave those untouched."""
    if original_title and not re.match(r"^\d+-[a-z\-]+\.md$", original_title, re.IGNORECASE):
        return original_title
    lname = (original_name or "").lower()
    for token, label in _AL_TITLE_MAP.items():
        if token in lname:
            return label
    return original_title or original_name


def write_distro_attachments(task_id: int, raw_variants: list) -> list:
    """Download each variant's content and stash it under
    /tmp/task-assist-T<id>/<clean-filename> so task-assist.sh can re-upload
    each to the task's thread with a preserved (or prettified) title.
    Returns an ordered manifest [{path, title, name, size}, ...]."""
    # Pin to /tmp explicitly (rather than tempfile.gettempdir() which is
    # /var/folders/... on macOS) so task-assist.sh's cleanup path matches.
    tmpdir = Path("/tmp") / f"task-assist-T{task_id}"
    tmpdir.mkdir(parents=True, exist_ok=True)
    manifest: list = []
    for i, v in enumerate(raw_variants, 1):
        url = v.get("url_private", "")
        if not url:
            continue
        content = _slack_download_file(url)
        if not content:
            continue
        original_name = v.get("name") or f"variant-{i}.md"
        # Strip any leading "NN-" that's already in the source name so we
        # don't get double-prefixed filenames like "01-01-canonical.md".
        clean_name = re.sub(r"^\d{1,3}-", "", original_name)
        path = tmpdir / f"{i:02d}-{clean_name}"
        path.write_text(content)
        manifest.append({
            "path":  str(path),
            "title": _prettify_title(v.get("title") or "", original_name),
            "name":  clean_name,
            "size":  len(content),
        })
    return manifest


def fmt_distro_article(blog: dict, product: str, n_attachments: int) -> str:
    """Concise wrapper. The full blog content lives in the file attachments
    that task-assist.sh uploads under this same thread — one per platform
    variant with its original Slack-assigned title preserved."""
    title       = blog.get("title", "(title not parsed)")
    canonical   = blog.get("canonical_url", "")
    src_thread  = blog.get("source_thread_url", "")
    blog_type   = blog.get("blog_type", "")

    lines = [f"📰 *Today's distribution: {title}*", ""]
    if canonical:
        lines.append(f"Canonical URL: <{canonical}>")
    else:
        lines.append(f"Canonical URL: _(in review — external draft only)_")
    if src_thread:
        lines.append(f"Source thread: <{src_thread}>")
    lines.append("")
    if n_attachments:
        lines.append(f"*Below: {n_attachments} platform variants* — pick the one for your target platform, adapt if needed, post from your personal account.")
    else:
        lines.append("_(no platform variants found in the source thread — click through above to grab them manually)_")
    return "\n".join(lines)


def find_recon_data(task: dict, cls: dict, recon: dict) -> Tuple[str, dict]:
    """Return (formatted_text, metadata_dict). Both may be empty if no match."""
    product = (task.get("product") or "").strip()
    assignee = (task.get("assignee") or "").strip()
    kind = cls["kind"]
    platform = cls.get("platform")

    # distro-article bypasses the recon cache — it reads live from Slack
    # source channels. All other kinds still require recon.
    if not recon and kind != "distro-article":
        return "", {"reason": "no recon cache for today", "task_id": task["id"]}

    if kind == "blog":
        blog = recon.get("blog_amplification", {})
        if not blog:
            return "", {"reason": "no blog_amplification in recon", "kind": kind}
        return fmt_blog_amp(blog, task["title"]), {
            "kind": "blog",
            "blog_url": blog.get("url"),
            "blog_title": blog.get("title"),
        }

    if kind == "distro-article":
        # Bypass recon — fetch live from the product's source blog channel.
        # Recon isn't the source of truth for distro because the source channels
        # (#ai-blogs, #applighter-ai-blogs) may be updated after the 06:00 recon fire.
        if not product:
            return "", {"reason": "task has no product; can't route distro-article", "kind": kind}
        blog = fetch_latest_distro_blog(product)
        if not blog:
            return "", {
                "reason": f"no distro blog found in source channel for product={product} (channel may be empty or scope missing)",
                "kind": kind,
                "product": product,
            }
        # Download each variant and stash under /tmp so task-assist.sh can
        # re-upload them into the task's thread, preserving titles.
        attachments = write_distro_attachments(task["id"], blog.get("raw_variants", []))
        text = fmt_distro_article(blog, product, len(attachments))
        return text, {
            "kind":              "distro-article",
            "product":           product,
            "blog_type":         blog.get("blog_type"),
            "blog_title":        blog.get("title"),
            "canonical_url":     blog.get("canonical_url"),
            "source_thread_url": blog.get("source_thread_url"),
            "attachments":       attachments,
        }

    if not product:
        return "", {"reason": "task has no product; can't scope recon", "kind": kind}
    prod_block = recon.get(product, {})
    if not prod_block:
        return "", {"reason": f"recon has no entry for product={product}", "kind": kind}

    if kind == "engagement":
        block = prod_block.get("findings", {}).get(platform, {})
        if block.get("status") != "ok":
            return "", {"reason": f"findings.{platform} not ok", "status": block.get("status"), "kind": kind}
        findings = block.get("findings", [])
        if not findings:
            return "", {"reason": f"findings.{platform} empty", "kind": kind}
        return fmt_engagement_findings(findings, platform), {
            "kind": "engagement",
            "platform": platform,
            "n_findings": len(findings),
            "urls": [f.get("url") for f in findings[:4]],
        }

    if kind == "personal":
        block = prod_block.get("original_posts", {}).get(platform, {})
        if block.get("status") != "ok":
            return "", {"reason": f"original_posts.{platform} not ok", "status": block.get("status"), "kind": kind}
        drafts = block.get("drafts", [])
        matching = [d for d in drafts if d.get("intended_for") == assignee]
        if not matching:
            return "", {"reason": f"no {platform} draft intended for {assignee}", "kind": kind, "n_drafts_total": len(drafts)}
        return fmt_personal_draft(matching[0], platform), {
            "kind": "personal",
            "platform": platform,
            "angle": matching[0].get("topic_angle"),
        }

    if kind == "article":
        tpl = cls.get("template_id", "")
        block = prod_block.get("article_drafts", {}).get(tpl, {})
        if block.get("status") != "ok":
            return "", {"reason": f"article_drafts.{tpl} not ok", "status": block.get("status"), "kind": kind}
        drafts = block.get("drafts", [])
        matching = [d for d in drafts if d.get("intended_for") == assignee]
        if not matching:
            return "", {"reason": f"no {tpl} article draft for {assignee}", "kind": kind, "n_drafts_total": len(drafts)}
        return fmt_article_draft(matching[0], platform), {
            "kind": "article",
            "platform": platform,
            "template_id": tpl,
            "topic": matching[0].get("topic"),
        }

    if kind == "quota":
        return "", {"reason": "quota tasks don't get thread suggestions (write in your own voice)", "kind": kind}

    # kind == "unknown"
    return "", {"reason": "title didn't match any known platform pattern", "kind": kind, "evidence": cls.get("evidence")}


# ─────────────────────────── MAIN ───────────────────────────


def build_assistance(task_id: int) -> dict:
    """Return {'ok': bool, 'text': str, 'metadata': dict, 'attachments': list, 'reason': str}."""
    task = load_task(task_id)
    if not task:
        return {"ok": False, "text": "", "metadata": {}, "attachments": [], "reason": f"task {task_id} not found"}

    cls = classify(task["title"])
    recon = load_recon(today_ist())
    text, meta = find_recon_data(task, cls, recon)

    # Promote attachments to top-level so task-assist.sh doesn't need to spelunk
    # into metadata to iterate. Leave a copy in metadata for the sqlite stash.
    attachments = meta.get("attachments", []) or []

    meta.update({
        "task_id": task_id,
        "task_title": task["title"],
        "classification": cls,
        "generated_at": datetime.datetime.now().isoformat(timespec="seconds"),
    })

    return {
        "ok":          True,
        "text":        text,
        "metadata":    meta,
        "attachments": attachments,
        "reason":      meta.get("reason", ""),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("task_id", type=int)
    ap.add_argument("--json", action="store_true", help="Print structured JSON instead of plain text")
    args = ap.parse_args()

    result = build_assistance(args.task_id)

    if args.json:
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 1

    # Plain-text mode: just the assistance text (may be empty).
    print(result["text"])
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
