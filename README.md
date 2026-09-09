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

### 2. Sign in

There is no key to paste. The first time Claude uses the `adup` connector it opens your browser at
Tara: sign in with your normal Tara login and click **Approve**. To trigger it deliberately:

```bash
claude mcp login plugin:adup:adup      # from any terminal
```

or, inside a Claude Code session, `/mcp` → **adup** → **Authenticate**. In the Claude desktop app's
Code tab, run the terminal command once — the sign-in is shared.

Optional: run `/adup:setup` afterwards to deploy the scheduled reporting tasks (it also removes
credentials left behind by plugin versions before 2.0).

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
| Auth | OAuth 2.0 — sign in from Claude; tokens are kept by Claude Code in the OS keychain and refreshed automatically |

That single connector aggregates every platform your shop has connected — there are no
per-platform connectors to add.

### Your sign-in

Signing in issues a short-lived access token and a refresh token to Claude Code. Claude refreshes
them itself; you sign in again only after 30 days without using the plugin, or after signing the
device out. Every device you sign in from is listed in Tara under **My MCP setup → Connected
devices**, where you can sign it out at any time. `/adup:reset` signs this machine out or switches
to another account.

Before 2.0 the plugin asked for an employee API key at enable time and older versions wrote it to
environment files. Nothing reads those any more; `/adup:setup` and `/adup:reset` remove them.

#### Automation machines

A machine that cannot open a browser (a server, a CI runner) either signs in once with
`claude mcp login plugin:adup:adup --no-browser`, or uses the employee API key from Tara → **My MCP
setup** through a second, hand-added connector:

```bash
./install.sh --automation emp_…
# = claude mcp add --transport http --scope user adup-automation https://gateway.adup.io/mcp --header "Authorization: Bearer emp_…"
```

The skills reference tools by name, so they work over either connector. Treat that key like a
password and rotate it from Tara if it may have leaked.

#### Non-production environments

The connector URL is a literal, so the plugin always signs in against production. Testing another
environment is a hand-added connector against that gateway (`claude mcp add --transport http
adup-staging https://gateway-staging.adup.io/mcp`), which runs its own sign-in against that
environment's portal.

### Choosing which client you're working on

Three steps, in this order:

1. **`list_shops`** — lists the brands you can access and the platforms connected to each.
2. **`set_active_shop(shop_slug="<slug>")`** — required before the platform tools
   appear at all. Until a shop is active (or your account has exactly one shop), the
   connector only exposes its handful of built-in tools — no `facebook__*`,
   no `google_ads__*`. If tools seem to be "missing", this is almost always why.
   The tool list changes when the active shop changes, so reload/reconnect the
   connector after switching.
3. **Pass `shop_slug="<slug>"` on every data call.** The active shop is stored once
   per sign-in (one slot per signed-in device), so anything running in parallel
   (scheduled tasks, loops over several clients) can otherwise read the wrong
   client's data. An explicit `shop_slug` always wins over the active shop.

Tool names are namespaced `platform__tool` — e.g. `facebook__get_ad_insights`,
`google_ads__execute_google_ads_gaql_query`, `ga4__get_ecommerce_performance`. Note the
Google Ads prefix is `google_ads__`, not `google__`.

## Available skills

### Setup & Connection
| Skill | Command | Description |
|-------|---------|-------------|
| Setup | `/adup:setup` | Check the sign-in, remove pre-2.0 leftovers, deploy scheduled tasks |
| Connect | `/adup:connect` | Verify connection and see available shops |
| Reset | `/adup:reset` | Sign this machine out, or switch to another Tara account |
| Shop Select | `/adup:shop-select` | Switch active client (agencies) |

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
| Launch | `/adup:creative-launch` | Validate, upload (credential-free presigned uploads), and propose ads in bulk per ad × platform × language |
| Status | `/adup:creative-status` | Sync approval statuses back into the workspace; `--csv` / `--sheet` exports |
| Creative Import | `/adup:creative-import` | Import a winning ad for cross-platform relaunch, or a spreadsheet copy matrix |

### Reporting
| Skill | Command | Description |
|-------|---------|-------------|
| Monday Briefing | `/adup:monday-briefing` | Per-client executive summary with wins & concerns |
| Client Report | `/adup:client-report` | Client-ready report with talking points — offers Tara's existing draft first when one covers the period |
| Anomaly Alerts | `/adup:anomaly-alerts` | Detect spend spikes, delivery stops, CTR drops |

## Tara's agents

Agents are configured, run and reviewed in Tara under **Agents** — the plugin has no agent
commands. The two only meet at the review queue: when Tara already drafts a brand's report,
`/adup:setup` does not create the local weekly/monthly reporting tasks for that brand, and
`/adup:client-report` offers Tara's draft before building one.

## Upgrading

### From 1.x to 2.0

After the update the connector no longer carries your key, so Claude asks you to sign in the next
time it uses ADUP — approve once in the browser and you are done. Your old employee key stays valid
(automations that use it keep working), but nothing in the plugin reads it any more: run
`/adup:setup` once to remove the cleartext copies earlier versions wrote to your machine.

### From 1.7

`/adup:sync-skills` is gone (the portal skill library it synced no longer exists). `/adup:setup`
lists the personal `adup-*` skills the old command wrote under `~/.claude/skills/`, asks, and
removes them.

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

- Claude Code 2.1.231+ (MCP OAuth for plugin connectors, loopback callback on `localhost`)
- Active ADUP account — [tara.adup.io](https://tara.adup.io)
- At least one connected ad platform

## License

MIT
