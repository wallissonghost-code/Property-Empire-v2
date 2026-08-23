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

cp "$SOURCE_PLACE" "$OUTPUT_PLACE"

# All future binary/place transformations for Mining Empire belong here.
# The upstream submodule remains untouched so license provenance stays auditable.

echo "Prepared $OUTPUT_PLACE from licensed upstream $ACTUAL_UPSTREAM"
ls -lh "$OUTPUT_PLACE"
