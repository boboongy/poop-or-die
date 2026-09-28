# Project cheatsheet (mi-godot, Windows, verified 2026-09-20)

## Paths and commands
- Godot editor: `C:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`; console (prints to terminal): `...\Godot_v4.7.2-stable_win64_console.exe`.
- Headless script run: `"<console exe>" --headless --path . --script res://tests/test_x.gd` (from the project root). A script that `extends SceneTree` and calls `quit()` when done.
- Tests: `bash tests/run.sh` (the whole suite in about a minute: parallel and `--fixed-fps 60`), `bash tests/run.sh --slow`, `bash tests/run.sh doors` (name filter), `JOBS=1 bash tests/run.sh` (serial), `REALTIME=1 bash tests/run.sh` (wall-clock, only to check a timing suspicion). Output is PASS/FAIL/INFO lines; exit code 1 on failure.
- Run ONE test fast by hand: `"<console exe>" --headless --path . --fixed-fps 60 --script tests/test_x.gd [-- args]`. Args used by the tests: `walkers`, `flood`, `multi` (all four puddles), `seeds=N first=K` (stress test). `--fixed-fps` = exactly 1/60 s per frame with no wall-clock waiting (34 s to 4 s, identical results).
- Windowed screenshot runs are NOT headless and are real-time; they are the only place shader errors and how things LOOK can be checked. Use Bob's own camera at normal distance for the player-eye pass, plus a free `Camera3D` for overviews.
- Godot MCP tools: `run_project`, `stop_project`, `get_debug_output`, `launch_editor`, `get_godot_version`. `run_project` needs `scene` = `res://scenes/level_toilet.tscn` (no main scene is set). Always call `get_debug_output` right after and read the WARNING lines. Stop the project before starting it again.
- Noise to ignore in headless output: `BUG: Unreferenced static string`, `ObjectDB instances were leaked`, `RIDs of type "Texture" were leaked`, the `agent_max_climb` navmesh warning at start.
- ffmpeg: `C:/Users/bobo/AppData/Local/Microsoft/WinGet/Packages/yt-dlp.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-N-125875-g5d4d3bdc61-win64-gpl/bin/ffmpeg.exe` (no glob input; frames as `name_%02d.png`).
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`; the MCP needs a GUI Blender with the addon server started BEFORE the Claude session begins. Headless works with `-b file.blend --python script.py`.
- Scratchpad for temporary files: the path given in the session's environment section (not the repo). Anything worth keeping goes in `tests/` or `tools/`.
- Git: `mi-godot` has only two commits (skeleton); almost everything is untracked. Commit only when the owner asks.

## Screenshot script pattern (windowed run, NOT headless)
```gdscript
extends SceneTree
func _snap(path: String) -> void:
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png(path)
func _init() -> void:
    get_root().size = Vector2i(1280, 720)
    var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
    await process_frame            # let the window exist before adding the scene
    get_root().add_child(lvl)
    # ... move things, await timers with process_frame, then: await _snap("C:/.../shot.png")
    quit()
```
Run it with the console exe and `--path . --script <file>` (no `--headless`). Use wall-clock waits (`Time.get_ticks_msec`) in windowed scripts. A free camera: add a `Camera3D`, set `current = true`.

## Numbers worth knowing
- Bob and Jijio are 1.3 m tall, same 63-bone skeleton and bone names (animations can be shared). Front is +Z in the model.
- Toilet: rows at z about -1.0 (row 1 doors) and -4.1 (row 2 doors); stall pitch 0.95 m from x 1.5; corridor A z about 0.3, corridor B z about -5.3; lobby (waiting room) x -5.3..-0.15; entry at x about -0.15.
- Interaction: `prompt()`, `interaction_point()`, `interact(player)` in group `interactable`; reach 1.3 m and roughly in view; `priority` boosts a nearby interactable over a closer one.
- Levels: add an entry to `scripts/level_defs.gd`, write mission scripts extending `scripts/missions/mission.gd` (`requires`, `activate()`, `finish()`), use `level.ctx` for shared notes.
