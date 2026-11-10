# claude-skills

Personal Claude Code skills. Each skill lives in its own directory.

| Skill | Description |
| --- | --- |
| [loop-engineer](loop-engineer/) | Do-check-redo loop until the task passes. Survives compaction/idle via on-disk memory + hooks, self-updates. Manual invoke via `/loop-engineer`. |

## loop-engineer

```
git clone https://github.com/sirawnoire-cloud/claude-skills && ./claude-skills/loop-engineer/install.sh
```

`install.sh` copies the skill to `~/.claude/skills/loop-engineer/`, the hooks to `~/.claude/hooks/`, and merges three hook entries (SessionStart, PreCompact, UserPromptSubmit) into `~/.claude/settings.json` (backup: `settings.json.bak-loop-engineer`; other hooks untouched; idempotent).

- Self-update: at SessionStart the skill text (SKILL.md/VERSION/CHANGELOG.md) is refreshed from this repo if `VERSION` is newer (sha256-checked against `manifest.txt`, at most every 6h). Disable with `LOOP_ENGINEER_NO_UPDATE=1`. Hook scripts are never auto-updated; re-run `install.sh` for those.
- Maintainers: bump `loop-engineer/VERSION`, add a CHANGELOG entry, run `loop-engineer/release.sh` to regenerate `manifest.txt`, then push.
