# ADUP — AI-Powered Performance Marketing Platform

## What is ADUP?

ADUP is an AI marketing analyst that connects to your ad accounts, analyses performance across platforms, and takes action — all supervised by humans through a safety-first approval pipeline.

It works as a Claude Code plugin: you talk to your marketing data in natural language, get executive-level analysis, and approve optimisations that the AI proposes — budget changes, pausing underperformers, refreshing creatives.

**Think of it as hiring a senior performance marketer that works 24/7, never forgets to check your accounts, and always asks before changing anything.**

---

## Who is it for?

### Agencies managing multiple clients
- One AI analyst across all clients, all platforms
- Monday morning briefings per client — ready before the team arrives
- 3-hour anomaly monitoring so Friday problems don't become Monday disasters
- Client-ready reports with talking points for your next call

### Solo advertisers
- Expert-level analysis without the expert salary
- Automated budget optimisation: scale winners, cut losers
- Creative fatigue detection before it wastes your budget
- Budget pacing alerts so you never overspend

---

## What platforms does it connect to?

| Platform | What you get |
|----------|-------------|
| **Facebook & Instagram Ads** | Campaign/ad set/ad management, budget changes, status changes, ad creation, fatigue detection, creative scoring, budget pacing |
| **Google Ads** | Search, Shopping, PMax analysis, budget changes, RSA headline/description updates, Quality Score diagnostics |
| **TikTok Ads** | Video-first analysis with hook rates, completion metrics, budget/status management |
| **LinkedIn Ads** | B2B lead gen analysis, CPL benchmarking, creative updates, budget/status management |
| **Google Analytics 4** | Revenue source of truth, blended ROAS, conversion funnels, attribution gap analysis |
| **HubSpot** | CRM data, deal pipeline, contact engagement |
| **Intercom** | Support data, customer journey context |

---

## Core capabilities

### 1. Cross-platform analysis

Ask questions in plain language and get instant answers from any connected platform:

```
"How are my Facebook campaigns doing this month?"
"Compare Google vs Facebook ROAS for the last 30 days"
"What's my blended ROAS across all channels?"
"Which TikTok ads have the best hook rate?"
```

ADUP pulls data from every connected platform, cross-references with GA4 for attribution accuracy, and gives you an opinionated answer — not a data dump.

### 2. Autonomous optimisation (with approval)

ADUP doesn't just analyse — it acts. But never without permission.

**How it works:**
1. AI identifies an opportunity: "Campaign X has 4.2x ROAS — 60% above target with stable trends"
2. AI creates a **proposal**: "Increase daily budget from $100 to $120 (+20%)"
3. Proposal enters the **Action Middleware** — checks against your safety rules
4. If within your rules → auto-approved and executed
5. If outside your rules → appears in your dashboard for manual review
6. Every action is logged with before/after snapshots

**Available actions:**

| Action | Facebook | Google | TikTok | LinkedIn |
|--------|----------|--------|--------|----------|
| Budget increase/decrease | ✅ | ✅ | ✅ | ✅ |
| Pause/activate campaigns | ✅ | ✅ | ✅ | ✅ |
| Pause/activate ad groups | ✅ | ✅ | ✅ | ✅ |
| Pause/activate ads | ✅ | ✅ | ✅ | — |
| Create new ads | ✅ | — | — | — |
| Update ad copy (RSA) | — | ✅ | — | — |
| Update creative copy | — | — | — | ✅ |

### 3. Safety guardrails

You set the boundaries. The AI works within them.

**Per-client settings:**
- **Monthly budget cap** — AI can never increase budgets beyond this total
- **Max % change per proposal** — e.g., never change a budget by more than 20% at once
- **Max absolute change** — e.g., never increase by more than $500 at once
- **Daily auto-approval limit** — e.g., max 10 automated actions per day
- **Manual review threshold** — everything above a certain risk level requires human approval
- **Global kill switch** — turn off all automation instantly

**How safety works:**
- Every proposal is checked against ALL your rules
- No matching rule = requires manual review (safe default)
- Monthly budget cap prevents runaway scaling
- Daily rate limiting prevents cascading changes
- High-risk actions (status changes, ad creation) can require manual approval by default
- Irreversible actions are flagged with warnings

### 4. Ad fatigue detection

ADUP monitors your creatives for fatigue signals:
- Rising frequency (audience seeing the same ad too often)
- Declining CTR week-over-week
- Increasing CPA week-over-week

Each ad gets scored: **HIGH** / **MEDIUM** / **LOW** fatigue.
- HIGH → proposes pausing the ad
- MEDIUM → proposes reducing budget on the parent ad set
- LOW → flags for monitoring, suggests preparing replacement creatives

### 5. Budget pacing

Tracks every campaign's spend against its budget:
- **On track** (90-110% of expected) → no action needed
- **Underpacing** (<90%) → alerts you, checks if targeting is too narrow
- **Overpacing** (>110%) → proposes budget reduction to pace through the period
- **Severe overpacing** (>150%) → urgent alert, proposes immediate correction

### 6. Creative intelligence

Scores your creatives across multiple dimensions to build a **Creative Playbook**:

| Dimension | What it scores |
|-----------|---------------|
| **Format** | Video vs static vs carousel — which drives best results? |
| **Content type** | Testimonial vs UGC vs product shot vs offer-led |
| **Headline pattern** | Question vs statement vs number-led |
| **CTA** | "Shop Now" vs "Learn More" vs "Get Started" |
| **Text length** | Short (<125 chars) vs medium vs long |

Each category is scored on: **CTR (20%)** + **CPA (30%)** + **ROAS (30%)** + **Durability (20%)**

The playbook tells you exactly what creative style works for each client — no more guessing.

### 7. Scheduled monitoring

| Task | Schedule | What it does |
|------|----------|-------------|
| **Monday Briefing** | Mon 8 AM | Per-client executive summary: verdict, top 3 wins, top 3 concerns, proposed actions |
| **Anomaly Alerts** | Every 3 hours | Catches spend spikes, delivery stops, budget exhaustion, CTR crashes |

**Monday Briefing output:**
```
📊 Nike NL — Week of March 3-9
Verdict: 🟢 Great week — ROAS up 18% WoW

Wins:
• "Spring Sale Retargeting" — ROAS 5.2x, recommend scaling 20%
• Google Brand Terms — CPA €8.50, lowest in 3 months

Concerns:
• "Prospecting Lookalike" — CPA spiked 35%, frequency 3.8
• LinkedIn "Decision Makers" — 0 conversions, €340 spent

Proposed Actions: [3 proposals created — awaiting approval]
```

**Anomaly Alerts:**
```
🔴 CRITICAL — Nike NL Facebook "Prospecting US" spend at 245% of daily average
→ Proposed: reduce daily budget from $500 to $400

⚠️ WARNING — Adidas EU Google Shopping CTR dropped 34% vs 7-day avg
```

### 8. Client reporting

Generate client-ready reports with:
- Executive summary in client-friendly language (no jargon)
- Performance by platform with WoW/MoM comparisons
- What worked and what needs improvement
- Talking points for the client call:
  - *"Lead with the 18% ROAS improvement on Facebook"*
  - *"Address the LinkedIn CPL increase — propose audience refinement"*
- Attribution transparency: GA4 blended ROAS vs platform-reported

---

## Architecture

```
You (Claude Code)
  ↓ natural language
ADUP Plugin (local)
  ↓ MCP protocol
Gateway (cloud)
  ↓ routes to platform
MCP Servers (Facebook, Google, TikTok, LinkedIn, GA4)
  ↓ reads data / creates proposals
Central API
  ├─ Auto-approval check against your rules
  ├─ If approved → Redis queue → Action Worker → Platform API
  └─ If needs review → Dashboard for manual approval
```

**6 components, fully integrated:**

| Component | What it does |
|-----------|-------------|
| **Claude Plugin** | Your interface — talk to your data |
| **MCP Servers** | Connect to each platform's API |
| **Gateway** | Routes requests, handles auth |
| **Central API** | Proposals, rules, approval engine |
| **Action Worker** | Executes approved changes on platform APIs |
| **Dashboard** | Review proposals, configure rules, audit trail |

---

## Getting started

### 1. Install the plugin
```bash
claude plugin install adup --plugin-dir /path/to/adup-claude-plugin
```

### 2. Set up your API key
```
/adup:setup
```
Get your key from [tara.adup.io/settings/api](https://tara.adup.io/settings/api).

### 3. Verify connection
```
/adup:connect
```

### 4. Start analysing
```
How are my campaigns doing this week?
@adup-analyst Give me a full performance review for Nike NL
/adup:monday-briefing
```

### 5. Configure safety rules (dashboard)
Set your budget caps, % limits, and approval thresholds at [tara.adup.io](https://tara.adup.io).

---

## Available skills (20)

| Category | Skill | What it does |
|----------|-------|-------------|
| **Setup** | `/adup:setup` | Configure API key |
| | `/adup:connect` | Verify connection |
| | `/adup:shop-select` | Switch client (agencies) |
| **Analysis** | `/adup:ads-overview` | Quick cross-platform summary |
| | `/adup:facebook-ads` | Deep Facebook/Instagram analysis |
| | `/adup:google-ads` | Google Ads performance |
| | `/adup:analytics` | GA4 web analytics |
| | `/adup:cross-platform` | Unified dashboard |
| | `/adup:budget-tracker` | Budget pacing alerts |
| | `/adup:ad-fatigue` | Creative fatigue scoring |
| | `/adup:creative-intelligence` | Creative playbook builder |
| **Actions** | `/adup:optimize-budget` | Budget reallocation proposals |
| | `/adup:manage-status` | Pause/activate proposals |
| | `/adup:create-ads` | New ad creation proposals |
| | `/adup:google-optimize` | Google Ads optimisation |
| | `/adup:linkedin-optimize` | LinkedIn optimisation |
| | `/adup:tiktok-optimize` | TikTok optimisation |
| **Reporting** | `/adup:monday-briefing` | Weekly executive briefing |
| | `/adup:client-report` | Client-ready reports |
| | `/adup:anomaly-alerts` | Real-time anomaly detection |

---

## What makes ADUP different

1. **Human-supervised, not autonomous.** AI proposes, you approve. Every action goes through your safety rules before execution.

2. **Cross-platform by default.** One conversation across Facebook, Google, TikTok, LinkedIn, and GA4. Blended metrics, not siloed dashboards.

3. **Opinionated analysis.** ADUP gives you a verdict ("Great week" / "Needs attention"), not a spreadsheet. It tells you what to do and why.

4. **Agency-first.** Multi-client by design. Monday briefings per client. Reports with talking points. Anomaly monitoring across all accounts.

5. **Safety-first automation.** Budget caps, percentage limits, daily rate limits, risk-level gating, manual review fallback. You set the boundaries — the AI works within them.

6. **Works where you work.** It's a Claude Code plugin — not another dashboard to check. Ask a question, get an answer, approve an action, move on.
