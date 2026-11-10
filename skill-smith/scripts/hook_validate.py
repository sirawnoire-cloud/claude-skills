#!/usr/bin/env python3
"""PostToolUse hook body. Reads the hook JSON on stdin, finds the skill the edited file belongs
to, runs validate.sh on it, and reports only when something is actually wrong."""
import json, os, platform, shutil, subprocess, sys

def quiet(*_):            # any internal problem: stay out of the way
    sys.exit(0)

def find_bash():
    # validate.sh is a bash script. macOS/Linux have bash on PATH; Windows generally doesn't,
    # even with Git for Windows installed, so fall back to its known bundled locations.
    b = shutil.which("bash")
    if b:
        return b
    if platform.system() == "Windows":
        for candidate in (r"C:\Program Files\Git\bin\bash.exe",
                          r"C:\Program Files\Git\usr\bin\bash.exe"):
            if os.path.isfile(candidate):
                return candidate
    return None

def autocommit(repo_root, root, name):
    """Stage and commit only this skill's directory, only when it's fully clean. Returns a
    short hash on success, None if there was nothing to commit or the commit failed — either
    way the caller treats None as 'stay quiet', never as an error to surface."""
    try:
        subprocess.run(["git", "-C", repo_root, "add", "--", root],
                        capture_output=True, timeout=15)
        # Nothing staged means either no real change (edit produced identical content) or the
        # path is outside this repo's working tree (a symlinked skill whose real files live
        # elsewhere, or a foreign nested repo git already ignores) — both are correctly no-ops.
        diff = subprocess.run(["git", "-C", repo_root, "diff", "--cached", "--quiet"],
                               capture_output=True, timeout=15)
        if diff.returncode == 0:
            return None
        msg = (
            "auto: update %s\n\n"
            "Auto-committed by skill-smith's validation hook after this skill passed "
            "validate.sh with no findings.\n\n"
            "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>" % name
        )
        commit = subprocess.run(
            ["git", "-C", repo_root, "commit"] + (["--author=" + __import__("os").environ["SKILL_SMITH_COMMIT_AUTHOR"]] if __import__("os").environ.get("SKILL_SMITH_COMMIT_AUTHOR") else []) + ["-m", msg],
            capture_output=True, text=True, timeout=15)
        if commit.returncode != 0:
            return None
        sha = subprocess.run(["git", "-C", repo_root, "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, timeout=15).stdout.strip()
        return sha or None
    except Exception:
        return None

try:
    payload = json.load(sys.stdin)
except Exception:
    quiet()

path = (payload.get("tool_input") or {}).get("file_path") or ""
if not path:
    quiet()
path = os.path.abspath(os.path.expanduser(path))

# Find the skill root: the component directly under a "skills" directory.
parts = path.split(os.sep)
try:
    i = len(parts) - 1 - parts[::-1].index("skills")   # last "skills" in the path
except ValueError:
    quiet()                                            # not inside any skills/ tree
if i + 1 >= len(parts):
    quiet()
root = os.sep.join(parts[: i + 2])
if not os.path.isfile(os.path.join(root, "SKILL.md")):
    quiet()                                            # not a skill dir (scratch, assets, etc.)

validator = os.path.expanduser("~/.claude/skills/skill-smith/scripts/validate.sh")
if not os.path.isfile(validator):
    quiet()

bash = find_bash()
if not bash:
    quiet()

try:
    r = subprocess.run([bash, validator, root], capture_output=True, text=True, timeout=20)
except Exception:
    quiet()

name = os.path.basename(root)
repo_root = os.path.dirname(root)

fails = [l for l in r.stdout.splitlines() if l.startswith("FAIL:")]
if not fails:
    # Fully valid — this is the only state worth committing as "the latest version" of the
    # skill. Skip foreign nested repos entirely (e.g. a third-party skill installed from its
    # own git history) rather than trying to commit into them.
    if not os.path.isdir(os.path.join(root, ".git")):
        sha = autocommit(repo_root, root, name)
        if sha:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": "skill '%s': auto-committed (%s)" % (name, sha)}}))
    sys.exit(0)

# A dangling reference is a normal mid-authoring state; everything else is structural.
soft = [f for f in fails if "does not exist" in f]
hard = [f for f in fails if "does not exist" not in f]

if hard:
    msg = ["skill-smith validation failed for '%s' after editing %s:" % (name, os.path.basename(path))]
    msg += ["  " + f for f in hard]
    if soft:
        msg += ["  " + f for f in soft]
    msg.append("Fix these before continuing. Re-check with: validate.sh %s" % root)
    print("\n".join(msg), file=sys.stderr)
    sys.exit(2)                                        # structural — surface it to the model

# Only dangling references: advisory, since the referenced file may still be on its way.
note = ["skill '%s': %d referenced file(s) not present yet —" % (name, len(soft))]
note += ["  " + f.replace("FAIL: ", "") for f in soft]
note.append("Fine if you are still writing them; otherwise fix the path.")
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "\n".join(note)}}))
sys.exit(0)
