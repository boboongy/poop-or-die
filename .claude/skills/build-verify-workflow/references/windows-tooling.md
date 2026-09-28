# Windows tooling rules (this machine)

Read this if a file write, edit or shell command misbehaves. (Moved out of SKILL.md on 2026-09-27.)

- **Write files with Write/Edit. Never through shell heredocs or long Python strings** (an empty heredoc hung the shell; Python strings turned `\3` and `\a` in Windows paths into hidden control characters). Forward slashes in paths. The PostToolUse hook rejects control characters.
- **Edit failures ("string not found") are almost always tab depth:** Grep -n the exact lines first, or anchor on one short unique line.
- **A background full run is going? Do not edit code, tests or run.sh until it prints its result** (2026-09-28, 2nd time: slice-4 code and run.sh edited under a slice-3 run: mixed code, run void). TODO make it mechanical: run.sh writes a lock, a PreToolUse hook refuses Write/Edit on scripts/ and tests/ while it exists.
- **Never edit a shell script (`tests/run.sh`) while it runs:** bash reads the file as it goes (2026-09-27, a 10-min run ended on a garbled line). Adding a new test's name to FAST_TESTS counts: do it before the baseline starts or after it ends (slipped again 2026-09-27, reverted within seconds; a mechanical fix = run.sh re-running itself from a temp copy).
- **Never put an Edit and a command that depends on it in the SAME parallel batch** (they can run in either order). No `sed -i` for a one-word change.
- **A settings file can hold a secret in a hook command (the ntfy topic in `~/.claude/settings.json`): never cat/Read it whole; grep for the key.**
- **The Edit tool drops a TRAILING space of `new_string`:** anchor on a whole word pair (`"x y"` -> `"x new y"`). (`run.sh` now refuses a test name with no file.) 3rd time 2026-09-27: a break-on-purpose edit anchored on `">= 4.9, "` glued the next argument on; for sabotage edits change only the number.
- Long commands go to the background with a log file; poll, never sleep-loop in the foreground. Windowed Godot runs take 10-40 s: batch several screenshots per run.
- No PIL/numpy in the system Python: contact sheets via ffmpeg `tile`; math in Godot/Blender scripts.
- `project-cheatsheet.md` has the exact commands, paths and the screenshot script pattern.
