---
name: <lowercase-kebab-case, must match the directory name>
description: <What it does, in the third person. Then: when to use it — the concrete situations, and the literal words a user would type. This is the ONLY thing visible at selection time, so it decides whether the skill ever fires. Add "Manual invoke only — use /<name>." if disable-model-invocation is set.>
# disable-model-invocation: true   # uncomment for expensive/destructive/opinionated skills
# allowed-tools: Read, Grep, Bash  # uncomment to restrict
---

<One line on what this is and who it's for.> Invoke as:

```
/<name> <argument shape, or "blank to use the current conversation's task">
```

## <Gather / Interview>

<What to ask before acting — one question at a time, plain language. And explicitly what NOT to ask
because it should be derived from the conversation, the repo, or the task's own nature. State each
derived value in one line so the user can correct it.>

## <Defaults — never ask, never skip>

<Decisions made once, here, so every run is consistent. Each with its reason.>

## <The procedure>

<Steps in order. Carry the reasoning for anything non-obvious — a step whose *why* is stated survives
a situation you didn't imagine; a bare imperative doesn't.>

## <Failure modes — the wrong turns this task invites>

<The specific ways this goes wrong, named. If the user has watched it fail before, that story goes
here in their words. This is the section that separates a mature skill from a first draft.>

## <Success criteria>

<What "done" means, concretely enough that the model can actually check it — a command that must
pass, an output that must validate, a bar that must be met.>

## <Reporting>

<What to tell the user at the end. Short and actionable: what happened, what's still open, what to do
next.>

<!--
Delete every unused section. Keep this body under ~500 lines — it loads in full on every invocation.
Push detail into references/ and name the files from the body. Push deterministic work into scripts/.
-->
