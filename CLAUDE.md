# adup-claude-plugin

**Role:** Claude Code plugin (`adup`, repo `adup-claude-plugin`) exposing the ADUP MCP connector and dynamically-registered skills.

## Phase 0 state
Single `adup` connector in `.mcp.json`. 28 bundled skill directories. 1 agent (`adup-analyst.md`). Chat-stream references in skills cleaned.

## .mcp.json — single aggregated connector
ONE connector: `adup → https://gateway.adup.io/mcp`
(auth `Authorization: Bearer ${user_config.ADUP_API_KEY}`).

### The key comes from plugin config, not the environment
`plugin.json` declares `userConfig.ADUP_API_KEY` (string, required, sensitive). Claude Code prompts
for it at enable time, masks it, stores it in the keychain, and substitutes it into the connector
header. `pack.sh --verify` asserts both halves — the literal URL and the `${user_config.…}` header —
plus the presence of the declaration, because either half alone ships a connector that cannot
authenticate.

**Why not an env var.** `${ADUP_API_KEY}` and `${ADUP_GATEWAY_BASE:-…}` expand in the Claude Code
CLI only. On claude.ai and the desktop app the literal string was used as the URL and the
credential: the connector dialog rejected the URL outright ("URL must start with 'https'") and the
header authenticated with the placeholder text. Measured 2026-08-24.

### Environments
The connector URL is literal, so the plugin always talks to the production gateway.
`ADUP_API_BASE` still moves the direct HTTP calls the skills make (reports, proposals, creative
assets, `/me/skills`) and defaults to `https://centralapi.adup.io`; staging is
`https://centralapi-staging.adup.io`, dev is `https://centralapi-dev.kodeia.com`. Moving it alone
splits the plugin across two environments — MCP tools from production, report/proposal endpoints
from elsewhere — so treat it as a testing tool only.

`ADUP_GATEWAY_BASE` is **dead**. `/adup:reset` clears leftovers; nothing writes it.

⚠️ **A key belongs to exactly ONE environment.** A staging key against production returns
`invalid_token` while being perfectly valid — check the environment before blaming the key.
`gateway.kodeia.com` is **dev**, not staging (the kodeia.com domain is used by both).
The gateway's base `/mcp` connector AGGREGATES every connected platform's tools for
the active shop, namespaced `platform__tool` (e.g. `facebook__get_campaigns`,
`google_ads__execute_google_ads_gaql_query`), plus the six unprefixed virtual tools (see
**Tool naming** below). Per-platform `/mcp/{platform}` connectors still exist
server-side (backward-compat) but the plugin no longer lists them — one connector
serves everything, so a single `ADUP_API_KEY` covers all platforms.

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

**Testing against staging** no longer works by env var alone: since v1.7.0 the connector URL is a
literal, so `ADUP_API_BASE` moves only the direct central-api calls while MCP tools keep answering
from production. A real staging test needs a variant build of the plugin (literal staging URL) or a
custom connector added by hand. A staging **employee key** is still required either way.

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
SIX **virtual** tools are served by the gateway itself and are **unprefixed**:
`list_shops`, `set_active_shop`, `create_report`, `get_kpi`, `get_report_template`,
`get_report_branding`.

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

**Concurrency.** `set_active_shop` sets ONE ambient shop **per `ADUP_API_KEY`**.
That is fine for a single interactive session, but concurrent runs sharing the key
(e.g. N scheduled automations at night) race: one run's `set_active_shop` clobbers
another's, and a call that relied on the ambient shop reads the wrong client. So:

- **Interactive, one client:** `set_active_shop`, then still pass `shop_slug` on
  data calls — it costs nothing and removes the ambient dependency.
- **Multiple clients in one session, loops, parallel or scheduled runs:** always
  pass `shop_slug="<slug>"` per call, e.g.
  `google_ads__get_google_ads_campaign_performance(shop_slug="nike", ...)`.
  Never rely on the ambient shop inside a loop or automation.

There is no request-header mechanism for pinning the shop — the gateway does not
read one. `shop_slug` per call is the only race-free option.

## Skill registration (Phase 4)
On `initialize`, the plugin fetches `GET /api/v1/me/skills`. The response returns SKILL.md content for installed public skills + org-private skills. The plugin registers these dynamically alongside the bundled fallback skills.

## Dynamic skill registration (Phase 4)

Claude Code plugins are static SKILL.md directories. The plugin cannot register new skills at runtime. To support "the agency installs a skill in the portal and it appears in every employee's Claude," we use a sync-skills approach:

1. `skills/sync-skills/SKILL.md` is a bootstrap skill that runs in Claude.
2. It fetches `GET /api/v1/me/skills` from `${ADUP_API_BASE:-https://centralapi.adup.io}` with the employee's API key. **Use the env override — a hardcoded prod host 401s for every dev/staging employee.**
3. It writes each returned `content` (full SKILL.md text including frontmatter) to `~/.claude/skills/adup-{slug}/SKILL.md`.
4. The employee restarts Claude Code. The synced skills are available as `/adup-{slug}`.

**The layout is load-bearing — do not "tidy" it into a subdirectory.** Claude Code discovers a
personal skill at `~/.claude/skills/<skill-name>/SKILL.md` (exactly one level) and **the directory
name is the command**. There is no `group:name` syntax for personal skills — that namespacing is
plugin-only. An earlier version wrote `~/.claude/skills/adup-org/{slug}/SKILL.md` and told users to
run `/adup-org:{slug}`: two levels deep is never discovered, and that invocation form does not
exist for personal skills, so nothing an agency published ever reached anyone. The flat
`adup-<slug>` prefix keeps the namespace without nesting.

**Surface limits (state these to the user, don't let them be discovered as a missing command):**
synced skills work in Claude Code and in local desktop scheduled tasks. **Cowork sessions and
cloud sessions/routines do not read `~/.claude/skills/` at all** — they load the skills enabled for
the user's claude.ai account. So this mechanism cannot deliver an agency skill to Cowork.

This is a Phase 4 stop-gap. If Claude Code adds runtime skill registration in the future, sync-skills becomes a no-op or a fallback.

The `/api/v1/me/skills` endpoint returns:
- Public ADUP skills the org has installed.
- Org-private skills the org owners have authored.
- Each item: `{ id, name, slug, description, category, platform, content, version, is_public, custom_config }`.

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
`ad-fatigue`, `ads-overview`, `analytics`, `anomaly-alerts`, `blended-roas`, `budget-tracker`, `client-report`, `connect`, `create-ads`, `creative-import`, `creative-intelligence`, `creative-launch`, `creative-status`, `creative-workspace`, `cross-platform`, `facebook-ads`, `google-ads`, `google-optimize`, `inspiration`, `linkedin-optimize`, `manage-status`, `monday-briefing`, `optimize-budget`, `setup`, `shop-select`, `sync-skills`, `tiktok-optimize`.

Skills are registered by directory presence (`skills/*/SKILL.md`); the slash-command name comes from the SKILL.md frontmatter `name`, which for `creative-launch`/`creative-status` deliberately differs from the directory (`/adup:launch`, `/adup:status`).

## Creative workspace family (v1.2.0)
Local-folder bulk ad launching (folders + markdown = source of truth):
- `skills/creative-workspace/` — `/adup:creative-workspace` init (scaffold BRAND.md, `.adup/workspace.json` with shop_slug + defaults incl. the one-time `enhancements: off|ask|on` answer, assets/, campaigns/ example) + doctor (structural checks, report-only). Ships shared resources: `specs/platform-specs.json` (per-platform ratio/px/mb/duration/text-limit matrix, `_meta.verified_at` for re-verification) and `scripts/inspect.sh` (file → JSON metadata via sips/identify/ffprobe + sha256) / `scripts/upload.sh` (checksum-dedup multipart upload to central-api creative-assets).
- `skills/creative-launch/` — `/adup:launch`: validate (specs + inspect.sh) → upload (central-api `POST /api/v1/shops/{slug}/creative-assets`, `from-url` for Drive links, sha256 dedup via `.adup/state.json` + `?checksum=`) → one uuid batch_id → fan out proposals per ad × platform × language (`facebook__propose_create_ad`/`facebook__propose_bulk_launch` — never the direct `facebook__ads_*_create` tools, which bypass the approval queue; `tiktok__propose_create_campaign` / `tiktok__propose_create_adgroup` / `tiktok__propose_create_ad`, `google_ads__propose_google_create_rsa` text ads, `linkedin__propose_linkedin_create_ad`; >3 ads on one platform → one `{platform}__propose_bulk_launch` call, 50 cap) → write back state + `status: proposed`. Every proposal embeds `metadata.platform_targets` (merged from the campaign `map:` blocks, all platforms) so the portal's approve-time "also launch on X" tick can auto-create replicas. Count confirmation before proposing; ONLY image-downscale auto-fix (with confirmation); never auto-truncates copy. Creation supported: facebook, tiktok, google (RSA text only), linkedin; snapchat degrades gracefully until its executor ships.
- **Detection-first media** (v1.2.x): files can be named ANYTHING — ratio/format come from actual pixels/duration (inspect.sh locally, server metadata after upload). Grouping: explicit `creative:` list/folder → stem-similarity clustering → one confirmation table on ambiguity. Filename ratio tokens are an optional hint; on contradiction detection wins with a warning (never an error).
  - **Two ratio notations, always translate.** central-api returns `aspect_ratio` in colon form (`1:1`, `4:5`, `1.91:1`); `inspect.sh` and `specs/platform-specs.json` key on the x-form (`1x1`, `4x5`, `191x100`). Convert via `_meta.ratio_notation` in `platform-specs.json` — comparing the raw strings matches nothing and would silently pass every placement check. A server value absent from that map (e.g. `7:3`) is `other`.
- `skills/creative-status/` — `/adup:status`: central-api `GET /api/v2/employee/tara/proposals?shop_slug=` → state.json + ad.md status sync, denial notes → `## Review feedback`, board output, `--csv` / `--sheet` exports. Also drains pending replication requests (`GET /api/v2/employee/tara/actions/replication-requests`) — reviewer ticked "also launch on X" in the portal → skill prepares + launches for that platform, then PATCHes the request fulfilled/dismissed.
  - **Employee keys authenticate against `/api/v2/employee/tara/…` only.** The gateway also proxies these as `{gateway}/actions/{shop}/proposals…`, but that proxy targeted central-api's seller-JWT *dashboard* routes until tara-gateway PR #90 — so on an older gateway it answers `401 Unauthenticated.` Calling central-api directly works on any gateway version, which is why the skill does. Response shapes differ: the list is a Laravel paginator (`data.data[]`), the single GET returns `data.proposal`.
- `skills/creative-import/` — `/adup:creative-import` winner (insights → pull copy → ask for source file → draft ad.md for NEW platforms) and sheet (CSV/xlsx copy-matrix → ad.md files, interactive column mapping, one-way).
- API bases: central-api `${ADUP_API_BASE:-https://centralapi.adup.io}` (bash-level calls); the gateway is the literal `https://gateway.adup.io`.
- HARD INVARIANT (restated in every launch-adjacent skill): nothing reaches an ad platform before portal approval; approved ads always land PAUSED.

## Removed/cleaned (Phase 0)
- All chat-stream references in skills.
- `agents/adup-analyst.md` chat-specific sections (documented for Phase 1 rewrite).

## Stack
Claude Code plugin format. `.mcp.json` for connectors. Markdown SKILL.md per skill.
