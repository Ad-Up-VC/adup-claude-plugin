---
name: sync-skills
description: DEPRECATED — the ADUP portal skill library it synced from no longer exists. Running it only cleans up the personal skills it used to write (~/.claude/skills/adup-*) and points you to /adup:agents, which operates the agency's managed agents instead. Removed in the next release.
---

# Sync ADUP Skills (deprecated)

This command used to fetch the skills your agency installed in the ADUP portal and write them to
`~/.claude/skills/adup-<slug>/SKILL.md` so they ran locally as `/adup-<slug>`.

**That library is gone.** The agency's skills now run *inside* Tara's managed agents — server-side,
brand-scoped, budgeted, on their own schedule, with their own review queue. Nothing is copied down
any more; you operate the agents from here with `/adup:agents`:

| You used to… | Now |
|---|---|
| sync the agency's skills and run them locally | `/adup:agents status` — see each brand's agents, state, last run |
| build the report yourself | `/adup:agents open reporting` — open the agent's draft in Tara, or download its PPTX/XLSX |
| wait for the schedule | `/adup:agents run reporting` — start a run now (confirms, it spends budget) |
| author a skill in the portal | `/adup:agents publish <folder>` — push a local SKILL.md folder up to the agents |

This works in Cowork and cloud sessions too, which the old sync never did.

## What this stub still does

Tell the user the above in two sentences, then run the **cleanup** that `/adup:agents cleanup`
runs — the old sync's own removal logic was the only thing keeping these directories honest, and
without a source they can only go stale:

1. List only directories matching the exact pattern the old sync used, **and** containing a
   `SKILL.md`. Never touch anything else under `~/.claude/skills/`:

   ```bash
   for d in "$HOME"/.claude/skills/adup-*/; do [ -f "$d/SKILL.md" ] && echo "$d"; done
   ```

   Nothing found → "Nothing to clean up." and stop.
2. Show the list and ask: "Delete these N directories? They were written by /adup:sync-skills
   and no longer have a source." Wait for a yes.
3. Delete exactly those directories (re-check each path is under `~/.claude/skills/` and starts
   with `adup-` before removing). Print each deleted path.
4. Tell the user the `/adup-<slug>` commands disappear on the next Claude Code restart.

Do **not** fetch anything, do not write to `~/.claude/skills/`, and do not tell the user to
restart to "pick up" synced skills — there are none.

## Removal

This stub ships for one release (v1.8.x) so existing installs get the message; it is deleted in
v1.9.0. `/adup:agents` is the command to learn.
