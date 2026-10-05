# YouTube script: "2.85 billion tokens to make a game about pooping"

Target **3:00** · VO **~485 words** (155-160 wpm) · Tone: deadpan, matter-of-fact, let the numbers be the joke
Rule for the edit: **every number appears on screen as text the moment it's spoken.** The numbers are the content.
All figures measured from the local session transcripts on 2026-10-05.

---

## 0:00-0:12 — HOOK (no intro, no "hey guys")

**VISUAL:** Black. White text, one line, as the first word lands: **2,850,000,000 TOKENS**. Hard cut on "poop" to gameplay — Bob sprinting down the stall corridor, timer ticking. No music yet.

**VO:**
> This game took two point eight five billion tokens to make.
>
> It's about needing to poop.
>
> Ten days, forty-eight sessions, and I wrote zero lines of code — because I can't code. I'm also on the twenty-dollar plan, which is the part I have to explain first, because that number sounds fake.

**ON SCREEN:** `10 days · 48 sessions · 0 lines written by me · $20/month`

---

## 0:12-0:50 — THE NUMBER, EXPLAINED (first payoff, keep it fast)

**VISUAL:** Simple animation — a chat bubble gets re-sent, and the whole conversation above it lights up each time. Counter spinning up to 2.85B. Then a two-bar chart: **$3,959 API rate** vs **$6.58 (10 days of Pro)**.

**VO:**
> It's not two point eight five billion different words. Every single time the AI replies, the whole conversation gets sent to it again. My average turn carried two hundred and thirty-two thousand tokens of context — the same design document, the same code, the same argument about toilet timers, re-read twelve thousand times.
>
> Ninety-eight percent of that number is re-reading, and re-reading is billed at about a tenth. At normal pay-per-token rates this folder is roughly four thousand dollars of traffic. Ten days of my plan costs six dollars and fifty-eight cents.

**ON SCREEN:** `232,000 tokens of context per turn · 12,197 turns · 98% re-reads`

---

## 0:50-1:28 — SO WHAT DID I ACTUALLY DO

**VISUAL:** Scroll the real message list fast — overlay **444 MESSAGES**. Then the mop level: you frantically mopping, timeout, kicked out. Then the bot run with a stopwatch: **52 s**. Then the timer reading **120**.

**VO:**
> So what did I do for ten days? I decided things.
>
> The mopping level: I gave players seventy seconds. Felt generous. It was impossible — I couldn't beat my own level. So we built a bot that plays it perfectly, and the bot needed fifty-two seconds. A human needs a hundred and twenty.
>
> No AI could have told me that, because it cannot feel a game. Four hundred and forty-four messages from me, and most of them were some version of "no, that feels wrong."

**ON SCREEN:** `70s → impossible · bot: 52s · now: 120s`

---

## 1:28-2:15 — THE STUFF I DIDN'T EXPECT

**VISUAL:** `bash tests/run.sh` running, `[done]` lines flying — overlay **126 TEST FILES / 14,062 LINES**. Then a file browser scrolling 1,225 audio files. Then the Blender fluid sim rendering, cut to the same flush playing in-game.

**VO:**
> Now the part nobody warned me about. This game has a hundred and twenty-six automated test files. Fourteen thousand lines of test code — that is more test code than actual game code. For a game about pooping your pants. They run with no window, in the background, and they are the only reason five levels still work when I change one thing.
>
> It has one thousand two hundred and twenty-five audio files.
>
> And the toilet flush isn't real-time water at all. It's a fluid simulation we ran in Blender, rendered out to a video file, and the game just plays the clip. Nobody has ever noticed.

**ON SCREEN:** `test code 14,062 lines > game code 13,119 lines`

---

## 2:15-2:38 — THE RATIO (the quiet gut-punch)

**VISUAL:** Huge **17,000,000 WORDS** on screen, then it collapses down to a small **27,181 LINES**.

**VO:**
> Here's the number that actually got me. Seventeen million words were written over this project. What survived is twenty-seven thousand lines of code. That's about eight hundred and fifty tokens produced for every line that lived. It isn't magic — it's brute force with a very fast delete key.

---

## 2:38-2:58 — AND IT'S STILL BROKEN

**VISUAL:** Hold on the A-pose bug — the entire toilet queue standing with arms out like scarecrows. Then the FPS counter: **31** next to your desktop, cut to **4** in real Chrome.

**VO:**
> And it isn't finished. Everybody in my game still stands around with their arms out like scarecrows, and neither of us knows why yet. It told me the browser build ran at thirty-one frames a second. Real Chrome: four. It will happily tell you something works when it has never once looked at the screen.
>
> Looking at the screen is still your job.

---

## 2:58-3:08 — CLOSE

**VISUAL:** Fast montage: tissue hand-off, the flood, the ghost, the water war, the dance battle. End card with the play link.

**VO:**
> Five levels, a ghost, and a dance battle. It's free in your browser, link in the description.
>
> Ten days. Two point eight five billion tokens. Six dollars and fifty-eight cents.

---

## Production notes

**Pacing:** the hook must land in 12 seconds — no channel intro, no "before we start". The 0:12-0:50 explanation is what earns the rest of the video; if a viewer stays past 0:50 they'll finish.

**Say it exactly this way** (defensible if challenged in comments):
- ✅ "about four thousand dollars of traffic at pay-per-token rates"
- ❌ "I saved four thousand dollars" — the token counts are measured, but how your plan counted them isn't in the files.

**If you run long, cut in this order:**
1. "No AI could have told me that, because it cannot feel a game." (keep the bot numbers)
2. The 1,225 audio files line.
3. "It isn't magic — it's brute force with a very fast delete key."

**If you need +20 s,** add after the test section:
> It also wrote a test for every bug I reported, before fixing it. That's why I could keep changing the game on day ten without breaking day two.

**Footage you already have:**
- `video/flush.ogv` — the Blender flush clip for 2:00.
- 44 `tests/shot_*.gd` scripts take real in-game screenshots — rerun for the A-pose shot and the level montage.
- `tools/web_fps.py` prints live FPS in real Chrome — screen-record for 2:38.
- `bash tests/run.sh` scrolling `[done]` lines — the 1:28 shot.

**Measured figures used (source: 60 session transcripts, 2026-09-10 → 2026-10-05):**
| Figure | Value |
|---|---|
| Tokens, game folder (Sep 19-28) | 2,848.40M |
| Tokens, incl. Blender asset work | 4,765.78M |
| Cache reads (the re-reading) | 2,798.18M of 2,850.85M = 98.2% |
| Avg / median context per turn | 232.5k / 196.2k |
| Assistant turns · tool calls | 12,156 · 6,663 |
| Your messages (game folder) | 444 |
| Sessions | 48 |
| Output tokens all-in | 23.26M ≈ 17.4M words |
| Surviving code | 13,119 game + 14,062 test = 27,181 lines |
| API list cost, game folder | $3,959 (Opus $3,428 + Sonnet $532) |
| API list cost, all workspaces | $4,993 |
| 10 days of Pro at $20/mo | $6.58 |

**Titles:**
- "I used 2.85 BILLION tokens to make a game about pooping"
- "My first 3D game cost 2.85 billion tokens and $6.58"
- "I can't code. I made a 3D game in 10 days. Here's the real receipt."

**Description seed:**
> Poop or Die — my first 3D game, built in 10 days with Claude Code while being completely unable to write code. 2.85 billion tokens, 444 messages from me, 126 automated tests, and one toilet flush that's secretly a video file. Play it free: https://boboongy.github.io/poop-or-die/
