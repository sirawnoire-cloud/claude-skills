#!/usr/bin/env bash
# loop-engineer Stop hook: refuse to end the turn while verify-diff.sh reported a VIOLATION.
# Blocks up to LOOP_ENGINEER_MAX_STOP_BLOCKS consecutive times (default 3), then lets the turn end with a
# user-visible warning, so an unfixable violation can never trap the session. Claude Code also caps
# consecutive stop-hook continuations (8) as a backstop. Kill switch: LOOP_ENGINEER_ENFORCE=0.
set -u
dbg() { [ -n "${LOOP_ENGINEER_DEBUG_LOG:-}" ] && printf '%s %s %s\n' "$(date +%T)" "stop" "$*" >> "$LOOP_ENGINEER_DEBUG_LOG"; return 0; }
command -v jq >/dev/null 2>&1 || exit 0
[ "${LOOP_ENGINEER_ENFORCE:-1}" = "0" ] && { dbg "enforce off"; exit 0; }
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null); CWD=${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
[ -f "$CWD/.loop-engineer-state.json" ] || exit 0
MARK="$CWD/.loop-engineer-violation"; CNT="$CWD/.loop-engineer-stopblocks"
if [ ! -f "$MARK" ]; then rm -f "$CNT"; dbg "no marker -> allow"; exit 0; fi
# never trust a stale marker: re-run the check live (the script rewrites/removes the marker itself)
SK="${LOOP_ENGINEER_SKILL_DIR:-$HOME/.claude/skills/loop-engineer}"
if [ -f "$CWD/.loop-engineer-snapshot.tsv" ] && [ -x "$SK/verify-diff.sh" ]; then
  LEDGER="$CWD/.loop-engineer-agents.jsonl"
  TASK=$(jq -r '.task // ""' "$CWD/.loop-engineer-state.json" 2>/dev/null); IT=$(jq -r '.iteration // 0' "$CWD/.loop-engineer-state.json" 2>/dev/null)
  ALL=$(jq -rs --arg t "$TASK" --argjson i "${IT:-0}" '[.[] | select(.event=="spawn" and .task==$t and .iteration==$i and .role=="executor") | .allowed] | join(",")' "$LEDGER" 2>/dev/null)
  ARGS=(); OLDIFS=$IFS; IFS=','; for g in $ALL; do g=$(printf '%s' "$g" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'); [ -n "$g" ] && ARGS+=(--allow "$g"); done; IFS=$OLDIFS
  (cd "$CWD" && "$SK/verify-diff.sh" check ${ARGS[@]+"${ARGS[@]}"} >/dev/null 2>&1) || true
  if [ ! -f "$MARK" ]; then rm -f "$CNT"; dbg "live re-check clean, stale marker removed -> allow"; exit 0; fi
fi
MAXB="${LOOP_ENGINEER_MAX_STOP_BLOCKS:-3}"
N=$(cat "$CNT" 2>/dev/null | head -n1); case "$N" in ''|*[!0-9]*) N=0 ;; esac
if [ "$N" -ge "$MAXB" ]; then
  rm -f "$CNT"; dbg "block limit $MAXB reached -> allow with warning"
  jq -n --arg s "loop-engineer: finishing with an UNRESOLVED verify-diff VIOLATION (see .loop-engineer-violation). The Stop hook blocked $MAXB times." '{systemMessage:$s}'
  exit 0
fi
echo $((N+1)) > "$CNT"
dbg "BLOCK $((N+1))/$MAXB (stop_hook_active=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null))"
jq -n --arg r "[loop-engineer] verify-diff.sh reported a VIOLATION and it is not resolved:
$(head -c 1500 "$MARK")
Fix or revert the offending change, then run ~/.claude/skills/loop-engineer/verify-diff.sh check (same --allow globs) until it passes. Do not finish the iteration before that." '{decision:"block",reason:$r}'
