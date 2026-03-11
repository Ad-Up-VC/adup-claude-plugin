# TikTok Ads Optimization — Scheduled Task

**Schedule:** Tuesday and Thursday at 9:30 AM
**Cron:** `30 9 * * 2,4`
**Skills Used:** `/adup:tiktok-optimize`
**Output:** Proposals via action middleware (budget, status changes)

---

## What It Does

Twice-weekly optimization of TikTok Ads accounts. TikTok creative fatigue is the fastest of any platform (7-14 days), so biweekly checks are essential. Focuses on video engagement metrics — hook rate and completion rates are the primary signals, not just CPA/ROAS.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client (TikTok Ads connected only):**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull performance data:**
      - `get_tiktok_campaign_reports` for last 14 days with campaign IDs
      - `get_tiktok_adgroup_reports` for ad group-level detail
      - `get_tiktok_ad_reports` for ad-level with video engagement
      - `get_tiktok_video_reports` for detailed completion metrics (2s/6s views, P25-P100)
   c. **Evaluate key metrics per ad group:**
      - Hook rate (3s views / impressions) — creative stopping power
      - P25/P50/P75/P100 completion rates — content retention
      - CTR, conversions, CPA, ROAS
      - WoW trends on all metrics
   d. **Identify opportunities:**
      - **Budget increase:** Hook rate >30%, good CPA/ROAS, 10+ conversions, stable WoW
      - **Budget decrease:** Hook rate <20%, poor CPA/ROAS, declining trends
      - **Pause:** Zero conversions with >$100 spent, hook rate <10%, CPA >2x target for 7+ days
   e. **Creative fatigue (TikTok-specific):**
      - Flag ads with hook rate declining >25% from first-week performance
      - Any ad running 14+ days with declining metrics = creative refresh needed
      - TikTok audiences expect freshness — recommend new angles, not minor edits
   f. **Create proposals:**
      - Budget: `propose_budget_change` (entity_type: "campaign" or "adgroup")
      - Status: `propose_status_change` (ENABLE/DISABLE — TikTok uses these)
3. **Summary** — Average hook rate, top/bottom performers, creative refresh list

## Output Format

```
## TikTok Optimization — [Date] 09:30

### [Client Name]

#### Ad Group Performance (14 days)
| Ad Group | Spend | Hook Rate | P100 | CTR | Conv. | CPA | ROAS | WoW |
|----------|-------|-----------|------|-----|-------|-----|------|-----|
| Spring Launch | $2,400 | 38% | 12% | 1.8% | 45 | $53 | 3.2x | +8% |
| Product Demo | $1,800 | 15% | 4% | 0.6% | 8 | $225 | 0.7x | -22% |

#### Creative Fatigue Alerts
- "Product Demo" — hook rate dropped from 28% to 15% over 10 days. Creative exhausted.
- "UGC Review V2" — 16 days live, hook rate declining. Prepare replacement.

#### Proposals
- Increase "Spring Launch" budget +20% (strong hook rate, ROAS above target)
- Pause "Product Demo" (hook rate 15%, CPA 4.2x target, declining)
- Flag: 2 ads need creative refresh within 7 days

Account average hook rate: 26% (benchmark: 20-30% = average)
```

## Rules

1. **TikTok uses ENABLE/DISABLE, not ACTIVE/PAUSED.** Always use correct status values.
2. **Hook rate is #1 signal.** Low hook rate = first 3 seconds aren't working. No budget fix for bad creative.
3. **Creative fatigue is faster.** Expect 7-14 day lifespan. Proactively flag ads approaching 14 days with declining hooks.
4. **Don't compare with Facebook/Google.** TikTok has its own engagement patterns and benchmarks.
5. **Spark Ads are read-only.** Analyze for insights but don't propose changes to Spark Ad campaigns.
6. **Budget modes matter.** BUDGET_MODE_DAY vs BUDGET_MODE_TOTAL — the tool auto-detects.
7. **Learning phase protection.** Don't propose changes during first 7 days or before 50 conversions.
8. **All proposals go through middleware.** Budget caps and limits enforced per shop.
