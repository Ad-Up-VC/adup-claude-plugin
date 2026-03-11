# Monday Morning Briefing — Scheduled Task

**Schedule:** Every Monday at 8:00 AM
**Cron:** `0 8 * * 1`
**Skills Used:** `/adup:monday-briefing`, `/adup:cross-platform`, `/adup:analytics`
**Output:** Proposals via action middleware + `.md` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`

---

## What It Does

The flagship weekly task. Runs an automated executive briefing for every active client each Monday morning, so the team walks in with a clear picture of the week ahead. Assigns a verdict per client, identifies wins and concerns, creates optimization proposals, and saves a briefing document per client.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all available shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull last 7 days vs previous 7 days from ALL connected platforms:**
      - Facebook: `get_campaign_performance_metrics` with WoW comparison + `get_ad_insights` with `time_increment=7`
      - Google: `get_google_ads_campaign_performance` for both periods (divide micros by 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` for both periods (include hook rate)
      - LinkedIn: campaign analytics for both periods (CPL focus)
      - GA4: `get_ecommerce_performance` for revenue by source + `get_user_acquisition` for channel data
   c. **Calculate blended metrics:**
      - Total ad spend across all platforms
      - GA4 revenue (last-click attribution) = source of truth
      - Blended ROAS = GA4 revenue / total ad spend
      - Attribution gap per platform (platform conversions vs GA4)
   d. **Generate executive summary:**
      - **Verdict:** Great week / Stable / Needs attention / Urgent
      - **Top 3 Wins:** Best-performing campaigns with specific numbers and WoW change
      - **Top 3 Concerns:** Biggest problems with data and severity
   e. **Propose actions for concerns:**
      - Budget scaling for winners (15-20% increase): `propose_budget_change`
      - Budget cuts for underperformers (15-25% decrease): `propose_budget_change`
      - Pauses for severe underperformers (ROAS <50% target for 7+ days): `propose_status_change`
   f. **Save briefing:**
      - `mkdir -p ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
      - Save as: `{client}_monday-briefing_{YYYY-MM-DD}.md`
3. **Cross-client summary** — Which clients need the most attention this week

## Output Format

```
## [Client Name] — Week of [Date Range]

**Verdict:** [emoji] [verdict] — [one-line summary]

### Wins
1. [Platform] [Campaign] — [metric] [value] ([WoW change])
2. [Campaign] — [metric] [value] ([WoW change])
3. [Campaign] — [metric] [value] ([WoW change])

### Concerns
1. [Platform] [Campaign] — [issue] ([data])
2. [Campaign] — [issue] ([data])
3. [Campaign] — [issue] ([data])

### Actions Proposed
- [X proposals created in middleware — awaiting approval]
- Proposal 1: [details]
- Proposal 2: [details]

### Key Metrics
| Platform | Spend | Conversions | ROAS | WoW Change |
|----------|-------|-------------|------|------------|
| Facebook | $X | X | X.Xx | +/-X% |
| Google | $X | X | X.Xx | +/-X% |
| GA4 Blended | $X | X | X.Xx | +/-X% |
```

## Rules

1. **GA4 is source of truth for revenue.** Always calculate blended ROAS using GA4, not platform-reported revenue.
2. **Opinionated, not neutral.** Lead with the verdict. Say "Great week" or "Urgent" — don't hedge.
3. **Actions must be data-backed.** Every proposal must reference specific metrics.
4. **Learning phase entities excluded.** Flag them but don't judge their performance.
5. **Weekend variance is normal.** Don't alarm on day-to-day fluctuations <=30%.
6. **Google Ads micros.** Always divide by 1,000,000.
7. **All proposals through middleware.** Never execute directly.
8. **Save the briefing.** Always save to the client's report folder for reference.
