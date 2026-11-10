# plan-thai-gate

A `PreToolUse` hook on `ExitPlanMode` for the [pordee](https://github.com/kerlos/pordee) plugin. When pordee mode is
on (`~/.pordee/state.json` has `"enabled": true`), it checks the plan file about to be shown to the user
(`~/.claude/plans/*.md`, newest, written in the last 5 minutes) and blocks `ExitPlanMode` with a reason if the
prose is mostly English or full of filler/hedging, asking the model to rewrite it as terse Thai. It blocks at most
twice per plan file, so a miscalibrated heuristic can never loop the session. Does nothing when pordee is off.

## Install (manual, on purpose)

```
./extras/plan-thai-gate/install.sh --dry-run
./extras/plan-thai-gate/install.sh
```

Copies the script to `~/.claude/hooks/` and registers it under `PreToolUse` / `ExitPlanMode` in
`~/.claude/settings.json` (backup: `settings.json.bak-plan-thai-gate`; other hooks untouched; idempotent).

## Not auto-updated

Unlike the skills in this repo, this is **executable code that runs on your machine on every plan**, so the
claude-skills sync hook never touches it. To update: `git pull && ./extras/plan-thai-gate/install.sh`.
