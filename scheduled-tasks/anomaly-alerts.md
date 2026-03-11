# Anomaly Detection & Alerts — Scheduled Task

**Schedule:** Every 3 hours, 24/7
**Cron:** `0 */3 * * *`
**Skills Used:** `/adup:anomaly-alerts`
**Output:** Proposals via action middleware for CRITICAL issues

---

## What It Does

Continuous monitoring across all active clients to catch problems before they cost real money. The Friday afternoon campaign break nobody notices until Monday. Runs 8 times per day — checks current performance against 7-day rolling averages and creates proposals for critical anomalies.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all available shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull current data from all connected platforms:**
      - Facebook: `get_campaign_performance_metrics` with `time_increment=1` for today + last 7 days
      - Google: `get_google_ads_campaign_performance` for today + last 7 days (micros / 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` for today + last 7 days
      - LinkedIn: campaign performance for today + last 7 days
   c. **Run anomaly detection against 7-day rolling averages:**

### CRITICAL Anomalies (immediate action)

| Signal | Detection | Action |
|--------|-----------|--------|
| **Delivery stopped** | Active campaign, $0 spend last 6h, was delivering | Alert + investigate |
| **Spend spike** | Campaign spend >200% of 7-day daily average | Propose budget decrease |
| **Budget exhaustion** | Projected to exhaust budget 5+ days before period end | Propose budget adjustment |
| **Account overspend** | Total account spend >120% of expected daily run rate | Alert + propose pauses |

### WARNING Anomalies (flag for next check)

| Signal | Detection | Action |
|--------|-----------|--------|
| **CTR collapse** | CTR dropped >30% vs 7-day average | Flag for creative review |
| **CPA spike** | CPA >50% above 7-day average for 24+ hours | Flag for next briefing |
| **Frequency alarm** | Ad frequency >4.0 | Flag for fatigue analysis |
| **Conversion drought** | No conversions in 24h on normally-converting campaign | Flag + investigate |

### INFO Anomalies (include in next Monday briefing)

| Signal | Detection | Action |
|--------|-----------|--------|
| **New learning phase** | Ad set entered Learning status | Note in briefing |
| **Pacing deviation** | Budget pacing >20% over/under expected | Note in briefing |
| **Attribution divergence** | Platform conversions diverging from GA4 by >30% | Note in briefing |

   d. **Act on CRITICAL anomalies:**
      - **Spend spikes:** Identify campaign(s), calculate correction, `propose_budget_change`
      - **Delivery stops:** Check status (may be intentional), alert but don't auto-reactivate
      - **Budget exhaustion:** Calculate remaining_budget / remaining_days, propose adjustment
   e. **Log all findings** with timestamps

3. **Summary** — CRITICAL / WARNING / INFO counts across all clients

## Output Format

```
## Anomaly Scan — [Date] [Time]

CRITICAL: [N] | WARNING: [N] | INFO: [N]

### CRITICAL
- [Client] [Platform] "[Campaign]" — [Issue]: [Data]
  -> [Action taken/proposed]

### WARNING
- [Client] [Platform] "[Campaign]" — [Issue]: [Data]

### INFO
- [Notes for next Monday briefing]

### All Clear
- [List clients with no anomalies]
```

## Rules

1. **CRITICAL anomalies get immediate proposals.** Don't wait for next briefing.
2. **Never auto-pause without understanding why delivery stopped.** Could be intentional, policy review, or actual problem.
3. **7-day rolling average is the baseline.** Not single-day or lifetime averages.
4. **Weekend patterns are normal.** If today is Saturday/Sunday, apply wider tolerance. 30% spend drop on Saturday is normal for B2B.
5. **Rate limit proposals.** One proposal per anomaly per check cycle. No duplicates.
6. **Google Ads micros.** Divide by 1,000,000.
7. **All proposals through middleware.** Budget caps, percentage limits, daily limits enforced.
8. **If no anomalies: "All clear" and exit.** Don't generate noise when everything is fine.
