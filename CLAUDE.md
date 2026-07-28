# tara26-plugin

**Role:** Claude Code plugin exposing ADUP MCP connectors and dynamically-registered skills.

## Phase 0 state
Unmodified copy of `adup-claude-plugin`. Single `adup` connector in `.mcp.json`. 21 bundled skills. 1 agent (`adup-analyst.md`). Chat-stream references in skills cleaned.

## .mcp.json — single aggregated connector
ONE connector: `adup → https://gateway.adup.io/mcp` (auth `Authorization: Bearer ${ADUP_API_KEY}`).
The gateway's base `/mcp` connector AGGREGATES every connected platform's tools for
the active shop, namespaced `platform__tool` (e.g. `facebook__get_campaigns`,
`google_ads__search_google_ads_data`), plus the virtual `list_shops` /
`set_active_shop`. Per-platform `/mcp/{platform}` connectors still exist
server-side (backward-compat) but the plugin no longer lists them — one connector
serves everything, so a single `ADUP_API_KEY` covers all platforms.

> History: an earlier "Phase 1" briefly split this into 9 connectors (base + one
> per platform). Reverted in favour of base-connector aggregation (tara-gateway
> PR #57) because single-URL clients (Claude.ai / Cowork web connector) can only
> add ONE connector URL.

## Shop-change tool renewal
After `set_active_shop`, the gateway emits `notifications/tools/list_changed`, but
most MCP clients (Claude Code / Cowork) don't act on it — reload tools / reconnect
to pick up the newly-active shop's tools.

## Selecting the client — per-call shop, concurrency-safe
`set_active_shop` sets ONE ambient shop **per `ADUP_API_KEY`** in the gateway. That
is fine for a single interactive session but races when multiple runs share the key
(e.g. N scheduled automations at night): one run's `set_active_shop` clobbers
another's active shop, so a data call can read the wrong client. The gateway resolves
the target shop **per call** with precedence: (1) `shop_slug` tool argument →
(2) `X-Shop-Slug` request header → (3) ambient active shop. Every aggregated platform
tool advertises an optional `shop_slug`; the gateway strips it before proxying
upstream, so this needs no MCP-server change.

- **Interactive:** `set_active_shop` once, then call normally (ambient fallback).
- **Multiple clients in one session / parallel:** pass `shop_slug="<slug>"` on each
  data call (e.g. `google_ads__get_campaigns(shop_slug="nike", ...)`).
- **Scheduled automations — one run per client (recommended, deterministic):** pin
  the client on the connector via a header. Each run sets `ADUP_SHOP_SLUG` to its
  client slug and uses:
  ```json
  { "mcpServers": { "adup": { "type": "http", "url": "https://gateway.adup.io/mcp",
    "headers": { "Authorization": "Bearer ${ADUP_API_KEY}", "X-Shop-Slug": "${ADUP_SHOP_SLUG}" } } } }
  ```
  No `set_active_shop`, no shared state, no race — and it is multi-instance safe.
  The bundled `.mcp.json` keeps the plain single-connector form for interactive use;
  the header line above is the automation variant.

## Skill registration (Phase 4)
On `initialize`, the plugin fetches `GET /api/v1/me/skills`. The response returns SKILL.md content for installed public skills + org-private skills. The plugin registers these dynamically alongside the bundled fallback skills.

## Dynamic skill registration (Phase 4)

Claude Code plugins are static SKILL.md directories. The plugin cannot register new skills at runtime. To support "the agency installs a skill in the portal and it appears in every employee's Claude," we use a sync-skills approach:

1. `skills/sync-skills/SKILL.md` is a bootstrap skill that runs in Claude.
2. It fetches `GET /api/v1/me/skills` from the Central API with the employee's API key.
3. It writes each returned `content` (full SKILL.md text including frontmatter) to `~/.claude/skills/adup-org/{slug}/SKILL.md`.
4. The employee restarts Claude. The synced skills are now available as `/adup-org:{slug}` commands.

This is a Phase 4 stop-gap. If Claude Code adds runtime skill registration in the future, sync-skills becomes a no-op or a fallback.

The `/api/v1/me/skills` endpoint returns:
- Public ADUP skills the org has installed.
- Org-private skills the org owners have authored.
- Each item: `{ id, name, slug, description, category, platform, content, version, is_public, custom_config }`.

## Bundled skills (25)
`setup`, `connect`, `shop-select`, `ads-overview`, `facebook-ads`, `google-ads`, `analytics`, `cross-platform`, `budget-tracker`, `ad-fatigue`, `creative-intelligence`, `optimize-budget`, `manage-status`, `create-ads`, `google-optimize`, `linkedin-optimize`, `tiktok-optimize`, `monday-briefing`, `client-report`, `anomaly-alerts`, `connect` (duplicate), plus the creative workspace family: `creative-workspace` (init/doctor), `launch` (dir `creative-launch`), `status` (dir `creative-status`), `creative-import` (winner + sheet).

Skills are registered by directory presence (`skills/*/SKILL.md`); the slash-command name comes from the SKILL.md frontmatter `name`, which for `creative-launch`/`creative-status` deliberately differs from the directory (`/adup:launch`, `/adup:status`).

## Creative workspace family (v1.2.0)
Local-folder bulk ad launching (folders + markdown = source of truth):
- `skills/creative-workspace/` — `/adup:creative-workspace` init (scaffold BRAND.md, `.adup/workspace.json` with shop_slug + defaults incl. the one-time `enhancements: off|ask|on` answer, assets/, campaigns/ example) + doctor (structural checks, report-only). Ships shared resources: `specs/platform-specs.json` (per-platform ratio/px/mb/duration/text-limit matrix, `_meta.verified_at` for re-verification) and `scripts/inspect.sh` (file → JSON metadata via sips/identify/ffprobe + sha256) / `scripts/upload.sh` (checksum-dedup multipart upload to central-api creative-assets).
- `skills/creative-launch/` — `/adup:launch`: validate (specs + inspect.sh) → upload (central-api `POST /api/v1/shops/{slug}/creative-assets`, `from-url` for Drive links, sha256 dedup via `.adup/state.json` + `?checksum=`) → one uuid batch_id → fan out proposals per ad × platform × language (`facebook__ads_ad_create`/`facebook__ads_creative_create`, `tiktok__propose_create_*`, `google__propose_google_create_rsa` text ads, `linkedin__propose_linkedin_create_ad`; >3 ads on one platform → one `{platform}__propose_bulk_launch` call, 50 cap) → write back state + `status: proposed`. Every proposal embeds `metadata.platform_targets` (merged from the campaign `map:` blocks, all platforms) so the portal's approve-time "also launch on X" tick can auto-create replicas. Count confirmation before proposing; ONLY image-downscale auto-fix (with confirmation); never auto-truncates copy. Creation supported: facebook, tiktok, google (RSA text only), linkedin; snapchat degrades gracefully until its executor ships.
- **Detection-first media** (v1.2.x): files can be named ANYTHING — ratio/format come from actual pixels/duration (inspect.sh locally, server metadata after upload). Grouping: explicit `creative:` list/folder → stem-similarity clustering → one confirmation table on ambiguity. Filename ratio tokens are an optional hint; on contradiction detection wins with a warning (never an error).
- `skills/creative-status/` — `/adup:status`: gateway `GET /actions/{shop}/proposals` → state.json + ad.md status sync, denial notes → `## Review feedback`, board output, `--csv` / `--sheet` exports. Also drains pending replication requests (`GET /api/v2/employee/tara/actions/replication-requests`) — reviewer ticked "also launch on X" in the portal → skill prepares + launches for that platform, then PATCHes the request fulfilled/dismissed.
- `skills/creative-import/` — `/adup:creative-import` winner (insights → pull copy → ask for source file → draft ad.md for NEW platforms) and sheet (CSV/xlsx copy-matrix → ad.md files, interactive column mapping, one-way).
- API bases: central-api `${ADUP_API_BASE:-https://centralapi.adup.io}`, gateway `${ADUP_GATEWAY_BASE:-https://gateway.adup.io}`.
- HARD INVARIANT (restated in every launch-adjacent skill): nothing reaches an ad platform before portal approval; approved ads always land PAUSED.

## Removed/cleaned (Phase 0)
- All chat-stream references in skills.
- `agents/adup-analyst.md` chat-specific sections (documented for Phase 1 rewrite).

## Stack
Claude Code plugin format. `.mcp.json` for connectors. Markdown SKILL.md per skill.
