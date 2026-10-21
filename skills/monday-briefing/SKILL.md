---
name: monday-briefing
description: Generate a per-client executive briefing for the start of the week. Pulls last 7 days vs previous 7 days from all connected platforms, calculates blended ROAS via GA4, delivers an opinionated summary with wins, concerns, and proposed actions.
---

# Monday Morning Briefing

## Pre-flight
- Call `list_shops` to get every brand + its `connected_platforms`
- Call `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**: an agency key only sees the 6 virtual tools until a shop is active
- For agencies, iterate through all active shops. **Inside the loop, pass `shop_slug="<that shop's slug>"` on EVERY data call** — `set_active_shop` sets ONE ambient shop per API key, so a loop relying on the ambient shop reads the wrong client (and concurrent runs clobber each other)
- All platform tools are namespaced `platform__tool` on the aggregated `adup` connector
- Period: last 7 days vs previous 7 days
- Pull data from ALL connected platforms per shop
- Call connector tools directly by name (`<platform>__<tool>`, `list_shops`). A tool search that finds no matching deferred tools only means the tools are already loaded or named differently, never that the connector dropped. Report the connector as disconnected only after a real connector call such as `list_shops` fails, and quote that error. **Sign-in needed:** if no adup tools are available (no `list_shops`, no `<platform>__` tools) or a call fails with an authentication error (`-32001` authentication required, `invalid_token`, "requires authentication", "needs authentication"), the adup connector is not signed in on this machine. Say that plainly, tell the user to sign in (Claude Code: `/mcp` → adup → Authenticate; terminal: `claude mcp login plugin:adup:adup`, with `--no-browser` on a machine without a browser; machines that cannot sign in: the automation connector; full steps: `/adup:setup`), and stop instead of reporting empty data, a disconnect or a generic failure. **Platforms per brand:** call a platform for a brand only when it is in that brand's `connected_platforms` from `list_shops`; a "not connected for brand" answer means skip that platform for that brand and name it in the report, never fail the run.

---

## Step 1 — Pull Cross-Platform Data

For each active shop, pull performance data from all connected platforms:

### Facebook Ads (if connected)
- `facebook__get_campaign_performance_metrics(time_range={...}, shop_slug="<slug>")` for campaign-level metrics
- `facebook__get_ad_insights` for detailed conversion data, one row per campaign per week. Always pass `fields` — without it every row also carries the raw `actions` / `cost_per_action_type` arrays (~4 KB a row) and the size-bounded answer holds only about ten campaigns:
  ```
  facebook__get_ad_insights(
    shop_slug="<slug>",
    time_range={"since": "<D-14>", "until": "<D-1>"},
    time_increment=7,                                  # row 1 = previous 7 days, row 2 = last 7 days
    metric_categories=["performance", "conversion"],
    fields=["campaign_id", "campaign_name", "date_start", "date_stop", "account_currency",
            "spend", "impressions", "clicks", "ctr", "cpm", "frequency",
            "purchases", "leads", "registrations", "purchase_roas"]
  )
  ```
  `purchases` / `leads` / `registrations` are derived from `actions`; a missing key means 0. CPA = `spend` ÷ conversions.
- **Page through it:** when the answer's LAST element is a `{"_truncated": true, "_next_after": "<cursor>", ...}` marker instead of a row, drop the marker and call again with the same arguments plus `after="<cursor>"`, until an answer ends without one (at most 10 pages per shop). If it is still truncated, say the Facebook numbers are incomplete rather than presenting them as the account total
- Compare last 7 days vs previous 7 days

### Google Ads (if connected)
- `google_ads__get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")` for all active campaigns
- Remember: all monetary values in micros — divide by 1,000,000

### TikTok Ads (if connected)
- TikTok IS available via MCP under the `tiktok__` prefix. The report tool is **ID-scoped** — call `tiktok__get_tiktok_campaigns(shop_slug="<slug>")` first, then `tiktok__get_tiktok_campaign_reports(shop_slug="<slug>", campaign_ids=[...], start_date="<YYYY-MM-DD>", end_date="<YYYY-MM-DD>")` for campaign-level spend, clicks, CTR, and conversions. All three of `campaign_ids`, `start_date`, `end_date` are required — there is no "all campaigns" mode

### LinkedIn Ads (if connected)
- LinkedIn IS available via MCP under the `linkedin__` prefix — use `linkedin__get_ad_analytics(shop_slug="<slug>", ...)` for spend, clicks, CTR, and leads/CPL

### GA4
- `ga4__get_ecommerce_performance(user_prompt="revenue by source", time_range={...}, shop_slug="<slug>")` for revenue, transactions, conversion rate
- Channel attribution to calculate blended ROAS

---

## Step 2 — Calculate Blended Metrics

### Per platform:
- Total spend
- Platform-reported conversions
- Platform-reported ROAS

### Blended (using GA4 as source of truth):
- Total ad spend across all platforms
- GA4 revenue (last-click attribution)
- Blended ROAS = GA4 revenue / total ad spend
- Attribution gap per platform (platform conversions vs GA4)

---

## Step 3 — Generate Executive Summary

### Overall Verdict
Assign one of:
- **Great week** — Blended ROAS improving, spend efficient
- **Stable** — Performance in line with targets, no major changes
- **Needs attention** — One or more metrics declining significantly
- **Urgent** — Critical issues requiring immediate action (spend spikes, delivery stops, ROAS collapse)

### Top 3 Wins
Identify the 3 best-performing campaigns/ads with specific numbers:
- Campaign name, platform, key metric, WoW change
- Example: "Campaign 'Spring Sale - Retargeting' — ROAS 5.2x (up from 4.1x WoW), recommend scaling 20%"

### Top 3 Concerns
Identify the 3 biggest problems with specific data:
- Campaign name, platform, issue, severity
- Example: "Facebook 'Prospecting - Lookalike' — CPA spiked 35%, frequency at 3.8 (fatigue signal)"

### Recommended Actions
For each concern, propose a concrete next step:
- Budget change → call the owning platform's `propose_budget_change` with data-backed reasoning (pass `shop_slug="<slug>"`)
- Pause → call the owning platform's `propose_status_change` with performance justification (pass `shop_slug="<slug>"`)
- Creative refresh → flag for user action

Both proposal tools are per-platform middleware tools — namespace every call with the platform the entity lives on: `facebook__`, `google_ads__`, `tiktok__`, or `linkedin__` (e.g. `facebook__propose_budget_change`, `google_ads__propose_status_change`).


---

## Step 4 — Propose Actions via Middleware

For each recommended action that can be automated:
- Create proposals through the action middleware
- Budget scaling for winners (15-20% increase)
- Budget cuts for underperformers (15-25% decrease)
- Pauses for severe underperformers (ROAS < 50% target for 7+ days)

Note: all proposals are subject to middleware guardrails (budget caps, % limits, daily limits).

---

## Output Format

```
## [Client Name] — Week of [Date Range]

**Verdict:** [emoji] [verdict] — [one-line summary]

### Wins
1. [Platform] [Campaign] — [metric] [value] ([WoW change])
2. ...
3. ...

### Concerns
1. [Platform] [Campaign] — [issue] ([data])
2. ...
3. ...

### Actions Proposed
- [X proposals created in middleware — awaiting approval]
- [Details of each proposal]

### Key Metrics
| Platform | Spend | Conversions | ROAS | WoW Change |
|----------|-------|-------------|------|------------|
| Facebook | ... | ... | ... | ... |
| Google | ... | ... | ... | ... |
| GA4 Blended | ... | ... | ... | ... |
```

---

## Rules

1. **GA4 is the source of truth for revenue.** Always calculate blended ROAS using GA4 revenue, not platform-reported revenue. Flag the attribution gap.

2. **Opinionated, not neutral.** This is an executive brief — lead with the verdict, not raw data. Say "Great week" or "Urgent" — don't hedge.

3. **Actions must be data-backed.** Every proposal must reference specific metrics: spend, ROAS, CPA, CTR, frequency, WoW trends.

4. **Learning phase entities are excluded from recommendations.** Flag them in the report but don't judge their performance.

5. **Weekend vs weekday variance is normal.** Don't alarm on day-to-day fluctuations of ≤30%. Focus on WoW trends.
