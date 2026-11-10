# SKILL.md anatomy

## Where skills live

| Scope | Path | Available in |
|---|---|---|
| Personal | `~/.claude/skills/<name>/SKILL.md` | every project on this machine |
| Project | `<repo>/.claude/skills/<name>/SKILL.md` | that repo only, and shareable via git |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | wherever the plugin is installed |

Default to personal unless the skill hardcodes something repo-specific (that repo's build command, its
directory layout, its house conventions) — that belongs in the repo, next to the thing it describes,
so it travels with the code and the team gets it too.

## Frontmatter

```yaml
---
name: skill-name                  # required
description: ...                  # required
disable-model-invocation: true    # optional
allowed-tools: Read, Grep, Bash   # optional
---
```

**`name`** — required. Lowercase kebab-case, and it must match the directory name. Keep it short and
concrete; it's what the user types after the slash.

**`description`** — required, and the highest-leverage line in the whole file. Until the skill is
selected, this is *all* the model can see; the body might as well not exist. Third person, present
tense. Say what the skill does, then say when to use it, and put the literal words a user would type
into that second half. Multi-line is fine with a `>` block. Cap around 1024 characters, but length is
not the goal — specificity is.

**`disable-model-invocation`** — optional boolean. `true` means the model will never auto-select it;
only an explicit `/name` runs it. Use it for anything expensive, destructive, long-running, or
opinionated enough that firing uninvited would be an annoyance. When set, say "Manual invoke only —
use /name" at the end of the description so the intent is visible in listings.

**`allowed-tools`** — optional. Restricts the skill to a named subset of tools while it runs. Worth
setting on a read-only or analysis skill; leave it off otherwise, since an over-tight list turns into
a mysterious mid-run failure.

## Body

Everything after the frontmatter. Loaded in full, every time the skill fires — so its length is a
recurring cost, not a one-time one.

Write it as instructions to a capable colleague who is about to do the work: what to do, in order,
with the *reasoning* behind the non-obvious steps. Reasoning is what lets the model adapt when the
situation doesn't match what you imagined; a bare imperative can only be followed or abandoned.

Useful sections, roughly in order of how often they earn their place:

- **How to invoke** — the command line, with the argument shape.
- **Gather / interview** — what to ask before acting, and explicitly what *not* to ask because it
  should be derived. Both `loop-engineer` and `ea-builder` do this; it's what keeps them from feeling
  like forms.
- **Defaults that are never asked** — decisions made once, in the skill, so every run is consistent.
- **The procedure** — the steps.
- **Failure modes** — the specific wrong turns this task invites, named. The most valuable section in
  a mature skill, and the one only experience can write.
- **Success criteria** — what "done" means, concretely enough to check.
- **Reporting** — what to tell the user at the end.

## Supporting files

- `references/` — detail read only when a branch needs it. This is the whole point of splitting: it
  keeps per-invocation cost down while leaving the depth available. Point at files by name from the
  body ("read `references/x.md` for ...") so the model knows when to reach for them.
- `templates/` — files the skill fills in and writes out.
- `scripts/` — deterministic work. Anything with an objectively correct answer (validating, counting,
  parsing, transforming) belongs here: a script is cheaper than prose, correct every time, and can't
  drift.
- `assets/` — anything else the skill ships.

## Skills vs the neighbors

- **Slash command** (`~/.claude/commands/<name>.md`) — a saved prompt. No supporting files, no
  auto-invocation. Right when there's genuinely one prompt and no procedure.
- **Hook** (`settings.json`) — harness-executed, fires on an event, guaranteed to run. The only
  option when the requirement is "every time, without fail."
- **Subagent** (`~/.claude/agents/<name>.md`) — runs in its own context window. Right for fan-out,
  or for keeping a big noisy investigation out of the main thread.
- **Memory / `CLAUDE.md`** — durable facts and preferences. Not procedures.

These compose. A common good shape is a hook that fires reliably and does nothing but tell the model
to invoke a skill that holds the actual procedure.
