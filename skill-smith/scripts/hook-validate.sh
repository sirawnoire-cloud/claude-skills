#!/usr/bin/env bash
# PostToolUse hook: mechanically validate a skill whenever one of its files is written or edited.
#
# Design notes:
#  - Silent when the skill is valid. A hook that talks when nothing is wrong gets ignored, and then
#    it isn't read when something IS wrong.
#  - Never fails the session. Any internal problem exits 0 quietly — a broken validator must not
#    become a broken editing experience.
#  - Missing referenced files are advisory, not blocking: writing SKILL.md before the references/
#    files it points at is a normal intermediate state during authoring.
exec python3 "$HOME/.claude/skills/skill-smith/scripts/hook_validate.py"
