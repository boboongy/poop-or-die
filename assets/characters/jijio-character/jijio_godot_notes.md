# Jijio → Godot: import notes

`exports/jijio.glb`: binary glTF 2.0, 601 KB, everything embedded (no external files).

## What is in it
| | |
|---|---|
| Size | body 1.300 m like Bob; hair spikes reach 1.317 m; feet on the ground plane, origin between the feet |
| Facing | Blender front (-Y) becomes glTF +Z, the normal convention for imported Blender models |
| Meshes (9, separate) | `Jijio_Body` `Jijio_Hair` `Jijio_Eye_L` `Jijio_Eye_R` `Jijio_Tongue` `Jijio_Shirt` `Jijio_Pants` `Jijio_Sandal_L` `Jijio_Sandal_R` |
| Triangles | 14,148 total |
| Skeleton | 1 skin, **63 deform bones** (`DEF-*`), the **same skeleton, bone names and A-pose rest as Bob**: animations can be shared between the two |
| Influences | max 4 per vertex, weights sum to 1 |
| Materials (11) | `M_Jijio_*`, Principled BSDF → `StandardMaterial3D`. Hair, shirt and pants are open shells and export **double-sided** |
| Animations | see **Animation clips** below (test poses stay in the .blend and are not exported) |

No lights, camera, rig widgets or IK/control bones. Build a Godot-side control rig if the game needs IK or look-at.

## Face (morph targets, per mesh)
glTF morph targets belong to one mesh, so a face key exists on every mesh it moves. Set the same key name on all of them.

| Mesh | Keys |
|---|---|
| `Jijio_Body` | `sk_mouth_open` `sk_mouth_wide` `sk_mouth_narrow` `sk_mouth_smile` `sk_mouth_frown` `sk_tongue_in` + 5 `sk_expr_*` |
| `Jijio_Tongue` | `sk_mouth_open` `sk_tongue_in` + 5 `sk_expr_*` |
| `Jijio_Eye_L` / `_R` | `sk_lid_raise_L/R` `sk_blink_L/R` + 5 `sk_expr_*` |
| `Jijio_Pants` | `sk_pants_bunch_ankle`, `sk_pants_stretch_waist` |

* **Default face is tongue out** with the sleepy half-lidded eyes (lids are real geometry).
* `sk_tongue_in` = 1 retracts the tongue **and closes the mouth to a thin line**; set it on `Jijio_Body` and `Jijio_Tongue` together.
* `sk_lid_raise_*` opens the eyes wide, `sk_blink_*` closes them. `sk_expr_neutral` is the all-zero anchor.
* Expression keys are absolute: set a single `sk_expr_*` to 0..1 on every mesh that has it.

## The pants (what did and did not export)
In Blender `JIJIO-rig["pants_slide"]` (0 = worn, 1 = pooled at the ankles) drives 11 bones with drivers and Child Of constraints. **Drivers and constraints do not exist in glTF.** What Godot gets:

* 11 `DEF-pants_*` bones, parented like this (mirrors the Blender-side carriers; the pants reach the ankle so the knee bends inside them):

| Bone | Parent in the glb |
|---|---|
| `DEF-pants_waist` | `DEF-spine` |
| `DEF-pants_L_0`, `_L_1` (and R) | `DEF-thigh.L` / `.R` |
| `DEF-pants_L_2`, `_L_3`, `DEF-pants_hem_L` (and R) | `DEF-shin.L` / `.R` |

  Verified on the re-imported file: the hem stays 1 cm from the ankle for thigh -50 / knee +60, thigh +50 / knee -60 and thigh -50 / knee -60.
* the two corrective morph targets on `Jijio_Pants`.

To pull the pants down in Godot, move each pants bone straight **down in model space** by `slide × travel`:

| Bone | Travel at slide = 1 (m) |
|---|---|
| `DEF-pants_waist` | 0.314 |
| `DEF-pants_L_0` / `_R_0` | 0.301 |
| `DEF-pants_L_1` / `_R_1` | 0.224 |
| `DEF-pants_L_2` / `_R_2` | 0.147 |
| `DEF-pants_L_3` / `_R_3` | 0.065 |
| `DEF-pants_hem_L` / `_R` | 0.010 |

Correctives: `sk_pants_bunch_ankle = slide`; `sk_pants_stretch_waist = (1 - slide) × clamp(thigh spread / 0.9 rad, 0, 1)`.
The bands travel different distances on purpose: the 0.46 m of fabric bunches into a fat cuff at the ankles. Note that at slide = 1 in Blender the whole waistband also follows the shins; in Godot, when you slide, re-parent or bake accordingly (the easiest route is to author the pull-down in Blender and export it as an animation with `export_animations=True`, which bakes the constraint result into plain bone keys).

## Hair, eyes, tongue
Rigid to the head bone (`DEF-spine.006`). The hair is one slab hanging behind the arm plane (it does not collide with the arms in the rest pose); it will clip through the shoulders in deep bends because it is rigid. Add `SpringBoneSimulator3D` to the hair in Godot if you want it to swing.

## Known limits
* Hair clips through the shoulders and back in deep forward bends (rigid, by choice).
* At `pants_slide` = 1 the pants gather into a chunky cuff over the sandals.
* Depth of hair, sleeves and pants is assumed (no side view was available).

## Rebuild order (all scripts idempotent; run from the project folder)
```
12_face.py (runs 11 -> 10)   13_hair.py   20_clothing.py   40_materials.py   41_lights_camera.py
30_rig_body.py   31_rig_pants.py   32_shapekeys_face.py   33_deform_test_poses.py
50_export_gltf.py   51_export_validate.py    (36 checks, non-zero exit on failure)
```
12 rebuilds the whole body collection (including the eyes' lid keys), so re-run 13, 30, 31, 32 after it. `glb_roundtrip.py -- exports/jijio.glb out.png` re-imports the file in a fresh process.


## Animation clips (added 2026-09-21; the file changed, re-import it)
Every clip is in this .glb, named exactly as in the game's contract, 30 fps, **in place** (the clip only animates bones, the game moves the body), keyed on the 63 `DEF-*` bones. Same skeleton, bone names and rest pose as Bob, so Godot builds one `AnimationPlayer` per file with one animation per name below.

| Clip | Frames | Length | Loop | Authored ground speed | Notes |
|---|---|---|---|---|---|
| `idle` | 90 | 3.000 s | **yes** | 0 (standing) | sleepy slouch: torso leaning about 4 degrees, head hanging about 6 degrees, one slow breath and weight shift per loop; both feet stay planted at the rest stance |
| `walk` | 20 | 0.667 s | **yes** | 1.0 m/s | same walk as Bob's (same skeleton); two steps per cycle, last key == first key |
| `run` | 15 | 0.500 s | **yes** | 3.1 m/s | same run as Bob's; two strides per cycle, both feet leave the ground for 4 of 15 frames; arms bent and pumping, torso leaning forward |
| `wash` | 48 | 1.600 s | **yes** | 0 | washing hands at a sink: leaning 18 degrees over the basin, palms together and fingers pointing forward-down, the hands sliding past each other (real hand rubbing), two rubs per loop. See "Where the clips expect the character" |
| `sit_down` | 30 | 1.000 s | no | 0 | **extra clip, not in the contract**: standing **0.34 m in front of the seat spot** with the back to the seat -> a small crouch, then a HOP up and back over the bowl with the knees tucked, land on the seat, shins swing down -> ends exactly on the first frame of `sit` |
| `sit` | 90 | 3.000 s | **yes** | 0 | seated on the toilet: thighs horizontal, shins dangling and swinging gently, hands on the knees, slow breathing |
| `stand_up` | 30 | 1.000 s | no | 0 | the reverse: from the first frame of `sit` -> tuck the knees, hop up and forward over the bowl, land -> standing **0.34 m in front of the seat spot** |
| `kick` | 42 | 1.400 s | no | 0 | **flying, big-swing, aggressive kick**: coil (0-9), huge backswing (9-13), leap and strike (13-16), hang at the peak with the foot trembling (16-20), fall and land in a crouch (20-26), stand up (26-42). Starts and ends in the standing rest pose. **Contact: the foot is fully out from frame 16 (0.53 s) to 20.** Airborne roughly frames 12-25, apex +0.27 m at frame 17. In place (only jumps straight up); to lunge, translate the body forward during frames 9-20 (the foot reaches about 0.39 m in front of the hips) |
| `kick_double` | 54 | 1.800 s | no | 0 | **extra**: flying double kick: the right leg kicks (the foot trembles briefly with rage), then the legs switch in mid-air and the left leg kicks higher and **holds perfectly still** (no shake, owner's request). **Contacts: frames 16-19 and 23-28.** Airborne about frames 12-33, apex +0.30 m. Starts and ends standing |
| `kick_spin` | 54 | 1.800 s | no | 0 | **extra**: spinning roundhouse: coil, a full 360 degree spin in the air with the arms out, the right leg whips out at the end. **Contact: frames 32-37.** Airborne about frames 13-38. The body turns 360 degrees and ends facing the same way (the pelvis bone rotates, it does not travel) |
| `punch` | 30 | 1.000 s | no | 0 | **extra**: one big cartoon haymaker: wind-up away, staggered stance, the right fist snaps out. **Contact: frames 14-18** |
| `punch_combo` | 48 | 1.600 s | no | 0 | **extra**: a flurry of five rapid alternating jabs (left, right, left, right, left), then a big right haymaker. **Contacts: jabs at frames 12, 16, 20, 24, 28 (about 2 frames each), haymaker 38-41** |
| `uppercut` | 40 | 1.333 s | no | 0 | **extra**: SHORYUKEN: a very deep crouch with the right fist dragged low, then the body ROCKETS about 0.4 m into the air in a spinning leap (one full turn) with the right arm thrust straight up over the head and the legs tucked; hang at the top, fall, land crouched with the fist still up, wobble and stand. **Contact: frames 12-16 (the fist rises past the chin), hang at the top to frame 22.** Airborne about frames 10-29, apex +0.42 m. Starts and ends standing, facing forward |
| `hook_right` | 42 | 1.400 s | no | 0 | **extra**: HAYMAKER HOOK: crouch and coil far back (body turned 80 degrees away, right arm cocked out wide), then the WHOLE BODY whips round about 150 degrees on planted feet with the right arm flat and fully extended at head height sweeping a huge arc, overshoot, a dizzy stagger and a wobble back to facing forward. **Contact: frames 15-20 (peak swing 17-20).** In place: the feet pivot, they do not travel |
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
| `cheer` | 18 | 0.600 s | **yes** | 0 | **crowd (level 5 audience)**: a little jump with both arms thrown up in a wide V; **apex = frame 9** (put it on the beat), lands in a small crouch. Airborne about frames 6-12. Starts/ends in its own crouch (blend in from `idle`) |
| `wave` | 36 | 1.200 s | **yes** | 0 | **crowd**: both arms up in a wide V, the body sways to its left (beat 1, frame 0) and right (beat 2, frame 18), knees down on each beat |
| `clap` | 18 | 0.600 s | **yes** | 0 | **crowd**: a knee bounce and ONE clap in front of the chest, **hands meet at frame 9** (on the beat) |
| `squirm` | 60 | 2.000 s | **yes** | 0 | **queue (2026-09-27)**: holding it in: knees squeezed, bouncing heel to heel, left hand on the belly, right hand clutching the butt, head darting left/right (looking for a free stall); **frames 30-40 a stiff clench** (up on the toes, fists tight, chin up), then a hip wiggle |
| `talk` | 90 | 3.000 s | **yes** | 0 | **queue**: chatting animatedly with someone on his LEFT: chest and head turned a little that way (feet stay forward), open palms (12), two chops (26-40), a big shrug (52-60), leans in rolling both hands "and then..." (66-82), nodding throughout. Body only, the mouth does not move (a speech bubble fits) |
| `twerk` | 36 | 1.200 s | **yes** | 0 | **queue**: wide squat on the balls of the feet, hands on the outside of the knees, **4 hip pops at frames 3, 12, 21, 30** (half a beat each at 100 BPM) with a side jiggle; head steady. Hips at 0.32 m: it is low, check the queue spacing |
| `swim` | 36 | 1.200 s | **yes** | 0 | **swim (level 2 flood, 2026-09-27)**: heads-up breaststroke at the surface: arms sweep out and back, hands meet under the chin and shoot forward, frog kick (heels up, out, squeeze), glide. The mouth stays 3-6.5 cm above the water the whole loop |
| `duck_dive` | 36 | 1.200 s | no | 0 | **swim**: starts on `swim` frame 0: one pull, jackknife at the hips (head down), the legs swing up straight out of the water, he slides under and levels out with the hips **0.90 m below the surface**, ending exactly on `swim_under` frame 0. The body sinks inside the clip (vertical, not travel): keep the origin on the water line |
| `swim_under` | 45 | 1.500 s | **yes** | 0 | **swim**: fully under water, flat, hips 0.90 m down, slow breaststroke with a full pull and a long glide. Nothing sticks out of the water |
| `tread_water` | 45 | 1.500 s | **yes** | 0 | **swim**: upright, head and shoulders out (mouth 13 cm above the water), legs cycling (2 per loop), hands sculling flat (3 per loop) |
| `float` | 90 | 3.000 s | **yes** | 0 | **swim**: on the back, limbs loose and spread, one slow breath per loop, a little drift; mouth 5.5 cm above the water |
| `swim_panic` | 30 | 1.000 s | **yes** | 0 | **swim (Jijio only)**: upright, head thrown back, arms thrash up in a wide V and slap the water (2 per arm per loop), legs kick wildly, the head bobs down to the water line |

* **Looping is not stored in a .glb.** Godot imports every clip with `loop_mode = 0`. The game must set `Animation.loop_mode = Animation.LOOP_LINEAR` on the clips marked "Loop: yes". The table is the source of truth.
* **Foot sliding:** the feet are planted at the authored ground speed. Play with `speed_scale = actual body speed / authored speed`: `walk_speed = 1.6` gives `speed_scale = 1.6` (a 0.42 s cycle, brisk but fine for Jijio). Jijio's chase speed (4.0) plays `run` at `speed_scale` 1.29; his shuffle (2.5) plays `run` at 0.8 or `walk` at 2.5 (a 0.27 s cycle, too fast: prefer `run` slowed).
* The **pants bones are baked** into the clips (waist and upper bands follow the hips and thighs, the lower bands and hem follow the shins). Do not also drive `DEF-pants_*` by code while a clip plays.
* Godot measured against Blender over 7 frames per clip: every bone within 0.002 m except the feet, toes and the lowest pants bands (up to 0.007 m, 0.0105 m in `kick_spin`: Rigify's bendy/tweak bones are not carried by glTF). Idle is within 0.0006 m.
* Face shape keys (default: tongue out) are not animated by any clip (the game drives them).
* **Skinning changed** (hips, shirt): wider pelvis blend, smoothed shirt weights (see STATUS.md). Rest pose and mesh are identical; only how it bends changed. Re-import once. Known limit: with both arms overhead (handstand-like poses) the shirt armpit stretches about 3x; not visible in any current clip.

### Where the clips expect the character (origin = on the floor)
* **`sit`, `sit_down`, `stand_up`:** origin at the game's seat spot (0.15 m forward of the seat centre, `toilet_session.gd _seat_spot`); in `sit` the hips are directly above the origin. **`sit_down` starts and `stand_up` ends with the whole body 0.34 m IN FRONT of the origin** (forward = +Z in Godot), facing away from the toilet: the pelvis and feet travel inside the clip, so the game only has to walk the character to that spot (0.34 m in front of the seat spot) and play `sit_down`; after `stand_up` he is standing 0.34 m in front of the seat spot. Authored for a seat ring top at **0.475 m** (the lid is 0.475-0.505). The clips **bake the hip height** (0.513 m, the pelvis bottom hangs 0.038 m below the hip joint): leave the model's y at 0 while they play (the game's `seat_y = seat top + 0.03 - 0.5` lowering must go). The character's standing hip height is 0.50 m, so on this seat the feet dangle about 0.2 m above the floor.
* **`wash`:** origin at the game's sink spot (`sinks.gd stand_spot`, 0.38 m from the wall side, the basin front at 0.60), facing the sink. Wrists work 0.30 m ahead at 0.86 m height, palms together, fingers pointing forward-down so the fingertips end up around 0.37 m ahead under the spout (counter 0.85 m, basin bottom 0.72 m, spout tip 0.92 m at 0.42 m ahead). The torso leans 18 degrees over the basin (the arms only reach about 0.31 m from the shoulder); the chest stays clear of the counter's front edge (0.22 m ahead).
* One-shot clips (`sit_down`, `stand_up`, the kicks and punches) start and end at poses that match the neighbouring clips' first/last frames, so blends are short.
* **Wrists (2026-09-21, re-import once):** in `sit`, `sit_down`, `stand_up`, `kick`, `kick_double`, `kick_spin`, `punch`, `punch_combo`, `uppercut`, `hook_right` the hands now continue the line of the forearm (no bent wrists). Only the hand direction changed; body motion, timing and contact frames are as before. `idle`, `walk`, `run` and `wash` are byte-identical to the previous file (`wash` keeps its own palm-to-palm hand pose). Godot vs Blender: within 0.0108 m (a toe in `kick_double`). The .glb is 2.83 MB.
* **`wash` changed (2026-09-22, re-import once):** the elbows are raised (about 45 degrees out and up) so the forearms pass over the basin rim at the standing spot (0.22 m from the sink front, counter 0.85 m); hands, rub and timing are unchanged. Only sleeve cloth (<= 2.5 cm) can touch the sink front.

## Dance battle clips (added 2026-09-25; the file changed, re-import it)
* 100 BPM, 30 fps: one beat = 18 frames. The four arrow moves are one beat each; `groove` loops over two beats with the knees down on frames 0 and 18.
* Every dance clip starts in the same STANCE (= `groove` frame 0), and all except `victory` / `defeat` end in it, so they chain in any order with no blend. From `idle` blend in over ~0.1 s.
* Arrow moves follow the SCREEN, not the character: `move_left` steps to the character's own right because he faces the battle camera. If a dancer ever faces away from the camera, swap left/right.
* In place: the game adds no root motion (the flare's hips orbit a fixed point and return; see the table).
* `stumble` (both, 2026-09-25 later) starts and ends in the STANCE. The crowd loops `cheer` `wave` `clap` are on Jijio only (same skeleton: the game may play them on Bob too); set `loop_mode = LOOP_LINEAR` on them.
* Same 10 clips, same names, on Bob and on Jijio (same skeleton; each file carries its own copy tuned to its clothes and hair).

## Waiting-room queue loops (added 2026-09-27; the file changed, re-import it)
* New clips `squirm`, `talk`, `twerk` (table above). All three **loop**: set `loop_mode = LOOP_LINEAR`. In place, start/end on their own pose (not the idle pose): **cross-fade 0.2-0.3 s** from `idle` and back (`AnimationPlayer.play(name, 0.25)`).
* The 28 older clips are byte-identical in this file (fingerprints); only these 3 were added. Validator 176/176. Real Godot vs Blender: squirm 7.4 mm (toe), talk 5.1 mm (hand), twerk 6.0 mm (toe); loop seams 0.
* **Suggested queue rule (owner's goal: the queue should look less static; the game side decides the details):** a queued Jijio plays `idle` most of the time; every 4-8 s (random per Jijio, so the line does not move in sync) pick one of `squirm` (weight 3: it is a toilet queue), `talk` (weight 2, only if another queued Jijio stands within ~1.2 m; turn his body so that neighbour is on his LEFT, as the clip turns the chest that way) or `twerk` (weight 1), play it 1-3 loops, then back to `idle`. Stop any of them at once (cross-fade to `walk`) when the queue moves or he steps aside for Bob (`make_way`).

## Swim clips (added 2026-09-27; the file changed, re-import it)
* New clips `swim`, `duck_dive`, `swim_under`, `tread_water`, `float`, `swim_panic` (table above). **Origin = the WATER SURFACE, not the floor**: put the character's origin on the wave height (y = water level) while they play; every height in these clips is measured from that line. The mouth height is solved per frame, so `swim`, `tread_water` and `float` keep the face out of the water.
* Loops: `swim`, `swim_under`, `tread_water`, `float`, `swim_panic` -> `loop_mode = LOOP_LINEAR`. `duck_dive` is a one-shot bridge: play it from `swim` and chain straight into `swim_under` (it ends on that clip's first frame, 0.90 m down). There is no surfacing clip yet: cross-fade `swim_under` -> `swim` over ~0.4 s while raising the body, or ask the factory for a `surface` clip.
* In place: `swim` and `swim_under` do not travel; move the body in Godot (`walk`-style `speed_scale` is not needed, pick a swim speed ~0.6-0.8 m/s).
* The 31 older clips are byte-identical in this file (fingerprints); only these were added. Validator 205/205. Real Godot vs Blender (5 frames each): worst 6.6 mm (toe), all RESULT OK.
