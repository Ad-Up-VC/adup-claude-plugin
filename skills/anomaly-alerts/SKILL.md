---
name: anomaly-alerts
description: Monitor ad accounts for anomalies every 3 hours. Detects spend spikes, delivery stops, CTR drops, budget exhaustion, and conversion rate collapse. Creates proposals for critical issues and logs warnings for the next briefing.
---

# Anomaly Detection & Alerts

## Pre-flight
- Iterate through all active shops with anomaly monitoring enabled
- Pull today's data with hourly/daily granularity
- Compare against 7-day rolling averages

---

## Step 1 — Pull Current Data

For each active shop, pull recent data from all connected platforms:

### Facebook Ads
- `get_campaign_performance_metrics(time_range={...}, shop_slug="<slug>")` for today and last 7 days
- `get_ad_insights(time_range={...}, time_increment=1, shop_slug="<slug>")` for daily granularity

### Google Ads
- `get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")` for today and last 7 days
- All monetary values in micros — divide by 1,000,000

### TikTok Ads (if connected)
- TikTok campaign tools not yet available via MCP — skip or note

### LinkedIn Ads (if connected)
- LinkedIn tools not yet available via MCP — skip or note

---

## Step 2 — Run Anomaly Detection

### CRITICAL Anomalies (immediate action required)

| Signal | Detection | Action |
|--------|-----------|--------|
| **Delivery stopped** | Impressions = 0 for 3+ hours while status = active | Alert + investigate |
| **Spend spike** | Spend > 200% of daily average in current window | Propose budget decrease |
| **Budget exhaustion** | Lifetime budget < 5% remaining, projected to exhaust today | Alert + propose budget increase or pause |
| **Account overspend** | Total account spend exceeding daily budget by 150%+ | Alert + propose pause on highest-spend campaigns |

### WARNING Anomalies (flag for next check)

| Signal | Detection | Action |
|--------|-----------|--------|
| **CTR collapse** | CTR dropped > 40% vs 7-day average | Log + monitor |
| **CPA spike** | CPA > 50% above 7-day average for 24+ hours | Log + monitor |
| **Frequency alarm** | Frequency > 4.0 on any active ad | Flag for creative refresh |
| **Conversion drought** | No conversions in 24 hours on normally-converting campaign | Log + investigate |

### INFO Anomalies (include in next briefing)

| Signal | Detection | Action |
|--------|-----------|--------|
| **New learning phase** | Ad set entered Learning status | Note in briefing |
| **Pacing deviation** | Budget pacing >20% over/under expected | Note in briefing |
| **Attribution divergence** | Platform conversions diverging from GA4 by >30% | Note in briefing |

---

## Step 3 — Take Action on Critical Anomalies

### For spend spikes:
- Identify the campaign(s) responsible
- Calculate the appropriate budget to return to normal pacing
- Call `propose_budget_change` with reasoning citing the spike data
- Example: "Campaign 'Retargeting US' spending at 3.2x daily average rate. At current pace, will exhaust monthly budget 10 days early. Propose reducing daily budget from $180 to $120."

### For delivery stops:
- Check campaign/ad set status (may have been paused externally)
- Check for rejection/policy issues
- Alert user with specific campaign details
- Do NOT propose reactivation without understanding the cause

### For budget exhaustion:
- Calculate remaining budget vs remaining days
- Propose budget adjustment or pause based on performance:
  - Good ROAS → propose budget increase
  - Poor ROAS → propose pause to preserve remaining budget

---

## Step 4 — Log Results

For each check cycle:
- Record all detected anomalies with timestamps
- Track which anomalies are new vs recurring
- Recurring CRITICAL anomalies that go unresolved for 24+ hours → escalate severity

---

## Output Format

```
## Anomaly Check — [Timestamp]

### CRITICAL
- [Platform] [Campaign] — [Issue]: [Data] → [Action taken/proposed]

### WARNING
- [Platform] [Campaign] — [Issue]: [Data]

### INFO
- [Notes for next briefing]

### All Clear
- [List of shops with no anomalies detected]
```

---

## Rules

1. **CRITICAL anomalies get immediate proposals.** Don't wait for the next briefing — create a middleware proposal now for spend spikes and budget exhaustion.

2. **Never auto-pause without understanding why delivery stopped.** A delivery stop might be intentional (user paused), a policy review, or an actual problem. Investigate first.

3. **7-day rolling average is the baseline.** Don't compare against a single day — use the 7-day average to account for day-of-week variance.

4. **Weekend patterns are normal.** Saturday/Sunday spend patterns can differ significantly from weekdays. Factor this into anomaly detection — a 30% spend drop on Saturday is normal for most B2B accounts.

5. **Rate limit proposals.** Don't create multiple proposals for the same issue in the same check cycle. One proposal per anomaly, tracked to prevent duplicates.

6. **All proposals go through middleware.** Budget caps, percentage limits, and daily auto-approval limits are enforced by the shop configuration.
