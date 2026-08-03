# ADUP — Claude Code Plugin

Query your marketing stack with natural language directly from Claude Code.

## Connected platforms

Facebook Ads · Google Ads · Google Analytics 4 · Google Search Console · LinkedIn Ads · HubSpot · Intercom

## Quick start

### 1. Install the plugin

```bash
claude plugin install adup --plugin-dir /path/to/adup-claude-plugin
```

### 2. Set up your API key

Once installed, run the setup skill — it will walk you through entering your API key and save it automatically:

```
/adup:setup
```

Get your API key from [tara.adup.io/settings/api](https://tara.adup.io/settings/api).

### 3. Verify connection

```
/adup:connect
```

## Connector

The plugin ships **one** MCP connector, `adup`:

| | |
|---|---|
| Name | `adup` |
| URL | `${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/mcp` |
| Auth | `Authorization: Bearer ${ADUP_API_KEY}` |

That single connector aggregates every platform your shop has connected — there are
no per-platform connectors to add. `/adup:setup` writes `ADUP_API_KEY` for you; if
you set it by hand, `export ADUP_API_KEY=your_key_here` and restart Claude Code.

#### Non-production environments

Production needs no configuration — the defaults point at it. To use a staging or dev
key, set **both** hosts (the gateway serves the MCP tools, central-api serves reports
and proposals — a mismatched pair leaves half the plugin 401ing):

```bash
# production (the default — the built-in values, set explicitly)
export ADUP_GATEWAY_BASE=https://gateway.adup.io
export ADUP_API_BASE=https://centralapi.adup.io

# staging
export ADUP_GATEWAY_BASE=https://gateway-staging.adup.io
export ADUP_API_BASE=https://centralapi-staging.adup.io

# dev
export ADUP_GATEWAY_BASE=https://gateway.kodeia.com
export ADUP_API_BASE=https://centralapi-dev.kodeia.com
```

Always set **both** — the gateway serves the MCP tools, central-api serves the report,
proposal and creative-asset endpoints the skills call directly. One without the other splits
the plugin across two environments.

A key belongs to exactly one environment: a staging key used against production returns
`invalid_token` even though it is valid. `/adup:connect` reports which environment you
are currently pointed at.

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
| Setup | `/adup:setup` | Configure your API key (run once after install) |
| Connect | `/adup:connect` | Verify connection and see available shops |
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
