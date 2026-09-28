# Audio sources and licences

Every sound file in `audio/` is listed here, one row per file (a test fails if a file is missing from this list, or listed but not used). Only CC0 (public domain) files are used, so no credit is required, but the source is recorded so a file can be replaced or checked later.
The folder is `audio/`, not `assets/`, because `assets/` holds only published .glb files (CLAUDE.md).
The event names and volumes that use these files are in `scripts/sfx.gd`.

**Nobody has listened to these files in the game yet.** They were chosen by pack and file name and, for the tap and flush, by looking at a spectrogram. The owner judges the sound.

## Edited files (2026-09-25)

The engine fades every sound in over its first few milliseconds, and some short files have their whole peak in the first 10 ms, so they played about 15 dB too quiet (footsteps peaked at -18 dB in the recorded mix; `tests/probe_footsteps_sound.gd`). These files got **30 ms of silence added at the start** with ffmpeg (`adelay=30`, nothing else changed; CC0 allows it): `footsteps/footstep_concrete_000-004.ogg`, `hits/impactSoft_heavy_000-002.ogg`, `hits/impactSoft_medium_000-001.ogg`, `hits/impactWood_light_000-002.ogg`, `ui/close_001.wav`, `ui/confirmation_001.wav`, `ui/confirmation_003.wav`, `ui/error_001.wav`, `ui/select_001.wav`, `ui/select_002.wav`. A new short sound: check its first 10 ms (see the probe) before using it.

## Made in code (no file)

- **Level 5 dance battle beat:** a boom-bap drum loop (kick, snare, hi-hat), 100 BPM, 2 bars, SYNTHESISED at runtime by `scripts/dance_beat.gd` (no licence question; exact tempo for the arrows). A PLACEHOLDER until a real CC0 loop with a known tempo is chosen; if one is added, list it below and keep the BPM in `dance_beat.gd` equal to the file's.

## Voices (`audio/voices/`, made 2026-09-27)

Every dialogue line is spoken: `tools/make_voices.py` renders it offline with **Piper TTS** (https://github.com/OHF-Voice/piper1-gpl; the program is only a tool here, nothing of it ships) and ffmpeg (pitch, a ghost echo, loudness -16 LUFS, shouts -13, 30 ms of silence in front). One file per (character, line), named by the text's md5; `audio/voices/manifest.json` lists them; `tests/test_voices.gd` checks them. **Only voices whose training data is public domain or CC0 are used (no credit needed; SPEC Round 2), checked on each voice's MODEL_CARD at https://huggingface.co/rhasspy/piper-voices on 2026-09-27:**

| Cast | Piper voice | Dataset licence (MODEL_CARD) |
|---|---|---|
| bob | en_US-kristin-medium, pitched x1.22 (was joe until the owner's "more animated and cute", 2026-09-27) | public domain (LibriVox) |
| jijio_a (generic Jijio) | en_US-bryce-medium | public domain |
| jijio_b (generic Jijio) | en_US-kristin-medium | public domain (LibriVox) |
| jijio_c (generic Jijio), pushy | en_US-norman-medium | public domain (LibriVox) |
| ghost | en_US-john-medium | public domain (LibriVox) |
| queen (SHUFFLE QUEEN) | en_GB-cori-medium | public domain (LibriVox) |
| sneaky | en_US-kathleen-low | CC0 |
| bossy | en_US-ljspeech-medium | public domain (LJ Speech) |

Rejected (need credit or are non-commercial): amy, danny, kusal, alan, jenny_dioco (licence "see URL"), lessac (Blizzard licence), libritts_r, alba, vctk, aru (CC BY 4.0), northern_english_male, southern_english_female (CC BY-SA 4.0), hfc_female, hfc_male, ryan, semaine (CC BY-NC-SA 4.0), arctic (own licence with a notice), sam (Apache 2.0, notice).

## Packs

| Pack | Author | Licence | Page |
|---|---|---|---|
| Kenney Impact Sounds 1.0 | Kenney | CC0 | https://kenney.nl/assets/impact-sounds (licence text: `licenses/kenney-impact-sounds-License.txt`) |
| Kenney Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/interface-sounds (files taken from the Godot repack https://github.com/Calinou/kenney-interface-sounds, which converts the original Ogg to WAV without change) |
| 100 CC0 SFX | rubberduck | CC0 | https://opengameart.org/content/100-cc0-sfx |
| 40 CC0 water / splash / slime SFX | rubberduck | CC0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx |
| 80 CC0 creature SFX | rubberduck | CC0 | https://opengameart.org/content/80-cc0-creature-sfx |
| (made here) | Claude, with ffmpeg | none needed (synthesised) | see "Placeholder" below |

## Files

| File | Pack | Used for |
|---|---|---|
| footsteps/footstep_concrete_000.ogg ... 004.ogg | Kenney Impact Sounds (30 ms pad, see "Edited files") | footsteps, walking and running (Stage 6b: back from `retired/`; running plays them pitched up x1.25 and louder): footsteps/footstep_concrete_000.ogg, footsteps/footstep_concrete_001.ogg, footsteps/footstep_concrete_002.ogg, footsteps/footstep_concrete_003.ogg, footsteps/footstep_concrete_004.ogg |
| doors/door_open.ogg | 100 CC0 SFX | stall door opens |
| doors/door_close_01.ogg | 100 CC0 SFX | stall door closes |
| doors/door_close_02.ogg | 100 CC0 SFX | stall door closes |
| water/loop_water_02.ogg | 40 CC0 water | tap running at a sink (loop; the steadiest of the three loops by spectrogram) |
| water/toilet_01.ogg | 100 CC0 SFX | flush (7 s, sustained water for about 5.3 s then tapering; the flush video is 5.5 s) |
| water/plop_01.ogg | 100 CC0 SFX | poop plop |
| water/plop_02.ogg | 100 CC0 SFX | poop plop |
| body/hurt_01.ogg | 80 CC0 creature SFX | Level 3's jump scare (placeholder; until Stage 6 also Bob kicked) |
| body/hurt_02.ogg | 80 CC0 creature SFX | Level 3's jump scare |
| body/hurt_03.ogg | 80 CC0 creature SFX | Level 3's jump scare |
| body/poop_blast_01.ogg, body/poop_blast_02.ogg | made here (Stage 6) | Bob's poop: three farts + wet splatter + bubbles + two plops (rebuilt brighter and louder, Stage 6b) |
| body/tummy_01.ogg, body/tummy_02.ogg, body/tummy_03.ogg, body/tummy_04.ogg | made here (Stage 6) | tummy rumbles from the stalls (background) |
| body/fart_01.ogg | made here (see "Made here") | fart: short pfft (Level 3's clench release, the stalls' background farts) |
| body/fart_02.ogg | made here | fart: long rip |
| body/fart_03.ogg | made here | fart: squeaky, rising |
| body/fart_04.ogg | made here | fart: wet sputter |
| body/fart_05.ogg | made here | fart: stutter |
| body/squelch_01.ogg | made here (Stage 6d, 2026-09-28) | Bob loses and fills his shorts: fart_02 slowed to 0.8x and low-passed 1.8 kHz + plop_02 (100 CC0 SFX) 0.12 s later, loudnorm -16 LUFS, peak -2.7 dB (ffmpeg) |
| body/fart_06.ogg | made here | the big one: Level 3 intro, the ghost's fart |
| body/diarrhoea.ogg | made here (`tools/make_flood_sounds.py`) | Level 2 intro: the blast from the clogged stall (fart_06 + wet splatter + bubbles) |
| water/trickle_loop.ogg | made here (flood) | water spilling out under the clogged stall's door (loop) |
| water/gush_loop.ogg | made here (flood) | a basin overflowing (loop, each running tap) |
| water/rise_loop.ogg | made here (flood) | the room filling: low slosh and rumble (loop, 2D) |
| water/gurgle_loop.ogg | made here (flood) | the drain swallowing the water (loop) |
| water/swim_splash_01.ogg, water/swim_splash_02.ogg, water/swim_splash_03.ogg, water/swim_splash_04.ogg | 40 CC0 water (`splash_06`, `splash_08`, `splash_13`, `splash_15`; mono, 30 ms pad, peak gain to -1 dB, at most +3 dB: `make_cartoon_sounds.py splash`) | a swimming stroke, synced to the `swim` clip (Stage 6b: replaces the synthesised strokes) |
| water/wade_01.ogg | made here (flood) | a step in shallow water |
| water/wade_02.ogg | made here (flood) | a step in shallow water |
| water/wade_03.ogg | made here (flood) | a step in shallow water |
| water/wade_04.ogg | made here (flood) | a step in shallow water |
| water/dive.ogg | made here (flood) | going under: splash + bubbles |
| water/surface.ogg | made here (flood) | coming back up |
| water/plunge_01.ogg | made here (flood) | plunger squelch |
| water/plunge_02.ogg | made here (flood) | plunger squelch |
| water/plunge_03.ogg | made here (flood) | plunger squelch |
| water/glug.ogg | made here (flood) | the toilet unclogs |
| water/tap_squeak.ogg | made here (flood) | a tap turned on or off |
| water/plug_pop.ogg | made here (flood) | the drain plug comes out |
| shooter/gun_shot_01.ogg | made here (`tools/make_shooter_sounds.py`) | Level 4 WATER WAR: Bob's water gun fires |
| shooter/gun_shot_02.ogg | made here (shooter) | Bob's water gun fires |
| shooter/gun_shot_03.ogg | made here (shooter) | Bob's water gun fires |
| shooter/blob_splash_01.ogg | made here (shooter) | a water blob lands |
| shooter/blob_splash_02.ogg | made here (shooter) | a water blob lands |
| shooter/blob_splash_03.ogg | made here (shooter) | a water blob lands |
| shooter/hit_tick.ogg | made here (shooter) | hit marker: body |
| shooter/hit_ding.ogg | made here (shooter) | hit marker: head |
| shooter/kill_chime.ogg | made here (shooter) | a kill |
| shooter/enemy_shot_01.ogg | made here (shooter) | a crew / BOSSY brown shot |
| shooter/enemy_shot_02.ogg | made here (shooter) | a crew / BOSSY brown shot |
| shooter/enemy_shot_03.ogg | made here (shooter) | a crew / BOSSY brown shot |
| shooter/bob_splat_01.ogg | made here (shooter) | a brown blob hits Bob |
| shooter/bob_splat_02.ogg | made here (shooter) | a brown blob hits Bob |
| shooter/dry_click.ogg | made here (shooter) | the trigger on an empty tank |
| shooter/refill.ogg | made here (shooter) | the tank refills at a sink |
| shooter/hose_loop.ogg | made here (shooter) | the SUPER-SOAKER hose (loop) |
| ambience/hum_loop.ogg | made here | room hum everywhere |
| ambience/gibberish_loop.ogg | made here (`tools/make_character_sounds.py`, Piper voices, Stage 6) | the queue in the waiting room: 4 high-pitched Jijio voices speaking gibberish |
| ambience/bed_loop.ogg | made here (`tools/make_cartoon_sounds.py`, Stage 6) | the constant background everywhere: this folder's farts, plops, groans, tummy rumbles, four flushes and taps, mixed through the walls (Stage 6b: farts twice as likely and louder) |
| ambience/groan_01.ogg | made here (Piper voices) | groan / straining from an occupied stall |
| ambience/groan_02.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_03.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_04.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_05.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_06.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_07.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_08.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_09.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_10.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_11.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_12.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_13.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_14.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_15.ogg | made here (Piper voices) | groan / straining |
| ambience/groan_16.ogg | made here (Piper voices) | groan / straining |
| hits/impactSoft_heavy_000.ogg | Kenney Impact Sounds | a kick landing on Bob |
| hits/impactSoft_heavy_001.ogg | Kenney Impact Sounds | a kick landing on Bob |
| hits/impactSoft_heavy_002.ogg | Kenney Impact Sounds | a kick landing on Bob |
| hits/impactPunch_medium_000.ogg | Kenney Impact Sounds | Level 4 fight: a jab lands (added 2026-09-25; the whole pack re-downloaded from kenney.nl, licence still CC0) |
| hits/impactPunch_medium_001.ogg | Kenney Impact Sounds | Level 4 fight: a jab lands |
| hits/impactPunch_medium_002.ogg | Kenney Impact Sounds | Level 4 fight: a jab lands |
| hits/impactPunch_heavy_000.ogg | Kenney Impact Sounds | Level 4 fight: a heavy hit lands (kick, uppercut, spin kick, super, finisher) |
| hits/impactPunch_heavy_001.ogg | Kenney Impact Sounds | Level 4 fight: a heavy hit lands |
| hits/impactPunch_heavy_002.ogg | Kenney Impact Sounds | Level 4 fight: a heavy hit lands |
| hits/impactPunch_heavy_003.ogg | Kenney Impact Sounds | Level 4 fight: the KO |
| hits/impactSoft_medium_000.ogg | Kenney Impact Sounds | Level 4 fight: a guarded hit |
| hits/impactSoft_medium_001.ogg | Kenney Impact Sounds | Level 4 fight: a guarded hit |
| hits/impactWood_light_000.ogg | Kenney Impact Sounds | knocking on a stall door |
| hits/impactWood_light_001.ogg | Kenney Impact Sounds | knocking on a stall door |
| hits/impactWood_light_002.ogg | Kenney Impact Sounds | knocking on a stall door |
| paper/wipe_01.ogg, paper/wipe_02.ogg, paper/wipe_03.ogg | made here (Stage 6) | wiping: a scrunch then a swipe |
| paper/tear_01.ogg, paper/tear_02.ogg | made here (Stage 6) | the tissue tears (tissue_grab frame 40) |
| paper/mop_squeak_01.ogg, paper/mop_squeak_02.ogg, paper/mop_squeak_03.ogg | made here (Stage 6) | a squeaky mop: two squeaks, no swish (rebuilt Stage 6b) |
| grunts/oof_jijio_a_01.ogg, grunts/oof_jijio_a_02.ogg, grunts/oof_jijio_a_03.ogg, grunts/oof_jijio_a_04.ogg, grunts/oof_jijio_b_01.ogg, grunts/oof_jijio_b_02.ogg, grunts/oof_jijio_b_03.ogg, grunts/oof_jijio_b_04.ogg, grunts/oof_jijio_c_01.ogg, grunts/oof_jijio_c_02.ogg, grunts/oof_jijio_c_03.ogg, grunts/oof_jijio_c_04.ogg | made here (`tools/make_character_sounds.py`, Piper voices, Stage 6) | a generic Jijio hit: Ooff / Oww / Urgh / Hmmph |
| grunts/oof_pushy_01.ogg, grunts/oof_pushy_02.ogg, grunts/oof_pushy_03.ogg, grunts/oof_pushy_04.ogg, grunts/oof_sneaky_01.ogg, grunts/oof_sneaky_02.ogg, grunts/oof_sneaky_03.ogg, grunts/oof_sneaky_04.ogg, grunts/oof_bossy_01.ogg, grunts/oof_bossy_02.ogg, grunts/oof_bossy_03.ogg, grunts/oof_bossy_04.ogg | made here (Piper voices) | each cutter hit in a fight, in their own voice |
| grunts/ko_pushy.ogg, grunts/ko_sneaky.ogg, grunts/ko_bossy.ogg | made here (Piper voices) | a cutter knocked out: "Ooooooh nooooooo..." |
| grunts/bob_ouch_01.ogg, grunts/bob_ouch_02.ogg, grunts/bob_ouch_03.ogg | made here (Piper voices) | Bob hit (fights, the timeout kick) |
| grunts/bob_groan_1_01.ogg, grunts/bob_groan_1_02.ogg, grunts/bob_groan_1_03.ogg, grunts/bob_groan_2_01.ogg, grunts/bob_groan_2_02.ogg, grunts/bob_groan_2_03.ogg, grunts/bob_groan_3_01.ogg, grunts/bob_groan_3_02.ogg, grunts/bob_groan_3_03.ogg | made here (Piper voices) | Bob holding it in: 1 mild, 2 bad, 3 desperate |
| grunts/complain_jijio_a_01.ogg, grunts/complain_jijio_a_02.ogg, grunts/complain_jijio_a_03.ogg, grunts/complain_jijio_a_04.ogg, grunts/complain_jijio_a_05.ogg, grunts/complain_jijio_a_06.ogg, grunts/complain_jijio_b_01.ogg, grunts/complain_jijio_b_02.ogg, grunts/complain_jijio_b_03.ogg, grunts/complain_jijio_b_04.ogg, grunts/complain_jijio_b_05.ogg, grunts/complain_jijio_b_06.ogg, grunts/complain_jijio_c_01.ogg, grunts/complain_jijio_c_02.ogg, grunts/complain_jijio_c_03.ogg, grunts/complain_jijio_c_04.ogg, grunts/complain_jijio_c_05.ogg, grunts/complain_jijio_c_06.ogg | made here (Piper voices) | Jijios complaining from the stalls (background) |
| ui/open_001.wav | Kenney Interface Sounds | conversation box opens |
| ui/close_001.wav | Kenney Interface Sounds | conversation box closes |
| ui/select_001.wav | Kenney Interface Sounds | conversation choice / advance |
| ui/select_002.wav | Kenney Interface Sounds | picking up an item |
| ui/error_001.wav | Kenney Interface Sounds | wrong answer |
| ui/confirmation_001.wav | Kenney Interface Sounds | a mission is done |
| ui/confirmation_003.wav | Kenney Interface Sounds | level complete |
| ui/error_003.wav | Kenney Interface Sounds | kicked out |

## Made here (2026-09-27, `tools/make_ambience.py`; no licence question)

None of the CC0 packs has a fart, a room hum or crowd chatter, and Pixabay (allowed: royalty-free, no credit) blocks scripted downloads, so these are made with ffmpeg and Piper. **Nobody has listened to them yet: the owner judges.**
- **Farts:** a buzz (tanh-shaped sine) whose pitch wobbles and drops, a little noise, an envelope; some chopped into a sputter. Low-passed 1.1 kHz, 30 ms lead-in, loudness -16 LUFS (the big one -12). They replace the old placeholder (brown noise with a tremolo, deleted).
- **Hum:** 120 Hz tube hum + harmonics and low-passed brown-noise air, -24 LUFS; a seamless 12 s loop (the tail is crossfaded into the head; measured: the step at the loop point is smaller than the file's normal sample steps).
- **Chatter:** RETIRED in Stage 6 (owner: "sounds like men"); replaced by the gibberish loop below. Old files (footstep_concrete, paper_01-04, swim_01-04) are in `retired/audio_stage6/`.
- **Stage 6 (2026-09-28, `tools/make_cartoon_sounds.py`, `tools/make_character_sounds.py`; owner "yes" to all after listening):** squeaks = a clipped sine gliding up with a fast wobble + a short wet slap (the flood's splash recipe); wipe = gated white-noise crackle (scrunch) then a pink-noise swipe; tear = a denser, brighter crackle; poop blast = fart_02/04/06 (or 04/01/02) staggered + brown-noise splatter + bubbles + plops, compressed; tummy = low bubbles + a wobbling 48-72 Hz growl; stroke = slap + spray + bubbles. The bed: 35 events in 40 s (fixed seed), low-passed 2.2 kHz with a room echo, -20 LUFS, a seamless 36 s loop. Voices: the dialogue casts (`tools/make_voices.py`); a grunt is cut at its first 0.2 s silence (norman added a second breath). Gibberish: 8 nonsense lines, 4 layers pitched 1.55-1.78 x and 25 % faster, low-passed 2.6 kHz, -22 LUFS, a seamless 20 s loop. One-shots: 30 ms lead-in.
- **Flood (2026-09-27, `tools/make_flood_sounds.py`):** splashes = white noise band-passed with a fast attack and an exponential tail; bubbles = trains of short sines whose pitch rises as they decay; loops = filtered pink/brown noise with a slow tremolo, made seamless like the hum; the plunger = a falling-pitch thump + a sucking noise; the squeak = a swept sine with vibrato; the blast = fart_06 + brown-noise splatter + bubbles. One-shots have 30 ms of silence in front and a set peak (-1.5 to -8 dB).
- **WATER WAR (2026-09-27, `tools/make_shooter_sounds.py`):** shots = high band-passed noise bursts + a falling low thump (the enemy's lower, with bubbles); splashes and Bob's splat = the flood's splash recipe, shorter or lower; tick = a 2.4 kHz blip; ding and chime = bell partials (1, 2.76, 5.4 x), the chime two rising notes; dry click = two 3.1 kHz clicks 35 ms apart; refill = bubbles + band-passed noise; hose = pink noise 0.5-8 kHz with a light tremolo, a seamless 4 s loop. One-shots: 30 ms lead-in, peaks -4 to -8 dB.
- **Groans:** 8 lines ("Hnnnnnngh...", "Why did I eat that burrito.") in the three generic voices, slowed, low-passed 1.6 kHz with a small boxy echo (through a stall door), -18 LUFS.
