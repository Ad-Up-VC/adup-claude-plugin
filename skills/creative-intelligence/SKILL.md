---
name: creative-intelligence
description: Analyse creative performance across formats, content types, and copy patterns to build a per-client creative playbook. Scores creative elements, identifies winning patterns, and provides data-driven recommendations for future creative production.
---

# Creative Intelligence

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- Default lookback: 30 days. State the assumption if user doesn't specify
- Pull ad-level data with creative details from all connected platforms

---

## Step 1 — Pull Creative Performance Data

### Facebook/Instagram Ads
- `get_ad_insights(time_range={...}, shop_slug="<slug>", metric_categories=["performance", "conversion"])` for ad-level performance
- `get_ads(shop_slug="<slug>")` to get creative details: image_url, body, title, call_to_action_type, object_type
- Include WoW trend data with `time_increment=7`

### Google Ads
- `get_google_ads_ad_performance(start_date="...", end_date="...", shop_slug="<slug>")` for ad-level metrics
- `get_google_ads_ad_creatives(shop_slug="<slug>")` for RSA headline/description performance and asset performance ratings (LOW, GOOD, BEST)

### TikTok Ads (if connected)
- TikTok ad-level tools not yet available via MCP — note in output that TikTok creative analysis is pending integration

### LinkedIn Ads (if connected)
- Creative-level performance: impressions, clicks, CTR, conversions, CPL

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
