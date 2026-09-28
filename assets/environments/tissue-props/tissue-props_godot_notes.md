# Tissue props → Godot: import and placement notes

`exports/tissue-props.glb`: binary glTF 2.0, about 37 KB, 768 triangles, 3 plain materials, no textures, no collision, no lights or cameras.
**Placeholders** (owner, 2026-09-21): simple low-poly shapes with the correct size, origins and axes, so animation can be authored against them now and the art swapped later.

## Nodes (all `SM_`), Godot axes (Y up, the prop faces +Z)
```
ENV_ROOT                      (empty, identity scale)
  SM_TissueHolder             origin = the mount point on the wall (centre of the backplate, at the roll axis height). Faces +Z: the wall is the z = 0 plane, the prop sticks out toward +Z.
    SM_TissueRoll             origin = the roll centre (0, 0, 0.075). Spin it about its LOCAL X axis (the axis is parallel to the wall). 0.11 m across, 0.10 m wide.
    SM_TissueTail             origin = its TOP edge at (0, -0.02, 0.126), hanging 0.12 m down the front of the roll. Scale its Y to make it longer (pulled paper); hide it when torn off.
  SM_TissueSheet              a folded pad of 7 thin tissue layers with a centre crease (0.062 x 0.045 x 0.024 m). Origin = the grip centre. Laid out 0.35 m to the side of the holder in the file: instantiate it by name and attach it.
```
Extents (m): holder + roll + tail 0.14 x 0.24 x 0.15; the whole file 0.45 x 0.24 x 0.15. Materials: `M_TissuePaper` (double-sided, used by roll, tail and sheet), `M_Cardboard` (roll core), `M_HolderMetal`.

## Where the holder goes in a stall (Bob's right-hand wall)
Measured from `toilet-environment.blend`: the stall walls are 0.45 to 0.50 m either side of the seat centre (partitions are 1.5 m deep, z 0.30-1.80 m). With `seat` = the seat centre and
`forward` = the toilet's front direction (+Z for row 1; the game already keeps `_forward`), `right = forward.cross(Vector3.UP)` (Bob sits facing `forward`; for `forward = +Z`, `right = -X`):

| | value |
|---|---|
| position | `seat + right * 0.45 + forward * 0.12`, height **0.75 m** (0.45 is the wall face; use 0.45 minus the plate thickness 0.008 if you want it flush) |
| rotation | the prop's +Z (its front) must point INTO the stall, i.e. along `-right`. For `forward = +Z`: `rotation_degrees.y = +90` |
| Bob's reach | the holder is 0.34 m from his right shoulder sideways and about 0.10 m below it; his arms reach only about 0.31 m, so `tissue_grab` will have him lean out to the right (like the `wipe` lean) |

Bob's origin is the game's seat spot (0.15 m in front of the seat centre), so in Bob's own frame (Godot axes, +Z = forward) the mount point is at x = -0.45, y = 0.75, z = -0.03 (0.03 m BEHIND his origin, because it is 0.12 m in front of the seat centre and his origin is 0.15 m in front of it).
The context render `renders/context_*.png` shows Bob seated on the real toilet (hips on the seat ring: hip joint 0.513 m, shorts at his ankles) with the holder on the wall.

## What the game does (Godot side)
* Place one holder per stall Bob can use (or one at a time, when he enters), from the seat position as above.
* `tissue_grab` (Bob, coming): attach `SM_TissueSheet` to his `DEF-hand.R` (a `BoneAttachment3D`) at the frame the clip's notes name, show it; spin `SM_TissueRoll` and stretch `SM_TissueTail` while the paper is pulled; hide the tail when it tears off.
* `wipe`: the sheet stays in the hand; after the wipe drop it into the bowl and hide it.
* The same roll and sheet can replace the cube stand-in of the Level 1 "find / give tissue" mission (`tissue_box.gd`).
* Add your own `Area3D` for the interaction (no collision is exported).

## `tissue_grab` timing (Bob, 90 frames = 3.0 s at 30 fps; built, held back from the .glb until the shorts export work is done)
| Frames | What happens | What the game does |
|---|---|---|
| 0-16 | he leans out to the wall (sideways tilt 18 degrees; more would push his head through the partition), head turned to the holder, left arm out for balance, right hand reaching | nothing |
| 16-22 | **grab**: fingers close on the paper tail at (-0.325, 0.03, 0.665) in Bob's frame | tail visible and hanging |
| 22-38 | **pull**: the hand drags the paper toward the front of his lap | spin `SM_TissueRoll` about its X, and every frame aim `SM_TissueTail` from its top to the hand and scale its length to the distance (rest length 0.12 m) |
| 38-42 | **tear**: a sharp downward jerk (frame 40) and a small snap back | hide the pulled tail at frame 40; a short hanging tail stays on the roll; tear sound |
| 42-72 | **fold**: he sits up, both hands come together in front of his belly and press two folds | show `SM_TissueSheet` from frame **44**, attached to `DEF-hand.R` (a `BoneAttachment3D`), about 0.035 m along the bone from the wrist |
| 72-90 | hand with the sheet to the knee, left hand to the other knee, settle into `sit` | keep the sheet until the `wipe` is over, then drop it into the bowl |
Numbers checked in Blender: the hand reaches the tail (0.0 m off at frame 22), the closest point of Bob to the wall is 0.042 m away at frame 16 (the head), no arm stretch; the upper arms lie against his sides in the fold (6 sample points inside the torso shell against 4 in the plain seated pose).

## Rebuild
`10_build_props.py` (builds and saves the .blend) → `50_env_export_gltf.py` → `51_env_validate.py` (19 checks). `20_review_render.py` and `21_context_render.py` (run on Bob's file) make the review images.
