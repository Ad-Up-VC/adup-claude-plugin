# Internal Monthly Review — Scheduled Task

**Schedule:** 1st of every month at 10:00 AM
**Cron:** `0 10 1 * *`
**Skills Used:** `/adup:cross-platform`, `/adup:analytics`, `/adup:budget-tracker`, `/adup:creative-intelligence`
**Output:** `.md` saved to `~/Desktop/ADUP-Reports/{client}/{YYYY-MM}/`

---

## What It Does

Monthly internal performance review for agency leadership. Strategic-level analysis: portfolio performance, client profitability signals, platform mix optimization, and planning for the month ahead. Runs after the monthly client reports (9:00 AM) so it can reference them.

## Workflow

1. **Connect** — Call `list_shops` to verify connection and get all active shops
2. **Per-client monthly rollup:**
   a. Call `set_active_shop(shop_slug="<slug>")` to switch context
   b. Pull full month performance data:
      - Total spend by platform
      - Blended ROAS (GA4 revenue / total spend)
      - Conversion volume and CPA
      - Budget utilization (actual vs planned)
      - MoM comparison (this month vs last month)
   c. **Platform mix analysis:**
      - Which platform delivered best ROAS for this client?
      - Platform spend distribution vs performance distribution
      - Recommendation: shift budget toward higher-performing platforms?
   d. **Creative summary:**
      - Reference creative playbook data
      - How many creative refreshes needed this month?
      - Average creative lifespan by platform
   e. **Optimization activity log:**
      - Total proposals created / approved / rejected
      - Budget changes made (total $ shifted)
      - Campaigns paused / activated
      - Ads created
   f. **Save:** `internal_monthly-review_{YYYY-MM-01}.md`
3. **Agency portfolio summary:**
   - Total managed ad spend (all clients)
   - Average portfolio ROAS
   - Client rankings by ROAS performance
   - Total optimization actions taken
   - Platform performance rankings (which platform performs best across portfolio)
   - Month-over-month trends
   - Strategic recommendations for next month
   - Save as: `internal_agency-monthly_{YYYY-MM-01}.md` in `_agency/` subfolder

## Output Format

```
## Internal Monthly Review — [Month Year]

### Portfolio Performance
| Client | Spend | Revenue (GA4) | Blended ROAS | Target | MoM | Status |
|--------|-------|---------------|-------------|--------|-----|--------|
| Nike NL | $34,200 | $126,540 | 3.7x | 3.5x | +8% | On Target |
| Adidas EU | $21,800 | $52,320 | 2.4x | 3.0x | -12% | Below |
| Puma | $12,400 | $54,560 | 4.4x | 3.0x | +15% | Above |
| **Total** | **$68,400** | **$233,420** | **3.4x** | — | +4% | — |

### Platform Performance (Portfolio-Wide)
| Platform | Total Spend | Avg ROAS | Best Client | Worst Client |
|----------|-------------|----------|-------------|-------------|
| Facebook | $32,100 | 3.1x | Puma (4.2x) | Adidas (1.8x) |
| Google | $24,800 | 4.2x | Nike (5.1x) | Adidas (3.0x) |
| TikTok | $6,200 | 2.8x | Puma (3.5x) | Nike (2.1x) |
| LinkedIn | $5,300 | — | — | — |

### Optimization Activity Summary
- Total proposals: 42 (36 approved, 4 pending, 2 rejected)
- Budget increased: $8,400/month across winners
- Budget decreased: $5,200/month across losers
- Campaigns paused: 3
- Ads created: 2
- Net budget shift: +$3,200/month toward high-performers

### Client Spotlight
**Best performing:** Puma — ROAS 4.4x (+15% MoM), strong TikTok creative strategy
**Needs attention:** Adidas EU — ROAS 2.4x (-12% MoM), Facebook prospecting and LinkedIn underperforming

### Strategic Recommendations for [Next Month]
1. Adidas EU: major creative refresh on Facebook, consider pausing LinkedIn B2B and reallocating to Google Shopping
2. Nike NL: scale Google Shopping (5.1x ROAS, 18% IS lost to budget)
3. Puma: expand TikTok budget (top-performing platform, room to scale)
4. Portfolio: shift 5% of total Facebook prospecting budget to Google (higher portfolio ROAS)

### Creative Health
- Average creative lifespan: 18 days (Facebook), 9 days (TikTok), 28 days (Google RSA)
- Creative refreshes needed this month: 12 across all clients
- Top format: Video testimonials (avg ROAS 4.1x across portfolio)
```

## Rules

1. **Strategic perspective.** Monthly is about direction, not daily tactics. Think channel mix, creative strategy, client health.
2. **Portfolio-level insights.** Always include cross-client analysis. What works for one client might work for others.
3. **Platform rankings.** Show which platform performs best across the portfolio — informs budget allocation recommendations.
4. **Optimization ROI.** Quantify the impact of changes: "Budget shifts generated estimated $X additional revenue."
5. **Creative lifespan tracking.** Include how long creatives last by platform — critical for production planning.
6. **Reference client reports.** This runs after client reports — link to them for details.
7. **Google Ads micros.** Divide by 1,000,000.
