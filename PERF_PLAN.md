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
