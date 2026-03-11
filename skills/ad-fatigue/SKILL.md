---
description: Run a daily ad fatigue check across all connected advertising platforms. Detects audience exhaustion signals (rising frequency, falling CTR, rising CPC) and scores each campaign or creative with a fatigue status, severity score, and recommended action. Run every morning after the previous day's data has synced.
---

# Ad Fatigue Check

Detect whether active ads are showing signs of audience exhaustion before performance deteriorates significantly. Ad fatigue occurs when ads continue to be shown frequently, but people engage with them less over time.

## When to Run

Once per morning, after yesterday's data has fully synced from each platform (typically after 08:00 local time). Run for each active shop.

## Pre-flight

1. Confirm shop context for agency accounts — call `list_shops` + `set_shop_context` if not set
2. Determine which platforms are connected (check `connected_platforms` from `list_shops`)
3. Set date variables: D-1 = yesterday, D-2 = day before, D-3 = three days ago (YYYY-MM-DD)
4. Run each connected platform's fatigue check below, then combine into one output

---

## Meta Ads — Full Fatigue Algorithm

Meta has native frequency data. The full 10-step algorithm applies.

### Data Retrieval

```
# Step 1: 3 days of daily ad-level data
get_ad_insights(
  time_range={"since": "D-3", "until": "D-1"},
  time_increment=1,
  # Returns per day: spend, impressions, inline_link_clicks, ctr, cpc, cpm, frequency, reach
)

# Check for Learning phase ad sets — always do this first
get_adsets(campaign_id="<each_active_campaign_id>")
```

Skip any ad set with status `Learning` or `Learning Limited` — flag it in the output with ⏳ and do not evaluate. Do not make performance judgments or recommendations for learning ad sets.

Ignore any entity with zero spend on D-1.

### Algorithm (Steps 2–9)

**Step 2 — CTR calculation**
Per day: CTR = `inline_link_clicks` ÷ `impressions`
Always use `inline_link_clicks` (Link Clicks), never `clicks` (Clicks (all)).
If impressions = 0 on any day, skip fatigue evaluation for that entity.

**Step 3 — Day-over-day changes (D-2 → D-1)**
Calculate percentage change for: spend, impressions, CPM, CPC, CTR, frequency.
Skip entity if D-2 value is zero or missing.

**Step 4 — Active delivery check**
If spend ↓ OR impressions ↓ >30% from D-2 to D-1:
→ Status: `Not Fatigue` — this is a delivery or budget issue, not audience fatigue.

**Step 5 — Audience exposure**
Evaluate D-1 frequency:
- Frequency < 2.0 → fatigue unlikely
- Frequency 2.0–2.5 → potential risk
- Frequency > 2.5 → high risk

Frequency must also have increased from D-2 to D-1. If frequency did not increase → fatigue unlikely regardless of other signals.

**Step 6 — Engagement decline**
Fatigue signal present if at least one of:
- CPC increased from D-2 to D-1
- CTR decreased from D-2 to D-1

**Step 7 — Status determination**
Assign status `Fatigue` only if ALL of the following are true:
1. Ads were actively running (Step 4 passed)
2. Delivery continued normally
3. Frequency increased (Step 5)
4. Audience response weakened (Step 6)

Otherwise assign status `OK`.

**Step 8 — Severity score (0–100)**

Calculate based on the magnitude of each signal:

| Signal | Max Points | Calculation |
|---|---|---|
| CPC increase % | 25 | min(CPC_delta_pct / 2, 25) |
| CTR decrease % | 25 | min(abs(CTR_delta_pct) / 2, 25) |
| Frequency above 2.5 | 20 | if freq > 2.5: min((freq - 2.5) × 20, 20); else 0 |
| CPM increase % | 15 | min(CPM_delta_pct / 2, 15) |
| Spend increase % | 15 | min(spend_delta_pct / 2, 15) |

Score = sum of all points, capped at 100.

Severity bands:
- 0–10 → Healthy
- 10–25 → Early Warning
- 25–40 → Clear Fatigue
- >40 → Immediate Action required

**Step 9 — Sustained fatigue confirmation**
Check D-3 → D-2 using the same algorithm (Steps 4–7).
- Fatigue on both D-3→D-2 AND D-2→D-1 → `Confirmed Fatigue`
- Fatigue only on D-2→D-1 → `Temporary Signal` (watch closely)

### Meta Language Rules

All Meta metrics are modelled estimates. Use:
- "estimated frequency of ~X" not "frequency is X"
- "estimated reach of ~X" not "reached X people"
- "approximately X% CTR" not "CTR is X%"

---

## TikTok Ads — Full Fatigue Algorithm

TikTok exposes native `frequency` and `reach` metrics. The same full 10-step algorithm applies as Meta.

### Data Retrieval

```
# Step 1: Account-level overview with frequency
get_tiktok_account_reports(
  start_date="D-3",
  end_date="D-1",
  metrics=["spend", "impressions", "clicks", "ctr", "cpc", "cpm", "reach", "frequency"]
)

# Step 1b: Daily breakdown per campaign
get_tiktok_time_reports(
  start_date="D-3",
  end_date="D-1",
  time_dimension="stat_time_day",
  campaign_ids=["<active_campaign_ids>"],
  metrics=["spend", "impressions", "clicks", "ctr", "cpc", "cpm", "frequency"]
)
```

Ignore campaigns with zero spend on D-1.

### Algorithm

Apply the same Steps 2–9 as Meta, with these differences:
- No Learning phase concept — all active TikTok campaigns are evaluated
- Frequency metrics are exact (not modelled) — no qualified language needed
- TikTok CTR = `clicks` ÷ `impressions` (no link-click disambiguation needed; all TikTok clicks go to destination)
- Severity score formula is identical to Meta

Status labels and severity bands are identical to Meta.

---

## Google Ads — Trend-Based Engagement Analysis

Google Ads does not expose frequency or reach. Use engagement trend analysis instead.

### Data Retrieval

```
# Period 1: D-2 to D-1 (most recent)
get_google_ads_campaign_performance(start_date="D-2", end_date="D-1")

# Period 2: D-3 to D-2 (comparison)
get_google_ads_campaign_performance(start_date="D-3", end_date="D-2")
```

Always divide all `cost_micros` values by 1,000,000 before displaying. Never show raw micro values.

### Analysis

Per campaign, compare Period 1 vs Period 2:
- CTR Δ = (P1_CTR − P2_CTR) / P2_CTR × 100
- CPC Δ = (P1_CPC − P2_CPC) / P2_CPC × 100
- Impressions Δ = (P1_impressions − P2_impressions) / P2_impressions × 100

**Declining Engagement signal** if: CTR ↓ AND CPC ↑ AND impressions stable (±20%)

**Status labels (different from Meta/TikTok — no frequency = weaker certainty):**
- 🟢 `Stable` — no signals
- ⚠️ `Declining Engagement` — CTR ↓ + CPC ↑ + impressions stable
- 🔵 `Delivery Change` — impressions ↓ >20% (budget or quality issue, not fatigue)

No severity score — insufficient signal without frequency data.

Always include this note in Google Ads output:
> "Google Ads does not expose frequency. This is engagement trend analysis — a directional signal, not confirmed ad fatigue."

---

## LinkedIn Ads — Trend-Based Engagement Analysis

LinkedIn does not expose frequency. Use daily creative-level trend analysis.

### Data Retrieval

```
get_daily_performance_trends(
  date_range={"since": "D-3", "until": "D-1"},
  pivot="CREATIVE",
  timeGranularity="DAILY"
)
```

### Analysis

Per creative, calculate from daily data:
- CTR = clicks ÷ impressions (per day)
- CPM = (costInLocalCurrency ÷ impressions) × 1000 (per day)

Compare D-1 vs D-2:
- CTR Δ and CPM Δ

**Declining Engagement signal** if: CTR ↓ AND CPM ↑ AND impressions stable (±20%)

**Status labels:**
- 🟢 `Stable`
- ⚠️ `Declining Engagement`
- 🔵 `Delivery Change`

No severity score.

Always include this note:
> "LinkedIn does not expose frequency. This is engagement trend analysis — a directional signal, not confirmed ad fatigue."

---

## Output Format

```
## Ad Fatigue Check — [Shop] | [Date: YYYY-MM-DD]

### Meta Ads

| Campaign / Ad Set | Status | Severity | Est. Frequency | Key Signals | Action |
|---|---|---|---|---|---|
| Spring Sale — Prospecting | 🔴 Confirmed Fatigue | 46 | ~2.8 | Freq ↑, CTR ↓ −14%, CPC ↑ +22% | Replace creatives now |
| Retargeting — DPA | 🟡 Early Warning | 18 | ~2.1 | Freq ↑, CTR slightly ↓ | Prepare new creative |
| Brand Awareness | ⏳ Learning | — | — | In learning phase | Do not evaluate |
| Summer Drop | 🟢 Healthy | 4 | ~1.3 | All signals stable | No action |

**Recommended Actions:**
- **Spring Sale Prospecting (Confirmed Fatigue, severity 46):** Launch new creative or rotate existing ads immediately. Estimated frequency ~2.8 — prospecting audience is saturated. If creative library is exhausted, expand audience first.
- **Retargeting DPA (Early Warning, severity 18):** Prepare 2–3 new creative variants. Monitor for 2 more days before acting — one day of signal may be noise.

---

### TikTok Ads

| Campaign | Status | Severity | Frequency | Key Signals | Action |
|---|---|---|---|---|---|
| Summer TikTok | 🟡 Early Warning | 22 | 2.2 | Freq ↑, CTR ↓ −8% | Prepare new video creative |
| Brand TikTok | 🟢 Healthy | 5 | 1.4 | All signals stable | No action |

**Recommended Actions:**
- **Summer TikTok (Early Warning, severity 22):** Frequency at 2.2 and rising. Begin briefing new video creatives — TikTok creative lifecycles are shorter than other platforms (often 2–4 weeks).

---

### Google Ads

| Campaign | Status | CTR Δ | CPC Δ | Impressions Δ | Signal |
|---|---|---|---|---|---|
| Shopping — All Products | ⚠️ Declining Engagement | −12% | +€0.18 | +8% | Watch closely |
| Brand Search | 🟢 Stable | +0.2% | −€0.03 | +4% | None |
| PMax | 🟢 Stable | −2% | +€0.04 | +1% | None |

> Google Ads does not expose frequency. Engagement trend analysis only — directional signal, not confirmed ad fatigue.

**Recommended Actions:**
- **Shopping — All Products:** CTR down 12%, CPC up with stable impressions — possible creative fatigue or increased auction competition. Check search term report for query drift. Consider refreshing ad copy and product feed images.

---

### LinkedIn Ads

| Creative | Status | CTR Δ | CPM Δ | Impressions Δ | Signal |
|---|---|---|---|---|---|
| Whitepaper — CTO | ⚠️ Declining Engagement | −18% | +€4.20 | +6% | Watch closely |
| Demo Request — SMB | 🟢 Stable | +3% | −€1.10 | −2% | None |

> LinkedIn does not expose frequency. Engagement trend analysis only — directional signal, not confirmed ad fatigue.

**Recommended Actions:**
- **Whitepaper CTO:** CTR down 18%, CPM rising — creative may be fatiguing with the target audience. LinkedIn creative typically lasts 4–6 weeks; refresh headline and visual if it has been running longer than that.
```

---

## Recommended Actions by Severity (Meta & TikTok)

| Status | Severity | Action |
|---|---|---|
| Healthy | 0–10 | No action needed. Monitor as normal. |
| Early Warning | 10–25 | Prepare new creative now. Do not change yet — wait for Confirmed signal. |
| Clear Fatigue | 25–40 | Plan creative refresh. Brief new creative. Consider audience expansion. |
| Confirmed or Immediate | >40 or Confirmed | Act now: launch new creatives, rotate existing ads, expand targeting, reduce frequency cap, refresh messaging. |

---

## False Positive Guards

**Never mark fatigue if:**
- Spend dropped significantly (>30%) — this is a budget or delivery issue
- Impressions dropped >30% — same reason
- Frequency did not increase — no exposure growth means no fatigue

**Meta-specific:**
- Ad sets in Learning or Learning Limited status → always ⏳, never evaluated
- Single-day CPA or CTR swings ≤30% are normal volatility — not fatigue

**Google Ads-specific:**
- Impression share lost to rank or budget → not fatigue, different root cause
- All costs must be converted from micros before comparison (÷ 1,000,000)

**General:**
- One day of declining engagement = `Temporary Signal`, not `Confirmed Fatigue`
- Confirmed Fatigue requires the same signals on two consecutive day-over-day comparisons

---

## Platform Coverage Summary

| Platform | Frequency | Algorithm | Status Labels |
|---|---|---|---|
| Meta | ✅ Native (modelled) | Full 10-step | Confirmed Fatigue / Temporary Signal / OK / Not Fatigue |
| TikTok | ✅ Native (exact) | Full 10-step | Same as Meta |
| Google Ads | ❌ Not available | Trend-based | Declining Engagement / Stable / Delivery Change |
| LinkedIn | ❌ Not available | Trend-based | Declining Engagement / Stable / Delivery Change |
