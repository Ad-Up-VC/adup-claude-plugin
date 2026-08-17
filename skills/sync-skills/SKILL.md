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

Confirm `ADUP_API_KEY` is set. If not, tell the user to run `/adup:setup` first.

### 2. Fetch and write

Run this in a bash tool:

```bash
API_BASE="${ADUP_API_BASE:-https://centralapi.adup.io}"
export SKILLS_ENDPOINT="${API_BASE}/api/v1/me/skills"

curl -sf -H "Authorization: Bearer ${ADUP_API_KEY}" -H "Accept: application/json" \
  "${API_BASE}/api/v1/me/skills" \
  -o /tmp/adup-me-skills.json || {
    echo "Could not reach ${API_BASE}. Check ADUP_API_KEY, and ADUP_API_BASE if you are on dev/staging."
    exit 1
  }

python3 <<'PY'
import json, os, pathlib, re, sys

with open('/tmp/adup-me-skills.json') as f:
    data = json.load(f)

skills = data.get('data', data) if isinstance(data, dict) else data
if not isinstance(skills, list):
    print('Unexpected response shape; aborting.')
    sys.exit(1)

source = os.environ.get('SKILLS_ENDPOINT', 'the ADUP portal')
skills_root = pathlib.Path.home() / '.claude' / 'skills'
skills_root.mkdir(parents=True, exist_ok=True)
PREFIX = 'adup-'

# Snapshot what is on disk BEFORE touching anything, so we can tell the user
# exactly which skills are new, which changed, and which are unchanged. Each
# file is EXECUTED as instructions on the next launch, and its content is authored
# in the portal (org owners can add org-private skills) — so this diff is a
# trust-boundary review, not a cosmetic log.
before = {}
for d in sorted(skills_root.glob(f'{PREFIX}*')):
    p = d / 'SKILL.md'
    if d.is_dir() and p.is_file():
        before[d.name] = p.read_text()

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

def summary_of(skill, content):
    desc = (skill.get('description') or '').strip()
    if desc:
        return desc
    for line in content.splitlines():
        s = line.strip()
        if s.startswith('#'):
            return s.lstrip('# ').strip()
    return ''

changes = []   # (name, status, chars, summary)
written, seen = [], set()
for skill in skills:
    slug = skill.get('slug')
    content = skill.get('content', '')
    if not slug or not content:
        continue
    safe = re.sub(r'-+', '-', re.sub(r'[^a-z0-9-]', '-', slug.lower())).strip('-')
    if not safe:
        continue
    name = f'{PREFIX}{safe}'
    d = skills_root / name
    d.mkdir(parents=True, exist_ok=True)
    (d / 'SKILL.md').write_text(content)
    written.append(name)
    seen.add(name)
    old = before.get(name)
    status = 'NEW' if old is None else ('CHANGED' if old != content else 'unchanged')
    changes.append((name, status, len(content), summary_of(skill, content)))

# Skills present locally but no longer returned = uninstalled in the portal.
for name in sorted(before):
    if name not in seen:
        changes.append((name, 'REMOVED', 0, '(no longer installed in the portal)'))

print(f'Source: {source}')
print(f'Synced {len(written)} skill(s) into {skills_root} (removed {removed} old dir(s) first).')
print('')
print('Review before restart — each SKILL.md below runs as instructions on next launch:')
for name, status, chars, summary in changes:
    print(f'  [{status:9}] /{name}  ({chars} chars)  {summary[:80]}')
PY
```

The script deliberately **surfaces a per-skill diff** (`NEW` / `CHANGED` / `unchanged` / `REMOVED`) instead of writing silently. These files are fetched from the portal and executed as instructions on the next launch, so a newly-added or changed skill is a trust boundary — the user should see what arrived and from where before it can run.

### 3. Report — surface the diff BEFORE the skills can run

Show the user the script's per-skill summary verbatim (`[NEW]` / `[CHANGED]` / `[unchanged]` /
`[REMOVED]` with the source endpoint), one line per skill — do not invent commands; use the
script's output. This step exists on purpose: synced files are fetched from the portal and are
**executed as instructions the next time Claude Code starts**, so the user must be able to see what
arrived and from where before it takes effect. Do not present the sync as done without showing the
list.

Then, if anything is `NEW` or `CHANGED`, explicitly call those out and offer to show the content:

> Heads up: the skills marked **NEW** / **CHANGED** were authored in your ADUP portal (your agency
> owners can add org-private skills) and will run as instructions once you restart. Want me to print
> any of them so you can review before they take effect? They live at
> `~/.claude/skills/adup-<slug>/SKILL.md`.

If the user asks, `cat` the relevant `~/.claude/skills/adup-<slug>/SKILL.md` so they can read it.
Only after the review:

> Restart Claude Code to pick them up — a skills directory that did not exist at session start
> only becomes watchable after a restart.
>
> Note: these are local personal skills. They will **not** appear in Cowork or in cloud
> routines, which load skills from your claude.ai account instead.

## Notes

- Synced skills are per-user, at `~/.claude/skills/adup-<slug>/`. They never collide with the
  bundled plugin skills, which are namespaced `/adup:<name>`.
- Re-run this any time the agency owner installs, updates or uninstalls a skill in the portal —
  the sync removes local copies of skills that are no longer returned.
- `ADUP_API_BASE` overrides the API host for dev/staging employees; it defaults to production.
- This is a Phase-4 stop-gap. If Claude Code adds runtime skill registration, this becomes a
  no-op fallback.
