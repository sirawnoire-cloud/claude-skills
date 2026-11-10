#!/usr/bin/env bash
# loop-engineer SessionStart hook (startup|resume|clear|compact|fork).
# 1) best-effort self-update  2) if a loop is in progress, re-inject state + memory
#    (+ the full current rules text when the skill was updated / the loop's skill_version is stale).
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
SRC=$(printf '%s' "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null)
HERE=$(cd "$(dirname "$0")" && pwd)
SK="${LOOP_ENGINEER_SKILL_DIR:-$HOME/.claude/skills/loop-engineer}"

# current skill text without frontmatter, capped
rules_body() { awk '/^---$/{c++; next} c>=2' "$SK/SKILL.md" 2>/dev/null | head -c 24000; }

OUT=""
UPD=$("$HERE/loop-engineer-update.sh" 2>/dev/null || true)
[ -n "$UPD" ] && OUT="$UPD"

# user-visible one-liner (systemMessage) when an update was applied
SYS=""
case "$UPD" in
  "[loop-engineer updated]"*)
    SYS=$(printf '%s' "$UPD" | head -n1 | sed -E 's/^\[loop-engineer updated\] (v[0-9.]+ -> v[0-9.]+).*/loop-engineer updated: \1 (details: ~\/.claude\/skills\/loop-engineer\/CHANGELOG.md, log: update.log)/') ;;
esac

STATE="$CWD/.loop-engineer-state.json"
MEM="$CWD/.loop-engineer-memory.md"
if [ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1; then
  S=$(head -c 4000 "$STATE")

  # rules-changed detection: loop created under a different skill version than the installed one
  VERMSG=""
  CUR=$(cat "$SK/VERSION" 2>/dev/null | tr -d '[:space:]')
  LOOPV=$(jq -r '.skill_version // empty' "$STATE" 2>/dev/null)
  if [ -n "$CUR" ] && [ -n "$LOOPV" ] && [ "$CUR" != "$LOOPV" ]; then
    VERMSG="[loop-engineer rules changed] this loop was created under skill v$LOOPV but v$CUR is installed. The full current rules are below and REPLACE any earlier copy of the loop-engineer rules in this conversation. Rewrite the Rules digest block in $CWD/.loop-engineer-memory.md to match them, set skill_version to \"$CUR\" in $CWD/.loop-engineer-state.json, then continue the loop where it was (no restart, keep the iteration count)."
  fi

  M=""
  if [ -f "$MEM" ]; then
    N=$(wc -l < "$MEM" | tr -d ' ')
    if [ "$N" -le 200 ]; then M=$(cat "$MEM")
    else M="$(head -n 20 "$MEM")
...(middle truncated — $N lines total; read $MEM for the rest)...
$(tail -n 120 "$MEM")"; fi
  fi
  AG=""
  if [ -f "$CWD/.loop-engineer-agents.jsonl" ]; then
    AG=$(tail -n 8 "$CWD/.loop-engineer-agents.jsonl" | jq -r '"- [\(.event)] \(.role // .agent_type // "") \(.description // .agent_id // "") \((.result_head // .allowed // "") | .[0:160] | gsub("\n";" "))"' 2>/dev/null)
  fi
  VIOL=""; [ -f "$CWD/.loop-engineer-violation" ] && VIOL=$(head -c 800 "$CWD/.loop-engineer-violation")
  BLOCK="[loop-engineer recovered] session source: $SRC. A loop-engineer loop is IN PROGRESS in $CWD. Context may have been compacted/cleared, so the files below are the source of truth. Do NOT restart and do NOT ask the user to re-invoke /loop-engineer: say in one line what is continuing (task, iteration, phase), then continue from phase/step/Next. Do not repeat anything under Done or Failed attempts. If phase is executor/between or you are unsure, re-run the evaluator first. Re-read ~/.claude/skills/loop-engineer/SKILL.md if you need the full rules.

--- .loop-engineer-state.json ---
$S

--- .loop-engineer-memory.md ---
${M:-(missing — rebuild it from the state file and the repo, then continue)}"
  [ -n "$AG" ] && BLOCK="$BLOCK

--- subagent ledger (last 8; logged by hooks, a result that is missing from memory must be re-checked on disk) ---
$AG"
  [ -n "$VIOL" ] && BLOCK="$BLOCK

--- UNRESOLVED verify-diff VIOLATION (the Stop hook blocks finishing until verify-diff.sh check passes) ---
$VIOL"
  [ -n "$VERMSG" ] && BLOCK="$BLOCK

$VERMSG"
  # ship the full current rules when they changed (stale loop) or were just updated
  if [ -n "$VERMSG" ] || [ -n "$UPD" ]; then
    RB=$(rules_body)
    [ -n "$RB" ] && BLOCK="$BLOCK

--- loop-engineer rules, CURRENT (v${CUR:-?}); supersede any earlier copy in this conversation ---
$RB"
  fi
  OUT="${OUT:+$OUT

}$BLOCK"
  TK=$(jq -r '.task // ""' "$STATE" | head -c 60); IT=$(jq -r '.iteration // "?"' "$STATE"); PH=$(jq -r '.phase // "?"' "$STATE")
  SYS="${SYS:+$SYS | }loop-engineer: loop resumed from disk (\"$TK\", iteration $IT, phase $PH)"
fi

[ -z "$OUT" ] && exit 0
jq -n --arg c "$OUT" --arg s "$SYS" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}} + (if $s != "" then {systemMessage:$s} else {} end)'
