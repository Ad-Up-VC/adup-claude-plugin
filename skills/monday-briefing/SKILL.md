---
name: monday-briefing
description: Generate a per-client executive briefing for the start of the week. Pulls last 7 days vs previous 7 days from all connected platforms, calculates blended ROAS via GA4, delivers an opinionated summary with wins, concerns, and proposed actions.
---

# Monday Morning Briefing

## Pre-flight
- Confirm shop context — for agencies, iterate through all active shops
- Period: last 7 days vs previous 7 days
- Pull data from ALL connected platforms per shop

---

## Step 1 — Pull Cross-Platform Data

For each active shop, pull performance data from all connected platforms:

### Facebook Ads
- `get_campaign_insights` with fields: campaign_name, spend, impressions, clicks, actions, cost_per_action_type, ctr, frequency
- Compare last 7 days vs previous 7 days

### Google Ads
- `get_campaign_performance` for all active campaigns
- Remember: all monetary values in micros — divide by 1,000,000

### TikTok Ads (if connected)
- `get_tiktok_campaign_reports` for last 7 days
- Include hook rate (3s views / impressions) for video content

### LinkedIn Ads (if connected)
- Campaign performance with CPL focus

### GA4
- `get_ecommerce_performance` for revenue, transactions, conversion rate
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
- Budget change → call `propose_budget_change` with data-backed reasoning
- Pause → call `propose_status_change` with performance justification
- Creative refresh → flag for user action

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
