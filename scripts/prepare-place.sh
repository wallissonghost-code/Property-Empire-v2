#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PLACE="Mining-Empire.rbxl"

if ! command -v rbxmk >/dev/null 2>&1; then
  echo "rbxmk is required to prepare the Roblox place" >&2
  exit 1
fi

test -f scripts/current-place.rbxmk.lua
rm -f "$OUTPUT_PLACE"
rbxmk run scripts/current-place.rbxmk.lua "$OUTPUT_PLACE"

test -s "$OUTPUT_PLACE"
echo "Prepared brand-new Mining Empire place from scratch"
ls -lh "$OUTPUT_PLACE"
