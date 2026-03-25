---
name: linkedin-optimize
description: Propose LinkedIn Ads optimizations through the action middleware. Covers campaign and campaign group budget changes, status changes, and creative copy updates based on engagement and CPL performance.
---

# LinkedIn Ads Optimization

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- Default lookback: 14 days. State the assumption if user doesn't specify
- Pull campaign-level performance data from LinkedIn Ads MCP tools
- LinkedIn is typically B2B — benchmark CPL between $50-$150 depending on industry

---

## Step 1 — Analyse Performance

Pull performance data using LinkedIn Ads read tools:
- Campaign-level: spend, impressions, clicks, CTR, conversions, CPL
- Creative-level: engagement (likes, comments, shares), CTR per creative
- Compare last 7 days vs previous 7 days for trends

### Key metrics per campaign:
| Metric | What it shows |
|--------|---------------|
| Spend | Total spend in period |
| Leads / Conversions | Conversion volume |
| CPL | Cost per lead — primary efficiency metric for B2B |
| CTR | Creative relevance and audience targeting quality |
| Engagement Rate | Likes + comments + shares / impressions |
| Frequency | How often the same person sees the ad |
| WoW Trend | Direction of performance |

---

## Step 2 — Identify Opportunities

### Budget Reallocation
- **Increase candidates:** CPL below target consistently, sufficient lead volume (5+ leads/week), improving trends
- **Decrease candidates:** CPL significantly above target (> 130%), declining trends, low engagement
- **Hold:** Campaigns with < 5 conversions — insufficient data for conclusions

### Status Changes
- **Pause candidates:** Zero leads with $200+ spent, CPL > 2x target for 7+ days, audience exhausted (frequency > 4)
- **Activate candidates:** Previously paused campaigns with seasonal relevance

### Creative Optimisation
- Identify low-CTR creatives (below 0.4% for Sponsored Content)
- Compare headline and description performance across creatives
- Propose copy updates for underperformers based on patterns from high performers

---

## Step 3 — Propose Changes

### Budget Changes
Call `propose_budget_change` (LinkedIn Ads) for each candidate:
- `entity_type`: "campaign" or "campaign_group"
- `new_budget`: in account currency (e.g., 50.0 for $50)
- LinkedIn uses `dailyBudget` or `totalBudget` — the tool auto-detects which one the entity uses
- **Winners:** Propose 15-20% budget increase
- **Losers:** Propose 15-25% budget decrease

### Status Changes
Call `propose_status_change` (LinkedIn Ads) for each candidate:
- `entity_type`: "campaign" or "campaign_group"
- `new_status`: "ACTIVE" or "PAUSED"
- Reasoning must cite CPL, conversion volume, trend data

### Creative Updates
Call `propose_creative_update` (LinkedIn Ads) for underperforming creatives:
- Provide `creative_id`, `headline` (new headline), `description` (new description)
- At least one of headline or description must be provided
- Base new copy on patterns from high-performing creatives in the account

---

## Step 4 — Summary

Present a clear summary:
- Number of proposals created (budget, status, creative)
- Current average CPL vs target CPL
- Expected impact of changes on lead volume and CPL
- Flag any campaigns with insufficient data for recommendations

---

## Rules

1. **LinkedIn is B2B context.** Think in terms of lead quality and CPL, not ROAS. A $100 CPL can be excellent for enterprise software but terrible for a SaaS free trial.

2. **Small data sets are common.** LinkedIn campaigns often have low volume — don't over-optimise on 3 leads. Require minimum 5 conversions before proposing budget cuts.

3. **Audience quality matters more than volume.** A campaign with higher CPL but targeting decision-makers may be more valuable than a cheap campaign reaching junior staff. Flag this context.

4. **Creative fatigue is real on LinkedIn.** Professional audiences see the same content repeatedly. Recommend creative refresh every 4-6 weeks for active campaigns.

5. **Campaign groups are LinkedIn's top-level entity.** Similar to Facebook campaign budget optimisation — budget changes at campaign group level affect all campaigns within.

6. **All proposals go through middleware.** Budget caps, percentage limits, and daily auto-approval limits are enforced by the shop's auto-approval rules.

7. **LinkedIn API uses dailyBudget and totalBudget.** The proposal tool handles both — it detects which type the entity uses and proposes accordingly.
