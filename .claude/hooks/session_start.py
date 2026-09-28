"""SessionStart hook: put the project's current state and the session-start checklist into Claude's context.

Prints JSON on stdout:
  {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
It injects sections 0 and 1 of the build-verify-workflow skill and the STATUS.md sections named in STATUS_SECTIONS (the head
up to the first '## ', then Snapshot, Next steps, Open decisions). The text must stay under LIMIT characters: Claude Code
cuts a longer injection to a 2 KB preview (2026-09-27: 12.6 KB was cut, so everything was read twice). `tests/check.sh` runs
this script with --check and fails when the text is over the limit. Any problem is reported inside the context text instead
of failing, so a missing file can never block a session from starting.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = ROOT / "STATUS.md"
SKILL = ROOT / ".claude" / "skills" / "build-verify-workflow" / "SKILL.md"
STATUS_SECTIONS = ("## Snapshot", "## Next steps", "## Open decisions")
LIMIT = 9000


def read_lines(path: Path):
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        return [f"(could not read {path.name}: {error})"]


def section(lines, prefix, missing):
    """The section whose heading starts with `prefix` (e.g. '## 1.'), up to the next '## ' heading."""
    out, on = [], False
    for line in lines:
        if line.startswith(prefix):
            on = True
        elif on and line.startswith("## "):
            break
        if on:
            out.append(line)
    return out or [missing]


status_lines = read_lines(STATUS)
status = []
for line in status_lines:  # the title and the "read this first" head
    if line.startswith("## "):
        break
    status.append(line)
for prefix in STATUS_SECTIONS:
    status += [""] + section(status_lines, prefix, f"(STATUS.md has no '{prefix}' section)")
skill_lines = read_lines(SKILL)
rules = section(skill_lines, "## 0.", "(top rules not found in the skill file: read .claude/skills/build-verify-workflow/SKILL.md)")
steps = section(skill_lines, "## 1.", "(session-start checklist not found in the skill file)")
text = "\n".join(
    [
        "PROJECT SESSION START (injected automatically by .claude/hooks/session_start.py).",
        "Do the checklist below BEFORE building anything, and tell the owner in 3 lines what state the project is in.",
        "Everything below is already in your context: do NOT Read these parts of SKILL.md and STATUS.md again.",
        "",
        "=== TOP RULES (SKILL.md section 0) ===",
        *rules,
        "",
        "=== Session-start checklist (SKILL.md section 1) ===",
        *steps,
        "",
        "=== STATUS.md (head, Snapshot, Next steps, Open decisions; the other sections only when your task touches them) ===",
        *status,
    ]
)
text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", text)  # never inject control characters
if "--check" in sys.argv:
    print(f"session_start hook text: {len(text)} characters (limit {LIMIT})")
    sys.exit(0 if len(text) <= LIMIT else 1)
if len(text) > LIMIT:
    text = text[:LIMIT - 200] + "\n(CUT: the injection is over its limit; shorten STATUS.md or SKILL.md sections 0-1.)"
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}))
