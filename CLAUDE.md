# adup-claude-plugin

**Role:** Claude Code plugin (`adup`, repo `adup-claude-plugin`) exposing the ADUP MCP connector and its bundled analyst skills.

## Phase 0 state
Single `adup` connector in `.mcp.json`. 27 bundled skill directories. 1 agent (`adup-analyst.md`). Chat-stream references in skills cleaned. No agent-operating command (see **Tara drafts reports too**).

## .mcp.json — single aggregated connector
ONE connector: `adup → https://gateway.adup.io/mcp`, **header-less**. Auth is OAuth 2.0.

### Sign-in is OAuth 2.0 (v2.0.0, TARA_PLUGIN_OAUTH2_PLAN.md WS5)
The connector carries no `headers` and no `oauth` block. Claude Code runs the MCP authorization
flow against the gateway (RFC 9728/8414 discovery → RFC 7591 dynamic client registration → PKCE
authorization code), the gateway 302s the browser to the portal consent page
(`tara.adup.io/oauth/authorize`), the employee signs in with the normal Tara login and approves,
central-api mints a 60-min `mcpat_` access token + a rotating `mcprt_` refresh token, and Claude
Code keeps both in the OS keychain and refreshes them itself. `claude mcp login plugin:adup:adup`
/ `claude mcp logout plugin:adup:adup` drive it from a terminal; the portal's **My MCP setup →
Connected devices** lists and revokes every sign-in (self-service; owners cannot revoke others'
devices yet).

**Why header-less is load-bearing.** A static `Authorization` header DISABLES Claude Code's OAuth
path for the whole entry — there is no hybrid. `pack.sh --verify` fails on any `headers` / `oauth`
key on the connector, on a leftover `userConfig.ADUP_API_KEY`, and on any `Bearer $ADUP_API_KEY`
in `skills/` or `install.sh`.

**Surfaces.** CLI: `/mcp` → adup → Authenticate. Desktop-app Code tab sessions are non-interactive
for MCP OAuth → one terminal login. Cowork: approve the prompt, else the terminal login once.
Headless machines: `--no-browser` login once, or the employee key through a hand-added connector
(`install.sh --automation emp_…` → `adup-automation`); skills reference tools by name so they work
over either connector.

**History.** 1.7–1.9 took the key from `plugin.json` `userConfig.ADUP_API_KEY` (after the env-var
era, whose `${ADUP_API_KEY}` only expanded in the CLI, measured 2026-08-24). Both are gone; `setup`
Step 2 / `reset` Step 3 remove the cleartext copies the env-var era wrote to LaunchAgent plists,
`~/.claude/settings.json` and shell profiles.

### Environments
The connector URL is literal, so the plugin always signs in against production. There are **no
direct HTTP calls** any more — everything a skill needs is a connector tool — so `ADUP_API_BASE`
is gone along with `ADUP_GATEWAY_BASE`; `/adup:setup` / `/adup:reset` clear leftovers. Testing
another environment = a hand-added connector against that gateway (`claude mcp add --transport
http adup-staging https://gateway-staging.adup.io/mcp`), which signs in against that environment's
portal. `gateway.kodeia.com` is **dev**, not staging.

The gateway's base `/mcp` connector AGGREGATES every connected platform's tools for
the active shop, namespaced `platform__tool` (e.g. `facebook__get_campaigns`,
`google_ads__execute_google_ads_gaql_query`), plus the unprefixed virtual tools (see
**Tool naming** below). Per-platform `/mcp/{platform}` connectors still exist
server-side (backward-compat) but the plugin no longer lists them — one connector
serves everything, so a single sign-in covers all platforms.

> History: an earlier "Phase 1" briefly split this into 9 connectors (base + one
> per platform). Reverted in favour of base-connector aggregation (tara-gateway
> PR #57) because single-URL clients (Claude.ai / Cowork web connector) can only
> add ONE connector URL.

## Branches and promotion
`development` → `staging` → `main`. The `staging` branch was added 2026-08-05; before that the
repo had only `development` and `main`, and "promote to staging" had no meaning here (unlike
tara-gateway, which has had a staging tier all along).

⚠️ **A staging BRANCH is not a staging distribution channel.** Clients install by adding this
repo as a plugin marketplace, and that resolves `.claude-plugin/marketplace.json` from the
**default branch (`main`)**. So nothing on the `staging` branch is installable from the
marketplace: the branch is an integration tier where a change is verified before it reaches
`main`, and publishing still means merging to `main`.

To test a `staging`-branch build before it is published, install from the working tree
(`--plugin-dir`) — do not expect `/plugin marketplace update` to see it.

## The marketplace is public — production only
`.claude-plugin/marketplace.json` is the PUBLIC distribution channel. Anyone who adds this repo
as a marketplace is offered every plugin listed in it, customers included. **It lists `adup` and
only `adup`**, and `pack.sh --verify` fails if anything else appears there.

**Testing against staging** = a hand-added connector against `gateway-staging.adup.io/mcp` with its
own OAuth sign-in against the staging portal (or a variant build with a literal staging URL,
tested from `--plugin-dir`). No env var moves the plugin any more.

> History: a separate internal `adup-staging` plugin variant used to be generated (`make-staging.sh`)
> and committed alongside `adup` as `./adup-staging` + `adup-staging.plugin`. It was listed publicly
> once (0eac391, 2026-08-03) and a customer was shown an **Adup staging** install card on 2026-08-10
> — a description is not an access control. The whole variant (tree, bundle, generator, and its
> pack/CI wiring) was removed on 2026-08-21; the env-var override above replaces it.

## Shop-change tool renewal
After `set_active_shop`, the gateway emits `notifications/tools/list_changed`, but
most MCP clients (Claude Code / Cowork) don't act on it — reload tools / reconnect
to pick up the newly-active shop's tools.

## Tool naming
The **virtual** tools are served by the gateway itself and are **unprefixed**: the six
`list_shops`, `set_active_shop`, `create_report`, `get_kpi`, `get_report_template`,
`get_report_branding`, plus the proposal / creative-asset tools the creative skills use —
`list_proposals`, `get_proposal`, `list_replication_requests`, `update_replication_request`
(creative-status) and `find_creative_asset`, `import_creative_asset_url`, `create_creative_upload`,
`finalize_creative_upload` (creative-launch). These replaced the skills' `curl … $ADUP_API_KEY`
calls in 2.0.0: an OAuth plugin holds no key, so nothing may call central-api directly. The
gateway also lists a handful of agent tools; three of them —
`list_agents`, `get_agent_runs`, `get_agent_output` (html only) — are read by the setup dedupe
and the client-report pre-flight, and nothing else uses them (see **Tara drafts reports too**
below). `run_agent`, `get_run_context`, `report_ready`, `report_failed` and the
`*_agent_skill*` tools must never be called by a skill.

**Every other tool is namespaced `platform__tool`** (double underscore). The only
valid platform prefixes are:

```
facebook, google_ads, ga4, gsc, linkedin, hubspot, intercom, tiktok, snapchat,
shopify, openai_ads, bol_com, reddit_ads, x_ads, dv360, adjust, trustpilot
```

plus remote vendor servers registered per brand (e.g. `semrush`).

## Argument gotchas (verified against the live tool schemas)
The tool list is authoritative — read each tool's schema before calling it. Three
shapes trip people up, because sibling tools disagree:

- **Date arguments are not uniform.** Facebook insight tools take a `time_range`
  object (`{"since": "YYYY-MM-DD", "until": "YYYY-MM-DD"}`); Google Ads and TikTok
  take flat `start_date` / `end_date` strings; LinkedIn takes `date_range` (a
  TimeRange object); and some Facebook analysis tools take neither —
  `facebook__analyze_creative_performance` and `facebook__detect_ad_fatigue` take
  `lookback_days`, `facebook__get_budget_pacing` takes a `date_range` **string**
  (`"this_month"`, `"last_30d"`, `"this_week"`). Never assume; check the schema.
- **TikTok report tools are ID-scoped and have no "all" mode.**
  `tiktok__get_tiktok_campaign_reports` requires `campaign_ids`, and
  `tiktok__get_tiktok_ad_reports` requires `ad_ids` — along with `start_date` and
  `end_date`. Fetch the IDs first (`tiktok__get_tiktok_campaigns` /
  `tiktok__get_tiktok_ads`), then report on them. Calling them with only a date
  range fails validation.
- **Every `propose_*` write tool requires `reasoning`** — plus the entity it acts
  on (`entity_type` + `entity_id`, or `campaign_id` / `adset_id` / `ad_group_id` /
  `creative_id` depending on the tool) and the new value (`new_budget`,
  `new_status`, …). `reasoning` is not decoration: it is what the human approver
  reads in the action queue before approving or denying, so write it for them.

Examples: `facebook__get_campaigns`, `facebook__get_ad_insights`,
`google_ads__execute_google_ads_gaql_query`,
`google_ads__get_google_ads_campaign_performance`,
`ga4__get_ecommerce_performance`, `gsc__query_performance`,
`tiktok__get_tiktok_campaigns`, `shopify__list_orders`,
`linkedin__get_linkedin_campaigns`.

**The Google Ads prefix is `google_ads__`, never `google__`.** Never invent a
prefix that is not in the list above.

## Selecting the client — three steps, always
1. `list_shops` → brands and their `connected_platforms`.
2. `set_active_shop(shop_slug="<slug>")` — **required for tool DISCOVERY**, not just
   routing. The aggregator only *lists* a shop's platform tools once that shop is
   active (or the key has exactly one shop). Without it an agency key sees ONLY the
   six virtual tools — no `facebook__*` at all. This is the part people get wrong:
   "the tools aren't there" almost always means "no active shop".
3. Pass `shop_slug="<slug>"` explicitly on EVERY data/action call.

Per-call the gateway resolves the target shop with two levels of precedence:
(1) explicit `shop_slug` tool argument → (2) ambient active shop (equivalently, the
sole shop when the key has only one). Every aggregated platform tool advertises an
optional `shop_slug`; the gateway strips it before proxying upstream, so this needs
no MCP-server change.

**Concurrency.** `set_active_shop` sets ONE ambient shop **per sign-in** — one slot per
signed-in device for an OAuth sign-in (the gateway keys it on the token family, so a
token refresh never loses it), one per key for an automation key. That is fine for a
single interactive session, but concurrent runs sharing a sign-in (e.g. N scheduled
automations at night) race: one run's `set_active_shop` clobbers another's, and a call
that relied on the ambient shop reads the wrong client. So:

- **Interactive, one client:** `set_active_shop`, then still pass `shop_slug` on
  data calls — it costs nothing and removes the ambient dependency.
- **Multiple clients in one session, loops, parallel or scheduled runs:** always
  pass `shop_slug="<slug>"` per call, e.g.
  `google_ads__get_google_ads_campaign_performance(shop_slug="nike", ...)`.
  Never rely on the ambient shop inside a loop or automation.

There is no request-header mechanism for pinning the shop — the gateway does not
read one. `shop_slug` per call is the only race-free option.

## Tara drafts reports too — the plugin has NO agent commands (v1.9.0)
Tara's agents (`Modules/ClientAgents` on central-api) are configured, run and reviewed **in Tara
only**, under **Agents** (`<TARA>/agents`). The plugin ships no command that lists, runs, or
publishes anything agent-related: `/adup:agents` (v1.8.x, dev only, never on main) and
`/adup:sync-skills` (≤ 1.7, synced a portal skill library that no longer exists) were both removed
in 1.9.0 — see `PLUGIN_SKILLS_REMOVAL_PLAN.md` at the GitHub folder root. Do not re-add either.

What survives are two **silent** hooks, kept so a brand does not get two drafts and two costs in
the same review queue:

- **`/adup:setup` Step 6 "Brands Tara already reports on".** Calls `list_agents(shop_slug)` per
  shop. The 14 local tasks are **agency-wide** (each prompt loops all shops), so per-brand dedupe
  lives **inside** the two reporting prompts (`adup-client-report-weekly` / `-monthly` skip brands
  where an `agents[]` entry of type `client_reporting` / `google_sheets` has `is_active: true`);
  when *every* brand is covered the two tasks are not created and existing ones are deleted
  (`list_scheduled_tasks` → exact `taskId` match → `delete_scheduled_task`, printed before/after);
  a brand whose Tara reporting is later switched off is picked up again by the run-time check, and
  the tasks are re-created on the next setup. `list_agents` missing or erroring → treat every
  brand as not covered. Without the scheduled-tasks tools (Cowork/cloud): list and instruct, never
  claim removal. Monitoring, optimisation, Monday briefing, internal reviews, creative playbook:
  untouched.
- **`/adup:client-report` pre-flight 2b "Already drafted by Tara?".**
  `get_agent_runs(shop_slug, 'client_reporting', limit 3)` → a `ready` run covering the period is
  offered first (default: open the Tara link from `get_agent_output(kind='html')` →
  `{client_report_id, portal_path}`); when building locally,
  `get_report_template().agency_instructions` is applied as **appended** house style — after,
  never over, the contract/safety/whitelabel/attribution rules.

**Vocabulary rule for both hooks.** User-facing lines say "drafted by Tara" / "Tara already
reports on this brand" — never "managed agent", never "agent run", and never a plugin command for
agents (there is none). The only agent-related link a skill prints is the plain hub URL
`<TARA>/agents` (configuration) or `<TARA>/client-reports/<id>` (review). Never call `run_agent`
from any skill or task prompt: Tara's reporting has its own schedule and its own budget.

**Personal skills written by plugin ≤ 1.7.** `/adup:sync-skills` wrote `~/.claude/skills/adup-<slug>/SKILL.md`
per synced skill; those directories have no source any more and nothing else removes them.
`/adup:setup` Step 3b lists (only `~/.claude/skills/adup-*/` that contain a `SKILL.md`), confirms,
deletes, prints each path — nothing else under `~/.claude/skills/` is ever touched. Layout facts:
Claude Code discovers `~/.claude/skills/<name>/SKILL.md` exactly one level deep and the directory
name is the command, which is why the old sync wrote the flat `adup-<slug>` prefix — that is the
only pattern Step 3b matches.

## Approval rules are not readable with an employee key
No tool and no gateway route reachable with an `emp_` key returns an organisation's approval
settings, auto-approval rules, or action audit log — `/actions/{shop}/settings`, `/rules` and
`/audit-log` all answer `Unauthenticated.` for one. That is deliberate (those routes forward
the employee Bearer to central-api's dashboard surface, which is session-authed; see
`tara-gateway/src/routes/actions.js`), so **never build a skill that reads them**. The
consequence to design around: a skill cannot know whether a proposal will wait for a human or
be auto-approved, so it must not promise the user that a write will be reviewed — only that it
has been filed. Confirmed live 2026-08-24.

Related, from the same run: a write call with **no content at all** (no entity, no value —
`reasoning` alone does not count) is refused with `-32602` and files nothing. Anything that
names an entity or supplies a value still files, `reasoning` or not.

## Bundled skills (27 directories)
`ad-fatigue`, `ads-overview`, `analytics`, `anomaly-alerts`, `blended-roas`, `budget-tracker`, `client-report`, `connect`, `create-ads`, `creative-import`, `creative-intelligence`, `creative-launch`, `creative-status`, `creative-workspace`, `cross-platform`, `facebook-ads`, `google-ads`, `google-optimize`, `inspiration`, `linkedin-optimize`, `manage-status`, `monday-briefing`, `optimize-budget`, `reset`, `setup`, `shop-select`, `tiktok-optimize`.

Skills are registered by directory presence (`skills/*/SKILL.md`); the slash-command name is the DIRECTORY name (Claude Code ignores the frontmatter `name` for command routing), so every skill's `name` must equal its directory — e.g. `skills/creative-launch/` → `/adup:creative-launch`, `skills/creative-status/` → `/adup:creative-status`. A frontmatter `name` that differs from the directory produces a command that does not exist; keep them in lockstep.

## Creative workspace family (v1.2.0)
Local-folder bulk ad launching (folders + markdown = source of truth):
- `skills/creative-workspace/` — `/adup:creative-workspace` init (scaffold BRAND.md, `.adup/workspace.json` with shop_slug + defaults incl. the one-time `enhancements: off|ask|on` answer, assets/, campaigns/ example) + doctor (structural checks, report-only). Ships shared resources: `specs/platform-specs.json` (per-platform ratio/px/mb/duration/text-limit matrix, `_meta.verified_at` for re-verification) and `scripts/inspect.sh` (file → JSON metadata via sips/identify/ffprobe + sha256) / `scripts/upload.sh` (credential-free `curl -T` PUT of a local file to the presigned URL that `create_creative_upload` returns).
- `skills/creative-launch/` — `/adup:creative-launch`: validate (specs + inspect.sh) → upload (connector tools, no key: `find_creative_asset` (sha256 dedup) → `create_creative_upload` (presigned PUT, or `deduplicated`) → `upload.sh` → `finalize_creative_upload` (server recomputes the sha256); `import_creative_asset_url` for Drive/Dropbox/https links; dedup also via `.adup/state.json`) → one uuid batch_id → fan out proposals per ad × platform × language (`facebook__propose_create_ad`/`facebook__propose_bulk_launch` — never the direct `facebook__ads_*_create` tools, which bypass the approval queue; `tiktok__propose_create_campaign` / `tiktok__propose_create_adgroup` / `tiktok__propose_create_ad`, `google_ads__propose_google_create_rsa` text ads, `linkedin__propose_linkedin_create_ad`; >3 ads on one platform → one `{platform}__propose_bulk_launch` call, 50 cap) → write back state + `status: proposed`. Every proposal embeds `metadata.platform_targets` (merged from the campaign `map:` blocks, all platforms) so the portal's approve-time "also launch on X" tick can auto-create replicas. Count confirmation before proposing; ONLY image-downscale auto-fix (with confirmation); never auto-truncates copy. Creation supported: facebook, tiktok, google (RSA text only), linkedin; snapchat degrades gracefully until its executor ships.
- **Detection-first media** (v1.2.x): files can be named ANYTHING — ratio/format come from actual pixels/duration (inspect.sh locally, server metadata after upload). Grouping: explicit `creative:` list/folder → stem-similarity clustering → one confirmation table on ambiguity. Filename ratio tokens are an optional hint; on contradiction detection wins with a warning (never an error).
  - **Two ratio notations, always translate.** central-api returns `aspect_ratio` in colon form (`1:1`, `4:5`, `1.91:1`); `inspect.sh` and `specs/platform-specs.json` key on the x-form (`1x1`, `4x5`, `191x100`). Convert via `_meta.ratio_notation` in `platform-specs.json` — comparing the raw strings matches nothing and would silently pass every placement check. A server value absent from that map (e.g. `7:3`) is `other`.
- `skills/creative-status/` — `/adup:creative-status`: `list_proposals(shop_slug, limit=100, page)` → state.json + ad.md status sync, denial notes → `## Review feedback`, board output, `--csv` / `--sheet` exports. Also drains pending replication requests (`list_replication_requests(shop_slug, status="pending")`) — reviewer ticked "also launch on X" in the portal → skill prepares + launches for that platform, then `update_replication_request(id, status=fulfilled|dismissed)`.
  - Response shapes differ: the list tool returns central-api's paginator (rows at `data[]`, plus `current_page` / `last_page`), `get_proposal` returns `{proposal}`. The gateway proxies `/api/v2/employee/tara/…` with the caller's token — the old `{gateway}/actions/{shop}/…` dashboard proxy is not used.
- `skills/creative-import/` — `/adup:creative-import` winner (insights → pull copy → ask for source file → draft ad.md for NEW platforms) and sheet (CSV/xlsx copy-matrix → ad.md files, interactive column mapping, one-way).
- There are no bash-level ADUP API calls any more; the gateway is the literal `https://gateway.adup.io` and every ADUP call is a connector tool.
- HARD INVARIANT (restated in every launch-adjacent skill): nothing reaches an ad platform before portal approval; approved ads always land PAUSED.

## Removed/cleaned (Phase 0)
- All chat-stream references in skills.
- `agents/adup-analyst.md` chat-specific sections (documented for Phase 1 rewrite).

## Stack
Claude Code plugin format. `.mcp.json` for connectors. Markdown SKILL.md per skill.
