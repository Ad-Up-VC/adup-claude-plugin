# Internal Daily Overview — Scheduled Task

**Schedule:** Every weekday at 8:30 AM (Mon-Fri)
**Cron:** `30 8 * * 1-5`
**Skills Used:** `/adup:ads-overview`, `/adup:budget-tracker`
**Output:** `.md` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`

---

## What It Does

Quick morning snapshot for the team — how is each client doing TODAY and this week? Not a deep analysis. Just enough to know who needs attention before the day starts. Saved per client folder with `internal_` prefix. Runs after budget pacing (6:30) and fatigue (7:00) so it can reference their findings.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull quick overview data:**
      - Facebook: `get_campaign_performance_metrics` for today + last 7 days
      - Google: `get_google_ads_campaign_performance` for today + last 7 days (micros / 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` if connected
      - LinkedIn: campaign analytics if connected
   c. **Quick health check per client:**
      - Total spend today vs daily average
      - Any campaigns with zero delivery?
      - Any critical anomalies from the 3-hourly anomaly check?
      - Budget pacing status from the 6:30 check
      - Fatigue alerts from the 7:00 check
   d. **Assign client status:** Green (all good) / Yellow (needs monitoring) / Red (needs action)
   e. **Save file:**
      - `mkdir -p ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
      - Save as: `internal_daily-overview_{YYYY-MM-DD}.md`
3. **Cross-client dashboard** — One-line status per client

## Output Format

```
## Internal Daily Overview — [Date] 08:30

### Client Status Dashboard
| Client | Status | Today Spend | WTD Spend | Active Campaigns | Alerts |
|--------|--------|-------------|-----------|------------------|--------|
| Nike NL | Green | $1,240 | $6,800 | 8 | None |
| Adidas EU | Yellow | $890 | $4,200 | 5 | 1 fatigue alert |
| Puma | Red | $0 | $2,100 | 3 | Delivery stopped |

### Needs Attention
- **Puma** — Facebook "Spring Campaign" showing $0 spend since yesterday. Status: Active. Investigate delivery issue.
- **Adidas EU** — "Retargeting US" ad fatigue HIGH (flagged at 07:00). Pause proposal pending.

### All Clear
- Nike NL — all metrics within normal range
```

## Rules

1. **Speed over depth.** This is a 30-second scan, not a deep analysis. Brief is better.
2. **Reference morning tasks.** Don't re-analyze what budget-pacing and fatigue already found. Reference their findings.
3. **Red/Yellow/Green only.** Don't overthink the status — keep it simple for quick triage.
4. **Internal only.** These reports are for the team, not clients. No need for polished language.
5. **Google Ads micros.** Divide by 1,000,000.
6. **Skip inactive clients.** If all campaigns are paused, note "All paused" and move on.
