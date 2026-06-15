# Collabs Tracker

Canonical list of every active and recently-closed collab. The `collabs-tuesday-update` routine reads this file every Tuesday 09:00 IST and posts a bullet-point summary to #collabs-and-partnerships (C09EY4E1X9Q).

**Edit rules for the bot:**
- Append new collabs to *Active* as they appear in #collabs-and-partnerships (emails or Sanket's notes).
- Move to *Closed* once the deliverable is shipped AND payment is settled (or the deal is dropped).
- Use ISO dates. Keep notes one-line per update — append, don't overwrite.
- Currency: USD unless noted. Amounts: what we *paid* (or quoted), not what was billed.

**Edit rules for humans:**
- Free-form anywhere. The bot will normalize on the next cron run.

---

## Active

### Shubham Wadekar (via Soxiol)
- Type: creator video — Instagram reel + story
- Amount: $259 paid
- Status: **shipped 2026-06-04, paid 2026-06-05**
- Owner: @sanket
- Reach so far: "in line with Shubham's typical reel performance" (Soxiol, 2026-06-04) — Sanket noted the reel didn't generate enough traffic
- Links:
  - Reel: https://www.instagram.com/reel/DZJ3OvXoBOh/
  - Story: https://www.instagram.com/stories/shubhaam.codes/3912055335267537801
- UTM: `utm_campaign=shubham_soxiol`
- 2026-05-25 — Sanket flagged: may bring influx of Indian devs; @suraj to consider cheaper model for India audience
- 2026-06-05 — closed; will keep eye on tail performance

### Finanzas 3.0 (Emiliano)
- Type: creator video — Instagram reel + TikTok
- Amount: $400 paid + ad codes provided
- Status: **shipped 2026-06-05, paid; ads NOT yet running**
- Owner: @sanket → looped in @russel on 2026-06-14 to manage Meta ads
- Links:
  - Reel: https://www.instagram.com/reel/DZBUw6MtpWM/
  - TikTok: https://vt.tiktok.com/ZSx7PSwdK/
- UTM: `utm_campaign=finanzas_3_0`
- Open issue: ads failing to go live — Emiliano asked what specific access we need; Russel now on it
- Note: Emiliano flagged one-off videos rarely convert without sustained content frequency

### Ibrahim El kobai (Mr Video Editor)
- Type: explainer video — main 60s + possible feature shorts
- Amount: **$650 quoted for one 60s explainer (Lovable 2.0 style)** — confirmed 2026-06-15 by Sanket
- Status: **proposal in — decision pending**
- Owner: @sanket
- Pitched bundle: 1 main 60s explainer + 4 feature shorts (idea→app, sketch→app, document→app, screenshot→app)
- Reference: mrvideoeditor.com; benchmarks Bubble + Lovable explainer videos
- Next: Sanket said "we will take a call early this week" (2026-06-14)

### Halmarr Agency (Amir Khan)
- Type: short explainer video for SaaS
- Amount: pricing/timeline requested 2026-06-14, not yet received
- Status: **inbound — awaiting quote**
- Owner: @sanket
- Past clients: Beehiiv, FinChat, Incident.io, Lovable
- Portfolio: https://halmarr.agency/

### Kobra Agency (Uliana / Julia Korolova)
- Type: TikTok organic growth (no ads), monthly pilot
- Amount: pricing pending — will be shared on call
- Status: **call to be scheduled**
- Owner: @sanket
- Pitch: organic TikTok content; reference case = Kiwi App (15M views, 55.5K followers)
- Booking link: calendly.com/olena-kondratiewa/tiktok-organic-promotion

## Closed / Dropped

_(none yet — Shubham reel will move here once we decide whether to keep watching the tail)_

---

## How the Tuesday update is structured

The cron-fired routine should post (top-level, not in a thread) a single message in C09EY4E1X9Q:

```
*Collabs update — <Tue date>*

*Shipped this week*
• <bullets>

*In motion*
• <name> — <deal> — <one-line state>

*Awaiting reply / decision*
• <name> — <what we owe them or vice versa>

*New inbound*
• <name> — <one-line pitch>

Full tracker: accountability/collabs/tracker.md
```

Keep it scannable. No paragraphs. Quote dollar amounts (these are private numbers in a private channel, but no ad codes / no API keys ever).
