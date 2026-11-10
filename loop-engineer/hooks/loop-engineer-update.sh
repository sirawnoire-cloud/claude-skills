#!/usr/bin/env bash
# loop-engineer self-update. Called by loop-engineer-recover.sh (SessionStart).
# Updates ONLY the skill text (SKILL.md, VERSION, CHANGELOG.md). Hook scripts are never
# auto-replaced (that would be remote code execution) — re-run install.sh to update them.
# Prints a one-paragraph notice on stdout iff an update was applied. Silent on any failure.
set -u
[ "${LOOP_ENGINEER_NO_UPDATE:-}" = "1" ] && exit 0

SKILL_DIR="${LOOP_ENGINEER_SKILL_DIR:-$HOME/.claude/skills/loop-engineer}"
REPO_RAW="${LOOP_ENGINEER_REPO_RAW:-https://raw.githubusercontent.com/sirawnoire-cloud/claude-skills/main/loop-engineer}"
INTERVAL_MIN=$(( ${LOOP_ENGINEER_UPDATE_INTERVAL:-21600} / 60 ))
STAMP="$SKILL_DIR/.last-check"

command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || exit 0
[ -d "$SKILL_DIR" ] || exit 0

# throttle
if [ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mmin "-$INTERVAL_MIN" 2>/dev/null)" ]; then exit 0; fi

fetch() { curl -fsS --connect-timeout 2 --max-time 5 "$1" 2>/dev/null; }
semver='^[0-9]+\.[0-9]+\.[0-9]+$'

REMOTE=$(fetch "$REPO_RAW/VERSION" | tr -d '[:space:]') || exit 0
printf '%s' "$REMOTE" | grep -Eq "$semver" || exit 0
touch "$STAMP" 2>/dev/null || true

LOCAL=$(tr -d '[:space:]' < "$SKILL_DIR/VERSION" 2>/dev/null || echo 0.0.0)
printf '%s' "$LOCAL" | grep -Eq "$semver" || LOCAL=0.0.0
[ "$REMOTE" = "$LOCAL" ] && exit 0
# only move forward
[ "$(printf '%s\n%s\n' "$LOCAL" "$REMOTE" | sort -V | head -n1)" = "$LOCAL" ] || exit 0

TMP=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$TMP"' EXIT
fetch "$REPO_RAW/manifest.txt" > "$TMP/manifest.txt" || exit 0

# manifest lines: "<sha256>  <name>", name must be one of the allowed skill files
ALLOWED='^(SKILL\.md|VERSION|CHANGELOG\.md)$'
GOT=""
while read -r sha name; do
  printf '%s' "$name" | grep -Eq "$ALLOWED" || continue
  printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || continue
  fetch "$REPO_RAW/$name" > "$TMP/$name" || exit 0
  [ "$(shasum -a 256 "$TMP/$name" | cut -d' ' -f1)" = "$sha" ] || exit 0
  GOT="$GOT $name"
done < "$TMP/manifest.txt"
case " $GOT " in *" SKILL.md "*) ;; *) exit 0 ;; esac
case " $GOT " in *" VERSION "*) ;; *) exit 0 ;; esac
[ "$(tr -d '[:space:]' < "$TMP/VERSION")" = "$REMOTE" ] || exit 0

# backup then atomic replace (VERSION last)
BAK="$SKILL_DIR/.bak-$LOCAL"; mkdir -p "$BAK" 2>/dev/null
for f in SKILL.md CHANGELOG.md VERSION; do [ -f "$SKILL_DIR/$f" ] && cp "$SKILL_DIR/$f" "$BAK/$f"; done
for f in SKILL.md CHANGELOG.md VERSION; do
  [ -f "$TMP/$f" ] && mv "$TMP/$f" "$SKILL_DIR/$f.new" && mv "$SKILL_DIR/$f.new" "$SKILL_DIR/$f"
done

CHG=$(head -n 15 "$SKILL_DIR/CHANGELOG.md" 2>/dev/null)
printf '[loop-engineer updated] v%s -> v%s (backup: %s). Changelog:\n%s\nRe-read %s/SKILL.md now (rules changed) and, if a loop-engineer loop is in progress, apply them and continue it. Hook scripts are not auto-updated; re-run install.sh from the repo if the changelog says hooks changed.\n' \
  "$LOCAL" "$REMOTE" "$BAK" "$CHG" "$SKILL_DIR"
