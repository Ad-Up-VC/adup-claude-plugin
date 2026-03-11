# Daily Budget Pacing Check — Scheduled Task

**Schedule:** Every day at 6:30 AM (Mon-Sun)
**Cron:** `30 6 * * *`
**Skills Used:** `/adup:budget-tracker`
**Output:** Proposals via action middleware + internal log

---

## What It Does

First task of the day. Checks budget pacing across all clients before anyone starts work. Catches overpacing campaigns before they exhaust budgets and underpacing campaigns that won't hit targets. Creates proposals for campaigns significantly off track.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. Pull budget pacing data for the current month:
      - Facebook: `get_campaign_performance_metrics` with current month date range
      - Google Ads: `get_google_ads_campaign_performance` (divide all micros by 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` if connected
      - LinkedIn: campaign analytics if connected
   c. For each campaign, calculate:
      - Days elapsed / total days in month = expected utilization %
      - Actual spend / total budget = actual utilization %
      - Run rate = (spent so far / days elapsed) * remaining days
      - Status: On Track (90-110%), Underpacing (<90%), Overpacing (>110%)
   d. **For overpacing campaigns (>115%):**
      - Calculate: remaining_budget / remaining_days = target daily spend
      - Propose budget decrease via `propose_budget_change` with reasoning citing pacing data
   e. **For severe overpacing (>150%):**
      - Flag as URGENT
      - Propose immediate budget reduction to align with remaining budget
   f. **For underpacing (<85%):**
      - Check if performance is strong (ROAS/CPA on target)
      - If performance is good, optionally propose budget increase
      - If performance is poor, flag for review (may need audience/creative changes)
3. **Summary** — Count of on-track / overpacing / underpacing campaigns across all clients

## Output Format

```
## Budget Pacing Check — [Date] 06:30

### [Client Name]
| Campaign | Platform | Budget | Spent | Util. | Run Rate | Projected | Status |
|----------|----------|--------|-------|-------|----------|-----------|--------|
| Summer Sale | Facebook | $5,000 | $3,200 | 64% | $180/day | $5,400 | Overpacing |
| Brand Search | Google | $3,000 | $1,200 | 40% | $100/day | $3,000 | On Track |

Proposals created: 1 (budget decrease for "Summer Sale")

### Cross-Client Summary
- On Track: 12 campaigns
- Overpacing: 2 campaigns (1 URGENT)
- Underpacing: 3 campaigns
```

## Rules

1. **Check performance alongside pacing.** Overpacing with great ROAS is less concerning than overpacing with poor ROAS. Note performance context in every proposal.
2. **Weekend patterns are normal.** Saturday/Sunday spend patterns can cause false pacing alerts. If today is Saturday or Sunday, apply a wider tolerance (80-120% instead of 90-110%).
3. **Google Ads micros.** Always divide all monetary values by 1,000,000 before calculating or displaying.
4. **All proposals go through middleware.** Budget caps, percentage limits, and daily limits enforced per shop configuration.
5. **Skip clients with no active campaigns.** If a client has all campaigns paused, skip and note it.
6. **Monthly reset.** On the 1st of each month, all pacing resets — don't flag campaigns as overpacing on day 1 when there's minimal data.
