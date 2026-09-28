"""Stop hook: two mechanical guards from the build-verify-workflow skill, each at most ONCE per session.

1. TESTS STALE: some source file (scripts, scenes, tests) is newer than the last full passing `bash tests/run.sh`
   (tests/run.sh writes .claude/last_full_run.json after an unfiltered run), or the last full run failed.
   -> block once: "run the suite (about a minute) and report it, or say why not".
2. RETRO DUE: tests are fresh and green, code changed today, and HISTORY.md has no RETRO entry dated today.
   -> block once: "if this is the end of a stage, write the 5-line retro and a skill line; otherwise ignore".

Never loops (stop_hook_active), never fails hard: any error just lets Claude stop. State: .claude/hook_state.json.
"""
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / ".claude" / "hook_state.json"
MARKER = ROOT / ".claude" / "last_full_run.json"
HISTORY = ROOT / "HISTORY.md"
SOURCE_GLOBS = ["scripts/**/*.gd", "scripts/**/*.gdshader", "scenes/**/*.tscn", "tests/**/*.gd", "tests/run.sh"]


def load(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def newest_source_mtime():
    newest = 0.0
    for pattern in SOURCE_GLOBS:
        for path in ROOT.glob(pattern):
            try:
                newest = max(newest, path.stat().st_mtime)
            except OSError:
                pass
    return newest


def retro_written_today():
    today = time.strftime("%Y-%m-%d")
    try:
        for line in HISTORY.read_text(encoding="utf-8").splitlines():
            if "RETRO" in line and today in line:
                return True
    except OSError:
        return True  # cannot check: do not nag
    return False


def block(reason):
    print(json.dumps({"decision": "block", "reason": reason}))


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}
    if data.get("stop_hook_active"):
        return  # already continuing because of a stop hook: never loop
    session = str(data.get("session_id", "unknown"))
    state = load(STATE, {})
    mine = state.get(session, {})
    marker = load(MARKER, {})
    newest = newest_source_mtime()
    stale = newest > float(marker.get("time", 0)) + 2 or marker.get("result") != "PASS"
    reason = ""
    if stale and not mine.get("tests"):
        mine["tests"] = True
        reason = (
            "STOP GUARD (skill top rule 2, build loop step 3): code changed since the last full PASSING `bash tests/run.sh` "
            "(or the last full run failed). Run `bash tests/run.sh` now (about a minute) and report the result, "
            "or tell the owner why you did not. Then finish your report with the one-line `Skill check:`."
        )
    elif not stale and newest > 0 and time.strftime("%Y-%m-%d", time.localtime(newest)) == time.strftime("%Y-%m-%d") \
            and not mine.get("retro") and not retro_written_today():
        mine["retro"] = True
        reason = (
            "STOP GUARD (skill sections 9 and 11): tests are green and code changed today, but HISTORY.md has no RETRO entry "
            "dated today. If this is the end of a stage or a long session, write the 5-line retro (what took long, cause class, "
            "what changed, skill line added) in HISTORY.md, add any skill line, and update the `Skill check:` line. "
            "If it is NOT a stage end, say so in one sentence and stop."
        )
    if reason:
        state[session] = mine
        for old in list(state)[:-20]:  # keep the file small
            del state[old]
        try:
            STATE.write_text(json.dumps(state), encoding="utf-8")
        except OSError:
            pass
        block(reason)


def fresh():
    """True when the last full run passed and no source file changed since (tools/session_start.sh skips its baseline then)."""
    marker = load(MARKER, {})
    return marker.get("result") == "PASS" and newest_source_mtime() <= float(marker.get("time", 0)) + 2


if "--fresh" in sys.argv:
    sys.exit(0 if fresh() else 1)

try:
    main()
except Exception:  # a broken guard must never trap the session
    pass
