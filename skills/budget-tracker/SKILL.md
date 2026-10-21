---
name: budget-tracker
description: Monitor budget pacing across Facebook Ads campaigns. Identifies overpacing and underpacing campaigns, calculates projected spend vs budgets, and proposes budget adjustments when pacing is significantly off track.
---

# Budget Pacing Analysis

## Pre-flight
- Resolve shop context in all three steps: (1) `list_shops` to see the brands and their connected platforms, (2) `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**, an agency key sees only the six virtual tools until a shop is active, (3) pass `shop_slug="<slug>"` explicitly on every data/action call below
- Default period: current month. State the assumption if user doesn't specify
- Call connector tools directly by name (`facebook__<tool>`, `list_shops`). A tool search that finds no matching deferred tools only means the tools are already loaded or named differently, never that the connector dropped. Report the connector as disconnected only after a real connector call such as `list_shops` fails, and quote that error. **Sign-in needed:** if no adup tools are available (no `list_shops`, no `<platform>__` tools) or a call fails with an authentication error (`-32001` authentication required, `invalid_token`, "requires authentication", "needs authentication"), the adup connector is not signed in on this machine. Say that plainly, tell the user to sign in (Claude Code: `/mcp` → adup → Authenticate; terminal: `claude mcp login plugin:adup:adup`, with `--no-browser` on a machine without a browser; machines that cannot sign in: the automation connector; full steps: `/adup:setup`), and stop instead of reporting empty data, a disconnect or a generic failure. **Platforms per brand:** call a platform for a brand only when it is in that brand's `connected_platforms` from `list_shops`; a "not connected for brand" answer means skip that platform for that brand and name it in the report, never fail the run.

---

## Step 1 — Pull Pacing Data

**Start with the server-side pacing tool.** `facebook__get_budget_pacing` computes spend-vs-expected
upstream, so prefer it over re-deriving pacing by hand:

```
facebook__get_budget_pacing(shop_slug="<slug>", date_range="this_month")
```

`date_range` here is a **plain string** — `"this_month"`, `"last_30d"`, `"this_week"` — **not** the
`{"since": …, "until": …}` object the insight tools take. Sibling Facebook tools disagree on this;
check the schema rather than assuming.

Fall back to computing it yourself when you need per-campaign detail the pacing tool doesn't
return, or if it is unavailable:

- `facebook__get_campaign_performance_metrics` with
  `time_range`: `{"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}` for the current month, and
  `shop_slug` always passed explicitly.
- Cross-reference with `facebook__get_campaigns(shop_slug="<slug>")` to get daily budgets per
  campaign, then compare actual spend vs expected spend at this point in the month.

---

## Step 2 — Present Pacing Report

### Summary
- Total budget across all campaigns
- Total spent so far
- Overall pacing status: on track / underpacing / overpacing
- Days remaining in period

### Per-Campaign Table
| Campaign | Budget | Spent | Utilization | Run Rate | Projected | Status |
|----------|--------|-------|-------------|----------|-----------|--------|

**Status key:**
- **On Track** (90-110% of expected utilization at this point)
- **Underpacing** (< 90%) — spending less than expected
- **Overpacing** (> 110%) — spending more than expected

---

## Step 3 — Propose Adjustments

### Overpacing (> 115%)
- Propose **budget decrease** via `facebook__propose_budget_change(shop_slug="<slug>", ...)`
- Calculate the adjustment needed to bring pacing back to 100%
- Reasoning: *"Campaign 'Retargeting US' is pacing at 132% of budget — projected to exhaust $5,000 budget by the 22nd. Recommend reducing daily budget from $180 to $150 to pace through month-end."*

### Severe Overpacing (> 150%)
- Flag as urgent — budget may exhaust mid-period
- Propose immediate reduction to align with remaining budget
- Calculate: remaining_budget / remaining_days = target daily spend

### Underpacing (< 85%)
- Alert user — campaigns may not spend their allocated budget
- Possible causes: audience too narrow, bids too low, ad fatigue
- Optionally propose budget increase if performance is strong (ROAS/CPA on target)
- Only propose increase if performance metrics justify it

### On Track (90-110%)
- No action needed — report and move on

---

## Rules

1. **Always check performance alongside pacing.** Overpacing with great ROAS is less concerning than overpacing with poor ROAS. If ROAS is above target, consider letting it run.

2. **Budget change proposals are governed by middleware.** Max percentage change, absolute limits, and monthly budget caps are enforced by the shop's auto-approval rules — not hardcoded here.

3. **State current and proposed values clearly.** Every budget proposal must include: current daily budget, proposed daily budget, percentage change, and reasoning.

4. **Consider seasonality.** Weekend vs weekday spend patterns can cause false pacing alerts. Note if the analysis period includes weekends with different spend profiles.
