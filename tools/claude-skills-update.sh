#!/usr/bin/env bash
# claude-skills self-update (generic). For every skill in ~/.claude/skills that
#   - is a real directory (symlinked / third-party skills are never touched),
#   - has a VERSION file (that is the opt-in: only skills installed from the claude-skills repo have one),
#   - and appears in the repo's manifest.json with a newer version,
# fetch the *text* files marked auto (SKILL.md, references/*.md, templates/*.md, CHANGELOG.md, VERSION),
# verify sha256 against the manifest, then atomically replace them (backup kept in <skill>/.bak-<oldver>).
# Code/data files (scripts, hooks, json...) are NEVER auto-updated: the notice tells you to re-run install.sh.
# Prints one notice block on stdout iff something was updated or code changed. Silent on any failure.
# Kill switch: CLAUDE_SKILLS_NO_UPDATE=1 (LOOP_ENGINEER_NO_UPDATE=1 also honored).
set -u
{ [ "${CLAUDE_SKILLS_NO_UPDATE:-}" = "1" ] || [ "${LOOP_ENGINEER_NO_UPDATE:-}" = "1" ]; } && exit 0
for c in curl jq shasum; do command -v "$c" >/dev/null 2>&1 || exit 0; done

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
STATE="${CLAUDE_SKILLS_STATE:-$HOME/.claude/.claude-skills-sync}"
RAW="${CLAUDE_SKILLS_REPO_RAW:-https://raw.githubusercontent.com/sirawnoire-cloud/claude-skills/main}"
INTERVAL_MIN=$(( ${CLAUDE_SKILLS_UPDATE_INTERVAL:-21600} / 60 ))
MAXFILES=300; MAXBYTES=1048576
mkdir -p "$STATE" 2>/dev/null || exit 0
STAMP="$STATE/last-check"; LOG="$STATE/update.log"; FAILS="$STATE/fails"

# single instance (hooks can run in parallel); drop a lock older than 3 minutes
LOCK="$STATE/lock"
[ -d "$LOCK" ] && [ -n "$(find "$LOCK" -mmin +3 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null
mkdir "$LOCK" 2>/dev/null || exit 0
TMP=$(mktemp -d 2>/dev/null) || { rmdir "$LOCK"; exit 0; }
trap 'rm -rf "$TMP"; rmdir "$LOCK" 2>/dev/null' EXIT

[ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin "-$INTERVAL_MIN" 2>/dev/null)" ] && exit 0
touch "$STAMP" 2>/dev/null || true      # before fetching: offline/failed checks also wait out the interval

fetch() { curl -fsS --connect-timeout 2 --max-time 6 "$1" 2>/dev/null; }
semver='^[0-9]+\.[0-9]+\.[0-9]+$'
log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG" 2>/dev/null || true; }

MAN=$(fetch "$RAW/manifest.json") || exit 0
printf '%s' "$MAN" | jq -e '.schema == 1 and (.skills | type == "object")' >/dev/null 2>&1 || exit 0

NOTICE=""; MISMATCH=0
for name in $(printf '%s' "$MAN" | jq -r '.skills | keys[]' 2>/dev/null); do
  printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || continue
  dir="$SKILLS_DIR/$name"
  [ -L "$dir" ] && continue
  [ -d "$dir" ] && [ -f "$dir/VERSION" ] && [ -f "$dir/SKILL.md" ] || continue
  LOCAL=$(cat "$dir/VERSION" 2>/dev/null | tr -d '[:space:]'); printf '%s' "$LOCAL" | grep -Eq "$semver" || LOCAL=0.0.0
  REMOTE=$(printf '%s' "$MAN" | jq -r --arg n "$name" '.skills[$n].version // ""')
  printf '%s' "$REMOTE" | grep -Eq "$semver" || continue
  [ "$REMOTE" = "$LOCAL" ] && continue
  [ "$(printf '%s\n%s\n' "$LOCAL" "$REMOTE" | sort -V | head -n1)" = "$LOCAL" ] || continue   # never downgrade

  # code/data files that differ from the manifest -> only reported
  CODE=""
  while read -r sha rel; do
    [ -n "$rel" ] || continue
    printf '%s' "$rel" | grep -Eq '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$' || continue
    case "$rel" in *..*) continue ;; esac
    if [ ! -f "$dir/$rel" ] || [ "$(shasum -a 256 "$dir/$rel" | cut -d' ' -f1)" != "$sha" ]; then CODE="$CODE $rel"; fi
  done < <(printf '%s' "$MAN" | jq -r --arg n "$name" '.skills[$n].files[] | select(.auto == false) | "\(.sha256) \(.path)"' | head -n "$MAXFILES")

  # stage + verify every auto file before touching anything
  STG="$TMP/$name"; mkdir -p "$STG"; OK=1; GOT=""; COUNT=0
  while read -r sha rel size; do
    [ -n "$rel" ] || continue
    COUNT=$((COUNT+1)); [ "$COUNT" -le "$MAXFILES" ] || { OK=0; break; }
    printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || { OK=0; break; }
    printf '%s' "$rel" | grep -Eq '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$' || { OK=0; break; }
    case "$rel" in *..*) OK=0; break ;; esac
    case "$rel" in VERSION|*.md) ;; *) OK=0; break ;; esac
    case "$size" in ''|*[!0-9]*) OK=0; break ;; esac
    [ "$size" -le "$MAXBYTES" ] || { OK=0; break; }
    mkdir -p "$STG/$(dirname "$rel")"
    fetch "$RAW/$name/$rel" > "$STG/$rel" || { OK=0; break; }
    [ "$(shasum -a 256 "$STG/$rel" | cut -d' ' -f1)" = "$sha" ] || { OK=0; MISMATCH=1; break; }
    GOT="$GOT $rel"
  done < <(printf '%s' "$MAN" | jq -r --arg n "$name" '.skills[$n].files[] | select(.auto == true) | "\(.sha256) \(.path) \(.size)"')
  case " $GOT " in *" SKILL.md "*) ;; *) OK=0 ;; esac
  case " $GOT " in *" VERSION "*) ;; *) OK=0 ;; esac
  [ "$OK" = 1 ] && [ "$(tr -d '[:space:]' < "$STG/VERSION")" = "$REMOTE" ] || { log "skip $name $LOCAL->$REMOTE (verification failed)"; continue; }

  BAK="$dir/.bak-$LOCAL"; mkdir -p "$BAK" 2>/dev/null
  for rel in $GOT; do
    [ -f "$dir/$rel" ] && { mkdir -p "$BAK/$(dirname "$rel")"; cp "$dir/$rel" "$BAK/$rel"; }
  done
  for rel in $GOT; do [ "$rel" = VERSION ] && continue
    mkdir -p "$dir/$(dirname "$rel")"; mv "$STG/$rel" "$dir/$rel.new" && mv "$dir/$rel.new" "$dir/$rel"
  done
  mv "$STG/VERSION" "$dir/VERSION.new" && mv "$dir/VERSION.new" "$dir/VERSION"
  log "updated $name $LOCAL -> $REMOTE"

  CHG=$(head -n 12 "$dir/CHANGELOG.md" 2>/dev/null)
  NOTICE="$NOTICE
[claude-skills updated] $name v$LOCAL -> v$REMOTE (backup: $BAK)${CHG:+. Changelog:
$CHG}${CODE:+
Code/data files changed but NOT auto-updated:$CODE — re-run the claude-skills install.sh to apply them.}"
done

if [ "$MISMATCH" = 1 ]; then      # likely CDN lag between manifest and files: allow a quick retry, bounded
  n=$(cat "$FAILS" 2>/dev/null | head -n1); case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -lt 3 ]; then echo $((n+1)) > "$FAILS"; rm -f "$STAMP"; fi
else rm -f "$FAILS"; fi

[ -n "$NOTICE" ] && printf '%s\n' "${NOTICE#?}"
exit 0
