"""PostToolUse hook for Write and Edit: fail loudly if the written text file contains hidden control characters.

Background: writing files through shell strings once turned `\\3` and `\\a` in Windows paths into invisible bytes
(0x03, 0x07) inside CLAUDE.md. Allowed control characters: newline, tab, carriage return.

Reads the hook JSON from stdin. Exit 0 = fine (or not a text file). Exit 2 = problem; the message on stderr is
shown to Claude so it fixes the file at once.
"""
import json
import sys
from pathlib import Path

TEXT_SUFFIXES = {".md", ".gd", ".tscn", ".tres", ".py", ".sh", ".json", ".txt", ".cfg", ".ini", ".yml", ".yaml", ".csv", ".godot", ".gdshader", ".toml"}
ALLOWED = {0x09, 0x0A, 0x0D}
NAMES = {0x00: "NUL", 0x03: "ETX", 0x07: "BEL (a '\\a' in a path)", 0x08: "BS", 0x0B: "VT", 0x0C: "FF", 0x1B: "ESC"}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0  # nothing to check
    tool_input = payload.get("tool_input") or {}
    tool_response = payload.get("tool_response") or {}
    raw = tool_input.get("file_path") or (tool_response.get("filePath") if isinstance(tool_response, dict) else None)
    if not raw:
        return 0
    path = Path(raw)
    if path.suffix.lower() not in TEXT_SUFFIXES or not path.is_file():
        return 0
    data = path.read_bytes()
    hits = []
    line = 1
    for byte in data:
        if byte == 0x0A:
            line += 1
        elif byte < 0x20 and byte not in ALLOWED:
            hits.append((line, byte))
    if not hits:
        return 0
    shown = ", ".join(f"line {ln}: 0x{b:02X} {NAMES.get(b, '')}".strip() for ln, b in hits[:8])
    more = f" (and {len(hits) - 8} more)" if len(hits) > 8 else ""
    print(
        f"HIDDEN CONTROL CHARACTERS in {path}: {shown}{more}. "
        "This is usually a backslash escape (\\a, \\3, \\b) inside a Windows path or string. "
        "Rewrite those lines with forward slashes, then check the file again.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
