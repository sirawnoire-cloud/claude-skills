#!/usr/bin/env bash
# loop-engineer SubagentStop hook: append the subagent's final message to the ledger (background agents report here).
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
j() { printf '%s' "$INPUT" | jq -r "$1" 2>/dev/null; }
CWD=$(j '.cwd // empty'); CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
STATE="$CWD/.loop-engineer-state.json"
[ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1 || exit 0
TASK=$(jq -r '.task // ""' "$STATE"); IT=$(jq -r '.iteration // 0' "$STATE")
jq -nc --arg ts "$(date '+%Y-%m-%dT%H:%M:%S%z')" --arg task "$TASK" --argjson it "${IT:-0}" \
  --arg ag "$(j '.agent_id // ""')" --arg ty "$(j '.agent_type // ""')" --arg r "$(j '.last_assistant_message // ""' | head -c 1500)" \
  '{ts:$ts,event:"stopped",task:$task,iteration:$it,agent_id:$ag,agent_type:$ty,result_head:$r}' >> "$CWD/.loop-engineer-agents.jsonl" 2>/dev/null || true
exit 0
