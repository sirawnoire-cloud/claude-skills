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

## Surviving a hard cutoff (usage limit)

A long conversation needs nothing extra — the harness auto-compresses context and the loop just continues. This section is only for a *hard* cutoff: the session dies mid-loop and a brand-new session (no memory of this chat) has to pick up later. That new session can't read the old chat, so the source of truth has to live outside it, on disk.

State file: `.loop-engineer-state.json` at the project root (the same repo/directory the task is in — never a global path, this is task-specific and disposable).

- **Write it after every iteration**, pass or fail: `{task, criteria, max_iterations, iteration, baseline, last_feedback}`. Keep every field a short, human-readable gist, never a raw dump — `last_feedback` is a sentence or two on what was tried and why it fell short, not pasted output/logs/data. The file only works as a resume point if loading it back is cheap; if writing it ever tempts you to paste something large, summarize instead.
- **On invoke, before doing anything else**, check for this file:
  - The conversation already has a clear current task and this file's `task` doesn't match it → ignore/overwrite, start fresh at iteration 1.
  - The conversation has no task yet (a bare invoke in a fresh session) and this file exists → there's nothing to match against, so treat the file's own `task` as the one to resume; state it back to the user in one line so they know what's continuing.
  - Either way it's a match → this is a resume, not a fresh start. Don't reset to iteration 1 and don't revert to `baseline` — the code as it currently sits (already partly fixed) is the new starting point. Re-run the evaluator immediately before doing anything else, since the cutoff may have hit right after a fix that was never actually checked. Continue the loop from the recorded iteration count, not from 1.
- **Delete the file** the instant the loop ends — pass, or the final report at max_iterations. A leftover file must never leak into a later, unrelated task.

## Remembering past runs (across sessions, not just mid-loop)

The state file above only exists while a loop is *in progress* — it's deleted the moment one finishes, so it can't answer "did I already loop-engineer this?" days or sessions later. That's a different question from resuming a cutoff, and it's the more common one in practice: the human simply forgets whether they already ran this.

Log file: `.loop-engineer-log.jsonl` at the project root — append-only, never deleted by this skill.

- **On invoke, before doing anything else** (even before touching the state file above), grep this log for a task that matches or closely overlaps the current one.
  - No match → proceed normally.
  - Match found → stop and tell the user: when it ran, what the result was (pass/fail), and ask whether to run it again anyway. Don't silently re-run — that's exactly the wasted/confusing repeat this check exists to prevent.
- **Append one line the instant the loop ends** (pass, or the final report at max_iterations): `{task, criteria, result, iterations_used, timestamp}`. Append, never overwrite — this is a history, not a state snapshot.

## Loop

```
before iteration 1: check the run log for a prior match (see above); if none, check
                     for a resume state file; if neither, record a baseline (git diff /
                     files about to be touched) so a regressed end-state can be
                     identified and reverted if the run finishes worse than it started

iteration = 1 (or the resumed count, from the state file)
loop:
  run executor (on iteration > 1, feed it the prior evaluator feedback)
  run evaluator → pass/fail + reason
  write/overwrite the state file with this iteration's result
  report the iteration result to the user in one line: "iter N: pass/fail — reason"
  if pass: delete state file, append run log, stop, report done
  if iteration == max_iterations: delete state file, append run log, stop, see "Final report" below
  iteration += 1
```

Stop immediately and ask the user if two consecutive iterations fail for the *same* reason — that signals the criteria or approach needs a human call, not another retry.

### Final report (max_iterations reached without pass)

Never claim pass. Give the user something actionable, not just "failed":

- What still fails, specifically (which check, which edge case, which part of the criteria)
- What was tried across the 3 iterations and why each attempt didn't clear it
- A concrete suggested next step (a different approach, a criteria that may be unreachable as stated, or a spot that needs human judgment)
- Whether the current state is safe to leave as-is or should be reverted to the baseline

For heavier fan-out (many independent files/checks per iteration, or isolation needed because attempts mutate files that would collide), use the Workflow tool's loop-until pattern instead of doing this inline — same three-part shape, just orchestrated.
