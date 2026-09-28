# Bob → Godot: import notes

`exports/bob.glb` — binary glTF 2.0, 617 KB, everything embedded (no external files).

## What is in it
| | |
|---|---|
| Size | 1.300 m tall, feet on the ground plane, origin between the feet |
| Facing | Blender's front (-Y) becomes glTF +Z, the normal convention for imported Blender models |
| Meshes (9, separate) | `Bob_Body` `Bob_Hair` `Bob_Eye_L` `Bob_Eye_R` `Bob_Teeth` `Bob_Shirt` `Bob_Shorts` `Bob_Sandal_L` `Bob_Sandal_R` |
| Triangles | 13,716 total |
| Skeleton | 1 skin, **63 deform bones** (`DEF-*`): 6 spine, 30 finger, arms/legs/shoulders/feet/toes, 11 shorts |
| Influences | max 4 per vertex, weights sum to 1 |
| Materials (11) | `M_Bob_*`, Principled BSDF → Godot `StandardMaterial3D`; the burger is an embedded PNG on `M_Bob_ShirtGraphic` |
| Animations | see **Animation clips** below (test poses stay in the .blend and are not exported) |

No lights, no camera, no rig widgets, no IK/control bones. Build a Godot-side control rig
(`SkeletonIK3D`, `LookAtModifier3D`, ...) on the deform skeleton if you need one.

## Facial shape keys (morph targets, per mesh)
glTF morph targets belong to one mesh, so a face key exists on every mesh it moves. Drive the
same key name on all of them (a small script that sets `blend_shapes/<name>` on each mesh):

| Mesh | Keys |
|---|---|
| `Bob_Body` and `Bob_Teeth` | `sk_mouth_open` `sk_mouth_wide` `sk_mouth_narrow` `sk_mouth_smile` `sk_mouth_frown`, `sk_expr_neutral` `sk_expr_happy` `sk_expr_disgust` `sk_expr_urgency` `sk_expr_relief` |
| `Bob_Eye_L` | `sk_blink_L` + the 5 `sk_expr_*` eye shapes |
| `Bob_Eye_R` | `sk_blink_R` + the 5 `sk_expr_*` eye shapes |
| `Bob_Shorts` | `sk_shorts_bunch_ankle`, `sk_shorts_stretch_waist` (correctives, see below) |

`sk_mouth_open` swells a hidden dark half-circle behind the teeth. The upper teeth do not move.
For an expression, set the single `sk_expr_*` key to 0..1 on every mesh that has it.

## The shorts (what did and did not export)
In Blender, `BOB-rig["shorts_slide"]` (0 = at the hips, 1 = at the ankles) drives 11 bones through
drivers and Child Of constraints. **Drivers and constraints do not exist in glTF.** What Godot gets:

* the 11 `DEF-shorts_*` bones, parented to `DEF-spine` (waistband) and `DEF-thigh.L/.R` (legs + hem),
  so at rest the shorts follow the hips and thighs like any other clothing;
* the two corrective morph targets on `Bob_Shorts`.

To pull the shorts down in Godot, move each shorts bone straight **down in model space** by
`slide × travel`, and set the correctives:

| Bone | Travel at slide = 1 (m) |
|---|---|
| `DEF-shorts_waist` | 0.384 |
| `DEF-shorts_L_0` / `_R_0` | 0.380 |
| `DEF-shorts_L_1` / `_R_1` | 0.348 |
| `DEF-shorts_L_2` / `_R_2` | 0.314 |
| `DEF-shorts_L_3` / `_R_3` | 0.280 |
| `DEF-shorts_hem_L` / `_R` | 0.264 |

`sk_shorts_bunch_ankle = slide`, and `sk_shorts_stretch_waist = (1 - slide) × clamp(thigh spread / 0.9 rad, 0, 1)`.
The bands travel different distances on purpose: the fabric compresses and bunches near the ankles.

The simplest route for a real game: author the pull-down in Blender (the rig does it correctly there,
including following the shins when Bob bends over), then **export that as an animation** — Blender bakes the
constraint result into plain bone keys. Re-run `50_export_gltf.py` with `export_animations=True` for that.

## Hair, eyes, teeth
Rigid to the head bone (`DEF-spine.006`). There are no jiggle bones: Godot owns physics, so add
`SpringBoneSimulator3D` (or similar) to the hair there if you want it to swing.

## Re-exporting after a change
Scripts are idempotent; rebuild in this order, then export and validate:

```
12_hair_revision.py   (runs 10 + 11)     21_shorts_deform_prep.py  (runs 20)
40_materials.py       41_lights_camera.py
30_rig_body.py        31_rig_shorts.py   32_shapekeys_face.py   33_deform_test_poses.py
50_export_gltf.py     51_export_validate.py   (non-zero exit code if any of 39 checks fails)
```

`"<blender.exe>" -b bob-character.blend --python scripts/50_export_gltf.py` works headless.


## Animation clips (added 2026-09-21; the file changed, re-import it)
Every clip is in this .glb, named exactly as in the game's contract, 30 fps, **in place** (the clip only animates bones, the game moves the body), keyed on the 63 `DEF-*` bones. Godot turns them into an `AnimationPlayer` with one animation per name below.

| Clip | Frames | Length | Loop | Authored ground speed | Notes |
|---|---|---|---|---|---|
| `idle` | 90 | 3.000 s | **yes** | 0 (standing) | one breath and one slow weight shift per loop; both feet stay planted at the rest stance |
| `walk` | 20 | 0.667 s | **yes** | 1.0 m/s | two steps per cycle; last key == first key, so it loops with no jump |
| `run` | 15 | 0.500 s | **yes** | 3.1 m/s | two strides per cycle, both feet leave the ground for 4 of 15 frames; arms bent and pumping, torso leaning forward |
| `kick` | 42 | 1.400 s | no | 0 | **flying, big-swing, aggressive kick** (same clip as Jijio's): coil (0-9), huge backswing (9-13), leap and strike (13-16), hang at the peak with the foot trembling (16-20), fall and land in a crouch (20-26), stand up (26-42). Starts and ends standing. **Contact: frames 16-20.** Airborne roughly frames 12-25, apex +0.27 m. In place (jumps straight up); translate the body forward during frames 9-20 for a lunge |
| `kick_double` | 54 | 1.800 s | no | 0 | **extra**: flying double kick: right leg (brief tremble), then the legs switch in mid-air and the left leg kicks higher and holds still. **Contacts: frames 16-19 and 23-28.** Airborne about frames 12-33, apex +0.30 m |
| `kick_spin` | 54 | 1.800 s | no | 0 | **extra**: spinning roundhouse: coil, a full 360 degree spin in the air with the arms out, the right leg whips out at the end. **Contact: frames 32-37.** Airborne about frames 13-38. The body turns 360 degrees and ends facing the same way |
| `punch` | 30 | 1.000 s | no | 0 | **extra**: one big cartoon haymaker: wind-up away, staggered stance, the right fist snaps out. **Contact: frames 14-18** |
| `punch_combo` | 48 | 1.600 s | no | 0 | **extra**: five rapid alternating jabs (left, right, left, right, left), then a big right haymaker. **Contacts: jabs at frames 12, 16, 20, 24, 28 (about 2 frames each), haymaker 38-41** |
| `uppercut` | 40 | 1.333 s | no | 0 | **extra**: SHORYUKEN: a very deep crouch with the right fist dragged low, then the body ROCKETS about 0.4 m into the air in a spinning leap (one full turn) with the right arm thrust straight up over the head and the legs tucked; hang at the top, fall, land crouched with the fist still up, wobble and stand. **Contact: frames 12-16 (the fist rises past the chin), hang at the top to frame 22.** Airborne about frames 10-29, apex +0.42 m. Starts and ends standing, facing forward |
| `hook_right` | 42 | 1.400 s | no | 0 | **extra**: HAYMAKER HOOK: crouch and coil far back (body turned 80 degrees away, right arm cocked out wide), then the WHOLE BODY whips round about 150 degrees on planted feet with the right arm flat and fully extended at head height sweeping a huge arc, overshoot, a dizzy stagger and a wobble back to facing forward. **Contact: frames 15-20 (peak swing 17-20).** In place: the feet pivot, they do not travel |
| `sit` | 90 | 3.000 s | **yes** | 0 | **toilet clip, shorts DOWN at the ankles (baked)**: seated on the toilet, shins 35 degrees, small breathing and foot sway. Origin = the seat spot (the seat centre is 0.15 m behind it); hips 0.513 m above the floor |
| `sit_down` | 30 | 1.000 s | no | 0 | **toilet clip, shorts down**: a small HOP from 0.34 m in front of the seat spot (crouch, spring up and back over the bowl with the knees tucked, land, shins swing down). Ends on `sit` frame 0. The pelvis travels about 0.34 m (`DRIFT_OK` 0.42 m): place the body 0.34 m in front of the seat spot before playing it |
| `stand_up` | 30 | 1.000 s | no | 0 | **toilet clip, shorts down**: the reverse of `sit_down`; starts on `sit` frame 0 and ends 0.34 m in front of the seat spot, standing |
| `wipe` | 96 | 3.200 s | no | 0 | **toilet clip, shorts down**: the right hand reaches behind the right cheek (torso twisted, left arm flung out for balance), 4 wiping strokes at **frames 16-56** (side-to-side rub at constant depth, hand height raised 0.50->0.52 2026-09-23 to clear the seat), back to the seat (62), a disgusted inspection of the paper (68-78), settle. The right hand stays on the outside of the hip, fingers level |
| `tissue_grab` | 90 | 3.000 s | no | 0 | **toilet clip, shorts down**: leans out 18 degrees to the wall holder at (-0.45, 0.03, 0.75) in Bob's frame, **grabs the tail at frame 22**, pulls to 38, **tears at 40**, folds the pad 42-72 (the sheet prop is in the hand from **frame 44**), sits back |
| `pants_down` | 45 | 1.500 s | no | 0 | **toilet clip, the shorts go DOWN (baked)**: the urgent yank. Bob stands 0.34 m in front of the seat spot (where `sit_down` starts), grabs the waistband at the hips (frames 4-8), hunches deep (8-14), lets go and the shorts FALL to the ankles (**frames 14-21**, the ankle bunching blend shape goes 0 -> 1 in the same frames), steps out of the left leg (24) and the right (28), straightens (33), a small hop (37) and lands (41). **Starts standing with the shorts WORN** (like `idle`, but 0.34 m in front of the seat spot) and **ends exactly on `sit_down` frame 0** (standing, shorts at the ankles), so `pants_down` -> `sit_down` chains with no jump. The hips move up to 0.09 m away from the toilet while he hunches (the pelvis drifts, `DRIFT_OK` 0.15 m); the feet stay planted |
| `press_flush` | 38 | 1.267 s | no | 0 | **toilet clip, shorts down**: seated, URGENT SLAM. Starts/ends on `sit` frame 0. **0-8** wind-up + the right hand swings round the outside of the hip (never straight across the chest). **8-15** chest twists ~-60 degrees toward the flush lever (knob at (-0.03, 0.405, 0.705) in Bob's frame, on the tank behind/above the seat); the hand is clamped to the arm's real reach (never stretched: limb stretch 1.0000) so it gets as close to the knob as physically possible. **15-18** the SLAP: brief hold at contact (**the lever's own press animation is a separate trigger in Godot, not part of this clip**). **18-30** pulls back the same outside arc, a small hop of relief (hips +2 cm), settles. **30-38** back to the seated rest pose. **Known, accepted overlap (owner OK'd 2026-09-23):** the forearm brushes the real seat ring for about 0.2 s at the slap (frames 12-18): 38 body vertices vs an 8-vertex baseline (same order as the accepted `uppercut` fist-in-hip overlap). Tried and rejected: a pelvis shift toward the lever (pushed the legs into the bowl instead, 7->68 shin vertices) and a backward lean (swung the chest into the tank, 372 body vertices) -- twist-only was the smallest of the three overlaps found. **Not verified against a picture of the actual lever contact** (the standard camera views don't include the tank/handle in frame) |
| `groove` | 36 | 1.200 s | **yes** | 0 | **dance (level 5, 2026-09-25)**: two-beat bounce at 100 BPM; knees DOWN on the beat at **frames 0 and 18**, shoulders roll, head nods. Frame 0 = the shared dance STANCE (knees bent, fists up in front): every dance clip starts there |
| `move_left` | 18 | 0.600 s | no | 0 | **dance, one beat**: toprock toward **SCREEN left** = the character's own RIGHT (in the battle he faces the camera): the left foot crosses over, the right foot steps out wide, dip, both arms thrown open. **Accent frames 9-12.** Starts and ends in the STANCE |
| `move_right` | 18 | 0.600 s | no | 0 | **dance, one beat**: the mirrored step toward **SCREEN right** (his left), but the left arm points high out to the side and the right fist pulls in to the chest (different from `move_left`). **Accent 9-12** |
| `move_down` | 18 | 0.600 s | no | 0 | **dance, one beat**: coffee-grinder sweep: low crouch, both palms flat on the floor (frames 4-13), the left leg sweeps a low arc from front-left round to behind (4-13), pop back up |
| `move_up` | 18 | 0.600 s | no | 0 | **dance, one beat**: one-hand freeze on the right palm, legs kicked up to the left, the left arm straight up; **freeze held frames 7-12**, snap back |
| `victory` | 45 | 1.500 s | no | 0 | **dance, round end**: pops up, two fist pumps (fist highest at **frames 9 and 18**, on the beats), ends in a held b-boy pose, arms crossed, chin up. Does NOT return to the stance |
| `defeat` | 45 | 1.500 s | no | 0 | **dance, round end**: shoulders drop, head hangs, a "forget it" wave of the right hand (frames 14-24), slump with the hands on the knees (held from 34). Does NOT return to the stance |
| `flare` | 36 | 1.200 s | no | 0 | **dance, big move (2 beats)**: squat onto both hands, the body turns TWICE round a fixed vertical axis with the legs straddled wide circling round, each hand hops as a leg passes (spin frames 7-29), back to the stance. The hips orbit the axis 0.15 m away (root drift 0.33 m, `DRIFT_OK` 0.35: it is NOT travel, the clip ends where it started); ends facing front |
| `headspin` | 72 | 2.400 s | no | 0 | **dance, big move (4 beats)**: tip onto the head (knees tucked, frame 12), legs open in a V, TWO spins on the crown with the arms out (**frames 17-45**), then a **bent-arm freeze** (palms on the floor, elbows bent, head just off the floor, legs straight up; held **frames 53-60**; the arms are too short for a straight-arm handstand), squat, stance |
| `worm` | 72 | 2.400 s | no | 0 | **dance, big move (4 beats)**: drop into a push-up (12), two waves roll through the body (chest dips + hips rise at 18 / 38, chest lifts + feet kick up at 26 / 46), push back up to the stance. In place: slide the body forward in Godot if the worm should travel |
| `stumble` | 12 | 0.400 s | no | 0 | **dance, a MISSED beat**: from the STANCE the left toe catches (heel up), the body lurches forward, the left arm flings up, the right foot stamps forward to catch the fall (frame 6), back to the STANCE. Never falls over |
| `squirm` | 60 | 2.000 s | **yes** | 0 | **queue (2026-09-27)**: holding it in: knees squeezed, bouncing heel to heel, left hand on the belly, right hand clutching the butt, head darting left/right (looking for a free stall); **frames 30-40 a stiff clench** (up on the toes, fists tight, chin up), then a hip wiggle |
| `talk` | 90 | 3.000 s | **yes** | 0 | **queue**: chatting animatedly with someone on his LEFT: chest and head turned a little that way (feet stay forward), open palms (12), two chops (26-40), a big shrug (52-60), leans in rolling both hands "and then..." (66-82), nodding throughout. Body only, the mouth does not move |
| `twerk` | 36 | 1.200 s | **yes** | 0 | **queue**: wide squat on the balls of the feet, hands on the outside of the knees, **4 hip pops at frames 3, 12, 21, 30** with a side jiggle; head steady. Hips at 0.32 m |
| `swim` | 36 | 1.200 s | **yes** | 0 | **swim (level 2 flood, 2026-09-27)**: heads-up breaststroke at the surface: arms sweep out and back, hands meet under the chin and shoot forward, frog kick (heels up, out, squeeze), glide. The mouth stays 3-6.5 cm above the water the whole loop |
| `duck_dive` | 36 | 1.200 s | no | 0 | **swim**: starts on `swim` frame 0: one pull, jackknife at the hips (head down), the legs swing up straight out of the water, he slides under and levels out with the hips **0.90 m below the surface**, ending exactly on `swim_under` frame 0. The body sinks inside the clip (vertical, not travel): keep the origin on the water line |
| `swim_under` | 45 | 1.500 s | **yes** | 0 | **swim**: fully under water, flat, hips 0.90 m down, slow breaststroke with a full pull and a long glide. Nothing sticks out of the water |
| `tread_water` | 45 | 1.500 s | **yes** | 0 | **swim**: upright, head and shoulders out (mouth 13 cm above the water), legs cycling (2 per loop), hands sculling flat (3 per loop) |
| `float` | 90 | 3.000 s | **yes** | 0 | **swim**: on the back, limbs loose and spread, one slow breath per loop, a little drift; mouth 5.5 cm above the water |

* **Looping is not stored in a .glb.** Godot imports every clip with `loop_mode = 0`. The game must set `Animation.loop_mode = Animation.LOOP_LINEAR` on the clips marked "Loop: yes" (or use an import script). The table is the source of truth.
* **Foot sliding:** the feet are planted at the authored ground speed. Play the clip with `speed_scale = actual body speed / authored speed`. Bob's legs are 0.445 m, so a natural walk is about 1 m/s. The game's `walk_speed = 3.0` for Bob is a **run** speed for this body: `run` (3.1 m/s) plays at `speed_scale` 0.97 there, and the 5.0 sprint at 1.6; the `walk` clip at 3.0 would need `speed_scale = 3.0` (a 0.22 s cycle, legs a blur). Suggest walk 1.0 to 1.6 m/s, run 3 to 5 m/s. Blend `idle` -> `walk` -> `run` with the AnimationTree/`AnimationPlayer` blend time (feet start planted, all clips key the same controls, so blending is safe).
* The **shorts bones are baked** into the clip (they follow the hips and thighs). Do not also drive `DEF-shorts_*` by code while a clip plays.
* Godot measured against Blender over 7 frames of the clip: every bone within 0.002 m except the feet and toes (up to 0.007 m: Rigify's bendy/tweak bones are not carried by glTF).
* The .glb is about 3.3 MB with seventeen clips (every clip carries all 63 bones, 30 keys per second); Godot's importer drops constant tracks.
* All clips except the first three are one-shots: they start and end in the standing rest pose (so they blend with `idle`); `kick` is in the game's contract, the other six attack clips are extras the owner asked for. In the attacks the shorts follow the hips and thighs rigidly (they are not pulled by any clip): fine for kicks and punches.
* Godot vs Blender: within 0.002 m except feet, toes, hands (up to 0.0105 m in `kick_spin`).
* Face shape keys are not animated by any clip (the game drives them).
* **Skinning changed** (hips): wider pelvis blend, smoothed shirt weights, softer shorts hips (see STATUS.md). Rest pose and mesh are identical; only how it bends changed. Re-import once.
* **Wrists (2026-09-21, re-import once):** in `kick`, `kick_double`, `kick_spin`, `punch`, `punch_combo`, `uppercut`, `hook_right` the hands now continue the line of the forearm (no bent wrists). Only the hand direction changed; the body motion, timing and contact frames above are as before. `idle`, `walk`, `run` are byte-identical to the previous file. Godot vs Blender: within 0.0108 m (a toe in `kick_double`), hands within 0.0075 m. The .glb is 3.1 MB (15 clips, see below).
* **Toilet clips = shorts down, BAKED (2026-09-22, re-import once).** In `sit sit_down stand_up wipe tissue_grab` the shorts are already at the ankles from frame 0; in `pants_down` they travel from the hips to the ankles. The shorts helper bones (`DEF-shorts_*`) carry baked keys and the clip also has a **blend-shape track on `Bob_Shorts` only** (`sk_shorts_bunch_ankle` = 1.0, `sk_shorts_stretch_waist` = 0.0) so the fabric bunches at the ankles. **While one of these 6 clips plays do NOT drive `DEF-shorts_*` or the shorts blend shapes by code**, and do not touch any face blend shape (no clip animates a face key). The default blend-shape weights of `Bob_Shorts` are 0, 0: idle, walk, run and the attacks show the shorts worn. The game's own pull-down (shorts sliding by code) keeps working when none of these clips is playing.
* Verification of the baked shorts: Godot vs Blender bone heads within 2 mm for all 11 shorts bones; skinned shorts vertices of the re-imported file within 3.7 mm of Blender's constrained shorts (`tools/glb_mesh_compare.py`, 4 clips, 22 frames); the 10 older clips are byte-identical to the file before the bake. The .glb is 3.3 MB with 16 clips. `pants_down`: shorts vertices of the re-imported file within 5.3 mm of Blender's through the fall (frames 14-24), bones within 8.9 mm (a toe) in Godot.
* Toilet fit (measured against the real toilet mesh, `tools/clip_env_collision.py`): the body is clear of the bowl in every frame except the shins (4-15 vertices, brushing); the pooled shorts cloth touches the bowl (about 65-80 vertices, 5 cm deep). Cloth only.

## Dance battle clips (added 2026-09-25; the file changed, re-import it)
* 100 BPM, 30 fps: one beat = 18 frames. The four arrow moves are one beat each; `groove` loops over two beats with the knees down on frames 0 and 18.
* Every dance clip starts in the same STANCE (= `groove` frame 0), and all except `victory` / `defeat` end in it, so they chain in any order with no blend. From `idle` blend in over ~0.1 s.
* Arrow moves follow the SCREEN, not the character: `move_left` steps to the character's own right because he faces the battle camera. If a dancer ever faces away from the camera, swap left/right.
* In place: the game adds no root motion (the flare's hips orbit a fixed point and return; see the table).
* `stumble` (both, 2026-09-25 later) starts and ends in the STANCE. The crowd loops `cheer` `wave` `clap` are on Jijio only (same skeleton: the game may play them on Bob too); set `loop_mode = LOOP_LINEAR` on them.
* Same 10 clips, same names, on Bob and on Jijio (same skeleton; each file carries its own copy tuned to its clothes and hair).

## Queue loops (added 2026-09-27; the file changed, re-import it)
* New clips `squirm`, `talk`, `twerk` (table above): the same moves as Jijio's (same skeleton, same script). All three **loop**: set `loop_mode = LOOP_LINEAR`; cross-fade ~0.25 s from `idle` and back. The shorts are not animated by these clips (default weights [0, 0]).
* The 28 older clips are byte-identical (fingerprints). Validator 175/175. Real Godot vs Blender: squirm 7.4 mm (toe), talk 5.1 mm (hand), twerk 6.0 mm (toe); loop seams 0.
* Use: the same queue rule as in `jijio_godot_notes.md` ("Waiting-room queue loops"), if Bob ever waits in a queue or is an NPC; the player Bob can use them as idle fidgets.

## Swim clips (added 2026-09-27; the file changed, re-import it)
* New clips `swim`, `duck_dive`, `swim_under`, `tread_water`, `float` (table above). **Origin = the WATER SURFACE, not the floor**: put the character's origin on the wave height (y = water level) while they play; every height in these clips is measured from that line. The mouth height is solved per frame, so `swim`, `tread_water` and `float` keep the face out of the water.
* Loops: `swim`, `swim_under`, `tread_water`, `float` -> `loop_mode = LOOP_LINEAR`. `duck_dive` is a one-shot bridge: play it from `swim` and chain straight into `swim_under` (it ends on that clip's first frame, 0.90 m down). There is no surfacing clip yet: cross-fade `swim_under` -> `swim` over ~0.4 s while raising the body, or ask the factory for a `surface` clip.
* In place: `swim` and `swim_under` do not travel; move the body in Godot (`walk`-style `speed_scale` is not needed, pick a swim speed ~0.6-0.8 m/s).
* The 31 older clips are byte-identical in this file (fingerprints); only these were added. Validator 199/199. Real Godot vs Blender (5 frames each): worst 6.6 mm (toe), all RESULT OK.
