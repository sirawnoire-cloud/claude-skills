#!/usr/bin/env bash
# loop-engineer SessionStart hook (startup|resume|compact|clear).
# 1) best-effort self-update  2) if a loop is in progress, re-inject state + memory.
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
SRC=$(printf '%s' "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null)
HERE=$(cd "$(dirname "$0")" && pwd)

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
  M=""
  if [ -f "$MEM" ]; then
    N=$(wc -l < "$MEM" | tr -d ' ')
    if [ "$N" -le 200 ]; then M=$(cat "$MEM")
    else M="$(head -n 20 "$MEM")
...(middle truncated — $N lines total; read $MEM for the rest)...
$(tail -n 120 "$MEM")"; fi
  fi
  BLOCK="[loop-engineer recovered] session source: $SRC. A loop-engineer loop is IN PROGRESS in $CWD. Context may have been compacted/cleared, so the files below are the source of truth. Do NOT restart and do NOT ask the user to re-invoke /loop-engineer: say in one line what is continuing (task, iteration, phase), then continue from phase/step/Next. Do not repeat anything under Done or Failed attempts. If phase is executor/between or you are unsure, re-run the evaluator first. Re-read ~/.claude/skills/loop-engineer/SKILL.md if you need the full rules.

--- .loop-engineer-state.json ---
$S

--- .loop-engineer-memory.md ---
${M:-(missing — rebuild it from the state file and the repo, then continue)}"
  OUT="${OUT:+$OUT

}$BLOCK"
  TK=$(jq -r '.task // ""' "$STATE" | head -c 60); IT=$(jq -r '.iteration // "?"' "$STATE"); PH=$(jq -r '.phase // "?"' "$STATE")
  SYS="${SYS:+$SYS | }loop-engineer: loop resumed from disk (\"$TK\", iteration $IT, phase $PH)"
fi

[ -z "$OUT" ] && exit 0
jq -n --arg c "$OUT" --arg s "$SYS" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}} + (if $s != "" then {systemMessage:$s} else {} end)'
