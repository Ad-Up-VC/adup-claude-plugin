#!/usr/bin/env bash
# Sync templates/REPORT-CONTRACT.md and templates/REPORT-DESIGN-GUIDE.md from
# central-api, which owns the canonical copies.
#
# WHY: the report contract and design guide are served to skills by the
# get_report_template tool (report_contract, report_design_guide). The copies in
# templates/ are only a fallback for a gateway that does not serve them yet, so
# they must stay byte-identical to the central-api files. Run this before every
# release; --check tells you whether they drifted.
#
# Usage:  bash scripts/sync-report-contract.sh [--check] [--ref <git-ref>] [<central-api-dir>]
#
#   <central-api-dir>  a central-api checkout. Falls back to CENTRAL_API_DIR.
#   --ref <git-ref>    read the files from that ref (e.g. origin/development)
#                      with git show, so nothing has to be checked out. Without
#                      it the working tree of the checkout is read.
#   --check            compare only: exit 0 when both copies are identical,
#                      exit 1 naming each file that differs. Writes nothing.
#
# Exit codes: 0 in sync (or synced), 1 --check found a difference, 2 usage or
# source error.
#
# The source files are located by name (report-contract.md,
# report-design-guide.md), so the script does not depend on where they live
# inside central-api. Each name must match exactly one file.
set -euo pipefail

CHECK=0
REF=""
SRC_DIR="${CENTRAL_API_DIR:-}"

usage() {
  echo "Usage: bash scripts/sync-report-contract.sh [--check] [--ref <git-ref>] [<central-api-dir>]" >&2
  echo "       (the directory may also come from CENTRAL_API_DIR)" >&2
  exit 2
}
die() {
  echo "sync-report-contract: $*" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1 ;;
    --ref)
      [ $# -ge 2 ] || die "--ref needs a git ref"
      REF="$2"
      shift
      ;;
    --ref=*) REF="${1#--ref=}" ;;
    -h|--help) usage ;;
    -*) die "unknown option: $1" ;;
    *) SRC_DIR="$1" ;;
  esac
  shift
done

[ -n "$SRC_DIR" ] || die "no central-api checkout given (pass a directory or set CENTRAL_API_DIR)"
[ -d "$SRC_DIR" ] || die "not a directory: $SRC_DIR"

# The plugin root is the parent of this script directory.
case "${BASH_SOURCE[0]}" in
  */*) SCRIPT_DIR="${BASH_SOURCE[0]%/*}" ;;
  *) SCRIPT_DIR="." ;;
esac
ORIG_DIR="$PWD"
cd "$SRC_DIR"
SRC_DIR="$PWD"
cd "$ORIG_DIR"
cd "$SCRIPT_DIR/.."
ROOT="$PWD"

LABEL_REF=""
if [ -n "$REF" ]; then
  git -C "$SRC_DIR" rev-parse --verify --quiet "$REF^{commit}" >/dev/null \
    || die "not a commit in $SRC_DIR (fetch first?): $REF"
  LABEL_REF=" at $REF"
fi

TMP=$(mktemp -d)
cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

# Every tracked file in the source (or, outside git, every file), one per line.
if [ -n "$REF" ]; then
  git -C "$SRC_DIR" ls-tree -r --name-only "$REF" > "$TMP/candidates"
elif git -C "$SRC_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  git -C "$SRC_DIR" ls-files > "$TMP/candidates"
else
  cd "$SRC_DIR"
  find . -type f -not -path "*/.git/*" -not -path "*/vendor/*" \
    -not -path "*/node_modules/*" > "$TMP/candidates"
  cd "$ROOT"
fi

# locate <name>: set LOCATED to the one source path whose file name is <name>.
LOCATED=""
locate() {
  local name="$1" path count=0
  LOCATED=""
  while IFS= read -r path; do
    case "/$path" in
      */"$name")
        LOCATED="${path#./}"
        count=$((count + 1))
        ;;
    esac
  done < "$TMP/candidates"
  [ "$count" -eq 1 ] || die "expected exactly one $name in $SRC_DIR$LABEL_REF, found $count"
}

# emit <path>: write the exact bytes of the source file to stdout.
emit() {
  if [ -n "$REF" ]; then
    git -C "$SRC_DIR" show "$REF:$1"
  else
    cat "$SRC_DIR/$1"
  fi
}

differs=0
for name in report-contract.md report-design-guide.md; do
  case "$name" in
    report-contract.md) target="templates/REPORT-CONTRACT.md" ;;
    report-design-guide.md) target="templates/REPORT-DESIGN-GUIDE.md" ;;
  esac
  locate "$name"
  emit "$LOCATED" > "$TMP/$name"
  if cmp -s "$TMP/$name" "$ROOT/$target"; then
    echo "sync-report-contract: $target is identical to central-api $LOCATED$LABEL_REF"
  elif [ "$CHECK" = "1" ]; then
    echo "sync-report-contract: $target differs from central-api $LOCATED$LABEL_REF" >&2
    differs=1
  else
    cp "$TMP/$name" "$ROOT/$target"
    echo "sync-report-contract: updated $target from central-api $LOCATED$LABEL_REF"
  fi
done

if [ "$differs" = "1" ]; then
  echo "sync-report-contract: run without --check to copy the central-api version, then rebuild with scripts/pack.sh" >&2
  exit 1
fi
exit 0
