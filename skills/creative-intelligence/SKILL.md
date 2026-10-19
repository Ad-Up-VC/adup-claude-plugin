---
name: creative-intelligence
description: Analyse creative performance across formats, content types, and copy patterns to build a per-client creative playbook. Scores creative elements, identifies winning patterns, and provides data-driven recommendations for future creative production.
---

# Creative Intelligence

## Pre-flight
- Resolve shop context in three steps: (1) `list_shops` to see brands + `connected_platforms`, (2) `set_active_shop(shop_slug="<slug>")` — **required for tool discovery**: an agency key only sees the 6 virtual tools until a shop is active, (3) pass `shop_slug="<slug>"` on every data call
- All platform tools are namespaced `platform__tool` on the aggregated `adup` connector
- Default lookback: 30 days. State the assumption if user doesn't specify
- Pull ad-level data with creative details from all connected platforms
- Call connector tools directly by name (`<platform>__<tool>`, `list_shops`). A tool search that finds no matching deferred tools only means the tools are already loaded or named differently, never that the connector dropped. Report the connector as disconnected only after a real connector call such as `list_shops` fails, and quote that error. **Sign-in needed:** if no adup tools are available (no `list_shops`, no `<platform>__` tools) or a call fails with an authentication error (`-32001` authentication required, `invalid_token`, "requires authentication", "needs authentication"), the adup connector is not signed in on this machine. Say that plainly, tell the user to sign in (Claude Code: `/mcp` → adup → Authenticate; terminal: `claude mcp login plugin:adup:adup`, with `--no-browser` on a machine without a browser; machines that cannot sign in: the automation connector; full steps: `/adup:setup`), and stop instead of reporting empty data, a disconnect or a generic failure. **Platforms per brand:** call a platform for a brand only when it is in that brand's `connected_platforms` from `list_shops`; a "not connected for brand" answer means skip that platform for that brand and name it in the report, never fail the run.

---

## Step 1 — Pull Creative Performance Data

### Facebook/Instagram Ads
- `facebook__get_ad_insights(time_range={...}, shop_slug="<slug>", time_increment=7, metric_categories=["performance", "conversion"], fields=["campaign_id", "campaign_name", "ad_id", "ad_name", "date_start", "date_stop", "account_currency", "spend", "impressions", "clicks", "ctr", "cpc", "cpm", "frequency", "purchases", "leads", "registrations", "purchase_roas"])` for weekly (WoW) performance. Always pass `fields`: without it every row also carries the raw `actions` / `cost_per_action_type` arrays (~4 KB a row) and the size-bounded answer holds only about ten rows. `purchases` / `leads` / `registrations` are derived from `actions` (missing key = 0). Without an `ad_id` the rows are per **campaign**, not per ad — pass `ad_id="<id>"` for one ad's series, and take the per-creative view from `facebook__analyze_creative_performance`
- **Page through it:** when the answer's LAST element is a `{"_truncated": true, "_next_after": "<cursor>", ...}` marker instead of a row, drop the marker and call again with the same arguments plus `after="<cursor>"`, until an answer ends without one (at most 10 pages). If still truncated, say the playbook rests on partial data
- `facebook__get_ads(shop_slug="<slug>")` to get creative details: image_url, body, title, call_to_action_type, object_type
- `facebook__analyze_creative_performance(lookback_days=30, shop_slug="<slug>")` for creative-level breakdowns — note this tool takes `lookback_days` (plus optional `min_impressions`, `min_conversions`), **not** a `time_range` object

### Google Ads
- `google_ads__get_google_ads_ad_performance(start_date="...", end_date="...", shop_slug="<slug>")` for ad-level metrics
- `google_ads__get_google_ads_ad_creatives(shop_slug="<slug>")` for RSA headline/description performance and asset performance ratings (LOW, GOOD, BEST)

### TikTok Ads (if connected)
- TikTok IS available via MCP under the `tiktok__` prefix. The ad report tool is **ID-scoped** — call `tiktok__get_tiktok_ads(shop_slug="<slug>")` first to get ad IDs, then `tiktok__get_tiktok_ad_reports(shop_slug="<slug>", ad_ids=[...], start_date="<YYYY-MM-DD>", end_date="<YYYY-MM-DD>")` for ad/creative-level metrics. All three of `ad_ids`, `start_date`, `end_date` are required

### LinkedIn Ads (if connected)
- `linkedin__get_ad_analytics(shop_slug="<slug>", ...)` for creative-level performance: impressions, clicks, CTR, conversions, CPL

---

## Step 2 — Categorise Creatives

### By Format
- **Video** (short <15s, medium 15-30s, long >30s)
- **Static Image** (single image)
- **Carousel** (multi-image/video)
- **Collection/Instant Experience**
- **Text-only** (LinkedIn)

### By Content Type
- **Testimonial/Social Proof** — customer quotes, reviews, case studies
- **Product Shot** — product-focused imagery
- **Lifestyle** — product in context, aspirational imagery
- **UGC** — user-generated content style (raw, authentic)
- **Before/After** — transformation visuals
- **Offer/Discount** — price-led, promotional
- **Educational** — how-to, tips, value-first

### By Copy Pattern
- **Question headline** — "Are you still...?"
- **Statement headline** — "The best way to..."
- **Number-led headline** — "5 reasons why..."
- **Social proof headline** — "10,000+ customers love..."
- **CTA type** — Shop Now, Learn More, Get Started, Sign Up, Book Now
- **Primary text length** — Short (<125 chars), Medium (125-250 chars), Long (>250 chars)

---

## Step 3 — Score Each Category

For each creative category, calculate:

| Metric | What it shows |
|--------|---------------|
| Average CTR | Creative appeal and relevance |
| Average CPA | Efficiency at driving conversions |
| Average ROAS | Revenue generation per dollar spent |
| Spend share | How much budget goes to this category |
| Conversion share | What % of total conversions come from this category |
| Fatigue rate | How quickly performance declines (days to -20% CTR) |

### Scoring formula:
- **CTR Score** — Rank categories by CTR, normalize to 1-10
- **CPA Score** — Rank by CPA (lower = better), normalize to 1-10
- **ROAS Score** — Rank by ROAS (higher = better), normalize to 1-10
- **Durability Score** — Rank by days before fatigue onset, normalize to 1-10
- **Overall Score** = (CTR × 0.2) + (CPA × 0.3) + (ROAS × 0.3) + (Durability × 0.2)

---

## Step 4 — Build Creative Playbook

### Top Performing Formats
Rank formats by overall score. Show the top 3 with specific metrics.

### Winning Content Types
Rank content types by overall score. Show the top 3 with comparisons.

### Copy Insights
- Which headline pattern drives highest CTR
- Which CTA drives highest conversion rate
- Optimal primary text length for this audience
- Emoji usage correlation (if data available)

### Audience × Creative Matrix
If breakdown data is available:
- Which creative styles work for which age groups
- Format preferences by platform (same creative on FB vs TikTok vs LinkedIn)
- Device-specific performance (mobile vs desktop)

---

## Step 5 — Generate Recommendations

Based on the playbook, provide specific recommendations:

1. **Produce more of what works** — "Your testimonial videos (15-30s) outperform all other formats by 2.1x ROAS. Prioritise this format in next creative batch."

2. **Test cross-platform winners** — "UGC-style content drives 2.8x engagement on TikTok. Test similar content on Facebook where you currently use only polished creative."

3. **Refresh underperformers** — "Static product shots have 45% higher CPA than video. Consider converting top product shots into short video formats."

4. **CTA optimisation** — "Replace 'Shop Now' with 'Get Started' across all campaigns — data shows 18% higher click rate."

5. **Copy length adjustment** — "Short primary text (<125 chars) drives 22% higher CTR on mobile. Currently 60% of your ads use long-form text."

---

## Output Format

```
## Creative Playbook — [Client Name]
### Based on [Date Range] | [X] ads analysed

### Top Performing Formats
| Rank | Format | CTR | CPA | ROAS | Score |
|------|--------|-----|-----|------|-------|
| 1 | Video (15-30s) | 2.1% | €18 | 4.2x | 8.7 |
| 2 | Carousel | 1.8% | €22 | 3.8x | 7.9 |
| 3 | Static Image | 1.2% | €28 | 2.9x | 6.1 |

### Winning Content Types
| Rank | Type | CTR | CPA | ROAS | Score |
|------|------|-----|-----|------|-------|
| 1 | Testimonials | 2.3% | €15 | 4.8x | 9.1 |
| 2 | UGC-style | 2.0% | €19 | 4.1x | 8.3 |
| 3 | Product + Lifestyle | 1.5% | €24 | 3.4x | 7.0 |

### Copy Insights
- Question headlines outperform statements by [X]%
- "[Best CTA]" drives [X]% more clicks than "[Worst CTA]"
- Optimal primary text length: [short/medium/long] ([X] chars)

### Recommendations
1. [Specific, actionable recommendation with data]
2. [Specific, actionable recommendation with data]
3. [Specific, actionable recommendation with data]
```

---

## Rules

1. **Minimum data requirement.** Only score creative categories with ≥1,000 impressions and ≥5 conversions. Flag categories with insufficient data.

2. **Don't over-index on CTR.** A high-CTR creative with poor CPA is a clickbait signal, not a winner. Always weight CPA and ROAS alongside CTR.

3. **Account for creative lifespan.** A creative that performs great for 3 days then crashes is less valuable than one that performs steadily for 30 days. The durability score captures this.

4. **Platform-specific benchmarks.** Don't compare TikTok hook rates with Facebook CTR. Each platform has its own engagement patterns.

5. **Breakdown Effect applies.** Don't recommend targeting changes based on creative × audience segment breakdowns. Evaluate at the ad level, use breakdowns for context only.

6. **Feed into other skills.** The creative playbook should inform ad creation proposals (create-ads skill) and fatigue response (ad-fatigue skill).
