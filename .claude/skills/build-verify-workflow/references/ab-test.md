# Does the workflow help? The clean A/B test (owner runs it) + what tokens cost

## Where the tokens actually go (measured 2026-10-06, `--costs`, 45 sessions)

1,057M tokens over 4,642 calls = **228k per call**, because the whole
conversation is re-sent every time. Shares (+-10 %): my tool-call inputs 34 %,
tool results 33 %, harness injections 18 %, the fixed part (system prompt, tool
schemas, CLAUDE.md, loaded skills) 13 % = about **30k on every single call**, my
replies 5 %, thinking 2 %, the owner typing 2 %. **No single read is the
problem - session LENGTH is**, so the handoff rule is the cheapest rule here.
Writing files through the shell (`python <<'PYEOF'`, `cat >`) cost 49M (5 %) on
its own before the Write/Edit rule; `STATUS.md` bookkeeping is the project's
single biggest "feature" at 57.7M tokens and 145 active minutes over 21
sessions, so keep STATUS edits short and few.



Why this file: the era table (`python tools/workflow_stats.py`) compares 53 real
sessions, but the three eras differ in more than the skill - later sessions had
a finished game, more tests and a faster suite. That comparison can show
*enforcement changed something*; it cannot prove the skill itself helps. Only
the same task, run twice in fresh sessions, can. **Claude must not run this
alone and report a winner**: it judges its own work, and only the owner can
feel a game.

## The task (same both times)

Pick a bug or a small feature that is **not yet started**, of a kind this
project has many of, and that does not need the owner's taste to judge. Good
shapes: one visible bug with a clear right answer (a Jijio in a wall, a prompt
that steals another's key), or one small mechanic with numbers already DECIDED
in SPEC.md. Bad shapes: anything whose answer is "how does it feel", anything
needing a Blender asset, anything already half-built.

Write the prompt down once and paste **exactly the same text** in both runs.
Say what to build, not how to work:

> "<one sentence of what is wrong or wanted>. Fix it and tell me when it works."

## Run A: with the workflow (the normal setup)

1. Fresh session (`/clear`), hooks and skill in place as usual.
2. Paste the prompt. Answer questions as the owner normally would.
3. Stop when Claude says it is done, or at 90 minutes, whichever comes first.

## Run B: without it

1. `git stash` nothing - the code must be identical: start from the same commit
   (`git log -1` written down, `git status` clean).
2. Turn the workflow off for that session only:
   - rename `.claude/settings.json` to `.claude/settings.json.off` (kills all
     four hooks: the injection, the reminder, the stop guards, the char check),
   - rename `.claude/skills/build-verify-workflow` to `...-off` (the skill can
     no longer be read or auto-loaded),
   - do not mention STATUS.md, tests or screenshots in the prompt.
3. Fresh session, same prompt, same 90-minute cap.
4. Put both names back afterwards, and `git checkout .` whichever run you do
   not keep.

Order matters a little: do A and B on different days, and if you ever run it a
second time, swap which goes first.

## Record these, both runs (nothing else)

| | A: with | B: without |
|---|---|---|
| minutes until "it works" (owner's clock) | | |
| owner messages typed | | |
| rounds: times the owner had to say "no, still wrong" | | |
| tokens and active minutes (`python tools/workflow_stats.py --sessions`, last row) | | |
| did it write a failing test first (yes/no) | | |
| `bash tests/run.sh` afterwards: green? how many files? | | |
| anything broken that the suite did NOT catch | | |

The honest read: **rounds** and **"anything broken the suite did not catch"**
are the numbers that matter. Minutes and tokens are secondary - a session that
is fast and wrong is worse than a slow one that holds.

## What would make the skill look bad

Say it out loud before running, so the result cannot be explained away:
- B finishes in fewer rounds with a green suite -> the skill's cost is not
  buying anything; cut it to the rules that fire mechanically (hooks).
- A spends more than half its time on process (reading, planning, retro) and
  still needs a second round -> the process is too heavy for a bug of this size.
- Both runs take the same rounds -> the skill is not what prevents rounds; the
  measured cause (7 of 17 retros: a look-or-feel judgement) needs the fix
  instead, not more rules.

One run of each is a sample of one: it can only suggest. Two pairs on different
tasks is the smallest result worth writing into SKILL.md.
