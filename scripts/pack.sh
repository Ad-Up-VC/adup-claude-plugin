#!/usr/bin/env bash
# Rebuild adup.plugin — the distributable zip bundle of this plugin.
#
# WHY: adup.plugin is a snapshot of the whole plugin tree (skills, agents,
# .mcp.json, manifests). It was previously hand-zipped, so it silently drifted
# from the source it is supposed to mirror — shipping stale skills to users.
# Run this after ANY change to skills/, agents/, templates/, .mcp.json,
# .claude-plugin/, or the top-level docs, and commit the regenerated bundle.
#
# It ALSO builds adup-staging.plugin + ./adup-staging/ — the staging variant, GENERATED
# from this same tree by scripts/make-staging.sh (never hand-maintained; see the
# rationale in that file). Both bundles are committed.
#
# Usage:  bash scripts/pack.sh           # rebuild BOTH bundles
#         bash scripts/pack.sh --check   # verify the committed bundles match
#                                        # the working tree (exit 1 if stale)
#         bash scripts/pack.sh --verify  # manifest + staging-leak checks
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="adup.plugin"
STAGING_OUT="adup-staging.plugin"
CHECK=0
VERIFY=0

# Everything the plugin needs at runtime. Deliberately EXCLUDES: .git, the
# bundles themselves, scripts/ (build tooling), and OS cruft.
# Defined up here because --verify stages the same set: checking the raw repo
# instead would flag scripts/pack.sh (which legitimately names the production
# host in its own assertions) and .git contents as "leaks".
INCLUDE=(
  .claude-plugin
  .mcp.json
  .gitignore
  CLAUDE.md
  PRODUCT.md
  README.md
  USAGE.md
  install.sh
  agents
  skills
  templates
)

# stage <dest> — copy the shipped file set, stripped of caches/OS noise.
stage() {
  local dest="$1"
  mkdir -p "$dest"
  local item
  for item in "${INCLUDE[@]}"; do
    [ -e "$item" ] || { echo "pack: missing '$item' — aborting" >&2; exit 1; }
    cp -R "$item" "$dest/"
  done
  find "$dest" \( -name '.DS_Store' -o -name '__pycache__' -o -name '*.pyc' \) \
    -exec rm -rf {} + 2>/dev/null || true
}
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

  # ── Staging variant ──────────────────────────────────────────────────────
  # THE critical check: a bundle labelled "staging" that still contains a
  # production host would silently read and WRITE against production. That is
  # the worst outcome this variant can produce, so a leak is a hard failure,
  # never a warning.
  STG_TMP="$(mktemp -d)"
  stage "$STG_TMP/prod"
  bash scripts/make-staging.sh "$STG_TMP/prod" "$STG_TMP/pkg" >/dev/null

  leaks=$(grep -rlE 'https://(gateway|centralapi)\.adup\.io' "$STG_TMP/pkg" 2>/dev/null | sed "s|$STG_TMP/pkg/||" || true)
  if [ -n "$leaks" ]; then
    note "STAGING BUNDLE LEAKS PRODUCTION HOSTS in:"
    echo "$leaks" | sed 's/^/    /' >&2
  fi

  # Dev hosts are the same class of hazard: a `kodeia.com` example left in the
  # staging bundle is a copy-pasteable way to repoint this plugin at dev, which
  # defeats the isolation the separate artifact exists to give.
  devleaks=$(grep -rl 'kodeia\.com' "$STG_TMP/pkg" 2>/dev/null | sed "s|$STG_TMP/pkg/||" || true)
  if [ -n "$devleaks" ]; then
    note "staging bundle references DEV hosts (kodeia.com) in:"
    echo "$devleaks" | sed 's/^/    /' >&2
  fi

  varleaks=$(grep -rlE '\$\{?ADUP_(API_KEY|API_BASE|GATEWAY_BASE)\b' "$STG_TMP/pkg" 2>/dev/null | sed "s|$STG_TMP/pkg/||" || true)
  if [ -n "$varleaks" ]; then
    note "staging bundle uses PRODUCTION variable names (must be ADUP_STAGING_*) in:"
    echo "$varleaks" | sed 's/^/    /' >&2
  fi

  sname=$(python3 -c "import json;print(json.load(open('$STG_TMP/pkg/.claude-plugin/plugin.json'))['name'])")
  [ "$sname" = "adup-staging" ] || note "staging plugin.json name is '$sname', expected 'adup-staging'"

  sver=$(python3 -c "import json;print(json.load(open('$STG_TMP/pkg/.claude-plugin/plugin.json'))['version'])")
  [ "$sver" = "$pv" ] || note "staging version ($sver) != production version ($pv) — they are the same code"

  # A plugin SOURCE DIR must not carry a marketplace.json — the root marketplace
  # already lists this plugin, and a nested copy is a second marketplace.
  [ ! -f "$STG_TMP/pkg/.claude-plugin/marketplace.json" ] \
    || note "staging tree contains .claude-plugin/marketplace.json — a plugin source dir must not"

  # The root marketplace must list BOTH plugins, and staging must resolve to the
  # committed generated tree (that is what makes it installable like production).
  python3 - <<'PY' || note "root marketplace does not list adup + adup-staging correctly"
import json, sys
d = json.load(open('.claude-plugin/marketplace.json'))
by = {p['name']: p for p in d['plugins']}
sys.exit(0 if by.get('adup', {}).get('source') == './'
         and by.get('adup-staging', {}).get('source') == './adup-staging' else 1)
PY

  # Parity: the variant must be a substitution of production, not a fork.
  pskills=$(ls skills | wc -l | tr -d ' ')
  sskills=$(ls "$STG_TMP/pkg/skills" | wc -l | tr -d ' ')
  [ "$pskills" = "$sskills" ] || note "skill count drift: production $pskills vs staging $sskills"

  surl=$(python3 -c "
import json
print(json.load(open('$STG_TMP/pkg/.mcp.json'))['mcpServers'].get('adup',{}).get('url',''))")
  case "$surl" in
    '${ADUP_STAGING_GATEWAY_BASE:-https://gateway-staging.adup.io}/mcp') ;;
    *) note "staging .mcp.json url is '$surl'" ;;
  esac
  rm -rf "$STG_TMP"

  [ "$fail" = "0" ] && echo "pack --verify: manifests OK (v$pv, 1 connector) + staging variant clean"
  exit "$fail"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STAGE="$TMP/pkg"
stage "$STAGE"

# -X drops extended attrs; sorted input + fixed order keeps the zip reproducible.
( cd "$STAGE" && find . -type f | LC_ALL=C sort | zip -qX "$TMP/out.zip" -@ )

# ── Staging variant, derived from the SAME staged tree ─────────────────────
# Built from $STAGE (post-INCLUDE, post-cruft-strip) so the two bundles cannot
# disagree about which files ship.
SSTAGE="$TMP/pkg-staging"
bash scripts/make-staging.sh "$STAGE" "$SSTAGE" >/dev/null
( cd "$SSTAGE" && find . -type f | LC_ALL=C sort | zip -qX "$TMP/out-staging.zip" -@ )

# The generated tree is ALSO committed at ./adup-staging so the root
# marketplace can resolve `"source": "./adup-staging"` — that is what makes the
# staging plugin installable the same way production is, rather than
# hand-unpacked from a bundle. It is generated output: never hand-edit it,
# `--check` fails if it drifts from what make-staging.sh produces.
STAGING_DIR="adup-staging"

if [ "$CHECK" = "1" ]; then
  if [ ! -f "$OUT" ]; then
    echo "pack --check: $OUT does not exist (run: bash scripts/pack.sh)" >&2
    exit 1
  fi
  if [ ! -f "$STAGING_OUT" ]; then
    echo "pack --check: $STAGING_OUT does not exist (run: bash scripts/pack.sh)" >&2
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
  stale=0
  [ "$(hash_zip "$OUT")" = "$(hash_zip "$TMP/out.zip")" ] || {
    echo "pack --check: $OUT is STALE — regenerate with: bash scripts/pack.sh" >&2; stale=1; }
  [ "$(hash_zip "$STAGING_OUT")" = "$(hash_zip "$TMP/out-staging.zip")" ] || {
    echo "pack --check: $STAGING_OUT is STALE — regenerate with: bash scripts/pack.sh" >&2; stale=1; }
  # The committed source dir must match too — it is what the marketplace installs.
  if ! diff -rq "$SSTAGE" "$STAGING_DIR" >/dev/null 2>&1; then
    echo "pack --check: ./$STAGING_DIR is STALE or hand-edited — regenerate with: bash scripts/pack.sh" >&2
    diff -rq "$SSTAGE" "$STAGING_DIR" 2>&1 | head -5 | sed 's/^/    /' >&2
    stale=1
  fi
  [ "$stale" = "0" ] && echo "pack --check: $OUT, $STAGING_OUT and ./$STAGING_DIR are up to date"
  exit "$stale"
fi

mv "$TMP/out.zip" "$OUT"
mv "$TMP/out-staging.zip" "$STAGING_OUT"
rm -rf "$STAGING_DIR" && cp -R "$SSTAGE" "$STAGING_DIR"
count_zip() { python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('$1').namelist() if not n.endswith('/')]))"; }
echo "pack: wrote $OUT ($(count_zip "$OUT") files)"
echo "pack: wrote $STAGING_OUT ($(count_zip "$STAGING_OUT") files, staging variant)"
