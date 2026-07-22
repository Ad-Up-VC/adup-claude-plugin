#!/usr/bin/env bash
# inspect.sh — probe a creative file and emit one JSON object on stdout.
#
# Usage: inspect.sh <file>
#
# Output: {"path", "bytes", "mime", "width", "height", "duration_s",
#          "aspect_label", "checksum", "server_will_validate"}
#
# Images:  sips (macOS) with ImageMagick `identify` fallback.
# Videos:  ffprobe when present, else width/height/duration are null and
#          "server_will_validate": true (central-api extracts metadata on upload).
#
# Portable: bash 3.2+ (macOS default), no jq required.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: inspect.sh <file>" >&2
  exit 2
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "inspect.sh: file not found: $FILE" >&2
  exit 1
fi

bytes=$(wc -c < "$FILE" | tr -d '[:space:]')
mime=$(file --brief --mime-type "$FILE" 2>/dev/null || echo "application/octet-stream")
checksum=$(shasum -a 256 "$FILE" | awk '{print $1}')

width="null"
height="null"
duration_s="null"
server_will_validate=false

case "$mime" in
  image/*)
    if command -v sips >/dev/null 2>&1; then
      width=$(sips -g pixelWidth "$FILE" 2>/dev/null | awk '/pixelWidth:/{print $2}')
      height=$(sips -g pixelHeight "$FILE" 2>/dev/null | awk '/pixelHeight:/{print $2}')
    elif command -v identify >/dev/null 2>&1; then
      dims=$(identify -format "%w %h" "${FILE}[0]" 2>/dev/null || true)
      width=$(echo "$dims" | awk '{print $1}')
      height=$(echo "$dims" | awk '{print $2}')
    else
      server_will_validate=true
    fi
    ;;
  video/*)
    if command -v ffprobe >/dev/null 2>&1; then
      dims=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=p=0:s=x "$FILE" 2>/dev/null | head -n1 || true)
      width=$(echo "$dims" | cut -dx -f1)
      height=$(echo "$dims" | cut -dx -f2)
      duration_s=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FILE" 2>/dev/null | head -n1 || true)
    else
      server_will_validate=true
    fi
    ;;
  *)
    server_will_validate=true
    ;;
esac

# Normalise empty probes to null
[ -n "${width:-}" ] && [ "$width" != "N/A" ] || width="null"
[ -n "${height:-}" ] && [ "$height" != "N/A" ] || height="null"
[ -n "${duration_s:-}" ] && [ "$duration_s" != "N/A" ] || duration_s="null"

# Map width/height to the nearest ratio token (2% tolerance), else "other"
aspect_label="null"
if [ "$width" != "null" ] && [ "$height" != "null" ]; then
  aspect_label=$(awk -v w="$width" -v h="$height" 'BEGIN {
    if (h == 0) { print "\"other\""; exit }
    r = w / h
    n = split("1x1:1.0 4x5:0.8 9x16:0.5625 16x9:1.77778 191x100:1.91", pairs, " ")
    best = "other"
    for (i = 1; i <= n; i++) {
      split(pairs[i], kv, ":")
      target = kv[2] + 0
      if (r >= target * 0.98 && r <= target * 1.02) { best = kv[1]; break }
    }
    printf "\"%s\"", best
  }')
fi

printf '{"path": "%s", "bytes": %s, "mime": "%s", "width": %s, "height": %s, "duration_s": %s, "aspect_label": %s, "checksum": "%s", "server_will_validate": %s}\n' \
  "$FILE" "$bytes" "$mime" "$width" "$height" "$duration_s" "$aspect_label" "$checksum" "$server_will_validate"
