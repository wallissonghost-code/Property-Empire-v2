#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_DIR="minershaven"
SOURCE_PLACE="$UPSTREAM_DIR/minershaven.rbxl"
OUTPUT_PLACE="Mining-Empire.rbxl"
EXPECTED_UPSTREAM="d5c8b41ca8ed9f1bd91176ec397e8dff9a259130"

if [ ! -f "$SOURCE_PLACE" ]; then
  echo "Missing upstream place: $SOURCE_PLACE" >&2
  exit 1
fi

ACTUAL_UPSTREAM=$(git -C "$UPSTREAM_DIR" rev-parse HEAD)
if [ "$ACTUAL_UPSTREAM" != "$EXPECTED_UPSTREAM" ]; then
  echo "Unexpected upstream revision: $ACTUAL_UPSTREAM" >&2
  exit 1
fi

if ! command -v rbxmk >/dev/null 2>&1; then
  echo "rbxmk is required to prepare the Roblox place" >&2
  exit 1
fi

rm -f "$OUTPUT_PLACE"
rbxmk run scripts/sterile-place.rbxmk.lua "$SOURCE_PLACE" "$OUTPUT_PLACE"

test -f "$OUTPUT_PLACE"
echo "Prepared Mining Empire sterile diagnostic place from licensed upstream $ACTUAL_UPSTREAM"
ls -lh "$OUTPUT_PLACE"
