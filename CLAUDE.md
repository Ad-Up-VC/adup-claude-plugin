# tara26-plugin

**Role:** Claude Code plugin exposing ADUP MCP connectors and dynamically-registered skills.

## Phase 0 state
Unmodified copy of `adup-claude-plugin`. Single `adup` connector in `.mcp.json`. 21 bundled skills. 1 agent (`adup-analyst.md`). Chat-stream references in skills cleaned.

## .mcp.json (current → Phase 1)
Currently: single connector `adup → https://gateway.adup.io/mcp`.
Phase 1: rewrite to 9 connectors:
- `adup` (base — 2 virtual tools: `list_shops`, `set_active_shop`)
- `adup-facebook` → `/mcp/facebook`
- `adup-google-ads` → `/mcp/google_ads`
- `adup-ga4` → `/mcp/ga4`
- `adup-gsc` → `/mcp/gsc`
- `adup-linkedin` → `/mcp/linkedin`
- `adup-hubspot` → `/mcp/hubspot`
- `adup-intercom` → `/mcp/intercom`
- `adup-tiktok` → `/mcp/tiktok`
All pass `Authorization: Bearer ${ADUP_API_KEY}`.

## Shop-change tool renewal
Gateway-side via `shopChangedTokens` Set + piggybacked `notifications/tools/list_changed` on each platform connector's next request. NO client-side refresh logic needed in the plugin.

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
