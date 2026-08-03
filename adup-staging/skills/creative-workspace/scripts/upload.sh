#!/usr/bin/env bash
# upload.sh — upload a creative file to the ADUP creative asset service.
#
# Usage: upload.sh <api_base> <shop_slug> <file> [tags-csv]
#   e.g. upload.sh "https://centralapi-staging.adup.io" acme-nl assets/summer-sale/hero_1x1.jpg "summer-sale,hero"
#
# Auth: requires ADUP_STAGING_API_KEY in the environment (personal employee key, emp_...).
#
# Behaviour:
#   1. Computes sha256 of the file.
#   2. GET  {api_base}/api/v1/shops/{slug}/creative-assets?checksum={sha256}
#      — if the asset already exists, prints its JSON (with "deduplicated": true)
#        and exits 0 WITHOUT uploading again.
#   3. POST {api_base}/api/v1/shops/{slug}/creative-assets (multipart: file, tags[])
#      and prints the response JSON.
#
# Exit: 0 on success/dedup-skip; non-zero with a message on stderr on 4xx/5xx.
# NOTE: this only stores the file on ADUP infrastructure (DO Spaces). Nothing
# reaches any ad platform until a proposal is approved in the portal.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: upload.sh <api_base> <shop_slug> <file> [tags-csv]" >&2
  exit 2
fi

API_BASE="${1%/}"
SHOP_SLUG="$2"
FILE="$3"
TAGS_CSV="${4:-}"

: "${ADUP_STAGING_API_KEY:?upload.sh: ADUP_STAGING_API_KEY must be set (your personal ADUP employee key)}"

if [ ! -f "$FILE" ]; then
  echo "upload.sh: file not found: $FILE" >&2
  exit 1
fi

CHECKSUM=$(shasum -a 256 "$FILE" | awk '{print $1}')
BASE_URL="$API_BASE/api/v1/shops/$SHOP_SLUG/creative-assets"

# ── 1. Idempotency check ─────────────────────────────────────────────────────
existing=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer $ADUP_STAGING_API_KEY" \
  -H "Accept: application/json" \
  "$BASE_URL?checksum=$CHECKSUM" || true)
existing_code=$(echo "$existing" | tail -n1)
existing_body=$(echo "$existing" | sed '$d')

if [ "$existing_code" = "200" ] && [ -n "$existing_body" ]; then
  hit=$(printf '%s' "$existing_body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
data = d.get("data")
if isinstance(data, list) and data:
    asset = data[0]
elif isinstance(data, dict) and data.get("id"):
    asset = data
else:
    sys.exit(0)
print(json.dumps({"data": asset, "deduplicated": True, "skipped_upload": True}))
' || true)
  if [ -n "$hit" ]; then
    printf '%s\n' "$hit"
    exit 0
  fi
fi

# ── 2. Multipart upload ──────────────────────────────────────────────────────
tag_args=()
if [ -n "$TAGS_CSV" ]; then
  OLD_IFS="$IFS"; IFS=','
  for t in $TAGS_CSV; do
    t=$(echo "$t" | sed 's/^ *//;s/ *$//')
    [ -n "$t" ] && tag_args+=(-F "tags[]=$t")
  done
  IFS="$OLD_IFS"
fi

response=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer $ADUP_STAGING_API_KEY" \
  -H "Accept: application/json" \
  -F "file=@$FILE" \
  ${tag_args[@]+"${tag_args[@]}"} \
  "$BASE_URL")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

case "$http_code" in
  200|201)
    printf '%s\n' "$body"
    exit 0
    ;;
  422)
    echo "upload.sh: rejected by server (HTTP 422 — bad mime type or file too large; 100MB cap): $body" >&2
    exit 1
    ;;
  401|403)
    echo "upload.sh: authentication/permission error (HTTP $http_code). Check ADUP_STAGING_API_KEY and shop access: $body" >&2
    exit 1
    ;;
  *)
    echo "upload.sh: upload failed (HTTP $http_code): $body" >&2
    exit 1
    ;;
esac
