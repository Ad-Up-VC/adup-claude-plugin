# CLAUDE.md

## What This Is

ADUP Claude Plugin — a Claude Code plugin that provides 20+ skills for natural-language marketing analytics. Lets users query ad performance, run audits, generate reports, and propose optimizations across Facebook, Google, LinkedIn, TikTok, and more — all through Claude Code.

## Tech Stack

- Claude Code plugin format (skills as Markdown)
- MCP connection to tara-gateway via HTTP
- No traditional code compilation — skills are prompt-based

## Project Structure

```
.mcp.json                    # MCP server config (points to tara-gateway)
.claude-plugin/              # Claude plugin metadata
skills/
  setup/                     # API key configuration
  connect/                   # Connection verification
  shop-select/               # Switch active client
  ads-overview/              # Cross-platform ad summary
  facebook-ads/              # Facebook/Instagram deep dive
  google-ads/                # Search/Shopping/PMax analysis
  analytics/                 # GA4 analysis
  cross-platform/            # Unified dashboard across platforms
  budget-tracker/            # Budget pacing & alerts
  ad-fatigue/                # Creative fatigue detection
  creative-intelligence/     # Creative scoring
  optimize-budget/           # Propose budget changes
  manage-status/             # Propose pause/activate
  create-ads/                # Propose ad creation
  google-optimize/           # Google-specific optimizations
  linkedin-optimize/         # LinkedIn-specific optimizations
  tiktok-optimize/           # TikTok-specific optimizations
  monday-briefing/           # Executive summary reports
  client-report/             # Client-ready reports
  anomaly-alerts/            # Spend/delivery/CTR anomalies
scheduled-tasks/             # Recurring task definitions
templates/                   # Email/report templates
agents/                      # Multi-skill coordination
```

## How It Works

1. User invokes a skill (e.g., `/adup:facebook-ads`)
2. Skill sends MCP tool calls to tara-gateway at the URL in `.mcp.json`
3. Gateway authenticates via `Authorization: Bearer ${ADUP_API_KEY}`
4. Gateway proxies to MCP servers (tara-mcps) for platform data
5. Skill formats and presents results to the user

## Setup

```bash
# Install the plugin in Claude Code
claude plugin install adup --plugin-dir /path/to/adup-claude-plugin

# Configure API key
/adup:setup        # Enter API key (get it from tara.adup.io/settings/api)

# Verify connection
/adup:connect
```

## Key Skills

| Skill | Purpose |
|-------|---------|
| `/adup:connect` | Verify API connection |
| `/adup:shop-select` | Switch active client |
| `/adup:ads-overview` | Quick cross-platform summary |
| `/adup:facebook-ads` | Facebook/Instagram deep dive |
| `/adup:google-ads` | Google Ads analysis |
| `/adup:analytics` | GA4 data analysis |
| `/adup:cross-platform` | Unified dashboard |
| `/adup:ad-fatigue` | Creative fatigue detection |
| `/adup:monday-briefing` | Executive report |

## MCP Configuration (.mcp.json)

```json
{
  "mcpServers": {
    "adup": {
      "type": "http",
      "url": "https://gateway.adup.io/mcp",
      "headers": {
        "Authorization": "Bearer ${ADUP_API_KEY}"
      }
    }
  }
}
```

## Ecosystem Connections

- **tara-gateway** — all MCP calls go through the gateway's `/mcp` endpoint
- **tara-mcps** — gateway proxies to these MCP servers for actual platform data
- **tara-central-api** — gateway fetches credentials from Central API

## Code Conventions

- Each skill is a directory with a `SKILL.md` file
- Skills contain natural language prompts, not traditional code
- All action proposals (budget changes, pause/activate, create ads) require human approval
- Skills should reference MCP tools by their exact names
- Keep skill prompts focused and specific

## Git Commit Guidelines

- Never mention co-authored-by or tool names in commit messages
