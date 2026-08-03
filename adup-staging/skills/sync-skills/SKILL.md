---
name: sync-skills
description: Fetch the skills your agency has installed in the ADUP portal and write them into your personal Claude skills directory. Run this after your agency owner installs or updates skills in the portal so they become available as /adup-<slug> commands in your next Claude Code session.
---

# Sync ADUP Skills

Fetch the org-installed and org-private skills from Central API and write them as **personal
skills** so Claude Code can find them.

## Layout — one directory per skill, exactly one level deep

Claude Code discovers a personal skill at `~/.claude/skills/<skill-name>/SKILL.md` and **the
directory name becomes the command**. Nothing nested deeper is discovered, and there is no
`group:name` syntax for personal skills — that namespacing exists only for *plugin* skills.

So each synced skill is written to its own top-level directory, prefixed `adup-`:

```
~/.claude/skills/adup-<slug>/SKILL.md     →  invoked as  /adup-<slug>
```

The `adup-` prefix keeps them recognisable and collision-free without nesting.

## Where synced skills DO and DO NOT appear

| Surface | Sees synced skills? |
|---|---|
| Claude Code (CLI / IDE / desktop local sessions) | ✅ yes |
| Desktop **scheduled tasks** (run locally) | ✅ yes |
| **Cowork** sessions | ❌ no |
| Cloud sessions / **routines** | ❌ no |

Cowork and cloud sessions do not read `~/.claude/skills/` at all — they load the skills enabled
for the user's claude.ai account at session start. **Say this to the user** rather than letting
them discover it as a missing command: an agency skill synced here will not appear in Cowork.

## Steps

### 1. Check the API key

Confirm `ADUP_STAGING_API_KEY` is set. If not, tell the user to run `/adup-staging:setup` first.

### 2. Fetch and write

Run this in a bash tool:

```bash
API_BASE="${ADUP_STAGING_API_BASE:-https://centralapi-staging.adup.io}"

curl -sf -H "Authorization: Bearer ${ADUP_STAGING_API_KEY}" -H "Accept: application/json" \
  "${API_BASE}/api/v1/me/skills" \
  -o /tmp/adup-me-skills.json || {
    echo "Could not reach ${API_BASE}. Check ADUP_STAGING_API_KEY, and ADUP_STAGING_API_BASE if you are on dev/staging."
    exit 1
  }

python3 <<'PY'
import json, pathlib, re, sys

with open('/tmp/adup-me-skills.json') as f:
    data = json.load(f)

skills = data.get('data', data) if isinstance(data, dict) else data
if not isinstance(skills, list):
    print('Unexpected response shape; aborting.')
    sys.exit(1)

skills_root = pathlib.Path.home() / '.claude' / 'skills'
skills_root.mkdir(parents=True, exist_ok=True)
PREFIX = 'adup-'

# Remove previously-synced skills so an uninstall in the portal removes the
# command locally too. Only ever touch directories we created: `adup-*` holding
# a SKILL.md. The bundled plugin lives elsewhere and is never touched.
removed = 0
for d in sorted(skills_root.glob(f'{PREFIX}*')):
    if d.is_dir() and (d / 'SKILL.md').is_file():
        for f in sorted(d.rglob('*'), reverse=True):
            f.unlink() if f.is_file() else f.rmdir()
        d.rmdir()
        removed += 1

written = []
for skill in skills:
    slug = skill.get('slug')
    content = skill.get('content', '')
    if not slug or not content:
        continue
    safe = re.sub(r'-+', '-', re.sub(r'[^a-z0-9-]', '-', slug.lower())).strip('-')
    if not safe:
        continue
    d = skills_root / f'{PREFIX}{safe}'
    d.mkdir(parents=True, exist_ok=True)
    (d / 'SKILL.md').write_text(content)
    written.append(f'{PREFIX}{safe}')

print(f'Removed {removed} previously-synced skill(s).')
print(f'Synced {len(written)} skill(s) into {skills_root}:')
for name in written:
    print(f'  /{name}')
PY
```

### 3. Report

List the commands that were actually written (`/adup-<slug>`, one per line — do not invent them;
use the script's output), then:

> Restart Claude Code to pick them up — a skills directory that did not exist at session start
> only becomes watchable after a restart.
>
> Note: these are local personal skills. They will **not** appear in Cowork or in cloud
> routines, which load skills from your claude.ai account instead.

## Notes

- Synced skills are per-user, at `~/.claude/skills/adup-<slug>/`. They never collide with the
  bundled plugin skills, which are namespaced `/adup-staging:<name>`.
- Re-run this any time the agency owner installs, updates or uninstalls a skill in the portal —
  the sync removes local copies of skills that are no longer returned.
- `ADUP_STAGING_API_BASE` overrides the API host for dev/staging employees; it defaults to production.
- This is a Phase-4 stop-gap. If Claude Code adds runtime skill registration, this becomes a
  no-op fallback.
