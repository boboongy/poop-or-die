# Mi Godot: Godot project rules

The game itself (Godot, GDScript). Assets are made elsewhere: `C:\Users\bobo\Documents\mi-gaming-factory` (Blender).

## Core workflow (always)
- Always present a written plan and wait for approval before beginning any multi-task step.
- Whenever unsure about anything, ask up to 6 clarifying questions. Do not assume.
- Work solo. Ask before spawning any agent.
- Never claim something works in Godot unless it was actually run or checked. Say what was not tested.

## Rules
- `assets/` holds ONLY published .glb files (+ notes) from the factory. NEVER edit or re-export them here. A model problem is fixed in the factory, then republished with `python tools/publish_to_game.py <slug>` (run from the factory).
- Each published asset has `assets/<characters|environments>/<slug>/<slug>.glb` and `*_godot_notes.md`: read the notes before using the asset (scale, collision suffix, lights not exported, animations).
- Lights are NOT in the .glb: build lighting in Godot (the toilet's green ceiling-grid look is described in the factory's toilet SPEC).
- Read `STATUS.md` first in every new session; update it at the end of every stage.
- Keep this file short (<= 40 lines).

## Layout
`assets/` published models | `scenes/` .tscn | `scripts/` GDScript | `project.godot` (created by Godot: open this folder in the Godot project manager and choose Create/Import; Claude does not hand-write it)
