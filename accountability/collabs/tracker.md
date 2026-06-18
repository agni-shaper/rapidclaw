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
- Status: **shipped 2026-06-05, paid; ad access resolved 2026-06-18 — ads ready to run**
- Owner: @sanket → looped in @russel on 2026-06-14 to manage Meta ads
- Links:
  - Reel: https://www.instagram.com/reel/DZBUw6MtpWM/
  - TikTok: https://vt.tiktok.com/ZSx7PSwdK/
- UTM: `utm_campaign=finanzas_3_0`
- 2026-06-18 — Sanket confirmed Finanzas access obtained; Russel can now launch Meta ads
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

### PilloleBar (TikTok)
- Type: creator video — TikTok short-form / viral storytelling page
- Amount: not yet discussed
- Status: **inbound — Sanket asked qualifier, awaiting reply**
- Owner: @sanket
- Pitch: 7M monthly views, curiosity-based viral content
- Source: support@rapidnative.com Partnership form, 2026-06-15
- 2026-06-18 — Sanket replied: prior creator collabs didn't work, asked what's different here

## Closed / Dropped

### Taha Anwar (BleedAI / BleedConnections) — dropped 2026-06-18
- Type: cold outbound campaign — funded-founder targeting; PRD-style strategy doc delivered
- Pitch: 25,850 reachable funded software founders (seed–Series A, 1–50 employees) via Prospeo, sliced into 7 sub-segments
- Doc: https://drive.google.com/file/d/1PRTIuZaAOjgWSx1JLiH2PCup0lTTPCRi/view (shared 2026-06-15)
- 2026-06-18 — Taha quoted $1.1K USD, over budget; Sanket dropping outsourced route and standing up in-house cold outbound team instead. Follow-up: [[inhouse-cold-outbound-team]] (P1, @sanket, sprint W24)

### Kobra Agency (Uliana / Julia Korolova) — dropped 2026-06-18
- Type: TikTok organic growth (no ads), monthly pilot
- Pitch: organic TikTok content; reference case = Kiwi App (15M views, 55.5K followers)
- Booking link: calendly.com/olena-kondratiewa/tiktok-organic-promotion
- 2026-06-18 — Sanket cancelled the call

_(Shubham reel still in Active for now — pending decision on whether to keep watching the tail)_

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
