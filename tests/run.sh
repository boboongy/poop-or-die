#!/bin/bash
# Headless regression tests. From the project root:
#   bash tests/run.sh              all fast tests, in PARALLEL and FASTER THAN REAL TIME (a couple of minutes)
#   bash tests/run.sh --slow       also the slow tests (all-stalls sink walk)
#   bash tests/run.sh level1       only tests whose name contains "level1"
#   bash tests/run.sh --about flood  only tests whose FILE mentions "flood" (case-insensitive): run this after changing an area
# Each file prints a "[done n/N] PASS|FAIL name (s)" line as it finishes, so a hang or a failure shows at once.
#   JOBS=1 bash tests/run.sh       one test at a time (JOBS=n runs n at once; default 8)
#   REALTIME=1 bash tests/run.sh   real time instead of --fixed-fps (only to check a suspicion that a test depends on wall-clock time)
# Why it is fast: `--fixed-fps 60` advances the game exactly 1/60 s per frame WITHOUT waiting for the wall clock, so a 40 s scene takes
# a few seconds, and game time no longer depends on how busy the CPU is (so parallel runs do not make tests flaky). Measured 2026-09-21:
# one test 34 s -> 4 s; eight slow tests (about 35 min one after another in real time) 23 s in parallel; identical pass counts.
# Prints one PASS/FAIL line per check and a summary. Exit code 1 if anything failed.
GODOT="/c/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.." || exit 1
SLOW=0
FILTER=""
ABOUT=""
NEXT_ABOUT=0
for arg in "$@"; do
  if [ "$NEXT_ABOUT" = "1" ]; then ABOUT="$arg"; NEXT_ABOUT=0
  elif [ "$arg" = "--about" ]; then NEXT_ABOUT=1
  elif [ "$arg" = "--slow" ]; then SLOW=1
  else FILTER="$arg"; fi
done
PARTIAL="$FILTER$ABOUT" # a name filter or --about: no parse check, no full-run marker for the Stop hook
JOBS="${JOBS:-8}"
FPS="--fixed-fps 60"
[ -n "$REALTIME" ] && FPS=""
# "name:walkers" runs the same test with the walking Jijios switched on (they are off by default in tests, see t.gd).
# "name:floodwalkers" runs it on the flood level (Level 3 since Stage 6b) with the walkers on; ":flooddry" the same with the flood not started; ":row1"/":row2" stalls.
FAST_TESTS="test_voices test_start_dialogue test_ambience test_walker_doors test_walker_doors:flooddry test_flood_water test_flood_tasks:row1 test_flood_tasks:row2 test_flood_swim test_bubble_time test_dance_clips test_dance_camera test_level5_setup test_level5_crowd test_dance_battle test_level5_chain test_level5_chain:walkers test_level1_chain test_fighter test_fight test_fight_hud test_shooter_gun test_shooter_feedback test_shooter_ai test_shooter_arena test_shooter_ult test_cutters test_cutters:walkers test_level4_chain test_level4_chain:walkers test_level4_fail test_level4_stalls:row1 test_level4_stalls:row2 test_toilet_sequence test_timeout_kick test_kickout_time test_queue_makeway test_head_visibility test_wipe_camera:row1 test_wipe_camera:row2 test_tissue_props:row1 test_tissue_props:row2 test_action_sounds test_doors test_audio test_walkers test_level1_chain:walkers test_toilet_sequence:walkers test_timeout_kick:walkers test_slip test_walker_slip test_mop test_flood_chain test_flood_chain:walkers test_level_flow test_toilet_sequence:floodwalkers test_timeout_kick:floodwalkers test_tissue_spots test_toilet_geometry test_walkers_stress test_talk_leave test_talk_view test_mop_assist test_sfx_release test_reward_blocked test_hide_hop test_seekers test_seekers:walkers test_hide_noise test_jump_scare test_hide_chain test_hide_chain:walkers test_locomotion_anim test_jijio_locomotion_anim test_jijio_walls test_jijio_solid test_talk_frozen test_queue_talk test_queue_fidget test_mission_shouts test_web_build:walkers"
SLOW_TESTS="test_all_stalls_sink"
TESTS="$FAST_TESTS"
[ "$SLOW" = "1" ] && TESTS="$FAST_TESTS $SLOW_TESTS"
# Every listed name must be a real test file: an Edit that dropped a trailing space glued two names into one ("test_asetuptest_b") and
# silently skipped both tests, twice (2026-09-24, 2026-09-25).
for t in $TESTS; do
  if [ ! -f "tests/${t%%:*}.gd" ]; then echo "run.sh: no file for test '$t' (two names glued together?)"; exit 1; fi
done
# A parse error anywhere (`:=` on a Variant, ...) stops the whole run in seconds instead of a test failing to load. Skipped for a name
# filter (quick iterations) and with NOCHECK=1.
if [ -z "$PARTIAL" ] && [ -z "$NOCHECK" ]; then
  bash tests/check.sh || exit 1
fi
# New assets (sounds) must be imported before a headless script can load them.
timeout 300 "$GODOT" --headless --path . --import > /dev/null 2>&1
TMP="$(mktemp -d)"
SELECTED=""
for t in $TESTS; do
  case "$t" in *"$FILTER"*) ;; *) continue ;; esac
  if [ -n "$ABOUT" ] && ! grep -qi -- "$ABOUT" "tests/${t%%:*}.gd"; then continue; fi
  SELECTED="$SELECTED $t"
done
TOTAL=$(echo $SELECTED | wc -w)
[ "$TOTAL" -eq 0 ] && { echo "run.sh: no test matches (filter '$FILTER', --about '$ABOUT')"; exit 1; }
START=$(date +%s)
echo "run.sh: $TOTAL test files, $JOBS at a time"
N=0
for t in $SELECTED; do
  N=$((N + 1))
  NAME="${t%%:*}"
  ARGS=""
  case "$t" in *:walkers) ARGS="-- walkers" ;; esac
  case "$t" in *:floodwalkers) ARGS="-- flood walkers" ;; esac
  case "$t" in *:flooddry) ARGS="-- flood walkers dry" ;; esac
  case "$t" in *:row1) ARGS="-- row1" ;; esac
  case "$t" in *:row2) ARGS="-- row2" ;; esac
  while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do sleep 0.3; done
  (
    # 480 s: the slowest file takes about 3 min; a hanging test (a script error never quits) used to burn 900 s (2026-09-27)
    OUT=$(timeout 480 "$GODOT" --headless --path . $FPS --script "tests/$NAME.gd" $ARGS 2>&1)
    CODE=$?
    # A runtime script error in the GAME's code fails the file even when every check passed (2026-09-27: test_level_flow printed a
    # SCRIPT ERROR from npc_jijio.stand_up under "ALL TESTS PASSED").
    if [ $CODE -eq 0 ] && echo "$OUT" | grep -q "SCRIPT ERROR"; then CODE=3; fi
    # Every line a test makes someone say must have a voice file (dialogue.gd prints VOICE MISSING; fix: python tools/make_voices.py).
    if [ $CODE -eq 0 ] && echo "$OUT" | grep -q "VOICE MISSING"; then CODE=4; fi
    {
      echo "=== $t"
      echo "$OUT" | grep -E "^(PASS|FAIL|RESULT|INFO)|SCRIPT ERROR|Parse Error|VOICE MISSING"
      [ $CODE -ne 0 ] && echo "  -> $t exited with code $CODE"
    } > "$TMP/$(printf %03d $N).txt"
    echo $CODE > "$TMP/$(printf %03d $N).code"
    VERDICT="PASS"
    [ $CODE -ne 0 ] && VERDICT="FAIL"
    echo "[done $(ls "$TMP"/*.code | wc -l)/$TOTAL] $VERDICT $t ($(echo "$OUT" | grep -c '^PASS') checks, $(( $(date +%s) - START )) s)"
  ) &
done
wait
FAILED=0
# Only the failed files' check lines (the [done] lines already said which passed); VERBOSE=1 prints every file's lines.
for f in "$TMP"/*.txt; do
  [ -e "$f" ] || continue
  if [ -n "$VERBOSE" ] || [ "$(cat "${f%.txt}.code")" != "0" ]; then echo; cat "$f"; fi
done
for f in "$TMP"/*.code; do [ -e "$f" ] && [ "$(cat "$f")" != "0" ] && FAILED=$((FAILED + 1)); done
CHECKS=$(cat "$TMP"/*.txt 2>/dev/null | grep -c '^PASS')
rm -rf "$TMP"
# An unfiltered run leaves a marker for the Stop hook (.claude/hooks/stop_guard.py): "tests are fresh and green".
if [ -z "$PARTIAL" ]; then
  RESULT="PASS"
  [ $FAILED -ne 0 ] && RESULT="FAIL"
  echo "{\"time\": $(date +%s), \"result\": \"$RESULT\", \"files\": $N}" > .claude/last_full_run.json
fi
echo
ELAPSED="$(( $(date +%s) - START )) s"
if [ $FAILED -eq 0 ]; then echo "ALL TESTS PASSED ($N test files, $CHECKS checks, $ELAPSED)"; else echo "$FAILED TEST FILE(S) FAILED (of $N; $CHECKS checks passed, $ELAPSED)"; exit 1; fi
