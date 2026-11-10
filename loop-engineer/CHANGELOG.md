# Changelog

## 0.2.5
- SKILL.md: new "Delegation (subagents)" section — default is no subagents; when worth it, executor-side and judge-side rules, never trust agent reports, record pending/returned agents in state/memory so compaction cannot lose them. Rules digest gets a matching line.
- New `verify-diff.sh` (snapshot / check / clean): deterministic diff vs a snapshot, flags out-of-scope changes and deleted/modified tests. Works in git and non-git dirs. NOT auto-updated and not a hook change — re-run `install.sh` to get it; SKILL.md falls back to `git diff --stat` if it is missing.

## 0.2.4
- HOOKS CHANGED — re-run `install.sh`: when the skill was updated or a loop's `skill_version` is stale, hooks inject the full current rules text (SKILL.md minus frontmatter, ~14 KB) with a "replaces any earlier copy" header, instead of only asking the model to re-read the file. SessionStart does it every time it fires; the prompt hook does it once per installed version per project. Only while a loop is in progress (no loop = no extra tokens).

## 0.2.3
- HOOKS CHANGED — re-run `install.sh`: state file records `skill_version`; SessionStart/prompt hooks compare it with the installed version and, if the skill was updated mid-loop, tell the model to refresh the Rules digest in the memory file and continue (no restart).
- SKILL.md: documents `skill_version` and the `[loop-engineer rules changed]` handling.

## 0.2.2
- HOOKS CHANGED — re-run `install.sh`: updates and loop recoveries now show a one-line user-visible `systemMessage`; each applied update is appended to `~/.claude/skills/loop-engineer/update.log`.

## 0.2.1
- HOOKS CHANGED — re-run `install.sh` (hook scripts are never auto-updated): the UserPromptSubmit hook now also runs the self-update check (throttled to once per 6h), so long-lived sessions get updates without a restart.
- Update stamp is touched before fetching, so an offline check cannot slow every prompt; update notice only asks for a SKILL.md re-read when a loop is in progress.

## 0.2.0
- Memory on disk: new `.loop-engineer-memory.md` (rules digest, goal, done, decisions, failed attempts, next); state gains `phase`, `step`, `evaluator`, `updated_at`.
- Checkpoint after every meaningful step (not only at iteration end); re-anchor rule at each iteration and after compaction.
- Removed the wrong claim that long conversations "need nothing extra".
- Run-log check skipped when a state file for the same task exists (continuation is not a repeat).
- Hooks (installed via install.sh, NOT auto-updated): SessionStart recover + self-update, PreCompact instructions, UserPromptSubmit nudge.
- Self-update of skill text (SKILL.md, VERSION, CHANGELOG.md) from GitHub, sha256-verified, throttled to once per 6h, kill-switch `LOOP_ENGINEER_NO_UPDATE=1`.

## 0.1.0
- Baseline: do-check-redo loop, mixed evaluator, guardrails, state file, run log.
