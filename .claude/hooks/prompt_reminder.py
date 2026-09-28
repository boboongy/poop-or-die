"""UserPromptSubmit hook: put the 4-line per-message reminder (SKILL.md section 0b) in front of Claude with every owner message.

Long chats made the rules fade (day 3 repeated mistakes the skill already listed). This costs about 150 tokens per message.
Any problem prints nothing, so a missing file can never block a message.
"""
import json
import re
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parents[2] / ".claude" / "skills" / "build-verify-workflow" / "SKILL.md"


def reminder():
    try:
        lines = SKILL.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ""
    out, on = [], False
    for line in lines:
        if line.startswith("## 0b."):
            on = True
            continue
        if on and line.startswith("## "):
            break
        if on and line.strip():
            out.append(line)
    return "\n".join(out)


## The context-size warning (80k /compact, 120k /clear) moved to the GLOBAL hook ~/.claude/hooks/context_warning.py on 2026-09-28
## (owner: "add it to my global settings"), so it works in every workspace and does not fire twice here.
out = {}
text = reminder()
if text.strip():
    text = "SKILL REMINDER (build-verify-workflow section 0b, injected by .claude/hooks/prompt_reminder.py):\n" + text
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", text)
    out["hookSpecificOutput"] = {"hookEventName": "UserPromptSubmit", "additionalContext": text}
if out:
    print(json.dumps(out))
