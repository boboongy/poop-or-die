# Mi Godot: Godot project rules

The game itself (Godot, GDScript). Assets are made elsewhere: `C:\Users\bobo\Documents\mi-gaming-factory` (Blender).

## Core workflow (always)
- Always present a written plan and wait for approval before beginning any multi-task step.
- Whenever unsure about anything, ask up to 6 clarifying questions. Do not assume.
- Work solo. Ask before spawning any agent.
- Never claim something works in Godot unless it was actually run or checked. Report as **Run / Seen / Felt** (only the owner can judge motion and feel) and list what was NOT verified.

## Every session
- **First:** the SessionStart hook already injected the skill's top rules and STATUS.md's key sections (do not re-read them); state back the plan in 3 lines, run `bash tools/session_start.sh` (tools + baseline) in the background, read only the skill's `references/` file the task touches.
- **Before proposing a design, ask what the owner already planned.** Mark SPEC.md lines DECIDED or PROPOSAL; never build a PROPOSAL without asking.
- **Every owner-reported bug becomes a failing test in `tests/` first;** fix the cause, test EVERY instance (all 20 stalls, both rows), run the whole suite before reporting.
- **Write files with the Write/Edit tools, never shell heredocs or Python strings** (they broke files and inserted hidden control characters).
- `STATUS.md` = current state only (max 80 lines, `tests/check.sh` fails above that); at every slice/stage end move the finished detail to `HISTORY.md` and keep one line. When a stage is done or the chat is long, finish the handoff and tell the owner to start a new session.
- **Keep the skill alive:** when a failure class repeats or something costs >15 min, add one line to `.claude/skills/build-verify-workflow/SKILL.md` (or its lessons file) in the same session, before the final report, and tell the owner in one sentence.

## Rules
- `assets/` holds ONLY published .glb files (+ notes) from the factory. NEVER edit or re-export them here. A model problem is fixed in the factory, then republished with `python tools/publish_to_game.py <slug>` (run from the factory).
- Each published asset has `assets/<characters|environments>/<slug>/<slug>.glb` and `*_godot_notes.md`: read the notes before using the asset (scale, collision suffix, lights not exported, animations).
- Lights are NOT in the .glb: build lighting in Godot (the toilet's green ceiling-grid look is described in the factory's toilet SPEC).
- Skill `.claude/skills/3d-water-animation` here is a COPY of the factory master; edit the master, then re-copy.
- Keep this file short (<= 40 lines).

## Layout
`assets/` published models | `video/` rendered cutscene clips (Ogg Theora) | `audio/` CC0 sounds + `SOURCES.md` (every file listed; `scripts/sfx.gd` maps events to files) | `scenes/` .tscn | `scripts/` GDScript | `tests/` headless tests (`bash tests/run.sh`) | `project.godot` (created by Godot: open this folder in the Godot project manager and choose Create/Import; Claude does not hand-write it)
