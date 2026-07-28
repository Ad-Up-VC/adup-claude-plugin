---
name: google-ads
description: Analyse Google Ads performance including Search, Shopping, Performance Max, and Display. Campaign metrics, Quality Score diagnostics, impression share analysis, keyword analysis, and conversion data. All costs returned in micros — always divide by 1,000,000.
---

# Google Ads Analysis

## Pre-flight
- Resolve shop context in three steps: (1) `list_shops` to see brands + `connected_platforms`, (2) `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**: an agency key only sees the 6 virtual tools until a shop is active, (3) pass `shop_slug="<slug>"` on every data call
- **Always include `shop_slug` in every Google Ads tool call** — the ambient active shop is per-API-key and races across concurrent runs
- All Google Ads tools are namespaced `google_ads__<tool>` on the aggregated `adup` connector (never `google__`)
- Default to last 30 days if no date range specified — state the assumption
- **Always call `google_ads__get_google_ads_account_currency(shop_slug="<slug>")` first** — display the correct currency symbol in all outputs
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
google_ads__get_google_ads_account_currency(shop_slug="<slug>")
```

**Campaign performance (main overview):**
```
google_ads__get_google_ads_campaign_performance(
  shop_slug="<slug>",
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```
Returns: campaign name, type, impressions, clicks, CTR, cost_micros, conversions, cost_per_conversion_micros, average_cpc.
Remember: divide all _micros values by 1,000,000.

**Custom GAQL queries (most powerful):**
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT campaign.name, metrics.clicks, metrics.cost_micros FROM campaign WHERE segments.date >= '2026-06-28' AND segments.date <= '2026-07-27' ORDER BY metrics.cost_micros DESC",
  customer_id="1234567890",   # optional — 10 digits, no dashes; defaults to the account credentials
  output_format="table"       # 'table' (default) | 'json' | 'csv'
)
```
This takes a **raw GAQL query string, not a natural-language prompt**. Field names are snake_case (`campaign.name`, `metrics.cost_micros`). The date range lives inside the query (`segments.date`), not in separate arguments.

Two date forms work. `DURING LAST_30_DAYS` (also `LAST_7_DAYS`, `LAST_14_DAYS`, `THIS_MONTH`) is the shorthand used in the examples below and needs no date math. Explicit bounds — `segments.date >= 'YYYY-MM-DD' AND segments.date <= 'YYYY-MM-DD'` — are the fallback if a shorthand range is ever rejected, and are required for any custom window; get those dates from the calendar MCP, never by calculating them yourself.

Use this for: search term reports, keyword-level analysis, quality score queries, impression share, any metric not in structured tools. Costs come back in micros here too — divide by 1,000,000.

**Conversion action details:**
```
google_ads__get_google_ads_conversion_actions(shop_slug="<slug>")
```
Use to understand what's being tracked and how (attribution model, lookback window, counting type).

**Conversion stats by action:**
```
google_ads__get_google_ads_conversion_action_stats(
  shop_slug="<slug>",
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```

**Ad-level performance:**
```
google_ads__get_google_ads_ad_performance(
  shop_slug="<slug>",
  start_date="YYYY-MM-DD",
  end_date="YYYY-MM-DD"
)
```

**Ad creative copy:**
```
google_ads__get_google_ads_ad_creatives(shop_slug="<slug>")
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

Keywords with QS <5 that spent more than €50 in the last 30 days (`metrics.cost_micros > 50000000` = €50, because cost is in micros):
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT campaign.name, ad_group.name, ad_group_criterion.keyword.text, ad_group_criterion.quality_info.quality_score, metrics.cost_micros, metrics.clicks, metrics.conversions FROM keyword_view WHERE segments.date DURING LAST_30_DAYS AND ad_group_criterion.quality_info.quality_score < 5 AND metrics.cost_micros > 50000000 ORDER BY metrics.cost_micros DESC"
)
```
Quality Score is a *current* snapshot, not a historical metric — the date range filters the spend, not the score.

---

## Impression Share Analysis

Impression Share tells you how often you showed vs. how often you could have shown.

| Metric | Low Because Of | Fix |
|---|---|---|
| IS lost due to **budget** | Ran out of daily budget | Increase budget or restrict to best hours |
| IS lost due to **rank** | Ad Rank too low (quality or bid) | Improve Quality Score first, then bid |

Impression share lost to budget vs. rank, per campaign:
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT campaign.name, campaign.advertising_channel_type, metrics.search_impression_share, metrics.search_budget_lost_impression_share, metrics.search_rank_lost_impression_share, metrics.cost_micros FROM campaign WHERE segments.date DURING LAST_30_DAYS AND campaign.status = 'ENABLED' ORDER BY metrics.search_budget_lost_impression_share DESC"
)
```
Impression-share metrics are fractions (0.34 = 34%).

---

## Attribution Context

Google Ads uses **data-driven attribution** by default (distributes conversion credit across touchpoints). This means:
- Google Ads conversions will always be higher than GA4 last-click conversions
- This is not inflation — it's a different attribution model
- Use GA4 for channel-level revenue truth; use Google Ads for within-account optimisation

Always check `google_ads__get_google_ads_conversion_actions(shop_slug="<slug>")` to confirm what's being tracked (soft events vs. purchases, lookback windows, cross-device).

---

## Analysis Workflow

### Step 1 — Get currency
`google_ads__get_google_ads_account_currency(shop_slug="<slug>")` — note the currency for all outputs.

### Step 2 — Campaign-level overview
`google_ads__get_google_ads_campaign_performance(shop_slug="<slug>", ...)` — get all campaigns, sort by spend. Convert all _micros values.

### Step 3 — Identify campaign types
Categorise each campaign: Search, Shopping, PMax, Display. Apply the right KPIs per type.

### Step 4 — Quality Score check (Search campaigns)
For Search campaigns, pull keywords scoring below 5 and flag any with significant spend (cost is in micros — divide by 1,000,000):
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT campaign.name, ad_group.name, ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type, ad_group_criterion.quality_info.quality_score, metrics.cost_micros, metrics.impressions FROM keyword_view WHERE segments.date DURING LAST_30_DAYS AND ad_group_criterion.quality_info.quality_score < 5 ORDER BY metrics.cost_micros DESC"
)
```

### Step 5 — Impression share check
For Search/Shopping, diagnose why IS is low — budget-constrained or rank-constrained:
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT campaign.name, campaign.advertising_channel_type, metrics.search_impression_share, metrics.search_budget_lost_impression_share, metrics.search_rank_lost_impression_share FROM campaign WHERE segments.date DURING LAST_30_DAYS AND campaign.status = 'ENABLED' ORDER BY metrics.search_impression_share ASC"
)
```

### Step 6 — Conversion action audit (if conversion data looks unexpected)
`google_ads__get_google_ads_conversion_actions(shop_slug="<slug>")` — confirm what's being counted, attribution model, lookback window.

### Step 7 — Deep dive with a custom GAQL query
For anything the structured tools don't cover, write a GAQL query and run it through `google_ads__execute_google_ads_gaql_query`. This covers search term reports, negative keyword opportunities, top keywords by CPA, ad copy performance, etc. Example — spend with zero conversions, the classic negative-keyword hunt:
```
google_ads__execute_google_ads_gaql_query(
  shop_slug="<slug>",
  query="SELECT search_term_view.search_term, campaign.name, metrics.cost_micros, metrics.clicks, metrics.conversions FROM search_term_view WHERE segments.date DURING LAST_30_DAYS AND metrics.conversions = 0 AND metrics.cost_micros > 50000000 ORDER BY metrics.cost_micros DESC"
)
```

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

Run these through `google_ads__execute_google_ads_gaql_query(shop_slug="<slug>", query="...")`:

Search terms that spent over €50 with zero conversions → negative keyword candidates:
```
SELECT search_term_view.search_term, campaign.name, metrics.cost_micros, metrics.clicks, metrics.conversions
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS AND metrics.conversions = 0 AND metrics.cost_micros > 50000000
ORDER BY metrics.cost_micros DESC
```

Top 20 search terms by conversion volume → exact match expansion opportunities:
```
SELECT search_term_view.search_term, campaign.name, metrics.conversions, metrics.cost_micros, metrics.clicks
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.conversions DESC
LIMIT 20
```

Broad match keywords with low quality score → match type waste:
```
SELECT campaign.name, ad_group.name, ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type, ad_group_criterion.quality_info.quality_score, metrics.cost_micros
FROM keyword_view
WHERE segments.date DURING LAST_30_DAYS AND ad_group_criterion.keyword.match_type = 'BROAD' AND ad_group_criterion.quality_info.quality_score < 5
ORDER BY metrics.cost_micros DESC
```

Campaigns losing more than 20% impression share to budget → budget-constrained campaigns:
```
SELECT campaign.name, metrics.search_impression_share, metrics.search_budget_lost_impression_share, metrics.cost_micros
FROM campaign
WHERE segments.date DURING LAST_30_DAYS AND metrics.search_budget_lost_impression_share > 0.2
ORDER BY metrics.search_budget_lost_impression_share DESC
```

These are the most high-value analyses for Search campaign optimisation.
