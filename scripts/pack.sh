#!/usr/bin/env bash
# Rebuild adup.plugin — the distributable zip bundle of this plugin.
#
# WHY: adup.plugin is a snapshot of the whole plugin tree (skills, agents,
# .mcp.json, manifests). It was previously hand-zipped, so it silently drifted
# from the source it is supposed to mirror — shipping stale skills to users.
# Run this after ANY change to skills/, agents/, templates/, .mcp.json,
# .claude-plugin/, or the top-level docs, and commit the regenerated bundle.
#
# Usage:  bash scripts/pack.sh          # rebuild adup.plugin
#         bash scripts/pack.sh --check  # verify the committed bundle matches
#                                       # the working tree (exit 1 if stale)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="adup.plugin"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

# Everything the plugin needs at runtime. Deliberately EXCLUDES: .git, the
# bundle itself, scripts/ (build tooling), and OS cruft.
INCLUDE=(
  .claude-plugin
  .mcp.json
  .gitignore
  CLAUDE.md
  PRODUCT.md
  README.md
  install.sh
  agents
  skills
  templates
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STAGE="$TMP/pkg"
mkdir -p "$STAGE"

for item in "${INCLUDE[@]}"; do
  [ -e "$item" ] || { echo "pack: missing '$item' — aborting" >&2; exit 1; }
  cp -R "$item" "$STAGE/"
done

# Strip caches / OS noise that must never ship.
find "$STAGE" \( -name '.DS_Store' -o -name '__pycache__' -o -name '*.pyc' \) \
  -exec rm -rf {} + 2>/dev/null || true

# -X drops extended attrs; sorted input + fixed order keeps the zip reproducible.
( cd "$STAGE" && find . -type f | LC_ALL=C sort | zip -qX "$TMP/out.zip" -@ )

if [ "$CHECK" = "1" ]; then
  if [ ! -f "$OUT" ]; then
    echo "pack --check: $OUT does not exist (run: bash scripts/pack.sh)" >&2
    exit 1
  fi
  # Compare CONTENT (names + bytes), not zip metadata like timestamps.
  hash_zip() {
    python3 - "$1" <<'PY'
import hashlib, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
h = hashlib.sha256()
for n in sorted(z.namelist()):
    if n.endswith('/'):
        continue
    h.update(n.encode())
    h.update(z.read(n))
print(h.hexdigest())
PY
  }
  if [ "$(hash_zip "$OUT")" = "$(hash_zip "$TMP/out.zip")" ]; then
    echo "pack --check: $OUT is up to date"
    exit 0
  fi
  echo "pack --check: $OUT is STALE — regenerate with: bash scripts/pack.sh" >&2
  exit 1
fi

mv "$TMP/out.zip" "$OUT"
COUNT="$(python3 -c "import zipfile,sys; print(len([n for n in zipfile.ZipFile('$OUT').namelist() if not n.endswith('/')]))")"
echo "pack: wrote $OUT ($COUNT files)"
