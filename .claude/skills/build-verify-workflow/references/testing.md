# Testing: fast feedback, the test-writing checklist, state changes, bug reports

Read this when you write or debug a test. (Moved out of SKILL.md on 2026-09-27; wording kept.)

## Fast feedback
- **Run tests with `--fixed-fps 60` and in parallel.** `--fixed-fps` advances exactly 1/60 s per frame without waiting for the wall clock, so game time no longer depends on CPU load (parallel runs are not flaky). Measured 2026-09-21: one test 34 s to 4 s; the 31-file suite about 75 min to 55 s; identical pass counts. `tests/run.sh` does it (`JOBS=n`, `REALTIME=1` to compare).
- **Use the speed to buy certainty:** more seeds, more instances, slow tests in the normal suite. A stress test with 8 seeds gave a false all-clear that 24 seeds contradicted.
- **When a test fails, do not rerun blind.** Print the state at the failure (who is near Bob, their states, the positions), or replay one case (`-- seeds=1 first=3`).
- **Pick the tests you run:** `bash tests/run.sh NAME` (test names containing NAME), `bash tests/run.sh --about WORD` (every test whose FILE mentions WORD, e.g. `--about flood`). Each file prints a `[done]` line as it finishes.
- **After replacing a level's design, run `bash tests/run.sh --about <that level's word>` BEFORE the first full `run.sh`** (2026-09-27, about 25 min: the old Level 2 tests hung on the new level and each burned run.sh's per-test timeout).
- Long-running commands go to the background with a log; poll with an `until` loop in a background command.

## Checklist for writing a test (what actually made tests fail first)
- Start from `tests/_template.gd`; run new tests with `timeout N`: a RUNTIME script error never calls quit and HANGS (count a hang as the honest "red" before the code exists). `bash tests/check.sh` catches parse errors in seconds.
- **A `wait_for` lambda on a node the game frees (a fight, the shooter) starts with `not is_instance_valid(x) or ...`,** else a sabotage or a bug that frees it early spins SCRIPT ERRORs until the timeout; and an outer `timeout` round `run.sh` must exceed its 480 s per-test limit, or it kills run.sh with no `[done]` line (2026-09-27, slice 6 sabotage).
- **Long tests must park the level timer** (`lvl._time_left = 100000.0`), or the timeout kick fires mid-test.
- **A bot must stand where a person could:** not inside a walker, a door line (a stall door within 0.4 m wins the E prompt) or a pilaster. Teleporting into an occupied spot shoves the bot.
- **Sample after the frame that updates the thing:** one `await process_frame` is NOT enough (the signal fires BEFORE the nodes' `_process`): wait 0.1 s.
- **With aim assist, snapping or auto-follow, assert behaviour, not exact positions.**
- **A statistical claim needs N and an encounter counter** (how many walks actually met a walker). A test that never meets the situation proves nothing.
- **A positioning/blocking test needs a CONTROL and a position printout per variant** (2026-09-21: `test_reward_blocked` passed all row-2 stalls because Bob stood where that row's Jijio never walks). Print the slowest time so a hidden delay shows. A bot steering to a fixed point pins itself on corners and door leaves: cross open areas through the middle.
- **A "sooner than / more often than" check needs a CONTROL run without the effect, and its bound must beat the control** (2026-09-22: "within 9 s" passed although the control took 8.4 s).
- **The FIRST level a test loads is added during the SceneTree's `_init`: its `_ready`/`@onready` members (`lvl.player`) are null until the first wait.**
- **Put the real state an object will be in into the test** (2026-09-24: `test_cutters` passed with the stall door shut; in the level it is open and its leaf jammed the cutters).
- **An NPC standing by a door steals the door's E prompt** (a walker 0.28 m BEHIND Bob won "E talk" in 20 of 20 stalls). Roaming chatty things get a negative `priority`; test with the NPC there AND a control.
- **Test an E prompt at the EDGE of reach (1.25 m of 1.3), not only close up** (the neighbouring stall door stole it).
- **A camera/framing test must use the real 16:9 frame and real bones:** headless windows are SQUARE (1152 x 1152), so project for 16:9 yourself (`test_dance_camera.gd` `_on_screen`); follow the head BONE (about 0.82 m, a guessed 1.45 m passed while the shot was bad); count HUD panels as off-screen.
- **A new system that draws random numbers (even `Sfx` via global `randi()`) changes every seeded test's sequence;** seed new RNGs from the global one (`_rng.seed = randi()`), never `randomize()`. Walker tests are still not fully repeatable: judge them over 3-4 runs.
- Explicit types for Variant values (`var x: float = fl.thing`); `:=` on untyped access is a parse error.
- Variants: `-- walkers`, `flood` (the flood level; `T.FLOOD_LEVEL` / `T.HIDE_LEVEL` name the swapped levels, never a bare 2 or 3), `dry`, `row1`/`row2`, `multi`, `seeds=N first=K` (see `run.sh`). `T.level()` uses ONE puddle unless `multi`.
- In a script test, `SceneTree.current_scene = lvl` is needed for `reload_current_scene()` (R, N, F4).
- Wait in physics frames (`T.wait`); with `--fixed-fps` that is also game time.
- A test you have never seen fail proves nothing: break the fix once, see red, restore.
- **Never check a number against the constant the code uses** (`limit := p.TALK_LOOK_LIMIT`): the sabotage moves with it and the test stays green. Write the DECIDED number in the test and check the constant equals it (2026-09-28, `test_talk_frozen`).
- **A per-frame "inside the level" invariant (bones vs walls):** skip poses that are inside by design (a seated Jijio's body is in the toilet's box: 48,000 false hits), print the collider's parent name + the offset from the body + the state the frame before, and fail on STREAKS (N frames in a row), not single frames: `physics_frame` fires before the fixing node's step and tweened doors push nobody (2026-09-28, `test_jijio_walls`, about 30 min).
- **Do not edit code, make voices or run `--import` while the baseline suite runs:** the files it starts later test the new code, so a later red cannot be blamed or cleared by "it passed in the baseline" (2026-09-28, slice 4: `test_flood_swim` red after, green in a mixed baseline, cause unknown at handoff).
- **A new voiced line (`bubble`/`say`/`shout_voice`) = run `python tools/make_voices.py` + `--import` BEFORE any test loads a level:** every level test prints VOICE MISSING and run.sh fails it (2026-09-28: 6 Level 4 files went red mid-baseline from one new shout).

## State changes and bug reports
- Anything that switches a state (first/third person, hidden/visible, open/closed, busy/free) needs an **invariant sampled on every frame** across the whole sequence, both directions (fixing "head returns at once" created "head vanishes at once"). `tests/test_head_visibility.gd` is the model.
- Owner bug report: **reproduce it as a failing test first**, fix the cause, check the mirrored case, run the whole suite, name the cause in one sentence.
- **An owner report is real until a large enough sample says otherwise** ("Jijios block my way" was dismissed after 8 clean seeds; a later run reproduced it).
