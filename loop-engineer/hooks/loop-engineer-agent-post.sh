#!/usr/bin/env bash
# loop-engineer PostToolUse hook, matcher "Agent". Logs the agent's result to the ledger (survives compaction),
# runs verify-diff.sh itself after an executor agent returns, and tells the model what to do next.
set -u
dbg() { [ -n "${LOOP_ENGINEER_DEBUG_LOG:-}" ] && printf '%s %s %s\n' "$(date +%T)" "agent-post" "$*" >> "$LOOP_ENGINEER_DEBUG_LOG"; return 0; }
command -v jq >/dev/null 2>&1 || exit 0
[ "${LOOP_ENGINEER_ENFORCE:-1}" = "0" ] && exit 0
INPUT=$(cat 2>/dev/null || true)
j() { printf '%s' "$INPUT" | jq -r "$1" 2>/dev/null; }
[ "$(j '.tool_name // ""')" = "Agent" ] || exit 0
CWD=$(j '.cwd // empty'); CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
STATE="$CWD/.loop-engineer-state.json"
[ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1 || exit 0
LEDGER="$CWD/.loop-engineer-agents.jsonl"
SK="${LOOP_ENGINEER_SKILL_DIR:-$HOME/.claude/skills/loop-engineer}"
TASK=$(jq -r '.task // ""' "$STATE"); IT=$(jq -r '.iteration // 0' "$STATE")
TUID=$(j '.tool_use_id // ""')
STATUS=$(j 'if (.tool_response|type)=="object" then (.tool_response.status // "completed") else "completed" end')
AGENT=$(j 'if (.tool_response|type)=="object" then (.tool_response.agentId // "") else "" end')
RES=$(j 'if (.tool_response|type)=="object" then ([.tool_response.content[]? | select(.type=="text") | .text] | join("\n")) else (.tool_response|tostring) end' | head -c 1500)
ROLE=$(jq -rs --arg u "$TUID" '[.[] | select(.event=="spawn" and .tool_use_id==$u)] | last | .role // ""' "$LEDGER" 2>/dev/null)

EV="returned"; [ "$STATUS" = "async_launched" ] && EV="launched"
jq -nc --arg ts "$(date '+%Y-%m-%dT%H:%M:%S%z')" --arg ev "$EV" --arg tu "$TUID" --arg task "$TASK" --argjson it "${IT:-0}" \
  --arg role "$ROLE" --arg ag "$AGENT" --arg r "$RES" \
  '{ts:$ts,event:$ev,tool_use_id:$tu,task:$task,iteration:$it,role:$role,agent_id:$ag,result_head:$r}' >> "$LEDGER" 2>/dev/null || true

emit() { dbg "EMIT $(printf '%s' "$1" | tr '\n' ' ' | head -c 160)"; jq -n --arg c "$1" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'; exit 0; }

if [ "$EV" = "launched" ]; then
  emit "[loop-engineer] background agent launched (id ${AGENT:-?}). Its result can be lost if the session compacts: set state \`step\` to note you are waiting on it. The spawn is logged in $LEDGER. When it reports back, run verify-diff.sh check yourself and write the result into memory."
fi

MSG="[loop-engineer] agent result logged to $LEDGER (role: ${ROLE:-unknown}). Treat its report as a claim, not evidence. Write what it did into memory (Done / Failed attempts) now."
if [ "$ROLE" = "executor" ] && [ -f "$CWD/.loop-engineer-snapshot.tsv" ] && [ -x "$SK/verify-diff.sh" ]; then
  ARGS=()
  ALL=$(jq -rs --arg t "$TASK" --argjson i "${IT:-0}" '[.[] | select(.event=="spawn" and .task==$t and .iteration==$i and .role=="executor") | .allowed] | join(",")' "$LEDGER" 2>/dev/null)
  OLDIFS=$IFS; IFS=','; for g in $ALL; do g=$(printf '%s' "$g" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'); [ -n "$g" ] && ARGS+=(--allow "$g"); done; IFS=$OLDIFS
  VOUT=$(cd "$CWD" && "$SK/verify-diff.sh" check ${ARGS[@]+"${ARGS[@]}"} 2>&1); VRC=$?
  VOUT=$(printf '%s' "$VOUT" | head -c 2500)
  MSG="$MSG verify-diff.sh check (run automatically by the hook):
$VOUT"
  if [ "$VRC" = "1" ]; then
    MSG="$MSG
VIOLATION found. Fix or revert the out-of-scope / test-deleting change; you cannot finish the turn until verify-diff.sh check passes."
  else
    MSG="$MSG
No violations. Now run the full test suite yourself before judging pass."
  fi
fi
emit "$MSG"
