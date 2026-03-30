---
name: ads-overview
description: Get a quick cross-platform advertising overview. Shows total spend, performance by platform, and top-level insights across all connected ad platforms for the active shop.
---

# Advertising Overview

Pull a quick overview of all connected advertising platforms for the active shop.

## Pre-flight

If the shop is an agency account and no client has been specified, call `list_shops` and ask which client.
If no date range given, default to last 30 days and state this.

## Tool call sequence

Call performance tools for each connected platform (check `connected_platforms` from `list_shops`):

**If Facebook Ads connected:**
```
get_campaign_performance_metrics(time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"})
```

**If Google Ads connected:**
```
get_google_ads_account_currency()
get_google_ads_campaign_performance(start_date="YYYY-MM-DD", end_date="YYYY-MM-DD")
```
Note: Google Ads returns costs in micros — divide by 1,000,000 for actual values.

**If LinkedIn Ads connected:**
- LinkedIn tools not yet available via MCP — note in output that LinkedIn data is pending integration

## Output format

```
## Advertising Overview — [Shop] | [Date Range]

| Platform | Spend | Clicks | CPC | Conversions | CPA/CPL | ROAS |
|----------|-------|--------|-----|-------------|---------|------|
| Google Ads | €7,241 | 7,680 | €0.94 | 597 | €12.13 | 4.2x |
| Facebook Ads | €6,339 | 18,600 | €0.34 | 187 | €33.90 | 3.1x |
| LinkedIn Ads | €1,742 | 893 | €1.95 | 28 leads | €62.21 | — |

**Total spend**: €15,322 | **Blended ROAS**: 3.7x

### Insights
- Google Ads delivers highest ROAS (4.2x) — consider increasing budget
- Facebook ROAS at 3.1x is above minimum threshold
- LinkedIn CPL €62 is efficient for B2B (benchmark: €80–200)
```

## Edge cases

- Google Ads micros: always divide `cost_micros` by 1,000,000
- ROAS only meaningful for e-commerce (SALES objective). For B2B/lead gen, use CPL instead
- If a platform has no data: "No [platform] data in this period — campaigns may be paused"
