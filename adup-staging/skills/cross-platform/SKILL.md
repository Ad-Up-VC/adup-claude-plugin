---
name: cross-platform
description: Build a unified cross-platform marketing dashboard showing total spend, performance by channel, blended ROAS, and key insights across all connected platforms. The most powerful ADUP skill.
---

# Cross-Platform Marketing Dashboard

## When to use
- "Full marketing overview"
- "Total spend across all channels"  
- "Which channel has the best ROI?"
- "Monthly marketing report"
- "Compare Facebook vs Google"

## Pre-flight
1. Call `list_shops` to get brands + `connected_platforms`
2. Call `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**: an agency key only sees the 6 virtual tools until a shop is active
3. Pass `shop_slug="<slug>"` on EVERY data call below. If you build this dashboard for more than one brand, pass each brand's own slug per call inside the loop — `set_active_shop` sets ONE ambient shop per API key and concurrent runs race
4. Use a consistent date range for ALL calls
5. Collect all data before formatting output

## Call sequence

All platform tools are namespaced `platform__tool` on the aggregated `adup` connector.

### 1. Paid platforms (call for each connected platform)

```
# Facebook (if connected)
facebook__get_campaign_performance_metrics(time_range={"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}, shop_slug="<slug>")

# Google Ads (if connected)
google_ads__get_google_ads_account_currency(shop_slug="<slug>")
google_ads__get_google_ads_campaign_performance(start_date="YYYY-MM-DD", end_date="YYYY-MM-DD", shop_slug="<slug>")

# LinkedIn Ads (if connected)
linkedin__get_ad_analytics(shop_slug="<slug>", ...)
```

### 2. Analytics (if GA4 connected)
```
ga4__get_ecommerce_performance(user_prompt="revenue by source", time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}}, format_type="table", shop_slug="<slug>")
ga4__get_user_acquisition(user_prompt="sessions by channel", time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}}, shop_slug="<slug>")
```

### 3. Assemble and cross-reference
- Sum total spend across all platforms
- Match GA4 channel names to ad platforms (google/cpc = Google Ads, facebook/cpc = Facebook)
- Calculate blended ROAS: total GA4 paid revenue / total ad spend

## Output format

```
## Marketing Dashboard — [Shop] | [Date Range]

### Investment
| Platform | Spend | Share |
|----------|-------|-------|
| Google Ads | €7,241 | 47% |
| Facebook Ads | €6,339 | 41% |
| LinkedIn Ads | €1,742 | 11% |
| **Total** | **€15,322** | **100%** |

### Performance by Platform
| Platform | Spend | Conv./Leads | CPA/CPL | ROAS |
|----------|-------|-------------|---------|------|
| Google Ads | €7,241 | 597 | €12.13 | 4.2x |
| Facebook Ads | €6,339 | 187 | €33.90 | 3.1x |
| LinkedIn Ads | €1,742 | 28 leads | €62.21 | — |

### GA4 Revenue Attribution
| Channel | Revenue | ROAS |
|---------|---------|------|
| google / cpc | €30,430 | 4.2x |
| facebook / cpc | €19,680 | 3.1x |

**Blended paid ROAS**: 3.3x | **Total paid revenue**: €50,110

### Key Insights
1. Google Ads leads on ROAS (4.2x) — highest ROI channel, scale budget here
2. Facebook ROAS declining (was 3.8x last month) — check for creative fatigue
3. LinkedIn CPL €62 is below the €80 B2B benchmark — efficient

### Recommendations
| Priority | Action |
|----------|--------|
| High | Increase Google Ads budget (4.2x ROAS, room to scale) |
| High | Refresh Facebook creatives (ROAS declining) |
| Medium | Review LinkedIn pipeline in HubSpot |
```

## Attribution disclaimer (always include)

"Attribution note: Platform-reported conversions use different windows (Facebook: 7-day click + 1-day view; Google: last-click 30-day). GA4 uses last-click session attribution. These will not sum — GA4 revenue is the most conservative baseline."
