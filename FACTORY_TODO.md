# Factory TODO: what still has to be made in Blender

Living list. Claude adds to it whenever the game needs something the published assets don't have. Everything here is made in `mi-gaming-factory`, then republished with `python tools/publish_to_game.py <slug>`. Never edit `assets/` here.

Bob and Jijio share the same 63-bone skeleton and bone names, so an animation made for one can be reused on the other (retarget by bone name in Godot).

## Priority order and delivery contract (2026-09-21; PROPOSAL from the game side, the factory session may adjust and must then say so in the asset's godot_notes.md)

Work these in order; deliver in small batches (each republish costs the game side one re-import + wiring + test round). After each publish the owner tells the game session the slug and what changed.

| Batch | What | Why now |
|---|---|---|
| 1 | Bob **idle, walk, run**; Jijio **idle, walk** (Bob's can be reused on Jijio: same skeleton) | Every level, the queue and the new walkers use them; biggest visible change. Jijio also needs a **pacing turn** only if walk cannot loop-turn (Godot turns the body itself, so a plain loop is enough) |
| 2 | Jijio **kick**, **sit** (loop) + **stand up**, **wash hands** (loop); Bob **wipe**, **press flush handle** | Replace today's code poses (timeout kick, stall occupants, sink washing, toilet sequence) |
| 3 | Toilet: **flush handle** as its own object; **collision for every stall** (items 1 and 4 below) | Ending sequence, and real walls instead of Godot-built boxes |
| 4 | Level 2 props: **mop, bucket, wet floor sign**; Bob **mop stroke** (one swing per click, about 0.5 s); Jijio **slip** (fall and get up); Bob **slip** | Level 2 "Wet floor" (BUILT with stand-ins 2026-09-21: `mop_prop.gd` = box bucket + stick mop, `flood.gd` `_make_sign()` = two yellow panels, code swing and code fall; each stand-in is one spot to replace when the real prop/clip is published. Mop: origin at the mop head on the floor, handle along +Y; the sign has no collision) |
| 5 | Jijio **floor sit** (loop): **cross-legged OR squat, whichever skins cleaner** (game side recommends squat; try it first, switch if it looks bad). Clip name `sit_floor` | Owner decided 2026-09-21: some walkers sit on the floor in the walkways. Lowest priority of the batches |

**Which factory skill for what (checked 2026-09-21):** props (mop, bucket, sign) and toilet fixes -> `3d-environment-assets`. Character animation clips (batches 1, 2 and the slips) are **out of scope of both skills** (`3d-game-assets` stops at test poses; `3d-environment-assets` says "NOT for animation"), so the factory session must first plan an animation workflow (probe the rig, make ONE clip, export it in the .glb, validate, look at it in Godot), and only after that works write it up as a new skill from what was learned.

**Rig stress test (owner, 2026-09-21):** Level 5 will be breakdancing (hands on the floor, legs in the air, spins), so in the very first test clip also bend Bob (and Jijio) into one extreme pose (deep crouch with hands on the floor, and legs high) and check the skin holds up: no stretched or collapsed shoulders/hips/knees, no clothing poke-through. If the skinning breaks, fix the weights BEFORE making more clips on top of it, and say so in the asset's STATUS.md. The dance moves themselves are not chosen yet; do not make them now.

**Clip contract (proposed names, so Godot can find them without guessing):** lowercase, one clip per action, in the same .glb as the character: `idle`, `walk`, `run`, `kick`, `sit`, `sit_floor`, `stand_up`, `wash`, `wipe`, `press_flush`, `mop`, `slip`, `pants_down`. Loops: `idle walk run sit wash` (loop them). **In place** (no root motion): Godot moves the body and the clip only animates the bones. 30 fps. Bake constraints/drivers to bone keys (`export_animations=True`, see item 5 below). Face shape keys stay as they are (Godot drives them). List every clip with length and loop flag in the asset's `*_godot_notes.md`; a clip missing from the notes does not exist as far as the game is concerned.

## A. Blocks the current build (do these first)

| # | Asset | What is needed | Needed for |
|---|-------|----------------|-----------|
| 1 | Toilet environment | **Collision for every stall.** (Interim: `scripts/stalls.gd` builds box collision from the meshes at level start and adds the door collision, so this no longer blocks play; a proper fix would still be better than blocky boxes.) Only the first instance of each linked duplicate got a `-convcolonly` proxy (door, front panel, partition, pilaster, toilet body, sink at stall 1 only). Stalls 2-10, all of row 2 and the other 9 sinks have none. Export one proxy per instance (or make the duplicates real copies). | Walls between stalls, sinks, toilets; Bob currently walks through them |
| 2 | Bob animations | Idle, walk, run (loopable). | Looks like walking instead of gliding |
| 3 | Jijio animations | Idle (standing in queue), walk, and a **kick**. Can reuse the Bob idle/walk. | Timeout scene (currently a code-driven tilt-and-thrust placeholder) |
| 4 | Toilet environment | **Flush handle or button** (separate object, so Godot can animate/trigger it). | Ending: flush the poop |
| 5 | Bob animations | **Pants (shorts) pull-down baked as an animation**, plus sit-on-toilet and poop. The Blender drivers do not export; bake to bone keys (`export_animations=True`). | Ending sequence |

Added 2026-09-19 (stall flow): these replace stand-ins Godot will use meanwhile.

| # | Asset | What is needed | Stand-in until then |
|---|-------|----------------|---------------------|
| 5a | Jijio animations | **Sit on toilet** (loop), stand up from toilet. | Skeleton posed in code (rough sit) |
| 5b | Jijio animations | **Wash hands at a sink** (loop). | Stands facing the sink |
| 5c | Bob animations | **Wipe** (after pooping) and **press the flush handle**. | Progress bar / plain interact |
| 5d | Toilet environment | Flush handle needs a known position on the toilet (item 4). Bowl water: see item 11 (rendered cutscene). | Cube on the tank; flat shader water |

Sink water (faucet stream) is a Godot effect (particles/shader). The **flush is now a pre-rendered cutscene: see item 11**; the flat shader water in Godot is only a stand-in until that video exists.

### 11. Realistic flush: Blender fluid simulation, rendered from the flush camera (owner wants hyper-realistic water)
**STATUS 2026-09-20: DONE (first version).** Claude built it headless in the factory instead of the owner (see `mi-gaming-factory/environments/toilet-environment/flush/`); `video/flush.ogv` (1280x720, 30 fps, 5.5 s, 0.97 MB) plays in the game. Possible upgrades, only if wanted: foam/spray/bubbles (needs a re-bake, about 1 h), a flush sound, a clearer or bluer water tint. The text below is the original spec.
Decided 2026-09-20: a real fluid simulation (Mantaflow) rendered as a **full-frame 16:9 video** from the exact first-person flush camera. It replaces the whole view for about 5.5 s (fade to black, video, fade back), so it does not need to be masked into the game and is not a sticker. One video serves all 20 toilets (row 2 is the same view mirrored around the stall).

**Owner builds it in the factory; Claude already wired the playback** (`ToiletFx.video_path`, default `res://video/flush.ogv`, Ogg Theora; Claude converts PNG frames or MP4 to .ogv with ffmpeg, which is installed). Until the file exists the game uses the flat shader water.

**Camera (must match the game so the cut is seamless).** Toilet R1_01 as the reference (`SM_Toilet_R1_01_*`), toilet faces +Z in Godot:
- Godot: position (1.50, 1.10, -1.55) m, looking toward -Z (at the toilet), pitched down 57.3 degrees (1.0 rad), **vertical FOV 70 degrees**, 16:9, near 0.02.
- Same thing relative to the toilet: 0.72 m in front of the seat centre (toward the stall door), 1.10 m above the floor, centred on the seat, aiming down into the bowl.
- Blender (scene is in cm; Godot Z = -Blender Y): camera location (150, 155, 110), rotation Euler XYZ (32.7, 0, 0) looks toward +Y (toward the toilet) pitched down 57.3 degrees. Sensor fit VERTICAL, sensor height 24 mm, focal length 17.14 mm gives a 70 degree vertical FOV. Check the toilet's centre is at about (150, 227) cm in the .blend before trusting these numbers.
- Do not move the camera during the shot.

**Scene.** The real stall as the game shows it: the toilet, the stall partitions left and right, the tiles, the back wall, the tank at the top of the frame. **Lid up / seat lid not in the shot** (the game hides it); the seat ring and bowl rim visible. No character, no hands. Lit like the game (sickly green fluorescent ceiling grid, see the toilet SPEC "Light plan"), so the cut to and from the game does not jump.

**Water and the flush.** The simulation needs a simplified bowl-and-trap shape (a closed domain inside the porcelain: bowl, rim, siphon channel, drain), not the game mesh. Resting water level is about 38 cm above the floor (about 9 cm below the seat top, which is at 50 cm). Clear water with a slight blue tint, real refraction, foam and bubbles.
Timeline at 30 fps, 165 frames (5.5 s):
1. 0.0-0.5 s calm water at rest.
2. 0.5-1.3 s water jets around the rim under the lip and washes round the wall; the level rises a little.
3. 1.3-3.3 s the siphon starts: whirlpool forms, level drops fast, foam and swirl spiral into the drain.
4. 3.3-4.3 s gurgle: last of the water, bubbles, a bit of splash on the wall.
5. 4.3-5.5 s bowl refills to the resting level from the tank refill, ripples settle to calm.

**Deliverable.** 1280x720 PNG sequence (or MP4), 30 fps, 165 frames, no alpha needed. Optional separate flush sound (.wav) and a refill/gurgle tail. Put the render in the factory and tell Claude where it is; Claude converts it to `video/flush.ogv` and checks it plays in Godot.
Note: `assets/` is for published .glb only, so the video lives in a new `video/` folder.

## B. Should be fixed but not blocking

| # | Asset | What is needed |
|---|-------|----------------|
| 6 | Toilet environment | Ceiling light panels in the lobby (waiting room). It has none in the glb, so Godot adds a stand-in light. |
| 7 | Toilet environment | Stall door collision must be a **separate body per door** so it can swing with the door (door pivot is already at the hinge, left edge). Part of item 1. |
| 8 | Jijio | Pants pull-down baked as an animation (same gap as Bob's; not needed until an NPC does it). |
| 12 | Toilet environment | **DO THIS FIRST (owner, 2026-09-21): the block at the far east end (`SM_SinkLedge_01`) stands inside the last sink and has no collision.** Full steps in section "12." right below this table. |
| 10 | Bob | Optional: a shorter or tucked shirt (or a lift-the-shirt animation) so the shorts are visible from eye level during the pull-down. Godot currently hides the shirt for that moment. Slimming the body is not needed. |
| 9 | Jijio | Variety if wanted (colors, hair, height, accessories). Identical copies for now. |
| 13 | Bob (pose) | **CONFIRMED needed, ready to work (owner, 2026-09-23): a real "standing on the sitting Jijio's lap" pose for Level 3 hiding.** Full numbers in section "13." right below this table. |
| 14 | Toilet environment | A real wall-mounted tissue holder + roll prop, one per stall. Placeholder now: a plain cylinder mesh Godot builds itself at level start (`toilet_session.gd _add_tissue_mesh`, world position `_tissue_position()` = seat - 0.45 m X, seat.y + 0.03 m Y, seat.z + forward.z * 0.75 m Z; in Bob's own frame per `bob_godot_notes.md`'s `tissue_grab` clip, that is "(-0.45, 0.03, 0.75)"). Functional (the `tissue_grab` clip reaches toward it) but plain and untuned by eye. Not blocking. |

### 12. Toilet: `SM_SinkLedge_01` stands inside sink 10 and has no collision (owner-reported 2026-09-21, DO FIRST)
**Slug:** `toilet-environment`. **Owner's words:** "the table at the most far end is colliding with the last far-end sink" (two screenshots: a tiled block, about as tall as the sinks' counter, cutting through the basin of the last sink).

**Measured in the game (Godot, world metres; Godot Z = -Blender Y, and the .blend is in cm, so x 10.03 m = 1003 cm):**
| Object | x | y (height) | z |
|---|---|---|---|
| `SM_SinkLedge_01` (the block) | 10.03 .. 10.66 | 0 .. 0.88 | 0.52 .. 1.00 |
| `SM_Sink_10` (last basin) | 9.82 .. 10.28 | 0.54 .. 0.94 | 0.60 .. 1.00 |
They intersect by 0.033 m^3 (overlap x 10.03 .. 10.28). It is the ONLY ledge: sinks 1-9 have none. It also has **no collision proxy**: in the game Bob walks into its volume (probed).

**What to do (about 5 minutes):**
1. Move `SM_SinkLedge_01` about **+0.27 m in Godot X (= +27 cm in Blender X)** so it starts at x >= 10.30 m, clear of the basin (its far edge then sits at about x 10.93, still inside the room: the east wall is at 12.65). Or shorten it from the west side, or delete it, or (if the idea is a counter) build a matching one for every sink; the owner has not decided what the block is for, so the smallest fix is the move. Keep its z range so it does not stick further into the corridor (front face at z 0.52; the corridor floor ends at z 0.60 at the sink fronts).
2. Give it a **`-convcolonly` collision proxy** (same suffix the toilet's other proxies use), so Bob and the Jijios cannot walk into it.
3. Run the toilet's validator, then republish: `python tools/publish_to_game.py toilet-environment` (from the factory). Update the asset's `*_godot_notes.md` (one line: "ledge moved to x >= 10.30, has a collision proxy").
4. Tell the game session the slug and what changed.

**What the game session does afterwards (so nobody forgets):** re-import; run `bash tests/run.sh toilet_geometry`. That test lists this overlap as a KNOWN defect and is built to FAIL with "known defect fixed by the factory? remove from KNOWN" once the overlap is gone: then empty `KNOWN` in `tests/test_toilet_geometry.gd`. Also run the slow test (`bash tests/run.sh --slow`, all-stalls sink walk) and `test_walkers`, because a new collision body next to sink 10 changes the navmesh at the sink-10 stand spot (x 10.05, z 0.38; the agent is 0.2 m wide). Do NOT add a Godot-side patch for this: the owner chose the factory fix.

### 13. Bob's "standing on the sitting Jijio's lap" pose overlaps the Jijio's torso (Level 3 hiding, CONFIRMED 2026-09-23, ready to work)

**Seen (2026-09-22 screenshot):** Bob's capsule intersects the sitting Jijio's body; reads as "Bob standing ON the Jijio" rather than beside/on the lap. Currently a code placeholder in Godot (`hide_seek.gd`/`Pose`: an upright tween, no real pose), which is why it's wrong — this is not a Godot bug, it needs an actual Blender pose.

**Measured in the game (`tests/probe_level3.gd`, real numbers, all 20 stalls):**
| Thing | Value |
|---|---|
| Stall interior | about 0.95 m wide, 1.5 m deep |
| Sitting Jijio's thigh (lap) bone height | 0.535 m |
| Sitting Jijio's ankle bones | 0.35-0.36 m |
| Seat (lid top) | 0.505 m, same on all 20 |
| Bob's capsule | radius 0.25 m, height 1.3 m |
| Lap depth available (front of Jijio's knees to the stall wall behind) | about 0.25 m — narrower than Bob's 0.5 m capsule width, hence the overlap |

**What's needed:** a real Bob pose for standing on the lap, sized to actually fit in that 0.25 m of depth (feet together, narrow stance, maybe angled sideways along the lap rather than facing forward) posed against the Jijio's REST sit pose (thigh bone 0.535 m) so the two meshes read as separate bodies, not intersecting. If 0.25 m truly cannot fit any standing pose without overlap, the alternative is changing the Jijio's sit pose to open the lap up more (spread knees, lean back) — the game side has no preference, whichever reads better in Blender.
**Deliverable:** either a static pose (bone transforms only, no animation needed — Bob doesn't move while hiding) baked into `bob.glb`, named per the clip contract (e.g. `hide_lap`) or, if simplest, updated REST-adjacent bone offsets the game can apply the same way `Pose.sit`/`Pose.wash` already work (check with the game session which is easier to wire).
**Not needed yet:** the empty-stall "stand on the seat" pose has NOT been reported as visually broken (no overlap there — the seat top is 0.505 m, clear of anything), so leave that placeholder alone for now.
**Hold, don't build yet:** the jump-scare pose (Jijio's lunge with a lit-from-below face) is a SEPARATE, still-unconfirmed item — the owner has not played Level 3 yet, so whether the current code placeholder even needs replacing is unknown. Do not spend factory time on it until the owner has actually seen it in play and confirms it's wrong (`FACTORY_TODO` will get its own numbered item then, same as this one, only once confirmed).

## C. Props and animations: ONLY once the owner picks the mini-game

Nothing here is needed yet. Make a prop only after its mini-game is chosen (see SPEC.md).

| Mini-game / mission | Props | Animations (Bob unless noted) |
|---|---|---|
| Clean the toilet / spray the toilet | spray bottle, toilet brush | spray, scrub |
| Scrub the mirror | sponge or cloth, spray bottle | scrub (mirror height) |
| Mop the floor | mop, bucket, wet-floor sign | mop |
| Find / give tissue | toilet paper roll (+ holder on stall wall). **Level 1 prototype uses a cube as a "tissue box" until this exists** | pick up, hand over |
| Spray the people | spray bottle | spray |
| Shout / cry / dance | none | shout, cry, dance |
| Find a person's missing item | the missing item(s) (small, several) | pick up |
| Rock paper scissors | none | three hand gestures (Bob + Jijio) |
| B-boy dance battle | maybe a boombox | several dance moves for both |
| Water gun at the odd one out | water gun, water stream effect (Godot particles) | aim, shoot; Jijio shout/react |
| Slip and slide | wet floor decal | slip, slide |
| Rhythm game | none (UI in Godot) | dance/beat poses |

## C2. Added 2026-09-20 from the level plan (props for hiding are the owner's to add; animations listed here)
| Level | Needs |
|---|---|
| 1 | Real tissue roll prop (stand-in cube now); Jijio "knock on a door" animation (optional) |
| 2 wet floor | Mop + bucket + wet floor sign props; Bob mop animation (one stroke per click); Jijio slip animation; overflow needs no asset (Godot puddle) |
| 3 hide and seek | **BUILT with stand-ins 2026-09-22** (one spot each to replace): Bob **hop onto the seat / onto the sitting Jijio's lap** and stand there (now: code tween, upright T-pose; the lap is only 0.25 m deep so Bob overlaps the sitting Jijio); seeker Jijio **sprint** (now: the walk with a faster speed) and **bend over and look under a door** (now: the model tilted 1.35 rad forward, `hide_seek.gd` `_peek`); a horror **jump-scare pose** with a lit-from-below face (now: `jump_scare.gd`, the model tilted toward the lens, an omni light under the chin); Bob **clench** pose (hold F; none now); a real **scare sting sound** (now the hurt cries pitched about, event `scare` in `sfx.gd`); hiding props the owner will add |
| 4 fight (2026-09-24, Street Fighter style, owner said the fight animations are ready) | Bob's existing clips cover punch, punch_combo, kick, uppercut, hook_right (contact frames used in `scripts/fighter.gd`). **Missing for both Bob and the Jijio cutters: `block` (hands up guard, looping), `jump` (short hop, about 0.7 s), `hit_react` (flinch, about 0.35 s), `ko_fall` (knocked down, stays down).** Jijio already has the same attack clips as Bob (checked in `jijio_godot_notes.md`). The attack clips are slow (1.0-1.8 s) and are played at 1.2-1.5x speed in game; if a faster set exists, publish it. **Stand-ins in the game now (2026-09-24, `scripts/fight.gd`):** stance = `punch_combo` frames 6-8 looped (fists up at the chin), block = `punch` frame 8 held + a lean back, jump = the stance lifted 0.5 m, hit = a lean back, dizzy/KO = `idle` + sway / tipped onto the back. A real **`fight_stance`** loop (Street Fighter bounce, about 0.7 s) would also help (nice-to-have) |
| 4 water fight (BOSSY, updated 2026-09-24; the old "odd one out" lunge/variants are no longer needed) | **Water gun prop** (a toy water gun, about 0.3 m long, held in the RIGHT hand, barrel along the hand's forward; bright colour so it reads in the green room; a separate grip point/empty named `muzzle` at the barrel tip would help). **Clips for Bob AND Jijio: `aim_gun` (holding it up at chest height, right arm forward, looping), `walk_aim` (strafe/walk while aiming, nice-to-have).** A **`soaked`** reaction (dripping, falls over) would replace the tip-over. **Stand-ins in the game now (`scripts/water_fight.gd`):** a box-and-sphere gun at (-0.3, 0.85, 0.3) in model space, arms in the `idle` pose, the stream = Godot particles (stays in Godot, not a factory job) |
| 5 dance battle (BUILT with stand-ins 2026-09-24, `scripts/dance.gd`) | **DELIVERED 2026-09-25 (factory republish, verified in Godot with `tests/probe_clip_list.gd`: Bob 27 clips, Jijio 24; suite 60/60 green on the new files): `groove`, `move_left/right/down/up`, `victory`, `defeat`, `flare`, `headspin`, `worm` on both. WIRED 2026-09-25 (`dance.gd` `_add_groove`, `on_power_move`, `_finale`; `test_dance_clips`; seen in 15 windowed battle shots). STILL TO MAKE: crowd `cheer` / `wave` / `clap`, `stumble`, the boombox prop.** Original ask: **Clips for Bob AND Jijio (same skeleton), 100 BPM, in place, GROUNDED (the game adds no root motion):** four one-beat b-boy moves, one per arrow, about **0.6 s** each, starting and ending in a shared stance so they chain: `move_left`, `move_down`, `move_up`, `move_right` (suggested: toprock step left, a drop into footwork, a freeze with an arm up, toprock step right); a looping **`groove`** (two beats, 1.2 s, bounce on each beat); **`stumble`** (a miss, about 0.4 s); **`victory`** and **`defeat`** (about 1.5 s). Optional big moves for later: `windmill`, `headspin`. **Crowd (Jijio):** looping `cheer` (arms up, jumping, one beat 0.6 s), `wave` (arms waving overhead, two beats), `clap` (one beat). **Prop:** a boombox (about 0.5 x 0.3 x 0.16 m, bright, two speaker cones, a handle; origin on the floor). **Stand-ins now:** groove = `walk` frames 0-20 over two beats; left/down/up/right = `hook_right` 0-16-0, `kick_double` 0-8-0 (the coil crouch), `uppercut` 0-12-0 (the rise), `punch` 8-16-8; crowd = groove or fist pump (`punch` 8-16-8) + code hops; stumble = a code tilt; boombox = a cyan box. Probe `tests/probe_dance_clips.gd` found every arms-up frame of the attack clips airborne and mid-spin, so no real "cheer" can be cut from them. |

## C3. Round 2 (owner 2026-09-25): new Level 2 flood, water gun shooter, fights, Level 3 fart cloud
**Stage 3 status (2026-09-27):** the Level 2 stand-ins for R1-R5 are BUILT in the game (swim = slowed `walk` tilted 0.7 rad about the water line, tread = slow `idle`; Jijio panic = `run` at 0.45x leaning back; code plunger (red cup 0.16 m, 0.6 m handle) pumped in code; drain = dark disc + brass ring at (-4.6, 0, -1.2) in the waiting room; taps = the sink mesh + the tap sound/stream; no Jijio diarrhoea/slap clips, the door rattles). Each row can now be replaced one at a time. R2 note: the plunger in the game is carried at Bob's CARRY_POSITION (0, 0.7, 0.4) and pumps 0.15 m down 4 times in 3 s. R3 note: the drain's position is set in `flood_story.gd DRAIN_POS`; a published drain object would replace it.
The game builds every item below with a STAND-IN first (owner: "just add placeholders for now"); each row says what the stand-in is, so the factory can replace one row at a time. Clips for Bob AND Jijio unless noted, same skeleton, in place, 30 fps, names exactly as written.
| # | Asset | What is needed | Stand-in in the game until then |
|---|---|---|---|
| R1 | Swim clips | `swim` (front crawl or breaststroke at the surface, head above water, loop about 1.2 s), `tread_water` (upright, legs cycling, arms sculling, loop about 1.5 s), `float` (on the back, limbs loose, loop about 3 s; the panicking Jijios), `swim_panic` (Jijio, flailing arms, loop about 1 s) | `walk`/`idle` played slowly, the body tilted forward in code, bobbing on the wave height |
| R1b | `surface` clip (Bob + Jijio; owner "yes" 2026-09-27) | A one-shot bridge back up from a dive: starts on `swim_under`'s first frame (0.90 m down, origin = the water surface like the other swim clips), rises and ends on `swim`'s first frame, about 0.6 s | a 0.4 s cross-fade `swim_under` -> `swim` while the body rises in code |
| R2 | Plunger prop + clip | Plunger (rubber cup about 0.14 m across, wooden handle about 0.6 m; origin at the cup rim; red cup so it reads in the green room). Bob `plunge` (both hands on the handle, pumping down, loop about 0.8 s per pump) | Cylinder + half-sphere plunger, `punch` frames held + code up/down pump |
| R3 | Floor drain + plug | A round floor drain grate (about 0.25 m) with a pull plug on a chain, as ONE separate object in the toilet environment (a published position, like the flush handle), or a standalone prop. Bob `pull_plug` (crouch, grab, yank up, about 1.2 s; underwater it is a dive) | A dark disc + a torus handle; code crouch |
| R4 | Tap handles | Every sink tap as its own object (so Godot can turn it and know it is ON/OFF), with a known position per sink. Bob `turn_tap` (a quick wrist twist, about 0.5 s) | Taps are part of the sink mesh; a code arm reach + the tap sound stops |
| R5 | Jijio clips for the story | `diarrhoea` (seated, clutching the belly, bouncing, about 2 s), `rampage_run` (arms flailing wild run, loop), `turn_on_tap` (a quick slap at the tap) | `sit` + code shake; `run` faster; `punch` frame at the tap |
| R6 | Water gun FPS viewmodel | First-person **arms + water gun** (Bob's forearms/hands holding the gun, as seen from the eyes), with `fp_idle`, `fp_fire` (small kick), `fp_refill` (tip the gun into a sink, about 1.2 s), `fp_ult` (the hose). A **tank on the gun** (a separate mesh the game can fill/empty). A bigger **super-soaker hose** prop for the ultimate. Brown-water guns for the 3 crew Jijios (same gun, the game tints it) | Box-and-cylinder gun in front of the camera, no arms; the ult = the same gun, a thicker stream |
| R6b | Stage 4 shooter extras (added 2026-09-27, plan in SPEC "Stage 4 plan APPROVED") | Jijio `aim_shoot` (gun held at the chest, small kick, loop about 0.6 s), `cover_crouch` (crouched behind knee-to-hip cover, loop), `peek_out` (step out from cover, about 0.4 s). Optional prop: a **toilet-paper stack** (about 0.8 x 0.6 x 1.0 m, rolls in a shrink-wrap pallet, with collision) | Jijio `idle`/`walk` + code gun; code-built box stacks of white rolls with a glowing blue band |
| R7 | Fight clips (upgrade of row 4) | Still missing: `block`, `jump`, `hit_react`, `ko_fall`, plus NEW `crouch` (loop) and `crouch_block` for the Street Fighter "hold back to block / S to crouch" controls | Held frames and code tilts (`fight.gd`) |
| R8 | Level 3 fart cloud | None needed: the brown cloud is a Godot volumetric fog/particle effect. Optional: Jijio/Bob `gag` (hand over the nose, waving the air, about 1.5 s) | Code: arm pose + a shake |
| R9 | Swimming ambience / flood look | None needed from the factory (the rising water, foam, caustics and splashes are built in Godot). Optional later: a short fixed-camera Blender fluid clip of water gushing out under the clogged stall door (3d-water-animation skill), used as the "water trickles out" close-up | Godot particles + the flood shader |

Water look references from the owner (2026-09-25): `refs/water/` (murky grey-green, foam, bright highlights, caustics on the floor; NOT blue).

## D. Already available, no work needed
Face shape keys on both characters (happy, disgust, urgency, relief, mouth shapes, blinks, Jijio tongue). Godot drives them.
