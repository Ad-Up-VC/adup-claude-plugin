---
description: Propose pausing or activating Facebook Ads campaigns, ad sets, and ads through the action middleware. Evaluates performance data to justify status changes with data-backed reasoning. Never changes entities in learning phase.
---

# Status Management (Pause / Activate)

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- Default lookback: 14 days. State the assumption if user doesn't specify

---

## Step 1 — Evaluate Current Performance

Pull entity-level performance data before proposing any status change:

### For campaigns/ad sets:
- Use `get_campaign_insights` or `get_adset_insights` with fields: campaign_name, spend, impressions, clicks, actions, cost_per_action_type, ctr
- Check learning phase status via `get_adsets` — **never propose changes to entities in Learning or Learning Limited**

### For individual ads:
- Use `get_ad_insights` with fields: ad_name, spend, impressions, clicks, actions, cost_per_action_type, ctr
- Check parent ad set status for learning phase

---

## Step 2 — Determine if Status Change is Justified

### Candidates for PAUSING (ACTIVE → PAUSED)

| Signal | Threshold | Data Requirement |
|--------|-----------|-----------------|
| Zero conversions with significant spend | Spend > 3× target CPA with 0 conversions | ≥ 7 days of data |
| Sustained poor ROAS | ROAS < 50% of target for 7+ consecutive days | ≥ 15 conversions in period |
| Severe creative fatigue | Frequency > 5.0 AND CTR declining > 30% WoW | ≥ 7 days of data |
| CPA explosion | CPA > 200% of target for 5+ consecutive days | ≥ 10 conversions in period |
| Budget waste | Spending full budget with 0 meaningful actions | ≥ 7 days of data |

### Candidates for ACTIVATING (PAUSED → ACTIVE)

| Signal | Threshold | Context |
|--------|-----------|---------|
| Seasonal relevance | Campaign was paused for off-season, now relevant | User confirms timing |
| Fixed root cause | Landing page fixed, creative refreshed, audience updated | User confirms changes |
| Testing restart | Re-testing after optimization changes | User confirms intent |

### NEVER change status when:
- Entity is in **Learning** or **Learning Limited** phase
- Insufficient data (< 7 days or < 10 conversions for pause decisions)
- Inside a CBO campaign — evaluate at campaign level, not ad set level
- The entity was paused for a known reason (seasonal, pending creative)

---

## Step 3 — Propose Status Change

### For each justified pause:
- Call `propose_status_change` with:
  - `entity_type`: "campaign", "adset", or "ad"
  - `entity_id`: the Facebook ID
  - `new_status`: "PAUSED"
  - `reasoning`: Must include specific metrics that justify the pause

**Example reasoning:**
> "Campaign 'Summer Sale - Prospecting' has spent €2,340 over the last 14 days with only 3 estimated conversions (CPA: €780 vs target of €45). ROAS is 0.4x against a 3x target. Frequency has reached 4.2 on the primary ad set, indicating audience saturation. Recommend pausing to prevent further budget waste."

### For each justified activation:
- Call `propose_status_change` with:
  - `entity_type`: "campaign", "adset", or "ad"
  - `entity_id`: the Facebook ID
  - `new_status`: "ACTIVE"
  - `reasoning`: Must explain why reactivation is expected to perform better

---

## Step 4 — Summary

Present a clear summary:
- Entities proposed for pause (with key metrics)
- Entities proposed for activation (with reasoning)
- Entities left unchanged and why
- Any entities in Learning phase that were skipped

---

## Rules

1. **Learning phase is sacred.** Never propose status changes for entities in Learning or Learning Limited phase. Flag them and recommend waiting.

2. **Minimum data requirement.** Never propose a pause based on < 7 days of data or < 10 conversions. Exception: zero conversions with significant spend (> 3× CPA target) after 7 days.

3. **CBO campaigns — correct level.** In CBO (Advantage+ Campaign Budget) campaigns, evaluate at the campaign level. Do not propose pausing individual ad sets within a CBO — the campaign controls allocation.

4. **Pause is not permanent.** Always frame pauses as temporary: "Pause to stop further spend while investigating / while preparing replacement creative."

5. **All proposals go through middleware.** Status transitions, risk levels, and daily limits are enforced per shop configuration. The agent proposes — the middleware decides.

6. **State what comes next.** After every pause proposal, suggest the next step: "Replace creative", "Narrow audience", "Test new angle", or "Reallocate budget to Campaign X."
