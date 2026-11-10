# Changelog

## 0.2.0
- Memory on disk: new `.loop-engineer-memory.md` (rules digest, goal, done, decisions, failed attempts, next); state gains `phase`, `step`, `evaluator`, `updated_at`.
- Checkpoint after every meaningful step (not only at iteration end); re-anchor rule at each iteration and after compaction.
- Removed the wrong claim that long conversations "need nothing extra".
- Run-log check skipped when a state file for the same task exists (continuation is not a repeat).
- Hooks (installed via install.sh, NOT auto-updated): SessionStart recover + self-update, PreCompact instructions, UserPromptSubmit nudge.
- Self-update of skill text (SKILL.md, VERSION, CHANGELOG.md) from GitHub, sha256-verified, throttled to once per 6h, kill-switch `LOOP_ENGINEER_NO_UPDATE=1`.

## 0.1.0
- Baseline: do-check-redo loop, mixed evaluator, guardrails, state file, run log.
