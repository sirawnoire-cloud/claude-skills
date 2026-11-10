#!/usr/bin/env bash
# loop-engineer UserPromptSubmit hook.
#  1) best-effort self-update check (throttled inside loop-engineer-update.sh, default 6h)
#  2) if a loop is active, a cheap reminder to re-anchor on the on-disk state (throttled 10 min)
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
HERE=$(cd "$(dirname "$0")" && pwd)

UPD=$("$HERE/loop-engineer-update.sh" 2>/dev/null || true)
OUT="$UPD"

# user-visible one-liner (systemMessage) when an update was applied
SYS=""
case "$UPD" in
  "[loop-engineer updated]"*)
    SYS=$(printf '%s' "$UPD" | head -n1 | sed -E 's/^\[loop-engineer updated\] (v[0-9.]+ -> v[0-9.]+).*/loop-engineer updated: \1 (details: ~\/.claude\/skills\/loop-engineer\/CHANGELOG.md, log: update.log)/') ;;
esac

STATE="$CWD/.loop-engineer-state.json"
if [ -f "$STATE" ]; then
  KEY=$(printf '%s' "$CWD" | shasum | cut -c1-12)
  STAMP="${TMPDIR:-/tmp}/loop-engineer-nudge-$KEY"
  if [ ! -f "$STAMP" ] || [ -z "$(find "$STAMP" -mmin -10 2>/dev/null)" ]; then
    touch "$STAMP" 2>/dev/null || true

# rules-changed detection: loop created under a different skill version than the installed one
VERMSG=""
SK="${LOOP_ENGINEER_SKILL_DIR:-$HOME/.claude/skills/loop-engineer}"
CUR=$(cat "$SK/VERSION" 2>/dev/null | tr -d '[:space:]')
LOOPV=$(jq -r '.skill_version // empty' "$STATE" 2>/dev/null)
if [ -n "$CUR" ] && [ -n "$LOOPV" ] && [ "$CUR" != "$LOOPV" ]; then
  VERMSG="[loop-engineer rules changed] this loop was created under skill v$LOOPV but v$CUR is installed. Re-read $SK/SKILL.md, rewrite the Rules digest block in $CWD/.loop-engineer-memory.md to match the new rules, set skill_version to \"$CUR\" in $CWD/.loop-engineer-state.json, then continue the loop where it was (no restart, keep the iteration count)."
fi
    IT=$(jq -r '.iteration // "?"' "$STATE" 2>/dev/null)
    PH=$(jq -r '.phase // "?"' "$STATE" 2>/dev/null)
    ST=$(jq -r '.step // ""' "$STATE" 2>/dev/null)
    MSG="[loop-engineer active] iteration $IT, phase $PH${ST:+, step: $ST}. If you do not clearly remember what is already done, read $CWD/.loop-engineer-state.json and $CWD/.loop-engineer-memory.md before acting, and continue the loop instead of starting over."
    [ -n "$VERMSG" ] && MSG="$MSG $VERMSG"
    OUT="${OUT:+$OUT

}$MSG"
  fi
fi

[ -z "$OUT" ] && exit 0
jq -n --arg c "$OUT" --arg s "$SYS" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}} + (if $s != "" then {systemMessage:$s} else {} end)'
