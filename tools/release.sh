#!/usr/bin/env bash
# Regenerate manifest.json for every skill directory (a dir with SKILL.md + VERSION) in this repo.
# manifest "auto": true  => file may be auto-updated by the sync hook (text only: *.md and VERSION)
#                  false => code/data (scripts, hooks, json...): never auto-updated; users re-run install.sh
set -eu
cd "$(dirname "$0")/.."
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
out=$(mktemp)
echo '{"schema":1,"skills":{}}' > "$out"
for d in */; do
  s="${d%/}"
  [ -f "$s/SKILL.md" ] && [ -f "$s/VERSION" ] || continue
  ver=$(tr -d '[:space:]' < "$s/VERSION")
  printf '%s' "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "bad VERSION in $s: '$ver'" >&2; exit 1; }
  files=$(mktemp); : > "$files"
  while IFS= read -r f; do
    rel="${f#"$s"/}"
    auto=false; case "$rel" in VERSION|*.md) auto=true ;; esac
    jq -nc --arg p "$rel" --arg h "$(shasum -a 256 "$f" | cut -d' ' -f1)" --argjson a "$auto" --argjson z "$(wc -c < "$f" | tr -d ' ')" \
      '{path:$p,sha256:$h,auto:$a,size:$z}' >> "$files"
  done < <(find "$s" -type f ! -name .DS_Store ! -name .last-check ! -name update.log ! -path '*/.bak-*' ! -path '*/node_modules/*' ! -name manifest.txt | LC_ALL=C sort)
  jq --arg n "$s" --arg v "$ver" --slurpfile f "$files" '.skills[$n]={version:$v,files:$f}' "$out" > "$out.new" && mv "$out.new" "$out"
  rm -f "$files"
done
mv "$out" manifest.json
# legacy format for already-installed loop-engineer <= 0.3.x updaters
if [ -f loop-engineer/VERSION ]; then
  : > loop-engineer/manifest.txt
  for f in SKILL.md VERSION CHANGELOG.md; do printf '%s  %s\n' "$(shasum -a 256 "loop-engineer/$f" | cut -d' ' -f1)" "$f" >> loop-engineer/manifest.txt; done
fi
jq -r '.skills | to_entries[] | "\(.key) \(.value.version) (\(.value.files|length) files, \([.value.files[]|select(.auto)]|length) auto)"' manifest.json
