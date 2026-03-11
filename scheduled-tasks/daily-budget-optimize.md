# Daily Budget Optimization — Scheduled Task

**Schedule:** Every weekday at 10:00 AM (Mon-Fri)
**Cron:** `0 10 * * 1-5`
**Skills Used:** `/adup:optimize-budget`, `/adup:manage-status`
**Output:** Proposals via action middleware (budget increase/decrease/pause)

---

## What It Does

Runs after the morning monitoring tasks (pacing at 6:30, fatigue at 7:00). Analyzes campaign performance across all clients and proposes budget reallocations — scaling winners and cutting losers. The core optimization engine of the daily workflow.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull performance data** from all connected platforms:
      - Facebook: `get_campaign_performance_metrics` for last 14 days + `get_ad_insights` with `time_increment=7` for WoW trend
      - Google: `get_google_ads_campaign_performance` for last 14 days (micros / 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` for last 14 days
      - LinkedIn: campaign analytics for last 14 days
      - GA4: `get_ecommerce_performance` for blended ROAS
   c. **Classify each campaign:**
      - **Winners** (increase budget): ROAS above target for 5+ days, CPA below target, 15+ conversions, improving/stable WoW, NOT in learning phase
      - **Losers** (decrease budget): ROAS below target for 5+ days, CPA >130% of target, declining WoW trends, sufficient data (10+ conversions)
      - **Hold** (no action): Learning phase, insufficient data, stable near target
   d. **For Winners:**
      - Propose 15-20% budget increase via `propose_budget_change`
      - Reasoning: cite ROAS, CPA, conversion volume, WoW trend
   e. **For Losers:**
      - Propose 15-25% budget decrease via `propose_budget_change`
      - If sustained poor performance (7+ days, <50% ROAS target): propose PAUSE via `propose_status_change`
   f. **Frame as reallocation when possible:**
      - "Move $50/day from Campaign A (1.2x ROAS) to Campaign B (3.8x ROAS)"
      - Budget-neutral shifts are more compelling than raw increases
3. **Summary per client:**
   - Total proposed increase / decrease / net change
   - Expected impact: "If trends hold, reallocation should improve blended ROAS from X to ~Y"

## Output Format

```
## Budget Optimization — [Date] 10:00

### [Client Name]

#### Winners (scale)
| Campaign | Platform | ROAS | CPA | Conv. | WoW Trend | Proposed |
|----------|----------|------|-----|-------|-----------|----------|
| Retargeting US | Facebook | 4.8x | $22 | 87 | +12% ROAS | +20% budget |
| Brand Search | Google | 6.1x | $8 | 312 | Stable | +15% budget |

#### Losers (cut)
| Campaign | Platform | ROAS | CPA | Conv. | WoW Trend | Proposed |
|----------|----------|------|-----|-------|-----------|----------|
| Prospecting Cold | Facebook | 1.2x | $65 | 14 | -22% ROAS | -25% budget |
| Display Awareness | Google | 0.8x | $140 | 3 | -35% ROAS | Pause |

#### Hold (no action)
- "New Spring Campaign" — Learning phase (day 4/7), excluded
- "LinkedIn Decision Makers" — 4 conversions, insufficient data

Net change: +$40/day reallocation from losers to winners
Expected impact: Blended ROAS improvement from 3.1x to ~3.5x

### Cross-Client Summary
- Proposals created: 8 (4 increases, 3 decreases, 1 pause)
- Clients with strong performance: 3
- Clients needing attention: 1
```

## Rules

1. **Minimum data requirement.** Never propose budget changes based on <7 days of data or <10 conversions.
2. **Learning phase protection.** Never propose changes to campaigns in Learning or Learning Limited.
3. **Breakdown Effect.** Do not reallocate based on segment-level CPA differences. Evaluate at campaign level.
4. **Google Ads micros.** Always divide by 1,000,000 before calculating or displaying.
5. **Budget-neutral framing.** When possible, present as reallocation (move from A to B) rather than isolated increases/decreases.
6. **All proposals go through middleware.** Budget caps, percentage limits, and daily limits enforced per shop configuration.
7. **State the uncertainty.** Frame as "based on current data" — performance is probabilistic.
8. **Don't duplicate morning findings.** If the 6:30 pacing check or 7:00 fatigue scan already created proposals for a campaign, don't create conflicting proposals. Reference the morning findings instead.
