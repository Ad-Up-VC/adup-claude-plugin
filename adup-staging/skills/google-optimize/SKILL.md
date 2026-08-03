---
name: google-optimize
description: Propose Google Ads optimizations through the action middleware. Covers budget changes, campaign/ad group/ad status changes, and RSA headline/description updates based on asset performance ratings.
---

# Google Ads Optimization

## Pre-flight
- Resolve shop context in all three steps: (1) `list_shops` to see the brands and their connected platforms, (2) `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**, an agency key sees only the six virtual tools until a shop is active, (3) pass `shop_slug="<slug>"` explicitly on every data/action call below
- Default lookback: 14 days. State the assumption if user doesn't specify
- Pull campaign and ad-level data from the `google_ads__*` MCP tools (the prefix is `google_ads__`, never `google__`)
- All Google Ads monetary values are in **micros** — divide by 1,000,000 for display

---

## Step 1 — Analyse Performance

Pull performance data using the namespaced Google Ads read tools:
- `google_ads__get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")` for campaign-level metrics
- `google_ads__get_google_ads_ad_performance(start_date="...", end_date="...", shop_slug="<slug>")` for ad-level metrics
- `google_ads__get_google_ads_ad_creatives(shop_slug="<slug>")` for RSA asset performance ratings (LOW, GOOD, BEST)
- `google_ads__execute_google_ads_gaql_query(query="<GAQL>", shop_slug="<slug>")` for quality score and impression share queries — this takes a **raw GAQL string, not a natural-language prompt**:
  - Quality Score: `SELECT campaign.name, ad_group.name, ad_group_criterion.keyword.text, ad_group_criterion.quality_info.quality_score, metrics.cost_micros FROM keyword_view WHERE segments.date DURING LAST_14_DAYS AND ad_group_criterion.quality_info.quality_score < 5 ORDER BY metrics.cost_micros DESC`
  - Impression share: `SELECT campaign.name, metrics.search_impression_share, metrics.search_budget_lost_impression_share, metrics.search_rank_lost_impression_share FROM campaign WHERE segments.date DURING LAST_14_DAYS AND campaign.status = 'ENABLED' ORDER BY metrics.search_impression_share ASC`

### Key metrics per campaign:
| Metric | Source |
|--------|--------|
| Spend | Campaign performance (micros / 1,000,000) |
| Conversions | Campaign performance |
| CPA | Spend / conversions |
| ROAS | Conversion value / spend |
| CTR | Clicks / impressions |
| Impression Share | Campaign performance |
| WoW Trend | Compare last 7d vs previous 7d |

---

## Step 2 — Identify Opportunities

### Budget Reallocation
- **Increase candidates:** ROAS above target for 5+ days, CPA below target, sufficient volume (15+ conversions)
- **Decrease candidates:** ROAS below target for 5+ days, CPA > 130% of target, declining trends
- **Hold:** In learning/ramp-up, insufficient data, stable near target

### Status Changes
- **Pause candidates:** Zero conversions with significant spend (>$100), sustained poor ROAS (<50% target for 7+ days)
- **Enable candidates:** Previously paused campaigns with historical strong performance that may benefit from reactivation

### RSA Headline/Description Optimisation
- Identify ads with headlines rated "LOW" by Google's asset performance
- Review which headlines are rated "BEST" — use as template for replacements
- Check description asset performance similarly
- Max 15 headlines, max 4 descriptions per RSA

---

## Step 3 — Propose Changes

The `propose_*` write tools exist on several platforms, so a bare name is ambiguous — always use the `google_ads__` ones here, with an explicit `shop_slug`.

### Budget Changes
Call `google_ads__propose_budget_change(shop_slug="<slug>", ...)` for each candidate:
- **Winners:** Propose 15-20% budget increase
- **Losers:** Propose 15-25% budget decrease
- Reasoning must cite: ROAS, CPA, conversion volume, WoW trends
- Budget values should be in **currency units** (not micros) — the tool handles conversion

### Status Changes
Call `google_ads__propose_status_change(shop_slug="<slug>", ...)` for each candidate:
- Provide `entity_type` (campaign, adgroup, ad), `entity_id`, `new_status` (ENABLED/PAUSED)
- Reasoning: cite specific performance data justifying the change
- Note: Google Ads uses ENABLED/PAUSED (not ACTIVE/PAUSED)

### RSA Updates
Call `google_ads__propose_rsa_update(shop_slug="<slug>", ...)` for underperforming RSAs:
- Replace LOW-rated headlines with new variations inspired by BEST-rated ones
- Keep BEST-rated headlines unchanged
- Propose max 3 headline replacements per ad at a time
- Always include reasoning with asset performance data

---

## Step 4 — Summary

Present a clear summary:
- Number of proposals created (budget, status, RSA)
- Expected impact based on data
- Campaigns in learning/ramp-up excluded from proposals
- Remind that all proposals require approval via middleware

---

## Rules

1. **Google Ads uses micros for all monetary values.** Always divide by 1,000,000 when displaying to the user. Proposal tools accept human-readable currency values.

2. **Google Ads uses ENABLED/PAUSED, not ACTIVE/PAUSED.** Always use the correct status values for Google Ads.

3. **RSA updates preserve BEST headlines.** Never propose removing a headline rated BEST. Only replace LOW or unrated headlines.

4. **Learning period protection.** Newly created campaigns and ad groups need time to optimise. Don't propose changes within the first 14 days or before 50 conversions.

5. **Impression share matters.** Low impression share with good performance may indicate a campaign worth scaling. High impression share with poor performance suggests audience exhaustion.

6. **All proposals go through middleware.** Budget caps, percentage limits, and daily auto-approval limits are enforced by the shop's auto-approval rules.

7. **Quality Score context.** A low Quality Score (< 5) on Search campaigns usually indicates landing page or ad relevance issues — not something budget changes fix. Flag these separately.
