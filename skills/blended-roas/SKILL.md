---
name: blended-roas
description: Blended ROAS per market — Shopify revenue per country matched to ad spend per country across Facebook, Google Ads and TikTok, with an explicit unattributed-spend bucket so the markets always reconcile to the account total. Use for "blended ROAS", "ROAS per market", "NL vs DE performance", "revenue by country vs spend", and for the recurring weekly/monthly market reports that are currently assembled by hand.
---

# Blended ROAS per market

## When to use
- "What's our blended ROAS?" / "ROAS per market" / "NL vs DE vs rest of world"
- "How much did we spend in Germany and what did it return?"
- Weekly or monthly reports with a per-market KPI
- Any time someone is about to sum Shopify revenue per country in a spreadsheet and divide it by ad spend by hand

**Not** for single-platform ROAS (use `facebook-ads`, `google-ads`) or a full multi-section client
report (use `client-report`, which can embed this skill's table).

## The rule that makes this report trustworthy

Spend that cannot be attributed to a market is **never** silently spread across markets or dropped.
It goes in its own `unattributed_spend` bucket, and this must always hold:

```
sum(markets[].spend) + unattributed_spend == account_total.spend
```

State it in the output. A market ROAS table whose parts do not add up to the account total is the
exact failure this skill exists to prevent — the sum of market ROAS deliberately does NOT equal the
blended account ROAS, and the reader has to be told why.

## Pre-flight

1. `list_shops` → brands + `connected_platforms`
2. `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**: an agency key sees only
   the six virtual tools until a shop is active
3. Pass `shop_slug="<slug>"` on EVERY call below. For several brands, loop and pass each brand's own
   slug per call — `set_active_shop` sets ONE ambient shop per key and concurrent runs race
4. One date range for every call, no exceptions. Ad platforms bucket in the ad account's timezone
   and Shopify in the store's; if they differ, say so in the output rather than silently mixing
5. `shopify__get_metric_definitions()` once — it states which revenue figure is authoritative and
   how refunds are signed. Quote the basis you used in the output

## Step 1 — Revenue per market (Shopify)

```
shopify__get_sales_by_market(start="YYYY-MM-DD", end="YYYY-MM-DD", basis="billing_country", shop_slug="<slug>")
```

Returns per country: `total_sales`, `share_pct`, `orders`, `order_share_pct`, `average_order_value`,
plus `totals` and a `conventions` block.

- `basis="billing_country"` (where the customer pays from) is the default and matches how ad
  platforms report country. Use `shipping_country` only if the brand reports on delivery
  destination — and then say which basis the table used.
- **If `get_sales_by_market` is not in the tool list** (older gateway build, or the brand's tool
  catalogue has not been re-introspected), fall back to
  `shopify__get_sales_analytics(group_by="billing_country", ...)` and compute the shares yourself.
  Say in the output that shares were derived.
- B2B-heavy brands: the ShopifyQL analytics tools cannot split B2B. If the brand needs a B2C-only
  figure, take revenue from `shopify__get_sales_summary(b2b="exclude")` for the account total and
  note that the per-market split still includes B2B.
- POS vs online (Oro Jewels): `shopify__get_sales_analytics(group_by="sales_channel")` separates
  them. A Gross-Sales ROAS that mixes POS revenue with online ad spend must say so explicitly.

## Step 2 — Spend per market (per platform, geo-native)

Use each platform's own geo breakdown. **Do not** infer a market from the campaign name when the
platform can tell you directly.

```
# Facebook / Instagram
facebook__ads_insights_get(since="YYYY-MM-DD", until="YYYY-MM-DD", level="campaign",
                           breakdowns=["country"], fields=["spend","impressions","clicks"],
                           limit=500, shop_slug="<slug>")

# TikTok
tiktok__get_tiktok_geographic_reports(start_date="YYYY-MM-DD", end_date="YYYY-MM-DD", shop_slug="<slug>")

# Google Ads — geo lives in GAQL, not the campaign-performance tool
google_ads__execute_google_ads_gaql_query(query="""
  SELECT geographic_view.country_criterion_id, metrics.cost_micros, metrics.impressions, metrics.clicks
  FROM geographic_view
  WHERE segments.date BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'
""", shop_slug="<slug>")
```

Notes that matter:
- **Google Ads costs are micros — divide by 1,000,000.** Confirm the account currency with
  `google_ads__get_google_ads_account_currency` before mixing currencies.
- `geographic_view` reports *location of interest OR physical location*; `user_location_view`
  reports physical location only. Pick one, and name it in the output — they disagree for brands
  advertising across borders.
- Meta's `country` breakdown is the country of the person served the ad.
- These three definitions of "country" are NOT identical. Say which each row came from rather than
  implying one clean definition.

### Fallback: campaign-name matching (declare it, never hide it)

Only when a platform returns no geo split. Match a market tag in the campaign name (e.g. `_NL_`,
`[DE]`), and then:
- label every row produced this way `method: "campaign-name"`;
- every campaign whose name carries no market tag goes to `unattributed_spend`, never into a
  market bucket and never quietly into the total only;
- report how much spend was matched this way as a share of total spend. Above ~20 %, say plainly
  that the market split is indicative rather than measured.

## Step 3 — Assemble

Build this object, then render it:

```json
{
  "range": {"start": "...", "end": "..."},
  "basis": {"revenue": "billing_country", "spend": {"facebook": "country", "google_ads": "geographic_view", "tiktok": "country_code"}},
  "markets": [
    {"country": "NL", "revenue": 0, "revenue_share_pct": 0, "orders": 0,
     "spend_by_platform": {"facebook": 0, "google_ads": 0, "tiktok": 0},
     "spend_total": 0, "blended_roas": 0, "method": "platform-geo"}
  ],
  "unattributed_spend": {"amount": 0, "by_platform": {}, "reason": "no geo breakdown / untagged campaigns"},
  "account_total": {"revenue": 0, "spend": 0, "blended_roas": 0},
  "reconciles": true
}
```

- `blended_roas` per market = market revenue ÷ market spend. A market with spend and no revenue is
  a real result — show it with ROAS `0`, do not omit the row.
- A market with revenue and **no** spend (organic/direct) is also real: show it, leave ROAS blank,
  and do not let it inflate a paid-ROAS claim.
- Verify `reconciles` before rendering. If it is false, do not paper over it — show the gap as its
  own line and say the split is incomplete.
- Use the `calculator` MCP for the arithmetic and the `calendar` MCP for date ranges.

## Step 4 — Output

```
## Blended ROAS by market — [Brand] | [Range]

Revenue basis: Shopify billing_country (total_sales, incl. shipping & tax, refunds subtracted)
Spend basis: Meta country breakdown · Google Ads geographic_view · TikTok country_code

| Market | Revenue | Share | Spend | Blended ROAS | Method |
|--------|---------|-------|-------|--------------|--------|
| NL | €82,400 | 61% | €18,900 | 4.36x | platform-geo |
| DE | €31,200 | 23% | €11,400 | 2.74x | platform-geo |
| Rest of world | €21,600 | 16% | €4,100 | 5.27x | platform-geo |
| **Attributed** | **€135,200** | **100%** | **€34,400** | **3.93x** | |
| Unattributed spend | — | — | €6,200 | — | no geo split (TikTok Pangle) |
| **Account total** | **€135,200** | | **€40,600** | **3.33x** | |

The market ROAS figures do not average to the account ROAS: €6,200 of spend could not be
assigned to a market and is excluded from the market rows but included in the account total.

### Reading this table
1. [Biggest mover, with the number]
2. [Where spend and return are out of proportion]
3. [What to do — shift budget, fix tagging, investigate a market]
```

## Third-party reconciliation (say it once, in every report)

Shopify will not equal Triple Whale, Northbeam, or the platforms' own reported revenue. Include this
paragraph rather than re-explaining it per client:

> Shopify counts an order when the customer pays; ad platforms count revenue against the ad click
> that preceded it, inside their own attribution window, in their own timezone. Triple Whale and
> Northbeam apply a third model again. Refunds land on the original order date in Shopify and are
> not removed from platform-reported revenue at all, and POS revenue exists only in Shopify. A gap
> is expected and is not an error in either system.

**Deviation flag:** if the brand tracks a third-party revenue figure (Upfront: Northbeam;
Oro Jewels/Sjumo: Triple Whale), compare it to Shopify and flag a difference above **5 %** as
worth investigating — below that, state it and move on.

## Named brand notes

- **Menyard** — KPI 2 is blended ROAS per market from Meta + TikTok. Use the geo breakdowns above;
  the old campaign-name matching is the fallback only. B2B orders can be excluded from the account
  revenue via `shopify__get_sales_summary(b2b="exclude")` — say when a figure is B2C-only.
- **Oro Jewels** — Gross Sales ROAS includes POS. Separate POS from online with
  `group_by="sales_channel"` and state which is in the numerator.
- **Sjumo** — Triple Whale Total Sales ≠ Shopify. Use the reconciliation paragraph; do not
  reconcile the two into one number.
- **Upfront** — check Shopify against Northbeam, flag >5 %.

## Guardrails

- Never spread unattributed spend across markets, not even proportionally. It is its own row.
- Never present campaign-name matching as measured geo data.
- Never mix currencies without converting and naming the rate.
- Never claim a market ROAS from a range where Shopify and the ad accounts used different
  timezones without saying so.
- This skill is read-only: it proposes no budget changes. Hand conclusions to `optimize-budget`.
