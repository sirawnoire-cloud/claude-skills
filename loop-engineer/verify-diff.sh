#!/usr/bin/env bash
# loop-engineer: deterministic check of what actually changed on disk (do not trust subagent reports).
#
#   verify-diff.sh snapshot                     record file hashes (run once, before the first delegation)
#   verify-diff.sh check [--allow GLOB]...      compare disk with the snapshot
#   verify-diff.sh clean                        remove the snapshot (loop finished)
#
# check prints A/M/D lines and flags:
#   VIOLATION  file changed outside every --allow glob (only if --allow was given; `*` matches `/`)
#   VIOLATION  a test file was deleted
#   WARN       a test file was modified (review the diff: weakened assertions? skipped tests?)
#   WARN       any other deletion
# Exit: 0 no violations, 1 violations found, 2 usage/error. Works in git and non-git directories.
set -u
SNAP=".loop-engineer-snapshot.tsv"
CAP=20000; BIG=5242880
cmd="${1:-}"; shift || true

list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard 2>/dev/null
  else
    find . -type d \( -name .git -o -name node_modules -o -name .venv -o -name __pycache__ -o -name dist -o -name build -o -name .next -o -name target \) -prune -o -type f -print 2>/dev/null | sed 's|^\./||'
  fi | grep -v -E '^\.loop-engineer-|(^|/)(\.git|node_modules)/' | head -n "$CAP"
}

hash_all() {
  list_files | while IFS= read -r f; do
    [ -f "$f" ] || continue
    sz=$(wc -c < "$f" | tr -d ' ')
    if [ "$sz" -gt "$BIG" ]; then h="big:$sz:$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)"
    else h=$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1); fi
    printf '%s\t%s\n' "$f" "$h"
  done
}

is_test() {
  case "$1" in
    test/*|*/test/*|tests/*|*/tests/*|__tests__/*|*/__tests__/*|spec/*|*/spec/*|*.test.*|*.spec.*|*_test.*|test_*|*/test_*) return 0 ;;
  esac
  return 1
}

case "$cmd" in
  snapshot)
    hash_all > "$SNAP" || { echo "snapshot failed" >&2; exit 2; }
    n=$(wc -l < "$SNAP" | tr -d ' ')
    echo "snapshot: $n files recorded in $SNAP"
    [ "$n" -ge "$CAP" ] && echo "WARN: file cap ($CAP) reached; later files are not tracked"
    exit 0 ;;
  clean) rm -f "$SNAP"; echo "snapshot removed"; exit 0 ;;
  check)
    [ -f "$SNAP" ] || { echo "no snapshot ($SNAP); run: verify-diff.sh snapshot" >&2; exit 2; }
    allow=()
    while [ $# -gt 0 ]; do
      case "$1" in --allow) [ $# -ge 2 ] || { echo "--allow needs a value" >&2; exit 2; }; allow+=("$2"); shift 2 ;; *) echo "unknown arg: $1" >&2; exit 2 ;; esac
    done
    cur=$(mktemp); trap 'rm -f "$cur"' EXIT
    hash_all > "$cur"
    changes=$(awk -F'\t' 'NR==FNR{a[$1]=$2; next} {b[$1]=$2} END{for(k in b){if(!(k in a)) print "A\t" k; else if(a[k]!=b[k]) print "M\t" k} for(k in a) if(!(k in b)) print "D\t" k}' "$SNAP" "$cur" | sort -t$'\t' -k2)
    if [ -z "$changes" ]; then echo "no changes since snapshot"; exit 0; fi
    viol=0
    while IFS=$'\t' read -r st f; do
      echo "$st $f"
      if [ ${#allow[@]} -gt 0 ]; then
        ok=0; for g in "${allow[@]}"; do case "$f" in $g) ok=1; break ;; esac; done
        [ "$ok" = 0 ] && { echo "  VIOLATION: outside allowed scope"; viol=1; }
      fi
      if is_test "$f"; then
        [ "$st" = D ] && { echo "  VIOLATION: test file deleted"; viol=1; }
        [ "$st" = M ] && echo "  WARN: test file modified — review the diff for weakened/skipped assertions"
      elif [ "$st" = D ]; then
        echo "  WARN: file deleted"
      fi
    done <<< "$changes"
    [ ${#allow[@]} -eq 0 ] && echo "note: no --allow given, scope not checked"
    [ "$viol" = 1 ] && { echo "RESULT: violations found"; exit 1; }
    echo "RESULT: no violations"; exit 0 ;;
  *) echo "usage: verify-diff.sh snapshot | check [--allow GLOB]... | clean" >&2; exit 2 ;;
esac
