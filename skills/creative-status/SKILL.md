---
name: status
description: Sync proposal and ad statuses from the ADUP approval queue back into a local creative workspace. Updates state.json and ad.md status fields, writes denial notes into Review feedback sections, handles reviewer replication requests ("also launch on X"), and prints a campaign board. Supports --csv (status.csv for stakeholders) and --sheet (write to a connected Google Sheets MCP).
---

# Creative Status (/adup:status)

Pulls the current status of every proposal a workspace has launched and writes it back into the files. The workspace stays the source of truth for *content*; the ADUP platform is the source of truth for *approval state* — this skill is the one-way sync from platform → files (plus fulfilment of reviewer **replication requests**, Step 4, which routes through the normal launch flow with the user's confirmation).

Usage: `/adup:status [path] [--csv] [--sheet]`

Reminder to surface when reporting: approved ads are created on the platform in **PAUSED** state — approval never means spending has started.

---

## Step 1 — Load the ledger

1. Find the workspace root (walk up to `.adup/workspace.json`); read `workspace.json` and `state.json`. The `shop_slug` in `workspace.json` is the shop for this whole run — it goes into the `<shop_slug>` path segment of every request below, and into `shop_slug="<slug>"` on any MCP tool call. Never depend on the gateway's ambient active shop here: it is set per API key and a concurrent run can clobber it.
2. Collect every `targets` entry across `state.json` `ads`: `(ad_path, platform, lang, proposal_id, last_known_status)`. Nothing recorded → say "nothing launched yet — run /adup:launch" and stop.

## Step 2 — Query proposal statuses

Query the ADUP gateway's actions surface with the employee key (same Bearer as the MCP connector). List per shop, paginated:

```bash
curl -s -H "Authorization: Bearer $ADUP_API_KEY" -H "Accept: application/json" \
  "${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/actions/<shop_slug>/proposals?per_page=100&page=1"
```

Page through until all pages are seen (the route also accepts `status`, `platform`, `category` filters). Match returned proposals to the ledger by proposal id. For any ledger id missing from the listing, fetch it directly:

```bash
curl -s -H "Authorization: Bearer $ADUP_API_KEY" -H "Accept: application/json" \
  "${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/actions/<shop_slug>/proposals/<proposal_id>"
```

Map platform statuses to workspace lifecycle statuses:

| proposal status                  | target status in state.json | ad.md `status:` (worst-of across targets) |
|----------------------------------|-----------------------------|--------------------------------------------|
| proposed / pending_review        | proposed                    | proposed                                    |
| auto_approved / approved / executing | approved                | approved                                    |
| completed (ad created, PAUSED)   | live                        | live                                        |
| denied / rejected                | changes_requested           | changes_requested                           |
| failed (execution error)         | failed                      | proposed (flag the error)                   |
| expired (72h without review)     | expired                     | ready (needs re-launch)                     |

An ad.md gets the "worst" status of its targets (any denial → `changes_requested`; else any pending → `proposed`; else all live → `live`).

## Step 3 — Write back

1. **state.json**: update each target's `status`, add `ad_id` when the completed proposal carries the created platform ad id, add `denied_reason` / `execution_error` when present, and stamp `last_synced`.
2. **ad.md status field**: update per the table above.
3. **Denial notes**: when a proposal was denied with a reviewer note, set the ad's `status: changes_requested` and append (or update) a `## Review feedback` section at the bottom of that `ad.md`:

   ```markdown
   ## Review feedback
   - [2026-07-03, facebook/en] Denied by j.doe: "Headline overpromises — drop the 50% claim."
   ```

   Never overwrite existing feedback entries; append new ones. After the user edits the copy, `/adup:launch` picks the ad up again (content hash changed) and re-proposes it.

## Step 4 — Replication requests ("also launch on X")

When a reviewer approves a proposal in the portal, they can tick extra platforms. When the backend could NOT auto-create the replica (missing/insufficient embedded `platform_targets`, or the platform needs new copy), it files a **replication request** for Claude to fulfil. Check for them every status run:

```bash
curl -s -H "Authorization: Bearer $ADUP_API_KEY" -H "Accept: application/json" \
  "${ADUP_API_BASE:-https://centralapi.adup.io}/api/v2/employee/tara/actions/replication-requests?shop_slug=<shop_slug>&status=pending"
```

Each row carries `{id, platform, source_proposal (summary incl. entity_name + creative preview), notes, status}`. For each **pending** request:

1. **Announce it**: "Reviewer asked to also launch '<entity_name>' on {platform}" (+ the reviewer's `notes`, if any).
2. **Locate the source ad**: match the source proposal id against `state.json` `targets`. If the source isn't in this workspace, say so and offer to scaffold a fresh ad folder from the request's creative preview + copy.
3. **Scaffold/adjust the `ad.md`**: add the platform to `platforms:`. If the source copy exceeds the target platform's limits (platform-specs.json), **draft platform-fit copy as a qualified section** (e.g. `## Primary text (tiktok)`) and **propose it to the user — never adjust copy silently**.
4. **Launch**: with the user's go-ahead, run the normal `/adup:launch` flow for that ad scoped to the requested platform (validate → upload → propose; same batch/count-confirmation rules). The proposal calls are namespaced `platform__tool` and each carries the workspace's `shop_slug="<slug>"` explicitly — a replication write must never land on another client.
5. **Close the request**:

   ```bash
   curl -s -X PATCH -H "Authorization: Bearer $ADUP_API_KEY" -H "Content-Type: application/json" -H "Accept: application/json" \
     -d '{"status": "fulfilled", "fulfilled_proposal_id": "<new proposal id>"}' \
     "${ADUP_API_BASE:-https://centralapi.adup.io}/api/v2/employee/tara/actions/replication-requests/<id>"
   ```

   If the user declines the replication, PATCH `{"status": "dismissed"}` instead (tell the user you're dismissing it so the reviewer sees it was seen). Leave the request untouched if the user wants to decide later.

The new proposal goes through the normal approval queue like any launch — replication never bypasses the middleware, and the resulting ad still lands PAUSED.

## Step 5 — Board output

Print a campaign → ad → per-platform board:

```
acme-nl — status (synced 2026-07-03 14:02)

2026-07_summer-sale
  prospecting-broad/hero-video      facebook:en  live (PAUSED on platform, ad_id 1202…)
                                    tiktok:en    approved — executing
  prospecting-broad/testimonial-1   facebook:en  changes_requested — see Review feedback
  retargeting/offer-static          facebook:en  proposed — awaiting review

3 live · 1 approved · 4 proposed · 1 changes_requested
1 replication request pending: "hero-video" → linkedin (see above)
Approve pending: https://tara.adup.io/proposals?batch=<batch_id>
```

End with: "Live = created on the platform in PAUSED state. Activate in the platform's ads manager when ready to spend."

## Variant: --csv

Also write `status.csv` at the workspace root — the stakeholder overview, one row per ad × platform × language:

```
campaign,adset,ad,platform,language,status,proposal_id,ad_id,batch_id,last_synced,notes
```

Populate `notes` with denial reasons / execution errors. Overwrite the file each run (it is generated output, not source of truth). Mention where it was saved.

## Variant: --sheet

Same table as `--csv`, but pushed to a spreadsheet: if a Google Sheets MCP (or Google Drive tool that can write sheets) is connected in this Claude session, write/update a tab named `ADUP Status — <shop_slug>` in the sheet the user designates (ask once, remember the choice in `workspace.json` under `reporting.sheet_id`). If no Sheets MCP is available, say so and fall back to `--csv` output the user can import. One-way export only — never read launch data back from the sheet.

## Rules

1. **One-way sync for statuses**: platform state → files. This skill never approves or denies proposals, and the only proposals it ever creates are replication-request fulfilments (Step 4) — explicitly user-confirmed and routed through the normal `/adup:launch` flow and approval queue.
2. **Never edit copy silently** — status sync touches only the `status:` frontmatter field and the `## Review feedback` section; replication scaffolding may add `platforms:` entries and user-approved copy variant sections, nothing else.
3. **Preserve unknown state**: if the gateway is unreachable, report the error and leave all files untouched.
4. **Restate the PAUSED invariant** whenever anything reaches `live`.
