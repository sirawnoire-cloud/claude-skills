#!/usr/bin/env bash
# Mechanically validate a skill directory. Usage: validate.sh <skill-dir>
# Exits 0 if all checks pass, 1 otherwise. Warnings alone do not fail.
set -uo pipefail

DIR="${1:-}"
[ -n "$DIR" ] || { echo "usage: validate.sh <skill-dir>"; exit 1; }
DIR="${DIR%/}"
SKILL="$DIR/SKILL.md"
FAIL=0
err()  { echo "FAIL: $*"; FAIL=1; }
warn() { echo "WARN: $*"; }
ok()   { echo "ok:   $*"; }

[ -f "$SKILL" ] || { echo "FAIL: no SKILL.md at $SKILL"; exit 1; }

# --- frontmatter block ---
if [ "$(head -1 "$SKILL")" != "---" ]; then
  err "SKILL.md must start with '---' on line 1"
  FM=""
else
  FM_END=$(awk 'NR>1 && /^---[[:space:]]*$/ {print NR; exit}' "$SKILL")
  if [ -z "$FM_END" ]; then
    err "frontmatter is never closed with '---'"
    FM=""
  else
    FM=$(sed -n "2,$((FM_END-1))p" "$SKILL")
    ok "frontmatter parses (lines 2-$((FM_END-1)))"
  fi
fi

# --- name ---
NAME=$(printf '%s\n' "$FM" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'"' \r')
BASE=$(basename "$DIR")
if [ -z "$NAME" ]; then
  err "frontmatter has no 'name:'"
else
  if printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    ok "name '$NAME' is valid kebab-case"
  else
    err "name '$NAME' must be lowercase kebab-case (a-z, 0-9, hyphens)"
  fi
  [ "${#NAME}" -le 64 ] || err "name is ${#NAME} chars (max 64)"
  if [ "$NAME" = "$BASE" ]; then ok "name matches directory"
  else err "name '$NAME' does not match directory '$BASE'"; fi
fi

# --- description ---
DESC=$(awk '/^description:/{f=1} f{print} f && /^[a-z-]+:/ && !/^description:/{exit}' "$SKILL" \
       | sed -n '/^description:/,$p' | head -20)
DESC_ONE=$(printf '%s\n' "$FM" | sed -n 's/^description:[[:space:]]*//p' | head -1)
if printf '%s\n' "$FM" | grep -q '^description:'; then
  BODY_DESC=$(printf '%s\n' "$FM" | awk '/^description:/{f=1;sub(/^description:[[:space:]]*/,"")} f{if(/^[a-zA-Z_-]+:[[:space:]]/ && !/^description:/)exit; print}')
  LEN=$(printf '%s' "$BODY_DESC" | tr -d '\n' | wc -c | tr -d ' ')
  if [ "$LEN" -eq 0 ]; then
    err "'description:' is empty"
  elif [ "$LEN" -gt 1024 ]; then
    err "description is $LEN chars (max 1024)"
  else
    ok "description present ($LEN chars)"
    [ "$LEN" -ge 40 ] || warn "description is only $LEN chars — likely too vague to trigger reliably"
    printf '%s' "$BODY_DESC" | grep -Eqi 'use[sd]? (this )?(when|for)|used? (this )?(when|for)|invoke|trigger|manual invoke' \
      || warn "description never says WHEN to use it — add the situations and the literal words a user would type"
  fi
else
  err "frontmatter has no 'description:'"
fi

# --- disable-model-invocation consistency ---
if printf '%s\n' "$FM" | grep -Eq '^disable-model-invocation:[[:space:]]*true'; then
  printf '%s\n' "$FM" | grep -qi 'manual invoke' \
    || warn "disable-model-invocation is true but the description doesn't say 'Manual invoke only — use /$NAME'"
fi

# --- body size ---
BODY_LINES=$(($(wc -l < "$SKILL") - ${FM_END:-0}))
if [ "$BODY_LINES" -le 0 ]; then
  err "SKILL.md has no body after the frontmatter"
elif [ "$BODY_LINES" -gt 500 ]; then
  warn "body is $BODY_LINES lines (>500) — push detail into references/ to cut per-invocation cost"
else
  ok "body is $BODY_LINES lines"
fi

# --- referenced files exist ---
# Capture the WHOLE token, so an absolute cross-skill path isn't mistaken for a local one.
for REF in $(grep -oE '[~/A-Za-z0-9._-]*(references|templates|scripts|assets)/[A-Za-z0-9._/-]+' "$SKILL" | sort -u); do
  case "$REF" in
    "~"/*|/*)                                   # absolute — resolve as-is
      ABS="${REF/#\~/$HOME}"
      [ -e "$ABS" ] && ok "external ref exists: $REF" \
                    || err "SKILL.md references '$REF' but that path does not exist"
      ;;
    references/*|templates/*|scripts/*|assets/*)  # local to this skill
      [ -e "$DIR/$REF" ] && ok "referenced file exists: $REF" \
                         || err "SKILL.md references '$REF' but $DIR/$REF does not exist"
      ;;
    *) ;;                                        # relative to something else — not ours to check
  esac
done

# --- scripts executable ---
if [ -d "$DIR/scripts" ]; then
  for S in "$DIR"/scripts/*.sh; do
    [ -e "$S" ] || continue
    [ -x "$S" ] && ok "executable: scripts/$(basename "$S")" \
                || warn "scripts/$(basename "$S") is not executable (chmod +x)"
  done
fi

# --- name collisions with installed skills ---
for ROOT in "$HOME/.claude/skills" ".claude/skills"; do
  [ -d "$ROOT" ] || continue
  for OTHER in "$ROOT"/*/; do
    [ -d "$OTHER" ] || continue
    OB=$(basename "${OTHER%/}")
    [ "$(cd "${OTHER%/}" 2>/dev/null && pwd)" = "$(cd "$DIR" 2>/dev/null && pwd)" ] && continue
    [ "$OB" = "$NAME" ] && err "name '$NAME' collides with an installed skill at ${OTHER%/}"
  done
done
[ "$FAIL" -eq 0 ] && ok "no name collision with installed skills"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "PASS — mechanical validation clean. Gate 1 done; now run the Gate 2 dry-run."
  exit 0
else
  echo "FAILED — fix the FAIL lines above and re-run."
  exit 1
fi
