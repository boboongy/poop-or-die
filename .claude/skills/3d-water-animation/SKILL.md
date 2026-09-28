---
name: 3d-water-animation
description: >
  Realistic WATER for games, made offline in Blender (fluid simulation) and played in Godot as a video: toilet flush, sink and tap, overflow, clogging, splash, pour, drip, puddle.
  Trigger whenever the user asks for realistic / real / hyper-realistic water, a liquid, a flush, an overflow, a splash or any water animation for a game.
  Contains: a decision table (offline sim vs Godot shader vs flipbook), a cheapest-first gate ladder, tested headless Blender 5.2 fluid scripts, engine colour matching,
  crop compositing, and the ffmpeg -> Ogg Theora -> Godot playback path. Built from the toilet-flush run (2026-09-20).
  Part A applies to ANY long headless Blender job (renders, bakes, big exports), not only water.
  NOT for rigid-body / destruction, NOT for character animation, NOT for ocean or river scale water.
---

# Water animation: Blender fluid sim -> video -> Godot

**Proven on one effect only:** the toilet flush (fixed camera, 5.5 s, 1280x720, 30 fps, 165 frames). Everything marked UNTESTED is reasoning, not evidence.
Read `references/lessons-toilet-flush.md` once (what went wrong and what it cost) and `references/blender-fluid-api-5x.md` before writing fluid code. Scripts are in `templates/` (edit the numbers at the top; they are hard-wired to the toilet project).

## A. Rules for any long headless Blender job
1. **Verify a tool before promising it.** The Blender MCP only works while a GUI Blender is open with the addon server started; `blender -b` cannot host it. In Phase 0 test it (`get_scene_info`) or test `blender.exe -b --python-expr "print(1)"`, then tell the user which route you will use. (In the flush run the user was told "Blender is connected" without a check; it was not.)
2. **Estimate, measure small, extrapolate, tell the user.** Before any job over 10 minutes: run it at about 1/3 size, time it, scale up (fluid time grows roughly with resolution^3.4 here), and say "about N minutes, unattended".
3. **Cheapest-first ladder. A bigger step never starts until the smaller one passes its test:** (1) camera still matches the engine, (2) tiny sim (res 48-64, under 2 min) has the right behaviour, (3) one look-dev frame with final lighting, (4) colour check against an engine screenshot, (5) final bake, (6) final render.
4. **Tune the physics at low resolution.** Resolution adds detail, it does not change the design. Two re-bakes at res 96 (15 min) were physics tuning that res 48 would have shown in 1 min.
5. **Sanity-print before baking:** domain box vs the object it must contain, object counts, emitter positions. Never trust `scale`: a size-1 cube with scale 0.2 is 0.2 m wide, not 0.4 (this cost two bakes).
6. **Render only what moves.** Render the moving region as a crop for every frame, the rest once as a background, composite in ffmpeg. 22 s per frame instead of 80+.
7. **Long jobs run in the background** (`nohup`, log file, outputs that can resume by skipping existing files). Poll every 5 minutes at most, never restart from zero, keep caches out of git and delete them after the final.
8. **Match the ENGINE, not Blender.** Godot (ACES tonemap, fog, GI) does not look like Blender's Standard view. Compare region means of a calm frame against a Godot screenshot from the same camera. Check dark regions on their own (averages over bright regions hide dark errors). The user must never be the first to see "grey".
9. **Write script files with the Write tool,** never shell heredocs or Python strings that contain quotes or Windows paths (two failures: unterminated quote, `\U` escape in a path). Use forward slashes.
10. **Look at every image you render before the next step.** Make contact sheets with ffmpeg `tile` (no PIL here). If you cannot view an image, say so and measure instead.
11. **Never edit the source .blend.** A script builds a derived scene from it every time (idempotent). The result lives next to it (`flush/toilet-flush.blend`).

## B. Decide the technique first (Phase 0, before any code)
| Situation | Use | Why |
|---|---|---|
| Realistic water, camera locked or a cutscene (flush) | Blender fluid sim -> video | Only route to real refraction, foam and depth on the owner's PC |
| Realistic, small, but the camera moves (sink splash, drip) | Looping video / flipbook on a plane, plus Godot particles (UNTESTED) | An offline sim cannot be seen from every angle |
| Stylised, many instances, mid distance | Godot shader + particles | Cheap, live |
| Puddle that spreads on the floor | Godot decal / floor mesh with a water shader that grows in scale and alpha (UNTESTED) | No simulation needed |

Ask: is the camera locked, how many places use it, how close does it get, how long is it? Then say the cost. **"Hyper-realistic" plus "real time" is not possible on this PC** (integrated AMD GPU, the game runs 15-35 FPS). A Godot shader was tried first for the flush; it looked like a floating sticker and cost about 1.5 hours and two rebuilds.

## C. Pipeline for a locked-camera water clip
0. **Deliverable spec** (write it first): the Godot camera (position, pitch, FOV), resolution, fps, frame count, timeline in seconds. Convert to Blender: Godot Z = -Blender Y; sensor fit VERTICAL, sensor height 24 mm, lens = 12 / tan(FOV/2); rotation X = 90 - pitch; metres. Put the camera in Godot **and** Blender and compare two stills before anything else (`f01`).
1. **Derive the scene** (`build_scene`): prune to what is in frame, convert cm to metres by baking scale into the meshes, remove things the game hides (the lid), add lights.
2. **Measure the container, do not assume it.** Ray-cast the cavity from above (`probe_cavity`). The real toilet mesh had no water trap (a shallow dish with a hole into a hollow base) and a non-manifold surface, so it cannot be a collision object. Build a **watertight proxy by revolving the measured profile**, plus the missing sump and a plug that opens for the drain.
3. **Fluid setup:** a LIQUID domain that contains everything with a margin; the collision proxy; the starting water as a GEOMETRY flow; jets/refill as INFLOW emitters whose `use_inflow` is keyframed (constant interpolation); an OUTFLOW **covering the whole floor slab** (a small one let water pool on the floor); the plug as a collision effector whose `use_effector` is keyframed off for the drain.
4. **Bake ladder:** res 48-64 first, watch for the right behaviour (`inspect_cache`: vertex counts and bounds per frame; bounds equal to the domain shell on every frame means the sim did nothing). Then the final res. Data bake, then mesh bake (`bake`).
5. **Look-dev on one frame:** Principled BSDF, transmission 1, IOR 1.333, roughness 0. Colour absorption made the water murky dark green: **drop it and let the scene lighting colour the water.** A soft fill or spot light above the bowl gives the highlights. Use a bright close-up crop with exposure boosted to judge (`f14`), never to deliver.
6. **Colour match** (`color_compare`, `light_match`): match a spot light by search, then finish with a per-channel gamma in ffmpeg `lutrgb` (game vs render here: R 0.92, G 0.72, B 1.05). Add a horizontal brightness falloff if the engine scene has one.
7. **Render crops + one background** (`render_crops`, `background`); crop box = the moving region only.
8. **Compose and encode** (`compose`): overlay the crops, multiply the falloff, grade, encode Ogg Theora (`libtheora -q:v 8`). ffmpeg here has no glob input, so name frames `crop_%04d.png`.
9. **Godot:** copy to `res://video/name.ogv`. `VideoStreamPlayer` (Godot plays only Ogg Theora). Cross-fade with `modulate:a` on the player, no black layer. Set `viewport.disable_3d = true` once the video is opaque. Always add a timeout, so a clip that fails to play cannot freeze the game. A lambda cannot reassign a captured local (use an array).
10. **Acceptance:** a windowed Godot run that plays the clip and returns to the game; then the owner looks.

## D. Numbers measured (AMD integrated-GPU PC, CPU Cycles, Blender 5.2.1)
| Item | Measured |
|---|---|
| Domain 0.40 x 0.40 x 0.58 m, 165 frames, res 64 | data 64 s, mesh 21 s |
| res 96 (24 jets) | data 486 s, mesh 124 s |
| res 160 | data 2731 s, mesh 411 s, cache 2.4 GB |
| Cycles crop 360x332, 64 samples, adaptive | about 22 s per frame (165 frames = 55 min) |
| Background 1280x720, 160 samples | about 4 min |
| Final video | 5.5 s, 0.9 MB |

## E. UNTESTED effects (reasoned starting points)
- **Sink overflow / clogging:** same recipe with the basin as a watertight proxy, the tap as INFLOW, the drain as a plug that closes; overflow over the rim needs the rim geometry to be exact. Only useful as a clip if the camera is locked; otherwise look-dev a short loop and play it on a plane.
- **Puddles:** see B; do not simulate.
- **Anything with a moving camera:** decide with the owner between a locked camera moment and a cheaper live effect BEFORE simulating.

## F. Before you deliver
- [ ] Ladder steps 1-4 done, and the user was told each cost first.
- [ ] Two stills (game vs Blender) show the same camera.
- [ ] Colour check numbers printed, dark regions individually.
- [ ] Every rendered image was looked at; the sheet is linked for the user.
- [ ] Godot run played the clip and returned to gameplay; timeout present.
- [ ] STATUS.md and FACTORY_TODO.md updated; large cache deleted or git-ignored.
