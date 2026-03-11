---
description: Analyse Google Ads performance including Search, Shopping, Performance Max, and Display. Campaign metrics, Quality Score diagnostics, impression share analysis, keyword analysis, and conversion data. All costs returned in micros — always divide by 1,000,000.
---

# Google Ads Analysis

## Pre-flight
- Confirm shop context for agency accounts
- Default to last 30 days if no date range specified — state the assumption
- **Always call `get_google_ads_account_currency()` first** — display the correct currency symbol in all outputs
- Google Ads returns ALL monetary values in micros — see conversion rule below

---

## ⚠️ Mandatory: Micros Conversion

Google Ads returns every cost, bid, and value as an integer in **micros** (millionths of a currency unit).

**Rule: always divide by 1,000,000 before displaying anything to the user. Never show raw micro values.**

```
cost_micros: 7,241,000,000  →  €7,241
average_cpc_micros: 940,000  →  €0.94
cost_per_conversion_micros: 8,430,000  →  €8.43
conversion_value_micros: 24,700,000,000  →  €24,700
```

If you see a number like `8430000` in a tool response, always divide by 1,000,000 before displaying it.

---

## ⚠️ Conversion Reliability Rule

**Do not make CPA or ROAS optimisation decisions based on fewer than 30 conversions in the evaluation window.** With small conversion volumes, CPA fluctuations are statistical noise, not signal. State this caveat when conversion counts are low.

---

## Key Tools

**Currency (always first):**
```
get_google_ads_account_currency()
```

**Campaign performance (main overview):**
```
get_google_ads_campaign_performance(
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```
Returns: campaign name, type, impressions, clicks, CTR, cost_micros, conversions, cost_per_conversion_micros, average_cpc.
Remember: divide all _micros values by 1,000,000.

**Natural language / custom queries (most powerful):**
```
search_google_ads_data(
  user_prompt="Show me keywords with quality score below 5 and spend above €100",
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```
Use this for: search term reports, keyword-level analysis, quality score queries, impression share, any metric not in structured tools.

**Raw GAQL (for advanced queries):**
```
execute_google_ads_gaql_query(
  query="SELECT campaign.name, metrics.impressions, metrics.cost_micros FROM campaign WHERE segments.date DURING LAST_30_DAYS",
  output_format="table"
)
```

**Conversion action details:**
```
get_google_ads_conversion_actions()
```
Use to understand what's being tracked and how (attribution model, lookback window, counting type).

**Conversion stats by action:**
```
get_google_ads_conversion_action_stats(
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```

**Ad-level performance:**
```
get_google_ads_ad_performance(
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```

**Ad creative copy:**
```
get_google_ads_ad_creatives()
```

---

## Campaign Type Rules — KPIs Differ by Type

| Campaign Type | Primary KPIs | Evaluation Window | Key Signals |
|---|---|---|---|
| **Search** | CTR, CPA, Quality Score | 7+ days | QS <5 = wasted budget; low impression share = lost auctions |
| **Shopping** | ROAS, conversion rate | 14+ days | Feed quality, product-level ROAS, impression share |
| **Performance Max (PMax)** | ROAS, conversion value | 14+ days | Limited visibility; evaluate by output not internals |
| **Display / Video** | CPM, view rate, reach | 14+ days | Brand awareness; don't optimise on CPA alone |
| **Brand Search** | CTR, impression share | 7+ days | CTR <80% = brand leakage to competitors |

**Never apply Search benchmarks to Shopping or PMax.** Each type has fundamentally different auction mechanics.

---

## Quality Score Diagnostics

Quality Score (1–10) has three sub-components, each diagnosing a different problem:

| Sub-score | Low Score Means | Fix |
|---|---|---|
| Expected CTR | Keyword-ad relevance poor | Tighten keyword-to-ad copy match; add keyword to headline |
| Ad Relevance | Ad copy doesn't match search intent | Rewrite ads for the keyword theme |
| Landing Page Experience | Page doesn't match ad/keyword | Improve page relevance, speed, mobile experience |

**QS <5 with meaningful spend = wasted budget. Flag this proactively.**
Use: `search_google_ads_data(user_prompt="keywords with quality score below 5 and cost above €50")`

---

## Impression Share Analysis

Impression Share tells you how often you showed vs. how often you could have shown.

| Metric | Low Because Of | Fix |
|---|---|---|
| IS lost due to **budget** | Ran out of daily budget | Increase budget or restrict to best hours |
| IS lost due to **rank** | Ad Rank too low (quality or bid) | Improve Quality Score first, then bid |

Use: `search_google_ads_data(user_prompt="impression share lost due to budget and rank by campaign")`

---

## Attribution Context

Google Ads uses **data-driven attribution** by default (distributes conversion credit across touchpoints). This means:
- Google Ads conversions will always be higher than GA4 last-click conversions
- This is not inflation — it's a different attribution model
- Use GA4 for channel-level revenue truth; use Google Ads for within-account optimisation

Always check `get_google_ads_conversion_actions()` to confirm what's being tracked (soft events vs. purchases, lookback windows, cross-device).

---

## Analysis Workflow

### Step 1 — Get currency
`get_google_ads_account_currency()` — note the currency for all outputs.

### Step 2 — Campaign-level overview
`get_google_ads_campaign_performance()` — get all campaigns, sort by spend. Convert all _micros values.

### Step 3 — Identify campaign types
Categorise each campaign: Search, Shopping, PMax, Display. Apply the right KPIs per type.

### Step 4 — Quality Score check (Search campaigns)
For Search campaigns: `search_google_ads_data("keywords with quality score below 5")`. Flag any with significant spend.

### Step 5 — Impression share check
For Search/Shopping: `search_google_ads_data("impression share lost to budget vs rank by campaign")`. Diagnose why IS is low.

### Step 6 — Conversion action audit (if conversion data looks unexpected)
`get_google_ads_conversion_actions()` — confirm what's being counted, attribution model, lookback window.

### Step 7 — Deep dive with natural language
For any specific question: `search_google_ads_data(user_prompt="<specific question>", ...)`. This covers search term reports, negative keyword opportunities, top keywords by CPA, ad copy performance, etc.

### Step 8 — Evaluate over correct window
- Search: 7+ days minimum
- Shopping / PMax: 14+ days (conversion data takes longer to accrue)
- Don't evaluate on <30 conversions — state the caveat

---

## Output Format

```
## Google Ads — [Shop] | [Date Range] | Currency: EUR

| Campaign | Type | Spend | Clicks | CTR | CPC | Conv. | CPA | ROAS |
|----------|------|-------|--------|-----|-----|-------|-----|------|
| Brand Search | Search | €2,145 | 3,860 | 8.01% | €0.56 | 312 | €6.87 | — |
| Shopping | Shopping | €3,892 | 2,480 | 2.00% | €1.57 | 198 | €19.66 | 6.3x |
| PMax | PMax | €1,204 | 1,340 | 1.50% | €0.90 | 87 | €13.84 | 4.1x |

**Total**: €7,241 | 597 conversions | Blended CPA: €12.13 | Blended ROAS: 5.2x

### ⚠️ Issues Found
- Shopping campaign: 2 keywords with QS <5 spending €340 — immediate optimisation opportunity
- PMax: impression share lost to rank 34% — Quality Score improvements needed before bid increases

### Insights
1. Brand Search CTR 8.01% — healthy, above 8% benchmark
2. Shopping ROAS 6.3x — strong; check impression share to identify scaling headroom
3. PMax limited transparency — evaluate on conversion value output, not internal metrics

### Recommendations
1. Fix QS <5 keywords in Shopping: align ad copy to keyword intent (€340 wasted budget recoverable)
2. PMax IS rank gap: audit asset group quality before increasing bids
3. [Third recommendation with evidence]
```

---

## Benchmarks by Campaign Type

| Campaign Type | Metric | Below Average | Good | Excellent |
|---|---|---|---|---|
| Brand Search | CTR | <6% | 8–15% | >15% |
| Non-brand Search | CTR | <2% | 4–8% | >8% |
| Shopping | CTR | <0.8% | 1.5–3% | >3% |
| Shopping | ROAS (e-comm) | <3x | 5–8x | >8x |
| PMax | ROAS (e-comm) | <3x | 4–7x | >7x |
| Search | Quality Score | <5 | 7–8 | 9–10 |
| Any | CPA trend | Rising week-over-week | Stable | Declining |

---

## Common Search Term Report Analysis

Use `search_google_ads_data` with prompts like:
- `"Show me search terms that spent over €50 with zero conversions last 30 days"` → negative keyword candidates
- `"Top 20 search terms by conversion volume this month"` → exact match expansion opportunities
- `"Search terms triggering broad match keywords with low quality score"` → match type waste
- `"Campaigns with impression share lost to budget above 20%"` → budget-constrained campaigns

These are the most high-value analyses for Search campaign optimisation.
