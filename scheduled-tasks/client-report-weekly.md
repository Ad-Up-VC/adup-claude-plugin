# Weekly Client Report — Scheduled Task

**Schedule:** Friday at 3:00 PM
**Cron:** `0 15 * * 5`
**Skills Used:** `/adup:client-report`, `/adup:cross-platform`, `anthropic-skills:pptx`
**Output:** `.md` + `.pptx` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
**Templates:** `~/Desktop/ADUP-Reports/templates/weekly-report-sample.md`, `~/Desktop/ADUP-Reports/templates/REPORT-DESIGN-GUIDE.md`

---

## What It Does

End-of-week client-ready performance report. Pulls data from all connected platforms, calculates blended ROAS via GA4, generates an executive narrative with talking points, and saves both a markdown file and a PowerPoint presentation to the client's report folder. Opens Finder so the account manager can grab the files.

**IMPORTANT:** Before generating, read `~/Desktop/ADUP-Reports/templates/weekly-report-sample.md` as the quality bar. Match its depth, tone, language, and structure. Read `~/Desktop/ADUP-Reports/templates/REPORT-DESIGN-GUIDE.md` for formatting rules, jargon translation, and quality checklist.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Loop per client:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. **Pull 7-day performance data from ALL connected platforms:**
      - Facebook: `get_campaign_performance_metrics` for last 7 days
      - Google: `get_google_ads_campaign_performance` (micros / 1,000,000)
      - TikTok: `get_tiktok_campaign_reports`
      - LinkedIn: campaign analytics
      - GA4: `get_ecommerce_performance` + `get_user_acquisition` for revenue attribution
   c. **Calculate metrics:**
      - Per platform: spend, conversions, ROAS, CPA, CTR
      - Blended ROAS = GA4 revenue / total ad spend
      - WoW comparison (this week vs last week)
      - Flag any metric with >20% change
   d. **Generate narrative sections:**
      - Executive Summary (2-3 sentences, client-friendly language)
      - Performance by Platform (table + 1-2 sentence assessment each)
      - What Worked (3-5 specific wins with data and why)
      - What Needs Improvement (3-5 issues with root cause analysis)
      - Recommendations for Next Week (3-5 prioritized actions)
      - Talking Points (structured for account manager call prep)
   e. **Save markdown file:**
      - `mkdir -p ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
      - Save as: `{client}_weekly_{YYYY-MM-DD}.md`
   f. **Generate PPTX:**
      - Use `anthropic-skills:pptx` to create a slide deck from the markdown content
      - Slides: Title, Executive Summary, Performance Overview (table), What Worked, What Needs Improvement, Recommendations, Talking Points
      - Save as: `{client}_weekly_{YYYY-MM-DD}.pptx`
   g. **Open Finder:** `open ~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`
3. **Summary** — List of reports generated, any clients skipped

## Output Format (Markdown)

```
## Performance Report — [Client Name]
### Week of [Start Date] to [End Date] | Compared to Previous Week

#### Executive Summary
Total spend of $X across [N] platforms. Blended ROAS of X.Xx, [up/down X%] from last week.
[Biggest win]. [Biggest challenge].

#### Performance Overview
| Platform | Spend | Conversions | ROAS | CPA | vs Last Week |
|----------|-------|-------------|------|-----|--------------|
| Facebook | $X | X | X.Xx | $X | +/-X% ROAS |
| Google | $X | X | X.Xx | $X | +/-X% ROAS |
| **Blended** | **$X** | **X** | **X.Xx** | **$X** | **+/-X%** |

#### What Worked
1. [Specific win with data and why]
2. [Specific win with data and why]
3. [Specific win with data and why]

#### What Needs Improvement
1. [Issue with root cause and proposed fix]
2. [Issue with root cause and proposed fix]

#### Recommendations
1. [Actionable recommendation with expected impact]
2. [Actionable recommendation with expected impact]
3. [Actionable recommendation with expected impact]

#### Attribution Note
GA4 uses last-click session attribution. Platform-reported conversions use different windows (Facebook: 7-day click + 1-day view; Google: data-driven). These will not sum. GA4 revenue is the most conservative baseline.

---

### Talking Points for Client Call

**Lead with:**
- "[Biggest win] — highlight the [X]% improvement"

**Address proactively:**
- "[Known issue] — explain [root cause] and propose [solution]"

**Recommend:**
- "[Action] — based on [data], we recommend [specific change]"
```

## PPTX Slide Structure

1. **Title Slide** — "[Client Name] Weekly Performance Report | [Date Range]"
2. **Executive Summary** — 3 bullet points (spend, ROAS, key insight)
3. **Performance by Platform** — Table with all platforms + blended
4. **What Worked** — 3 wins with supporting metrics
5. **What Needs Improvement** — 2-3 items with proposed solutions
6. **Recommendations** — Prioritized action items
7. **Next Steps** — Talking points for client discussion

## Rules

1. **Client-friendly language.** No jargon. "Cost per customer" not "CPA". "Return on ad spend" not "ROAS" (define on first use).
2. **Always include blended ROAS.** Clients care about actual revenue vs total spend.
3. **Frame improvements as opportunities.** "We see an opportunity to improve..." not "Mobile is failing."
4. **Attribution note is mandatory.** Always explain why platform numbers differ from GA4.
5. **Recommendations must be actionable.** "Test testimonial video format" is actionable. "Improve performance" is not.
6. **Google Ads micros.** Divide by 1,000,000 before including in report.
7. **Open Finder after saving.** Account managers need to grab files quickly.
