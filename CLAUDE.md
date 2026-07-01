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

## Bundled skills (21)
`setup`, `connect`, `shop-select`, `ads-overview`, `facebook-ads`, `google-ads`, `analytics`, `cross-platform`, `budget-tracker`, `ad-fatigue`, `creative-intelligence`, `optimize-budget`, `manage-status`, `create-ads`, `google-optimize`, `linkedin-optimize`, `tiktok-optimize`, `monday-briefing`, `client-report`, `anomaly-alerts`, `connect` (duplicate).

## Removed/cleaned (Phase 0)
- All chat-stream references in skills.
- `agents/adup-analyst.md` chat-specific sections (documented for Phase 1 rewrite).

## Stack
Claude Code plugin format. `.mcp.json` for connectors. Markdown SKILL.md per skill.
