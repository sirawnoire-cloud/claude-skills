#!/usr/bin/env bash
# Install loop-engineer skill + hooks into ~/.claude and merge hook entries into settings.json.
# Idempotent: re-running replaces loop-engineer hook entries, leaves all other hooks untouched.
set -eu
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
SK="$CLAUDE/skills/loop-engineer"; HK="$CLAUDE/hooks"; SET="$CLAUDE/settings.json"
mkdir -p "$SK" "$HK"

for f in SKILL.md VERSION CHANGELOG.md; do cp "$SRC/$f" "$SK/$f"; done
cp "$SRC/verify-diff.sh" "$SK/verify-diff.sh"; chmod +x "$SK/verify-diff.sh"
for f in recover precompact nudge update; do
  cp "$SRC/hooks/loop-engineer-$f.sh" "$HK/loop-engineer-$f.sh"; chmod +x "$HK/loop-engineer-$f.sh"
done

[ -f "$SET" ] || echo '{}' > "$SET"
jq -e . "$SET" >/dev/null || { echo "settings.json is not valid JSON; aborting" >&2; exit 1; }
cp "$SET" "$SET.bak-loop-engineer"

tmp=$(mktemp)
jq --arg h "$HK" '
  def drop(ev): (.hooks[ev] // []) | map(select([.hooks[]?.command] | any(contains("loop-engineer-")) | not));
  def entry(m; cmd; t): ({hooks:[{type:"command", command:cmd, timeout:t}]} + (if m then {matcher:m} else {} end));
  .hooks //= {}
  | .hooks.SessionStart     = (drop("SessionStart")     + [entry("startup|resume|clear|compact|fork"; "\"\($h)/loop-engineer-recover.sh\""; 20)])
  | .hooks.PreCompact       = (drop("PreCompact")       + [entry(null; "\"\($h)/loop-engineer-precompact.sh\""; 10)])
  | .hooks.UserPromptSubmit = (drop("UserPromptSubmit") + [entry(null; "\"\($h)/loop-engineer-nudge.sh\""; 25)])
' "$SET" > "$tmp"
jq -e . "$tmp" >/dev/null && mv "$tmp" "$SET"
echo "installed loop-engineer v$(cat "$SK/VERSION") -> $CLAUDE (settings backup: $SET.bak-loop-engineer)"
