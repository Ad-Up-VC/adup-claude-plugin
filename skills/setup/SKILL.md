---
name: setup
description: Set up your ADUP API key, connect to your marketing data, and automatically deploy all scheduled monitoring, optimization, and reporting tasks. Run this once when you first install the plugin, or any time you need to update your key or re-deploy tasks.
---

# ADUP Setup

Full setup wizard: API key configuration, connection verification, report folder creation, and automatic deployment of all 14 scheduled tasks.

## Steps

### 1. Check if the key is already set

Run this in a bash tool:
```bash
echo "${ADUP_API_KEY:-NOT_SET}"
```

If it returns a UUID (not `NOT_SET`), the key is already configured. Tell the user and ask if they want to update it. If they say no, skip to **Step 4** (deploy tasks).

### 2. Ask for the API key

Tell the user:

> To connect ADUP, you need your API key from the ADUP dashboard.
>
> 1. Go to **[tara.adup.io/settings/api](https://tara.adup.io/settings/api)**
> 2. Copy your API key
> 3. Paste it here

Wait for them to paste the key. It will be a UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 3. Save the key

Once the user provides the key, save it to their shell profile so it persists across sessions:

```bash
# Detect shell profile
PROFILE_FILE="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && PROFILE_FILE="$HOME/.bashrc"

# Remove any existing ADUP_API_KEY line
sed -i '' '/^export ADUP_API_KEY=/d' "$PROFILE_FILE" 2>/dev/null || true

# Append new key
echo "export ADUP_API_KEY=<KEY_FROM_USER>" >> "$PROFILE_FILE"

# Set it for this session too
export ADUP_API_KEY=<KEY_FROM_USER>
```

Tell the user:
> API key saved to `~/.zshrc` (or `~/.bashrc`). It will load automatically in future sessions.
> **Restart Claude Code now** so the MCP connection picks up the new `ADUP_API_KEY`. Then run `/adup:connect` to verify.

### 4. Verify the connection and discover clients

Call `list_shops` using the key. If it returns shops, report success and list them:

```
Connected to ADUP!

You manage [N] client shops:
  - Shop Name  (shop-slug) — Facebook Ads, Google Ads
  ...
```

If it fails with an auth error:
> The key doesn't seem to be valid. Double-check it at tara.adup.io/settings/api and try again.

**If successful, proceed to Step 5.**

### 5. Create report folder structure

For each client shop returned by `list_shops`, create the local report folder:

```bash
# Get current year-month
YEAR_MONTH=$(date +%Y-%m)

# Create per-client report folders
mkdir -p ~/Desktop/ADUP-Reports/<client-slug>/$YEAR_MONTH
```

Repeat for every client. This creates the structure:
```
~/Desktop/ADUP-Reports/
├── nike-nl/2026-03/
├── adidas-eu/2026-03/
└── puma/2026-03/
```

Tell the user:
> Report folders created at `~/Desktop/ADUP-Reports/`. Weekly and monthly reports will be saved here automatically.

### 6. Deploy all scheduled tasks

Now create all 14 scheduled tasks using the `create_scheduled_task` tool. Deploy them in this order (monitoring first, then optimization, then reporting):

#### Monitoring Tasks (3)

```
create_scheduled_task(
  taskId: "adup-budget-pacing",
  description: "Daily budget pacing check across all clients",
  cronExpression: "30 6 * * *",
  prompt: "Run /adup:budget-tracker for all clients. Call list_shops, then loop through each shop: set_active_shop, pull campaign data with get_campaign_performance_metrics and get_campaigns for the current month, calculate pacing by comparing actual spend vs expected. Identify overpacing (>110%) and underpacing (<85%) campaigns. For overpacing >115%, propose budget decreases via propose_budget_change. For severe overpacing >150%, flag as urgent. Report pacing status per client."
)

create_scheduled_task(
  taskId: "adup-ad-fatigue",
  description: "Daily creative fatigue scan across all clients",
  cronExpression: "0 7 * * *",
  prompt: "Run /adup:ad-fatigue for all clients. Call list_shops, loop through each shop: set_active_shop, pull ad-level data with get_ad_insights (time_increment=1 for last 3 days) and check learning phase with get_adsets. For HIGH fatigue ads (frequency >threshold AND CTR decline >20% OR CPA increase >25%), propose pause via propose_status_change. For MEDIUM fatigue, propose 15-20% budget decrease on parent ad set via propose_budget_change. For LOW fatigue, flag for monitoring only. Never propose changes to ads in Learning phase. Save summary."
)

create_scheduled_task(
  taskId: "adup-anomaly-alerts",
  description: "Anomaly detection every 3 hours across all clients",
  cronExpression: "0 */3 * * *",
  prompt: "Run /adup:anomaly-alerts for all clients. Call list_shops, loop through each shop: set_active_shop, pull today's data vs 7-day rolling averages from all connected platforms (Facebook: get_campaign_performance_metrics, Google: get_google_ads_campaign_performance with micros/1000000). Detect CRITICAL anomalies: delivery stopped ($0 spend 6h+ while active), spend spikes (>200% of 7-day avg), budget exhaustion (<5% remaining). For CRITICAL: create proposals via propose_budget_change. Detect WARNING: CTR drop >30%, CPA spike >50%, frequency >4.0. Report counts: CRITICAL/WARNING/INFO. If weekend, apply wider tolerance."
)
```

#### Optimization Tasks (4)

```
create_scheduled_task(
  taskId: "adup-google-optimize",
  description: "Google Ads optimization on Tuesday and Thursday",
  cronExpression: "0 9 * * 2,4",
  prompt: "Run /adup:google-optimize for all clients with Google Ads connected. Call list_shops, loop through each shop: set_active_shop, get_google_ads_account_currency, get_google_ads_campaign_performance for last 14 days (divide all micros by 1,000,000). Check Quality Score (flag QS<5 with significant spend), impression share (diagnose budget vs rank loss). For winners (ROAS above target 5+ days, 15+ conversions): propose 15-20% budget increase. For losers (ROAS below target 5+ days, declining WoW): propose 15-25% decrease. Check RSA asset performance and propose headline replacements for LOW-rated assets. All via middleware."
)

create_scheduled_task(
  taskId: "adup-linkedin-optimize",
  description: "LinkedIn Ads optimization on Wednesday",
  cronExpression: "0 9 * * 3",
  prompt: "Run /adup:linkedin-optimize for all clients with LinkedIn Ads connected. Call list_shops, loop through each shop: set_active_shop, pull campaign analytics for last 14 days. Focus on CPL (benchmark: $50-$150 B2B). For winners (CPL below target, 5+ leads/week, improving trends): propose 15-20% budget increase via propose_budget_change. For losers (CPL >130% target, declining trends): propose 15-25% decrease. For zero leads with $200+ spent: propose pause via propose_status_change. Identify low-CTR creatives (<0.4%) and propose copy updates based on high performers. All via middleware."
)

create_scheduled_task(
  taskId: "adup-tiktok-optimize",
  description: "TikTok Ads optimization on Tuesday and Thursday",
  cronExpression: "30 9 * * 2,4",
  prompt: "Run /adup:tiktok-optimize for all clients with TikTok Ads connected. Call list_shops, loop through each shop: set_active_shop. Note: TikTok report tools not yet available via MCP — when available, pull campaign/adgroup/video reports for last 14 days. Key metric: hook rate (3s views/impressions). For winners (hook rate >30%, good CPA/ROAS, 10+ conversions): propose 15-20% budget increase. For losers (hook rate <20%, poor CPA): propose decrease. For hook rate <10% with spend: propose DISABLE (TikTok uses ENABLE/DISABLE). Flag creative fatigue: any ad 14+ days with declining hook rate needs replacement. All via middleware."
)

create_scheduled_task(
  taskId: "adup-budget-optimize",
  description: "Daily cross-platform budget reallocation",
  cronExpression: "0 10 * * 1-5",
  prompt: "Run /adup:optimize-budget for all clients. Call list_shops, loop through each shop: set_active_shop. Pull 14-day performance from all connected platforms (Facebook, Google with micros/1000000, TikTok, LinkedIn). Pull GA4 for blended ROAS. Classify campaigns: Winners (ROAS above target 5+ days, CPA below target, 15+ conversions, not in learning) get 15-20% budget increase. Losers (ROAS below target 5+ days, CPA >130% target, declining WoW) get 15-25% decrease. Frame as reallocation when possible (budget-neutral shifts). Never change campaigns in Learning phase or with <10 conversions. All proposals via middleware."
)
```

#### Reporting Tasks — Client-Facing (3)

```
create_scheduled_task(
  taskId: "adup-monday-briefing",
  description: "Monday morning executive briefing per client",
  cronExpression: "0 8 * * 1",
  prompt: "Run /adup:monday-briefing for all clients. Call list_shops, loop through each shop: set_active_shop. Pull last 7 days vs previous 7 days from ALL connected platforms (Facebook, Google with micros/1000000, TikTok with hook rates, LinkedIn with CPL, GA4 for blended ROAS). Calculate blended ROAS = GA4 revenue / total ad spend. Assign verdict: Great week / Stable / Needs attention / Urgent. Identify top 3 wins and top 3 concerns with specific numbers. Propose actions for concerns via middleware. Save briefing as markdown to ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monday-briefing_{YYYY-MM-DD}.md (create directory with mkdir -p first). End with cross-client summary ranking which clients need the most attention."
)

create_scheduled_task(
  taskId: "adup-client-report-weekly",
  description: "Weekly client performance report with PPTX",
  cronExpression: "0 15 * * 5",
  prompt: "Run /adup:client-report for all clients. Call list_shops, loop through each shop: set_active_shop. Pull last 7 days vs previous 7 days from all connected platforms (Facebook, Google with micros/1000000, TikTok, LinkedIn, GA4). Generate full client report: Executive Summary, Performance by Platform table, What Worked (3-5 wins), What Needs Improvement (3-5 issues with root causes), Recommendations, and Talking Points for client call. Calculate blended ROAS via GA4. Use client-friendly language (no jargon). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_weekly_{YYYY-MM-DD}.md (mkdir -p first). Then generate a PPTX presentation from the content and save as {client}_weekly_{YYYY-MM-DD}.pptx in same folder. Open Finder to the folder after saving: open ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/"
)

create_scheduled_task(
  taskId: "adup-client-report-monthly",
  description: "Monthly client performance report with PPTX",
  cronExpression: "0 9 1 * *",
  prompt: "Run /adup:client-report for all clients (monthly edition). Call list_shops, loop through each shop: set_active_shop. Pull full previous month data from all connected platforms. Include: Executive Summary, Platform Performance MoM comparison, Conversion Funnel Analysis (GA4 get_conversion_funnel), Budget Utilization Review, Channel Mix (GA4 revenue attribution), Creative Performance Summary, What Worked (top 5), What Needs Improvement (top 5 with root causes), Strategic Recommendations for next month, and Talking Points. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monthly_{YYYY-MM-01}.md (mkdir -p first). Generate PPTX with slides: Title, Exec Summary, Platform Performance, Funnel, Budget Review, Channel Mix, Wins, Improvements, Recommendations. Save as {client}_monthly_{YYYY-MM-01}.pptx in same folder. Open Finder after saving."
)
```

#### Reporting Tasks — Internal (3)

```
create_scheduled_task(
  taskId: "adup-internal-daily-overview",
  description: "Quick morning overview of all clients",
  cronExpression: "30 8 * * 1-5",
  prompt: "Quick daily health check across all clients. Call list_shops, loop through each shop: set_active_shop. For each client pull yesterday's data from all connected platforms: total spend, conversions, ROAS/CPA. Compare to 7-day average. Flag anything >20% off baseline. Output a quick status table: Client | Spend | Conv | ROAS | Status (OK/Watch/Alert). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_daily-overview_{YYYY-MM-DD}.md (mkdir -p first). End with summary: how many clients OK vs needing attention."
)

create_scheduled_task(
  taskId: "adup-internal-weekly-review",
  description: "Friday internal agency-wide performance review",
  cronExpression: "0 16 * * 5",
  prompt: "Internal agency review. Call list_shops, loop through each shop: set_active_shop. Pull last 7 days from all platforms per client. Generate per-client summary: spend, revenue, blended ROAS, WoW change, key wins, key concerns. Then generate cross-client analysis: total managed ad spend, average portfolio ROAS, client rankings by ROAS, platform performance rankings, optimization actions taken this week. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_weekly-review_{YYYY-MM-DD}.md (mkdir -p first)."
)

create_scheduled_task(
  taskId: "adup-internal-monthly-review",
  description: "Monthly internal agency P&L and strategic review",
  cronExpression: "0 10 1 * *",
  prompt: "Monthly internal strategic review. Call list_shops, loop through each shop: set_active_shop. Pull full previous month data. Per client: total spend by platform, blended ROAS, MoM comparison, budget utilization, optimization activity (proposals created/approved/rejected). Generate portfolio summary: total managed spend, average ROAS, client rankings, platform performance rankings across portfolio, creative health (average lifespan, refreshes needed), total optimization actions taken. Strategic recommendations for next month. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_monthly-review_{YYYY-MM-01}.md (mkdir -p first)."
)
```

#### Analysis Tasks (1)

```
create_scheduled_task(
  taskId: "adup-creative-intelligence",
  description: "Weekly creative playbook update per client",
  cronExpression: "0 10 * * 1",
  prompt: "Run /adup:creative-intelligence for all clients. Call list_shops, loop through each shop: set_active_shop. Pull 30-day ad-level data with creative details from all platforms (Facebook: get_ad_insights + get_ads, Google: get_google_ads_ad_performance + get_google_ads_ad_creatives). Categorize creatives by format (video/static/carousel), content type (testimonial/UGC/product), and copy pattern (question/statement/CTA type). Score each category on CTR (20%), CPA (30%), ROAS (30%), Durability (20%). Build creative playbook: top formats, winning content types, copy insights, recommendations. Only score categories with 1000+ impressions and 5+ conversions. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_creative-playbook_{YYYY-MM-DD}.md (mkdir -p first)."
)
```

### 7. Report deployed tasks

After all tasks are created, present a summary to the user:

```
ADUP Fully Configured!

API Key: xxxxxxxx... (saved)
Clients: [N] shops connected
Report Folder: ~/Desktop/ADUP-Reports/

Scheduled Tasks Deployed (14):

MONITORING (daily/continuous)
  06:30  Budget Pacing Check ............. daily
  07:00  Ad Fatigue Scan ................ daily
  Every 3h  Anomaly Alerts .............. 24/7

OPTIMIZATION (targeted days)
  09:00  Google Ads Optimize ............ Tue/Thu
  09:00  LinkedIn Optimize .............. Wed
  09:30  TikTok Optimize ................ Tue/Thu
  10:00  Budget Reallocation ............ Mon-Fri

REPORTING — CLIENT
  08:00  Monday Briefing ................ Mon
  15:00  Weekly Report + PPTX ........... Fri
  09:00  Monthly Report + PPTX .......... 1st of month

REPORTING — INTERNAL
  08:30  Daily Overview ................. Mon-Fri
  16:00  Weekly Review .................. Fri
  10:00  Monthly Review ................. 1st of month

ANALYSIS
  10:00  Creative Playbook .............. Mon

All tasks are now running automatically.
Reports saved to: ~/Desktop/ADUP-Reports/{client}/
Try: "How are my campaigns doing?" to start exploring.
```

### 8. Optional: Deploy for single client only

If the user says they only want to set up tasks for a specific client, ask which client and only create report folders for that one. The scheduled tasks themselves loop through all clients automatically, so no change needed — but the report folder only needs to be created for the requested client.

## Notes

- Never log or display the full API key after the user pastes it — only show the first 8 characters followed by `...` for confirmation
- The key is a UUID in the format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- If tasks already exist (user re-runs setup), the `create_scheduled_task` tool will handle duplicates — existing tasks with the same `taskId` will be updated, not duplicated
- If the user only wants to re-deploy tasks (key already set), skip steps 1-3 and jump straight to step 4
- All 14 tasks loop through all clients automatically — no per-client task creation needed
- The task prompts reference specific ADUP MCP tools by name — these are the actual function names the AI should call when executing
