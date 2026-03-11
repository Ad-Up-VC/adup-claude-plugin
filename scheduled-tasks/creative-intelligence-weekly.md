# Creative Intelligence — Scheduled Task

**Schedule:** Monday at 10:00 AM
**Cron:** `0 10 * * 1`
**Skills Used:** `/adup:creative-intelligence`
**Output:** Creative playbook saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`

---

## What It Does

Runs after the Monday Briefing (8:00 AM). Analyzes creative performance across all formats, content types, and copy patterns to build a per-client creative playbook. Scores creative elements, identifies winning patterns, and provides data-driven recommendations for the week's creative production. Saves the playbook as a markdown file per client.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull creative performance data (last 30 days):**
      - Facebook: `get_ad_insights` with creative fields + `get_ad_creatives` for details (image_url, body, title, CTA)
      - Google: `get_google_ads_ad_performance` + `get_google_ads_ad_creatives` for RSA asset ratings
      - TikTok: `get_tiktok_ad_reports` + `get_tiktok_video_reports` for hook rate and completion
      - LinkedIn: creative-level performance if connected
   c. **Categorize creatives:**
      - By format: Video (short/medium/long), Static Image, Carousel, Collection
      - By content type: Testimonial, Product Shot, Lifestyle, UGC, Before/After, Offer, Educational
      - By copy pattern: Question headline, Statement, Number-led, Social proof, CTA type, text length
   d. **Score each category:**
      - CTR Score (normalized 1-10)
      - CPA Score (lower = better, normalized 1-10)
      - ROAS Score (higher = better, normalized 1-10)
      - Durability Score (days before fatigue onset, normalized 1-10)
      - **Overall = (CTR x 0.2) + (CPA x 0.3) + (ROAS x 0.3) + (Durability x 0.2)**
   e. **Generate playbook:** Top formats, winning content types, copy insights, recommendations
   f. **Save to file:**
      - Create directory: `mkdir -p ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
      - Save as: `{client}_creative-playbook_{YYYY-MM-DD}.md`
3. **Summary** — Key creative insights across all clients

## Output Format

```
## Creative Playbook — [Client Name]
### Based on [Date Range] | [X] ads analysed

### Top Performing Formats
| Rank | Format | CTR | CPA | ROAS | Durability | Score |
|------|--------|-----|-----|------|------------|-------|
| 1 | Video (15-30s) | 2.1% | $18 | 4.2x | 21 days | 8.7 |
| 2 | Carousel | 1.8% | $22 | 3.8x | 28 days | 7.9 |
| 3 | Static Image | 1.2% | $28 | 2.9x | 14 days | 6.1 |

### Winning Content Types
| Rank | Type | CTR | CPA | ROAS | Score |
|------|------|-----|-----|------|-------|
| 1 | Testimonials | 2.3% | $15 | 4.8x | 9.1 |
| 2 | UGC-style | 2.0% | $19 | 4.1x | 8.3 |
| 3 | Product + Lifestyle | 1.5% | $24 | 3.4x | 7.0 |

### Copy Insights
- Question headlines outperform statements by [X]%
- "[Best CTA]" drives [X]% more clicks than "[Worst CTA]"
- Optimal primary text length: [short/medium/long] ([X] chars)

### This Week's Recommendations
1. Produce more [winning format] with [winning content type]
2. Test [cross-platform winner] on [underperforming platform]
3. Refresh [N] fatigued creatives with [recommended approach]
4. Replace "[worst CTA]" with "[best CTA]" across all campaigns
```

## Rules

1. **Minimum data.** Only score categories with 1,000+ impressions and 5+ conversions.
2. **Don't over-index on CTR.** High CTR with poor CPA = clickbait. Always weight CPA/ROAS alongside.
3. **Durability matters.** A creative great for 3 days then crashes < one that's steady for 30 days.
4. **Platform-specific benchmarks.** Don't compare TikTok hook rates with Facebook CTR.
5. **Breakdown Effect.** Evaluate at ad level, use breakdowns for context only.
6. **Feed into other skills.** Playbook informs ad creation and fatigue response.
7. **Google Ads micros.** Divide by 1,000,000 before scoring.
