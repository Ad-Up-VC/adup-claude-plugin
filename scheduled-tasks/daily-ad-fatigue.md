# Daily Ad Fatigue Scan — Scheduled Task

**Schedule:** Every day at 7:00 AM (Mon-Sun)
**Cron:** `0 7 * * *`
**Skills Used:** `/adup:ad-fatigue`, `/adup:manage-status`
**Output:** Proposals via action middleware (pause/budget decrease)

---

## What It Does

Scans all active ads across every client for creative fatigue signals. Catches declining performance early — before a fatigued ad wastes the day's budget. Creates proposals to pause HIGH fatigue ads and reduce budgets on MEDIUM fatigue ad sets.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Facebook/Instagram Ads** (if connected):
      - Call `detect_ad_fatigue(lookback_days=14, frequency_threshold=3.0)` if available
      - OR manually pull: `get_ad_insights` with `time_increment=7` for last 14 days to get WoW trends
      - Check per ad: frequency, CTR trend, CPA trend, spend
      - Score each ad: HIGH / MEDIUM / LOW fatigue
   c. **Google Ads** (if connected):
      - Pull `get_google_ads_ad_performance` for last 14 days
      - Check CTR and CPA trends WoW
      - Flag ads with sustained CTR decline >20% or CPA increase >25%
   d. **TikTok Ads** (if connected):
      - Pull `get_tiktok_ad_reports` + `get_tiktok_video_reports` for last 14 days
      - Check hook rate trend (3s views / impressions)
      - TikTok fatigue is faster — flag at 7 days of decline instead of 14
   e. **Score and act:**
      - **HIGH fatigue** (frequency >3.0 AND CTR decline >20% OR CPA increase >25%):
        - Propose PAUSE via `propose_status_change`
        - Reasoning: cite frequency, CTR trend, CPA trend, spend wasted
      - **MEDIUM fatigue** (frequency >3.0 OR significant CTR/CPA deterioration):
        - Propose 15-20% budget decrease on parent ad set via `propose_budget_change`
      - **LOW fatigue** (early warning signals):
        - Log for monitoring, no action
3. **Summary** — Total fatigued ads found, proposals created, ads in learning (skipped)

## Output Format

```
## Ad Fatigue Scan — [Date] 07:00

### [Client Name]

| Ad | Platform | Severity | Freq | CTR Trend | CPA Trend | Action |
|----|----------|----------|------|-----------|-----------|--------|
| Summer Sale V3 | Facebook | HIGH | 4.2 | -28% WoW | +32% WoW | Propose pause |
| Lookalike Video | Facebook | MEDIUM | 3.4 | -12% WoW | +18% WoW | Budget -15% |
| Spring Hook | TikTok | HIGH | — | Hook -35% | +40% WoW | Propose pause |

Proposals: 2 pause, 1 budget decrease
Skipped: 3 ads in Learning phase

### Cross-Client Summary
- HIGH fatigue: 4 ads (3 pause proposals, 1 already paused)
- MEDIUM fatigue: 7 ads (5 budget decrease proposals)
- LOW fatigue: 12 ads (monitoring only)
- Learning phase: 6 ads (skipped)
```

## Rules

1. **Never touch Learning phase ads.** If an ad or its parent ad set is in Learning or Learning Limited, skip it regardless of fatigue signals.
2. **Check at ad set level first.** If ALL ads in an ad set are fatigued, the issue is audience saturation — propose pausing or reducing at the ad set level, not individual ads.
3. **Breakdown Effect applies.** Don't recommend actions based solely on segment-level metrics.
4. **TikTok fatigue is faster.** Use 7-day lookback for TikTok (not 14). Hook rate decline >25% from first-week performance = immediate flag.
5. **Always suggest what comes next.** After proposing pauses, note: "Prepare replacement creatives targeting the same audience."
6. **All proposals go through middleware.** Max percentage change, daily limits, budget caps enforced per shop configuration.
7. **Minimum data requirement.** Only flag ads with at least 1,000 impressions and 7 days of delivery data.
