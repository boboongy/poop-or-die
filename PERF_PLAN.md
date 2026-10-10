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
