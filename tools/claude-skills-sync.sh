#!/usr/bin/env bash
# Hook (SessionStart + UserPromptSubmit): run the generic skills updater and tell the model + the user.
set -u
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
EV=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
case "$EV" in SessionStart|UserPromptSubmit) ;; *) EV=UserPromptSubmit ;; esac
HERE=$(cd "$(dirname "$0")" && pwd)
UPD=$("$HERE/claude-skills-update.sh" 2>/dev/null || true)
[ -z "$UPD" ] && exit 0
SYS=$(printf '%s\n' "$UPD" | grep -E '^\[claude-skills updated\]' | sed -E 's/^\[claude-skills updated\] ([a-z0-9-]+) (v[0-9.]+ -> v[0-9.]+).*/\1 \2/' | paste -sd',' - | sed 's/,/, /g')
CTX="$UPD
If one of these skills is currently in use in this conversation, its text changed: re-read the skill's SKILL.md (and any references it points to) before continuing; otherwise nothing to do — the new version loads on next use."
jq -n --arg c "$CTX" --arg s "claude-skills updated: $SYS (log: ~/.claude/.claude-skills-sync/update.log)" --arg ev "$EV" \
  '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$c},systemMessage:$s}'
