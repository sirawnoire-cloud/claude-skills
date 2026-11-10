# claude-skills

Personal Claude Code skills, versioned here and kept up to date on every machine by a small sync hook.

| Skill | What it does |
| --- | --- |
| [loop-engineer](loop-engineer/) | Do-check-redo loop until a task passes. Survives compaction/idle via on-disk memory + hooks; enforces its delegation rules mechanically. |
| [ui-craft](ui-craft/) | Builds web UI that is distinctive, fluidly responsive and alive by default, then verifies it in a real browser (`scripts/preflight.sh`). |
| [skill-smith](skill-smith/) | Design, write, test and install a Claude Code skill from a plain-language idea (+ validation hook). |
| [ea-builder](ea-builder/) | Build a MetaTrader 5 Expert Advisor for XAUUSD from a plain-language idea. |
| [claude-handoff](claude-handoff/) | Hand the current conversation off to a fresh background agent. |
| [wayfinder](wayfinder/) | Plan a huge chunk of work as a shared map of investigation tickets. |

## Install

```
git clone https://github.com/sirawnoire-cloud/claude-skills && cd claude-skills
./install.sh --dry-run     # shows exactly what would change
./install.sh               # all skills; or: ./install.sh ui-craft loop-engineer
```

Needs `jq` and `rsync`. Symlinked skills and skills that carry their own `.git` are skipped; an existing,
different copy is backed up to `~/.claude/.skills-install-backup/` first; `settings.json` is backed up and
only this repo's hook entries are replaced. Re-running is idempotent. Open a new session afterwards so the
hooks load.

## Self-update (what the sync hook does)

`claude-skills-sync` runs on SessionStart and on every prompt, at most once per 6 hours:

1. fetches `manifest.json`;
2. for each skill that is a real directory in `~/.claude/skills`, has a `VERSION` file (the opt-in) and is
   behind the manifest, downloads the files marked `auto`, checks their sha256, and replaces them
   atomically (backup in `<skill>/.bak-<oldversion>/`);
3. shows a one-line message (`claude-skills updated: ui-craft v2.0.0 -> v2.0.1`) and tells the model to
   re-read the skill if it is in use; every update is logged to `~/.claude/.claude-skills-sync/update.log`.

**Only text is auto-updated** (`*.md`, `VERSION`). Scripts, hooks and data files are never replaced
automatically (that would be remote code execution from this repo); when they changed, the notice tells you
to `git pull && ./install.sh`. Never touched: symlinked skills, skills without `VERSION`, anything not in the
manifest. Never downgrades. Kill switch: `CLAUDE_SKILLS_NO_UPDATE=1`.

Trust model: integrity is checked against a manifest from the same repo, so anyone who can push here can
change what the skills tell your model to do. Protect the account (2FA), and consider the repo's contents
as instructions you have reviewed.

## Maintaining

- Skills you edit locally in `~/.claude/skills/<name>`: `tools/publish.sh <name> --bump patch -m "what changed"`
  copies it here, sanitizes, scans for secrets/emails (refuses on a hit), bumps `VERSION`, regenerates
  `manifest.json`. Then review, commit, push.
- `loop-engineer` is mastered in this repo: edit it here, bump its `VERSION`, run `tools/release.sh`.
- Always run `tools/release.sh` (publish.sh does) before pushing; the manifest must match the files.
