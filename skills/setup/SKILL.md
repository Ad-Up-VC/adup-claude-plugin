---
name: setup
description: Sign in to ADUP from Claude (OAuth), verify the connection, remove credentials left by key-based installs, and deploy the scheduled monitoring, optimization and reporting tasks. This skill stores nothing — Claude keeps your sign-in in the OS keychain. Use /adup:reset to sign out or switch accounts.
---

# ADUP Setup

Sign-in check, cleanup of key-based leftovers, report folder creation, a check for brands Tara already reports on, and deployment of the 14 scheduled tasks (12 when Tara already drafts every brand's report).

> **v2.0.0 — there is no key to paste.** The `adup` connector authenticates with OAuth 2.0. The
> first time Claude uses it, your browser opens Tara; you sign in with your normal Tara login,
> approve, and Claude keeps the resulting tokens in the OS keychain and refreshes them itself.
> This skill writes no credential anywhere. The employee API key still exists in Tara (**My MCP
> setup**) but is only for automations that cannot open a browser — see **Automation machines**
> at the end.

## Steps

### 1. Make sure the connector is signed in

Call `list_shops` on the `adup` connector.

- **It answers** → you are signed in. Continue with Step 2.
- **It fails with an authentication error** (`-32001` / `invalid_token`, "server requires
  authentication", or the connector shows as needing authentication) → this machine has not
  signed in yet, or was signed out. Tell the user how to sign in **on the surface they are
  using**, then retry `list_shops`:

  | surface | how to sign in |
  |---|---|
  | Claude Code CLI | run `/mcp`, pick **adup**, choose **Authenticate** — the browser opens Tara |
  | any terminal | `claude mcp login plugin:adup:adup` (add `--no-browser` on a machine without one: it prints the URL and asks for the redirect URL back) |
  | Claude desktop app, Code tab | sessions there cannot start the browser flow — run the terminal command above once; the sign-in is shared |
  | Cowork | approve the connector's sign-in prompt when it appears; if the surface never prompts, run the terminal command once on this Mac |

  In the browser Tara asks you to log in (unless you already are), shows **Claude Code wants to
  access ADUP** with your account and the number of brands you can reach, and you click
  **Approve**. Then come back here.

  Do not ask the user for a key, do not look for `ADUP_API_KEY`, and do not offer to store
  anything — none of that is used any more.

### 2. Remove leftovers from key-based installs (plugin ≤ 1.9)

Earlier versions wrote the employee key **in cleartext** to three per-user places and copied
personal skills under `~/.claude/skills/`. Nothing reads any of it any more, and a cleartext
credential on disk is the one thing this release must not leave behind. Runs every time setup runs.

1. **List** what exists — only these exact paths, nothing else:

   ```bash
   ls "$HOME"/Library/LaunchAgents/io.adup.env.*.plist 2>/dev/null
   python3 - "$HOME/.claude/settings.json" <<'PY'
   import json, sys
   try:
       env = json.load(open(sys.argv[1])).get("env", {})
   except Exception:
       env = {}
   print("settings.json env:", [k for k in ("ADUP_API_KEY", "ADUP_GATEWAY_BASE", "ADUP_API_BASE") if k in env])
   PY
   grep -nE '^export (ADUP_API_KEY|ADUP_GATEWAY_BASE|ADUP_API_BASE)=' "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null
   for d in "$HOME"/.claude/skills/adup-*/; do [ -f "$d/SKILL.md" ] && echo "$d"; done
   ```

   Nothing found → say nothing and continue with Step 3.
2. **Show** the list and ask: "Remove these? They were written by an earlier version of this
   plugin and are no longer used — the key copies are cleartext credentials." Wait for a yes; a
   no leaves them and continues.
3. **Remove** exactly what was listed:

   ```bash
   for OLD in "$HOME"/Library/LaunchAgents/io.adup.env.*.plist; do
     [ -e "$OLD" ] || continue
     VAR="$(basename "$OLD" .plist)"; VAR="${VAR#io.adup.env.}"
     launchctl unload "$OLD" 2>/dev/null || true
     launchctl unsetenv "$VAR" 2>/dev/null || true
     rm -f "$OLD"; echo "removed $OLD"
   done
   python3 - "$HOME/.claude/settings.json" <<'PY'
   import json, sys
   path = sys.argv[1]
   try:
       settings = json.load(open(path))
   except (FileNotFoundError, json.JSONDecodeError):
       sys.exit(0)
   env = settings.get("env", {})
   removed = [k for k in ("ADUP_API_KEY", "ADUP_GATEWAY_BASE", "ADUP_API_BASE") if env.pop(k, None) is not None]
   if removed:
       json.dump(settings, open(path, "w"), indent=2)
       print("settings.json: removed", removed)
   PY
   for PROFILE_FILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
     [ -f "$PROFILE_FILE" ] || continue
     grep -vE '^export (ADUP_API_KEY|ADUP_GATEWAY_BASE|ADUP_API_BASE)=' "$PROFILE_FILE" \
       > "$PROFILE_FILE.tmp" && mv "$PROFILE_FILE.tmp" "$PROFILE_FILE"
   done
   ```

   and, for each personal skill directory that was listed, `rm -rf` it (re-check the path is under
   `~/.claude/skills/` and its name starts with `adup-` first). Print each deleted path; the matching
   `/adup-<slug>` commands disappear on the next Claude Code restart.

### 3. Nothing to save

There is nothing to store: the sign-in lives in Claude's keychain, per macOS user, and the skills
that used to call the ADUP API over bash now use the connector's own tools (`list_proposals`,
`find_creative_asset`, `create_creative_upload`, …). Continue with Step 4.

### 4. Verify the connection and discover clients

Call `list_shops` on the `adup` connector (signed in since Step 1). The gateway resolves your identity via `/api/v1/me` and returns:

- Your role (`owner` / `team_lead` / `manager` / `analyst` / `read_only`)
- The shops you can access (filtered by your assigned shop permissions)

Then call `set_active_shop(shop_slug="<slug>")` for one of them. This is **required for tool discovery**, not just routing: the base connector only lists a shop's platform tools (`facebook__*`, `google_ads__*`, `ga4__*`, …) once a shop is active — an agency account with no active shop sees ONLY the unprefixed virtual tools (`list_shops`, `set_active_shop`, the report, proposal and creative-asset tools, plus the gateway's agent tools — of which only `list_agents` is read here, in Step 6). Every data/action call after that still passes `shop_slug="<slug>"` explicitly.

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

If it fails with an auth error (`invalid_token` / `-32001`), the sign-in on this machine is missing,
expired after long inactivity, or was signed out from Tara (**My MCP setup → Connected devices**).
Go back to Step 1 and sign in again on the user's surface — never ask for a key. If Tara itself
refuses the login, the account is the problem (ask the agency owner to check the invitation on the
portal Team page).

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

### 6. Brands Tara already reports on — remove the local reporting tasks they make redundant

Tara drafts client reports itself, per brand, on its own schedule, into the **same review queue**
that `/adup:client-report` submits to (configured in Tara under **Agents**, not from here). A brand
that Tara already reports on *and* the local weekly/monthly reporting tasks gets two drafts per
period, two costs, and a reviewer who has to guess which one is canonical. So before deploying,
find out which brands are covered and step aside for them. Decided 2026-09-07: **remove** the
duplicates, do not merely skip them.

**6a. Which brands Tara already reports on.** For every shop from Step 4 call
`list_agents(shop_slug="<slug>")` (unprefixed virtual tool, explicit `shop_slug` every call — never
the ambient shop; this is a loop). A brand is **covered** when any entry in `agents[]` has
`agent_type` `client_reporting` or `google_sheets` with `is_active: true`. Print one summary line
per brand — user-facing wording is "drafted by Tara", nothing more technical:

```
Reporting per brand:
  acme-nl      Reporting: drafted by Tara → local weekly/monthly tasks removed
  puma         Reporting: drafted by Tara (spreadsheet) → local weekly/monthly tasks removed
  adidas-eu    Reporting: not drafted by Tara → local weekly/monthly tasks kept
```

If `list_agents` is not in the tool list (older gateway) or errors, treat every brand as
**not covered**, say so once, and continue — never let this step block the deploy.

**6b. Which tasks this is about.** The 14 tasks are **agency-wide**: each one loops every shop
inside its own prompt, so there is no per-brand task to delete. The reporting tasks Tara's drafts
make redundant are exactly these two, by the `taskId` this skill assigns and nothing else:

| taskId | what it duplicates |
|---|---|
| `adup-client-report-weekly` | Tara's weekly draft (HTML + PPTX) |
| `adup-client-report-monthly` | Tara's monthly draft (HTML + PPTX) |

Monitoring, optimisation, the Monday briefing, the internal reviews and the creative playbook are
**untouched** — nothing server-side replaces them yet.

**6c. Apply, per-brand and whole-task.** Two mechanisms, both needed:

1. **Inside the prompt (per brand).** Both reporting-task prompts in Step 7 carry a dedupe clause:
   at run time the task calls `list_agents(shop_slug="<slug>")` per shop and **skips** covered
   brands, printing `skipped — Tara already drafts this report`. This is what makes the per-brand
   decision live: a brand whose Tara reporting is switched off later is picked up again on the next
   run without re-running setup, and a brand whose Tara reporting is switched on stops getting a
   local draft.
2. **The task itself (all brands).** When **every** brand is covered the two tasks have nothing
   left to do — do **not** create them, and **delete** any that already exist:
   - `list_scheduled_tasks()` → match **only** the exact `taskId`s `adup-client-report-weekly`
     and `adup-client-report-monthly`. Never delete a task this skill did not create, and never
     match on description or prompt text.
   - Print each match by name **before** deleting ("Removing `adup-client-report-weekly` — Tara
     already drafts every brand's report"), call `delete_scheduled_task(taskId="<id>")`,
     then print it again **after** ("Removed `adup-client-report-weekly`"). Nothing matched →
     say "no local reporting tasks to remove".
   - **Reverse direction:** when at least one brand is *not* covered (Tara's reporting was
     switched off since the last setup, or a new brand appeared), the two tasks are (re)created in
     Step 7 as normal — say "re-created `adup-client-report-weekly`: <brand> is not drafted by
     Tara". `create_scheduled_task` with an existing `taskId` updates it in place, so a task that
     already exists is refreshed with the current prompt rather than duplicated.

**If the scheduled-tasks tools are absent** (`list_scheduled_tasks` / `delete_scheduled_task` not
in the tool list — Cowork, cloud sessions): do not pretend. List the duplicates by name and tell the
user to remove them **where they were created** (the desktop app's task list, or the routine's own
settings). Never claim they are gone.

**Never** create a task that calls `run_agent`, and never call it from this skill: Tara's
reporting already has a schedule and a budget, and a local cron calling run-now is a second
schedule that spends it. Switching Tara's reporting on or off for a brand is done in Tara at
`https://tara.adup.io/agents` — there is no plugin command for it.

### 7. Deploy all scheduled tasks

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
> then skip to Step 8. Cowork and cloud **routines** schedule differently — see
> `/docs/en/routines`; the task prompts below are still the right content to schedule there.

Now create the scheduled tasks using the `create_scheduled_task` tool — all 14, **minus the two
client reporting tasks when Step 6 said to remove them**. Deploy them in this order (monitoring
first, then optimization, then reporting).

**Why every prompt below repeats the same shop-safety paragraph:** these tasks run on cron, often at overlapping times, and they all share ONE sign-in. `set_active_shop` sets a single *ambient* shop per sign-in (one slot per signed-in device, or per automation key) — so if a task looped `set_active_shop` per client, a concurrently running task would clobber it mid-loop and the task could read (or propose changes against) the wrong client's account. The prompts therefore call `list_shops` once, use `set_active_shop` only to make platform tools discoverable, and pass `shop_slug="<slug>"` explicitly on every single data and proposal call. Keep that paragraph verbatim if you edit these prompts. Tool names in the prompts are namespaced `platform__tool` (`facebook__`, `google_ads__`, `ga4__`, `tiktok__`, `linkedin__`) — only the gateway's own virtual tools are unprefixed, and the Google Ads prefix is `google_ads__`, never `google__`.

#### Monitoring Tasks (3)

```
create_scheduled_task(
  taskId: "adup-budget-pacing",
  description: "Daily budget pacing check across all clients",
  cronExpression: "30 6 * * *",
  prompt: "Run /adup:budget-tracker for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign data with facebook__get_campaign_performance_metrics(shop_slug=\"<slug>\") and facebook__get_campaigns(shop_slug=\"<slug>\") for the current month, calculate pacing by comparing actual spend vs expected. Identify overpacing (>110%) and underpacing (<85%) campaigns. For overpacing >115%, propose budget decreases via facebook__propose_budget_change(shop_slug=\"<slug>\"). For severe overpacing >150%, flag as urgent. Report pacing status per client."
)

create_scheduled_task(
  taskId: "adup-ad-fatigue",
  description: "Daily creative fatigue scan across all clients",
  cronExpression: "0 7 * * *",
  prompt: "Run /adup:ad-fatigue for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: run facebook__detect_ad_fatigue(shop_slug=\"<slug>\", lookback_days=14) — it takes lookback_days, NOT a time_range object, and that span is SPLIT IN HALF (last 7 days vs the 7 before). Do not lower it below 4. If you need the underlying rows, facebook__get_ad_insights REQUIRES a time_range object: facebook__get_ad_insights(shop_slug=\"<slug>\", time_range={\"since\":\"YYYY-MM-DD\",\"until\":\"YYYY-MM-DD\"}, time_increment=1). Check learning phase with facebook__get_adsets(shop_slug=\"<slug>\"). For HIGH fatigue ads (frequency >threshold AND CTR decline >20% OR CPA increase >25%), propose pause via facebook__propose_status_change(shop_slug=\"<slug>\"). For MEDIUM fatigue, propose 15-20% budget decrease on parent ad set via facebook__propose_budget_change(shop_slug=\"<slug>\"). For LOW fatigue, flag for monitoring only. Never propose changes to ads in Learning phase. Save summary."
)

create_scheduled_task(
  taskId: "adup-anomaly-alerts",
  description: "Anomaly detection every 3 hours across all clients",
  cronExpression: "0 */3 * * *",
  prompt: "Run /adup:anomaly-alerts for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull today's data vs 7-day rolling averages from all connected platforms (Facebook: facebook__get_campaign_performance_metrics(shop_slug=\"<slug>\"), Google: google_ads__get_google_ads_campaign_performance(shop_slug=\"<slug>\") with micros/1000000). Detect CRITICAL anomalies: delivery stopped ($0 spend 6h+ while active), spend spikes (>200% of 7-day avg), budget exhaustion (<5% remaining). For CRITICAL: create proposals via the owning platform's tool — facebook__propose_budget_change / google_ads__propose_budget_change / tiktok__propose_budget_change / linkedin__propose_budget_change — each with shop_slug=\"<slug>\". Detect WARNING: CTR drop >30%, CPA spike >50%, frequency >4.0. Report counts: CRITICAL/WARNING/INFO. If weekend, apply wider tolerance."
)
```

#### Optimization Tasks (4)

```
create_scheduled_task(
  taskId: "adup-google-optimize",
  description: "Google Ads optimization on Tuesday and Thursday",
  cronExpression: "0 9 * * 2,4",
  prompt: "Run /adup:google-optimize for all clients with Google Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: google_ads__get_google_ads_account_currency(shop_slug=\"<slug>\"), google_ads__get_google_ads_campaign_performance(shop_slug=\"<slug>\") for last 14 days (divide all micros by 1,000,000). Check Quality Score (flag QS<5 with significant spend), impression share (diagnose budget vs rank loss). For winners (ROAS above target 5+ days, 15+ conversions): propose 15-20% budget increase via google_ads__propose_budget_change(shop_slug=\"<slug>\"). For losers (ROAS below target 5+ days, declining WoW): propose 15-25% decrease the same way. Check RSA asset performance via google_ads__get_google_ads_ad_creatives(shop_slug=\"<slug>\") and propose headline replacements for LOW-rated assets via google_ads__propose_rsa_update(shop_slug=\"<slug>\"). The Google Ads prefix is google_ads__, never google__. All via middleware."
)

create_scheduled_task(
  taskId: "adup-linkedin-optimize",
  description: "LinkedIn Ads optimization on Wednesday",
  cronExpression: "0 9 * * 3",
  prompt: "Run /adup:linkedin-optimize for all clients with LinkedIn Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign analytics for the last 14 days with the linkedin__* tools (e.g. linkedin__get_linkedin_campaigns(shop_slug=\"<slug>\")). Focus on CPL (benchmark: $50-$150 B2B). For winners (CPL below target, 5+ leads/week, improving trends): propose 15-20% budget increase via linkedin__propose_budget_change(shop_slug=\"<slug>\"). For losers (CPL >130% target, declining trends): propose 15-25% decrease. For zero leads with $200+ spent: propose pause via linkedin__propose_status_change(shop_slug=\"<slug>\"). Identify low-CTR creatives (<0.4%) and propose copy updates based on high performers via linkedin__propose_creative_update(shop_slug=\"<slug>\"). All via middleware."
)

create_scheduled_task(
  taskId: "adup-tiktok-optimize",
  description: "TikTok Ads optimization on Tuesday and Thursday",
  cronExpression: "30 9 * * 2,4",
  prompt: "Run /adup:tiktok-optimize for all clients with TikTok Ads connected. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull campaign/adgroup/video reports for the last 14 days with the tiktok__* tools (e.g. tiktok__get_tiktok_campaigns(shop_slug=\"<slug>\") plus the tiktok__* report tools). Key metric: hook rate (3s views/impressions). For winners (hook rate >30%, good CPA/ROAS, 10+ conversions): propose 15-20% budget increase via tiktok__propose_budget_change(shop_slug=\"<slug>\"). For losers (hook rate <20%, poor CPA): propose decrease the same way. For hook rate <10% with spend: propose DISABLE via tiktok__propose_status_change(shop_slug=\"<slug>\") (TikTok uses ENABLE/DISABLE). Flag creative fatigue: any ad 14+ days with declining hook rate needs replacement. All via middleware."
)

create_scheduled_task(
  taskId: "adup-budget-optimize",
  description: "Daily cross-platform budget reallocation",
  cronExpression: "0 10 * * 1-5",
  prompt: "Run /adup:optimize-budget for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull 14-day performance from all connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__*, linkedin__*). Pull ga4__* for blended ROAS. Classify campaigns: Winners (ROAS above target 5+ days, CPA below target, 15+ conversions, not in learning) get 15-20% budget increase. Losers (ROAS below target 5+ days, CPA >130% target, declining WoW) get 15-25% decrease. Frame as reallocation when possible (budget-neutral shifts). Never change campaigns in Learning phase or with <10 conversions. Propose with the owning platform's tool — facebook__propose_budget_change / google_ads__propose_budget_change / tiktok__propose_budget_change / linkedin__propose_budget_change — always with shop_slug=\"<slug>\"; a bare propose_budget_change is ambiguous across platforms. All proposals via middleware."
)
```

#### Reporting Tasks — Client-Facing (3)

```
create_scheduled_task(
  taskId: "adup-monday-briefing",
  description: "Monday morning executive briefing per client",
  cronExpression: "0 8 * * 1",
  prompt: "Run /adup:monday-briefing for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and proposal call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. Per shop: pull last 7 days vs previous 7 days from ALL connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__* with hook rates, linkedin__* with CPL, ga4__* for blended ROAS). Calculate blended ROAS = GA4 revenue / total ad spend. Assign verdict: Great week / Stable / Needs attention / Urgent. Identify top 3 wins and top 3 concerns with specific numbers. Propose actions for concerns via the owning platform's <platform>__propose_* tool with shop_slug=\"<slug>\", through the middleware. Save briefing as markdown to ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monday-briefing_{YYYY-MM-DD}.md (create directory with mkdir -p first). End with cross-client summary ranking which clients need the most attention."
)

create_scheduled_task(
  taskId: "adup-client-report-weekly",
  description: "Weekly client performance report with PPTX",
  cronExpression: "0 15 * * 5",
  prompt: "Run /adup:client-report for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and report call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. DEDUPE FIRST, per shop: call list_agents(shop_slug=\"<slug>\"); if any agents[] entry has agent_type client_reporting or google_sheets with is_active true, SKIP this shop entirely and print '<slug>: skipped — Tara already drafts this report' (Tara drafts this report itself into the same review queue; a second local draft is a duplicate and a second cost). If list_agents is unavailable or errors, treat the shop as not covered. Never call run_agent from this task. Per shop that is not covered: pull last 7 days vs previous 7 days from all connected platforms (facebook__*, google_ads__* with micros/1000000, tiktok__*, linkedin__*, ga4__*). Generate full client report: Executive Summary, Performance by Platform table, What Worked (3-5 wins), What Needs Improvement (3-5 issues with root causes), Recommendations, and Talking Points for client call. Calculate blended ROAS via GA4. Use client-friendly language (no jargon). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_weekly_{YYYY-MM-DD}.md (mkdir -p first). Then generate a PPTX presentation from the content and save as {client}_weekly_{YYYY-MM-DD}.pptx in same folder. Open Finder to the folder after saving: open ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/"
)

create_scheduled_task(
  taskId: "adup-client-report-monthly",
  description: "Monthly client performance report with PPTX",
  cronExpression: "0 9 1 * *",
  prompt: "Run /adup:client-report for all clients (monthly edition). Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data and report call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read or write the wrong client's data. DEDUPE FIRST, per shop: call list_agents(shop_slug=\"<slug>\"); if any agents[] entry has agent_type client_reporting or google_sheets with is_active true, SKIP this shop entirely and print '<slug>: skipped — Tara already drafts this report' (Tara drafts this report itself into the same review queue; a second local draft is a duplicate and a second cost). If list_agents is unavailable or errors, treat the shop as not covered. Never call run_agent from this task. Per shop that is not covered: pull full previous month data from all connected platforms (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*). Include: Executive Summary, Platform Performance MoM comparison, Conversion Funnel Analysis (ga4__get_conversion_funnel(shop_slug=\"<slug>\")), Budget Utilization Review, Channel Mix (GA4 revenue attribution), Creative Performance Summary, What Worked (top 5), What Needs Improvement (top 5 with root causes), Strategic Recommendations for next month, and Talking Points. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_monthly_{YYYY-MM-01}.md (mkdir -p first). Generate PPTX with slides: Title, Exec Summary, Platform Performance, Funnel, Budget Review, Channel Mix, Wins, Improvements, Recommendations. Save as {client}_monthly_{YYYY-MM-01}.pptx in same folder. Open Finder after saving."
)
```

#### Reporting Tasks — Internal (3)

```
create_scheduled_task(
  taskId: "adup-internal-daily-overview",
  description: "Quick morning overview of all clients",
  cronExpression: "30 8 * * 1-5",
  prompt: "Quick daily health check across all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. For each client pull yesterday's data from all connected platforms (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"): total spend, conversions, ROAS/CPA. Compare to 7-day average. Flag anything >20% off baseline. Output a quick status table: Client | Spend | Conv | ROAS | Status (OK/Watch/Alert). Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_daily-overview_{YYYY-MM-DD}.md (mkdir -p first). End with summary: how many clients OK vs needing attention."
)

create_scheduled_task(
  taskId: "adup-internal-weekly-review",
  description: "Friday internal agency-wide performance review",
  cronExpression: "0 16 * * 5",
  prompt: "Internal agency review. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Pull last 7 days from all platforms per client (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"). Generate per-client summary: spend, revenue, blended ROAS, WoW change, key wins, key concerns. Then generate cross-client analysis: total managed ad spend, average portfolio ROAS, client rankings by ROAS, platform performance rankings, optimization actions taken this week. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_weekly-review_{YYYY-MM-DD}.md (mkdir -p first)."
)

create_scheduled_task(
  taskId: "adup-internal-monthly-review",
  description: "Monthly internal agency P&L and strategic review",
  cronExpression: "0 10 1 * *",
  prompt: "Monthly internal strategic review. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Pull full previous month data per client (facebook__*, google_ads__*, tiktok__*, linkedin__*, ga4__*, each with shop_slug=\"<slug>\"). Per client: total spend by platform, blended ROAS, MoM comparison, budget utilization, optimization activity (proposals created/approved/rejected). Generate portfolio summary: total managed spend, average ROAS, client rankings, platform performance rankings across portfolio, creative health (average lifespan, refreshes needed), total optimization actions taken. Strategic recommendations for next month. Save per-client as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/internal_monthly-review_{YYYY-MM-01}.md (mkdir -p first)."
)
```

#### Analysis Tasks (1)

```
create_scheduled_task(
  taskId: "adup-creative-intelligence",
  description: "Weekly creative playbook update per client",
  cronExpression: "0 10 * * 1",
  prompt: "Run /adup:creative-intelligence for all clients. Call list_shops ONCE to get every shop's slug and connected_platforms. Call set_active_shop once up front only so the platform tools become discoverable (re-call it for a shop whose tools are not listed); NEVER rely on it for routing. For each shop, pass shop_slug=\"<slug>\" explicitly on EVERY data call — these scheduled runs share one ADUP sign-in and can run concurrently, so an ambient active shop set by one run clobbers another and a task can read the wrong client's data. Per shop: pull 30-day ad-level data with creative details from all platforms (Facebook: facebook__get_ad_insights(shop_slug=\"<slug>\") + facebook__get_ads(shop_slug=\"<slug>\"), Google: google_ads__get_google_ads_ad_performance(shop_slug=\"<slug>\") + google_ads__get_google_ads_ad_creatives(shop_slug=\"<slug>\")). Categorize creatives by format (video/static/carousel), content type (testimonial/UGC/product), and copy pattern (question/statement/CTA type). Score each category on CTR (20%), CPA (30%), ROAS (30%), Durability (20%). Build creative playbook: top formats, winning content types, copy insights, recommendations. Only score categories with 1000+ impressions and 5+ conversions. Save as ~/Desktop/ADUP-Reports/{client-slug}/{YYYY-MM}/{client}_creative-playbook_{YYYY-MM-DD}.md (mkdir -p first)."
)
```

### 8. Report deployed tasks

After all tasks are created, present a summary to the user. Include the per-brand reporting
lines from Step 6a, and when the two client reporting tasks were removed or not created, show
them as such instead of as deployed (and count 12, not 14):

```
ADUP Fully Configured!

Signed in as: <email> (<role>)
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
  15:00  Weekly Report + PPTX ........... Fri        (skips brands whose report Tara already drafts)
  09:00  Monthly Report + PPTX .......... 1st of month (same)

Reporting per brand:
  acme-nl      Reporting: drafted by Tara → local weekly/monthly tasks removed
  adidas-eu    Reporting: not drafted by Tara → local weekly/monthly tasks kept

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

### 9. Optional: Deploy for single client only

If the user says they only want to set up tasks for a specific client, ask which client and only create report folders for that one. The scheduled tasks themselves loop through all clients automatically, so no change needed — but the report folder only needs to be created for the requested client.

## Notes

- This skill never asks for, displays or stores a credential. The sign-in is Claude's (OS keychain); if something still shows an `ADUP_API_KEY`, that is a leftover for Step 2 to remove
- If tasks already exist (user re-runs setup), the `create_scheduled_task` tool will handle duplicates — existing tasks with the same `taskId` will be updated, not duplicated
- If the user only wants to re-deploy tasks, Step 1 is just the `list_shops` check — Step 2 (leftovers) and Step 6 (brands Tara already reports on) still run every time, because Step 6 is how a brand whose Tara reporting was switched on or off since the last setup gets its local reporting task removed or re-created
- The only tasks setup ever deletes are `adup-client-report-weekly` and `adup-client-report-monthly`, matched by exact `taskId`, each printed by name before and after deletion
- All 14 tasks iterate over all clients automatically — no per-client task creation needed. They do it by passing `shop_slug="<slug>"` per call, **not** by re-pointing an ambient active shop per client: `set_active_shop` sets one shop per sign-in, so a per-client `set_active_shop` loop races with the other cron tasks sharing that sign-in and can read or write the wrong client
- The task prompts reference specific ADUP MCP tools by name — these are the actual function names the AI should call when executing. All platform tools are namespaced `platform__tool` (`facebook__`, `google_ads__`, `ga4__`, `tiktok__`, `linkedin__`, …); only the gateway's own virtual tools (`list_shops`, `set_active_shop`, the report tools, the proposal / creative-asset tools and the agent tools) are unprefixed. A bare `propose_budget_change` / `propose_status_change` is ambiguous — those tools exist on four platforms

## Automation machines

A machine that runs scheduled tasks unattended and never had a browser sign-in (a server, a CI
runner) cannot complete the OAuth flow. Two options, in order of preference:

1. **Sign in once, interactively, on that machine.** `claude mcp login plugin:adup:adup --no-browser`
   prints a URL to open on any device and asks for the redirect URL back. The tokens live in that
   user's keychain (Linux: Claude Code's credentials file), refresh automatically, and stay valid
   while the machine keeps using them — 30 days of inactivity signs it out, 12 months at the most.
2. **The employee API key through a second, hand-added connector.** Get the key from Tara →
   **My MCP setup** (the "automation key"), then on that machine:

   ```bash
   claude mcp add --transport http --scope user adup-automation https://gateway.adup.io/mcp \
     --header "Authorization: Bearer emp_…"
   ```

   (or `./install.sh --automation emp_…` from the plugin checkout). The skills reference tools by
   name, not by connector, so they work over this connector unchanged. The plugin's own `adup`
   connector keeps offering to authenticate on that machine — expected; ignore it there. Treat the
   key like a password and rotate it from Tara (My MCP setup → Regenerate key) if it may have leaked.
   Never put the key back into this plugin's config or into an environment variable: nothing reads
   it there any more.

## Multi-user macOS note

Sign-ins are per macOS user — the keychain is per user. Each person signs in once with their own
Tara account (Step 1); nothing of one user's session is visible to another.

## Security

Nothing this skill writes is a credential. The connector's access token lives 60 minutes and is
refreshed by Claude Code from a rotating refresh token, both kept in the OS keychain. Signing a
device out from Tara (**My MCP setup → Connected devices**) revokes it within a minute; so does
`claude mcp logout plugin:adup:adup` locally. If an install older than 2.0.0 left key copies on
disk, Step 2 removes them.
