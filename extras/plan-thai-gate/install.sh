#!/usr/bin/env bash
# Install plan-thai-gate.js into ~/.claude/hooks and register it on PreToolUse/ExitPlanMode. Idempotent.
#   install.sh [--dry-run]     (CLAUDE_HOME overrides ~/.claude for testing)
set -eu
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"; HK="$CLAUDE/hooks"; SET="$CLAUDE/settings.json"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
if [ "$DRY" = 1 ]; then
  echo "[dry-run] copy plan-thai-gate.js -> $HK/"
  echo "[dry-run] settings.json: PreToolUse / ExitPlanMode -> node \"$HK/plan-thai-gate.js\" (backup -> settings.json.bak-plan-thai-gate)"
  exit 0
fi
mkdir -p "$HK"; cp "$SRC/plan-thai-gate.js" "$HK/plan-thai-gate.js"
[ -f "$SET" ] || echo '{}' > "$SET"
jq -e . "$SET" >/dev/null || { echo "settings.json is not valid JSON; aborting" >&2; exit 1; }
cp "$SET" "$SET.bak-plan-thai-gate"
tmp=$(mktemp)
jq --arg c "node \"$HK/plan-thai-gate.js\"" '
  .hooks //= {}
  | .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select([.hooks[]?.command] | any(contains("plan-thai-gate.js")) | not)))
      + [{matcher:"ExitPlanMode", hooks:[{type:"command", command:$c}]}]' "$SET" > "$tmp"
jq -e . "$tmp" >/dev/null && mv "$tmp" "$SET"
echo "installed plan-thai-gate -> $HK (settings backup: $SET.bak-plan-thai-gate)"
