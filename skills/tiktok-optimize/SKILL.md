---
name: tiktok-optimize
description: Propose TikTok Ads optimizations through the action middleware. Covers campaign and ad group budget changes, and status changes (pause/enable) based on video engagement metrics, hook rates, and conversion performance.
---

# TikTok Ads Optimization

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- Default lookback: 14 days. State the assumption if user doesn't specify
- Pull campaign and ad group data from TikTok Ads MCP tools
- TikTok is video-first — hook rate and completion rates are critical metrics

---

## Step 1 — Analyse Performance

Pull performance data using TikTok Ads read tools:
- `get_tiktok_campaign_reports` for campaign-level metrics
- `get_tiktok_adgroup_reports` for ad group-level metrics
- `get_tiktok_ad_reports` for ad-level with video engagement
- `get_tiktok_video_reports` for detailed video metrics (2s/6s views, P25-P100 completion)

### Key metrics per campaign/ad group:
| Metric | What it shows |
|--------|---------------|
| Spend | Total spend in period |
| Impressions | Delivery volume |
| Hook Rate | 3-second views / impressions — creative stopping power |
| P25/P50/P75/P100 | Video completion rates — content retention |
| CTR | Click-through rate to destination |
| Conversions | Actions taken (purchase, lead, install) |
| CPA | Cost per conversion |
| ROAS | Return on ad spend (if e-commerce) |
| WoW Trend | Direction of performance |

### TikTok-Specific Benchmarks
| Metric | Good | Average | Poor |
|--------|------|---------|------|
| Hook Rate (3s) | > 30% | 20-30% | < 20% |
| P25 Completion | > 50% | 30-50% | < 30% |
| P100 Completion | > 15% | 8-15% | < 8% |
| CTR | > 1.5% | 0.8-1.5% | < 0.8% |

---

## Step 2 — Identify Opportunities

### Budget Reallocation
- **Increase candidates:** Strong hook rate (>30%), good ROAS/CPA, sufficient conversions (10+), stable or improving WoW
- **Decrease candidates:** Low hook rate (<20%), poor CPA/ROAS, declining engagement trends
- **Hold:** Campaigns with < 7 days of data or < 5 conversions

### Status Changes
- **Pause candidates:** Zero conversions with significant spend (>$100), hook rate < 10% (creative not resonating), CPA > 2x target sustained for 7+ days
- **Enable candidates:** Previously paused campaigns/ad groups that align with new creative strategy

### Creative Fatigue (TikTok-Specific)
TikTok creative fatigue is **faster** than other platforms — typically 7-14 days for high-spend campaigns:
- Monitor hook rate decline over daily/weekly trend
- If hook rate drops > 25% from first-week performance → flag for creative refresh
- Recommend new creative angles, not just minor edits — TikTok audiences expect freshness

---

## Step 3 — Propose Changes

### Budget Changes
Call `propose_budget_change` (TikTok Ads) for each candidate:
- `entity_type`: "campaign" or "adgroup"
- `entity_id`: TikTok campaign/ad group ID
- `new_budget`: in account currency (e.g., 50.0 for $50)
- `budget_mode`: the tool auto-detects BUDGET_MODE_DAY or BUDGET_MODE_TOTAL
- **Winners:** Propose 15-20% budget increase
- **Losers:** Propose 15-25% budget decrease

### Status Changes
Call `propose_status_change` (TikTok Ads) for each candidate:
- `entity_type`: "campaign", "adgroup", or "ad"
- `entity_id`: TikTok entity ID
- `new_status`: "ENABLE" or "DISABLE" (TikTok uses these instead of ACTIVE/PAUSED)
- Reasoning must cite hook rate, completion rates, CPA/ROAS, trend data

---

## Step 4 — Summary

Present a clear summary:
- Number of proposals created (budget, status)
- Average hook rate across account
- Top 3 performing ad groups by hook rate and conversion rate
- Bottom 3 ad groups flagged for action
- Creative refresh recommendations (which ads need new video content)

---

## Rules

1. **TikTok uses ENABLE/DISABLE, not ACTIVE/PAUSED.** Always use the correct TikTok status values in proposals.

2. **Hook rate is the #1 creative signal.** A low hook rate means the first 3 seconds aren't working — no amount of budget will fix bad creative. Flag this to the user as a creative issue, not a targeting issue.

3. **Creative fatigue is faster on TikTok.** Expect 7-14 day creative lifespan for high-spend ad groups. Proactively flag ads approaching 14 days with declining hook rates.

4. **Don't compare TikTok metrics with Facebook/Google.** Each platform has its own engagement patterns. TikTok CTRs are typically higher than Facebook but conversion rates may differ. Evaluate TikTok within its own benchmarks.

5. **Spark Ads (boosted organic) are read-only for now.** Analyse their performance for insights but don't propose changes to Spark Ad campaigns — they have different controls.

6. **Budget modes matter.** TikTok uses BUDGET_MODE_DAY and BUDGET_MODE_TOTAL. The proposal tool detects which one is in use. Don't mix them.

7. **All proposals go through middleware.** Budget caps, percentage limits, and daily auto-approval limits are enforced by the shop's auto-approval rules.

8. **Learning phase protection.** TikTok ad groups in the "Learning" phase need 50 conversions or 7 days before reliable optimisation. Don't propose changes during learning.
