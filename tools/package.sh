#!/usr/bin/env bash
# Build the CurseForge release zip: dist/AzerothFit-<version>.zip
# The zip holds one root folder, AzerothFit/, with AzerothFit.toc inside (what CurseForge expects).
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^## Version: *//p' AzerothFit/AzerothFit.toc | tr -d '\r')
out="dist/AzerothFit-${version}.zip"

# Refuse to package a broken build.
lua5.1 tests/run_tests.lua >/dev/null
lua5.1 tests/run_v02.lua >/dev/null
for f in $(find AzerothFit -name '*.lua'); do luac5.1 -p "$f"; done

mkdir -p dist
rm -f "$out"
zip -q -r -X "$out" AzerothFit -x '*.DS_Store' '*/.*' '*~'
echo "built $out ($(du -h "$out" | cut -f1))"
unzip -l "$out" | tail -1
