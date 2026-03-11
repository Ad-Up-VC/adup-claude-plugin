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

Get your API key from [tara-vc.adup.io/settings/api](https://tara-vc.adup.io/settings/api).

### 3. Verify connection

```
/adup:connect
```

## Available skills

### Setup & Connection
| Skill | Command | Description |
|-------|---------|-------------|
| Setup | `/adup:setup` | Configure your API key (run once after install) |
| Connect | `/adup:connect` | Verify connection and see available shops |
| Shop Select | `/adup:shop-select` | Switch active client (agencies) |

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

### Actions (via middleware — all proposals require approval)
| Skill | Command | Description |
|-------|---------|-------------|
| Optimize Budget | `/adup:optimize-budget` | Propose budget increases/decreases with data |
| Manage Status | `/adup:manage-status` | Propose pausing/activating campaigns, ad sets, ads |
| Create Ads | `/adup:create-ads` | Propose new ad creation within existing ad sets |
| Google Optimize | `/adup:google-optimize` | Propose Google Ads budget, status & RSA changes |
| LinkedIn Optimize | `/adup:linkedin-optimize` | Propose LinkedIn budget, status & creative changes |
| TikTok Optimize | `/adup:tiktok-optimize` | Propose TikTok budget & status changes |

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
- Active ADUP account — [tara-vc.adup.io](https://tara-vc.adup.io)
- At least one connected ad platform

## License

MIT
