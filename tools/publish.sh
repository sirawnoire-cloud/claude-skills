#!/usr/bin/env bash
# Copy a skill you maintain in ~/.claude/skills/<name> into this repo, sanitize, scan for secrets/emails,
# bump VERSION, regenerate manifest.json. Does NOT commit or push.
#   tools/publish.sh <skill> [--bump patch|minor|major|none] [-m "changelog line"] [--first VERSION]
# (loop-engineer is mastered in this repo; edit it here, then run tools/release.sh.)
set -eu
cd "$(dirname "$0")/.."
SK="${1:-}"; shift || true
[ -n "$SK" ] || { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
BUMP=patch; MSG=""; FIRST=""
while [ $# -gt 0 ]; do case "$1" in --bump) BUMP="$2"; shift 2 ;; -m) MSG="$2"; shift 2 ;; --first) FIRST="$2"; shift 2 ;; *) echo "unknown arg $1" >&2; exit 2 ;; esac; done
SRC="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/$SK"
[ "$SK" = "loop-engineer" ] && { echo "loop-engineer is mastered in this repo; just edit it and run tools/release.sh" >&2; exit 2; }
[ -L "$SRC" ] && { echo "$SK is a symlink (third-party?) — not publishing" >&2; exit 2; }
[ -d "$SRC/.git" ] && { echo "$SK has its own .git repo (someone else's?) — not publishing" >&2; exit 2; }
[ -f "$SRC/SKILL.md" ] || { echo "$SRC/SKILL.md not found" >&2; exit 2; }
mkdir -p "$SK"
rsync -a --delete --exclude .git --exclude .DS_Store --exclude .last-check --exclude update.log --exclude '.bak-*' --exclude node_modules \
  --filter='P VERSION' --filter='P CHANGELOG.md' "$SRC/" "$SK/"

# sanitize known personal data in the PUBLISHED copy only (your local files are untouched)
if [ -f "$SK/scripts/hook_validate.py" ]; then
  python3 - "$SK/scripts/hook_validate.py" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
# drop any hardcoded git author; use $SKILL_SMITH_COMMIT_AUTHOR if the user sets one
n=re.sub(r'\["git", "-C", repo_root, "commit", "--author=[^"]*", "-m", msg\],',
         '["git", "-C", repo_root, "commit"] + (["--author=" + __import__("os").environ["SKILL_SMITH_COMMIT_AUTHOR"]] if __import__("os").environ.get("SKILL_SMITH_COMMIT_AUTHOR") else []) + ["-m", msg],', s)
open(p,'w').write(n)
PY
fi

# scan: secrets + any email address except noreply@anthropic.com
HITS=$(grep -rInE --exclude-dir=.git --exclude='*.png' --exclude='*.jpg' \
  '(sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,}|gh[pous]_[A-Za-z0-9]{30,}|xox[abp]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|bearer [A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,})' "$SK" | grep -v 'noreply@anthropic.com' | head -10 || true)
if [ -n "$HITS" ]; then echo "REFUSING: possible secret / personal data in $SK:" >&2; echo "$HITS" >&2; exit 3; fi

cur="0.0.0"; [ -f "$SK/VERSION" ] && cur=$(tr -d '[:space:]' < "$SK/VERSION")
if [ -n "$FIRST" ]; then new="$FIRST"
else
  IFS=. read -r a b c <<< "$cur"
  case "$BUMP" in major) new="$((a+1)).0.0" ;; minor) new="$a.$((b+1)).0" ;; patch) new="$a.$b.$((c+1))" ;; none) new="$cur" ;; *) echo "bad --bump" >&2; exit 2 ;; esac
fi
echo "$new" > "$SK/VERSION"
if [ -n "$MSG" ]; then
  [ -f "$SK/CHANGELOG.md" ] || printf '# Changelog\n' > "$SK/CHANGELOG.md"
  python3 - "$SK/CHANGELOG.md" "$new" "$MSG" <<'PY'
import sys
p,v,m=sys.argv[1:4]; s=open(p).read()
s=s.replace('# Changelog\n','# Changelog\n\n## %s\n- %s\n' % (v,m),1) if s.startswith('# Changelog') else '# Changelog\n\n## %s\n- %s\n\n%s' % (v,m,s)
open(p,'w').write(s)
PY
fi
tools/release.sh >/dev/null
# keep the local copy's VERSION/CHANGELOG in step so the updater tracks it
cp "$SK/VERSION" "$SRC/VERSION"; [ -f "$SK/CHANGELOG.md" ] && cp "$SK/CHANGELOG.md" "$SRC/CHANGELOG.md" || true
echo "published $SK $cur -> $new (not committed). Review: git status && git diff --stat"
