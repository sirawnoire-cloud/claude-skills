# Changelog

## 0.4.1
- SKILL.md only (auto-updates; no hook change): new "When the task itself is ambiguous" rule. Before iteration 1, if the task supports materially different readings that nothing in the conversation/repo/run log settles and a wrong guess is costly, ask ONE question with a recommended answer; otherwise infer, record "assumed: X", and go. Headless runs take the most conservative reading; mid-loop forks are decided and recorded unless irreversible. Rules digest gets a matching line.

## 0.4.0
- HOOKS CHANGED — re-run the repo's `install.sh`: skill self-update moved out of the loop-engineer hooks into a generic, separate `claude-skills-sync` hook (updates every skill installed from this repo, not just loop-engineer). `loop-engineer-update.sh` is removed; the recover/nudge hooks now only handle loop recovery and stale-rules detection (via `skill_version`).

## 0.3.0
- HOOKS CHANGED — re-run `install.sh` (adds 4 hooks: PreToolUse/PostToolUse on `Agent`, `SubagentStop`, `Stop`): Delegation rules are now enforced mechanically while a loop is active. Spawns are denied unless the prompt has the LOOP-ROLE/ALLOWED-FILES/GUARDRAILS (executor) or CRITERIA/ARTIFACTS (judge) headers; judge/research must use a read-only agent type; no nested agents; cap 5 per iteration; executor needs a snapshot.
- After an executor agent returns, the hook runs `verify-diff.sh check` itself and reports; every spawn/result is logged to `.loop-engineer-agents.jsonl` (shown after recovery); the Stop hook blocks finishing while a VIOLATION marker exists (guarded by `stop_hook_active`).
- Stop hook re-runs the check live (a stale marker never blocks), blocks at most `LOOP_ENGINEER_MAX_STOP_BLOCKS` (default 3) times, then lets the turn end with a user-visible warning. `LOOP_ENGINEER_DEBUG_LOG=<file>` makes the Pre/Post/Stop hooks log their decisions.
- Kill switch: `LOOP_ENGINEER_ENFORCE=0`. Tunables: `LOOP_ENGINEER_MAX_AGENTS`, `LOOP_ENGINEER_READONLY_AGENTS`.
- verify-diff.sh writes/clears `.loop-engineer-violation`.

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
