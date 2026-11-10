---
name: loop-engineer
description: Run a task through a do-check-redo loop until it passes, self-deriving both the task and its pass criteria from context. Manual invoke only — use /loop-engineer.
disable-model-invocation: true
---

Reusable across any project. Invoke as:

```
/loop-engineer <task, or blank to use the current conversation's task>
```

Don't ask the user to spell out `criteria` or `max_iterations` — derive both yourself:

- **Task**: whatever the user just asked for in this conversation, or the literal text passed to the command.
- **Criteria**: infer from the task's own nature before the first attempt — a code task implies tests/build/type-check must pass and existing behavior mustn't break; a writing task implies matching the tone/spec/requirements stated or implied earlier in the conversation; a data/config task implies the output validates against its schema or the stated constraint. State the criteria you inferred in one line before iterating, so the run is auditable — but don't stop to ask the user to confirm it.
- **max_iterations**: always 3. Fixed, no confirmation needed.

## Repeat invoke, same session

If `/loop-engineer` already ran earlier in this same conversation and this invoke names no new task (just bare `/loop-engineer` again), don't re-explain the whole framework or re-derive anything — the chat history already shows it's active here. Reply short: something like "loop-engineer here — give a task" and stop. Only run the full flow below when there's an actual task to act on, whether that's this invoke or the next message.

## Three parts, one session

- **Executor** — you, doing the task.
- **Evaluator** — you, judging the latest attempt against `criteria`.
- **Controller** — the loop below, deciding retry vs stop.

## Pick the evaluator per criteria (mixed mode)

Inspect `criteria` before the first attempt:

- Mentions a runnable check (tests, lint, build, type-check, a specific command, an exit code) → **rule-based**: actually run that command via Bash and read its real output. Never assert pass without running it.
- Mentions a qualitative bar (tone, clarity, matches a style, "make sense") → **LLM-judge**: read the output yourself and judge it against the stated bar, stating which part of the criteria it fails if it fails.
- Mentions both → run rule-based first (cheaper, deterministic); only spend a judge pass if that clears.

For code tasks specifically, passing the existing/stated tests is not enough. Before declaring pass, think through edge cases the task implies — empty/null input, boundary values, wrong type, concurrent access, empty collections — and check the code actually handles them (write a quick throwaway check if no test covers it). Note which edge cases you checked in the iteration report; don't just report the happy-path result.

Also run the **full** existing test suite, not only tests touching the changed area — a fix that passes its own new check but breaks something else does not count as pass.

For **web UI tasks**, the LLM-judge branch has a real rubric available — don't judge on impression.
Load `~/.claude/skills/ui-craft/references/rubric.md` and judge the attempt against it item by item,
returning which specific items failed and where. "Doesn't look good enough" gives the next iteration
nothing to act on; "tap targets are 32px on a mobile-primary layout, and submit has no loading state"
does. The UI form of criteria-gaming is making a screenshot look right while states, keyboard access,
and small-width layout stay broken — judge the rubric, not the screenshot.

## Guardrails against gaming the criteria

The executor is trying to clear the criteria as fast as possible, which creates pressure to cheat it rather than the actual problem. Watch for and refuse:

- Deleting, skipping, or weakening a failing test instead of fixing the code it tests
- Hardcoding an expected output instead of implementing the real logic
- Mocking or stubbing away the exact thing the criteria is checking
- Narrowing the criteria's scope mid-loop to make a partial fix count as pass

If the executor did any of these, treat it as a fail regardless of what the check reports, and say so in the iteration report.

## Guard against context-busting files

Before reading any file relevant to the task — via Read, cat, or otherwise loading its contents into the conversation — check its size first: `wc -l` for line count, or `ls -la` for bytes. Thousands of lines is a caution sign; tens of thousands or more, don't read it directly. This isn't hypothetical — a 99,999-row data file read straight into a session once caused it to hit the context limit and re-compact on nearly every following message, degrading the whole session past the point of being useful.

Past that threshold, reach for whatever narrow tool actually answers the question instead of a full read — `grep` for a pattern, `head`/`tail` for a slice, `wc`/`awk` for a count or aggregate, or a throwaway script that computes just the needed result and prints a short summary. Which one fits depends on what the task actually needs; pick per situation rather than forcing one fixed method every time. The only fixed rule is the outcome: the bulk of a huge file must never land in context — only the small, task-relevant result extracted from it should.

This applies to both the executor (doing the task) and the evaluator (checking the result) — a check that reads a huge reference/expected-output file in full falls into the same trap.

## Surviving compaction, idle, and hard cutoffs (memory on disk)

Compaction is lossy. After `/compact` (or auto-compact), a long idle, `--resume`, or a hard cutoff (usage limit), the conversation summary may drop the criteria, the plan, what is already done, which attempts failed, and even these rules. **The source of truth lives on disk, not in the chat.** Two files at the project root (the directory the task is in — never a global path; both are task-specific and disposable):

### `.loop-engineer-state.json` — machine state, small

`{skill_version, task, criteria, max_iterations, iteration, phase, step, evaluator, baseline, last_feedback, updated_at}`

- `skill_version`: the contents of `~/.claude/skills/loop-engineer/VERSION` when the loop was created (or last re-synced). Hooks compare it with the installed version to detect that the rules changed mid-loop.
- `phase`: `executor` | `evaluator` | `between` (iteration finished, next not started).
- `step`: one short line — exactly what you are doing or about to do.
- `evaluator`: `{mode: rule|judge|mixed, commands: [...], rubric: "<path or null>"}` so a fresh context knows what to run.
- `baseline`: git repos → "git diff clean" or the commit hash; non-git dirs → list of files about to be touched with their sha256/mtime. A short gist, never a raw dump.
- `last_feedback`: a sentence or two. Full history goes in the memory file.

### `.loop-engineer-memory.md` — progress memory (like a MEMORY.md)

Human-readable, short (aim under ~150 lines — it gets re-injected into context, so keep it cheap). Edit in place; don't just append forever. Sections:

```
## Rules digest        (copy this block verbatim — it survives even if the skill text is lost)
- max 3 iterations; stop+ask if 2 consecutive fails have the same reason
- evaluator: rule-based = actually run the command; LLM-judge = judge against criteria (web UI: ui-craft rubric); both = rule first
- code: check edge cases + run the FULL test suite
- never: delete/weaken tests, hardcode outputs, mock the thing under test, narrow the criteria
- never load huge files whole (check wc -l / ls -la first; grep/head/awk instead)
- on finish (pass or max_iterations): delete state + memory files, append one line to .loop-engineer-log.jsonl
## Goal & criteria
## Done               (checklist: finished steps, files touched)
## Decisions          (choice + why)
## Failed attempts    (per iteration: what was tried, why it fell short — so it is never repeated)
## Next               (the single next action)
```

### When to write

- **At every checkpoint**, not only at the end of an iteration: after finishing each meaningful step, before any long or risky operation (big refactor, long-running job, anything that might hit a limit), and right after each evaluator result. If context were wiped this second, the files must be enough to continue.
- Write order: update memory (`Done`/`Failed attempts`/`Next`) first, then state (`phase`/`step`/`iteration`).

### Re-anchor rule (this is what survives compaction)

- **At the start of every iteration**, and **any time the context starts with a compaction summary, or you are unsure what is already done**, read `.loop-engineer-state.json` and `.loop-engineer-memory.md` first (size-check per the guard above). Continue from `phase` / `step` / `Next`. Do not restart, do not re-derive criteria, do not repeat anything listed under `Done` or `Failed attempts`.
- If a hook injected a block starting with `[loop-engineer recovered]`, treat it as an authoritative resume: the user does **not** need to re-invoke `/loop-engineer`. Say in one line what is continuing (task, iteration, phase), then keep going.
- If a hook injected `[loop-engineer rules changed]` (the state file's `skill_version` differs from the installed version): re-read `~/.claude/skills/loop-engineer/SKILL.md`, rewrite the `## Rules digest` block in the memory file to match the new rules (keep every other section as is), set `skill_version` in the state file to the installed version, then continue the loop from where it was. Do not restart and do not reset the iteration count.
- If a hook injected `[loop-engineer updated]`, re-read `~/.claude/skills/loop-engineer/SKILL.md` (the rules changed), apply them to the in-progress loop, and continue.

### Resume semantics (new session or after compaction)

- Bare invoke in a fresh session with no task and a state file present → resume the file's `task`; state it back in one line.
- The conversation has a clear task that doesn't match the state file's `task` → ignore the old files, overwrite, start fresh at iteration 1.
- A match → resume, not a fresh start. Don't reset to iteration 1 and don't revert to `baseline` — the code as it currently sits is the new starting point. If `phase` is `executor` or `between`, or unsure, re-run the evaluator before doing anything else (the cutoff may have hit right after a fix that was never checked). Continue from the recorded iteration count.
- For a cutoff where the work itself should move to a brand-new session, the `handoff` skill can package the rest; the two files above are what it should point at.

### Finish

Delete both files the instant the loop ends — pass, or the final report at max_iterations. A leftover file must never leak into a later, unrelated task.

## Remembering past runs (across sessions, not just mid-loop)

The state/memory files only exist while a loop is *in progress* — they're deleted the moment one finishes, so they can't answer "did I already loop-engineer this?" days or sessions later. That's a different question from resuming, and it's the more common one in practice: the human simply forgets whether they already ran this.

Log file: `.loop-engineer-log.jsonl` at the project root — append-only, never deleted by this skill.

- **On a fresh invoke, before doing anything else**, grep this log for a task that matches or closely overlaps the current one. **Skip this check when a state file for the same task already exists** — that is a continuation, not a repeat, and must not be blocked.
  - No match → proceed normally.
  - Match found → stop and tell the user: when it ran, what the result was (pass/fail), and ask whether to run it again anyway. Don't silently re-run — that's exactly the wasted/confusing repeat this check exists to prevent.
- **Append one line the instant the loop ends** (pass, or the final report at max_iterations): `{task, criteria, result, iterations_used, timestamp, memory_summary}` — `memory_summary` is one or two sentences distilled from the memory file (what was done, what was left). Append, never overwrite — this is a history, not a state snapshot.

## Loop

```
before iteration 1: if a state file exists for this task → resume (see above), skip the log check;
                     else check the run log for a prior match; if none, record a baseline (see
                     `baseline`) and create the state + memory files (criteria, rules digest, Next)

iteration = 1 (or the resumed count, from the state file)
loop:
  re-anchor: read state + memory if this is not the very first iteration or context looks compacted
  run executor (on iteration > 1, feed it the prior evaluator feedback + Failed attempts);
      checkpoint memory + state after each meaningful step (phase=executor)
  run evaluator → pass/fail + reason (phase=evaluator)
  write memory (Done / Failed attempts / Next) then state (phase=between, iteration, last_feedback)
  report the iteration result to the user in one line: "iter N: pass/fail — reason"
  if pass: delete state + memory, append run log, stop, report done
  if iteration == max_iterations: delete state + memory, append run log, stop, see "Final report" below
  iteration += 1
```

Stop immediately and ask the user if two consecutive iterations fail for the *same* reason — that signals the criteria or approach needs a human call, not another retry. (Keep the state + memory files in this case — the user may tell you to continue.)

### Final report (max_iterations reached without pass)

Never claim pass. Give the user something actionable, not just "failed":

- What still fails, specifically (which check, which edge case, which part of the criteria)
- What was tried across the 3 iterations and why each attempt didn't clear it
- A concrete suggested next step (a different approach, a criteria that may be unreachable as stated, or a spot that needs human judgment)
- Whether the current state is safe to leave as-is or should be reverted to the baseline

For heavier fan-out (many independent files/checks per iteration, or isolation needed because attempts mutate files that would collide), use the Workflow tool's loop-until pattern instead of doing this inline — same three-part shape, just orchestrated.
