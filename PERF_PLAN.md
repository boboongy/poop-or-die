# Fullscreen FPS plan (desktop, integrated GPU)

Owner, 2026-10-10: **the game runs about 20 FPS in a small window and about 10 FPS at full screen** (1920x1080),
on a Ryzen 5 7430U with integrated Radeon graphics. The owner needs a recordable frame rate at full screen for
the YouTube gameplay video (`VIDEO_SCRIPT.md`). Owner's call: fix it in the game, not in OBS.

## Diagnosis (read 2026-10-10, NOT yet measured)

`scripts/liminal_lighting.gd` turns on a near-AAA screen-space stack, and the desktop path has no cut-down tier
(the web build does: `COMPAT_*`, one shadow light, `COMPAT_SCALE 0.75`). Everything marked PER-PIXEL below costs
about twice as much at 1080p as at 720p, which is exactly the halving the owner sees:

| Setting | Where | Cost |
|---|---|---|
| **MSAA 4x** | `_ready()` line 58, unconditional | PER-PIXEL, 4 samples; prime suspect |
| Anisotropic 16x | `_ready()` line 59 | bandwidth |
| **SDFGI** | `apply_quality`, HIGH only | PER-PIXEL, expensive |
| **SSR** | `apply_quality`, medium+ | PER-PIXEL |
| **SSAO** (radius 1.2, intensity 2.5) | `apply_quality`, medium+ | PER-PIXEL |
| **Volumetric fog** (length 40 m) | `apply_quality`, medium+ | PER-PIXEL froxel grid |
| Glow/bloom | `_build_environment` | PER-PIXEL |
| One shadow-casting spot per ceiling panel | `_build_lights` | one shadow pass per light |

Comment at line 58 says MSAA + anisotropic are there because "tile grids shimmer badly at a distance without
these". Anisotropic 16x is what fixes TEXTURE shimmer (cheap, keep it); MSAA fixes GEOMETRY edges and is the
expensive half. FXAA or MSAA 2x is the likely trade.

Not the cause (checked 2026-10-10): no game code or `project.godot` change since the Sep 28 commit; the tree is
clean. Also present but a separate issue: OBS was recording with Display Capture + software x264 at the time of
the first reports, on a laptop at 20 % battery on the Balanced power plan (see HISTORY / this session).

## Step 1 FIRST: a measuring tool (nothing is decided without numbers)

The project has no desktop FPS probe (`tools/web_fps.py` is Chrome only; the `shot_*` tests print a single frame's
FPS, which is meaningless). Write `tests/probe_fullscreen_fps.gd` (from `tests/_template.gd`):

- boots Level 1 in a REAL window (not headless; the whole point is the GPU), resolution from an argument
- lets the intro finish, puts Bob in the corridor, then samples `Engine.get_frames_per_second()` for about 10 s
- prints `avg`, `min`, `p5` and the frame count, so a run is comparable to the next run
- NEVER run with `--fixed-fps` (that pins the frame rate and hides the thing being measured)

Baseline to record: 1280x720 and 1920x1080, OBS CLOSED, laptop on AC above 50 %. That pair is the number to beat.

## Step 2: the ladder, cheapest and least visible first, RE-MEASURE at 1080p after each

1. **MSAA 4x -> 2x, then off with `screen_space_aa = FXAA`.** Keep anisotropic 16x. Expected the largest single
   win. Check the tile shimmer in a player-eye shot down the corridor before accepting.
2. **SSR off.** Wet-tile reflections; look cost is real but small in motion.
3. **`rendering/scaling_3d/mode = bilinear`, `scale = 0.8`** (0.75 already proven acceptable on web). The HUD stays
   sharp: `window/stretch/mode` is already `canvas_items`.
4. **SDFGI off at 1080p**, compensating with ambient energy the way `COMPAT_AMBIENT` already does for web
   (ambient 1.2 left characters "so shadowed" per the owner 2026-09-28; COMPAT uses 6.0).
5. **Volumetric fog length 40 -> 20 m**, density unchanged. The liminal green haze is the look; cut length, not density.
6. **Shadow-casting spots: nearest N only** (the web path already does nearest-1 in `_update_shadow_light()`;
   desktop could use nearest 3-4 and reuse that code).

Stop as soon as 1080p clears the target. SHADOWS OFF ENTIRELY is a last resort: the green ceiling-grid look is
the game's signature and is what the video shows.

## Target

Owner to confirm: **>= 30 FPS at 1920x1080** with OBS recording via hardware encode is the recordable bar; 25 is
usable at 30 fps capture. If the ladder cannot reach it, fall back to recording a 1280x720 window 1:1 (720p is
normal for YouTube gameplay) and keep the ladder's cheap wins anyway.

## Design question for the owner (ask before building)

A desktop quality tier means the game can look different from the screenshots so far. Which?
- **A (recommended):** an automatic tier - measure FPS for 3 s at startup and drop MSAA/SSR/SDFGI if it is low.
  The owner never thinks about it; the risk is it changing mid-recording.
- **B:** a fixed "recording" preset on a key or a command-line flag (`--perf`), nothing automatic.
- **C:** change the defaults for everyone and accept the slightly plainer look.

## Verify before reporting (rules that apply here)

- A player-eye pass at 1920x1080 BEFORE and AFTER, same camera, as a 2x2 contact sheet: corridor, ceiling grid,
  wet floor, a Jijio face. A perf win that ruins the look is not a win.
- `bash tests/run.sh` in full: `liminal_lighting.gd` is touched by the web/compat tests and the shot tests.
- Report Run / Seen / Felt with the sample size (how many seconds sampled, how many runs), never "feels smoother".

## MEASURED 2026-10-10 (`tests/probe_fullscreen_fps.gd`, Level 1, default camera, vsync off, OBS closed, AC 49 %, Balanced plan)

Run: a real Forward+ window, 8-10 s per sample, 2-3 samples per setting, the median reported. Machine: Ryzen 5 7430U +
AMD Radeon integrated, desktop 1920x1200.

**Baseline (3 x 10 s): 1280x720 = 23.6 FPS, 1920x1080 = 17.4 FPS.** 2.25x the pixels costs only 26 %, so the owner's
"10 FPS" included the OBS software-x264 overhead; the game alone is 17.

**The diagnosis above was WRONG about which setting is to blame.** One setting at a time at 1080p changed nothing:
MSAA 2x 18.5 | MSAA off + FXAA 17.7 | SSR off 18.1 | SSAO off 16.4 | fog off 17.1 | all 10 shadows off 17.6 |
nearest-1 shadow 17.4 | SDFGI off 22.1. Everything off at once, though, gave 110 FPS at scale 0.5 and 68 at scale 1.0.
**This is memory-bandwidth saturation on an APU: with the stack on, removing one effect only lets the others fill the
gap, so a single-factor ladder measures ~0 for everything. Cut the WHOLE per-pixel stack, or nothing.**

Shadows look free in the first table and cost 19 FPS in the second: **a per-pixel probe must be re-run once the stack is
off, in the regime the game will actually ship in.** Draw calls say nothing here (shadows off: 7000 -> 591 draw calls,
+0.2 FPS).

With MSAA + SSR + SSAO + SDFGI off and ambient 1.2 compensating the lost bounce, at full 1920x1080:

| Also kept | 1080p median | Look kept |
|---|---|---|
| fog 20 m + glow + **all 10 shadows** | **40.6 FPS** | haze, glow, every ceiling-grid shadow |
| glow + all 10 shadows (no fog) | 45.3 FPS | no green haze |
| all 10 shadows only | 49.2 FPS | no haze, no glow |
| nearest-1 shadow only | 63.3 FPS | one lit panel |
| no shadows | 68.1 FPS | flat |

**BUILT 2026-10-10 (option A, `scripts/liminal_lighting.gd`, test `tests/test_perf_tier.gd`):** the game samples its own
frame rate once per launch (90 warm-up frames, then the median of 3 s) and drops to MEDIUM below 35 FPS. The verdict is a
static var, so it survives a retry or the next level and can NEVER switch mid-recording. `--perf=high|med|low` overrides it.
In a real 1080p window: `PERF TIER: 16 FPS -> MEDIUM`, then **37.6 FPS measured over 2 x 10 s** (`--perf=high` 16.3 on the
same camera). **The ambient is 0.5, not the web build's 1.2:** a 2x2 contact sheet showed 1.2 and 0.8 washing the room flat
(the web tier has no lamps to add to; this one keeps all 10). Owner still to judge the look.

**DECIDED: the tier is row 1 (40.6 FPS, 2.4x the baseline).** It clears the 30 FPS bar with room for OBS, keeps the
green haze, the glow and every shadow, and needs no render-scale drop - only SDFGI's bounce is traded for ambient 1.2.
Row 2 is the fallback if OBS eats more than 10 FPS.


## Web speed 2 - MEASURED 2026-10-11 (the desktop tier above does NOT apply to web: `is_compat()` is excluded)

Owner's report: the github.io page is still slow and the shadows still look heavy, while the editor now feels good.
Both halves are true for different reasons - the page is a **2026-09-28 build** (`origin/gh-pages` = 4d07ac7, 13 days
behind `main`, missing the water fix 37239b6), AND the browser-specific speed work was never written.

**Baseline: a fresh export of `main`, real Chrome, viewport 1920x1080, min of 3 x 5 s rAF samples per level,
ANGLE -> D3D11 on AMD Radeon** (`SIZE=1920x1080 python tools/web_fps.py <dir> 3`):

| Level | FPS | draw calls | process (CPU main loop) | render CPU | GPU |
|---|---|---|---|---|---|
| L1 | 12.6 | 619 | 71.7 ms | 25.5 ms | unreadable in WebGL |
| L2 | 14.4 | 486 | 84.2 ms | 23.0 ms | - |
| L3 | 10.6 | 654 | 89.5 ms | 44.3 ms | - |
| L4 | 9.2 | 659 | 84.4 ms | 39.2 ms | - |
| L5 | 11.8 | 622 | 75.4 ms | 32.5 ms | - |

Every level fails the >= 20 FPS bar; L4 is worst. `gpu 0.0` means WebGL cannot report GPU time, so a GPU stall and a
CPU bottleneck look alike in `process`. Two one-factor probes settled it (`probe_compat_fps.gd`, native
`gl_compatibility`, L3, `shadows=near scale=0.75`, 4 s each, 1 run per setting):

1. **Resolution is irrelevant: 1280x720 -> 46.5 FPS, 1920x1080 -> 46.8 FPS.** The frame is NOT fill-rate bound, so
   **the render-scale rung is dropped from the plan** (`COMPAT_SCALE` stays 0.75), and window size does NOT explain
   the old "L3 32-40 then 11-16 the same night" (a concurrent test suite halves the numbers - likeliest cause).
2. **Native 1080p 46.8 FPS vs Chrome 10.6 FPS = 4.4x browser overhead at ~653 draw calls/frame.** Same renderer, same
   level. Each GL call crosses WASM -> JS -> ANGLE -> D3D11, so **draw-call count is the lever**, not pixels.

Measured levers at 1920x1080 (native, so the FPS gain understates the browser gain; the draw-call delta is what
transfers):

| Setting | draw calls | FPS | read |
|---|---|---|---|
| baseline `shadows=near scale=0.75` | 663 | 46.8 | - |
| `chars=0` (all characters hidden) | 502 (-24 %) | 56.3 | the characters are the biggest known block |
| `range=7` | 665 | 45.3 | no effect - the option does not do what its name suggests |
| `shadows=none` | 668 | 44.0 | **NOT MEASURED - see the trap below** |

**TRAP: the probe's `shadows=none` is silently undone.** `liminal_lighting.gd:207-210` re-runs
`_update_shadow_light()` every 0.25 s and switches the nearest spot back on, so the probe still printed `shadowed 1`
and the shadow rung has no number yet. Fix the probe (or stop the timer) before trusting any shadow measurement.

**Corrected ladder, cheapest first, one factor per measurement, stop at the first rung that clears 20 FPS in Chrome
at 1920x1080 on all 5 levels:**
1. Hide Jijios beyond ~18 m (the `chars=0` result says characters are worth about 160 draw calls).
2. Merge the scenery meshes (static geometry is the rest of the ~500 baseline calls).
3. A real shadows-off test + feet blob, once the probe trap is fixed.
4. Re-confirm in Chrome, then one export and one deploy to `gh-pages` (which also finally ships the water fix).

### What that ladder was worth - MEASURED 2026-10-11, same session (it was worth nothing)

**Rung 1 is dead on arrival: there is no Jijio beyond 18 m.** The probe now prints a distance line every run
(`PROBE dist`), and on L3/L4 all 31-34 of them sit inside 18 m of the default camera (`<6m 3-9, 6-12m 12-20,
12-18m 10-11, >18m 0`), so `far=18` hid 0 characters and saved 0 draw calls. `far=12` hides 10 Jijios for -29 calls
and -0.8 FPS native: not worth the pop-in. **The room is 18 m deep - distance culling is not a lever in this game.**

**The shadow rung is big and free, so it was taken** (`lights=noshadow`, which stops the 0.25 s updater first):

| Level | draw calls with nearest-1 shadow | with no shadow | native FPS |
|---|---|---|---|
| L1 | 643 | 348 (-46 %) | 57.0 -> 60.3 |
| L3 | 657 | 356 (-46 %) | 46.8 -> 52.8 |
| L4 | 653 | 362 (-45 %) | 47.8 -> 54.8 |

A 2x2 contact sheet (L1 and L3, default camera, with and without) shows **no visible difference**: against
`COMPAT_AMBIENT 6.0` the one spot cone casts nothing the player can see. So `liminal_lighting.gd` now switches every
shadow off in compat and `_update_shadow_light()` is gone (`test_web_build.gd` asserts no spot casts a shadow under
each of the 10 spot positions). No feet blob: there was no shadow under anyone to replace.

**And then the draw-call theory failed its own test. Chrome, fresh export, 1920x1080, 3 x 5 s:**

| Level | FPS before (653 calls) | FPS after (~350 calls) | render CPU before -> after |
|---|---|---|---|
| L1 | 12.6 | 13.2 | 25.5 -> 26.5 ms |
| L2 | 14.4 | 13.2 | 23.0 -> 20.6 ms |
| L3 | 10.6 | 8.6 | 44.3 -> 43.4 ms |
| L4 | 9.2 | 8.4 | 39.2 -> 46.0 ms |
| L5 | 11.8 | 9.8 | 32.5 -> 35.1 ms |

**Half the draw calls bought nothing** - not even in render CPU. So the browser's 4.4x is not per-call overhead
either. Keep the shadows-off change anyway: it is free speed on the native compat path and costs no look.

### Where the web frame actually goes - MEASURED IN CHROME 2026-10-11 (one factor each, 2 x 5 s per level)

All at 1920x1080 on the shadows-off build, via the switches `web_probe.gd` already had
(`index.html?anim=0|chars=0|phys=0`), plus a plain run at 1280x720 and one at 1080p with `COMPAT_SCALE 0.5`:

| Level | baseline 1080p | `anim=0` | `chars=0` | `phys=0` | 720p | 1080p @ scale 0.5 |
|---|---|---|---|---|---|---|
| L1 | 13.2 | 11.2 | **18.8** | 13.0 | 16.4 | 13.0 |
| L2 | 13.2 | 12.4 | **17.2** | 13.4 | **19.8** | 16.2 |
| L3 | 8.6 | 9.8 | **12.8** | 12.2 | 14.6 | 11.6 |
| L4 | 8.4 | 8.4 | **12.4** | 11.6 | 12.4 | 10.2 |
| L5 | 9.8 | 11.0 | **18.0** | 12.8 | 17.0 | 13.0 |

Read, in order of size:
1. **Drawing the characters is the biggest single cost (+4 to +8 FPS when hidden), but posing them is free**
   (`anim=0` changed nothing, and the animation throttle already caps that). So it is the ~32 x 9,774 skinned
   vertices per frame, not the AnimationPlayers and not the 160 draw calls they cost.
2. **Physics is second** (+3 FPS on L3-L5, where `web_probe` shows 6-12 ms per frame).
3. **Pixels DO matter in the browser, though they were free natively** (native L3: 720p 46.5 vs 1080p 46.8; Chrome
   L3: 14.6 vs 8.6). A native probe does not predict the browser - never rank a web rung without a Chrome run.
4. 720p beats 1080p-at-scale-0.5 everywhere (16.4/19.8/14.6/12.4/17.0 vs 13.0/16.2/11.6/10.2/13.0) although both
   draw the same 960x540 of 3D: the HUD, the canvas blit and the page compositing are charged at the window size.

**The 20 FPS bar is not reachable at 1920x1080 by tuning: even with every character hidden, L3/L4 sit at 12.4-12.8.**
Three honest options for the owner (none is Claude's to pick):
- **(a) A smaller canvas on the page** (fix the game to 1280x720 and let CSS stretch it): measured 12.4-19.8 FPS,
  no gameplay or asset change, the whole cost is sharpness.
- **(b) Cheaper characters** (a low-poly web Jijio from the factory, or a smaller crowd on web): worth +4 to +8 FPS.
- **(c) Accept the web build as a slow demo** and keep the desktop build as the real one.
