# Google Ads Optimization — Scheduled Task

**Schedule:** Tuesday and Thursday at 9:00 AM
**Cron:** `0 9 * * 2,4`
**Skills Used:** `/adup:google-optimize`, `/adup:google-ads`
**Output:** Proposals via action middleware (budget, status, RSA updates)

---

## What It Does

Twice-weekly deep optimization of Google Ads accounts across all clients. Goes beyond the daily budget optimizer by analyzing Quality Scores, impression share, RSA asset performance, and search term opportunities. Creates proposals for budget changes, status changes, and RSA headline/description replacements.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client (Google Ads connected only):**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Get currency:** `get_google_ads_account_currency()` — note symbol for all outputs
   c. **Campaign overview:** `get_google_ads_campaign_performance(start_date, end_date)` for last 14 days
      - Divide ALL _micros values by 1,000,000
      - Categorize: Search, Shopping, PMax, Display
   d. **Quality Score audit (Search campaigns):**
      - `search_google_ads_data("keywords with quality score below 5 and spend above €50")`
      - Flag wasted budget on low QS keywords
   e. **Impression share check:**
      - `search_google_ads_data("impression share lost to budget vs rank by campaign")`
      - IS lost to budget = increase budget (if performance is good)
      - IS lost to rank = improve Quality Score first
   f. **RSA asset performance:**
      - `get_google_ads_ad_creatives()` for asset ratings (LOW, GOOD, BEST)
      - Identify ads with LOW-rated headlines
      - Propose replacements inspired by BEST-rated headlines
   g. **Search term opportunities:**
      - `search_google_ads_data("search terms with spend over €50 and zero conversions")` — negative keyword candidates
      - `search_google_ads_data("top 20 search terms by conversion volume")` — exact match expansion
   h. **Create proposals:**
      - Budget changes: `propose_budget_change` (winners +15-20%, losers -15-25%)
      - Status changes: `propose_status_change` (ENABLED/PAUSED — Google uses these)
      - RSA updates: `propose_rsa_update` (replace LOW headlines, keep BEST)
3. **Summary** — Total proposals created, QS issues found, IS opportunities

## Output Format

```
## Google Ads Optimization — [Date] 09:00

### [Client Name] | Currency: EUR

#### Campaign Performance (14 days)
| Campaign | Type | Spend | Clicks | CTR | CPC | Conv. | CPA | ROAS |
|----------|------|-------|--------|-----|-----|-------|-----|------|
| Brand Search | Search | €2,145 | 3,860 | 8.01% | €0.56 | 312 | €6.87 | — |
| Shopping | Shopping | €3,892 | 2,480 | 2.00% | €1.57 | 198 | €19.66 | 6.3x |

#### Quality Score Issues
- 3 keywords with QS <5 spending €340/month — immediate optimization opportunity
- Fix: align ad copy to keyword intent, improve landing page relevance

#### Impression Share Gaps
- Shopping: 18% IS lost to budget (good ROAS → scale opportunity)
- PMax: 34% IS lost to rank (improve asset group quality first)

#### RSA Updates Proposed
- Ad "Summer Deals RSA" — replace 2 LOW headlines with variants of BEST headline pattern
- Ad "Brand Terms RSA" — replace 1 LOW description

#### Proposals Created: 4
- 1 budget increase (Shopping +15%)
- 1 RSA update (Summer Deals)
- 1 RSA update (Brand Terms)
- 1 negative keyword recommendation (flagged for manual review)
```

## Rules

1. **Google Ads uses micros.** Always divide by 1,000,000 before displaying. Proposal tools accept human-readable values.
2. **Google uses ENABLED/PAUSED, not ACTIVE/PAUSED.** Always use correct status values.
3. **RSA: preserve BEST headlines.** Never propose removing a BEST-rated headline. Only replace LOW or unrated.
4. **Campaign type KPIs differ.** Search: CTR, CPA, QS. Shopping: ROAS, product-level. PMax: evaluate output only. Display: CPM, reach.
5. **Learning period protection.** Don't propose changes within first 14 days or before 50 conversions.
6. **Conversion reliability.** Don't make CPA/ROAS decisions based on <30 conversions. State the caveat.
7. **Max 3 RSA headline replacements per ad per cycle.** Don't overwhelm the ad with changes.
8. **All proposals go through middleware.** Budget caps and percentage limits enforced per shop.
