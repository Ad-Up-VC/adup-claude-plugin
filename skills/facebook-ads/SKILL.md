---
name: facebook-ads
description: Analyse Facebook and Instagram ad performance using Meta-native analytical frameworks. Covers campaigns, ROAS, conversion funnel, learning phase diagnosis, breakdown effect, relevance diagnostics, creative fatigue, and audience breakdowns.
---

# Facebook Ads Analysis

## Pre-flight
- Confirm shop context for agency accounts (use `set_shop_context` if not already set)
- Default to last 30 days if no date range specified — state the assumption
- Facebook monetary values are in account currency (not micros — no conversion needed)
- Always call `get_recommendations` before finalising recommendations — align with Meta's own suggestions or explicitly explain any divergence

---

## ⚠️ Mandatory Analysis Rules — Never Break These

### 1. The Breakdown Effect — CRITICAL
**NEVER recommend pausing or reducing budget for a segment based solely on higher average CPA/CPM in breakdown reports.**

Why: Meta's system optimises for **marginal CPA** (the cost of the *next* result), not average CPA. A segment showing high average CPA may still be the cheapest source of incremental conversions. Removing it forces the system to find results in more expensive territory, raising total costs.

**Always:**
- Evaluate aggregate performance first (campaign or ad set level), then use breakdowns for context only
- Infer marginal CPA trends from time-series data, not single-period averages
- Frame changes as testable hypotheses ("test pausing this segment"), never as directives

**Example framing:**
> "While the 45–54 age group shows €18 average CPA vs €12 overall, time-series data shows the 25–34 group's CPA rising sharply week-over-week. The system may be correctly shifting budget toward 45–54 as marginal costs shift. Test, don't cut."

---

### 2. Correct Evaluation Level

| Campaign Setup | Evaluate At |
|---|---|
| Advantage+ Campaign Budget (CBO) | **Campaign level** |
| Automatic Placements (no CBO) | **Ad set level** |
| Multiple ads within one ad set | **Ad set level** |

Never compare ad set performance inside a CBO campaign and conclude one ad set is "underperforming" — the budget controller is the campaign.

---

### 3. Learning Phase — Do Not Judge or Change
If any ad set status is **"Learning"** or **"Learning Limited"**:
- Do not make definitive performance judgments on that ad set
- Do not recommend edits (each significant edit resets the learning clock)
- Ad sets need ~50 optimisation events within 7 days to exit learning
- Flag clearly in output, recommend patience

**Learning Limited** = insufficient budget or audience to ever exit learning. Recommend consolidating ad sets or increasing budget.

---

### 4. Click Disambiguation — Always Be Precise
**Never say "clicks" alone.**

| Term | Meaning |
|---|---|
| **Clicks (all)** | All interactions: likes, shares, link clicks, page clicks |
| **Link Clicks** | Clicks that take the user to the destination URL |

These are completely different metrics. CTR on Link Clicks is always lower than CTR on Clicks (all).

---

### 5. Qualified Language
Meta metrics are modelled estimates, not exact counts.

| Instead of | Say |
|---|---|
| "You reached 45,000 people" | "Estimated reach of ~45,000" |
| "5 conversions" | "Estimated 5 conversions" |
| "Your CTR is 1.8%" | "Estimated CTR of approximately 1.8%" |

---

## Key Tools

**Campaign overview:**
```
get_campaign_performance_metrics(
  time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}
)
```
Returns: spend, impressions, link clicks, CTR, CPC, purchases, ROAS per campaign.

**Full metrics with conversions:**
```
get_ad_insights(
  time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"},
  campaign_id="<id_if_known>"
)
```

**Conversion funnel (ViewContent → Purchase):**
```
analyze_standard_events_funnel(
  time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}
)
```
Shows drop-off rates at each funnel stage.

**Video performance:**
```
analyze_video_performance(
  time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}
)
```

**Ad set details (learning phase + budget check):**
```
get_adsets(campaign_id="<id>")
```
Use this to check status, daily budget, and targeting for each ad set.

**Meta's own recommendations:**
```
get_recommendations(ad_account_id="act_<id>")
```
Always call before finalising — surface these to the user and align.

---

## Analysis Workflow

### Step 1 — Identify evaluation level
CBO campaign? → Evaluate at campaign level.
Non-CBO? → Evaluate at ad set level.

### Step 2 — Check learning phase status
Pull ad sets with `get_adsets`. Flag any in Learning/Learning Limited before proceeding. Exclude from performance judgments.

### Step 3 — Evaluate aggregate performance
Pull campaign-level metrics first. Get total spend, ROAS, purchase volume, link click CTR. Form a view of overall health before drilling down.

### Step 4 — Check relevance diagnostics (for underperforming ads)

| Ranking | Likely Root Cause | Action |
|---|---|---|
| Low Quality Ranking | Creative perceived as low quality or clickbait | Refresh creative, reduce sensationalism |
| Low Engagement Ranking | Ad not compelling enough to click | Test new angles, stronger hook |
| Low Conversion Ranking | Post-click experience failing | Optimise landing page, check audience-offer fit |
| All three low | Audience-creative fundamental mismatch | Reconsider targeting strategy and creative together |

Relevance diagnostics require ≥500 impressions to be available.

### Step 5 — Apply breakdown context (not as a cutting guide)
Use breakdowns (age, gender, placement, device) to understand system decisions — not to remove segments. Explain what you see through the Breakdown Effect lens.

### Step 6 — Check auction signals
- **Auction overlap** — multiple ad sets targeting the same audience; Meta picks the winner and excludes others. Result: wasted budget, prevented learning exit. Fix: consolidate ad sets.
- **Low total auction value** — low delivery despite reasonable bid indicates low estimated action rate or ad quality, not low bid. Fix: creative quality, not higher bids.

### Step 7 — Check Meta recommendations
Call `get_recommendations`. Surface them. If you diverge from any, explain why explicitly.

### Step 8 — Evaluate over correct time window
- Stable ad sets: minimum 7 days. Single-day snapshots are noise.
- Learning phase ad sets: exclude entirely.
- Weekend vs. weekday variance (up to 30%) is normal and expected.

---

## Output Format

```
## Facebook Ads — [Shop] | [Date Range]

| Campaign | Spend | Impressions | Link Clicks | CTR | CPC | Purchases | ROAS | Status |
|----------|-------|-------------|-------------|-----|-----|-----------|------|--------|
| Summer Sale | €4,231 | 892K | 12,400 | 1.39% | €0.34 | 187 | 3.8x | Active |
| Brand Awareness | €2,108 | 1.24M | 6,200 | 0.50% | €0.34 | — | — | 🔄 Learning |

**Total**: €6,339 spend | ~187 estimated purchases | Blended ROAS: 3.1x

### ⚠️ Learning Phase Alert
- Brand Awareness is in Learning phase — performance data not yet reliable. Avoid all edits until it exits (~50 purchases needed within 7 days).

### Insights
1. Summer Sale ROAS 3.8x — strong, above the 3x e-commerce benchmark
2. Brand Awareness excluded from evaluation (learning phase)
3. [Relevance diagnostic findings if applicable]
4. [Auction overlap signals if applicable]

### Recommendations
1. [Aligned with get_recommendations output — cite the recommendation]
2. [Data-backed with specific metric cited]
3. [Framed as testable hypothesis if uncertain]

### Meta's Recommendations
[List any from get_recommendations, or "None returned for this account"]
```

---

## Creative Fatigue Signals — Flag Proactively
- Link click CTR declining 2+ consecutive weeks on the same creative with unchanged targeting
- Estimated reach frequency >4.0 on cold (prospecting) audiences
- ROAS drop >20% week-over-week on a campaign with no budget or creative changes
- CPM rising >30% week-over-week (audience saturation signal)

---

## Performance Fluctuation Guide

**Normal — do not alarm:**
- Day-to-day CPA variation ≤30%
- Weekend vs. weekday differences in CPM and CTR
- Higher CPA during first 7 days of a new ad set (learning volatility)
- Spend "holding back" early in campaign then accelerating (budget pacing behaviour)

**Concerning — flag and investigate:**
- Sustained CPA increase >50% for 3+ consecutive days
- Delivery dropping to near zero unexpectedly
- Conversion rate declining while spend holds steady
- Performance degradation with no changes made to the account

**Before concluding there's a problem, always check:**
1. Is the ad set still in learning phase?
2. Are there external factors (seasonal, competitive, platform changes)?
3. Is the evaluation window at least 7 days?

---

## ROAS Benchmarks (E-commerce)

| ROAS | Status |
|---|---|
| <2x | Underperforming — investigate immediately |
| 2–3x | Acceptable — monitor |
| 3–4x | Good — maintain and optimise |
| >4x | Strong — scale budget carefully |

---

## Auction Mechanics Context

**Total Auction Value = Bid × Estimated Action Rate + Ad Quality**

- Improving creative quality can win more auctions than raising bids
- Low delivery ≠ low bid. Low estimated action rate or quality loses auctions at any bid level
- Relevance improvements are almost always more cost-efficient than bidding higher
