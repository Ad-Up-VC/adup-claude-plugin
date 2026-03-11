# Monthly Client Report — Scheduled Task

**Schedule:** 1st of every month at 9:00 AM
**Cron:** `0 9 1 * *`
**Skills Used:** `/adup:client-report`, `/adup:cross-platform`, `/adup:analytics`, `anthropic-skills:pptx`
**Output:** `.md` + `.pptx` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
**Templates:** `~/Desktop/ADUP-Reports/templates/monthly-report-sample.md`, `~/Desktop/ADUP-Reports/templates/REPORT-DESIGN-GUIDE.md`

---

## What It Does

Comprehensive monthly performance report for every client. Deeper than the weekly report — includes full funnel analysis, creative performance summary, budget utilization review, and strategic recommendations for the month ahead. Generates both markdown and PowerPoint for client sharing.

**IMPORTANT:** Before generating, read `~/Desktop/ADUP-Reports/templates/monthly-report-sample.md` as the quality bar. Match its depth, tone, language, and structure. Read `~/Desktop/ADUP-Reports/templates/REPORT-DESIGN-GUIDE.md` for formatting rules, jargon translation, and quality checklist. Monthly reports should be strategic (channel mix, creative strategy, audience expansion) not just tactical.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull full month data from ALL connected platforms:**
      - Facebook: `get_campaign_performance_metrics` + `analyze_standard_events_funnel` for conversion funnel
      - Google: `get_google_ads_campaign_performance` + Quality Score overview (micros / 1,000,000)
      - TikTok: `get_tiktok_campaign_reports` + `get_tiktok_video_reports` for video metrics
      - LinkedIn: campaign analytics with CPL focus
      - GA4: `get_ecommerce_performance` (revenue by channel) + `get_conversion_funnel` + `get_user_acquisition`
   c. **Calculate monthly metrics:**
      - Per platform: spend, conversions, ROAS, CPA, CTR
      - Blended ROAS = GA4 revenue / total ad spend
      - Month-over-month comparison (this month vs last month)
      - Budget utilization: actual spend vs planned budget per campaign
      - Conversion funnel drop-off rates
   d. **Generate narrative sections:**
      - Executive Summary (monthly verdict)
      - Monthly Performance by Platform (tables + assessments)
      - Conversion Funnel Analysis (where users drop off)
      - Budget Utilization Review (over/underspend by campaign)
      - Creative Performance Summary (top/bottom creatives, reference creative playbook)
      - Channel Mix Analysis (GA4 attribution, which channels drive most revenue)
      - What Worked This Month (top 5 wins)
      - What Needs Improvement (top 5 issues with root causes)
      - Strategic Recommendations for Next Month (5 prioritized actions with expected impact)
      - Talking Points
   e. **Save markdown:**
      - `mkdir -p ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
      - Save as: `{client}_monthly_{YYYY-MM-01}.md`
   f. **Generate PPTX:**
      - Use `anthropic-skills:pptx` to create slide deck
      - More slides than weekly: Title, Exec Summary, Platform Performance, Funnel, Budget Review, Creative Summary, Channel Mix, Wins, Improvements, Recommendations, Next Steps
      - Save as: `{client}_monthly_{YYYY-MM-01}.pptx`
   g. **Open Finder:** `open ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
3. **Summary** — List of reports generated, highlight any clients with major changes

## Output Format (Markdown)

```
## Monthly Performance Report — [Client Name]
### [Month Year] | Compared to [Previous Month]

#### Executive Summary
[Monthly verdict: Great month / Stable / Needs attention]
Total spend: $X across [N] platforms. Blended ROAS: X.Xx ([+/-X%] MoM).
[Biggest achievement]. [Biggest challenge]. [Key recommendation for next month].

#### Platform Performance
| Platform | Spend | Conv. | ROAS | CPA | MoM Change |
|----------|-------|-------|------|-----|------------|
| Facebook | $X | X | X.Xx | $X | +/-X% |
| Google | $X | X | X.Xx | $X | +/-X% |
| TikTok | $X | X | X.Xx | $X | +/-X% |
| LinkedIn | $X | X leads | — | $X CPL | +/-X% |
| **Blended** | **$X** | **X** | **X.Xx** | **$X** | **+/-X%** |

#### Conversion Funnel (GA4)
| Step | Users | Drop-off |
|------|-------|----------|
| View Item | X | — |
| Add to Cart | X | X% |
| Begin Checkout | X | X% |
| Purchase | X | X% |
> Biggest bottleneck: [step] with [X%] drop-off

#### Budget Utilization
| Campaign | Budget | Spent | Util. | Status |
|----------|--------|-------|-------|--------|
| ... | ... | ... | ... | On Track / Over / Under |

#### Channel Mix (GA4 Revenue Attribution)
| Channel | Sessions | Revenue | Share | Conv. Rate |
|---------|----------|---------|-------|------------|
| Paid Search | X | $X | X% | X% |
| Paid Social | X | $X | X% | X% |
| Organic | X | $X | X% | X% |

#### What Worked
1-5 wins with data

#### What Needs Improvement
1-5 issues with root causes and proposed fixes

#### Strategic Recommendations for [Next Month]
1. [Action with expected impact and resource requirement]
2. [Action with expected impact and resource requirement]
3. [Action with expected impact and resource requirement]

#### Attribution Note
[Standard attribution disclaimer]

---

### Talking Points
[Structured for client call]
```

## PPTX Slide Structure

1. Title Slide
2. Executive Summary (3-4 bullet points)
3. Platform Performance (table)
4. Conversion Funnel (visual funnel with drop-off rates)
5. Budget Utilization (table with status indicators)
6. Channel Mix / Revenue Attribution (table)
7. What Worked (top 3-5 wins)
8. What Needs Improvement (top 3-5 with solutions)
9. Strategic Recommendations (prioritized)
10. Next Steps / Talking Points

## Rules

1. **Client-friendly language.** No jargon throughout.
2. **Blended ROAS is mandatory.** Always include GA4-based blended figures.
3. **Include funnel analysis.** Monthly reports must include conversion funnel — it's the highest-leverage insight.
4. **Budget utilization review.** Show whether campaigns hit their budget targets.
5. **Reference creative playbook.** Link creative findings back to the weekly playbook data.
6. **Strategic, not tactical.** Monthly recommendations should be bigger-picture: channel mix shifts, new platform tests, audience expansion, creative strategy changes.
7. **Attribution note mandatory.** Always included.
8. **Google Ads micros.** Divide by 1,000,000.
9. **Open Finder after saving.** Files need to be easily accessible.
