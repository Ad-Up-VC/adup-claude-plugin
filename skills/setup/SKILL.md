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
# Check the session environment first
echo "${ADUP_API_KEY:-NOT_SET}"

# Also check ~/.claude/settings.json (the authoritative per-user store)
python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
try:
    s = json.load(open(path))
    key = s.get('env', {}).get('ADUP_API_KEY', 'NOT_SET')
    print('settings.json:', key[:8] + '...' if key != 'NOT_SET' else 'NOT_SET')
except: print('settings.json: NOT_SET')
"
```

If either check returns anything other than `NOT_SET`, the key is already configured for this
user. Tell the user and ask if they want to update it. If they say no, skip to **Step 4** (deploy
tasks).

Current keys are **`emp_` + 40 characters**. If what you find is a bare UUID
(`4ee0b75b-2690-…`), that is a **legacy** key from before per-employee keys: it will not
authenticate, so treat it as unset and continue to Step 2 to collect the real one.

### 2. Ask for the API key

Tell the user:

> To connect ADUP, you need **your personal API key**.
>
> Each employee on the ADUP platform has their own personal key — this is not a shared agency key. Your key authenticates you to the gateway, which then scopes the available tools to the clients you have been assigned and to your role (owner / team_lead / manager / analyst / read_only).
>
> 1. If you have not been invited yet, ask your agency owner to invite you in the agency portal under **Team → Invite employee**. You'll receive an email with your key.
> 2. If you already have your key, paste it here.

Wait for them to paste the key. Keys start with `emp_` followed by a 40-character random string (e.g., `emp_a1b2c3d4...`).

### 3. Save the key

Once the user provides the key, save it using **three methods** so it works across all Claude surfaces (Cowork desktop app, Claude Code CLI, terminal). Run all three blocks:

#### 3a. macOS LaunchAgent — the critical one for desktop apps

On macOS, GUI apps like Cowork do NOT source shell profiles. The only way to expose an env var to a desktop app is via `launchctl`. A `~/Library/LaunchAgents/` plist is per-macOS-user (each user has their own `~/Library/`) and survives reboots.

```bash
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/io.adup.env.ADUP_API_KEY.plist"
API_KEY="<KEY_FROM_USER>"

mkdir -p "$LAUNCH_AGENTS_DIR"

cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.adup.env.ADUP_API_KEY</string>
    <key>ProgramArguments</key>
    <array>
        <string>launchctl</string>
        <string>setenv</string>
        <string>ADUP_API_KEY</string>
        <string>${API_KEY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

# Unload any old version, load the new one, and set immediately for this session
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"
launchctl setenv ADUP_API_KEY "$API_KEY"
```

#### 3b. Claude Code CLI settings

```bash
mkdir -p "$HOME/.claude"
python3 - "$HOME/.claude/settings.json" "<KEY_FROM_USER>" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
api_key = sys.argv[2]

try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {})
settings["env"]["ADUP_API_KEY"] = api_key

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
```

#### 3c. Shell profile (for terminal sessions)

```bash
PROFILE_FILE="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && PROFILE_FILE="$HOME/.bashrc"
touch "$PROFILE_FILE"

# `sed -i` takes a mandatory backup suffix on BSD/macOS and must NOT have one on
# GNU/Linux, so the same invocation cannot work on both. Rewrite via a temp file
# instead — portable, and it never leaves a stray `.bak` behind.
grep -v '^export ADUP_API_KEY=' "$PROFILE_FILE" > "$PROFILE_FILE.tmp" && mv "$PROFILE_FILE.tmp" "$PROFILE_FILE"
echo 'export ADUP_API_KEY="<KEY_FROM_USER>"' >> "$PROFILE_FILE"
```

Tell the user:
> API key saved in three places so it works everywhere for your Mac user account.
> **Restart Cowork (or Claude Code) once** to pick up the new environment variable. Then run `/adup:connect` to verify.
>
> Other macOS users on this machine will need to run setup separately with their own API key — your key is stored in your personal `~/Library/` folder and is not visible to other users.

### 4. Verify the connection and discover clients

Call `list_shops` on the `adup` base connector using the key. The gateway will resolve your identity via `/api/v1/me` and return:

- Your role (`owner` / `team_lead` / `manager` / `analyst` / `read_only`)
- The shops you can access (filtered by your assigned shop permissions)

Then call `set_active_shop(shop_slug="<slug>")` for one of them. This is **required for tool discovery**, not just routing: the base connector only lists a shop's platform tools (`facebook__*`, `google_ads__*`, `ga4__*`, …) once a shop is active — an agency key with no active shop sees ONLY the six unprefixed virtual tools (`list_shops`, `set_active_shop`, `create_report`, `get_kpi`, `get_report_template`, `get_report_branding`). Every data/action call after that still passes `shop_slug="<slug>"` explicitly.

Report success with:

```
Connected to ADUP!

Role: <role>
You can access [N] client shops:
  - Shop Name  (shop-slug) — Facebook Ads, Google Ads
  ...
```

If your role is `read_only`, mention that you can only read data — you can still run reads/analyses but cannot propose changes.

If your role is `analyst`, mention that any change you propose will always go to `pending_review` and require a manager/team_lead/owner to approve.

If it fails with an auth error:
> The key doesn't seem to be valid. Ask your agency owner to verify your invitation in the portal Team page, or to regenerate your key.

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

> **This step needs a scheduling tool that the ADUP plugin does not provide.**
> `create_scheduled_task` comes from Claude's scheduled-tasks capability, not from the `adup`
> connector — the ADUP connector serves only the six virtual tools plus `platform__tool` data
> tools. **Check that a `create_scheduled_task` tool is actually available before starting this
> step.** If it is not, do not fail the setup and do not fake it: everything through Step 5 is
> already working, so tell the user
>
> > Your ADUP connection is set up and working. I could not deploy the 14 scheduled tasks because
> > no task-scheduling tool is available in this session — scheduling is a Claude feature, not part
> > of the ADUP plugin. You can run any of these on demand (e.g. `/adup:monday-briefing`), and
> > re-run `/adup:setup` once scheduling is available to deploy them.
>
> then skip to Step 7. Cowork and cloud **routines** schedule differently — see
> `/docs/en/routines`; the task prompts below are still the right content to schedule there.

Now create all 14 scheduled tasks using the `create_scheduled_task` tool. Deploy them in this order (monitoring first, then optimization, then reporting).

**Why every prompt below repeats the same shop-safety paragraph:** these tasks run on cron, often at overlapping times, and they all share ONE `ADUP_API_KEY`. `set_active_shop` sets a single *ambient* shop per API key — so if a task looped `set_active_shop` per client, a concurrently running task would clobber it mid-loop and the task could read (or propose changes against) the wrong client's account. The prompts therefore call `list_shops` once, use `set_active_shop` only to make platform tools discoverable, and pass `shop_slug="<slug>"` explicitly on every single data and proposal call. Keep that paragraph verbatim if you edit these prompts. Tool names in the prompts are namespaced `platform__tool` (`facebook__`, `google_ads__`, `ga4__`, `tiktok__`, `linkedin__`) — only the six virtual tools are unprefixed, and the Google Ads prefix is `google_ads__`, never `google__`.

#### Monitoring Tasks (3)

```
create_scheduled_task(
  taskId: "adup-budget-pacing",
  description: "Daily budget pacing check across all clients",
  cronExpression: "30 6 * * *",
  prompt: "Run /adup:budget-tracker for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign data with facebook__get_campaign_performance_metrics(shop_slug=\"<slug>\") and facebook__get_campaigns(shop_slug=\"<slug>\") for the current month, calculate pacing by comparing actual spend vs expected. Identify overpacing (>110%) and underpacing (<85%) campaigns. For overpacing >115%, propose budget decreases via facebook__propose_budget_change(shop_slug=\"<slug>\"). For severe overpacing >150%, flag as urgent. Report pacing status per client."
)

create_scheduled_task(
  taskId: "adup-ad-fatigue",
  description: "Daily creative fatigue scan across all clients",
  cronExpression: "0 7 * * *",
  prompt: "Run /adup:ad-fatigue for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: run facebook__detect_ad_fatigue(shop_slug=\"<slug>\", lookback_days=3) — it takes lookback_days, NOT a time_range object. If you need the underlying rows, facebook__get_ad_insights REQUIRES a time_range object: facebook__get_ad_insights(shop_slug=\"<slug>\", time_range={\"since\":\"YYYY-MM-DD\",\"until\":\"YYYY-MM-DD\"}, time_increment=1). Check learning phase with facebook__get_adsets(shop_slug=\"<slug>\"). For HIGH fatigue ads (frequency >threshold AND CTR decline >20% OR CPA increase >25%), propose pause via facebook__propose_status_change(shop_slug=\"<slug>\"). For MEDIUM fatigue, propose 15-20% budget decrease on parent ad set via facebook__propose_budget_change(shop_slug=\"<slug>\"). For LOW fatigue, flag for monitoring only. Never propose changes to ads in Learning phase. Save summary."
)

create_scheduled_task(
  taskId: "adup-anomaly-alerts",
  description: "Anomaly detection every 3 hours across all clients",
  cronExpression: "0 */3 * * *",
  prompt: "Run /adup:anomaly-alerts for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull today's data vs 7-day rolling averages from all connected platforms (Facebook: facebook__get_campaign_performance_metrics(shop_slug=\"<slug>\"), Google: google_ads__get_google_ads_campaign_performance(shop_slug=\"<slug>\") with micros/1000000). Detect CRITICAL anomalies: delivery stopped ($0 spend 6h+ while active), spend spikes (>200% of 7-day avg), budget exhaustion (<5% remaining). For CRITICAL: create proposals via the owning platform's tool — facebook__propose_budget_change / google_ads__propose_budget_change / tiktok__propose_budget_change / linkedin__propose_budget_change — each with shop_slug=\"<slug>\". Detect WARNING: CTR drop >30%, CPA spike >50%, frequency >4.0. Report counts: CRITICAL/WARNING/INFO. If weekend, apply wider tolerance."
)
```

#### Optimization Tasks (4)

```
create_scheduled_task(
  taskId: "adup-google-optimize",
  description: "Google Ads optimization on Tuesday and Thursday",
  cronExpression: "0 9 * * 2,4",
  prompt: "Run /adup:google-optimize for all clients with Google Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: google_ads__get_google_ads_account_currency(shop_slug=\"<slug>\"), google_ads__get_google_ads_campaign_performance(shop_slug=\"<slug>\") for last 14 days (divide all micros by 1,000,000). Check Quality Score (flag QS<5 with significant spend), impression share (diagnose budget vs rank loss). For winners (ROAS above target 5+ days, 15+ conversions): propose 15-20% budget increase via google_ads__propose_budget_change(shop_slug=\"<slug>\"). For losers (ROAS below target 5+ days, declining WoW): propose 15-25% decrease the same way. Check RSA asset performance via google_ads__get_google_ads_ad_creatives(shop_slug=\"<slug>\") and propose headline replacements for LOW-rated assets via google_ads__propose_rsa_update(shop_slug=\"<slug>\"). The Google Ads prefix is google_ads__, never google__. All via middleware."
)

create_scheduled_task(
  taskId: "adup-linkedin-optimize",
  description: "LinkedIn Ads optimization on Wednesday",
  cronExpression: "0 9 * * 3",
  prompt: "Run /adup:linkedin-optimize for all clients with LinkedIn Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign analytics for the last 14 days with the linkedin__* tools (e.g. linkedin__get_linkedin_campaigns(shop_slug=\"<slug>\")). Focus on CPL (benchmark: $50-$150 B2B). For winners (CPL below target, 5+ leads/week, improving trends): propose 15-20% budget increase via linkedin__propose_budget_change(shop_slug=\"<slug>\"). For losers (CPL >130% target, declining trends): propose 15-25% decrease. For zero leads with $200+ spent: propose pause via linkedin__propose_status_change(shop_slug=\"<slug>\"). Identify low-CTR creatives (<0.4%) and propose copy updates based on high performers via linkedin__propose_creative_update(shop_slug=\"<slug>\"). All via middleware."
)

create_scheduled_task(
  taskId: "adup-tiktok-optimize",
  description: "TikTok Ads optimization on Tuesday and Thursday",
  cronExpression: "30 9 * * 2,4",
  prompt: "Run /adup:tiktok-optimize for all clients with TikTok Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign/adgroup/video reports for the last 14 days with the tiktok__* tools (e.g. tiktok__get_tiktok_campaigns(shop_slug=\"<slug>\") plus the tiktok__* report tools). Key metric: hook rate (3s views/impressions). For winners (hook rate >30%, good CPA/ROAS, 10+ conversions): propose 15-20% budget increase via tiktok__propose_budget_change(shop_slug=\"<slug>\"). For losers (hook rate <20%, poor CPA): propose decrease the same way. For hook rate <10% with spend: propose DISABLE via tiktok__propose_status_change(shop_slug=\"<slug>\") (TikTok uses ENABLE/DISABLE). Flag creative fatigue: any ad 14+ days with declining hook rate needs replacement. All via middleware."
)

create_scheduled_task(
  taskId: "adup-budget-optimize",
  description: "Daily cross-platform budget reallocation",
  cronExpression: "0 10 * * 1-5",
  prompt: "Run /adup:optimize-budget for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull 14-day performance from all connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__*, linkedin__*). Pull ga4__* for blended ROAS. Classify campaigns: Winners (ROAS above target 5+ days, CPA below target, 15+ conversions, not in learning) get 15-20% budget increase. Losers (ROAS below target 5+ days, CPA >130% target, declining WoW) get 15-25% decrease. Frame as reallocation when possible (budget-neutral shifts). Never change campaigns in Learning phase or with <10 conversions. Propose with the owning platform's tool — facebook__propose_budget_change / google_ads__propose_budget_change / tiktok__propose_budget_change / linkedin__propose_budget_change — always with shop_slug=\"<slug>\"; a bare propose_budget_change is ambiguous across platforms. All proposals via middleware."
)
```

#### Reporting Tasks — Client-Facing (3)

```
create_scheduled_task(
  taskId: "adup-monday-briefing",
  description: "Monday morning executive briefing per client",
  cronExpression: "0 8 * * 1",
  prompt: "Run /adup:monday-briefing for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull last 7 days vs previous 7 days from ALL connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__* with hook rates, linkedin__* with CPL, ga4__* for blended ROAS). Calculate blended ROAS = GA4 revenue / total ad spend. Assign verdict: Great week / Stable / Needs attention / Urgent. Identify top 3 wins and top 3 concerns with specific numbers. Propose actions for concerns via the owning platform's <platform>__propose_* tool with shop_slug=\"<slug>\", through the middleware. Save briefing as markdown to ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monday-briefing_{YYYY-MM-DD}.md (create directory with mkdir -p first). End with cross-client summary ranking which clients need the most attention."
)

create_scheduled_task(
  taskId: "adup-client-report-weekly",
  description: "Weekly client performance report with PPTX",
  cronExpression: "0 15 * * 5",
  prompt: "Run /adup:client-report for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and report call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull last 7 days vs previous 7 days from all connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__*, linkedin__*, ga4__*). Generate full client report: Executive Summary, Performance by Platform table, What Worked (3-5 wins), What Needs Improvement (3-5 issues with root causes), Recommendations, and Talking Points for client call. Calculate blended ROAS via GA4. Use client-friendly language (no jargon). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_weekly_{YYYY-MM-DD}.md (mkdir -p first). Then generate a PPTX presentation from the content and save as {client}_weekly_{YYYY-MM-DD}.pptx in same folder. Open Finder to the folder after saving: open ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/"
)

create_scheduled_task(
  taskId: "adup-client-report-monthly",
  description: "Monthly client performance report with PPTX",
  cronExpression: "0 9 1 * *",
  prompt: "Run /adup:client-report for all clients (monthly edition). Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and report call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull full previous month data from all connected platforms (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*). Include: Executive Summary, Platform Performance MoM comparison, Conversion Funnel Analysis (ga4__get_conversion_funnel(shop_slug=\"<slug>\")), Budget Utilization Review, Channel Mix (GA4 revenue attribution), Creative Performance Summary, What Worked (top 5), What Needs Improvement (top 5 with root causes), Strategic Recommendations for next month, and Talking Points. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monthly_{YYYY-MM-01}.md (mkdir -p first). Generate PPTX with slides: Title, Exec Summary, Platform Performance, Funnel, Budget Review, Channel Mix, Wins, Improvements, Recommendations. Save as {client}_monthly_{YYYY-MM-01}.pptx in same folder. Open Finder after saving."
)
```

#### Reporting Tasks — Internal (3)

```
create_scheduled_task(
  taskId: "adup-internal-daily-overview",
  description: "Quick morning overview of all clients",
  cronExpression: "30 8 * * 1-5",
  prompt: "Quick daily health check across all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. For each client pull yesterday's data from all connected platforms (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"): total spend, conversions, ROAS/CPA. Compare to 7-day average. Flag anything >20% off baseline. Output a quick status table: Client | Spend | Conv | ROAS | Status (OK/Watch/Alert). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_daily-overview_{YYYY-MM-DD}.md (mkdir -p first). End with summary: how many clients OK vs needing attention."
)

create_scheduled_task(
  taskId: "adup-internal-weekly-review",
  description: "Friday internal agency-wide performance review",
  cronExpression: "0 16 * * 5",
  prompt: "Internal agency review. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Pull last 7 days from all platforms per client (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"). Generate per-client summary: spend, revenue, blended ROAS, WoW change, key wins, key concerns. Then generate cross-client analysis: total managed ad spend, average portfolio ROAS, client rankings by ROAS, platform performance rankings, optimization actions taken this week. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_weekly-review_{YYYY-MM-DD}.md (mkdir -p first)."
)

create_scheduled_task(
  taskId: "adup-internal-monthly-review",
  description: "Monthly internal agency P&L and strategic review",
  cronExpression: "0 10 1 * *",
  prompt: "Monthly internal strategic review. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Pull full previous month data per client (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"). Per client: total spend by platform, blended ROAS, MoM comparison, budget utilization, optimization activity (proposals created/approved/rejected). Generate portfolio summary: total managed spend, average ROAS, client rankings, platform performance rankings across portfolio, creative health (average lifespan, refreshes needed), total optimization actions taken. Strategic recommendations for next month. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_monthly-review_{YYYY-MM-01}.md (mkdir -p first)."
)
```

#### Analysis Tasks (1)

```
create_scheduled_task(
  taskId: "adup-creative-intelligence",
  description: "Weekly creative playbook update per client",
  cronExpression: "0 10 * * 1",
  prompt: "Run /adup:creative-intelligence for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one API key and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Per shop: pull 30-day ad-level data with creative details from all platforms (Facebook: facebook__get_ad_insights(shop_slug=\"<slug>\") + facebook__get_ads(shop_slug=\"<slug>\"), Google: google_ads__get_google_ads_ad_performance(shop_slug=\"<slug>\") + google_ads__get_google_ads_ad_creatives(shop_slug=\"<slug>\")). Categorize creatives by format (video/static/carousel), content type (testimonial/UGC/product), and copy pattern (question/statement/CTA type). Score each category on CTR (20%), CPA (30%), ROAS (30%), Durability (20%). Build creative playbook: top formats, winning content types, copy insights, recommendations. Only score categories with 1000+ impressions and 5+ conversions. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_creative-playbook_{YYYY-MM-DD}.md (mkdir -p first)."
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

### 9. Sync your org's installed skills

After API key + report folders + scheduled tasks are set up, run `/adup:sync-skills` to pull any org-installed or org-private skills your agency has added in the portal. Restart Claude Code once after the sync so the new skills become available.

## Notes

- Never log or display the full API key after the user pastes it — only show the first 8 characters followed by `...` for confirmation
- The key is a UUID in the format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- If tasks already exist (user re-runs setup), the `create_scheduled_task` tool will handle duplicates — existing tasks with the same `taskId` will be updated, not duplicated
- If the user only wants to re-deploy tasks (key already set), skip steps 1-3 and jump straight to step 4
- All 14 tasks iterate over all clients automatically — no per-client task creation needed. They do it by passing `shop_slug="<slug>"` per call, **not** by re-pointing an ambient active shop per client: `set_active_shop` sets one shop per API key, so a per-client `set_active_shop` loop races with the other cron tasks sharing that key and can read or write the wrong client
- The task prompts reference specific ADUP MCP tools by name — these are the actual function names the AI should call when executing. All platform tools are namespaced `platform__tool` (`facebook__`, `google_ads__`, `ga4__`, `tiktok__`, `linkedin__`, …); only `list_shops`, `set_active_shop`, `create_report`, `get_kpi`, `get_report_template`, and `get_report_branding` are unprefixed. A bare `propose_budget_change` / `propose_status_change` is ambiguous — those tools exist on four platforms

## Multi-user macOS note

The API key is stored in three per-user locations. On a Mac shared by multiple users:

- **`~/Library/LaunchAgents/io.adup.env.ADUP_API_KEY.plist`** — the primary mechanism. `~/Library/` is per-macOS-user. The LaunchAgent sets the env var at login so desktop apps (Cowork, Claude Code) can read it. This is the method that actually works for GUI apps.
- **`~/.claude/settings.json`** — for Claude Code CLI users.
- **`~/.zshrc` / `~/.bashrc`** — for terminal sessions.

Shell profiles (`.zshrc`, `.bashrc`) are **not** sourced by macOS GUI apps — that's why the LaunchAgent is essential. Each macOS user must run `/adup:setup` once with their own API key. One user's key is never visible to another.
