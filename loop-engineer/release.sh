#!/usr/bin/env bash
# Regenerate manifest.txt (sha256 of the auto-updatable skill files). Run before every push.
set -eu
cd "$(dirname "$0")"
: > manifest.txt
for f in SKILL.md VERSION CHANGELOG.md; do
  printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f" >> manifest.txt
done
cat manifest.txt
