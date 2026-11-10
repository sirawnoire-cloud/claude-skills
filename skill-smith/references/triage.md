# Triage: is this actually a skill?

## The decision table

| What the user describes | Build this | Why not a skill |
|---|---|---|
| "Every time X happens, do Y" / "always" / "never forget to" | **Hook** | A skill fires when the model judges it relevant. That judgment is good, not perfect. If a miss is unacceptable, the harness has to enforce it — and only hooks are enforced. |
| "Remember that I use pnpm" / "our API base is X" | **Memory** or `CLAUDE.md` | A fact, not a procedure. Skills answer *how*; this answers *what is true*. |
| One prompt they retype, no branching, no reference material | **Slash command** | A skill's overhead buys supporting files and conditional logic. A five-line prompt uses neither. |
| "Go read the whole codebase and report back" | **Subagent** | Needs its own context window. A skill runs inside the current one and inherits its pollution. |
| "Do this across 30 files independently" | **Workflow** or parallel subagents | Fan-out is orchestration, not procedure. |
| A multi-step procedure with judgment calls, house-specific knowledge, and known failure modes | **Skill** | This is the actual shape a skill fits. |

## The three questions that settle most cases

**Does it need to fire without fail?** Yes → hook. A skill is *offered* to the model, and a well-written
description makes that offer land nearly always — but "nearly" is the whole distinction. Compliance
requirements, safety gates, and anything the user phrases as "make sure you never" belong in a hook.

**Is there a procedure at all?** If the user can't walk through one concrete run of it, there's nothing
to write down yet. Say that plainly instead of interviewing harder — more questions won't create a
procedure that doesn't exist. Suggest they do the thing manually two or three times and come back with
what they actually did.

**Would the model do this well anyway?** Test it before building. Genuinely ask whether the default
behavior is already fine. If it is, a skill adds tokens on every invocation and, worse, risks making
the behavior *narrower* than it was — over-specification is a real regression, not a neutral one.

## Borderline cases

**"It mostly works but sometimes goes wrong."** Often the best skill there is a short one: just the
failure modes and the checks, not a full re-specification of a task the model already handles. Write
the corrective, skip the tutorial.

**"I want it to know our conventions."** Split it. Stable facts (naming, structure, forbidden
patterns) go in `CLAUDE.md`, where they're always loaded. The *procedure* that applies them goes in a
skill. Putting conventions in a skill hides them until the skill fires; putting a procedure in
`CLAUDE.md` pays for it on every single message.

**"There's already a skill close to this."** Almost always extend the existing one. Two skills with
overlapping descriptions is the worst outcome available here: nothing errors, the model just silently
picks the wrong one, and the user can't see why. Split into two skills only when the triggers are
genuinely disjoint — different words, different situations, no request that could reasonably want
both.

**"It's a whole workflow with several phases."** One skill with phases, or several skills plus a
coordinator? Prefer one skill if the phases always run together in order; prefer separate skills if
the user would ever want to start at phase three. Splitting a strictly-sequential workflow just
multiplies descriptions that compete with each other.

## When the verdict is "not a skill"

Say it in a line or two, name what to build instead, and offer to build that. Don't stop at the
refusal — the user came with a real problem, and the shape of the answer changing doesn't make the
problem go away.

If they hear the verdict and still want a skill, build the skill. It's their call, the reasoning is
on record, and being right about the shape is worth less than them having the thing they asked for.
