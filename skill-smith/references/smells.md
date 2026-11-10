# Skill smells

Check every draft against this list before Phase 4, and use it as the rubric in Review mode. Ordered
by how much each one actually costs.

## 1. Vague description — the skill never fires

The most expensive failure, because it's invisible: the skill is fine, it just never gets selected,
and nobody finds out. The description is the only thing the model sees at selection time.

- Bad: `description: Helps with testing.`
- Good: `description: Write and run tests for changed code. Use when the user asks to add tests, says coverage is missing, mentions a bug that needs a regression test, or asks to verify a change works.`

Name the situations *and* the literal words. If it doesn't contain the phrases a user would type,
rewrite it.

## 2. Two skills competing for the same request

Nothing errors. The model just loads the wrong one, and the symptom the user sees is "it did something
weird." Before installing anything, read the description of every adjacent installed skill and confirm
no request could reasonably match both. If one could, merge them or narrow both triggers explicitly —
"use this for X, not Y; for Y use `other-skill`" in each description.

## 3. Everything in SKILL.md

The body loads in full on every invocation, so its length is a per-run tax. A 900-line body that could
have been a 150-line procedure plus four reference files costs ~6x on every fire for detail that's
needed maybe once in five runs. Push branches, tables, and examples into `references/` and name them
from the body.

## 4. Prose doing a script's job

"Count the entries and check each one parses as JSON" is a script. Written as prose it's slower, more
expensive, and occasionally wrong. Anything with an objectively correct answer — validating, counting,
parsing, transforming, checking existence — goes in `scripts/`. Keep prose for judgment.

## 5. Imperatives with no reasoning

"Always use approach X" tells the model what to do in the case you imagined and nothing at all about
the case you didn't. "Use approach X, because Y breaks when the input is streamed" lets it recognize a
sibling situation and adapt. Every non-obvious instruction should carry its *why* — that's what makes
a skill robust rather than brittle.

## 6. No stated boundary

A skill that says when to fire but never when *not* to will bleed into neighboring requests. One
sentence fixes it.

## 7. No failure modes

The sections that make a mature skill good are the ones naming the specific wrong turn this task
invites. `ea-builder` says don't retune a mismatched indicator, because that wasted whole runs.
`loop-engineer` lists ways an executor games its own criteria, because it did. If the user has watched
this task go wrong before, get that story into the skill in their words.

## 8. Asking what should be derived

Every question is friction. If the answer is inferable from the conversation, the repo, or the task's
own nature, derive it and *state what you derived* in one line so it's correctable — don't ask.
Reserve questions for decisions where guessing wrong would waste real work.

## 9. Success criteria you can't check

"Make sure it's good" is not a criterion. "The test suite passes, and the new function handles empty
input" is. If the skill can't tell whether a run succeeded, neither can the model running it.

## 10. Frozen paths and versions

Hardcoded absolute paths, machine-specific directories, pinned versions that will age out. Read them
from the environment, or gather them once into a small config file the skill reuses — the way
`ea-builder` keeps connection details in `.ea-builder-pc.json` instead of inlining an IP.

## 11. Auto-invocable when it shouldn't be

Expensive, destructive, long-running, or strongly opinionated skills firing uninvited is a bad
surprise. `disable-model-invocation: true` and let the user choose deliberately.

## 12. Documentation voice

A skill is read at runtime by the model that will act on it, not by a human browsing docs. "This skill
provides functionality for..." is wasted space. Address the actor, in the imperative, and get to the
procedure.
