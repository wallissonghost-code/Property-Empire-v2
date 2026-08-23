#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PLACE="Museu-Empire.rbxl"

if ! command -v rbxmk >/dev/null 2>&1; then
  echo "rbxmk is required" >&2
  exit 1
fi

test -f scripts/diagnostic-place.rbxmk.lua
rm -f "$OUTPUT_PLACE"
rbxmk run scripts/diagnostic-place.rbxmk.lua "$OUTPUT_PLACE"
test -s "$OUTPUT_PLACE"
echo "Prepared ultra-minimal Museu Empire diagnostic place"
ls -lh "$OUTPUT_PLACE"
