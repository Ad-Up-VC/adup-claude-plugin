#!/usr/bin/env bash
# Rebuild adup.plugin — the distributable zip bundle of this plugin.
#
# WHY: adup.plugin is a snapshot of the whole plugin tree (skills, agents,
# .mcp.json, manifests). It was previously hand-zipped, so it silently drifted
# from the source it is supposed to mirror — shipping stale skills to users.
# Run this after ANY change to skills/, agents/, templates/, .mcp.json,
# .claude-plugin/, or the top-level docs, and commit the regenerated bundle.
#
# Usage:  bash scripts/pack.sh           # rebuild adup.plugin
#         bash scripts/pack.sh --check   # verify the committed bundle matches
#                                        # the working tree (exit 1 if stale)
#         bash scripts/pack.sh --verify  # manifest sanity checks (exit 1 on fail)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="adup.plugin"
CHECK=0
VERIFY=0
case "${1:-}" in
  --check)  CHECK=1 ;;
  --verify) VERIFY=1 ;;
  "")       ;;
  *) echo "pack: unknown option '$1' (want --check or --verify)" >&2; exit 2 ;;
esac

# ── --verify: catch the failure mode --check cannot see ─────────────────────
#
# --check proves the bundle matches the TREE. It cannot tell you the tree is
# mislabelled. A build uploaded to the desktop app was found in the wild
# declaring version 1.0.0 while carrying 21 skills (1.0.0 shipped 8) — the
# manifest version is not bumped when the bundle is rebuilt, so "1.0.0" said
# nothing about what was inside. That is exactly why a stale plugin survived a
# full QA cycle undetected on 2026-07-28: there was no signal to notice.
#
# That same build also shipped the REVERTED 9-connector .mcp.json, whose skills
# call unprefixed tool names that do not exist on the aggregated /mcp
# connector. One connector is the contract (see CLAUDE.md).
if [ "$VERIFY" = "1" ]; then
  fail=0
  note() { echo "pack --verify: $*" >&2; fail=1; }

  pv=$(python3 -c "import json;print(json.load(open('.claude-plugin/plugin.json'))['version'])")
  mv=$(python3 -c "import json;print(json.load(open('.claude-plugin/marketplace.json'))['metadata']['version'])")
  mpv=$(python3 -c "import json;d=json.load(open('.claude-plugin/marketplace.json'));print(d['plugins'][0]['version'])")

  [ "$pv" = "$mv" ]  || note "plugin.json version ($pv) != marketplace metadata version ($mv)"
  [ "$pv" = "$mpv" ] || note "plugin.json version ($pv) != marketplace plugins[0].version ($mpv)"

  servers=$(python3 -c "import json;print(len(json.load(open('.mcp.json'))['mcpServers']))")
  [ "$servers" = "1" ] || note ".mcp.json declares $servers servers — the contract is ONE aggregated connector"

  key=$(python3 -c "
import json
h=json.load(open('.mcp.json'))['mcpServers'].get('adup',{}).get('headers',{})
print(h.get('Authorization',''))")
  case "$key" in
    'Bearer ${ADUP_API_KEY}') ;;
    *) note ".mcp.json Authorization must be 'Bearer \${ADUP_API_KEY}', not a literal key (got: ${key:0:24}…)" ;;
  esac

  # The connector URL must stay environment-overridable. A hardcoded host pins
  # every install to production and is why there was no way to point the plugin
  # at dev or staging without hand-editing the shipped file. Claude Code expands
  # ${VAR:-default} in an http server's `url`, so the default keeps production
  # zero-config while ADUP_GATEWAY_BASE retargets it.
  url=$(python3 -c "
import json
print(json.load(open('.mcp.json'))['mcpServers'].get('adup',{}).get('url',''))")
  case "$url" in
    '${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/mcp') ;;
    *) note ".mcp.json url must be '\${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/mcp' (got: $url)" ;;
  esac

  # A version bump is required whenever the shipped tree changed. Compare
  # against the last tag; skip cleanly when the repo has no tags yet.
  if last_tag=$(git describe --tags --abbrev=0 2>/dev/null); then
    tag_ver="${last_tag#v}"
    if [ "$pv" = "$tag_ver" ] && ! git diff --quiet "$last_tag" -- \
        skills agents templates .mcp.json .claude-plugin 2>/dev/null; then
      note "shipped files changed since $last_tag but version is still $pv — bump it"
    fi
  fi

  [ "$fail" = "0" ] && echo "pack --verify: manifests OK (v$pv, 1 connector)"
  exit "$fail"
fi

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
