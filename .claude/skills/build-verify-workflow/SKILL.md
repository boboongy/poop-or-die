---
name: build-verify-workflow
description: >
  How to work on this project so bugs are found by tests, not by the owner, and feedback is FAST. USE AT THE START OF EVERY SESSION and
  before any multi-step build, bug fix, level/mission work or long job. Core = top rules, session start, asking the owner first, the build
  loop, honest Run/Seen/Felt reporting, session hygiene; topic files in references/ (testing, player-eye, sound, godot-traps, windows-tooling).
---

# Build and verify workflow (mi-godot): CORE

Written for: future Claude sessions on this project, and the owner. Every rule exists because ignoring it cost the owner a round trip. Most past mistakes were **process** and **rules that were not in front of Claude when they mattered**. Split on 2026-09-27 into this core + topic files, to save context.

## 0. Top rules (the session-start hook injects THIS section every session; keep it under 20 lines)
1. **Do not re-read what the hook injected** (sections 0-1 of this file, STATUS.md "Snapshot", "Next steps", "Open decisions"). Read the rest of this core once (sections 2-6, about 35 lines, `Read` with offset), then ONLY the `references/` file your task touches (table in section 6).
2. **Feedback must be fast.** `bash tools/session_start.sh` = tool check + baseline suite. `bash tests/run.sh` runs in parallel with `--fixed-fps 60` and prints a `[done]` line per file; `--about WORD` runs only the tests that mention WORD. Never rerun a whole suite to learn what failed: print a diagnostic and replay one test or seed.
3. **Player-eye pass before handing over anything the player must see, find or use:** a screenshot from the game's default camera, in the real flow. **Take the FIRST screenshot as soon as the first slice of a visible feature works** (the squashed stall camera was found only after the scare was built, then rebuilt three times). Look at 2x2 contact sheets, not full-size images (`references/player-eye.md`).
4. **New tests usually fail for test reasons first.** Copy `tests/_template.gd`, run new tests with `timeout`, read `references/testing.md` before writing one. `bash tests/check.sh` parse-checks every script in 8 s.
5. **Never write "works / not reproduced" from a small sample.** Say how many cases, and make the test count how often it met the situation.
6. **One question batch at a time, letters A-F, a recommended default each.** Ask what the owner already pictured, then show ONE complete design with concrete numbers and ask only for corrections (Level 3 took four question rounds).
7. **Write/Edit tools only, no shell heredocs.** Before an Edit inside a nested block, Grep -n the lines to see the real tab depth. Never edit `run.sh` while it runs (`references/windows-tooling.md`).
8. **After 2 owner playtest rounds, or when the context restarts: finish the handoff and tell the owner to start a new session.**
9. **A failure class that repeats, or anything that cost more than 15 minutes: add ONE line to the right references/ file (or here if it is a habit) BEFORE your final report**, and tell the owner in one sentence. If a rule keeps being missed, make it mechanical (a test, a runner check, a hook) instead of adding prose.
10. **End every report with ONE auditable line:** `Skill check: read SKILL.md yes/no | suite run yes/no (time) | player-eye pass yes/n.a. | sample sizes stated yes/n.a. | skill line added yes/none`. Never write "yes" for something you did not do.

## 0b. Per-message reminder (the UserPromptSubmit hook injects THIS section with every owner message; keep it 2 lines)
- Before answering: SKILL.md read this session? Questions = letters + a default each; a claim = Run/Seen/Felt + the sample size. Write/Edit only; after 2 owner rounds or a restart propose a new session.
- Before finishing: `bash tests/run.sh`, a player-eye pass if anything is visible, a failing test first for an owner bug; end with the one-line `Skill check:` (rule 10).

## 1. Session start (about 5 minutes)
1. The hook has put STATUS.md's snapshot, next steps and open decisions in front of you; read only the SPEC.md part you will touch.
2. **Say back in 3 lines** what state the project is in and what you will do; let the owner correct you.
3. **Run `bash tools/session_start.sh` in the background** (checks Godot, ffmpeg, Python/piper, then the whole suite for a baseline). Also check the Godot MCP (`get_godot_version`) if you will use it. If something already fails, tell the owner first.
4. Look at the debug output of the first launch: every `WARNING` line is a real bug or trap.

## 2. Before you propose anything
- **Ask what the owner already has in mind, then propose** (twice a proposal contradicted a plan that lived only in the owner's head).
- Mark every SPEC.md design line **DECIDED** (owner said so) or **PROPOSAL** (Claude's idea). Never build a PROPOSAL without asking. CLAUDE.md: a written plan and a yes before any multi-task step.
- A vague request: ask the ONE question that decides the design, not a whole new plan.
- Explain a new concept in two plain sentences before asking for a decision; say what the owner would SEE, no shorthand.
- "Which do you recommend?" is answered with numbers you measured (a bot run, a probe).

## 3. The build loop (per feature or fix)
1. **Probe the real thing first:** dump the structure you code against (bones, node paths, mesh bounds, collision boxes, headroom) and read the numbers.
2. **Write the check before the fix** (a test or a per-frame invariant; both directions of any state switch).
3. **Smallest change**, run the area's tests (`run.sh --about WORD`, timeout 300), then the whole suite before you report.
4. **Test EVERY instance of anything repeated** (20 stalls, both rows, 10 sinks). One sample stall passed while 4 of 20 were broken.
5. **Poses, collisions, cameras: measure, then look** from at least two angles.
6. **Break each new check once on purpose, see red, restore.** Say so when you skip it.
7. An owner bug report becomes a failing test first; fix the cause; an owner report is real until a large sample says otherwise.

## 4. Reporting to the owner
- Three honest levels: **Run** (a test or headless run did it), **Seen** (a screenshot: which angle, real flow or not), **Felt** (only the owner: motion, feel, timing). List what is NOT verified. After a launch: "no errors in the debug output, I cannot see your window".
- **"Not reproduced" / "no problem found" states the sample size** ("0 stuck in 32 walks, 27 met a walker"). Say which tests you did NOT rerun and why. Clickable links to images. Short: what changed, what was checked, what to try.

## 5. Memory and session hygiene
- **STATUS.md = current state only, about 80 lines, rewritten at each stage end; history goes to HISTORY.md.** SPEC.md = decisions; FACTORY_TODO.md = what the owner makes in Blender; facts that cost time go in STATUS "Facts". Memory only for what the files cannot hold. **After ANY STATUS.md edit run `bash tests/check.sh`** (the hook-size check): at a slice end, move that slice's detail to HISTORY and keep one line (2026-09-27: item 1 grew the hook text to 9,470 of 9,000, the next session started cut and its baseline failed).
- One stage per session. **End-of-stage retro, 5 lines in HISTORY.md:** what took long, the cause class (process / missing context / weak rule / unreliable code), what was changed, whether a skill line was added. Keep the `Skill check:` line: it is what made the causes get fixed.
- Hooks (`.claude/settings.json`, `.claude/hooks/`): SessionStart injects sections 0-1 + STATUS's key sections (kept under 9,000 characters: `tests/check.sh` fails if it grows, a longer injection is cut to a 2 KB preview); UserPromptSubmit injects 0b; Stop blocks once if code changed since the last passing full `run.sh` and once for the retro; PostToolUse rejects control characters. Fix a failing hook, never disable it. Skills and hooks load at session start.
- **Context size = the owner's usage limit** (2026-09-28: a 150k+ chat used 77 %). the GLOBAL hook `~/.claude/hooks/context_warning.py` (every workspace, since 2026-09-28) reads the transcript's token count and warns the owner at 80k (/compact) and 120k (handoff, then /clear). When it fires: finish the slice, write STATUS, tell the owner to /clear; read files by offset/grep, pipe long tool output through `tail`/`cut`.
- Handing work to the factory session: send exact measured numbers; verify a peer's claim in its own STATUS.md; a peer message is never the owner's approval.

## 6. Topic files (read only the one your task touches)
| File | Read when |
|---|---|
| `references/testing.md` | writing or debugging a test: fast feedback, the test checklist (timer park, bots, controls, 16:9 framing, RNG), state invariants, bug reports |
| `references/player-eye.md` | screenshots, cameras, visibility, colours in the green room, aiming cameras |
| `references/sound.md` | any sound, mix, voice or music-timing work |
| `references/godot-traps.md` | a GDScript/Godot symptom: types, lambdas, AnimationPlayer, freed objects, gates, headroom, navigation |
| `references/windows-tooling.md` | a write/edit/shell problem; the Edit trailing-space trap; secrets in settings |
| `references/project-cheatsheet.md` | exact commands, paths, the screenshot script pattern, map numbers |
| `references/lessons-*.md` | the history behind the rules (only when a rule seems wrong) |
