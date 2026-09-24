#!/usr/bin/env python3
"""Static pre-publish QA for Robloxjogo Luau sources."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
PROJECT = ROOT / "default.project.json"
errors = []

if not SRC.is_dir():
    errors.append("src/ directory is missing")

lua_files = sorted(list(SRC.rglob("*.lua")) + list(SRC.rglob("*.luau")))
if not lua_files:
    errors.append("no Luau source files found under src/")

bad_escape = re.compile(r"\\[nt]")
merge_marker = re.compile(r"^(<<<<<<<|=======|>>>>>>>)", re.MULTILINE)

for path in lua_files:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    if bad_escape.search(text):
        errors.append(f"{rel}: literal \\n or \\t escape found in source")
    if merge_marker.search(text):
        errors.append(f"{rel}: unresolved git merge marker")
    if "\x00" in text:
        errors.append(f"{rel}: NUL byte found")
    if path.name.endswith(".client.lua") and "LocalPlayer" not in text and "require(" not in text:
        print(f"QA notice: {rel} is a client script without LocalPlayer (allowed).")

try:
    project = json.loads(PROJECT.read_text(encoding="utf-8"))
except Exception as exc:
    errors.append(f"default.project.json is invalid JSON: {exc}")
    project = None

if project:
    raw = PROJECT.read_text(encoding="utf-8")
    for required in ("DataModel", "Workspace", "ServerScriptService", "StarterGui"):
        if required not in raw:
            errors.append(f"default.project.json missing required mapping: {required}")
    for match in re.finditer(r'"\$path"\s*:\s*"([^"]+)"', raw):
        mapped = ROOT / match.group(1)
        if not mapped.exists():
            errors.append(f"default.project.json maps missing path: {match.group(1)}")

if errors:
    print("ROBLOXJOGO QA FAILED")
    for error in errors:
        print(f"::error::{error}")
    sys.exit(1)

print(f"ROBLOXJOGO QA PASS — {len(lua_files)} Luau files checked")
