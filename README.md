# ADUP — Claude Code Plugin

Query your marketing stack with natural language directly from Claude Code.

**→ [USAGE.md](USAGE.md) — how to use the plugin and the connector correctly** (shop selection,
tool naming, argument shapes, approvals, errors). Read it before your first real query; it is
also written to be pasted into project instructions when you use the connector without the
plugin.

## Connected platforms

Facebook Ads · Google Ads · Google Analytics 4 · Google Search Console · LinkedIn Ads · HubSpot · Intercom

## Quick start

### 1. Install the plugin

```bash
claude plugin install adup --plugin-dir /path/to/adup-claude-plugin
```

### 2. Enter your employee API key

Enabling the plugin prompts for your **Employee API key**. Paste the personal `emp_…` key from
[Tara → My MCP setup](https://tara.adup.io/my-mcp-setup). That is all the connector needs.

Optional: run `/adup:setup` afterwards to deploy the scheduled reporting tasks and to store the key
for the skills that call the ADUP API directly (client reports, proposals, creative uploads).

```
/adup:setup
```

### 3. Verify connection

```
/adup:connect
```

## Connector

The plugin ships **one** MCP connector, `adup`:

| | |
|---|---|
| Name | `adup` |
| URL | `https://gateway.adup.io/mcp` |
| Auth | `Authorization: Bearer ${user_config.ADUP_API_KEY}` |

That single connector aggregates every platform your shop has connected — there are no
per-platform connectors to add.

### Your key

When you enable the plugin it asks for your **Employee API key** — the personal `emp_…` key from
Tara → **My MCP setup**. The value is masked and stored in your OS keychain, and the connector
reads it from there. To change it later, run `/adup:reset`.

Before v1.7.0 the key came from an `ADUP_API_KEY` environment variable. That only ever worked in
the Claude Code CLI: every other surface sent the literal string `${ADUP_API_KEY}` as the
credential and the connector 401'd with no way to fix it from the UI.

#### Non-production environments

The connector URL is a literal, so the connector always points at production. A key belongs to
exactly one environment, so a staging or dev key returns `invalid_token` here even though it is
valid where it came from. Reaching another gateway needs a variant build of the plugin or a custom
connector added by hand.

`ADUP_API_BASE` still redirects the **direct** central-api calls the skills make (reports,
proposals, creative assets, `/me/skills`) and defaults to production:

```bash
export ADUP_API_BASE=https://centralapi-staging.adup.io   # staging
export ADUP_API_BASE=https://centralapi-dev.kodeia.com    # dev
```

Note this only moves half the plugin: MCP tools still answer from production. That split is a
testing tool, not a supported configuration.


A key belongs to exactly one environment: a staging key used against production returns
`invalid_token` even though it is valid. `/adup:connect` tells you which failure you are looking at,
and `/adup:reset` walks through replacing the key.

### Choosing which client you're working on

Three steps, in this order:

1. **`list_shops`** — lists the brands you can access and the platforms connected to each.
2. **`set_active_shop(shop_slug="<slug>")`** — required before the platform tools
   appear at all. Until a shop is active (or your key has exactly one shop), the
   connector only exposes its handful of built-in tools — no `facebook__*`,
   no `google_ads__*`. If tools seem to be "missing", this is almost always why.
   The tool list changes when the active shop changes, so reload/reconnect the
   connector after switching.
3. **Pass `shop_slug="<slug>"` on every data call.** The active shop is stored once
   per API key, so anything running in parallel (scheduled tasks, loops over
   several clients) can otherwise read the wrong client's data. An explicit
   `shop_slug` always wins over the active shop.

Tool names are namespaced `platform__tool` — e.g. `facebook__get_ad_insights`,
`google_ads__execute_google_ads_gaql_query`, `ga4__get_ecommerce_performance`. Note the
Google Ads prefix is `google_ads__`, not `google__`.

## Available skills

### Setup & Connection
| Skill | Command | Description |
|-------|---------|-------------|
| Setup | `/adup:setup` | Deploy scheduled tasks; store the key for direct API calls |
| Connect | `/adup:connect` | Verify connection and see available shops |
| Reset | `/adup:reset` | Change the employee API key, or clear a stale one |
| Shop Select | `/adup:shop-select` | Switch active client (agencies) |
| Sync Skills | `/adup:sync-skills` | Pull the skills your agency installed in the ADUP portal into your local Claude |

### Analysis
| Skill | Command | Description |
|-------|---------|-------------|
| Ads Overview | `/adup:ads-overview` | Quick cross-platform ad summary |
| Facebook Ads | `/adup:facebook-ads` | Facebook & Instagram analysis |
| Google Ads | `/adup:google-ads` | Search, Shopping, PMax analysis |
| Analytics | `/adup:analytics` | GA4 web analytics & e-commerce |
| Cross-Platform | `/adup:cross-platform` | Unified marketing dashboard |
| Blended ROAS | `/adup:blended-roas` | ROAS per market — Shopify revenue by country vs ad spend by country, with an explicit unattributed-spend bucket |
| Budget Tracker | `/adup:budget-tracker` | Monitor budget pacing, flag over/underspend |
| Ad Fatigue | `/adup:ad-fatigue` | Detect creative fatigue and propose responses |
| Creative Intelligence | `/adup:creative-intelligence` | Score creative performance, build playbooks |
| Inspiration | `/adup:inspiration` | "Next steps for this client" briefing — prioritised recommendations tied to KPI gaps |

### Actions (via middleware — all proposals require approval)
| Skill | Command | Description |
|-------|---------|-------------|
| Optimize Budget | `/adup:optimize-budget` | Propose budget increases/decreases with data |
| Manage Status | `/adup:manage-status` | Propose pausing/activating campaigns, ad sets, ads |
| Create Ads | `/adup:create-ads` | Propose new ad creation within existing ad sets |
| Google Optimize | `/adup:google-optimize` | Propose Google Ads budget, status & RSA changes |
| LinkedIn Optimize | `/adup:linkedin-optimize` | Propose LinkedIn budget, status & creative changes |
| TikTok Optimize | `/adup:tiktok-optimize` | Propose TikTok budget & status changes |

### Creative Workspace (bulk launching — all proposals require approval, ads land PAUSED)
| Skill | Command | Description |
|-------|---------|-------------|
| Creative Workspace | `/adup:creative-workspace` | Init a local creative workspace (folders + markdown) or run doctor checks |
| Launch | `/adup:launch` | Validate, upload, and propose ads in bulk per ad × platform × language |
| Status | `/adup:status` | Sync approval statuses back into the workspace; `--csv` / `--sheet` exports |
| Creative Import | `/adup:creative-import` | Import a winning ad for cross-platform relaunch, or a spreadsheet copy matrix |

### Reporting
| Skill | Command | Description |
|-------|---------|-------------|
| Monday Briefing | `/adup:monday-briefing` | Per-client executive summary with wins & concerns |
| Client Report | `/adup:client-report` | Client-ready report with talking points |
| Anomaly Alerts | `/adup:anomaly-alerts` | Detect spend spikes, delivery stops, CTR drops |

## Usage examples

### Solo advertiser
```
How are my Facebook campaigns doing this month?
What's my Google Ads ROAS for Q1?
Show me revenue by channel from GA4.
```

### Agency
```
How are the Nike campaigns performing?
Show me an overview for all my clients.
Compare Facebook vs Google for Adidas EU.
```

### Using the analyst agent
```
@adup-analyst What's wrong with the Facebook account? ROAS has been dropping.
@adup-analyst Build me a monthly report for Nike NL.
```

## Requirements

- Claude Code 1.0.0+
- Active ADUP account — [tara.adup.io](https://tara.adup.io)
- At least one connected ad platform

## License

MIT
