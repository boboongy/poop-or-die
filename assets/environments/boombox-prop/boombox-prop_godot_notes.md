# boombox-prop.glb: Godot notes (2026-09-25)

Retro 80s boombox for the level 5 dance battle (replaces the cyan-box stand-in in `scripts/dance.gd`).

## What is in it
| Item | Value |
|---|---|
| Nodes | ONE mesh node `SM_Boombox` (6 surfaces / materials), no skeleton, no animation, no lights, no cameras |
| Size (Godot, measured in Godot 4.7.2 after import) | 0.504 wide (X) x 0.303 high (Y) x 0.177 deep (Z) m |
| Origin | floor centre under the case: place it ON the floor (y = 0); lowest point y = 0.000 |
| Front | the speakers face **+Z** (glTF/Godot). The stand-in's `rotation.y = PI / 2` turns them to +X, toward the battle camera: keep that line |
| Collision | none (not asked for); add a small box in Godot if a character should bump it |
| Triangles | 1720 |
| Materials | `M_BoomboxSilver` (metallic 0.6), `M_Chrome` (metallic 1.0, speaker rims, caps, handle), `M_SpeakerBlack`, `M_BoomboxPanel`, `M_AccentPink` (trim + buttons), `M_DisplayCyan` (emissive 1.5: the cassette window and display strip glow a little) |

## Ideas the game can add (not in the file)
* Speaker "thump" on the beat: scale the node 1.00 -> 1.03 -> 1.00 on every beat (the whole prop; the speakers are part of the one mesh).
* The cyan display can flash with the beat by animating the emission energy of `M_DisplayCyan` on the imported material.

## Rebuild
`"$BLENDER" -b boombox-prop.blend --python scripts/10_build_boombox.py` (all sizes in `scripts/lib/env_config.py`), then `50_env_export_gltf.py` and `51_env_validate.py` (19/19).
