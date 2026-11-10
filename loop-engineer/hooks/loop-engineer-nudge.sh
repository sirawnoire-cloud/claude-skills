#!/usr/bin/env bash
# loop-engineer UserPromptSubmit hook: cheap reminder while a loop is active.
# Safety net for idle/compaction cases SessionStart did not cover. Throttled.
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
STATE="$CWD/.loop-engineer-state.json"
[ -f "$STATE" ] || exit 0

KEY=$(printf '%s' "$CWD" | shasum | cut -c1-12)
STAMP="${TMPDIR:-/tmp}/loop-engineer-nudge-$KEY"
if [ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin -10 2>/dev/null)" ]; then exit 0; fi
touch "$STAMP" 2>/dev/null || true

IT=$(jq -r '.iteration // "?"' "$STATE" 2>/dev/null)
PH=$(jq -r '.phase // "?"' "$STATE" 2>/dev/null)
ST=$(jq -r '.step // ""' "$STATE" 2>/dev/null)
MSG="[loop-engineer active] iteration $IT, phase $PH${ST:+, step: $ST}. If you do not clearly remember what is already done, read $CWD/.loop-engineer-state.json and $CWD/.loop-engineer-memory.md before acting, and continue the loop instead of starting over."
jq -n --arg c "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
