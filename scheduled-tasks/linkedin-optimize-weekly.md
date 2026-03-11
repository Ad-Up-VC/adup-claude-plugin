# LinkedIn Ads Optimization — Scheduled Task

**Schedule:** Wednesday at 9:00 AM
**Cron:** `0 9 * * 3`
**Skills Used:** `/adup:linkedin-optimize`
**Output:** Proposals via action middleware (budget, status, creative updates)

---

## What It Does

Weekly optimization of LinkedIn Ads accounts for B2B clients. LinkedIn has lower volume than Facebook/Google, so weekly cadence is sufficient. Focuses on CPL efficiency, creative performance, and audience quality — not just raw volume.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client (LinkedIn Ads connected only):**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull performance data:**
      - Campaign-level: spend, impressions, clicks, CTR, conversions, CPL
      - Creative-level: engagement (likes, comments, shares), CTR per creative
      - Compare last 7 days vs previous 7 days for WoW trends
   c. **Identify opportunities:**
      - **Budget increase candidates:** CPL below target consistently, 5+ leads/week, improving trends
      - **Budget decrease candidates:** CPL >130% of target, declining trends, low engagement
      - **Pause candidates:** Zero leads with $200+ spent, CPL >2x target for 7+ days, frequency >4
   d. **Creative analysis:**
      - Identify low-CTR creatives (below 0.4% for Sponsored Content)
      - Compare headline and description performance across creatives
      - Propose copy updates for underperformers based on high-performer patterns
   e. **Create proposals:**
      - Budget: `propose_budget_change` (entity_type: "campaign" or "campaign_group")
      - Status: `propose_status_change` (ACTIVE/PAUSED)
      - Creative: `propose_creative_update` (headline and/or description)
3. **Summary** — Average CPL vs target, proposals created, creative refresh recommendations

## Output Format

```
## LinkedIn Optimization — [Date] 09:00

### [Client Name]

#### Campaign Performance (7 days)
| Campaign | Spend | Leads | CPL | CTR | Eng. Rate | WoW Trend |
|----------|-------|-------|-----|-----|-----------|-----------|
| Decision Makers | $1,200 | 8 | $150 | 0.52% | 1.8% | CPL -12% |
| Awareness Content | $800 | 3 | $267 | 0.71% | 2.4% | CPL +28% |

#### Proposals
- Increase "Decision Makers" budget +15% (CPL improving, below $160 target)
- Decrease "Awareness Content" budget -20% (CPL 67% above target, declining)
- Update creative headline on "Awareness Content" — current CTR 0.71%, propose testing question-format headline

Average CPL: $180 (target: $160) — improving WoW
```

## Rules

1. **LinkedIn is B2B context.** Think CPL and lead quality, not ROAS.
2. **Small data sets are common.** Don't over-optimize on <5 conversions. Require minimum 5 leads before proposing budget cuts.
3. **Audience quality > volume.** Higher CPL targeting decision-makers may be more valuable. Flag this context.
4. **Creative fatigue: refresh every 4-6 weeks** for active campaigns. Professional audiences see the same content repeatedly.
5. **Campaign groups are top-level.** Budget changes at campaign group level affect all campaigns within.
6. **All proposals go through middleware.** Budget caps and limits enforced per shop.
