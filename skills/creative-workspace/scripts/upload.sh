#!/usr/bin/env bash
# upload.sh — PUT a local creative file to a presigned upload URL.
#
# Credential-free (plugin v2.0.0): the URL comes from the `create_creative_upload`
# connector tool and carries its own short-lived signature, so this script
# needs no ADUP credential at all. The full flow is:
#
#   1. bash inspect.sh <file>              → bytes, mime, checksum (sha256)
#   2. find_creative_asset(shop_slug, checksum_sha256)
#        found → reuse the asset, stop here
#   3. create_creative_upload(shop_slug, filename, mime_type, size_bytes, checksum_sha256)
#        deduplicated → reuse the returned asset, stop here
#        otherwise    → upload.url (+ upload.headers), valid ~15 minutes
#   4. bash upload.sh <file> "<upload.url>" [content_type]      ← THIS SCRIPT
#   5. finalize_creative_upload(shop_slug, checksum_sha256, filename, mime_type, tags)
#        the server recomputes the sha256 and stores the asset
#
# Usage: upload.sh <file> "<upload_url>" [content_type]
#   e.g. upload.sh assets/summer-sale/hero_1x1.jpg "https://….digitaloceanspaces.com/…?X-Amz-Signature=…" image/jpeg
#
# Exit: 0 on 2xx; 1 with a message on stderr otherwise (the presigned URL may
# have expired — call create_creative_upload again). Prints the HTTP status.
# NOTE: this only stores the file on ADUP infrastructure. Nothing reaches any
# ad platform until a proposal is approved in the portal.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: upload.sh <file> \"<upload_url>\" [content_type]" >&2
  exit 2
fi

FILE="$1"
URL="$2"
MIME="${3:-}"

if [ ! -f "$FILE" ]; then
  echo "upload.sh: file not found: $FILE" >&2
  exit 1
fi

case "$URL" in
  https://*) ;;
  *) echo "upload.sh: the upload URL must be https (got: ${URL:0:40}…)" >&2; exit 2 ;;
esac

if [ -z "$MIME" ]; then
  MIME=$(file --brief --mime-type "$FILE" 2>/dev/null || echo "application/octet-stream")
fi

http_code=$(curl -sS -o /dev/null -w '%{http_code}' \
  -X PUT -T "$FILE" \
  -H "Content-Type: $MIME" \
  "$URL") || {
  echo "upload.sh: PUT failed (network error)" >&2
  exit 1
}

case "$http_code" in
  2??)
    echo "$http_code"
    exit 0
    ;;
  403)
    echo "upload.sh: PUT rejected (HTTP 403) — the presigned URL expired or the Content-Type differs from the one declared to create_creative_upload; request a new URL." >&2
    exit 1
    ;;
  *)
    echo "upload.sh: PUT failed (HTTP $http_code)" >&2
    exit 1
    ;;
esac
