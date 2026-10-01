#!/usr/bin/env bash
# Rebuild adup.plugin — the distributable zip bundle of this plugin.
#
# WHY: adup.plugin is a snapshot of the whole plugin tree (skills, agents,
# .mcp.json, manifests). It was previously hand-zipped, so it silently drifted
# from the source it is supposed to mirror — shipping stale skills to users.
# Run this after ANY change to skills/, agents/, templates/, .mcp.json,
# .claude-plugin/, or the top-level docs, and commit the regenerated bundle.
#
# Usage:  bash scripts/pack.sh           # rebuild the bundle
#         bash scripts/pack.sh --check   # verify the committed bundle matches
#                                        # the working tree (exit 1 if stale)
#         bash scripts/pack.sh --verify  # manifest checks
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="adup.plugin"
CHECK=0
VERIFY=0

# Everything the plugin needs at runtime. Deliberately EXCLUDES: .git, the
# bundle itself, scripts/ (build tooling), and OS cruft.
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

  # v2.0.0 — the connector authenticates with OAuth 2.0: Claude Code runs the
  # MCP authorization flow against the gateway and keeps the tokens in the OS
  # keychain (TARA_PLUGIN_OAUTH2_PLAN.md WS5). A static Authorization header
  # DISABLES that flow for the whole entry, so the connector must carry NO
  # headers at all — and no `oauth` block either: dynamic client registration
  # against the gateway is the contract, a pinned client id / callback port is
  # not (a fixed port collides on user machines for nothing).
  python3 - <<'PY' || note ".mcp.json adup connector must be header-less (OAuth sign-in): no 'headers' and no 'oauth' keys"
import json, sys
c = json.load(open('.mcp.json'))['mcpServers'].get('adup', {})
sys.exit(0 if 'headers' not in c and 'oauth' not in c else 1)
PY

  # ...and the old key field must be gone, or Claude Code keeps prompting for
  # a key that nothing reads.
  python3 - <<'PY' || note "plugin.json must not declare userConfig.ADUP_API_KEY any more (OAuth sign-in replaced it)"
import json, sys
uc = json.load(open('.claude-plugin/plugin.json')).get('userConfig') or {}
sys.exit(1 if 'ADUP_API_KEY' in uc else 0)
PY

  # ...and no skill or script may authenticate with a raw key: every direct
  # central-api call became a gateway tool (plan WS4). A reintroduced
  # `Bearer $ADUP_API_KEY` would silently fail on every OAuth install.
  if grep -rnE 'Bearer \$\{?ADUP_API_KEY' skills install.sh --exclude=pack.sh 2>/dev/null; then
    note "a skill or script still authenticates with \$ADUP_API_KEY — use the gateway tools instead (plan WS4)"
  fi

  # The connector URL must be a LITERAL https URL.
  #
  # It used to be `${ADUP_GATEWAY_BASE:-https://gateway.adup.io}/mcp` so the
  # environment could be retargeted. That expansion is a Claude Code CLI feature
  # only: the claude.ai / desktop connector layer takes the string verbatim, and
  # its own validator then rejects it ("URL must start with 'https'"), so the
  # connector could not be added at all on those surfaces. Any shell-style
  # placeholder here reintroduces that bug — hence the exact-match.
  #
  # The cost is that dev/staging can no longer be reached by exporting a
  # variable; build a variant plugin or add a custom connector by hand instead.
  url=$(python3 -c "
import json
print(json.load(open('.mcp.json'))['mcpServers'].get('adup',{}).get('url',''))")
  case "$url" in
    'https://gateway.adup.io/mcp') ;;
    *) note ".mcp.json url must be the literal 'https://gateway.adup.io/mcp' (got: $url)" ;;
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

  # The root marketplace is the PUBLIC distribution channel: adding this repo as a
  # marketplace resolves it and offers every plugin it lists to whoever added it —
  # customers included. So it must list production and ONLY production.
  python3 - <<'PY' || note "root marketplace must list adup -> ./ and nothing else"
import json, sys
d = json.load(open('.claude-plugin/marketplace.json'))
by = {p['name']: p for p in d['plugins']}
sys.exit(0 if list(by) == ['adup'] and by['adup'].get('source') == './' else 1)
PY

  [ "$fail" = "0" ] && echo "pack --verify: manifests OK (v$pv, 1 header-less OAuth connector)"
  exit "$fail"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STAGE="$TMP/pkg"
stage "$STAGE"

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
  stale=0
  [ "$(hash_zip "$OUT")" = "$(hash_zip "$TMP/out.zip")" ] || {
    echo "pack --check: $OUT is STALE — regenerate with: bash scripts/pack.sh" >&2; stale=1; }
  [ "$stale" = "0" ] && echo "pack --check: $OUT is up to date"
  exit "$stale"
fi

mv "$TMP/out.zip" "$OUT"
count_zip() { python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('$1').namelist() if not n.endswith('/')]))"; }
echo "pack: wrote $OUT ($(count_zip "$OUT") files)"
