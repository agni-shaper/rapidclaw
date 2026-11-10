#!/usr/bin/env python3
"""daily-tasks-post.py — post the daily distribution tasks + a Task-Assistance-Bot
thread reply under each one, using today's live recon.

Inputs:
  marketing/daily-tasks-crew.md              active crew + persona groups (# = paused)
  marketing/daily-tasks-assist-templates.json static help text per PRODUCT|task-kind
  marketing/.state/daily-recon-YYYY-MM-DD.json  live threads (daily-tasks-recon.py)
Posts to #rn-coach-social. Task IDs continue from marketing/.state/daily-tasks-counter.

Usage: daily-tasks-post.py [--dry-run] [--force] [--channel C…]
"""
import datetime as dt, json, os, re, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "marketing/.state"
TODAY = dt.date.today()
CHANNEL = sys.argv[sys.argv.index("--channel") + 1] if "--channel" in sys.argv else "C0B6Q8TUVL2"  # #rn-coach-social
DRY = "--dry-run" in sys.argv
PRODUCTS = ["RN", "AL", "LDI"]                       # tinbase closed 2026-11-05
SLUG = {"RN": "rapidnative", "AL": "applighter", "LDI": "letsdeployit"}
PLATFORM_NAME = {"x": "X", "linkedin": "LinkedIn", "reddit": "Reddit", "quora": "Quora", "hn": "Hacker News"}

BLOG = {  # "Distribute today's blog" — latest post per product
    "RN": ("How an OS in the browser saved us $10K+ on sandboxes",
           "https://www.rapidnative.com/blogs/how-building-an-os-in-the-browser-saved-us-on-sandboxes"),
    "AL": ("Artificial Intelligence UX Design: Principles and Patterns",
           "https://www.applighter.com/blog/artificial-intelligence-ux-design"),
}

# Weekday task sets per product. {G}=main persona group, {A}=posting persona, {Q}=quora group, {W}=week label
# Rebuilt from the Oct 2026 history (w2/w3-October) + engagement fill to 9 kinds/product/day.
_LI_POST = "LinkedIn ({G}) Post from LinkedIn account (from personal accounts)"
_X_POST = "Twitter ({G}) Post from Twitter account (from personal accounts)"
_W6 = "Write 6 articles for Distribution"
_ENG = lambda plat, grp="G": f"{plat} community engagement - ({{{grp}}} for {{W}})"
_MON_FRI = [
    "Submit 1 article to GeeksForGeeks from {A} account - ({G} for {W})",
    "Hackernews community postings using {A} account - ({G} for {W})",
    _ENG("Hackernews"), _W6, _LI_POST, _X_POST,
    _ENG("Reddit"), _ENG("Quora", "Q"), _ENG("LinkedIn"),
]
DAY_TASKS = {
    0: _MON_FRI,                                      # Monday
    1: [                                              # Tuesday
        "Submit 1 article to Medium from {A} account - ({G} for {W})",
        "Reddit community postings using {A} account - ({G} for {W})",
        _ENG("Reddit"), _W6, _X_POST, _LI_POST,
        _ENG("Quora", "Q"), _ENG("LinkedIn"), _ENG("Community forums"),
    ],
    2: [                                              # Wednesday
        "Submit 1 article to <http://dev.to|dev.to> from {A} account - ({G} for {W})",
        "Quora community postings using {A} account - ({Q} for {W})",
        _ENG("Quora", "Q"), _W6, _LI_POST, _X_POST,
        _ENG("Reddit"), _ENG("LinkedIn"), _ENG("Community forums"),
    ],
    3: [                                              # Thursday
        _ENG("Community forums"),
        "Facebook community postings using {A} account - ({G} for {W})",
        "Quora ({Q}) Post from Quora account (from personal accounts)",
        "Submit 1 article to Hashnode from {A} account - ({G} for {W})",
        _X_POST, _W6,
        _ENG("Reddit"), _ENG("LinkedIn"), _ENG("Quora", "Q"),
    ],
    4: _MON_FRI,                                      # Friday
}
EXTRA = [("RN", "Distribute today's blog to a platform of choice"),
         ("AL", "Distribute today's blog to a platform of choice"),
         ("RN", "Create a Free Tool")]

# task kind -> live platforms to pull threads from (in order)
LIVE = {
    "Community forums community engagement": ["hn", "reddit"],
    "Reddit community engagement": ["reddit"],
    "LinkedIn community engagement": ["linkedin"],
    "Quora community engagement": ["quora"],
    "Quora  Post": ["quora"],
    "Twitter  Post": ["x"],
    "LinkedIn  Post": ["linkedin"],
    "Hackernews community engagement": ["hn"],
    "Hackernews community postings": ["hn"],
    "Reddit community postings": ["reddit"],
    "Quora community postings": ["quora"],
}
PER_TASK = 3


BLOG_INDEX = {"RN": ("https://www.rapidnative.com/blogs", r'href="(/blogs/[a-z0-9-]{6,})"', "https://www.rapidnative.com"),
              "AL": ("https://www.applighter.com/blog", r'href="(/blog/[a-z0-9-]{6,})"', "https://www.applighter.com")}


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (rapidnative-coach daily-tasks)"})
    return urllib.request.urlopen(req, timeout=20).read().decode("utf-8", "replace")


def refresh_blogs():
    """Point 'Distribute today's blog' at the newest post on each blog index (keeps the default on failure)."""
    for prod, (index, pat, base) in BLOG_INDEX.items():
        try:
            path = re.search(pat, _get(index)).group(1)
            title = re.search(r"<title>([^<|]+)", _get(base + path)).group(1).strip()
            BLOG[prod] = (title, base + path)
        except Exception as e:
            print(f"blog refresh {prod} failed ({e}); using default")


def kind_of(text):
    return re.sub(r" using \S+ account| from \S+ account| - \(.*\)|\(.*?\)", "", text).strip()


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("|", "¦")


def load_crew():
    crew = []
    for line in (ROOT / "marketing/daily-tasks-crew.md").read_text().splitlines():
        m = re.match(r"^(U[A-Z0-9]{8,})\s*\|\s*(\S+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*$", line)
        if m: crew.append(m.groups())
    return crew


def patch(r):
    r = re.sub(r"Recon drafted a personal (\w+) post for @\w+ today\. To avoid several personas posting the same thing, YOU draft from a different topic:",
               "To avoid several personas posting the same thing, pick a topic your teammates aren't using:", r)
    r = re.sub(r"Recon drafted one full (\w+) article for @\w+ today\. To avoid several crews publishing the same topic, YOU pick",
               "To avoid several crews publishing the same topic, pick", r)
    r = re.sub(r" — not @\w+'s\.", " — not a teammate's.", r)
    r = re.sub(r":warning: \*[^*]*(?:unavailable|No fresh)[^*]*\*[^\n]*\n*", "", r)
    return r


class Pool:
    """Hands out live threads per product×platform without repeats until exhausted."""
    def __init__(self, recon):
        self.items = recon.get("items", {}) if recon else {}
        self.status = recon.get("status", {}) if recon else {}
        self.gen = recon.get("generated", "") if recon else ""
        self.ptr = {}

    def take(self, prod, plat, n):
        lst = self.items.get(prod, {}).get(plat, [])
        if not lst: return []
        k = (prod, plat); i = self.ptr.get(k, 0); self.ptr[k] = i + n
        return [lst[(i + j) % len(lst)] for j in range(min(n, len(lst)))]


def live_block(pool, prod, plats, persona):
    got = []
    per = [PER_TASK - (len(plats) - 1)] + [1] * (len(plats) - 1) if len(plats) > 1 else [PER_TASK]
    for plat, n in zip(plats, per):
        got += [(plat, it) for it in pool.take(prod, plat, n)]
    if len(got) < PER_TASK:  # top up from any platform in the list that still has items
        for plat in plats:
            got += [(plat, it) for it in pool.take(prod, plat, PER_TASK - len(got))]
            if len(got) >= PER_TASK: break
    if not got:
        why = "; ".join(f"{PLATFORM_NAME[p]}: {pool.status.get(p, 'not scraped')}" for p in plats)
        return None, why
    when = pool.gen[11:16] if pool.gen else ""
    lines = [f":satellite_antenna: *Live right now* — {len(got)} fresh thread{'s' * (len(got) > 1)} (recon {when} IST)\n"]
    for i, (plat, it) in enumerate(got, 1):
        meta = " · ".join(x for x in [PLATFORM_NAME[plat], it.get("author", ""), it.get("age", ""), it.get("stats", "")] if x)
        title = esc(re.sub(r"\s+", " ", it["title"]))[:200]
        lines.append(f"*{i}.* <{it['url']}|{title}>\n      {esc(meta)}")
        if it.get("angle"): lines.append(f"      _Angle:_ {esc(it['angle'])}")
    return "\n".join(lines), None


def topic_pool(template):
    m = re.search(r"\*(?:Product topic pool|Topic pool for this product)\*[^\n]*\n((?:\s+•[^\n]*\n?)+)", template or "")
    return m.group(1).rstrip() if m else ""


def build_reply(tid, prod, text, persona, tpl, pool):
    k = kind_of(text)
    head = f":robot_face: *Task-Assistance-Bot* — for {tid}\n\n"
    foot = f"\n\n_{SLUG[prod]} · marketing_"
    if k.startswith("Distribute today's blog"):
        title, url = BLOG[prod]
        return head + (f":newspaper: *Today's distribution: {title}*\n\nCanonical URL: <{url}?utm_source=distribution&utm_medium=social>\n\n"
                       "Pick ONE platform you haven't used this week (LinkedIn / X / Reddit / dev.to / Hashnode / Medium / Quora), "
                       "write a native 2–4 line intro in your persona's voice with one concrete takeaway, and link the canonical URL.\n\n"
                       "_Summarise + link, don't paste the article. Reply here with the live URL once posted._") + foot
    plats = LIVE.get(k)
    if plats:
        block, why = live_block(pool, prod, plats, persona)
        if block:
            if k == "Twitter  Post":
                tp = topic_pool(tpl)
                guide = (f"These are the conversations moving on X in this space. Write your OWN post (not a reply) from your persona account, "
                         f"riffing on one of them with a concrete take." + (f"\n\n*Topic pool if none fit:*\n{tp}" if tp else ""))
            elif k == "Quora  Post":
                guide = f"Answer ONE of these live questions from a {persona} account — real experience, specifics, no product pitch in the first lines."
            elif k == "LinkedIn  Post":
                guide = "These are the live LinkedIn conversations in this space. Write your own post from your persona account on one of these themes."
            else:
                guide = f"Pick 1–2 and leave a substantive comment from your persona account ({persona}). Add context or answer the question — no drive-by promo."
            return head + block + "\n\n" + guide + "\n\n_Reply in this thread with your post/comment links when done._" + foot
        body = patch(tpl) if tpl else head + "_No template for this task._"
        note = f":warning: *Live recon unavailable* — {why}. Browse these instead:\n\n"
        body = re.sub(r"(— for T\d+\n\n)", lambda m: m.group(1) + note, body, count=1)
        return re.sub(r"for T\d+", f"for {tid}", body, count=1)
    body = patch(tpl) if tpl else head + f":memo: *{k}*\n\nNo assist template yet for this task." + foot
    return re.sub(r"for T\d+", f"for {tid}", body, count=1)


def slack(method, payload):
    tok = (Path.home() / ".config/claude/rapidnative-coach-slack-bot-token").read_text().strip()
    for _ in range(6):
        req = urllib.request.Request(f"https://slack.com/api/{method}", data=json.dumps(payload).encode(),
                                     headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json; charset=utf-8"})
        r = json.load(urllib.request.urlopen(req, timeout=30))
        if r.get("error") == "ratelimited": time.sleep(5); continue
        return r
    return r


def main():
    wd = TODAY.weekday()
    tasks_today = DAY_TASKS.get(wd)
    if not tasks_today:
        print(f"no task set for weekday {wd} (weekend) — nothing to post"); return
    refresh_blogs()
    week = f"w{(TODAY.day - 1) // 7 + 1}-{TODAY:%B}"
    sentinel = STATE / f"daily-tasks-posted-{TODAY}.json"
    if sentinel.exists() and "--force" not in sys.argv and not DRY:
        print(f"already posted today ({sentinel}); use --force"); return
    recon_f = STATE / f"daily-recon-{TODAY}.json"
    recon = json.loads(recon_f.read_text()) if recon_f.exists() else None
    pool = Pool(recon)
    tpls = json.loads((ROOT / "marketing/daily-tasks-assist-templates.json").read_text())
    counter_f = STATE / "daily-tasks-counter"
    n = int(counter_f.read_text()) if counter_f.exists() else 8867
    crew = load_crew()

    plan = []
    for uid, handle, G, Q in crew:
        A = G.split(", ")[-1]
        for prod in PRODUCTS:
            for t in tasks_today:
                plan.append((uid, prod, t.format(G=G, A=A, Q=Q, W=week), A))
        for prod, t in EXTRA:
            plan.append((uid, prod, t, A))
    print(f"{len(crew)} crew · {len(plan)} tasks · recon={'yes' if recon else 'MISSING'} {pool.status}")

    posted = fail = live = 0
    if not DRY:
        slack("chat.postMessage", {"channel": CHANNEL, "text":
              f":clipboard: *Daily distribution tasks* · {TODAY:%a %d %b} · {len(crew)} members × {len(plan)//max(len(crew),1)} tasks · RN / AL / LDI\n"
              f"Each task has a :robot_face: thread with live threads from today's recon. Recon status: "
              + ", ".join(f"{PLATFORM_NAME.get(k,k)} {'✅' if v == 'ok' else '⚠️ ' + v}" for k, v in pool.status.items())})
    for uid, prod, text, persona in plan:
        tid = f"T{n}"; n += 1
        msg = f"New task [{tid}] [{prod}] → <@{uid}> · due {TODAY} · normal · {text}"
        reply = build_reply(tid, prod, text, persona, tpls.get(f"{prod}|{kind_of(text)}"), pool)
        live += ":satellite_antenna:" in reply
        if DRY:
            print("\n" + msg + "\n" + reply) if "--verbose" in sys.argv else None
            continue
        r = slack("chat.postMessage", {"channel": CHANNEL, "text": msg})
        if not r.get("ok"): fail += 1; print("FAIL task", tid, r.get("error")); continue
        time.sleep(1.1)
        r2 = slack("chat.postMessage", {"channel": CHANNEL, "thread_ts": r["ts"], "text": reply, "unfurl_links": False, "unfurl_media": False})
        if not r2.get("ok"): fail += 1; print("FAIL reply", tid, r2.get("error"))
        posted += 1; time.sleep(1.1)
    if not DRY:
        counter_f.write_text(str(n))
        sentinel.write_text(json.dumps({"posted": posted, "failed": fail, "live_replies": live, "last_id": f"T{n-1}"}))
    print(f"tasks posted={posted} failed={fail} replies_with_live_threads={live}/{len(plan)}")


if __name__ == "__main__":
    main()
