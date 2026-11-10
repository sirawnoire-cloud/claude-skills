---
name: skill-smith
description: Design, write, test, and install a Claude Code skill from a plain-language idea — including the prior question of whether the idea should be a skill at all. Also reviews and repairs skills that already exist. Manual invoke only — use /skill-smith.
disable-model-invocation: true
---

The meta-skill: it makes skills. Invoke as:

```
/skill-smith <idea, a skill name to review, or blank>
```

Reusable across any project. Default install target is `~/.claude/skills/<name>/` (personal — available in every project), matching where `loop-engineer` and `ea-builder` live.

## Pick the mode from what was passed

- **An idea, a capability, a workflow, a complaint about repetitive work** → *Build* mode. Run the whole flow below, starting with triage.
- **The name or path of a skill that already exists** → *Review* mode. Skip to "Review mode" near the bottom.
- **A bare name that is *not* an installed skill** — ambiguous: it could be the name the user wants for a new
  skill, or a misremembered existing one. Say both readings in one line and ask which, rather than guessing;
  guessing wrong here costs a whole interview.
- **Blank, but the conversation just established a task** → *Build* mode, using that task as the idea. Say in one line which idea you picked up, so the user can correct you before you spend the interview on the wrong thing.
- **Blank, no task in the conversation** → *Audit* mode. Skip to "Audit mode" near the bottom.

## Phase 0 — Triage: should this be a skill at all?

Run this before asking a single requirement question. The most useful thing this skill does is sometimes talk the user out of building a skill, and that only works if it happens before they've invested in describing one.

A skill is procedural knowledge that Claude loads *when relevant* and then follows. That makes it the wrong shape for several things it gets reached for anyway:

- **Wants to fire automatically on an event** (after every edit, before every commit, when the session starts) → that's a **hook**, not a skill. A skill can't guarantee it runs; the harness runs hooks. If the user says "every time," "always," "automatically," or "make sure you never forget to," treat that as a strong hook signal.
- **A fact about the user, the project, or a preference** ("I use pnpm," "our API base is X," "don't add comments") → that's **memory** or `CLAUDE.md`, not a skill. Skills describe *how to do something*; these describe *what is true*.
- **A single prompt the user retypes** with no branching, no reference material, no multi-step procedure → a **slash command** (`~/.claude/commands/<name>.md`) is lighter and does the job. Skills earn their weight through supporting files and conditional logic; a five-line prompt has neither.
- **Needs a fresh context window, or fan-out across many files** → a **subagent** (`~/.claude/agents/`) or the Workflow tool. A skill runs in the current context and inherits its pollution.
- **Already exists** — check first, always. `ls ~/.claude/skills/ .claude/skills/` and read the `description:` line of anything that sounds adjacent. Overlapping skills are worse than no skill: two descriptions that both half-match a request make the model pick badly and load the wrong one. If something close already exists, the answer is usually "extend that one," and Review mode is the right flow.
- **The model already does this well unprompted** → no skill. Writing a skill for behavior that's already default adds tokens and adds a chance to *degrade* it by over-specifying.

State the triage verdict in one or two lines before moving on. If the verdict is "not a skill," say what it should be instead and offer to build *that* — don't just decline and stop. If the user hears the verdict and still wants a skill, build the skill; the call is theirs, and note the reasoning stays on record in the final report.

Read `references/triage.md` for the fuller decision table and the borderline cases.

## Phase 1 — Interview: get the trigger right first

Ask one question at a time, in plain language, and stop as soon as you have enough. Do not run the user through a fixed questionnaire — most ideas answer half of these on their own, and re-asking what they already said is the fastest way to make this feel like a form.

What you actually need:

1. **The trigger** — when should this fire? This matters more than anything else and is the single most common failure. Push for the words the user would really type or the situation they'd really be in, not a topic label. "When I want to deploy" is a topic; "when I say ship it, push to prod, or ask to cut a release" is a trigger.
2. **The procedure** — walk through it once, concretely, on a real example. Vague procedures produce vague skills. If the user can't describe one concrete run of it, the idea isn't ready and interviewing further won't fix that — say so.
3. **The boundary** — when should it *not* fire? A skill with no stated boundary bleeds into neighboring requests.
4. **What "done" looks like** — how would the user know a run went well? This becomes the skill's own success criteria and, later, the dry-run test.
5. **Fixed knowledge it needs** — commands, file paths, API shapes, house style, a checklist, a template. Anything stable goes into the skill; anything that changes per-run is an input to gather at runtime.
6. **Invocation style** — auto-invocable (the model decides from the description) or manual-only (`disable-model-invocation: true`, `/name`). Default to auto; recommend manual for anything expensive, destructive, or opinionated enough that the user wants to choose it deliberately. Both `loop-engineer` and `ea-builder` are manual for exactly that reason.

## Phase 2 — Spec back in plain language, then confirm

Before writing a line of the skill, say back: the name, the one-sentence description, when it fires, when it doesn't, the steps in order, and what files it'll create. Plain language, no YAML yet.

This is the cheapest place to catch a misunderstanding — rewriting a paragraph here costs nothing, rewriting an installed skill after the user tries it costs a whole round trip. Let the user confirm before spending the write.

## Phase 3 — Write it

Layout for a skill named `<name>`:

```
~/.claude/skills/<name>/
  SKILL.md            # required — frontmatter + the procedure
  references/         # optional — detail loaded only when needed
  templates/          # optional — files the skill fills in
  scripts/            # optional — deterministic work better done by code
```

Before writing anything, check whether `~/.claude/skills/<name>/` already exists. If it does, stop and ask —
never overwrite an installed skill on the assumption it's stale. The user picks: a different name, or an
explicit edit of the existing one via Review mode.

Start from `templates/SKILL.template.md`. The rules that matter:

**The `description` is the skill's entire user interface.** For an auto-invocable skill it is the *only* thing the model sees until the skill is loaded — the body doesn't exist yet at selection time. Write it in the third person, state what the skill does *and* the concrete situations that should trigger it, and include the literal words a user would say. Vague descriptions are the number one reason a good skill never fires.

**Name in lowercase kebab-case**, matching the directory name. Make it a thing, not a sentence.

**Write the body as instructions to a capable colleague**, not as documentation for a human reader. It's read at runtime by the model that will act on it. Say what to do, in order, with the reasoning that lets it adapt when reality doesn't match — a step whose *why* is stated survives an unexpected situation; a bare imperative doesn't.

**Push detail out of SKILL.md.** The body loads in full every time the skill fires, so it pays for its own length on every invocation. Keep it to the procedure and the decisions; move long reference material, tables, and examples into `references/` and point at them by filename, so they're read only when that branch actually comes up. Target well under 500 lines in the body.

**Prefer a script over prose for anything deterministic.** If a step is "validate this JSON" or "count the matches," a script does it correctly every time for a fraction of the tokens and none of the drift. Prose is for judgment; scripts are for mechanics.

**State the failure modes.** The most valuable paragraphs in a mature skill are the ones naming the specific wrong turn the model tends to take — `ea-builder`'s "don't retune a mismatched indicator" and `loop-engineer`'s anti-gaming guardrails exist because those exact failures happened. If the user has watched this task go wrong before, that story belongs in the skill verbatim.

Read `references/anatomy.md` for every frontmatter field and what it does, and `references/smells.md` for the specific patterns that make skills fail in practice — check the draft against that list before moving on.

## Phase 4 — Validate, then actually test it

Two gates. Neither is optional, and neither is satisfied by reading the file and judging it looks right.

**Gate 1 — mechanical validation.** Run `scripts/validate.sh <skill-dir>` and read its real output. It checks the frontmatter parses, `name` matches the directory and is well-formed, `description` exists and is within limits, every file referenced from the body actually exists, and the name doesn't collide or substantially overlap with an installed skill. Any failure is a fail — fix and re-run.

**Gate 2 — dry-run.** Mechanical validity says nothing about whether the instructions work. Pick two test cases from the interview and, for each, read the skill as if encountering it fresh and walk the procedure against that case.

For an auto-invocable skill, use one case squarely inside its scope and one just outside that should *not* trigger — the negative case is what catches a description broad enough to fire on everything. For a `disable-model-invocation: true` skill there is nothing to mis-trigger, so spend both cases on the procedure instead: one straightforward run, and one awkward one — a missing input, an ambiguous argument, a branch the happy path skips.

What you're looking for: a step that turns out to be ambiguous, a decision point with no stated default, a dependency the skill assumes but never gathers, and — on the negative case — a description so broad it would have fired anyway. Fix what the dry-run surfaces, then re-run it. Report both cases and their outcomes to the user; don't just assert it passed.

If the skill's real payoff can only be seen by running it for real (it drives external tools, needs a live service), say so plainly rather than faking a pass — dry-run what you can, and tell the user which part is still unproven and how they'd prove it.

## Phase 5 — Install and report

The files were written to `~/.claude/skills/<name>/` in Phase 3, so it's already installed. Skills are picked up on the next session; tell the user they may need a fresh session or `/reload` before `/<name>` resolves.

Close with a short report — not a wall of text:

- Where it lives, and how to invoke it
- The trigger, in one line
- What the two dry-run cases showed
- Anything deliberately left out of scope, and why
- One concrete next step if the user wants to sharpen it (usually: use it three times, then come back to `/skill-smith <name>` for Review mode)

## The auto-validate hook

Gate 1 also runs on its own. A `PostToolUse` hook on `Write|Edit` (in `~/.claude/settings.json`) calls
`scripts/hook-validate.sh`, which finds the skill any edited file belongs to and validates it.

It's a hook rather than part of this skill because "every time a skill file changes" is a guarantee,
and skills aren't guaranteed to fire — only the harness is. Behaviour:

- **Valid → silent.** A hook that speaks when nothing is wrong gets tuned out, and then it isn't read
  when something is wrong.
- **Structural failure** (bad frontmatter, name mismatch, name collision) → exit 2, surfaced to the
  model to fix.
- **A referenced file that doesn't exist yet** → advisory only. Writing SKILL.md before the
  `references/` files it points at is normal while authoring, and blocking on it would fight the way
  these get built.
- **Anything wrong internally** → exits 0 quietly. A broken validator must never become a broken
  editing session.

**It also auto-commits.** A fully clean pass (no FAIL at all, hard or soft) stages and commits just
that skill's directory — `auto:` message, `Co-Authored-By` trailer. This is what makes "the latest
version" a well-defined thing: the git history at `~/.claude/skills` is always exactly as current as
the files on disk, never sitting on a forgotten `git add`. Anything failing outright, or only
partway there (a dangling reference), is never auto-committed — a clean pass is the only state worth
recording. A foreign nested repo (a skill installed from its own git history, e.g. `handoff/`) is
skipped rather than committed into. Expect many small `auto:` commits during an active session —
that's fine for feeding a fast-forward-only pull on another machine, and squashable by hand later.

What the hook cannot do is judge whether the `description` still matches a body that just grew, or
whether a change introduced one of the smells. That's judgment, so it stays here — run
`/skill-smith <name>` for Review mode after a substantial edit.

## Review mode

Given an existing skill by name or path: read the whole thing, run `scripts/validate.sh` on it, then assess it against `references/smells.md`.

Report findings ordered by what actually costs the user something — a description that keeps the skill from ever firing outranks a body that's fifty lines too long. For each finding: what's wrong, why it hurts, and the concrete edit. Offer to apply them; don't apply unasked.

Do check whether the skill still deserves to exist. A skill written for a workflow that's since changed, or for behavior the model now does well unprompted, is a net cost — say so if that's what you find.

## Audit mode

Bare invoke, no task: survey what's installed. `ls` both `~/.claude/skills/` and `.claude/skills/`, read every `description:` line, and report:

- **Overlaps** — two or more skills whose descriptions compete for the same request. This is the most damaging problem in a skill collection and the least visible, because nothing errors; the model just loads the wrong one. Name the pairs and suggest which to merge or narrow.
- **Dead weight** — skills whose trigger is so narrow or so vague they likely never fire.
- **Gaps** — repetitive work visible in this project or conversation that no installed skill covers.

Keep it to the findings. Don't recite the full inventory back — the user can `ls` for that.
