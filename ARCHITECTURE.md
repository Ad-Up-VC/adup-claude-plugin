# ADUP Platform — Architecture & Developer Onboarding

> **Read this first.** It describes what we're building, why, and how the pieces
> fit together across all the repos. Every repo also has a `CLAUDE.md` at its
> root with repo-specific guidance that Claude Code auto-loads — start there for
> the repo you're working in, and come back here for the cross-repo picture.

---

## 1. What ADUP is

ADUP is a **B2B marketing-AI middleware platform**. It sits between an AI
assistant (Claude, via Claude Code) and the marketing platforms an agency runs
ads on (Meta/Facebook, Google Ads, TikTok, LinkedIn, GA4, GSC, HubSpot,
Intercom, …) and enforces **permissions, human approval, and a full audit trail
on every change the AI proposes.**

Two customer types:

| Type | Unit they manage | Billed per | Term in the UI |
|------|------------------|-----------|----------------|
| **Agency** | client accounts | active connected client | **Brand** |
| **Enterprise** | internal business units | active user seat | **Business Unit** |

> Internally the managed account is still a **shop** (`shop_id` / `shop_slug` /
> `active_shop_slug`) everywhere in the DB and code. "Brand" is a UI label only
> (see §10). Don't rename the variables.

### The goal / the mechanic

> **Reads flow straight through. Every write is intercepted, turned into a
> proposal, run through an approval policy, executed by a platform executor, and
> audited — no matter which MCP server or AI produced it.**

This lets an agency safely let AI operate dozens of ad accounts: an analyst can
*propose* a budget change from a chat with Claude, and it only goes live after a
manager approves (in the portal, or via Slack/Teams/etc.), with the whole thing
logged.

We are **official-MCP-first**: when Meta/Google ship official MCP servers we
route to them; until then our own Python MCP servers (`tara-mcps`) bridge to the
platform APIs. The interception/approval layer is identical either way.

---

## 2. The repos at a glance

| Repo | Role | Stack | Default branch | Deploys to |
|------|------|-------|----------------|-----------|
| **tara-client** | Web portals (Agency / Client / Admin) | React 18 + TypeScript (CRA `react-scripts`), Redux Toolkit, React Router v6, legacy SCSS | `main` (active work + dev deploy on `development`) | DigitalOcean App Platform |
| **tara-central-api** | Backend: identity, billing, proposals, executors, integrations | Laravel 12, modular (`nwidart/laravel-modules`), MySQL 8, Redis | `main` (deploy on `development`) | DigitalOcean droplet (nginx + PHP-FPM) |
| **tara-gateway** | MCP middleware between Claude and the MCP servers | Node.js (Fastify) | `main` | DigitalOcean App Platform |
| **tara-mcps** | Per-platform MCP servers (read tools + `propose_*` write tools) | Python (FastMCP) | `main` | DigitalOcean droplet (SSH deploy) |
| **adup-claude-plugin** | The Claude Code plugin employees install | Claude Code plugin (`.mcp.json` + skills) | `main` | Distributed to employees |
| **tara-action-worker2** | **DEPRECATED** Redis BRPOP execution worker | Python 3.11 | — | not deployed (central-api executes inline) |
| **adup-website** | Marketing site | Next.js | `main` | (set up hosting) |

> The `tara26-*` folders in the workspace were a planned "copy-and-rebuild"
> strategy that we did **not** end up using — all real work happens on the repos
> above. The `CLAUDE.md` headers still say `tara26-*` for that historical reason;
> the repos are named `tara-*`.

---

## 3. System architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│  PEOPLE                                                                    │
│  Agency owner / team_lead / manager / analyst / read_only   +  Brand contact│
└───────────────┬───────────────────────────────────────┬──────────────────┘
                │ Web portal (Bearer: employee API key)  │ Claude Code + plugin
                ▼                                         ▼  (Bearer: employee key)
   ┌─────────────────────────┐               ┌───────────────────────────────┐
   │   tara-client (React)   │   REST        │   adup-claude-plugin (.mcp.json)│
   │  Dashboard, Log Center, │◄────────────► │   connectors → gateway          │
   │  Brands, Control Center │   /api/v1     └───────────────┬───────────────┘
   │  (/integrations),       │   /api/v2                     │ MCP (JSON-RPC)
   │  Actions, Team, Skills   │                              ▼
   └───────────┬─────────────┘               ┌───────────────────────────────┐
               │ REST                          │   tara-gateway (Fastify)       │
               ▼                               │  • resolve employee identity   │
   ┌─────────────────────────────────────┐     │  • scope tools to brands       │
   │   tara-central-api (Laravel)        │◄───►│  • READS → pass through         │
   │  Identity / RBAC, Integrations,     │ REST│  • WRITES → intercept → proposal│
   │  TaraActions (proposal pipeline +   │     └───────────────┬───────────────┘
   │  executors + Meta rate governor +   │                     │ MCP
   │  audit), Payments/Billing, Skills,  │                     ▼
   │  ClientPortal, Notifications        │     ┌───────────────────────────────┐
   └───────────┬─────────────────────────┘     │   tara-mcps (Python FastMCP)   │
               │ executes approved writes        │  facebook_ads, google_ads, ga4,│
               ▼                                 │  gsc, linkedin, hubspot, …      │
   ┌─────────────────────────────────────┐      │  reads → platform API           │
   │  Platform APIs (Meta, Google, …)    │◄─────│  writes → propose_* → central   │
   │  + Slack/Teams/Email notifications  │      └───────────────────────────────┘
   └─────────────────────────────────────┘
```

**The golden rule:** a write never reaches a platform API directly. It always
becomes an `ActionProposal` in `tara-central-api`, is evaluated by the
auto-approval rules, and is only executed by a platform **executor** after it is
approved.

---

## 4. Core domain concepts

### Identity, roles & RBAC
- **Employees** (`agency_employees`) belong to an organisation and have a role:
  `owner → team_lead → manager → analyst → read_only`.
- **Permissions** are per-brand (`employee_shop_permissions`) and capability-based
  (Spatie + a small capability map). Reads are broad; *proposing* and *approving*
  writes are gated by role.
- **Auth:** the web portal logs in with a seller JWT **and** receives an agency
  **employee API key** (`agency_api_key`, an `emp_…` bearer). The FE stores the
  agency bearer in Redux **only** (never localStorage) and calls
  `GET /api/v1/me` to load the `employeeIdentity` (role + accessible brands).
  The gateway/plugin authenticate to the API with the same employee key.
  > Gotcha we hit: login must call `/me` to populate `employeeIdentity`, or every
  > brand selector renders empty. (Fixed — `App.tsx` bootstraps it from the token.)

### Brands (shops) & integrations
- A **brand** is a `shop`. Each brand connects platforms **per-brand**:
  - **OAuth** (W2) — user token, stored in `tara_credentials.oauth`.
  - **System-User token** (Meta) — non-expiring, better rate limits; provisioned
    in the UI on the Facebook card, stored with `token_kind: system_user`.
- The gateway forwards per-brand credentials to the MCP servers per request.

### The approval pipeline (the heart of the system — `Modules/TaraActions`)
```
MCP write tool (propose_* or official) 
  → gateway intercepts (write-interceptor)
  → ActionProposalController → ActionProposalService::create
  → AutoApprovalService::evaluate (KPI threshold rules; else pending_review)
  → events: ActionProposed / ActionApproved / ActionDenied
  → DispatchApprovedActionJob → ActionExecutionService::execute(platform, payload)
  → platform executor (Facebook / Google / TikTok / LinkedIn / OfficialMcp)
  → AuditLogService + multi-channel notification
```
- **Auto-approval rules** (`/actions/rules`) let owners/managers auto-approve
  proposals that meet KPI thresholds (e.g. "budget change < 10% when ROAS > 3").
- **Approval settings** (`/actions/approval-settings`) are per-brand (budget caps,
  manual-approval threshold, middleware on/off).

### Meta rate governor (`Modules/TaraActions/Services/MetaRateGovernor.php`)
Proactive token-bucket limiter in front of every Meta Graph write:
- **80% safety factor** of Meta's real limits.
- Per-ad-account **BUC** bucket + app-level **platform** bucket (Redis-backed).
- Self-corrects from `X-Business-Use-Case-Usage` / `X-App-Usage` response headers.
- Prefers **system-user tokens** (BUC bucket only) over OAuth user tokens.
- On a would-be breach it **requeues** the job (spreads bursts) instead of erroring.
- Every Meta call is logged to `meta_api_call_log` and surfaced per-agency in the
  **Log Center → Meta API** tab.

### MCP & the gateway
- The gateway is **stateless** beyond in-memory caches. It resolves the employee
  from the bearer, scopes the tool list to the brands they can access, routes
  reads straight to the upstream MCP, and **intercepts writes** into the proposal
  pipeline.
- Our MCP servers expose write tools only as `propose_*` (which POST to the
  proposal endpoint). **Never add a direct-mutation tool to an MCP server** — it
  would bypass approval.

### Notifications
Proposal events fan out to Slack / Teams / Google Chat / Email / Webhook through
a channel abstraction (`Modules/Notifications`), with one-click approve/deny.

### Skills & the plugin
`adup-claude-plugin` ships `.mcp.json` connectors (pointing at the gateway) plus
skills (`facebook-ads`, `google-ads`, `monday-briefing`, `cross-platform`, …).
Employees install it, run `/adup:setup` with their API key, and Claude can then
read + propose across the brands they're allowed to see.

---

## 5. Key end-to-end flows

**Connect a platform (per brand):** Control Center (`/integrations`) → platform
card → Connect (OAuth) **or**, for Meta, "Connect via System User" on the
Facebook card → token validated, ad account mapped, stored on the brand.

**A read:** plugin/portal → gateway → MCP server → platform API → data back. No
proposal, no approval.

**A write (the important one):** analyst asks Claude to change a budget → MCP
`propose_budget_change` (or an official write tool the gateway intercepts) →
`ActionProposal` created → auto-approval rules evaluated → if not auto-approved,
`pending_review` + Slack/Teams notification → manager approves → executor applies
it via the platform API (governed by the rate governor) → audit log entry.

**Employee onboarding:** owner invites employee (magic-link) → employee accepts,
gets their `emp_…` API key once → installs the plugin / logs into the portal →
sees only their assigned brands.

---

## 6. The web app (`tara-client`) — what's where

Single React app, role-based routing. Main nav:

- **Dashboard** — pending proposals, quick stats, onboarding surface.
- **Log Center** (`/logs`) — tabbed: **Audit** (who did what) + **Meta API**
  (every Meta call + rate-limit usage). (Old `/audit-log` and `/meta-activity`
  redirect here.)
- **Brands** (`/clients`) — the brand list + per-brand connection status.
- **Control Center** (`/integrations`) — tabbed hub:
  **Integrations** (the platform logo-card grid + Meta System-User connect on the
  Facebook card) · **Claude Code plugin** (gateway URL + Cowork setup) ·
  **Custom MCP** (add a server by URL) · **Governance** (per-tool allow /
  require-approval / block). *Lives at `/integrations` because the OAuth callback
  round-trips back to that URL.*
- **Actions** — **Queue** · **History** · **Auto-Approval Rules** · **Approval
  Settings** (per brand).
- **Team** — employees, roles, brand assignment, invites.
- **Skills** — org skill library.
- **My MCP setup** — per-employee plugin setup.
- **Settings** — billing/subscription, profile, API keys, etc.

**FE conventions:** agency bearer in Redux only; new endpoints under `/api/v1/*`,
proposals under `/api/v2/*`; legacy SCSS (no new MUI); the production build is
`react-scripts build` and it **fails the whole build on any TS error** — always
run `npx tsc --noEmit --skipLibCheck` before pushing.

---

## 7. The backend (`tara-central-api`) — modules

Laravel 12, `nwidart/laravel-modules`. Key modules:
- **TaraActions** — the proposal pipeline, executors, `MetaRateGovernor`, audit,
  jobs, events, v2 routes. *Do not redesign; extend.*
- **Identity** — `agency_employees`, groups, permissions, `/api/v1/me`, invites.
- **Shop / Integration / TaraAi** — brands + per-brand platform credentials, Meta
  OAuth + system-user provisioning.
- **Payments / Billing** — Stripe subscriptions; agency-client vs enterprise-seat
  counting.
- **SkillLibrary / ClientPortal / Notifications / Admin / Settings**.

**DB safety (important):** test every migration on a staging copy of prod first;
always `php artisan migrate --pretend` before `migrate`; never drop columns
without a backup migration. The deploy build runs `composer install`, which runs
`artisan package:discover` (boots every provider) — a fatal in any new file fails
the whole build.

---

## 8. Local development

Each repo has its own setup (see its `README.md` / `CLAUDE.md`). Sketch:
- **tara-client:** `npm install` → `npm start` (CRA dev server). Build:
  `DISABLE_ESLINT_PLUGIN=true npm run build`.
- **tara-central-api:** `composer install`, `.env`, `php artisan key:generate`,
  `php artisan migrate`, `php artisan serve`. Requires MySQL 8 + Redis.
- **tara-gateway:** `npm install` → `npm run dev`. Needs the central-api URL +
  the internal token.
- **tara-mcps:** `pip install -e .`; each server runs as a FastMCP process; the
  gateway forwards per-brand credentials as headers.
- **adup-claude-plugin:** point `.mcp.json` at your gateway, set `ADUP_API_KEY`.

The FE talks to a **dev** central-api/gateway by hostname (it picks DEV vs
STAGING vs LIVE from `src/lib/constants/central-api.ts` based on the URL).

---

## 9. Deployment & infra

- **tara-client & tara-gateway:** DigitalOcean **App Platform** — auto-build &
  deploy on push to the tracked branch (`development` for the dev FE). The FE
  build is the same `react-scripts build`; a TS error breaks the deploy.
- **tara-central-api & tara-mcps:** DigitalOcean **droplets** — CI (`pipline.yml`
  / SSH deploy) on push to the tracked branch. central-api runs migrations on
  deploy (so a bad migration breaks the deploy — see §7).
- **DNS:** Cloudflare-managed (`kodeia.com` for dev/staging, `adup.io` for some
  prod hosts). Subdomain records are **not** in any repo's CI — they're managed in
  Cloudflare. (We had an incident where deleted Cloudflare records made the dev
  site unreachable even though the servers were healthy — DNS ≠ deploy.)

---

## 10. Conventions, invariants & gotchas

- **Security:** agency/admin bearer tokens live in **Redux only**, never
  localStorage; employee API keys are **bcrypt-hashed** server-side (`api_key_hint`
  keeps only the last 4 chars); tokens are never logged.
- **Never bypass the approval pipeline.** Every write tool must route through
  interception → proposal → executor. No direct-mutation MCP tools.
- **"Brand" is a label, not a rename.** UI says Brand/Business Unit; the DB and
  code stay `shop_*`. The merchant's own **e-commerce webshop** (Webshop, Shopper,
  AI Checkout, Shop Appearance) is a *different* concept — leave those as "shop".
- **TS errors fail the FE build.** Run `tsc --noEmit --skipLibCheck` before push.
- **Migrations are load-bearing for deploys.** See §7.

---

## 11. Claude Code setup (why each repo has a CLAUDE.md)

Claude Code automatically loads a repo's root `CLAUDE.md` when you open it. Each
of our repos has one with repo-specific role, key files, conventions, and
security rules — so a developer (or Claude) who clones a single repo is oriented
immediately, and this `ARCHITECTURE.md` gives the cross-repo picture.

When you clone a repo: open it in Claude Code, and it will pick up `CLAUDE.md`
automatically. Start a task by reading `CLAUDE.md` (repo specifics) + this file
(the whole platform).

---

## 12. Status & roadmap

**Shipped:** RBAC + per-brand scoping; per-brand platform OAuth + Meta
system-user tokens; the full approval pipeline with auto-approval rules and
per-brand approval settings; the Meta rate governor with per-agency call audit;
the unified Log Center; the tabbed Control Center / Integrations hub; multi-channel
notifications; the Skills library; billing (agency clients / enterprise seats).

**Next:** per-user rate limits + per-user usage views; wiring official Meta/Google
MCP servers as they launch (the executor already supports an `official_mcp`
execution path); optional revival of the execution worker for scale.
