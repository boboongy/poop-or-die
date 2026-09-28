#!/bin/bash
# Parse-only check of EVERY script (scripts/, scripts/missions/, tests/) in parallel, a few seconds in all.
# Why: a parse error such as `:=` on a Variant value used to show up late (a test failed to load, or a test hung on a script error).
# Godot's `--check-only` reports it at once and exits 1. tests/run.sh calls this first (NOCHECK=1 skips it).
#   bash tests/check.sh        prints PARSE-FAIL lines and the error text; exit code 1 if any file fails
GODOT="/c/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.." || exit 1
TMP="$(mktemp -d)"
export GODOT TMP
ls scripts/*.gd scripts/missions/*.gd tests/*.gd 2>/dev/null | xargs -P "${JOBS:-8}" -I{} sh -c '
  OUT=$("$GODOT" --headless --path . --check-only --script "res://{}" 2>&1)
  CODE=$?
  if [ $CODE -ne 0 ]; then
    { echo "PARSE-FAIL  {}"; echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error|Compile Error" | head -4; } > "$TMP/$(echo {} | tr / _).fail"
  fi
'
# The session-start hook's text must stay under its limit (a longer one is cut to a 2 KB preview; 2026-09-27).
if ! python .claude/hooks/session_start.py --check > "$TMP/hook.txt"; then
  { echo "PARSE-FAIL  .claude/hooks/session_start.py"; cat "$TMP/hook.txt"; echo "  shorten STATUS.md Snapshot/Next steps/Open decisions or SKILL.md sections 0-1"; } > "$TMP/hook.fail"
fi
# STATUS.md = current state only (owner 2026-09-28: a long file wastes tokens every session). Over 80 lines = move history to HISTORY.md.
STATUS_LINES=$(wc -l < STATUS.md)
if [ "$STATUS_LINES" -gt 80 ]; then
  echo "PARSE-FAIL  STATUS.md is $STATUS_LINES lines (limit 80): move finished slices/stages to HISTORY.md, keep one line each" > "$TMP/status.fail"
fi
FAILS=$(ls "$TMP"/*.fail 2>/dev/null | wc -l)
cat "$TMP"/*.fail 2>/dev/null
rm -rf "$TMP"
if [ "$FAILS" -gt 0 ]; then
  echo "PARSE CHECK FAILED: $FAILS file(s)"
  exit 1
fi
echo "PARSE CHECK OK"
