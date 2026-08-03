---
name: optimize-budget
description: Analyse campaign performance to identify budget reallocation opportunities. Proposes increasing budgets on strong performers and decreasing budgets on underperformers, all through the action middleware with data-backed reasoning.
---

# Budget Optimization

## Pre-flight
- Resolve shop context in all three steps: (1) `list_shops` to see the brands and their connected platforms, (2) `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**, an agency key sees only the six virtual tools until a shop is active, (3) pass `shop_slug="<slug>"` explicitly on every data/action call below
- Default lookback: last 14 days. State the assumption
- Pull GA4 data alongside platform data when available for blended ROAS

---

## Step 1 — Analyse Performance

Pull campaign-level performance data using the namespaced platform read tools:
- Facebook: `facebook__get_campaign_performance_metrics(time_range={...}, shop_slug="<slug>")` for campaign-level spend, clicks, CTR, CPC, purchases, ROAS
- Google: `google_ads__get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")` — remember to divide micros by 1,000,000
- TikTok: `tiktok__*` report tools with `shop_slug="<slug>"`; LinkedIn: `linkedin__*` campaign tools with `shop_slug="<slug>"`
- Compare last 7 days vs previous 7 days for trend

### Key metrics per campaign:
- Spend
- ROAS (platform-reported and GA4 blended if available)
- CPA
- CTR
- Conversion volume
- Week-over-week trends

---

## Step 2 — Classify Campaigns

### Winners (candidates for budget increase)
- ROAS above target consistently (5+ days)
- CPA below target
- Sufficient conversion volume (minimum 15-20 conversions in period)
- Not in Learning phase
- Improving or stable WoW trends

### Losers (candidates for budget decrease)
- ROAS below target consistently (5+ days)
- CPA significantly above target (> 130%)
- Declining trends WoW
- Sufficient data to be conclusive (avoid cutting on < 10 conversions)

### Hold (no action)
- In Learning phase — do not touch
- Insufficient data to decide
- Stable performance near target

---

## Step 3 — Propose Reallocations

`propose_budget_change` and `propose_status_change` exist on **several** platforms, so the bare name is ambiguous — always call the platform-specific one that owns the campaign, with an explicit `shop_slug`:
`facebook__propose_budget_change` / `google_ads__propose_budget_change` / `tiktok__propose_budget_change` / `linkedin__propose_budget_change`, and likewise `facebook__propose_status_change` / `google_ads__propose_status_change` / `tiktok__propose_status_change` / `linkedin__propose_status_change`.

### For each Winner:
- Call `<platform>__propose_budget_change(shop_slug="<slug>", ...)` to increase budget
- Suggest 15-20% increase (respect scaling best practices)
- Reasoning: cite ROAS, CPA, trend data, conversion volume

### For each Loser:
- Call `<platform>__propose_budget_change(shop_slug="<slug>", ...)` to decrease budget
- Suggest 15-25% decrease
- If sustained poor performance (7+ days, < 50% of ROAS target): consider proposing pause via `<platform>__propose_status_change(shop_slug="<slug>", ...)`

### Budget-neutral approach:
- When possible, frame as reallocation: "Move $50/day from Campaign A (1.2x ROAS) to Campaign B (3.8x ROAS)"
- Total budget stays the same, allocation improves

---

## Step 4 — Summary

Present a clear summary:
- Total proposed budget increase (across winners)
- Total proposed budget decrease (across losers)
- Net change
- Expected impact: "If trends hold, this reallocation should improve blended ROAS from X to approximately Y"

---

## Rules

1. **Minimum data requirement.** Never propose budget changes based on < 7 days of data or < 10 conversions. Flag insufficient data and recommend waiting.

2. **Learning phase protection.** Never propose changes to campaigns in Learning or Learning Limited. Flag them and note expected exit date if available.

3. **Breakdown Effect applies.** Do not reallocate based on segment-level CPA differences. Evaluate at campaign level.

4. **All proposals go through middleware.** Max percentage change, budget caps, and daily limits are enforced per shop configuration.

5. **State the uncertainty.** Performance is probabilistic. Frame recommendations as "based on current data" rather than guarantees.
