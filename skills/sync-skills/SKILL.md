---
name: sync-skills
description: Fetch the skills your agency has installed in the ADUP portal and write them to your local Claude skills directory. Run this after your agency owner installs or updates skills in the portal so they become available as /adup commands in your next Claude session.
---

# Sync ADUP Skills

Fetch the latest org-installed and org-private skills from Central API and write them to `~/.claude/skills/` so Claude can find them on next session start.

## Steps

### 1. Check API key

Confirm `ADUP_API_KEY` is set. If not, tell the user to run `/adup:setup` first.

### 2. Fetch skills from Central API

Run this in a bash tool:

```bash
mkdir -p ~/.claude/skills/adup-org
curl -sf -H "Authorization: Bearer ${ADUP_API_KEY}" \
  "https://centralapi.adup.io/api/v1/me/skills" \
  -o /tmp/adup-me-skills.json

# Parse and write each skill to its own SKILL.md
python3 <<'PY'
import json, os, pathlib, re, sys

with open('/tmp/adup-me-skills.json') as f:
    data = json.load(f)

skills = data.get('data', data) if isinstance(data, dict) else data
if not isinstance(skills, list):
    print('Unexpected response shape; aborting.')
    sys.exit(1)

base = pathlib.Path.home() / '.claude' / 'skills' / 'adup-org'
base.mkdir(parents=True, exist_ok=True)

# Remove any previously-synced skills to keep the dir clean
for sub in base.iterdir():
    if sub.is_dir():
        for f in sub.iterdir():
            f.unlink()
        sub.rmdir()

count = 0
for skill in skills:
    slug = skill.get('slug')
    content = skill.get('content', '')
    if not slug or not content:
        continue
    safe_slug = re.sub(r'[^a-z0-9-]', '-', slug.lower())
    skill_dir = base / safe_slug
    skill_dir.mkdir(parents=True, exist_ok=True)
    (skill_dir / 'SKILL.md').write_text(content)
    count += 1

print(f'Synced {count} skills to {base}')
PY
```

### 3. Tell the user to restart

> Synced N skills to ~/.claude/skills/adup-org/. Restart Claude Code to pick them up. Then they'll be available as /adup-org:{slug} commands.

## Notes

- The synced skills live under `~/.claude/skills/adup-org/` (per-user) — they don't conflict with the bundled `adup` plugin skills.
- This sync should be re-run any time the agency owner installs/uninstalls/updates a skill in the portal.
- This is a stop-gap for Phase 4. Future Claude Code releases may support runtime skill registration; if they do, this skill becomes a no-op fallback.
