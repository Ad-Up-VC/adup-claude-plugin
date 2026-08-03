#!/usr/bin/env bash
# Generate the internal `adup-staging` plugin tree from the production tree.
#
# WHY GENERATED, NOT FORKED: the two variants share 100% of their logic — 26
# skills, one agent, the templates. A hand-maintained copy would drift, and this
# repo has already paid for that once (a committed bundle silently diverged from
# its source and shipped stale skills, which is why pack.sh --check exists). So
# the production tree at the repo root is the single source of truth and the
# staging tree is derived from it every build. Never hand-edit the output.
#
# WHY EVERY VARIABLE IS RENAMED: both plugins can be installed at the same time.
# If they shared `ADUP_API_KEY` only one could be configured at a time; if they
# shared `ADUP_GATEWAY_BASE` / `ADUP_API_BASE`, a user pointing production
# somewhere would silently repoint staging too. Full isolation is the whole
# point of a separate artifact, so all three get the STAGING_ prefix.
#
# Usage: make-staging.sh <src-dir> <dest-dir>
set -euo pipefail

SRC="${1:?usage: make-staging.sh <src-dir> <dest-dir>}"
DEST="${2:?usage: make-staging.sh <src-dir> <dest-dir>}"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

# ── Substitutions ───────────────────────────────────────────────────────────
# Applied to every text file. Order matters only in that the longer, more
# specific tokens are listed first so a shorter one cannot eat their prefix.
#
#   ADUP_API_KEY   -> ADUP_STAGING_API_KEY      (credential, per environment)
#   ADUP_API_BASE  -> ADUP_STAGING_API_BASE     (central-api override)
#   ADUP_GATEWAY_BASE -> ADUP_STAGING_GATEWAY_BASE (connector override)
#   gateway.adup.io    -> gateway-staging.adup.io
#   centralapi.adup.io -> centralapi-staging.adup.io
#   /adup:<cmd>        -> /adup-staging:<cmd>
#
# NOTE `/adup-` (e.g. the `/adup-<slug>` org-skill commands sync-skills writes)
# is deliberately NOT matched — the pattern requires the colon.
while IFS= read -r -d '' f; do
  case "$f" in *.png|*.jpg|*.gif|*.zip|*.plugin) continue ;; esac
  perl -0pi -e '
    s/\bADUP_API_KEY\b/ADUP_STAGING_API_KEY/g;
    s/\bADUP_API_BASE\b/ADUP_STAGING_API_BASE/g;
    s/\bADUP_GATEWAY_BASE\b/ADUP_STAGING_GATEWAY_BASE/g;
    s{https://gateway\.adup\.io}{https://gateway-staging.adup.io}g;
    s{https://centralapi\.adup\.io}{https://centralapi-staging.adup.io}g;
    s{/adup:}{/adup-staging:}g;
  ' "$f"
done < <(find "$DEST" -type f -print0)

# ── Manifests ───────────────────────────────────────────────────────────────
python3 - "$DEST" <<'PY'
import json, sys, pathlib
dest = pathlib.Path(sys.argv[1])

p = dest / ".claude-plugin" / "plugin.json"
d = json.loads(p.read_text())
d["name"] = "adup-staging"
d["description"] = (
    "ADUP against the STAGING environment — same skills as the production `adup` "
    "plugin, pointed at gateway-staging.adup.io and centralapi-staging.adup.io. "
    "For ADUP staff testing before a release. Needs a STAGING employee key in "
    "ADUP_STAGING_API_KEY; a production key will not authenticate."
)
p.write_text(json.dumps(d, indent=2) + "\n")

# A plugin SOURCE DIRECTORY must not carry a marketplace.json — that file
# describes a marketplace, and the root one already lists this plugin. Leaving a
# nested copy here would put a second marketplace in the repo.
m = dest / ".claude-plugin" / "marketplace.json"
if m.exists():
    m.unlink()
PY

# ── Overlay: setup's environment CHOICE makes no sense in this variant ─────
# Substitution alone leaves step 2b claiming "production" maps to the staging
# hosts, and leaves a dev row that would let someone repoint the staging plugin
# at dev — which defeats the entire reason this artifact exists. Replace the
# whole section with a fixed statement.
python3 - "$DEST/skills/setup/SKILL.md" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
t = p.read_text()

replacement = """### 2b. Environment — fixed, nothing to choose

**This plugin IS the staging environment.** There is no environment question to ask and no
environment variable for the user to pick. The connector and every skill already default to:

| | |
|---|---|
| gateway | `https://gateway-staging.adup.io` |
| central-api | `https://centralapi-staging.adup.io` |

Do not offer production or dev. Someone who needs production installs the separate `adup` plugin —
both can be installed at once, and the command prefix (`/adup:` vs `/adup-staging:`) is what
selects the environment.

The key must be a **staging** employee key, minted in the staging portal. A production or dev key
returns `invalid_token` here; that is the isolation working, not a fault.

"""

m = re.search(r'^### 2b\..*?(?=^### 3\.)', t, re.S | re.M)
if m:
    t = t[:m.start()] + replacement + t[m.end():]
    p.write_text(t)
else:
    raise SystemExit("make-staging: could not find setup step 2b to replace — "
                     "the production skill changed shape; update this overlay")
PY

# ── Strip the multi-environment scaffolding ────────────────────────────────
# The production plugin supports three environments, so it carries env tables,
# alternative export blocks and a "which env is my key from?" probe loop. None
# of that survives substitution sensibly (it ends up listing the staging hosts
# under a "production" label), and worse, the dev rows on kodeia.com are a live
# footgun: they would let someone repoint THIS plugin at dev, defeating the
# isolation the separate artifact exists to provide.
python3 - "$DEST" <<'PY'
import pathlib, re, sys
dest = pathlib.Path(sys.argv[1])

# NOTE: every pattern here is LINE-BOUNDED (`[^\n]*`, never `.*` with DOTALL).
# With re.S a greedy `.*\n` swallows the rest of the file, which silently ate
# ~33k characters the first time this was written — including the block the
# next substitution needed. Keep the character classes explicit.
def sub(rel, pattern, replacement):
    p = dest / rel
    if not p.exists():
        return
    t = p.read_text()
    new, n = re.subn(pattern, replacement, t, flags=re.M)
    if n == 0:
        raise SystemExit(f"make-staging: no match stripping env scaffolding in {rel} — "
                         "the production file changed shape; update this overlay")
    p.write_text(new)

# connect: the "which environment am I on?" table collapses to one row.
sub("skills/connect/SKILL.md",
    r'\| `ADUP_STAGING_GATEWAY_BASE` \| environment \|\n\|---\|---\|\n(?:\|[^\n]*\n)+',
    "| `ADUP_STAGING_GATEWAY_BASE` | environment |\n|---|---|\n"
    "| `https://gateway-staging.adup.io` *(or unset)* | **staging** — the only one this plugin serves |\n")

# setup: drop the alternative ADUP_VARS lines; there is only one environment.
sub("skills/setup/SKILL.md",
    r'\n# Staging / dev — REPLACE the line above[^\n]*\n(?:# ADUP_VARS=[^\n]*\n)+',
    "\n")

# setup: the multi-environment key probe becomes a single staging check.
sub("skills/setup/SKILL.md",
    r'^for BASE in https://[^\n]*\n(?:[^\n]*\n)*?done\n',
    'curl -s -o /dev/null -w \'%{http_code}\\n\' '
    '"https://centralapi-staging.adup.io/api/v1/me" '
    '-H "Authorization: Bearer $ADUP_STAGING_API_KEY"   # 200 = a staging key\n')

# README: only the staging export block is meaningful here.
sub("README.md",
    r'\n# staging\n(?:export [^\n]*\n)+\n# dev\n(?:export [^\n]*\n)+',
    "\n")

# CLAUDE.md carries the three-environment matrix — meaningless in this variant.
sub("CLAUDE.md",
    r'^\| dev \| `https://gateway\.kodeia\.com`[^\n]*\n', "")
sub("CLAUDE.md",
    r'^`gateway\.kodeia\.com` is \*\*dev\*\*[^\n]*\n', "")
PY

# ── Banner so nobody mistakes a staging run for production ──────────────────
# Prepended to the two skills a user meets first.
for s in connect setup; do
  f="$DEST/skills/$s/SKILL.md"
  [ -f "$f" ] || continue
  python3 - "$f" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
banner = (
    "\n> ## ⚠️ STAGING\n"
    "> This is the **internal staging** plugin. Every tool call, report and proposal\n"
    "> goes to the STAGING environment — never to production or to a real client.\n"
    "> It needs a **staging** employee key in `ADUP_STAGING_API_KEY`; a production\n"
    "> key will return `invalid_token`.\n"
)
# insert immediately after the YAML frontmatter
m = re.match(r'^(---\n.*?\n---\n)', t, re.S)
p.write_text((m.group(1) + banner + t[m.end():]) if m else (banner + t))
PY
done

echo "make-staging: generated $DEST"
