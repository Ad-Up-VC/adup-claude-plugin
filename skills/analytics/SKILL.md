---
name: analytics
description: Analyse Google Analytics 4 data — sessions, revenue, e-commerce, user acquisition by channel, content engagement, funnel drop-off, and conversion events. Use to connect paid ad spend to actual on-site revenue and understand the full customer journey.
---

# GA4 Analytics

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- **Always include `shop_slug` in every GA4 tool call** — required for agency accounts
- Default to last 30 days if no date range specified — state the assumption
- GA4 values are in actual currency (no micros conversion needed)
- Pass the user's actual question as `user_prompt` for context

## Metric & Dimension Selection (CRITICAL)

**You MUST always pass explicit `dimensions` and `metrics` lists to every GA4 tool call.** The tools do not auto-select — they require explicit GA4 API names.

Refer to `GA4_REFERENCE.md` (in this skill directory) for:
- Scope compatibility rules (session/user/event/item scopes must match)
- Ready-made dimension/metric sets for common use cases
- Which dimensions each tool auto-appends (don't duplicate those)
- Known incompatible combinations to avoid

**Quick rules:**
1. Pick dimensions and metrics from the SAME scope (see GA4_REFERENCE.md)
2. `date`, `deviceCategory`, `country` are safe dimensions that work with most metrics
3. Some tools auto-append dimensions (e.g. `get_ecommerce_performance` adds `date`) — see reference

---

## ⚠️ Attribution Model — Always State This

**GA4 uses last-click session attribution.** Every platform (Facebook, Google, LinkedIn) reports its own conversions using its own attribution windows. This causes a fundamental, expected discrepancy:

- Facebook may report 200 purchases; Google may report 150 purchases; GA4 may report 180 purchases
- These numbers **cannot be added together** — they count overlapping conversions differently
- GA4 is the most conservative and is generally the closest to ground truth for total revenue
- Platform numbers are correct for within-platform optimisation; GA4 is correct for channel budget allocation

**Always include this context when showing GA4 data alongside platform data.** Never treat the discrepancy as an error or a problem to fix.

---

## ⚠️ Engagement Rate vs Bounce Rate

GA4 does not use Bounce Rate the same way Universal Analytics did.

- **Engagement Rate** = % of sessions that were engaged (≥10s on page, OR 2+ pageviews, OR a conversion event fired)
- **Bounce Rate** in GA4 = 100% − Engagement Rate (inverse)
- A "good" Engagement Rate is typically >50–60% for most e-commerce sites
- **Never use Bounce Rate as a primary metric in GA4** — use Engagement Rate instead

---

## Key Tools

**E-commerce revenue and transactions:**
```
get_ecommerce_performance(
  user_prompt="Revenue by traffic source last 30 days",
  dimensions=["sessionDefaultChannelGroup"],
  metrics=["purchaseRevenue", "transactions", "activeUsers", "engagementRate"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table",
  include_items=False
)
```
Returns: revenue, transactions, AOV, conversion rate. Note: `date` is auto-appended.

**User acquisition by channel:**
```
get_user_acquisition(
  user_prompt="Sessions and revenue by channel this month",
  dimensions=["sessionSource", "sessionMedium"],
  metrics=["sessions", "activeUsers", "newUsers", "engagementRate", "bounceRate"],
  num_top_sources=10,
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table"
)
```
Use to answer "where do users come from?" Note: `sessionSource` is auto-appended if missing.

**Conversion funnel drop-off:**
```
get_conversion_funnel(
  user_prompt="Show me the purchase funnel drop-off",
  dimensions=["eventName"],
  metrics=["eventCount", "activeUsers"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table",
  funnel_steps=["view_item", "add_to_cart", "begin_checkout", "add_payment_info", "purchase"]
)
```
Shows step-by-step drop-off rates. Use whenever conversion rate is the question.

**Active users and audience:**
```
get_active_users(
  user_prompt="New vs returning users this month",
  dimensions=["date"],
  metrics=["activeUsers", "newUsers", "totalUsers", "engagementRate"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table"
)
```
Use to answer "how big is the audience?" and "is it growing?"

**Content and page performance:**
```
get_content_engagement(
  user_prompt="Top pages by engagement time",
  dimensions=["pagePath", "pageTitle"],
  metrics=["screenPageViews", "engagementRate", "userEngagementDuration", "averageSessionDuration"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table",
  limit=20,
  path_contains="/blog"
)
```
Use to answer "what do users do on the site?" — page views, engagement time, engaged sessions.

**Specific events:**
```
get_events(
  user_prompt="Add to cart events this month by device",
  dimensions=["eventName", "deviceCategory"],
  metrics=["eventCount", "eventValue", "conversions"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  event_name="add_to_cart",
  include_parameters=True
)
```
Use for micro-conversion analysis, event frequency, and event-level conversion rates.

**Flexible custom report (most powerful):**
```
run_report(
  user_prompt="Revenue by country and device category this month",
  dimensions=["country", "deviceCategory"],
  metrics=["purchaseRevenue", "transactions", "activeUsers"],
  time_range={"since": {"year": YYYY, "month": M, "day": D}, "until": {"year": YYYY, "month": M, "day": D}},
  format_type="table",
  include_totals=True
)
```
Use for any report not covered by structured tools. Select dimensions/metrics from GA4_REFERENCE.md.

---

## GA4 Default Channel Groupings

GA4 automatically groups traffic into these channels:

| Channel | What It Means |
|---|---|
| Organic Search | SEO — Google, Bing, etc. (unpaid) |
| Paid Search | Google Ads, Microsoft Ads |
| Organic Social | Facebook, Instagram, TikTok (unpaid) |
| Paid Social | Facebook Ads, LinkedIn Ads (paid) |
| Direct | Typed URL, bookmarks, no referrer |
| Email | Links from email campaigns |
| Referral | Links from other websites |
| Unassigned | Sessions GA4 couldn't categorise |

High "Unassigned" or "Direct" traffic often indicates missing UTM parameters on campaigns — flag this.

---

## Analysis Workflow

### Step 1 — Revenue and transaction overview
`get_ecommerce_performance` — get total revenue, transactions, AOV, and conversion rate for the period. This sets the baseline.

### Step 2 — Channel acquisition breakdown
`get_user_acquisition` — see which channels drive sessions and revenue. Identify the revenue contribution per channel.

### Step 3 — Funnel analysis (if conversion rate is the question)
`get_conversion_funnel` — identify where users drop off. The biggest drop-off step is the highest-leverage optimisation point.

### Step 4 — Cross-platform reconciliation
When combining GA4 with Facebook/Google Ads data:
- Use platform data for within-platform CPA/ROAS optimisation
- Use GA4 for true channel revenue contribution and budget allocation decisions
- State the attribution difference clearly — do not treat discrepancy as an error

### Step 5 — Audience and engagement (if user growth is the question)
`get_active_users` — new vs. returning, device split, engagement trends.

### Step 6 — Content performance (if UX or SEO is the question)
`get_content_engagement` — top pages by engagement time, pages with high views but low engagement (UX issue signals).

### Step 7 — Custom analysis
`run_report` for any other question — select appropriate dimensions/metrics from GA4_REFERENCE.md based on the user's question.

---

## Time Window Rules

| Analysis Type | Minimum Window |
|---|---|
| Conversion rate / revenue trends | 7 days |
| Channel contribution | 30 days |
| Seasonal comparisons | Same period last year |
| Funnel drop-off | 14+ days (needs volume) |

---

## Output Format

```
## GA4 Analytics — [Shop] | [Date Range]

**Revenue**: €48,320 | **Transactions**: 1,240 | **AOV**: €38.97 | **Conv. Rate**: 2.4% | **Engagement Rate**: 61%

### Revenue by Channel
| Channel | Sessions | Revenue | Transactions | Conv. Rate |
|---------|----------|---------|--------------|------------|
| Paid Search | 18,400 | €22,180 | 569 | 3.1% |
| Paid Social | 12,200 | €14,640 | 373 | 3.1% |
| Direct | 8,100 | €7,240 | 187 | 2.3% |
| Organic Search | 6,300 | €3,060 | 75 | 1.2% |
| Email | 2,800 | €1,200 | 36 | 1.3% |

### Conversion Funnel
| Step | Users | Drop-off |
|------|-------|----------|
| View Item | 24,800 | — |
| Add to Cart | 6,820 | 72.5% |
| Begin Checkout | 2,940 | 56.9% |
| Purchase | 1,240 | 57.8% |
→ Biggest drop: View Item → Add to Cart (72.5%). Product page conversion is the primary bottleneck.

### Insights
1. Paid channels drive 76% of revenue from 59% of sessions
2. Organic Search conversion rate (1.2%) is 61% below paid — landing page or content optimisation opportunity
3. Add to Cart drop-off (72.5%) is above typical e-commerce benchmark of 60–65% — product page UX or pricing issue
4. [Any UTM/attribution gaps noticed]

### Recommendations
1. Prioritise product page conversion optimisation — this is where 72% of potential buyers exit
2. [Second recommendation with evidence]
3. [Third if applicable]

### Attribution Note
GA4 uses last-click session attribution. Platform-reported conversions (Facebook, Google Ads) use their own attribution windows and models — they will show different numbers. This is expected. GA4 figures represent the most conservative revenue estimate.
```

---

## Cross-Platform Reconciliation Guide

When users ask "why does Facebook show 200 sales but GA4 shows 180?":

1. **Different attribution models** — Facebook uses a 7-day click / 1-day view window by default; GA4 uses last-click session
2. **Different counting** — Facebook counts a conversion per ad interaction; GA4 counts a conversion per session
3. **Cross-device** — a user may click a Facebook ad on mobile and convert on desktop; GA4 may attribute to Direct
4. **View-through conversions** — Facebook counts these; GA4 does not

**The right answer:** Use GA4 for true revenue totals and channel mix decisions. Use platform data for within-platform creative and bid optimisation. Never add platform conversion numbers together.

---

## Proactive Signals to Flag

- Organic Search sessions down >15% week-over-week → potential indexing issue or ranking drop
- "Unassigned" or "Direct" traffic >25% of total → UTM parameter gaps in campaigns
- Funnel drop-off at Add to Cart >70% → product page or pricing issue
- Funnel drop-off at Begin Checkout >60% → cart friction (shipping cost reveal, registration wall)
- Mobile conversion rate <50% of desktop → mobile UX issue
- Engagement Rate <40% → landing page quality or audience-content mismatch
