# ADUP — Claude Code Plugin

Query your entire marketing stack with natural language directly from Claude Code. Powered by [ADUP](https://adup.io).

## Connected platforms

Facebook Ads · Google Ads · Google Analytics 4 · Google Search Console · LinkedIn Ads · TikTok Ads · HubSpot · Intercom

## Installation

### Option 1: Install from GitHub (recommended)

```bash
claude plugin install Ad-Up-VC/adup-claude-plugin
```

### Option 2: Clone and install locally

```bash
git clone https://github.com/Ad-Up-VC/adup-claude-plugin.git
claude plugin install adup --plugin-dir ./adup-claude-plugin
```

### Option 3: Add the MCP server directly

```bash
claude mcp add adup --transport http https://tara-gateway-vc-v2wpc.ondigitalocean.app/mcp \
  --header "Authorization: Bearer $ADUP_API_KEY"
```

### Set your API key

```bash
export ADUP_API_KEY=your_adup_api_key_here
```

Get your API key from your [ADUP dashboard](https://app.adup.io) or during onboarding.

### Verify connection

```
/adup:connect
```

## Available skills

| Skill | Command | Description |
|-------|---------|-------------|
| Connect | `/adup:connect` | Verify connection and see available shops |
| Shop Select | `/adup:shop-select` | Switch active client (agencies) |
| Ads Overview | `/adup:ads-overview` | Quick cross-platform ad summary |
| Facebook Ads | `/adup:facebook-ads` | Facebook & Instagram analysis |
| Google Ads | `/adup:google-ads` | Search, Shopping, PMax analysis |
| Analytics | `/adup:analytics` | GA4 web analytics & e-commerce |
| Cross-Platform | `/adup:cross-platform` | Unified marketing dashboard |
| Ad Fatigue | `/adup:ad-fatigue` | Daily fatigue check across Meta, TikTok, Google Ads, LinkedIn |

## Built-in AI analyst

The plugin includes an ADUP Analyst agent — a senior performance marketing analyst that proactively surfaces insights, anomalies, and recommendations across all your connected platforms.

```
@adup-analyst What's wrong with the Facebook account? ROAS has been dropping.
@adup-analyst Build me a monthly report for Nike NL.
@adup-analyst Compare Meta vs Google performance for Q1.
```

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

## Requirements

- Claude Code 1.0.0+
- Active ADUP account — [app.adup.io](https://app.adup.io)
- At least one connected ad platform

## Support

- Email: hello@adup.io
- Dashboard: [app.adup.io](https://app.adup.io)

## License

MIT
