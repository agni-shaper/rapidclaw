#!/usr/bin/env python3
"""daily-tasks-recon.py — live market recon for the daily distribution tasks.

Scrapes what's happening RIGHT NOW on X, LinkedIn, Reddit, Quora (logged-in bot
Chrome via browser-open.sh + browser-use eval) and HN (Algolia API), per product,
then asks `claude -p` to drop off-topic items and add a one-line engagement angle.

Output: marketing/.state/daily-recon-YYYY-MM-DD.json
  { "date":…, "status": {platform: "ok"|"login_required"|"fail: …"},
    "items": { "RN": { "x": [ {title,url,author,age,stats,angle}, … ], "linkedin": […], … }, … } }

Read-only: only opens pages and reads the DOM. Never clicks, likes, posts.
Usage: daily-tasks-recon.py [--no-rank] [--only x,reddit,...]
"""
import datetime as dt, json, os, re, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BU = os.path.expanduser("~/.browser-use-env/bin/browser-use")
OPEN = str(ROOT / "accountability/routines/browser-open.sh")
TODAY = dt.date.today()
SINCE = (TODAY - dt.timedelta(days=2)).isoformat()
OUT = ROOT / "marketing/.state" / f"daily-recon-{TODAY}.json"

# Per-product search plan. Tweak queries/subreddits here.
PRODUCTS = {
    "RN": {  # RapidNative — AI React Native app builder
        "desc": "RapidNative: AI app builder that generates React Native / Expo apps from prompts",
        "x": ['"react native" app', "expo react native", '"ai app builder" mobile'],
        "linkedin": ["react native", "ai app builder"],
        "reddit": ["reactnative", "expo", "SideProject"],
        "quora": ["react native", "build mobile app without coding"],
        "hn": ["react native", "expo"],
    },
    "AL": {  # Applighter — full-stack templates store
        "desc": "Applighter: store of full-stack app templates / boilerplates (React Native, Next.js, SaaS starters)",
        "x": ['"saas boilerplate"', '"app template" react native', "nextjs starter kit"],
        "linkedin": ["saas boilerplate", "app templates"],
        "reddit": ["SaaS", "webdev", "indiehackers"],
        "quora": ["app template", "saas starter kit", "buy app source code"],
        "hn": ["boilerplate", "starter kit"],
    },
    "LDI": {  # LetsDeployIt — mobile app deploy service
        "desc": "LetsDeployIt: service that builds and ships mobile apps to the App Store / Play Store for you",
        "x": ["testflight", '"app store" rejected', '"eas build"'],
        "linkedin": ["app store submission", "mobile app deployment"],
        "reddit": ["iOSProgramming", "androiddev", "FlutterDev"],
        "quora": ["publish iOS app", "app store review", "Google Play app rejected"],
        "hn": ["app store review", "testflight"],
    },
}

JS = {
"x": r"""JSON.stringify([...document.querySelectorAll('article')].map(a=>{
  const t=a.querySelector('time'); const l=t&&t.closest('a');
  const like=a.querySelector('[data-testid="like"],[data-testid="unlike"]');
  const rep=a.querySelector('[data-testid="reply"]');
  return {url:l?l.href:'', iso:t?t.getAttribute('datetime'):'',
    text:(a.querySelector('[data-testid="tweetText"]')||{}).innerText||'',
    likes:like?(like.getAttribute('aria-label')||''):'', replies:rep?(rep.getAttribute('aria-label')||''):''};
}).filter(x=>x.url&&x.text))""",
"linkedin": r"""JSON.stringify(document.body.innerText.split(/\nFeed post\n/).slice(1).map(c=>{
  const L=c.split('\n').map(s=>s.trim()).filter(Boolean);
  const ti=L.findIndex(s=>/^\d+(m|h|d|w|mo|yr)( •.*)?$/.test(s));
  const body=L.slice(ti+1).filter(s=>!/^(Follow|Connect|…more|Like|Comment|Repost|Send)$/.test(s));
  return {author:L[0]||'', age:(L[ti]||'').split(' ')[0], text:body.slice(0,8).join(' ').slice(0,400),
          stats:(L.find(s=>/\d+ (reactions?|comments?)/.test(s))||'')};
}).filter(x=>x.text))""",
"reddit": r"""JSON.stringify([...document.querySelectorAll('div.thing.link')].map(t=>({
  title:(t.querySelector('a.title')||{}).innerText||'', url:'https://www.reddit.com'+t.dataset.permalink,
  ts:+t.dataset.timestamp, comments:+t.dataset.commentsCount, score:+(t.dataset.score||0),
  sub:t.dataset.subreddit, stickied:t.classList.contains('stickied')})))""",
"quora": r"""JSON.stringify({wall:!!document.querySelector('input[type=password]')||location.pathname==='/',
  qs:[...new Map([...document.querySelectorAll('a')].map(a=>[a.href.split('?')[0],a.innerText.trim()])
     .filter(([h,t])=>/^https:\/\/www\.quora\.com\/(unanswered\/)?[^\/#]+$/.test(h)&&t.endsWith('?'))).entries()]})""",
}

HIRING = re.compile(r"\b(hiring|we.?re hiring|job (title|opening)|resume|cv\b|apply now|vacanc|looking for (a|an) .{0,30}(developer|engineer)|years? of experience|#jobs?|recruit)", re.I)


def log(*a):
    print(f"[{dt.datetime.now():%H:%M:%S}]", *a, file=sys.stderr, flush=True)


def _same_page(a, b):
    """True if tab URL `a` is the page we requested as `b` (host + path + query values, encoding-insensitive)."""
    pa, pb = urllib.parse.urlsplit(a), urllib.parse.urlsplit(b)
    if pa.netloc != pb.netloc or pa.path.rstrip("/") != pb.path.rstrip("/"):
        return False
    qa, qb = urllib.parse.parse_qs(pa.query), urllib.parse.parse_qs(pb.query)
    return all(qa.get(k) == v for k, v in qb.items() if k in ("q", "keywords"))


def _tabs():
    out = subprocess.run([BU, "tab", "list"], capture_output=True, text=True, timeout=30).stdout
    return [(int(m.group(1)), m.group(2)) for m in re.finditer(r"^\s*(\d+)\s+(\S+)", out, re.M)]


def scrape(url, js, wait=7):
    """Open url in a new bot-Chrome tab, eval js IN THAT TAB, close THAT tab."""
    r = subprocess.run([OPEN, url], capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError(f"browser-open rc={r.returncode}: {r.stderr.strip()[-200:]}")
    time.sleep(wait)
    mine = [i for i, u in _tabs() if _same_page(u, url)]
    if not mine:
        raise RuntimeError(f"opened tab not found for {url}")
    idx = mine[-1]                                     # newest matching tab
    try:
        subprocess.run([BU, "tab", "switch", str(idx)], capture_output=True, timeout=30)
        out = subprocess.run([BU, "eval", js], capture_output=True, text=True, timeout=60).stdout
        out = re.sub(r"^result:\s*", "", out.strip())
        return json.loads(out) if out else None
    finally:
        subprocess.run([BU, "tab", "close", str(idx)], capture_output=True, timeout=30)
        # sweep any stragglers for this exact page left by earlier runs
        for i, u in sorted(_tabs(), reverse=True):
            if _same_page(u, url):
                subprocess.run([BU, "tab", "close", str(i)], capture_output=True, timeout=30)


def ago(seconds):
    h = seconds / 3600
    return f"{int(seconds/60)}m" if h < 1 else (f"{int(h)}h" if h < 48 else f"{int(h/24)}d")


def num(label):
    m = re.search(r"([\d,.]+)\s*([KkMm])?", label or "")
    if not m: return 0
    n = float(m.group(1).replace(",", ""))
    return int(n * (1000 if (m.group(2) or "").lower() == "k" else 1_000_000 if (m.group(2) or "").lower() == "m" else 1))


def do_x(p, cfg):
    items, seen = [], set()
    for q in cfg["x"]:
        url = "https://x.com/search?" + urllib.parse.urlencode({"q": f"{q} since:{SINCE} -filter:replies lang:en", "src": "typed_query", "f": "top"})
        for t in scrape(url, JS["x"], wait=8) or []:
            u = t["url"].split("/analytics")[0]
            if u in seen: continue
            seen.add(u)
            age = ago((dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(t["iso"].replace("Z", "+00:00"))).total_seconds()) if t["iso"] else ""
            items.append({"title": t["text"][:280], "url": u, "author": "@" + u.split("/")[3], "age": age,
                          "stats": f"{num(t['likes'])} likes · {num(t['replies'])} replies", "_score": num(t["likes"]) + 3 * num(t["replies"])})
    return sorted(items, key=lambda x: -x["_score"])


def do_linkedin(p, cfg):
    items, seen = [], set()
    for q in cfg["linkedin"]:
        url = "https://www.linkedin.com/search/results/content/?" + urllib.parse.urlencode({"keywords": q, "sortBy": '"date_posted"'})
        for t in scrape(url, JS["linkedin"], wait=9) or []:
            if HIRING.search(t["text"]) or t["text"][:60] in seen: continue
            seen.add(t["text"][:60])
            words = re.sub(r"[^\w\s']", " ", t["text"]).split()[:9]
            find = "https://www.linkedin.com/search/results/content/?" + urllib.parse.urlencode({"keywords": '"' + " ".join(words) + '"'})
            items.append({"title": t["text"][:280], "url": find, "author": t["author"], "age": t["age"], "stats": t["stats"]})
    return items


def do_reddit(p, cfg):
    items, now = [], time.time()
    for sub in cfg["reddit"]:
        for t in scrape(f"https://old.reddit.com/r/{sub}/new/", JS["reddit"], wait=5) or []:
            age_s = now - t["ts"] / 1000
            if t["stickied"] or age_s > 48 * 3600 or not t["title"]: continue
            items.append({"title": t["title"], "url": t["url"], "author": f"r/{t['sub']}", "age": ago(age_s),
                          "stats": f"{t['comments']} comments · {t['score']} upvotes", "_score": t["comments"] * 2 + t["score"]})
    return sorted(items, key=lambda x: -x["_score"])


def do_quora(p, cfg):
    items = []
    seen = set()
    for q in cfg["quora"]:
        for tf, age in (("month", "≤30d"), (None, "")):   # niche queries: fall back to all-time if month is thin
            params = {"q": q, "type": "question", **({"time": tf} if tf else {})}
            r = scrape("https://www.quora.com/search?" + urllib.parse.urlencode(params), JS["quora"], wait=9) or {}
            if r.get("wall"):
                raise PermissionError("login_required")
            qs = [(u, t) for u, t in r.get("qs", []) if u not in seen]
            for u, t in qs:
                seen.add(u)
                items.append({"title": t, "url": u, "author": "Quora · unanswered" if "/unanswered/" in u else "Quora", "age": age, "stats": ""})
            if len(qs) >= 4:
                break
    return items


def do_hn(p, cfg):
    items, since = [], int(time.time() - 7 * 86400)
    for q in cfg["hn"]:
        u = "https://hn.algolia.com/api/v1/search_by_date?" + urllib.parse.urlencode({"query": q, "tags": "story", "numericFilters": f"created_at_i>{since}", "hitsPerPage": 15})
        for h in json.load(urllib.request.urlopen(u, timeout=20)).get("hits", []):
            items.append({"title": h.get("title") or "", "url": f"https://news.ycombinator.com/item?id={h['objectID']}",
                          "author": h.get("author", ""), "age": ago(time.time() - h["created_at_i"]),
                          "stats": f"{h.get('points',0)} points · {h.get('num_comments',0)} comments", "_score": (h.get("points") or 0) + 2 * (h.get("num_comments") or 0)})
    return sorted(items, key=lambda x: -x["_score"])


SCRAPERS = {"x": do_x, "linkedin": do_linkedin, "reddit": do_reddit, "quora": do_quora, "hn": do_hn}


def rank(raw):
    """One claude -p pass: drop off-topic items, keep best ≤8 per product×platform, add an angle."""
    slim = {p: {pl: [{"i": i, "title": it["title"][:240], "author": it["author"], "stats": it["stats"]} for i, it in enumerate(lst[:25])]
                for pl, lst in plats.items()} for p, plats in raw.items()}
    prompt = (
        "You filter live social threads for a small dev-tools company's daily engagement tasks.\n"
        "Products:\n" + "\n".join(f"- {k}: {v['desc']}" for k, v in PRODUCTS.items()) +
        "\n\nFor EACH product and platform below, keep up to 8 items a team member could genuinely engage with "
        "(relevant to that product's audience/problem space; real discussion or question; not spam, not job posts, "
        "not crypto, not unrelated). For each kept item write `angle`: ONE short sentence (max 25 words) on what a helpful, "
        "non-promotional reply/answer would add. Never mention the product name in the angle.\n"
        "Return ONLY JSON shaped {\"RN\": {\"x\": [{\"i\": <index>, \"angle\": \"…\"}], …}, …}. No prose.\n\n"
        + json.dumps(slim, ensure_ascii=False))
    claude = os.path.expanduser("~/.local/bin/claude")
    r = subprocess.run([claude, "-p", "--output-format", "text"], input=prompt, capture_output=True, text=True, timeout=600)
    m = re.search(r"\{.*\}", r.stdout, re.S)
    picks = json.loads(m.group(0))
    out = {}
    for p, plats in raw.items():
        out[p] = {}
        for pl, lst in plats.items():
            chosen = []
            for k in picks.get(p, {}).get(pl, []):
                if isinstance(k, dict) and isinstance(k.get("i"), int) and k["i"] < len(lst):
                    it = dict(lst[k["i"]]); it["angle"] = k.get("angle", ""); chosen.append(it)
            out[p][pl] = chosen
    return out


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    raw, status = {p: {} for p in PRODUCTS}, {}
    for pl, fn in SCRAPERS.items():
        if only and pl not in only: continue
        status[pl] = "ok"
        for p, cfg in PRODUCTS.items():
            try:
                raw[p][pl] = fn(p, cfg)
                log(f"{pl:8} {p:3} {len(raw[p][pl])} items")
            except PermissionError:
                status[pl] = "login_required"; raw[p][pl] = []
                log(f"{pl:8} login wall — log into {pl} once in the bot Chrome window"); break
            except Exception as e:  # keep going on other platforms
                status[pl] = f"fail: {str(e)[:120]}"; raw[p][pl] = []
                log(f"{pl:8} {p:3} FAIL {e}")
        for p in PRODUCTS: raw[p].setdefault(pl, [])
    items = raw
    if "--no-rank" not in sys.argv:
        try:
            items = rank(raw); log("ranked via claude -p")
        except Exception as e:
            log(f"rank step failed ({e}); keeping top raw items unranked")
            items = {p: {pl: lst[:8] for pl, lst in plats.items()} for p, plats in raw.items()}
    for plats in items.values():
        for lst in plats.values():
            for it in lst: it.pop("_score", None)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"date": str(TODAY), "generated": dt.datetime.now().isoformat(timespec="seconds"),
                               "status": status, "items": items}, ensure_ascii=False, indent=1))
    print(OUT)
    for p, plats in items.items():
        print(p, {pl: len(v) for pl, v in plats.items()})
    print("status", status)


if __name__ == "__main__":
    main()
