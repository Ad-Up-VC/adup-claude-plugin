# Internal Weekly Review — Scheduled Task

**Schedule:** Friday at 4:00 PM
**Cron:** `0 16 * * 5`
**Skills Used:** `/adup:cross-platform`, `/adup:budget-tracker`, `/adup:analytics`
**Output:** `.md` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`

---

## What It Does

End-of-week internal review for the agency team. Different from the client report (3:00 PM) — this one is raw, honest, and focuses on agency operations: which clients are profitable, where are we spending time, what proposals were made vs approved, and what's the plan for next week. Runs after client reports are generated.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Per-client summary:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. Pull cross-platform performance for last 7 days:
      - Total spend, blended ROAS, conversion volume, CPA
      - WoW trends on all key metrics
      - GA4 blended ROAS as source of truth
   c. **Operational metrics:**
      - Budget proposals created this week (from middleware logs)
      - Proposals approved vs pending vs rejected
      - Fatigue alerts triggered
      - Anomalies detected
   d. **Client health score:**
      - Performance: ROAS on target? CPA on target?
      - Optimization activity: how many changes made this week?
      - Risk: any campaigns in learning? Any spend anomalies?
   e. **Save per-client:** `internal_weekly-review_{YYYY-MM-DD}.md`
3. **Agency-wide summary:**
   - Total managed spend across all clients
   - Average blended ROAS across portfolio
   - Clients above/below target
   - Total proposals: created / approved / pending / rejected
   - Top 3 wins across all clients
   - Top 3 issues across all clients
   - Next week focus areas
   - Save as: `internal_agency-weekly_{YYYY-MM-DD}.md` in a general `_agency/` subfolder

## Output Format

```
## Internal Weekly Review — Week of [Date Range]

### Agency Dashboard
| Client | Spend | Blended ROAS | Target | Status | Proposals |
|--------|-------|-------------|--------|--------|-----------|
| Nike NL | $8,400 | 3.8x | 3.5x | Above | 5 (4 approved) |
| Adidas EU | $5,200 | 2.1x | 3.0x | Below | 3 (2 approved) |
| Puma | $3,100 | 4.2x | 3.0x | Above | 2 (2 approved) |

**Total managed spend:** $16,700
**Average blended ROAS:** 3.3x
**Portfolio health:** 2/3 clients above target

### Top 3 Wins This Week
1. Nike NL — Retargeting ROAS hit 5.2x, scaled budget +20%
2. Puma — New TikTok creative 42% hook rate, best in account
3. Nike NL — Google Brand Search CPA lowest in 3 months

### Top 3 Issues
1. Adidas EU — Blended ROAS 2.1x (30% below 3.0x target). Facebook prospecting CPA spiked. Action: pause underperformer, reallocate to Shopping.
2. Adidas EU — LinkedIn "B2B Decision Makers" zero leads this week, $680 spent. Action: creative refresh or pause.
3. Puma — Facebook delivery issue Wednesday (resolved). Monitor.

### Optimization Activity
- Proposals created: 10
- Auto-approved: 7
- Manual approval needed: 2
- Rejected: 1

### Next Week Focus
1. Adidas EU: urgent attention on Facebook prospecting + LinkedIn
2. Nike NL: scale Shopping and Retargeting campaigns
3. Puma: prepare new TikTok creatives (current batch approaching fatigue)
```

## Rules

1. **Raw and honest.** This is internal — no polishing. Say "Adidas is struggling" not "We see opportunity."
2. **Operational focus.** Not just performance — also track proposals, optimization activity, team workload signals.
3. **Agency-wide view.** Always include the portfolio-level summary, not just per-client.
4. **Link to client reports.** Reference the client-facing reports generated at 3:00 PM for details.
5. **Next week priorities.** Always end with action items for next week.
6. **Google Ads micros.** Divide by 1,000,000.
