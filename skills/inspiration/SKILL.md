---
name: inspiration
description: On-demand "next steps for this client" advisor for an agency. Resolves the active brand, reads its KPI targets and gaps, pulls recent cross-platform performance, and produces a prioritized, client-friendly "Next steps for {brand}" briefing — 5-10 concrete recommendations grouped by opportunity (scale, fix, test, creative, budget), each tied to a metric or KPI gap with an expected impact. Trigger on "next steps", "what should we do next", "what's next for {brand}", "inspiration for {brand}", "ideas for this client", "recommendations for {brand}", "how do we improve {brand}". A briefing generator only — it never executes changes or files proposals.
---

# Next Steps Advisor ("Inspiration")

Generate an opinionated, agency-facing briefing of the highest-leverage next moves for
the active brand. This skill READS data and THINKS — it produces a markdown briefing.
It does **not** change budgets, statuses, or creatives, and it does **not** file action
proposals. If the user wants to act on a recommendation, point them at the relevant
optimize/manage skill (`/adup:optimize-budget`, `/adup:google-optimize`,
`/adup:manage-status`, `/adup:create-ads`, etc.) — but only when they ask.

This is a sibling of `client-report`, not a replacement: client-report tells the client
what happened; **inspiration tells the agency what to do next.**

---

## Pre-flight — resolve the brand and gather inputs

Every step below is **optional-degrade**: if a tool is not in the tool list, or it
returns an error, or it returns an empty / `has_*: false` result, note it and CONTINUE.
Never hard-fail the briefing over one missing tool — build from whatever data resolved.

### 1. Resolve the active brand (precedence)

1. **`shop_slug` argument** — if the user named a brand or passed a slug, resolve it:
   call `list_shops`, match the name case-insensitively (partial ok; exact slug wins;
   prefer the most recent on ties; if 2+ ambiguous matches, ask which one), then use that
   slug. Pass `shop_slug="<slug>"` on every data call below.
2. **Active shop** — otherwise use the already-active shop. If none is set and the user
   named no brand, call `list_shops`; if there's exactly one, use it; if several, ask
   which client this is for before continuing.

Record the resolved **brand display name** and **slug** — the briefing is titled with the
display name and every data call carries the slug.

### 2. Read KPI targets, gaps, and the AI summary

Call `get_kpi(shop_slug="<slug>", period="<current YYYY-MM>", platform="blended")`, then
call it again per connected platform (`meta`, `google`, `tiktok`, `linkedin`, `ga4`) when
you want platform-specific targets for the scorecard.

- **`has_targets: false`** (or tool absent / error) → skip target commentary. The briefing
  still stands on recent performance alone; say targets weren't available so recommendations
  lean on trends and benchmarks instead of explicit goals.
- **`has_targets: true`** → this is the backbone of the briefing. Use:
  - **`ai_summary`** — a compiled natural-language read of where the brand stands vs goal.
    Let it seed the framing of the top recommendations.
  - **`targets[]`** — each is `{metric_key, metric_label, platform, period_type,
    period_start, target_value, target_type, unit, direction, currency, notes}`. For each
    target, compute the **gap** against the matching recent-performance number from Step 3
    and turn the biggest gaps into recommendations.
    - **Respect `direction`**: `lower_better` (CPA, CPC, CPM) → a value ABOVE target is bad
      (an opportunity to fix); `higher_better` (ROAS, revenue, CTR) → a value BELOW target
      is bad. Never recommend "fixing" a metric that's already on the good side of its goal —
      instead consider scaling it.
    - Use `target_type` (`target` / `cap` / `floor`), `unit`/`currency`, `platform`, and
      `notes` (agency-quotable context) to phrase the gap concretely.

### 3. Pull recent cross-platform performance (optional-degrade each)

Reuse the SAME aggregated `adup` MCP tools the `client-report` skill uses. Default window:
**last 30 days vs the previous 30 days** (so a trend direction is available). Pass
`shop_slug` on every call. Skip any platform that isn't connected; skip any tool that isn't
in the tool list.

**Facebook & Instagram**
```
get_campaign_performance_metrics(time_range={...}, shop_slug="<slug>")
get_ad_insights(time_range={...}, shop_slug="<slug>", metric_categories=["performance","conversion","standard_events"])
```
Campaign-level spend, impressions, link clicks, CTR, purchases, ROAS, frequency. Note rising
frequency + falling CTR (creative fatigue) and any campaign still in the optimization/learning
period (flag, don't judge).

**Google Ads**
```
get_google_ads_account_currency(shop_slug="<slug>")
get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")
```
- **CRITICAL: divide EVERY `_micros` value by 1,000,000 before using or displaying.**
- Note impression-share headroom (a strong campaign under its eligible-impression ceiling is
  a scale opportunity), campaign type (Search / Shopping / PMax / Display), and CPA vs target.

**E-commerce / GA4 (source of truth for revenue)**
```
get_ecommerce_performance(user_prompt="Revenue by traffic source", time_range={...}, format_type="table", shop_slug="<slug>")
get_user_acquisition(user_prompt="Sessions and revenue by channel", time_range={...}, shop_slug="<slug>")
```
Blended revenue and the channel mix. Blended return = GA4 revenue / total ad spend.

**Other platforms** — if `get_ecommerce_performance` / TikTok / LinkedIn aggregated tools are
present, pull them the same way; if a platform's report tools aren't available via MCP yet,
note the gap in the briefing and move on.

If the plugin exposes helper skills you can lean on for richer signal (e.g.
`ad-fatigue`, `creative-intelligence`, `budget-tracker`), you MAY reference their framing,
but do not run their side-effectful steps — this skill only reads.

---

## Step 4 — Find the opportunities

Turn the data into a ranked list of candidate moves. For each candidate, decide which of the
five **opportunity buckets** it belongs to:

| Bucket | Signal that suggests it | Example move |
|--------|------------------------|--------------|
| **Scale** | A channel/campaign beating its target with headroom (impression share <100%, ROAS above goal, CPA under cap) | Raise budget on the winner to capture more of the same |
| **Fix** | A metric on the wrong side of its KPI (CPA over cap, ROAS under floor, delivery stalled, spend wasted) | Rework targeting/bids/landing to close the gap |
| **Test** | Ambiguous or plateaued performance; an untested audience, placement, or bidding strategy | Structured A/B — new audience, new bid strategy, new placement |
| **Creative** | Rising frequency + falling CTR (fatigue), thin creative variety, one format carrying everything | Refresh creative, add a new format/angle, retire worn ads |
| **Budget** | Misallocation across channels — spend concentrated where return is weakest, or a strong channel starved | Reallocate budget from low-return to high-return channels |

Ranking rule: **largest KPI gap × spend at stake × confidence** first. A big gap on a
high-spend channel with a clear cause outranks a small gap on a tiny campaign.

Aim for **5-10** recommendations total, with a spread across buckets (don't return ten
"scale" items). If the data only supports fewer strong recommendations, return fewer —
never pad with vague filler.

---

## Step 5 — Write the briefing

Output markdown titled **`Next steps for {brand}`**. This is agency-facing, but the
**client-friendly language rules in `templates/REPORT-DESIGN-GUIDE.md` still apply** — write
so the briefing could be read aloud to the client without translation. Translate jargon
(CPA → cost per customer, ROAS → return, CTR → click-through rate, impressions → times shown,
learning phase → optimization period), frame problems as opportunities, and be specific with
numbers instead of vague ("raise Google Shopping budget 15% to capture ~90 more customers",
not "consider increasing budget"). Read `templates/REPORT-DESIGN-GUIDE.md` before writing.

### Structure

```
# Next steps for {brand}
### Advisory briefing — {today's date} · Window: {last 30 days vs previous 30}

**Where {brand} stands:** 1-2 sentences. Blended return, biggest KPI gap, and the single
most important move — seeded by get_kpi ai_summary when available.

## Priority moves

<numbered list, ranked, 5-10 items — see item format below>

## KPI scorecard
<short table: Metric | Recent | Target | Gap | Read — one row per target that drove a
recommendation. Omit entirely if has_targets:false.>

## Watch-list
<0-3 bullets: things that aren't recommendations yet but could become issues — a campaign
entering fatigue, a channel drifting toward its cap. Skip if nothing qualifies.>

## How to act on these
One line: these are recommendations only — nothing has been changed and no proposals filed.
Point to the relevant optimize/manage skill for any the user wants to pursue.
```

### Priority-move item format (every item, all four parts)

```
### N. [SCALE|FIX|TEST|CREATIVE|BUDGET] — <one-line headline of the move>
- **Why:** the rationale, tied to a specific metric or KPI gap — quote the number and the
  target. e.g. "Cost per customer is €41 vs the €25 Meta target (64% over) on the Prospecting
  campaign, which is absorbing 38% of Meta spend."
- **Do:** the concrete action, specific and quantified. e.g. "Cut Prospecting daily budget
  20% and shift it to the Retargeting campaign, which is returning €4.10 per €1 vs €2.10 here."
- **Expected impact:** the quantified outcome. e.g. "Pulls blended cost per customer back
  toward the €25 target and should recover ~€3-4K in monthly return at current volumes."
```

Every item MUST carry a bucket tag, a metric-anchored **Why**, a concrete **Do**, and an
**Expected impact**. Reuse KPI targets explicitly wherever one exists for the metric in play
("… vs €25 Meta target"). If a recommendation rests on a trend rather than a target (targets
absent), say so ("no target set — this is off the 30-day trend").

---

## Rules

1. **Briefing generator only.** Never call a `propose_*` / `create_*` / status-change /
   budget-change tool from this skill, and never file an action proposal. Read + recommend.
   v1 stops at the briefing.

2. **Resolve the brand first.** `shop_slug` argument > active shop. Ambiguous or missing →
   ask before pulling data. Carry `shop_slug` on every data call.

3. **KPI targets are the backbone.** Reuse `get_kpi` targets, gaps, and `ai_summary`
   explicitly. Respect each target's `direction` — never tell the agency to "fix" a metric
   already on the good side of its goal. If `has_targets:false`, lean on trends/benchmarks and
   say so.

4. **Optional-degrade everything.** A missing/erroring/empty tool is skipped with a note, not
   a failure. The briefing works with whatever data resolved — even KPIs alone, or performance
   alone.

5. **Client-friendly language.** Follow `templates/REPORT-DESIGN-GUIDE.md`: translate jargon,
   frame problems as opportunities, be specific and quantified. No untranslated CPA/ROAS/CTR.

6. **Google Ads micros.** ALWAYS divide `_micros` values by 1,000,000 before using them.
   Displaying raw micros is a critical error.

7. **Rank by leverage.** Largest KPI gap × spend at stake × confidence first. 5-10 items with
   a spread across buckets. Fewer strong items beats padding with filler.

8. **Every item is complete.** Bucket tag + metric-anchored Why + concrete quantified Do +
   Expected impact. No problem without a proposed move; no move without an expected outcome.

9. **Flag, don't judge, the optimization period.** Campaigns still learning (~50 conversions)
   are noted as context, not scored as failures.

10. **GA4 is the source of truth for revenue.** Blended return uses GA4 revenue over total ad
    spend; platform-reported conversions are for within-channel context only.
