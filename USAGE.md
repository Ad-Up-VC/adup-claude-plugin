# Using ADUP — the plugin and the connector

How to get correct answers out of ADUP, whether you use the Claude Code plugin or add the MCP
connector directly to Claude.ai / Cowork / any other MCP client.

If you read nothing else, read [The five rules](#the-five-rules). Rule 3 —
**always pass `shop_slug`** — is the one that silently returns the wrong client's data when
it is skipped.

---

## 1. Two ways to connect

| | **Plugin** (Claude Code) | **Connector only** (Claude.ai, Cowork, other MCP clients) |
|---|---|---|
| What you add | The `adup` plugin from the marketplace | One MCP server URL + your API key |
| Tools | All of them, aggregated | All of them, aggregated — identical surface |
| Skills (`/adup:facebook-ads`, …) | ✅ 29 bundled | ❌ none — a plugin feature |
| Knows the rules below | ✅ the skills enforce them | ❌ **you** must state them — paste [§9](#9-drop-in-rules-for-a-bare-connector) |

Both talk to the same gateway with the same key. The connector is not a lesser product — it is
the same tools without the packaged workflows, which means nothing is reminding the model to
pass `shop_slug` or to check a tool's schema. That is what §9 is for.

---

## 2. Setup

### Plugin

```
/adup:setup      # stores your API key
/adup:connect    # verifies the key, environment, and which brands you can see
```

Get your key from **tara.adup.io → Settings → API**.

### Connector

Add one MCP server:

| | |
|---|---|
| URL | `https://gateway.adup.io/mcp` |
| Header | `Authorization: Bearer <your ADUP API key>` |

That single connector aggregates **every platform the brand has connected**. There are no
per-platform connectors to add.

Two connectors exist beyond it, and only if you need them:

- `https://gateway.adup.io/mcp/custom` — external MCP servers your organisation registered in
  the Control Center. These are **not** part of the base connector.
- `https://gateway.adup.io/mcp/{platform}` — the legacy per-platform routes. Still supported,
  no reason to use them for new setups.

### Environments

Production needs no configuration, and the connector cannot be moved off it — its URL is a
literal. `ADUP_API_BASE` redirects only the direct central-api calls (reports, proposals, creative
assets), so setting it splits the plugin across two environments: MCP tools from production,
everything else from wherever you pointed it. Useful for testing, not a supported setup. See
`README.md`.

**A key belongs to exactly one environment.** A key from another environment returns
`invalid_token` while being perfectly valid — check the environment before blaming the key.

---

## The five rules

### Rule 1 — Start with `list_shops`

It returns every brand you can access, its `shop_slug`, and which platforms are connected to
each. Never guess a slug from a brand name.

### Rule 2 — `set_active_shop` is about **tool discovery**, not just routing

The connector only *lists* a brand's platform tools once that brand is active — or if your key
has exactly one brand, in which case it resolves automatically.

> **"The Facebook tools aren't there" almost always means "no active shop".** An agency key with
> no active shop sees only the six built-in tools and zero `facebook__*`.

```
set_active_shop(shop_slug="acme-nl")
```

The tool list changes when the active shop changes. The gateway does emit
`notifications/tools/list_changed`, but most clients ignore it — **reload or reconnect after
switching brands**.

### Rule 3 — Pass `shop_slug` on every single call

Every aggregated tool accepts an optional `shop_slug`. Pass it. Always.

```
facebook__get_campaigns(shop_slug="acme-nl", ...)
google_ads__get_google_ads_campaign_performance(shop_slug="acme-nl", ...)
```

The gateway resolves the target brand most-specific-first:

1. explicit `shop_slug` argument →
2. the active shop (set by `set_active_shop`) →
3. the sole shop, if the key has exactly one

**Why it matters:** the active shop is stored **once per API key**, not per session. Anything
running concurrently on that key — scheduled tasks, a loop over five clients, two open windows —
races: one run's `set_active_shop` clobbers the other's, and a call that relied on the ambient
shop reads the wrong client. An explicit `shop_slug` is the only race-free option; there is no
request header that pins the brand.

- **Interactive, one brand:** `set_active_shop` (you need it for discovery anyway), then still
  pass `shop_slug` — it costs nothing.
- **Multiple brands, loops, parallel or scheduled runs:** `shop_slug` per call, no exceptions.

Safety guarantees worth knowing: `shop_slug` is a gateway-only routing argument, stripped before
the request is forwarded upstream — so it never conflicts with a tool's own parameters. A
`shop_slug` outside your access is **rejected (-32001), never silently redirected** to another
brand.

### Rule 4 — Tool names are `platform__tool` (double underscore)

**The virtual tools are unprefixed** — they are served by the gateway itself:

`list_shops` · `set_active_shop` · `create_report` · `get_kpi` · `get_report_template` ·
`get_report_branding`

plus the managed-agent tools (see §6): `list_agents` · `get_agent_runs` · `get_agent_output` ·
`run_agent` · `list_agent_skills` · `publish_agent_skill` · `get_agent_skill_package`

**Everything else carries a platform prefix.** The built-in prefixes are:

```
facebook      google_ads    ga4        gsc         linkedin    hubspot
intercom      tiktok        snapchat   shopify     openai_ads  bol_com
reddit_ads    x_ads         dv360      adjust      trustpilot
```

plus vendor servers registered per brand (`semrush`, `klaviyo`, `ahrefs`, …).

> **The Google Ads prefix is `google_ads__`, never `google__`.** `ga4__` and `gsc__` are separate
> platforms with their own connections. Never invent a prefix that is not in the list.

Examples: `facebook__get_ad_insights`, `google_ads__execute_google_ads_gaql_query`,
`ga4__get_ecommerce_performance`, `gsc__query_performance`, `tiktok__get_tiktok_campaigns`,
`shopify__list_orders`, `linkedin__get_linkedin_campaigns`.

### Rule 5 — Read the tool's own schema before calling it

Sibling tools genuinely disagree with each other about argument shapes (they wrap different
vendor APIs). The tool list is authoritative. §4 lists the shapes that catch people out.

---

## 4. Argument shapes that differ per platform

| Platform | Date arguments |
|---|---|
| Facebook (insights) | `time_range` object: `{"since": "2026-08-01", "until": "2026-08-31"}` |
| Facebook (`ads_insights_get`) | neither — `date_preset` + `time_increment` |
| Facebook (analysis) | no dates — `lookback_days` on `analyze_creative_performance`, `detect_ad_fatigue` |
| Facebook (`get_budget_pacing`) | `date_range` as a **string**: `"this_month"`, `"last_30d"`, `"this_week"` |
| Google Ads · TikTok | flat `start_date` / `end_date` strings, `YYYY-MM-DD` |
| GA4 | `time_range` with **nested numbers**: `{"since": {"year": 2026, "month": 8, "day": 1}, "until": {…}}` |
| LinkedIn | `date_range` (TimeRange object) |
| Intercom | camelCase `startDate` / `endDate` in **`DD/MM/YYYY`**, max **7-day** window |
| everything else | its own shape — `x_ads` uses `start_time`/`end_time`, `adjust` uses `date_period`, `bol_com` uses `period_start_date`/`period_end_date`. Read the schema. |

Other things that bite:

- **GA4 reporting tools require four arguments, not two.** Every GA4 reporting tool requires
  `user_prompt` (the question in natural language), `time_range`, **`dimensions` and
  `metrics`** — a call with only a prompt and dates fails validation.
  `ga4__run_realtime_report` is the exception with no `time_range` at all (and it rejects the
  `date` dimension — realtime takes dimensions like `city`).
- **Some GA4 tools demand specific dimensions or metrics**, and say so one at a time:
  `ga4__get_conversion_events` needs the `eventName` dimension **and both** `eventCount` and a
  conversions metric (`keyEvents` or `conversions`); `ga4__get_conversion_event_details` needs
  `eventCount`. The error names exactly what is missing — read it and add that one, rather than
  guessing at a whole new argument set.
- **`tiktok__get_tiktok_business_center` needs a `bc_id`** that no tool returns under that name.
  Get it from `tiktok__get_tiktok_account_info`, where the field is called **`owner_bc_id`**.
- **Google Ads costs are in micros.** Divide by 1,000,000. A "€4,300,000 CPC" is €4.30.
- **`google_ads__execute_google_ads_gaql_query` takes raw GAQL**, not a natural-language prompt.
- **TikTok report tools are ID-scoped and have no "all" mode.**
  `tiktok__get_tiktok_campaign_reports` requires `campaign_ids`;
  `tiktok__get_tiktok_ad_reports` requires `ad_ids`. Fetch the IDs first
  (`tiktok__get_tiktok_campaigns` / `..._ads`), then report on them. A date range alone fails
  validation.

---

## 5. Writes go through approval

Write tools are named `propose_*` (plus the creative-creation tools), and calling one **files a
proposal in the agency's action queue** rather than executing:

```
{platform}__propose_budget_change(shop_slug="acme-nl", entity_type="campaign",
  entity_id="1234", new_budget=250,
  reasoning="ROAS 4.1 over 14 days at a 60% impression-share ceiling; +25% headroom.")
```

- **Always send `reasoning`** — it is what the human approver reads before approving or denying.
  The four `{platform}__propose_bulk_launch` tools call it **`shared_reasoning`** instead (it
  applies to every proposal in the batch).
  ⚠️ **Almost nothing enforces this.** The tool schemas mark `reasoning` as required, but the
  gateway builds the proposal from your arguments *before* the tool itself ever validates them —
  so a write that names an entity and a value but omits `reasoning` does **not** error. It files
  a proposal with no rationale, and the approver sees a budget or status change with nothing
  explaining it. Verified live on staging. Treat `reasoning` as your responsibility, not the
  platform's.
  The one case that *is* refused is a call with **no content at all** — no entity to act on and
  no value to propose. That returns `-32602` and files nothing. Passing only `reasoning` counts
  as no content, so it is refused too.
- A proposal returns `proposal_id` and `status`. Nothing changes until someone approves it in
  the portal.
- **Ads default to `status: "PAUSED"`.** The ADUP skills always propose PAUSED, but the
  underlying create tools also accept `"ACTIVE"` — so if you are calling them raw, set
  `status` explicitly rather than assuming it.
- Some organisations block specific tools entirely via the MCP Control Center — that is
  `-32004`, not a bug.

**Not every write is a `propose_*` tool.** A handful of tools mutate directly and take no
`reasoning` at all — `gsc__submit_sitemap`, `gsc__delete_sitemap`,
`hubspot__hubspot_create_contact`, `hubspot__hubspot_create_company`,
`ga4__unmark_event_as_conversion`, and the Facebook `ads_*_create` / `ads_*_update` family. The
gateway still recognises them as writes by name and **defaults them to approval**, but an
organisation can set a tool's Control Center policy to `allow`, and then the call executes for
real.

The gateway decides "is this a write?" from the tool name: it is a write when the name contains
any of these as a whole underscore-separated token —

`create`, `update`, `delete`, `mutate`, `set`, `add`, `remove`, `propose`, `pause`, `enable`,
`disable`, `write`, `publish`, `launch`, `archive`, `submit`, `unmark`, `upload`, `send`,
`reply`, `move`, `start`, `stop`

Treat any tool matching that list as live-fire unless you know your organisation's policy.

### You cannot read the approval rules from here

There is no tool, and no gateway route reachable with an ADUP API key, that returns an
organisation's **approval settings, auto-approval rules, or action audit log**. Those live behind
the portal's own session auth, and `/actions/{shop}/settings`, `/actions/{shop}/rules` and
`/actions/{shop}/audit-log` answer `Unauthenticated.` for an `emp_` key. This is deliberate, not
an outage — do not build a skill that depends on reading them.

The practical consequence: **you cannot tell in advance whether a proposal will wait for a human
or be auto-approved and executed.** An organisation may have rules that approve certain changes
automatically. So do not describe a proposal to the user as "safe because someone will review
it" — say that it has been filed for review, and let the portal be the authority on what happens
next. If a user needs to know their auto-approval rules, point them at the portal.

---

## 6. Reports and targets

| Tool | What it does |
|---|---|
| `get_report_branding` | Agency/brand design system — fetch **before** building a report |
| `get_report_template` | Last approved report's structure + accumulated human edits |
| `get_kpi` | The brand's KPI targets (year/quarter/month, budget caps, per-platform metric targets) |
| `create_report` | Submits a report **for agency review** — it is not published to the client |

`create_report` takes a complete, self-contained HTML document: inline CSS, inline SVG charts,
no external scripts, fonts, stylesheets or images. Oversized HTML is rejected with a size hint —
switch base64 raster images to inline SVG rather than trimming content.

`get_report_template` also returns `agency_instructions` — the house instructions the managed
Reporting Skill runs with. Apply them *after* the report contract's rules, never instead of them.

### Managed agents

The agency's managed agents (Reporting Skill, Spreadsheet Skill, Assistant) run server-side in
Tara and file into the same review queue. Operate them with these tools — every one takes an
explicit `shop_slug`:

| Tool | What it does |
|---|---|
| `list_agents` | The brand's agents: `is_active`, schedule, `needs_attention`, next/last run — plus `available_types` |
| `get_agent_runs` | Recent runs: status (`scheduled`/`running`/`generating`/`ready`/`failed`/`budget_reached`), period, summary, artifacts, cost |
| `get_agent_output` | `kind: html` → the Tara portal path (review happens there); `pptx`/`xlsx` → a 15-minute signed download URL |
| `run_agent` | Starts a run **now**. It spends the agent's per-run budget — confirm with the user first, never put it in a schedule or a loop. 409 = a run is in flight; 422 = the agent is off |
| `list_agent_skills` · `publish_agent_skill` · `get_agent_skill_package` | The agency's custom agent skills: list, publish a zipped `SKILL.md` folder (≤ 2 MB, `SKILL.md` at the zip root), download one |

Activating agents, editing schedules/budgets/instructions, attaching skills and approving reports
are done in Tara at `/agents/<agent_type>` — there is no tool for them, by design. `report_ready`
and `report_failed`, if you ever see them, are worker-side tools: do not call them.

Before a local report is built, check `get_agent_runs` for a `ready` run covering the period and
offer it — one draft per period.

---

## 7. Errors, and what they actually mean

| Response | Meaning | Fix |
|---|---|---|
| `401 invalid_token` | Key rejected — often a key from a different environment | Check the key's environment before assuming it is revoked |
| `-32001 Shop "x" not in your accessible shops` | Correct behaviour, protecting client scope | Use a slug from `list_shops` |
| `-32602 No shop selected` | No `shop_slug`, no active shop, and more than one accessible | Pass `shop_slug` or call `set_active_shop` |
| `-32602 Tool 'x' is not available for this brand` | Tool exists, this brand has no such connection | Check `connected_platforms` from `list_shops` |
| `-32004 blocked by your organisation's MCP Control Center` | Policy, not a failure | Ask an owner to adjust Tool Access |
| `-32005` | Per-employee rate limit reached | Slow down; limits are configurable |
| `-32601 Platform x not connected for shop y` | The brand has not connected that platform | Connect it in the portal |
| `-32603 Upstream <platform> returned 4xx/5xx` | The vendor API answered with an error | Read the message — usually an account condition |

**A platform error is not a platform outage.** In the last production sweep, 21 of 21 failures
were external account conditions: HTTP 402 (a frozen Shopify store), 403 (a token missing a
scope), a TikTok permission that was never granted. When *every* tool of one platform fails
identically, look at the account, not the code.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "There are no Facebook/Google tools" | No active shop (Rule 2) | `set_active_shop`, then reload/reconnect |
| Tools still missing after switching brands | Client ignored `list_changed` | Reload or reconnect the connector |
| Answers are about the wrong client | Ambient-shop race (Rule 3) | Pass `shop_slug` on every call |
| Data tools work, reports/proposals 401 | Only one of the two env vars set | Set the gateway and central-api hosts as a pair |
| Everything 401s with a valid key | Key from another environment | Match key to environment |
| One platform fails on all its tools | Account condition upstream | Check billing, token scopes, permissions |
| A write "did nothing" | It filed a proposal, by design | Approve it in the portal action queue |

---

## 9. Drop-in rules for a bare connector

Using the connector without the plugin? Paste this into your project instructions / `CLAUDE.md`
so the model behaves the way the skills do:

```markdown
## ADUP connector rules

1. Call `list_shops` first to resolve brand names to slugs. Never guess a slug.
2. Call `set_active_shop(shop_slug=...)` before expecting platform tools to exist — the
   connector only lists a brand's tools once that brand is active. After switching brands,
   reload the tools.
3. Pass `shop_slug="<slug>"` on EVERY data and action call, even after set_active_shop. The
   active shop is shared per API key and races across parallel or scheduled runs.
4. Tool names are `platform__tool` (double underscore). Unprefixed tools are only:
   list_shops, set_active_shop, create_report, get_kpi, get_report_template,
   get_report_branding, and the managed-agent tools list_agents, get_agent_runs,
   get_agent_output, run_agent, list_agent_skills, publish_agent_skill,
   get_agent_skill_package. The Google Ads prefix is `google_ads__`, never `google__`.
5. Read each tool's schema before calling it — date arguments differ per platform
   (Facebook `time_range` {since,until}; Google Ads/TikTok flat start_date/end_date;
   GA4 nested {year,month,day}; Intercom camelCase DD/MM/YYYY, 7-day max).
6. Google Ads costs are in micros — divide by 1,000,000.
7. Every `propose_*` write requires a `reasoning` string and only files a proposal for human
   approval. It never changes anything live, and approved ads land PAUSED.
8. Never invent tool names or platform prefixes. If a tool is not in the list, say so.
9. `run_agent` spends a managed agent's per-run budget: confirm with the user before every
   call, never schedule it, never loop it over shops. Reports are reviewed in Tara, not here.
```

---

## 10. Quick reference

**Virtual tools (unprefixed):** `list_shops`, `set_active_shop`, `create_report`, `get_kpi`,
`get_report_template`, `get_report_branding`, `list_agents`, `get_agent_runs`,
`get_agent_output`, `run_agent`, `list_agent_skills`, `publish_agent_skill`,
`get_agent_skill_package`

**Built-in platform prefixes:** `facebook`, `google_ads`, `ga4`, `gsc`, `linkedin`, `hubspot`,
`intercom`, `tiktok`, `snapchat`, `shopify`, `openai_ads`, `bol_com`, `reddit_ads`, `x_ads`,
`dv360`, `adjust`, `trustpilot` — plus per-brand vendor servers.

**Shop precedence:** `shop_slug` argument → active shop → sole shop.

**Plugin skills:** see the tables in `README.md`.
