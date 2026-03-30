---
name: google-optimize
description: Propose Google Ads optimizations through the action middleware. Covers budget changes, campaign/ad group/ad status changes, and RSA headline/description updates based on asset performance ratings.
---

# Google Ads Optimization

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- Default lookback: 14 days. State the assumption if user doesn't specify
- Pull campaign and ad-level data from Google Ads MCP tools
- All Google Ads monetary values are in **micros** — divide by 1,000,000 for display

---

## Step 1 — Analyse Performance

Pull performance data using Google Ads read tools:
- `get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")` for campaign-level metrics
- `get_google_ads_ad_performance(start_date="...", end_date="...", shop_slug="<slug>")` for ad-level metrics
- `get_google_ads_ad_creatives(shop_slug="<slug>")` for RSA asset performance ratings (LOW, GOOD, BEST)
- `search_google_ads_data(user_prompt="...", shop_slug="<slug>")` for quality score and impression share queries

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

### Budget Changes
Call `propose_budget_change` (Google Ads) for each candidate:
- **Winners:** Propose 15-20% budget increase
- **Losers:** Propose 15-25% budget decrease
- Reasoning must cite: ROAS, CPA, conversion volume, WoW trends
- Budget values should be in **currency units** (not micros) — the tool handles conversion

### Status Changes
Call `propose_status_change` (Google Ads) for each candidate:
- Provide `entity_type` (campaign, adgroup, ad), `entity_id`, `new_status` (ENABLED/PAUSED)
- Reasoning: cite specific performance data justifying the change
- Note: Google Ads uses ENABLED/PAUSED (not ACTIVE/PAUSED)

### RSA Updates
Call `propose_rsa_update` (Google Ads) for underperforming RSAs:
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
