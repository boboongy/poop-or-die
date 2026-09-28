#!/bin/bash
# Session start in one command (build-verify-workflow section 1 step 3): check the tools, then run the whole suite for a baseline.
#   bash tools/session_start.sh           tools + full suite (about 10 min; run it in the background)
#   bash tools/session_start.sh --tools   tools only (a few seconds)
#   bash tools/session_start.sh --full    always the full suite (by default it is skipped when no code changed since the last full pass)
# Prints one line per tool (OK / MISSING) and the suite's summary; exit 1 if a tool is missing or a test fails.
cd "$(dirname "$0")/.." || exit 1
GODOT="/c/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
BAD=0
check() { # name, command...
  local name="$1"; shift
  local out
  if out=$("$@" 2>&1 | head -1) && [ -n "$out" ]; then echo "OK       $name: $out"; else echo "MISSING  $name"; BAD=1; fi
}
check "godot" "$GODOT" --headless --version
check "ffmpeg" ffmpeg -hide_banner -version
check "python" python --version
check "piper-tts" python -c "import piper; print('piper importable')"
if [ -d "$LOCALAPPDATA/piper-voices" ]; then echo "OK       piper voices: $(ls "$LOCALAPPDATA/piper-voices" | grep -c '\.onnx$') models"; else echo "MISSING  piper voices ($LOCALAPPDATA/piper-voices)"; BAD=1; fi
python .claude/hooks/session_start.py --check || BAD=1
echo "git: $(git status --porcelain | wc -l) changed/untracked paths, branch $(git branch --show-current)"
[ "$1" = "--tools" ] && exit $BAD
echo
# Owner A1 2026-09-27: no code changed since the last full PASS (.claude/last_full_run.json, the Stop hook's test) = no 12-minute baseline.
if [ "$1" != "--full" ] && python .claude/hooks/stop_guard.py --fresh; then
  echo "BASELINE SKIPPED: no code changed since the last full passing run ($(date -d @"$(python -c "import json;print(json.load(open('.claude/last_full_run.json'))['time'])")" '+%Y-%m-%d %H:%M')); parse check only (--full forces the suite)"
  bash tests/check.sh || BAD=1
  exit $BAD
fi
bash tests/run.sh || BAD=1
exit $BAD
