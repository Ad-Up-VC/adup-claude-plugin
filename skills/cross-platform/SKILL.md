---
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
1. Confirm shop context (agency accounts)
2. Call `list_shops` to check which platforms are connected
3. Use a consistent date range for ALL calls
4. Collect all data before formatting output

## Call sequence

### 1. Paid platforms (call for each connected platform)

```
# Facebook (if connected)
get_campaign_performance_metrics(time_range={...})

# Google Ads (if connected)  
get_google_ads_account_currency()
get_google_ads_campaign_performance(start_date=..., end_date=...)

# LinkedIn (if connected)
get_campaign_analytics_with_names(date_range={...})
```

### 2. Analytics (if GA4 connected)
```
get_ecommerce_performance(user_prompt="revenue by source", time_range={...}, format_type="table")
get_user_acquisition(user_prompt="sessions by channel", time_range={...})
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
