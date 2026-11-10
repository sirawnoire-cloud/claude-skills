#!/usr/bin/env bash
# loop-engineer PreCompact hook. stdout on exit 0 = extra instructions for the compaction summary.
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
STATE="$CWD/.loop-engineer-state.json"
[ -f "$STATE" ] || exit 0
IT=$(jq -r '.iteration // "?"' "$STATE" 2>/dev/null)
PH=$(jq -r '.phase // "?"' "$STATE" 2>/dev/null)
TK=$(jq -r '.task // ""' "$STATE" 2>/dev/null | head -c 300)
cat <<MSG
A loop-engineer loop is IN PROGRESS in $CWD (task: $TK; iteration $IT; phase $PH). In the summary, state this prominently and keep: the task, the criteria, the current iteration/phase, and the instruction that after compaction the assistant must first re-read $CWD/.loop-engineer-state.json and $CWD/.loop-engineer-memory.md (the on-disk source of truth) and continue the loop from phase/step/Next instead of restarting. Do not paraphrase away that these two files exist.
MSG
