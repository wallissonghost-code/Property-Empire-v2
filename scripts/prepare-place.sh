#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_DIR="minershaven"
SOURCE_PLACE="$UPSTREAM_DIR/minershaven.rbxl"
OUTPUT_PLACE="Mining-Empire.rbxl"
TEMP1="Mining-Empire.stage1.rbxl"
TEMP2="Mining-Empire.stage2.rbxl"
TEMP3="Mining-Empire.stage3.rbxl"
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
  echo "rbxmk is required to customize the Roblox place" >&2
  exit 1
fi

rm -f "$TEMP1" "$TEMP2" "$TEMP3" "$OUTPUT_PLACE"
rbxmk run scripts/customize-place.rbxmk.lua "$SOURCE_PLACE" "$TEMP1"
rbxmk run scripts/add-visitors.rbxmk.lua "$TEMP1" "$TEMP2"
rbxmk run scripts/fix-entry.rbxmk.lua "$TEMP2" "$TEMP3"
rbxmk run scripts/fix-safe-hud.rbxmk.lua "$TEMP3" "$OUTPUT_PLACE"
rm -f "$TEMP1" "$TEMP2" "$TEMP3"

test -f "$OUTPUT_PLACE"
echo "Prepared customized $OUTPUT_PLACE from licensed upstream $ACTUAL_UPSTREAM"
ls -lh "$OUTPUT_PLACE"
