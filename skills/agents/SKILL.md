---
name: agents
description: Operate your agency's managed agents (the Reporting Skill, the Spreadsheet Skill, the Assistant) from Claude Code. Shows each brand's agents with their state, schedule and last run; opens the latest drafted report in Tara or downloads its PPTX/XLSX; starts a run now (with an explicit cost confirmation); lists, pulls and publishes the agency's custom agent skills; and cleans up the personal skills the retired /adup:sync-skills wrote. Tool-backed, so it works in Cowork and cloud sessions too. Trigger on "agents", "is the report drafted", "open the Acme report", "run the reporting agent", "publish this skill to the agents".
---

# Managed Agents (/adup:agents)

The agency's managed agents run **server-side** in Tara — brand-scoped, budgeted, on their own
schedule, filing drafts into the same review queue `/adup:client-report` uses. This skill does not
execute them locally and does not copy their instructions down; it **operates** them from wherever
the analyst is working: read state, fetch output, start a run, and publish house-style skills up.

Usage: `/adup:agents [status | open <agent> | run <agent> [period] [--focus "…"] | skills | pull <skill> | publish <folder> [--name …] [--description …] | cleanup]`

Everything goes through the `adup` connector's unprefixed virtual tools — `list_agents`,
`get_agent_runs`, `get_agent_output`, `run_agent`, `list_agent_skills`, `publish_agent_skill`,
`get_agent_skill_package`. No curl, no `ADUP_API_KEY` in bash: the tools inherit the connector's
key, RBAC and ambient-shop guard, which is why this skill also works in Cowork and cloud sessions.
If these tools are not in the tool list, the gateway on this environment predates them — say so
plainly and point the user to Tara → **Agents**; do not fake a result.

**Tara portal base (`<TARA>`).** Links below are written as `<TARA>/…`. Resolve it from the
environment the connector is pointed at: production → `https://tara.adup.io`; if `ADUP_API_BASE`
(or the connector URL) is the dev host (`centralapi-dev.kodeia.com` / `gateway.kodeia.com`) →
`https://tara-dev.kodeia.com`; staging (`centralapi-staging.adup.io` / `gateway-staging.adup.io`)
→ `https://tara-staging.adup.io`. Print the resolved absolute URL, never the placeholder.

## Hard rules

- **`run_agent` is money.** Every run spends the agent's per-run budget. Always confirm first with
  the exact wording in "run" below. **Never** create a scheduled task that calls `run_agent` (the
  agent already has its own schedule — a local cron calling run-now is a double schedule), and
  never call it in a loop over shops.
- **Review happens in Tara.** This skill links to the report; it never approves, edits or publishes
  one, and it never renders an HTML report in the terminal.
- **Configuration happens in Tara.** Activating/deactivating an agent, changing its schedule,
  budget, model, instructions or attached skills is done at `<TARA>/agents/<agent_type>`.
  This skill has no tool for any of that and must not improvise one.
- **`report_ready` / `report_failed` are worker tools.** If they ever appear in the tool list for
  an employee key, do not call them — they belong to the run↔worker binding, not to you.
- **`publish` is a trust boundary.** The folder becomes instructions inside a server-side agent
  that reads client data. Show the full `SKILL.md` and get a confirmation before uploading.
- Pass `shop_slug="<slug>"` explicitly on every call (see "Resolve the brand").

## Resolve the brand — three steps, always

Every sub-command except `cleanup` is brand-scoped. Resolve it first, the way every skill does:

1. `list_shops` → the brands you can access. Match the brand the user named (case-insensitive,
   partial, exact slug wins; ask when 2+ match). One shop on the key → it is the brand.
2. `set_active_shop(shop_slug="<slug>")` — required for tool discovery; an agency key sees only the
   virtual tools until a shop is active.
3. Pass `shop_slug="<slug>"` explicitly on **every** call below. `set_active_shop` sets ONE
   ambient shop per API key; scheduled tasks and parallel sessions sharing that key race on it, so
   an explicit `shop_slug` is the only race-free option. Never rely on the ambient shop.

If the user named no brand and the key has several, ask which one (or offer "all" for `status`,
which then loops `list_agents(shop_slug=…)` per brand — reads only, no `run_agent` in a loop).

## Parsing the request

Take the sub-command from the user's words, not from a strict syntax:

| The user says | Sub-command |
|---|---|
| nothing / "status" / "what's the state of the agents" / "is the report drafted for Acme" | `status` |
| "open the report" / "download the deck" / "get the spreadsheet" | `open <agent>` |
| "run the reporting agent" / "draft May now" / "run it for last week, focus on Meta" | `run <agent> [period] [--focus "…"]` |
| "which skills has the agency published" | `skills` |
| "pull the house-style skill" / "download skill X so I can edit it" | `pull <skill>` |
| "publish this folder as a skill" / "push ./house-style to the agents" | `publish <folder> [--name …] [--description …]` |
| "clean up the old synced skills" | `cleanup` |

`<agent>` matches `agent_type` (`client_reporting`, `google_sheets`, `assistant`) or its `label`
("Reporting", "Spreadsheet", "Assistant") — case-insensitive, partial. When no agent is named and
the brand has exactly one agent that produces output, use it; otherwise ask.

---

## `status` (default)

1. Resolve the brand. Call `list_agents(shop_slug="<slug>")`.
2. Print one table. `agents[]` are the brand's configured agents; `available_types[]` lists every
   type the agency can switch on — a type present in `available_types` but absent from `agents` is
   shown as **Set up** (not configured for this brand yet).

```
Managed agents — Acme NL (acme-nl)

Agent              State            Schedule                    Last run                                     Next run
Reporting Skill    Active           Mondays 07:00 Europe/Amsterdam   ready · 2026-09-01 — "Aug: ROAS 3.4x, Meta up 12%"   Mon 2026-09-08 07:00
Spreadsheet Skill  Needs attention  Mondays 06:00 Europe/Amsterdam   failed · 2026-09-01 — "GA4 token expired"           Mon 2026-09-08 06:00
Assistant          Set up           —                           —                                            —

Configure, switch on/off or change schedules in Tara: <TARA>/agents
```

   - **State:** `needs_attention: true` → **Needs attention**; else `is_active` → **Active**;
     else **Off**; not configured → **Set up**.
   - **Schedule in words:** translate `schedule.cron` + `schedule.timezone` ("Mondays 07:00
     Europe/Amsterdam", "1st of the month 09:00", "weekdays 06:30"). Never print raw cron to the
     user; keep it available if they ask. `kind: 'chat'` agents have no schedule — print `—`.
   - **Last run:** from `last_run_at` plus the newest entry of `get_agent_runs(shop_slug="<slug>",
     agent_type="<type>", limit=1)` — `status` and `summary` (truncate the summary to one line).
     Skip the extra call for chat agents. **Next run:** `next_run_at`, in the schedule's timezone.
3. After the table, one line per agent that **Needs attention**, quoting the last run's `error`,
   and the Tara link `<TARA>/agents/<agent_type>`.
4. **First-run cleanup offer.** The first time `status` runs in a session, check for leftovers of
   the retired `/adup:sync-skills` (see `cleanup`). If any exist, say how many and offer to remove
   them — offer once, never delete unasked.

## `open <agent>`

1. Resolve the brand and the agent. Call `get_agent_runs(shop_slug="<slug>",
   agent_type="<type>", limit=3)` and take the newest run with `status: 'ready'`. None → say so
   ("No finished run yet — the last one is `<status>`") and offer `run`.
2. Deliver per output kind — the run's `outputs`/`artifacts[]` say what exists:
   - **HTML report** (`client_report_id` present) → `get_agent_output(run_id="<id>", kind="html")`
     → `{client_report_id, portal_path}`. Print the Tara link:
     `<TARA><portal_path>` (equivalently `<TARA>/client-reports/<client_report_id>`).
     The report is **reviewed in Tara** — never render it in the terminal, never call
     `create_report` for it, never claim it has been approved.
   - **PPTX / XLSX** (`artifacts[].kind`) → `get_agent_output(run_id="<id>", kind="pptx"|"xlsx")`
     → `{url, expires_at, filename}`. The URL is signed and expires in ~15 minutes — download it
     right away into the workspace reports folder `/adup:setup` creates:

     ```bash
     DEST=~/Desktop/ADUP-Reports/<slug>/$(date +%Y-%m)
     mkdir -p "$DEST"
     curl -sfL -o "$DEST/<filename>" "<url>" && ls -la "$DEST/<filename>"
     ```

     Print the saved path. If the download fails (expired URL, 4xx), call `get_agent_output`
     again for a fresh URL once; then report the error. Never print the signed URL in the summary.
3. Repeat the last-run line: period (`period_label`), `summary`, `cost_cents` as "€X.XX".

## `run <agent> [period] [--focus "…"]`

1. Resolve the brand and the agent. Read the agent's `label` from `list_agents`. Parse the
   period ("last week", "August", "2026-08-01 to 2026-08-31") into `period_start` / `period_end`
   (ISO dates); omit both to let the agent use its default period. `--focus` (or "focus on Meta
   creatives") → `focus`.
2. **Confirm first — verbatim, then wait for a yes:**

   > This starts a {label} run for {brand} and spends its per-run budget. Continue?

   No confirmation → do nothing. Never skip this, not even when the user said "just run it".
3. `run_agent(shop_slug="<slug>", agent_type="<type>", period_start=…, period_end=…, focus=…)`
   → `{run_id, status: 'scheduled'}`. Tool errors, in plain words:
   - **409** — "A {label} run for {brand} is already in flight. Follow it in Tara:
     <TARA>/agents/<agent_type>". Do not retry.
   - **422** — "The {label} agent is switched off for {brand}. Switch it on first in Tara:
     <TARA>/agents/<agent_type>, then run again." Do not try to activate it.
   - Anything else → quote the message; do not retry blindly (a retry may spend a second budget).
4. **Poll**: `get_agent_runs(shop_slug="<slug>", agent_type="<type>", limit=3)` every **10
   seconds**, matching `runs[].id == run_id`, until `status` is `ready`, `failed` or
   `budget_reached`. Report progress sparingly ("running…", "generating…"). **Cap: 30 minutes** —
   then stop polling and say: "Still running after 30 minutes — follow it in Tara at
   <TARA>/agents/<agent_type>; run `/adup:agents open <agent>` later." Never
   create a scheduled task to keep polling.
5. `ready` → behave exactly like `open` for this run. `failed` → quote `error` and the Tara link.
   `budget_reached` → say the run stopped at its budget cap (`cost_cents`), that a partial draft
   may exist in Tara, and that the cap is changed under the agent's settings in Tara — not here.

## `skills`

Resolve the brand (the catalog is agency-wide but the tool is brand-scoped). Call
`list_agent_skills(shop_slug="<slug>")` → `[{id, name, description, source, has_package, updated_at}]`.
Print:

```
Agent skills — Acme agency

ID     Name                 Source   Updated       Package
sk_12  House style          agency   2026-09-01    yes
sk_07  Report QA checklist  adup     2026-07-14    yes
sk_03  Legacy tone guide    agency   2026-05-02    no  (uploaded before packages were retained — republish to pull it)

Which agents a skill is attached to is not shown here — see Skill settings at <TARA>/agents/<agent_type>.
```

If the tool errors with a permission error, the user's role cannot manage settings — say so and
name the role required (`settings.manage`, i.e. owner/team_lead/manager).

## `pull <skill>`

1. Match `<skill>` against `list_agent_skills` by id or name. `has_package: false` → explain it
   cannot be pulled (published before packages were retained) and stop.
2. `get_agent_skill_package(shop_slug="<slug>", skill_id="<id>")` → `{url, expires_at}`. Download
   and unzip into the workspace for editing:

   ```bash
   DEST=~/Desktop/ADUP-Reports/_agent-skills/<slug-of-name>
   mkdir -p "$DEST"
   curl -sfL -o "$DEST.zip" "<url>" && unzip -o -q "$DEST.zip" -d "$DEST" && rm "$DEST.zip"
   ls -la "$DEST"
   ```

   (If the user is in a folder they want it in, use that instead.) Print the path and remind
   them that `/adup:agents publish <folder>` pushes an edited copy back as a **new** skill —
   re-attaching it to an agent happens in Tara.

## `publish <folder> [--name "…"] [--description "…"]`

1. **Validate.** The folder must exist and contain `SKILL.md` at its root (exactly that name,
   case-sensitive). Missing → say so and stop. Read `SKILL.md`; take `name` / `description` from
   its frontmatter when the flags are absent (fall back to the folder name; ask if still empty).
2. **Zip one level deep** — the server requires `SKILL.md` at the zip root, so zip the folder's
   *contents*, not the folder:

   ```bash
   cd "<folder>" && rm -f /tmp/adup-skill.zip && zip -r -q -X /tmp/adup-skill.zip . -x '.*' '__MACOSX/*' '*/.DS_Store'
   ls -la /tmp/adup-skill.zip && unzip -l /tmp/adup-skill.zip
   ```

   Over 2 MB decoded → stop and say what to trim (it is a rules file, not an asset store).
3. **Show, then ask.** Print the **full** `SKILL.md` and the zip's file list to the user, then:

   > This becomes instructions inside a server-side agent that reads {brand}'s client data.
   > Publish "{name}" to the agency's agent skills?

   No confirmation → delete the zip and stop. Never upload unasked.
4. `base64 -i /tmp/adup-skill.zip | tr -d '\n'` → `publish_agent_skill(shop_slug="<slug>",
   name="<name>", description="<description>", package_base64="<…>", filename="<name>.zip")`.
   The tool returns the created row; print its `id` and `name`. Remove the temp zip.
5. Remind: **attaching it to an agent happens in Tara** under **Skill settings** at
   `<TARA>/agents/<agent_type>` — publishing alone changes nothing for any agent.

## `cleanup`

Removes what the retired `/adup:sync-skills` left behind: personal skills it wrote to
`~/.claude/skills/adup-*/SKILL.md`. Their source (the portal skill library) no longer exists, so
they can only go stale.

1. List — only directories matching the exact pattern the old sync used, **and** containing a
   `SKILL.md`. Never touch anything else under `~/.claude/skills/`:

   ```bash
   for d in "$HOME"/.claude/skills/adup-*/; do [ -f "$d/SKILL.md" ] && echo "$d"; done
   ```

   Nothing found → "Nothing to clean up." and stop.
2. Show the list and ask: "Delete these N directories? They were written by /adup:sync-skills
   and no longer have a source." Wait for a yes.
3. Delete exactly those directories (`rm -rf` each listed path — re-check each is under
   `~/.claude/skills/` and starts with `adup-` before removing). Print each deleted path.
4. Tell the user the corresponding `/adup-<slug>` commands disappear on the next Claude Code
   restart, and that the agency's skills now live in the agents (`/adup:agents skills`).

`status` offers this automatically the first time it finds such directories in a session.

---

## Surfaces

| Surface | `/adup:agents` |
|---|---|
| Claude Code (CLI / IDE / desktop) | ✅ all sub-commands |
| Cowork sessions, cloud sessions / routines | ✅ `status`, `open` (HTML link), `run`, `skills` — tool-backed. `open` for PPTX/XLSX, `pull`, `publish`, `cleanup` need a shell; without one, print the signed URL's filename and expiry and say the download needs a local session |

## Notes

- Agent types today: `client_reporting` (HTML + PPTX, default Mondays 07:00), `google_sheets`
  (XLSX, default Mondays 06:00), `assistant` (chat only — no runs, no outputs; chat with it in
  Tara, or just keep talking here: Claude Code with the ADUP connector is a chat over the same
  tools). `available_types[].default_schedule` is what a newly activated agent gets.
- `/adup:client-report` checks `get_agent_runs` before building locally and offers the agent's
  draft when one covers the period. `/adup:setup` removes the local weekly/monthly reporting
  tasks for brands whose managed agent is active. Between the three, a brand gets one draft per
  period, not two.
- Costs are in cents (`cost_cents`); print as euros with two decimals.
- Never print signed URLs or the base64 package in the final summary.
