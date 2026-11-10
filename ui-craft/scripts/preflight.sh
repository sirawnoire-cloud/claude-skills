#!/usr/bin/env bash
# ui-craft preflight: open a page in headless Chrome at several widths, screenshot, report objective problems.
# usage: preflight.sh <url-or-html-file> [--out DIR] [--widths 320,390,768,1024,1440,1920]
# First run installs playwright-core into ~/.cache/ui-craft (no browser download; uses installed Chrome).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE="${UI_CRAFT_CACHE:-$HOME/.cache/ui-craft}"
command -v node >/dev/null 2>&1 || { echo "preflight: node is required" >&2; exit 2; }
if ! (cd "$CACHE" 2>/dev/null && node -e "require.resolve('playwright-core')" >/dev/null 2>&1); then
  echo "ui-craft preflight: installing playwright-core into $CACHE (one time, no browser download)..." >&2
  mkdir -p "$CACHE"
  ( cd "$CACHE" && { [ -f package.json ] || npm init -y >/dev/null 2>&1; } && npm install --silent --no-audit --no-fund playwright-core@1.49.1 >&2 )
fi
exec node "$HERE/preflight.mjs" "$@"
