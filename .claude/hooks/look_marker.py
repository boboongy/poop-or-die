"""PostToolUse hook: record when I last LOOKED at the game, for the stop guard.

Measured 2026-10-06 over the 17 retro entries in HISTORY.md: the single most
common reason a fix needed a second round was a look-or-feel judgement no
headless test can make (7 of 17; tooling and waiting 6, a cause guessed before
it was measured 3, owner design rounds 1). Skill top rule 3 already says to
take the first screenshot as soon as the first slice of a visible feature
works - nothing checked it, so this hook makes it mechanical.

A "look" is: reading a .png (the player-eye pass is looking at the image), or
running a shot_*.gd / screenshot / web_smoke command. It writes the timestamp
to .claude/last_look.json; stop_guard.py blocks once when a visible file
(scenes/*.tscn, *.gdshader) is newer than that.

Never fails hard: any error leaves the marker alone.
"""
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MARKER = ROOT / ".claude" / "last_look.json"
LOOKED = re.compile(r"shot_|screenshot|web_smoke|sheet\.png|get_viewport_screenshot", re.I)


def main():
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    looked = False
    if tool == "Read":
        looked = str(inp.get("file_path", "")).lower().endswith(".png")
    elif tool in ("Bash", "PowerShell"):
        looked = bool(LOOKED.search(str(inp.get("command", ""))))
    if looked:
        MARKER.write_text(json.dumps({"time": time.time(),
                                      "what": tool}), encoding="utf-8")


try:
    main()
except Exception:  # a broken marker must never trap the session
    pass
