---
name: client-report
description: Generate polished, client-ready performance reports with executive summaries, data-backed narratives, and account manager talking points. Outputs both markdown and PPTX. Follows the ADUP Report Design Guide for consistent tone, structure, and quality. Supports weekly, monthly, and custom date ranges.
---

# Client-Ready Performance Report

## Pre-flight

1. Confirm shop context (use `set_active_shop` if not already set, include `shop_slug` in every call)
2. Determine report type and period:
   - **Weekly:** last 7 days vs previous 7 days
   - **Monthly:** last calendar month vs previous calendar month
   - **Custom:** user-specified date range vs equal-length previous period
3. Identify all connected platforms for this client via `list_shops`
4. Read the Report Design Guide at `~/Desktop/ADUP-Reports/templates/REPORT-DESIGN-GUIDE.md` for tone, structure, and quality rules
5. Reference sample reports at `~/Desktop/ADUP-Reports/templates/weekly-report-sample.md` or `~/Desktop/ADUP-Reports/templates/monthly-report-sample.md` for the quality bar

---

## Step 1 — Pull Performance Data (All Connected Platforms)

Pull data from EVERY connected platform. Always include `shop_slug` in every call.

### Facebook & Instagram Ads
```
get_campaign_performance_metrics(time_range={...}, shop_slug="<slug>")
get_ad_insights(time_range={...}, shop_slug="<slug>", metric_categories=["performance", "conversion", "standard_events"])
```
- Campaign-level: spend, impressions, link clicks, CTR, purchases, ROAS, frequency
- Pull both current and comparison period for WoW/MoM delta
- Check for learning phase via `get_adsets` — flag but don't judge

### Google Ads
```
get_google_ads_account_currency(shop_slug="<slug>")
get_google_ads_campaign_performance(start_date="...", end_date="...", shop_slug="<slug>")
```
- **CRITICAL: Divide ALL _micros values by 1,000,000 before displaying**
- Pull for both current and comparison period
- Include campaign type context (Search, Shopping, PMax, Display)

### TikTok Ads (if connected)
- TikTok report tools not yet available via MCP — note in report that TikTok data is pending integration
- When available, include hook rate (3s views / impressions) and video completion rates (P25/P50/P75/P100)

### LinkedIn Ads (if connected)
- Campaign analytics for both periods
- Focus on CPL, lead quality, engagement rate
- Benchmark CPL against $50-$150 B2B range

### GA4 — SOURCE OF TRUTH for revenue
```
get_ecommerce_performance(user_prompt="Revenue by traffic source", time_range={...}, format_type="table", shop_slug="<slug>")
get_user_acquisition(user_prompt="Sessions and revenue by channel", time_range={...}, shop_slug="<slug>")
```
- For monthly reports, also pull:
```
get_conversion_funnel(user_prompt="Purchase funnel", time_range={...}, funnel_steps=["view_item","add_to_cart","begin_checkout","add_payment_info","purchase"], shop_slug="<slug>")
```

---

## Step 2 — Calculate Key Metrics

### Per Platform
| Metric | Formula | Display Format |
|--------|---------|---------------|
| Spend | Direct from platform | €X (whole number if >€100) |
| Conversions | Platform-reported actions | Whole number |
| Return on Spend | Platform revenue / spend | **X.Xx** (bold) |
| Cost per Customer | Spend / conversions | €X.XX |
| Click-through Rate | Link clicks / impressions | X.X% |

### Blended Metrics (GA4 = source of truth)
| Metric | Formula |
|--------|---------|
| Total Spend | Sum of all platform spend |
| Total Revenue | GA4 e-commerce revenue |
| Blended Return | GA4 revenue / total spend |
| Blended Cost per Customer | Total spend / GA4 transactions |
| Attribution Gap | Platform conversions vs GA4 (expect 15-25% gap — normal) |

### Period Comparison
- Calculate absolute change AND percentage change for every key metric
- **Flag any metric with >20% change** — these become talking points
- Use consistent formatting: "+8% return" with sign always shown

---

## Step 3 — Generate Report Narrative

### Mandatory Language Translation (Client Reports)

| DON'T write | DO write |
|-------------|----------|
| CPA | Cost per customer |
| ROAS 3.8x | Return of €3.80 for every €1 spent (first use), then "3.8x return" |
| CTR 1.8% | 1.8% of people who saw the ad clicked through |
| Impressions | Times the ad was shown |
| Underperformed | Cost per customer increased / return declined |
| The campaign failed | We see an opportunity to improve... |
| Consider increasing budget | Increase budget by 15% to capture ~90 additional customers |
| CPM | (skip — clients rarely care about cost per thousand) |
| Learning phase | Optimization period (the platform needs ~50 conversions to learn) |

### Section-by-Section Writing Guide

#### Executive Summary (2-3 sentences)
The most important section — many clients only read this.
- **Sentence 1:** Verdict + total spend + total revenue + blended return + vs previous period
- **Sentence 2:** Biggest win (specific campaign, specific number)
- **Sentence 3:** Biggest challenge + what you're doing about it

**Quality bar (from sample):**
> This was a strong week for Nike NL. Total advertising spend of €15,322 across 3 platforms generated €50,110 in revenue, delivering a blended return of €3.27 for every €1 spent — up 12% from last week. Google Ads was the standout performer with a 4.2x return, while Facebook showed early signs of creative wear on prospecting campaigns that need attention before next week.

#### Performance Overview Table
One table with ALL platforms + bold blended row at bottom.
- Column headers: Platform | Spend | Conversions | Revenue | Return on Spend | Cost per Customer | vs Last Week/Month
- Include directional words in comparison column: "+8% return" not just "+8%"
- Bold the Return on Spend column and the Blended row

#### What Worked (3-5 items)
For EACH win, include ALL THREE parts:
1. **What happened** — specific campaign, specific metric, specific number
2. **Why it worked** — the insight (feed optimization, creative type, audience response, timing)
3. **What to do about it** — concrete next step (continue, scale by X%, replicate approach)

Include a blockquote recommendation after each win:
> **Recommendation:** This campaign has room to grow — we're only showing in 72% of eligible searches. Increasing the daily budget by 15% should capture more high-intent shoppers.

#### What Needs Improvement (3-5 items)
For EACH issue, include ALL THREE parts:
1. **What happened** — specific campaign, specific metric change
2. **Root cause** — WHY (creative fatigue, audience saturation, landing page friction, budget misallocation)
3. **Proposed solution** — specific, actionable, with timeline

**RULE: NEVER present a problem without a proposed solution.**

#### Recommendations Table
Table format: Priority | Action | Expected Impact | What's Needed
- **High** = this week, clear ROI
- **Medium** = within 2 weeks, good opportunity
- **Low** = explore when capacity allows

Every recommendation must include an expected quantified impact:
- "Capture ~90 additional customers at €8.50 each"
- "Reduce cost per customer from €38 back to €28 range"
- "Unlock €15-20K additional monthly revenue from existing traffic"

#### Attribution Note (MANDATORY — never skip)
Standard text:
> **How we measure:** Google Analytics 4 (last-click attribution) is the single source of truth for all revenue and customer numbers in this report. Each advertising platform counts conversions using its own method — Facebook includes people who saw an ad but didn't click, while Google distributes credit across multiple touchpoints. These different methods will always produce higher numbers than Google Analytics. This is normal and expected. We use platform numbers for optimizing within each channel, and Google Analytics for cross-channel budget decisions and total revenue reporting.

#### Talking Points for Client Call
Structure for account managers — these are spoken, so make them conversational:
- **Lead with:** The biggest positive story (1 bullet)
- **Address proactively:** Known issues + what you're already doing about them (1-2 bullets)
- **Recommend:** Top 1-2 action items with supporting data (1-2 bullets)
- **If they ask about [likely question]:** Prepared responses with data (2-3 bullets)

---

## Step 4 — Monthly Report: Additional Sections

For monthly reports, insert these between Performance Overview and What Worked:

### Conversion Funnel (GA4)
Table: Step | Users | Drop-off from Previous Step
Include a blockquote highlighting the biggest bottleneck:
> Biggest opportunity: Product page to cart loses 75% of shoppers — above the 65-70% industry benchmark.

### Budget Utilization
Table: Campaign Group | Planned Budget | Actual Spend | Utilization | Status
- On Track (90-110%) / Over-paced (>110%) / Under-paced (<90%)
- Explain any intentional variances

### Channel Mix (GA4 Revenue Attribution)
Table: Channel | Sessions | Revenue | Revenue Share | Conversion Rate
- Flag high Unassigned/Direct (>25% = UTM gaps)

### Creative Performance Highlights
Reference creative playbook data:
- Top formats by return
- Average creative lifespan by platform
- Creative refreshes performed this month

---

## Step 5 — Save Report Files

### File Naming Convention
```
Weekly:  {client-slug}_weekly_{YYYY-MM-DD}.md    + .pptx
Monthly: {client-slug}_monthly_{YYYY-MM-01}.md   + .pptx
```

### Save Process
1. Create directory: `mkdir -p ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/`
2. Write markdown file
3. Generate PPTX using `anthropic-skills:pptx` — follow slide structure below
4. Open Finder: `open ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/`

### PPTX Slide Structure

**Weekly (7 slides):**
1. Title — Client name, date range, verdict in subtitle
2. Executive Summary — 3-4 bullets
3. Performance Overview — Platform table
4. What Worked — Top 3 wins
5. What Needs Attention — Top 2-3 with solutions
6. Recommendations — Priority table
7. Next Steps / Discussion

**Monthly (10-11 slides):**
1. Title with verdict
2. Executive Summary
3. Platform Performance table
4. Conversion Funnel
5. Budget Utilization
6. Channel Mix
7. Creative Highlights
8. What Worked (top 5)
9. What Needs Improvement (top 5)
10. Strategic Recommendations
11. Next Steps

**Slide rules:**
- Max 5 bullet points per slide
- One table/chart per slide
- Title slide must include the verdict
- Footer on every slide: "Source: ADUP Performance Marketing | [Date]"

---

## Step 6 — Quality Checklist (Run Before Saving)

Before finalizing, verify:

- [ ] Executive summary gives a clear verdict in the first sentence
- [ ] Blended return uses GA4 revenue (not platform-reported)
- [ ] Google Ads values divided by 1,000,000 (no raw micros)
- [ ] All currency values use the correct symbol
- [ ] ROAS displayed as "Xx" format
- [ ] Period comparison shows +/- percentage on every metric
- [ ] Every problem has a proposed solution
- [ ] Every recommendation has a quantified expected impact
- [ ] Attribution note included
- [ ] Talking points included and conversational
- [ ] No untranslated jargon (CPA → cost per customer, etc.)
- [ ] Learning phase entities flagged but not judged
- [ ] Performance table has bold blended/total row
- [ ] File saved with correct naming convention
- [ ] PPTX generated with correct slide structure
- [ ] Finder opened to report folder

---

## Rules

1. **Client-friendly language is non-negotiable.** Follow the translation table. Read every sentence as if you're a client who doesn't know what "CPA" means.

2. **GA4 is the source of truth.** Blended return always uses GA4 revenue. Platform numbers are for within-platform context.

3. **Never present a problem without a solution.** Every "needs improvement" item must have a specific proposed action.

4. **Recommendations must be quantified.** "Increase budget by 15%" with "expected to capture ~90 additional customers" — not "consider increasing budget."

5. **Attribution note is mandatory.** Every report that combines platform and GA4 data must include it. No exceptions.

6. **Follow the sample reports.** Reference `~/Desktop/ADUP-Reports/templates/weekly-report-sample.md` and `~/Desktop/ADUP-Reports/templates/monthly-report-sample.md` for the quality bar. Match their depth, tone, and structure.

7. **Google Ads micros.** ALWAYS divide by 1,000,000. Displaying raw micros is a critical error.

8. **Frame positively.** "Opportunity to improve" not "failing." Frame challenges as opportunities, not failures.

9. **Save and open.** Always save to `~/Desktop/ADUP-Reports/`. Always generate PPTX. Always open Finder.

10. **Monthly = strategic, weekly = tactical.** Monthly reports go deeper: funnel, utilization, channel mix, creative health, strategic recommendations. Weekly stays focused on this week's performance and next week's actions.
