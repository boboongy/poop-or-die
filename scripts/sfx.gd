extends RefCounted
## Every game sound, by event name. This is the one place that maps an event to its files, volume and pitch
## range, so replacing a sound means editing one line. Files and licences: audio/SOURCES.md.
## World sounds are 3D (they come from where they happen, and are heard through walls); UI sounds are plain.
## `played` records the events in order (newest last) so tests can check that an action makes a sound.
## No autoload (project.godot is editor-owned): everything here is static and parents its players to the tree root.

const DIR := "res://audio/"
## A 3D sound may get louder than its volume when the listener is close (Godot's default max_db is +3 dB): the boombox walked up to
## touched 0 dB in the recorded mix (probe_level5_sound / probe_soundscape, 2026-09-27). Every 3D player is capped here.
const MAX_3D_DB := 0.0

## files: relative to DIR, one picked at random. db: volume. pitch: random +- range. range: 3D hearing distance (m).
## max_voices: how many copies may sound at once (five kickers must not deafen).
const EVENTS := {
	# Owner 2026-09-25 "no footstep sound": they fired (11 in 3 s of walking) but peaked at -18 dB in the recorded mix
	# (tests/probe_footsteps_sound.gd): the engine fades a 3D sound in over its first milliseconds and a step's whole peak is
	# in its first 10 ms. The files now start with 30 ms of silence (SOURCES.md). Walking measured at -10 dB here (was 0 dB peaks at -7).
	# Stage 6b A (owner playtest 2026-09-28: the squeaky steps were constant, "normal footsteps again"): the Kenney steps are back;
	# running = the SAME steps pitched up x1.25 and 4 dB louder (footsteps.gd RUN_SPEED). pitch_base: a fixed pitch before the random range.
	# Every action's sound peaks >= -12 dB (tools/sound_levels.py, tests/test_action_sounds.gd).
	"step": {"files": ["footsteps/footstep_concrete_000.ogg", "footsteps/footstep_concrete_001.ogg", "footsteps/footstep_concrete_002.ogg", "footsteps/footstep_concrete_003.ogg", "footsteps/footstep_concrete_004.ogg"], "db": -9.0, "pitch": 0.1, "range": 18.0, "max_voices": 8, "max_db": -9.0},
	# ^ -9 (was -8/-7 on the first wiring): 8 crowd steps in 0.15 s + 3 slips on one frame peaked at -0.8/-1.3/-1.4 dB in 3 of 3
	# windowed flood recordings (probe_flood_sound, segment e at 23 s). OPEN (owner): Bob's own step on top of the Level 5 boombox, close
	# up, peaks -0.4 to -1.5 dB (4 runs; -3.1 dB or less with steps muted, 3 runs); the -0.5 dB limiter catches it. -10 would fail the -12 floor.
	"run_step": {"files": ["footsteps/footstep_concrete_000.ogg", "footsteps/footstep_concrete_001.ogg", "footsteps/footstep_concrete_002.ogg", "footsteps/footstep_concrete_003.ogg", "footsteps/footstep_concrete_004.ogg"], "db": -5.0, "pitch": 0.08, "pitch_base": 1.25, "range": 20.0, "max_voices": 8, "max_db": -5.0},
	# max_db: a step can be AT the listener (Level 2's rampage runs through Bob): uncapped up close it reached 0 dB in the recorded mix
	"door_open": {"files": ["doors/door_open.ogg"], "db": -4.0, "pitch": 0.05, "range": 20.0, "max_voices": 24},
	"door_close": {"files": ["doors/door_close_01.ogg", "doors/door_close_02.ogg"], "db": -4.0, "pitch": 0.05, "range": 20.0, "max_voices": 24},
	"tap": {"files": ["water/loop_water_02.ogg"], "db": -16.0, "range": 6.0}, # looped: loop_at()
	"flush": {"files": ["water/toilet_01.ogg"], "db": -3.0},
	"plop": {"files": ["water/plop_01.ogg", "water/plop_02.ogg"], "db": -4.0, "pitch": 0.1, "range": 12.0},
	"fart": {"files": ["body/fart_01.ogg", "body/fart_02.ogg", "body/fart_03.ogg", "body/fart_04.ogg", "body/fart_05.ogg"], "db": -2.0, "pitch": 0.12, "range": 12.0},
	"shat": {"files": ["body/squelch_01.ogg"], "db": -2.0, "pitch": 0.04, "range": 14.0}, # Stage 6d: Bob loses, the wet squelch
	"fart_loud": {"files": ["body/fart_06.ogg"], "db": -3.0, "pitch": 0.03, "range": 40.0}, # Level 3 intro: the ghost's fart
	# Background soundscape (ambience.gd; SPEC Round 2 Stage 2). All made by tools/make_ambience.py except the flush and tap files.
	# Levels set by windowed recordings (probe_soundscape, probe_level5_sound): a groan at -4 / fart at -6 beside her boombox hit 0 dB.
	"amb_hum": {"files": ["ambience/hum_loop.ogg"], "db": -12.0}, # looped: loop_ui(), everywhere
	# looped: loop_at(), the queue in the waiting room. Stage 6 (8): high-pitched Jijio gibberish (make_character_sounds.py)
	"amb_chatter": {"files": ["ambience/gibberish_loop.ogg"], "db": -8.0, "range": 14.0},
	# Stage 6, owner 2026-09-28: a CONSTANT bed of farts, plops, flushes, sinks and groans through the walls (looped: loop_ui(), everywhere)
	# -13 (was -11 on the first wiring): Level 5 peaked at -0.2 dB in 1 of 6 windowed runs with it, -1.1 dB worst in 3 runs without it
	# Stage 6b B (owner: the bed "lacks audible farts, flushes, groans"): +6 dB to -7, and the file has more, louder farts and 4 flushes
	"amb_bed": {"files": ["ambience/bed_loop.ogg"], "db": -7.0},
	"amb_plop": {"files": ["water/plop_01.ogg", "water/plop_02.ogg"], "db": -8.0, "pitch": 0.15, "range": 16.0, "max_voices": 2},
	"amb_tummy": {"files": ["body/tummy_01.ogg", "body/tummy_02.ogg", "body/tummy_03.ogg", "body/tummy_04.ogg"], "db": -8.0, "pitch": 0.1, "range": 14.0, "max_voices": 2},
	"amb_complain": {"files": ["grunts/complain_jijio_a_01.ogg", "grunts/complain_jijio_a_02.ogg", "grunts/complain_jijio_a_03.ogg", "grunts/complain_jijio_a_04.ogg", "grunts/complain_jijio_a_05.ogg", "grunts/complain_jijio_a_06.ogg", "grunts/complain_jijio_b_01.ogg", "grunts/complain_jijio_b_02.ogg", "grunts/complain_jijio_b_03.ogg", "grunts/complain_jijio_b_04.ogg", "grunts/complain_jijio_b_05.ogg", "grunts/complain_jijio_b_06.ogg", "grunts/complain_jijio_c_01.ogg", "grunts/complain_jijio_c_02.ogg", "grunts/complain_jijio_c_03.ogg", "grunts/complain_jijio_c_04.ogg", "grunts/complain_jijio_c_05.ogg", "grunts/complain_jijio_c_06.ogg"], "db": -7.0, "range": 18.0, "max_voices": 2},
	"amb_flush": {"files": ["water/toilet_01.ogg"], "db": -9.0, "pitch": 0.08, "range": 30.0, "max_voices": 2},
	"amb_tap": {"files": ["water/loop_water_02.ogg"], "db": -14.0, "range": 14.0}, # looped for a few seconds: someone washing their hands
	"amb_fart": {"files": ["body/fart_01.ogg", "body/fart_02.ogg", "body/fart_03.ogg", "body/fart_04.ogg", "body/fart_05.ogg"], "db": -9.0, "pitch": 0.12, "range": 20.0, "max_voices": 2},
	"amb_groan": {"files": ["ambience/groan_01.ogg", "ambience/groan_02.ogg", "ambience/groan_03.ogg", "ambience/groan_04.ogg", "ambience/groan_05.ogg", "ambience/groan_06.ogg", "ambience/groan_07.ogg", "ambience/groan_08.ogg", "ambience/groan_09.ogg", "ambience/groan_10.ogg", "ambience/groan_11.ogg", "ambience/groan_12.ogg", "ambience/groan_13.ogg", "ambience/groan_14.ogg", "ambience/groan_15.ogg", "ambience/groan_16.ogg"], "db": -7.0, "pitch": 0.04, "range": 16.0, "max_voices": 2},
	"kick": {"files": ["hits/impactSoft_heavy_000.ogg", "hits/impactSoft_heavy_001.ogg", "hits/impactSoft_heavy_002.ogg"], "db": -3.0, "pitch": 0.1, "range": 25.0, "max_voices": 4},
	"scare": {"files": ["body/hurt_01.ogg", "body/hurt_02.ogg", "body/hurt_03.ogg"], "db": 4.0, "pitch": 0.3, "max_voices": 2}, # Level 3 jump scare: PLACEHOLDER (the hurt cries, loud and pitched about); the owner may supply a real sting
	"knock": {"files": ["hits/impactWood_light_000.ogg", "hits/impactWood_light_001.ogg", "hits/impactWood_light_002.ogg"], "db": 0.0, "pitch": 0.05, "range": 40.0},
	"wipe": {"files": ["paper/wipe_01.ogg", "paper/wipe_02.ogg", "paper/wipe_03.ogg"], "db": -6.0, "pitch": 0.08, "range": 12.0, "max_voices": 2}, # scrunch + swipe
	"tear": {"files": ["paper/tear_01.ogg", "paper/tear_02.ogg"], "db": -4.0, "pitch": 0.08, "range": 12.0}, # tissue_grab frame 40
	"flood": {"files": ["water/loop_water_02.ogg"], "db": -8.0, "range": 12.0}, # looped: loop_at(), Level 2's overflowing toilet
	"spray": {"files": ["water/loop_water_02.ogg"], "db": -10.0, "range": 12.0}, # looped: loop_at(), Level 4 water guns (stand-in for a spray hiss)
	"mop": {"files": ["paper/mop_squeak_01.ogg", "paper/mop_squeak_02.ogg", "paper/mop_squeak_03.ogg"], "db": -9.0, "pitch": 0.12, "range": 10.0}, # Stage 6b: squeaks only (the swish went); a pure squeak is loud (-6 LUFS): -9 (was -5)
	"slip": {"files": ["hits/impactSoft_heavy_001.ogg", "hits/impactSoft_heavy_002.ogg"], "db": -2.0, "pitch": 0.1, "range": 15.0, "max_voices": 2}, # 2 (was 4): three walkers slipping on one frame added to a 0 dB peak
	# Level 4 fist fights (owner 2026-09-25: "punching sound also don't have"): jabs, heavy hits (kick, uppercut, spin, super,
	# finisher), a guarded hit, the KO.
	"punch_hit": {"files": ["hits/impactPunch_medium_000.ogg", "hits/impactPunch_medium_001.ogg", "hits/impactPunch_medium_002.ogg"], "db": 0.0, "pitch": 0.12, "range": 25.0, "max_voices": 4},
	"heavy_hit": {"files": ["hits/impactPunch_heavy_000.ogg", "hits/impactPunch_heavy_001.ogg", "hits/impactPunch_heavy_002.ogg"], "db": 1.0, "pitch": 0.1, "range": 25.0, "max_voices": 4},
	"block_hit": {"files": ["hits/impactSoft_medium_000.ogg", "hits/impactSoft_medium_001.ogg"], "db": -3.0, "pitch": 0.1, "range": 25.0, "max_voices": 4},
	"ko": {"files": ["hits/impactPunch_heavy_003.ogg"], "db": 3.0, "pitch": 0.05, "range": 30.0},
	# Stage 6 (2) E: voices on hits, in each character's own Piper cast (tools/make_character_sounds.py). fight.gd: the cutter on about
	# every other clean hit, Bob on every one, a long groan on the KO. `oof` = the generic Jijios (the hide-and-seek and slip hits).
	"oof": {"files": ["grunts/oof_jijio_a_01.ogg", "grunts/oof_jijio_a_02.ogg", "grunts/oof_jijio_a_03.ogg", "grunts/oof_jijio_a_04.ogg", "grunts/oof_jijio_b_01.ogg", "grunts/oof_jijio_b_02.ogg", "grunts/oof_jijio_b_03.ogg", "grunts/oof_jijio_b_04.ogg", "grunts/oof_jijio_c_01.ogg", "grunts/oof_jijio_c_02.ogg", "grunts/oof_jijio_c_03.ogg", "grunts/oof_jijio_c_04.ogg"], "db": -3.0, "pitch": 0.05, "range": 25.0, "max_voices": 2},
	"oof_pushy": {"files": ["grunts/oof_pushy_01.ogg", "grunts/oof_pushy_02.ogg", "grunts/oof_pushy_03.ogg", "grunts/oof_pushy_04.ogg"], "db": -3.0, "pitch": 0.04, "range": 25.0, "max_voices": 1},
	"oof_sneaky": {"files": ["grunts/oof_sneaky_01.ogg", "grunts/oof_sneaky_02.ogg", "grunts/oof_sneaky_03.ogg", "grunts/oof_sneaky_04.ogg"], "db": -3.0, "pitch": 0.04, "range": 25.0, "max_voices": 1},
	"oof_bossy": {"files": ["grunts/oof_bossy_01.ogg", "grunts/oof_bossy_02.ogg", "grunts/oof_bossy_03.ogg", "grunts/oof_bossy_04.ogg"], "db": -3.0, "pitch": 0.04, "range": 25.0, "max_voices": 1},
	"ko_pushy": {"files": ["grunts/ko_pushy.ogg"], "db": -2.0, "range": 30.0, "max_voices": 1},
	"ko_sneaky": {"files": ["grunts/ko_sneaky.ogg"], "db": -2.0, "range": 30.0, "max_voices": 1},
	"ko_bossy": {"files": ["grunts/ko_bossy.ogg"], "db": -2.0, "range": 30.0, "max_voices": 1},
	"bob_ouch": {"files": ["grunts/bob_ouch_01.ogg", "grunts/bob_ouch_02.ogg", "grunts/bob_ouch_03.ogg"], "db": -3.0, "pitch": 0.04, "range": 25.0, "max_voices": 1},
	# Stage 6 (10) B: Bob holding it in (2D: it is the player's own voice), more desperate as the level timer runs low (level_toilet.gd)
	"bob_groan": {"files": ["grunts/bob_groan_1_01.ogg", "grunts/bob_groan_1_02.ogg", "grunts/bob_groan_1_03.ogg"], "db": -6.0, "max_voices": 1},
	"bob_groan_bad": {"files": ["grunts/bob_groan_2_01.ogg", "grunts/bob_groan_2_02.ogg", "grunts/bob_groan_2_03.ogg"], "db": -5.0, "max_voices": 1},
	"bob_groan_desperate": {"files": ["grunts/bob_groan_3_01.ogg", "grunts/bob_groan_3_02.ogg", "grunts/bob_groan_3_03.ogg"], "db": -3.0, "max_voices": 1},
	# Level 2 "The flood" (SPEC Round 2 Stage 3): all made by tools/make_flood_sounds.py. Levels are PROPOSAL until measured in a
	# windowed recording (tests/probe_flood_sound.gd) and heard by the owner.
	"diarrhoea": {"files": ["body/diarrhoea.ogg"], "db": -3.0, "range": 45.0}, # the intro's blast from the clogged stall
	# Stage 6 (1): Bob's poop, an explosive diarrhoea + fart burst (make_cartoon_sounds.py; its own splats and plops). Stage 6b: 2D (it is
	# his, play_ui in toilet_session.gd) and rebuilt brighter and denser: it fired but the owner did not hear it (-16.7/-18.8 LUFS, 3D at -2
	# dB from the seat, quieter than a footstep in the windowed recording, tests/probe_poop_sound.gd); now -11.5 LUFS. -3 (was 0: 0.0 dB
	# peaks in 3 of 3 windowed sequences, pinned on the limiter for 2 s).
	"poop_blast": {"files": ["body/poop_blast_01.ogg", "body/poop_blast_02.ogg"], "db": -3.0, "pitch": 0.05, "max_voices": 1},
	"trickle": {"files": ["water/trickle_loop.ogg"], "db": -6.0, "range": 12.0}, # looped: water out under the stall door
	"gush": {"files": ["water/gush_loop.ogg"], "db": -15.0, "range": 12.0, "max_voices": 5}, # looped: each running source (-10 hit 0 dB beside the sinks, 1 run in 3)
	"rise": {"files": ["water/rise_loop.ogg"], "db": -40.0}, # looped 2D: the room filling; flood_water.gd raises it with the depth
	"gurgle": {"files": ["water/gurgle_loop.ogg"], "db": -4.0, "range": 30.0}, # looped: the drain
	# Stage 6b C: a REAL recorded CC0 splash per stroke (the synthesised one "does not sound right"), synced to the `swim` clip
	# (footsteps.gd, player.gd SWIM_SPLASH_PHASE)
	"swim": {"files": ["water/swim_splash_01.ogg", "water/swim_splash_02.ogg", "water/swim_splash_03.ogg", "water/swim_splash_04.ogg"], "db": -5.0, "pitch": 0.1, "range": 15.0, "max_voices": 3},
	"wade": {"files": ["water/wade_01.ogg", "water/wade_02.ogg", "water/wade_03.ogg", "water/wade_04.ogg"], "db": -10.0, "pitch": 0.1, "range": 15.0, "max_voices": 8, "max_db": -8.0},
	# the last pump, the glug and the surfacing land together beside Bob: at -4/-3/-6 they hit 0 dB (2 runs in 3, probe_flood_sound)
	"dive": {"files": ["water/dive.ogg"], "db": -7.0, "range": 20.0},
	"surface": {"files": ["water/surface.ogg"], "db": -10.0, "range": 20.0},
	"plunge": {"files": ["water/plunge_01.ogg", "water/plunge_02.ogg", "water/plunge_03.ogg"], "db": -8.0, "pitch": 0.08, "range": 20.0},
	"glug": {"files": ["water/glug.ogg"], "db": -8.0, "range": 25.0},
	"tap_squeak": {"files": ["water/tap_squeak.ogg"], "db": -8.0, "pitch": 0.08, "range": 15.0, "max_voices": 4},
	"plug_pop": {"files": ["water/plug_pop.ogg"], "db": -3.0, "range": 20.0},
	# Level 4 round 3 "WATER WAR" (SPEC Stage 4 plan (9)): all made by tools/make_shooter_sounds.py. Levels are PROPOSAL until
	# measured in a windowed recording (tests/probe_shooter_sound.gd) and heard by the owner. Bob's own gun and the markers are 2D
	# (they are his); what happens out there is 3D. max_voices: 8 shots/s, each held 0.19 s + 0.3 s (Sfx._start) = 4 at once.
	"gun_shot": {"files": ["shooter/gun_shot_01.ogg", "shooter/gun_shot_02.ogg", "shooter/gun_shot_03.ogg"], "db": -12.0, "pitch": 0.06, "max_voices": 5},
	"blob_splash": {"files": ["shooter/blob_splash_01.ogg", "shooter/blob_splash_02.ogg", "shooter/blob_splash_03.ogg"], "db": -12.0, "pitch": 0.12, "range": 16.0, "max_voices": 4, "max_db": -8.0},
	"hit_tick": {"files": ["shooter/hit_tick.ogg"], "db": -8.0, "pitch": 0.03, "max_voices": 4},
	"hit_ding": {"files": ["shooter/hit_ding.ogg"], "db": -8.0, "max_voices": 3},
	"kill_chime": {"files": ["shooter/kill_chime.ogg"], "db": -6.0, "max_voices": 2},
	"enemy_shot": {"files": ["shooter/enemy_shot_01.ogg", "shooter/enemy_shot_02.ogg", "shooter/enemy_shot_03.ogg"], "db": -10.0, "pitch": 0.08, "range": 25.0, "max_voices": 6, "max_db": -6.0},
	"bob_splat": {"files": ["shooter/bob_splat_01.ogg", "shooter/bob_splat_02.ogg"], "db": -8.0, "pitch": 0.08, "max_voices": 2},
	"dry_click": {"files": ["shooter/dry_click.ogg"], "db": -8.0, "max_voices": 2},
	"refill": {"files": ["shooter/refill.ogg"], "db": -8.0, "max_voices": 1},
	"hose": {"files": ["shooter/hose_loop.ogg"], "db": -10.0}, # looped: loop_ui(), the SUPER-SOAKER ultimate
	"pickup": {"files": ["ui/select_002.wav"], "db": -6.0},
	"ui_open": {"files": ["ui/open_001.wav"], "db": -8.0},
	"ui_close": {"files": ["ui/close_001.wav"], "db": -8.0},
	"ui_choose": {"files": ["ui/select_001.wav"], "db": -8.0},
	"ui_wrong": {"files": ["ui/error_001.wav"], "db": -8.0},
	"ui_done": {"files": ["ui/confirmation_001.wav"], "db": -6.0},
	"ui_win": {"files": ["ui/confirmation_003.wav"], "db": -4.0},
	"ui_lose": {"files": ["ui/error_003.wav"], "db": -4.0},
}

static var played: Array[String] = [] ## event names, newest last (kept short)
static var _cache := {}
static var _voices := {}


## The sound events, with their file lists (tests check that every file exists and is listed in SOURCES.md).
static func events() -> Dictionary:
	return EVENTS


static func count(event: String) -> int:
	return played.count(event)


## A sound at a place in the world, heard through walls and fading with distance.
static func play_at(anchor: Node, event: String, position: Vector3) -> AudioStreamPlayer3D:
	var def := _def(event)
	if not _take_voice(event, def):
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = _pick(def)
	player.volume_db = def["db"]
	player.pitch_scale = _pitch(def)
	player.max_distance = def.get("range", 25.0)
	player.unit_size = 5.0
	player.max_db = def.get("max_db", MAX_3D_DB)
	anchor.get_tree().root.add_child(player)
	player.global_position = position
	_start(anchor, event, player)
	return player


## A plain (not positional) sound: UI, and the flush, which covers the whole screen.
static func play_ui(anchor: Node, event: String) -> AudioStreamPlayer:
	var def := _def(event)
	if not _take_voice(event, def):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = _pick(def)
	player.volume_db = def["db"]
	player.pitch_scale = _pitch(def)
	anchor.get_tree().root.add_child(player)
	_start(anchor, event, player)
	return player


## A looping sound that lives on `anchor` (a running tap). The caller stops it with stop_loop().
static func loop_at(anchor: Node3D, event: String) -> AudioStreamPlayer3D:
	var def := _def(event)
	var player := AudioStreamPlayer3D.new()
	player.stream = _looped(_pick(def))
	player.volume_db = def["db"]
	player.max_distance = def.get("range", 25.0)
	player.unit_size = 3.0
	player.max_db = MAX_3D_DB
	anchor.add_child(player)
	player.play()
	_log(event)
	return player


## A plain (not positional) looping sound (the room hum). The caller stops it with stop_loop().
static func loop_ui(anchor: Node, event: String) -> AudioStreamPlayer:
	var def := _def(event)
	var player := AudioStreamPlayer.new()
	player.stream = _looped(_pick(def))
	player.volume_db = def["db"]
	anchor.add_child(player)
	player.play()
	_log(event)
	return player


static func _looped(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate() as AudioStream # a copy, so the loop flag is not shared with one-shots
	if copy is AudioStreamOggVorbis:
		copy.loop = true
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return copy


static func stop_loop(player: Node) -> void:
	if is_instance_valid(player):
		player.queue_free()


## Knock on a door: `times` knocks about 0.2 s apart, from where the door is.
static func knock(anchor: Node, position: Vector3, times := 3) -> void:
	for i in times:
		if not is_instance_valid(anchor) or not anchor.is_inside_tree():
			return
		play_at(anchor, "knock", position)
		await anchor.get_tree().create_timer(0.17 + randf() * 0.06).timeout


## Let a playing sound die away instead of cutting off.
static func fade_out(player: Node, seconds := 0.5) -> void:
	if not is_instance_valid(player):
		return
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", -60.0, seconds)
	tween.tween_callback(player.queue_free)


static func _def(event: String) -> Dictionary:
	assert(EVENTS.has(event), "unknown sound event '%s'" % event)
	return EVENTS[event]


static func _load(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = load(DIR + file)
	return _cache[file]


static func _pick(def: Dictionary) -> AudioStream:
	var files: Array = def["files"]
	return _load(files[randi() % files.size()])


static func _pitch(def: Dictionary) -> float:
	return float(def.get("pitch_base", 1.0)) * (1.0 + randf_range(-1.0, 1.0) * float(def.get("pitch", 0.0)))


static func _take_voice(event: String, def: Dictionary) -> bool:
	var used: int = _voices.get(event, 0)
	if used >= int(def.get("max_voices", 6)):
		return false
	_voices[event] = used + 1
	return true


static func _log(event: String) -> void:
	played.append(event)
	if played.size() > 400:
		played = played.slice(200)


static func _start(anchor: Node, event: String, player: Node) -> void:
	_log(event)
	player.play()
	# Free it when it should be over. A timer, not `finished`, so it also works with the dummy audio driver.
	var life: float = player.stream.get_length() / maxf(player.pitch_scale, 0.1) + 0.3
	anchor.get_tree().create_timer(life).timeout.connect(_release.bind(event, player))


## `player` is untyped on purpose: a fade-out or the scene ending may have freed it already, and a typed parameter refuses a freed object.
static func _release(event: String, player) -> void:
	_voices[event] = maxi(int(_voices.get(event, 1)) - 1, 0)
	if is_instance_valid(player):
		player.queue_free()
