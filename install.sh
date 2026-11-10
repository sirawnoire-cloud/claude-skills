#!/usr/bin/env bash
# Install skills from this repo into ~/.claude/skills and wire the hooks:
#   - claude-skills-sync (SessionStart + UserPromptSubmit): self-update for every skill installed from here
#   - loop-engineer hooks (via loop-engineer/install.sh)
#
#   ./install.sh [--dry-run] [skill ...]      (default: all skills in this repo)
#
# Safe by design: symlinked skills and skills with their own .git are skipped; an existing different copy is
# backed up to ~/.claude/.skills-install-backup/ first; settings.json is backed up and only this repo's hook
# entries are replaced (all other hooks untouched). Re-running is idempotent.
set -eu
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync required" >&2; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"; SKILLS="$CLAUDE/skills"; HK="$CLAUDE/hooks"; SET="$CLAUDE/settings.json"
DRY=0; WANT=()
for a in "$@"; do case "$a" in --dry-run|-n) DRY=1 ;; -*) echo "unknown option $a" >&2; exit 2 ;; *) WANT+=("$a") ;; esac; done
if [ ${#WANT[@]} -eq 0 ]; then
  for d in "$SRC"/*/; do s=$(basename "$d"); [ -f "$d/SKILL.md" ] && [ -f "$d/VERSION" ] && WANT+=("$s"); done
fi
say() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else echo "$*"; fi; }
run() { [ "$DRY" = 1 ] || "$@"; }
EXCL=(--exclude '.bak-*' --exclude .last-check --exclude update.log --exclude .DS_Store --exclude node_modules)
DIFFX=(-x '.bak-*' -x .last-check -x update.log -x .DS_Store -x node_modules)

DO_LOOP=0
for s in "${WANT[@]}"; do
  [ -f "$SRC/$s/SKILL.md" ] || { echo "skip $s: not a skill in this repo" >&2; continue; }
  [ "$s" = "loop-engineer" ] && { DO_LOOP=1; continue; }
  T="$SKILLS/$s"
  if [ -L "$T" ]; then say "skip  $s: $T is a symlink (not ours)"; continue; fi
  if [ -d "$T/.git" ]; then say "skip  $s: $T has its own .git repo"; continue; fi
  if [ -d "$T" ] && ! diff -rq "${DIFFX[@]}" "$T" "$SRC/$s" >/dev/null 2>&1; then
    B="$CLAUDE/.skills-install-backup/$s-$(date +%Y%m%d%H%M%S)"
    say "backup $s -> $B"; run mkdir -p "$B"; run rsync -a "${EXCL[@]}" "$T/" "$B/"
  fi
  say "install $s v$(tr -d '[:space:]' < "$SRC/$s/VERSION") -> $T"
  run mkdir -p "$T"; run rsync -a --delete "${EXCL[@]}" "$SRC/$s/" "$T/"
done

# generic updater + sync hook
say "install hooks: claude-skills-update.sh, claude-skills-sync.sh -> $HK"
if [ "$DRY" = 0 ]; then
  mkdir -p "$HK"
  cp "$SRC/tools/claude-skills-update.sh" "$SRC/tools/claude-skills-sync.sh" "$HK/"; chmod +x "$HK"/claude-skills-*.sh
  [ -f "$SET" ] || echo '{}' > "$SET"
  jq -e . "$SET" >/dev/null || { echo "settings.json is not valid JSON; aborting" >&2; exit 1; }
  cp "$SET" "$SET.bak-claude-skills"
  tmp=$(mktemp)
  jq --arg h "$HK" '
    def drop(ev): (.hooks[ev] // []) | map(select([.hooks[]?.command] | any(contains("claude-skills-")) | not));
    def entry(m; cmd; t): ({hooks:[{type:"command", command:cmd, timeout:t}]} + (if m then {matcher:m} else {} end));
    .hooks //= {}
    | .hooks.SessionStart     = (drop("SessionStart")     + [entry("startup|resume|clear|compact|fork"; "\"\($h)/claude-skills-sync.sh\""; 30)])
    | .hooks.UserPromptSubmit = (drop("UserPromptSubmit") + [entry(null; "\"\($h)/claude-skills-sync.sh\""; 30)])
  ' "$SET" > "$tmp"
  jq -e . "$tmp" >/dev/null && mv "$tmp" "$SET"
else
  echo "[dry-run] settings.json: add claude-skills-sync.sh to SessionStart and UserPromptSubmit (backup -> settings.json.bak-claude-skills)"
fi

if [ "$DO_LOOP" = 1 ]; then
  say "install loop-engineer (skill + its 7 hooks) via loop-engineer/install.sh"
  [ "$DRY" = 1 ] || "$SRC/loop-engineer/install.sh"
fi
[ "$DRY" = 1 ] && echo "(dry run: nothing was changed)" || echo "done. Open a new session so new hooks load."
