#!/usr/bin/env bash
# loop-engineer PreToolUse hook, matcher "Agent". Only acts while a loop is active (state file in cwd).
# Mechanically enforces the Delegation rules: no nested agents, per-iteration cap, required prompt header,
# read-only agent types for judge/research, snapshot before executor agents. Logs every spawn to a ledger.
# Kill switch: LOOP_ENGINEER_ENFORCE=0
set -u
dbg() { [ -n "${LOOP_ENGINEER_DEBUG_LOG:-}" ] && printf '%s %s %s\n' "$(date +%T)" "agent-pre" "$*" >> "$LOOP_ENGINEER_DEBUG_LOG"; return 0; }
command -v jq >/dev/null 2>&1 || exit 0
[ "${LOOP_ENGINEER_ENFORCE:-1}" = "0" ] && exit 0
INPUT=$(cat 2>/dev/null || true)
j() { printf '%s' "$INPUT" | jq -r "$1" 2>/dev/null; }
[ "$(j '.tool_name // ""')" = "Agent" ] || exit 0
CWD=$(j '.cwd // empty'); CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
STATE="$CWD/.loop-engineer-state.json"
[ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1 || exit 0
LEDGER="$CWD/.loop-engineer-agents.jsonl"
MAXA="${LOOP_ENGINEER_MAX_AGENTS:-5}"
READONLY="${LOOP_ENGINEER_READONLY_AGENTS:-Explore Plan claude-code-guide cavecrew-investigator cavecrew-reviewer}"

deny() {
  dbg "DENY $1"
  jq -n --arg r "[loop-engineer] spawn blocked: $1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

[ -n "$(j '.agent_id // empty')" ] && deny "nested subagents are not allowed while a loop is active; do the work inside this agent."

PROMPT=$(j '.tool_input.prompt // ""')
TYPE=$(j '.tool_input.subagent_type // ""')
DESC=$(j '.tool_input.description // ""')
TUID=$(j '.tool_use_id // ""')
TASK=$(jq -r '.task // ""' "$STATE"); IT=$(jq -r '.iteration // 0' "$STATE")
field() { printf '%s\n' "$PROMPT" | grep -m1 -E "^$1:" | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]*\$//"; }
HDR="Put these header lines at the very top of the agent prompt (see the Delegation section of ~/.claude/skills/loop-engineer/SKILL.md): LOOP-ROLE: executor|judge|research; executor also needs ALLOWED-FILES: <comma-separated globs> and GUARDRAILS: no-delete-tests, no-hardcode, no-mock-target, no-narrow-criteria; judge also needs CRITERIA: and ARTIFACTS:."

ROLE=$(field 'LOOP-ROLE' | tr 'A-Z' 'a-z')
case "$ROLE" in executor|judge|research) ;; *) deny "missing or invalid LOOP-ROLE header. $HDR" ;; esac

is_readonly() { for t in $READONLY; do [ "$t" = "$TYPE" ] && return 0; done; return 1; }

ALLOWED=""
case "$ROLE" in
  executor)
    ALLOWED=$(field 'ALLOWED-FILES')
    [ -n "$ALLOWED" ] || deny "executor agent needs an ALLOWED-FILES header (comma-separated globs it may change). $HDR"
    G=$(field 'GUARDRAILS')
    for g in no-delete-tests no-hardcode no-mock-target no-narrow-criteria; do
      printf '%s' "$G" | grep -q -- "$g" || deny "executor GUARDRAILS header must include '$g'. $HDR"
    done
    [ -f "$CWD/.loop-engineer-snapshot.tsv" ] || deny "no snapshot yet. Run: ~/.claude/skills/loop-engineer/verify-diff.sh snapshot (in $CWD) before delegating executor work, then retry." ;;
  judge)
    [ -n "$(field 'CRITERIA')" ] && [ -n "$(field 'ARTIFACTS')" ] || deny "judge agent needs CRITERIA: and ARTIFACTS: headers (give it the work and the criteria, never your verdict). $HDR"
    is_readonly || deny "judge agents must be read-only; subagent_type '$TYPE' is not in: $READONLY" ;;
  research)
    is_readonly || deny "research agents must be read-only; subagent_type '$TYPE' is not in: $READONLY (use role executor for agents that edit files)." ;;
esac

N=$(jq -s --arg t "$TASK" --argjson i "${IT:-0}" '[.[] | select(.event=="spawn" and .task==$t and .iteration==$i)] | length' "$LEDGER" 2>/dev/null | head -n1)
case "$N" in ''|*[!0-9]*) N=0 ;; esac
[ "${N:-0}" -ge "$MAXA" ] && deny "agent cap reached ($MAXA per iteration, $N already spawned in iteration $IT). Do the rest yourself or finish the iteration."

jq -nc --arg ts "$(date '+%Y-%m-%dT%H:%M:%S%z')" --arg tu "$TUID" --arg task "$TASK" --argjson it "${IT:-0}" \
  --arg role "$ROLE" --arg d "$DESC" --arg al "$ALLOWED" --arg ty "$TYPE" \
  '{ts:$ts,event:"spawn",tool_use_id:$tu,task:$task,iteration:$it,role:$role,description:$d,allowed:$al,subagent_type:$ty}' >> "$LEDGER" 2>/dev/null || true
dbg "ALLOW role=$ROLE type=$TYPE"
exit 0
