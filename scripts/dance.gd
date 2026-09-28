extends Node
## Level 5 "Dance battle" (SPEC "Level 5", owner story + plan approved 2026-09-24). SHUFFLE QUEEN (hot pink) dances in place
## outside a random stall that is about to open, waiting for her turn; her boombox plays the beat (3D: louder when closer, heard
## through walls, so Bob can follow the music). After the finesse talk (missions/finesse_queue.gd) Bob may talk to her: every
## reply ends in her challenge (`challenged_bob`). Then EVERY Jijio (the queue + the walkers) rushes toward the two of them shouting,
## she yells "Not here! Waiting room!", a short fade, and everyone stands in a ring in the WAITING ROOM (the only open floor: every
## corridor is 2 m wide; owner chose it 2026-09-24), seen from a fixed camera in the toilet doorway with a gap in the ring on that side.
## The crowd grooves, pumps fists and hops on the beat, turning a little and shouting. The disco lights and the rhythm battle come next.
## Her stall's occupant stays inside until Bob wins (the level then releases that stall: ctx "reward_stall").
## Stand-in moves until the factory makes real clips (probed with tests/probe_dance_clips.gd: every arms-up frame of the attack clips is
## airborne and mid-spin): groove = two `walk` steps over two beats; fist pump = `punch` guard -> fist out -> guard over one beat; hop and
## sway are code.

signal challenged_bob ## Bob talked to her: the battle is on
signal circle_formed ## everyone stands in the ring in the waiting room
signal battle_won ## Bob won the dance battle: her stall opens (missions/win_dance_battle.gd)

const Cutters := preload("res://scripts/cutters.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")
const Fight := preload("res://scripts/fight.gd") ## its static _slice() cuts a looping clip from frames of another
const Pose := preload("res://scripts/pose.gd")
const DanceHud := preload("res://scripts/dance_hud.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Battle := preload("res://scripts/dance_battle.gd")
const Sfx := preload("res://scripts/sfx.gd")
const BoomboxProp := preload("res://assets/environments/boombox-prop/boombox-prop.glb")

const QUEEN_NAME := "SHUFFLE QUEEN"
const QUEEN_COLOR := Color(1.0, 0.1, 0.65)
const BOOMBOX_PULSE := 0.03 ## the boombox grows this much on each beat (boombox-prop notes)
const DISPLAY_GLOW := 1.5 ## M_DisplayCyan's emission energy between beats (as exported) ...
const DISPLAY_FLASH := 2.5 ## ... plus this on the beat
const SPOT_OUT := 0.55 ## from the door plane into the corridor (the Level 4 cutters stand the same)
const BOUNCE := 0.05 ## m the body dips on every beat
const SWAY := 0.09 ## rad of hip sway, one side per beat
const BEAT_DB := -3.0
## During the battle the beat is MUSIC: no fall-off with distance, no muffling (owner 2026-09-25: "during the battle I didn't hear
## anything"; recorded in a window, tests/probe_level5_sound.gd: 4.1 m from the battle camera the 3D beat was 8 dB quieter on average and
## its peaks 10 dB lower than when walking up to her). The synthesised loop itself is quiet (it peaks about 4 dB under full scale), so the
## battle level is raised too: measured with it, the battle mix averages about -18 dB with peaks near -3 dB. PROPOSAL, tune by ear.
## 2026-09-27: +1 -> 0 dB: with the crowd's shouts now spoken, two shouts on a drum hit reached 0 dB in 1 of 2 recorded runs.
const BATTLE_BEAT_DB := 0.0
const BATTLE_SHOUT_DB := -14.0 ## the crowd's spoken shouts during the battle (her own lines keep their level)
const BEAT_FILTER_DB := -24.0 ## Godot's default distance muffling, restored after the battle
const NOTES_TEXT := "♪ ♫"
const NOTES_HEIGHT := 2.25
## The waiting room (tests/probe_level5_space.gd): walls at x -5.15 / -0.3 and z -2.0 / +2.0, ceiling 2.8 m, the doorway into the toilet
## in the east wall at z 0.
const ROOM_CENTER := Vector3(-2.7, 0.0, 0.0)
const RING := Vector2(1.9, 1.55) ## the ellipse's half widths along x and z (0.45 m from the walls)
const RING_GAP := 0.8 ## rad left open each side of the camera (+X), so nobody stands between the lens and the dancers
## 1.1 m apart: with the dancers 1.4 m apart the ring's sides stood 0.75 m from them (test_level5_crowd)
const BOB_SPOT := Vector3(-2.5, 0.0, 0.55)
const QUEEN_SPOT := Vector3(-2.5, 0.0, -0.55)
const CAM_POS := Vector3(-0.5, 2.2, 0.0) ## in the doorway, high
const CAM_LOOK := Vector3(-2.6, 0.9, 0.0) ## 0.75 cut the back row's shout bubbles off at the top
const CAM_FOV := 65.0
## Camera focus (owner 2026-09-25): on each turn the camera glides from the doorway shot toward the dancer whose turn it is, with the
## other still in frame, holds, then glides back before the turn ends (test_dance_camera). The spot sits in the ring's open side on
## dancer's OWN side (z mirrored), 1.5 m up, so whoever dances is the nearer, bigger one (from the partner's side both turns looked
## alike: she was the big one both times). At z 0.45 the partner's head left the frame; `camera_focus` then turns the camera so the pair
## sits in the free part of the screen, right of the arrow lanes.
const FOCUS_SPOT := Vector3(-1.3, 1.5, 0.3) ## Bob's turn (Bob is at z +0.55); her turn uses z -0.3
const FOCUS_AIM := 0.65 ## the look point: 65 % of the way from the partner's chest to the dancer's chest
const FOCUS_IN := 0.5
const FOCUS_OUT := 0.7
const FOCUS_HOLD_MAX := 2.5
const FOCUS_MARGIN := 0.4 ## s the camera is home before the turn ends
const RUSH_SECONDS := 2.2
const FADE_SECONDS := 0.35
const RUN_SPEED := 3.6 ## above npc_jijio ANIM_WALK_RUN_MID, so they play `run`
const PUMP := ["punch", [8, 16, 8]] ## guard, fist out, guard: one beat
const HOP := 0.18 ## m
const WOBBLE := 0.22 ## rad the crowd turns left and right while cheering
const STYLES := ["groove", "pump", "groove_hop", "pump_hop"]
const SHOUTS := ["DANCE OFF!", "DO IT, BOB!", "OHHHHH!", "BATTLE! BATTLE!", "SHUFFLE QUEEN!!", "GET HER, BOB!", "WOOO!", "SHOW US!"]
const MOVE_HUD := ["HUD/MissionLabel", "HUD/PromptLabel", "HUD/StatusLabel", "HUD/CarryLabel"] ## hidden during the battle; the timer stays
const SHOUT_HEIGHT := 1.7 ## lower than a normal bubble (2.05): the battle camera looks down from 2.2 m and cut the tops off
## Disco (step 4). The room's own lights fall to ROOM_DIM and the picture's exposure to DISCO_EXPOSURE (most of the room's brightness is
## global illumination, so dimming the lights alone does little: Level 3's jump scare learned that). Four coloured spots sweep the floor,
## two white ones stay on the dancers, a mirror ball turns under the ceiling.
const ROOM_DIM := 0.2
const DISCO_EXPOSURE := 0.55
const DISCO_COLORS := [Color(1.0, 0.1, 0.8), Color(0.1, 0.9, 1.0), Color(1.0, 0.85, 0.1), Color(0.6, 0.2, 1.0)]
const DISCO_ENERGY := 6.0
const DISCO_HEIGHT := 2.65
const SWEEP := Vector2(1.3, 1.0) ## the ellipse the coloured beams trace on the floor
const WHITE_ENERGY := 3.5 ## 7 whited Bob's face out (first disco screenshot)
const BATTLE_COLOR := Color(1.0, 0.3, 0.85)
const BATTLE_DELAY := 1.6 ## after "DANCE BATTLE!" the first round starts on the next beat
const REMATCH_DELAY := 2.4 ## the winner's worm (4 beats); was 1.8 before the real clips
const WIN_DELAY := 2.4 ## Bob's worm while the crowd cheers and she gives in, before the lights come back (was 2.2)
const GROOVE_SLACK := 0.03 ## s the groove may drift from the heard beat before it is put back
## The factory's one-beat move per arrow lane (left, down, up, right). They follow the SCREEN: the dancers face the battle camera
## three-quarters, so move_left steps to screen left (the asset notes).
const MOVES := ["move_left", "move_down", "move_up", "move_right"]
const STUMBLE := 0.35 ## rad the body tips back on a miss / her fumble
const STUMBLE_SECONDS := 0.4

static var force_stall := -1 ## tests: she waits outside this stall (index 0-19) instead of a random one
static var test_aspect := 0.0 ## tests: the window's width / height to frame for (headless windows are square; the game is 16:9)
static var _beat_stream: AudioStreamWAV

var queen: Node3D
var stall := -1
var spot := Vector3.ZERO
var out := Vector3.BACK ## from her door into the corridor
var boombox: Node3D
var boombox_display: StandardMaterial3D ## this boombox's own copy of M_DisplayCyan (flashes on the beat)
var beat_player: AudioStreamPlayer3D
var notes: Label3D
var challenged := false
var crowd: Array[Node3D] = [] ## every queue Jijio and walker, once the rush starts
var circle_ready := false
var camera: Camera3D
var shouts := 0 ## crowd shout bubbles so far (tests)
var disco_spots: Array[SpotLight3D] = []
var bob_spot_light: SpotLight3D
var queen_spot_light: SpotLight3D
var hud ## dance_hud.gd
var _disco: Node3D ## holds every disco light and the mirror ball
var _ball: MeshInstance3D
var _room_energy := {} ## room light -> its energy before the disco
var _room_exposure := 1.0
var battle ## dance_battle.gd while a battle runs, else null
var rematches := 0
var combo_cheers := 0 ## Stage 7 E1: crowd cheers for a 5x / 10x combo (tests)
var _old_battle ## the previous (lost) battle, kept for one rematch so its numbers stay readable
var _aborted := false
var _stumble := {} ## body -> seconds of stumble left
var use_audio_clock := DisplayServer.get_name() != "headless" ## headless = the dummy audio driver: no playback position
var _loops := 0
var _last_pos := 0.0

var _level: Node
var _dialogue
var _player
var _clock := 0.0 ## seconds since the beat started (the groove and the bounce follow it)
var _yaw := 0.0
var _crowd_info := {} ## body -> {"style", "yaw", "phase", "speed"}
var _rng := RandomNumberGenerator.new()
var _fade: ColorRect
var _hidden: Array = [] ## [node, was_visible]
var _prev_camera: Camera3D
var _next_shout := 0.0
var _focus_start := -1.0 ## song time the camera focus began; -1 = the camera is home
var _focus_hold := 0.0
var _focus_home: Transform3D
var _focus_to: Transform3D


func setup(level: Node) -> void:
	_level = level
	_dialogue = level.dialogue
	_player = level.player
	_rng.seed = 5
	var population = level.population
	stall = force_stall if force_stall >= 0 else population.pick_free_stall()
	var door: Node3D = level.stalls.doors[stall]
	var occupant: Node3D = population.occupants[stall]
	out = Vector3(0.0, 0.0, signf(door.point.z - occupant.global_position.z))
	spot = Vector3(door.point.x, 0.0, door.point.z) + out * SPOT_OUT
	_yaw = atan2(out.x, out.z) # she faces into the corridor, her back to the door
	queen = population.spawn_walker(spot, _yaw)
	population.walkers.erase(queen) # nobody else steers her; walkers pass through her (layer 2), Bob does not
	queen.name = "ShuffleQueen"
	queen.state = queen.State.DANCE
	queen.priority = 1.0 # the stall doors beside her won the E prompt at 1.25 m (first screenshot; test_level5_setup)
	Cutters._tint(queen, QUEEN_COLOR)
	_add_groove(queen.anim())
	queen.anim().play("dance/groove")
	_build_boombox()
	_build_notes()


## E on her is allowed once the finesse talk is done (find_dancer.gd).
func enable_talk() -> void:
	queen.set_interaction("E  talk to %s" % QUEEN_NAME, _on_talk)


func is_tinted(body: Node3D, color: Color) -> bool:
	return Cutters.is_tinted(body, color)


func _on_talk(player: Node3D) -> void:
	if challenged:
		return
	_dialogue.begin(queen, player)
	await _dialogue.choose(queen, "Hey! Can't you see I'm WAITING? This stall is mine next.",
			["Please, I really, really need to go!", "Let me go first. I was here before you.", "Nice moves... for a beginner."], QUEEN_NAME)
	await _dialogue.say(queen, "You want my turn? Then DANCE for it!", false, QUEEN_NAME)
	_dialogue.end(queen, player)
	queen.clear_interaction()
	challenged = true
	challenged_bob.emit()
	_rush()


func style_of(body: Node3D) -> String:
	return _crowd_info.get(body, {}).get("style", "")


## Everyone runs at Bob and her, shouting; she calls it; fade; the ring in the waiting room.
func _rush() -> void:
	_player.busy = true
	_player.velocity = Vector3.ZERO
	var population = _level.population
	if population.walker_manager:
		population.walker_manager.stop_all() # no more routes, taps off, no small talk
	crowd.clear()
	for npc: Node3D in population.queue + population.walkers:
		if is_instance_valid(npc):
			crowd.append(npc)
	var bob_at: Vector3 = _player.global_position
	for npc in crowd:
		npc.clear_interaction()
		npc.talking = false
		_crowd_info[npc] = {"speed": npc.walk_speed}
		npc.walk_speed = RUN_SPEED
		var a := _rng.randf() * TAU
		npc.go_to(bob_at + Vector3(cos(a), 0.0, sin(a)) * 1.2)
	for k in 4:
		get_tree().create_timer(0.25 + 0.45 * k, false).timeout.connect(_shout)
	get_tree().create_timer(1.1, false).timeout.connect(func() -> void:
		if is_instance_valid(queen):
			_dialogue.bubble(queen, "Not here! WAITING ROOM, everybody!", 1.4, Dialogue.BUBBLE_HEIGHT, QUEEN_NAME))
	await get_tree().create_timer(RUSH_SECONDS, false).timeout
	if not is_inside_tree() or _aborted:
		return
	await _fade_to(1.0)
	if _aborted:
		_fade.color.a = 0.0
		return
	_form_circle()
	await _fade_to(0.0)
	await get_tree().create_timer(BATTLE_DELAY, false).timeout
	if not _aborted:
		_start_battle()


## The song clock: seconds since the beat started, as HEARD. With real audio it is read from the boombox itself (its playback position,
## unwrapped over the loops, minus the sound card's delay): a clock counted on physics ticks ran 60-90 ms behind the heard beat in a
## windowed run (it loses the level's loading hitches; tests/probe_dance_sync.gd), as much as the whole PERFECT window. Headless runs
## (tests) have no real audio and use the tick clock.
func song_time() -> float:
	if not _audio_clock():
		return _clock - AudioServer.get_output_latency()
	var pos := beat_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	var loops := _loops
	if pos < _last_pos - _loop_len() * 0.5: # it wrapped since the last physics tick counted the loops
		loops += 1
	return loops * _loop_len() + pos - AudioServer.get_output_latency()


func _audio_clock() -> bool:
	return use_audio_clock and is_instance_valid(beat_player) and beat_player.playing


func _loop_len() -> float:
	return DanceBeat.beat_seconds() * 4.0 * DanceBeat.BARS


## Once per tick: count the loops of the beat (song_time() unwraps with it).
func _count_loops() -> void:
	if not _audio_clock():
		return
	var pos := beat_player.get_playback_position() + AudioServer.get_time_since_last_mix()
	if pos < _last_pos - _loop_len() * 0.5:
		_loops += 1
	_last_pos = pos


func _start_battle() -> void:
	if is_instance_valid(_old_battle):
		_old_battle.queue_free()
	_old_battle = battle
	if _old_battle:
		_old_battle.set_physics_process(false)
		_old_battle.set_process_input(false)
	battle = Battle.new()
	battle.name = "Battle"
	add_child(battle)
	var beat := DanceBeat.beat_seconds()
	var at := ceilf((song_time() + 0.3) / beat) * beat
	battle.start(self, at, 7 + rematches)
	battle.ended.connect(_on_battle_ended)
	battle.judged.connect(func(lane: int, result: String) -> void:
		if is_instance_valid(hud):
			hud.on_judged(lane, result)
		# Stage 7 E1: the crowd cheers at a 5x and a 10x combo (with the HUD's confetti)
		if result in hud.HIT_RESULTS and battle.combo in hud.CONFETTI_AT:
			combo_cheers += 1
			for k in 2:
				_shout())
	hud.battle = battle
	_player.anim().play("dance/groove", 0.2)
	queen.anim().play("dance/groove", 0.2) # a rematch: out of her victory pose


## Bob's arrow: hit = that arrow's move, then back to the groove; miss = a stumble.
func on_bob_move(lane: int, ok: bool) -> void:
	_move(_player, _player.anim(), lane, ok)


func on_queen_move(lane: int, ok: bool) -> void:
	_move(queen, queen.anim(), lane, ok)


## Rounds 2-3 (dance_battle.gd POWER): the round's power move, she at the end of her turn, Bob at the end of his; then the groove.
func on_power_move(bob: bool, clip: String) -> void:
	var body: Node3D = _player if bob else queen
	if not is_instance_valid(body):
		return
	_restart(_player.anim() if bob else queen.anim(), "dance/" + clip)


func _move(body: Node3D, ap: AnimationPlayer, lane: int, ok: bool) -> void:
	if not is_instance_valid(body):
		return
	if ok:
		_restart(ap, "dance/move%d" % lane)
	else:
		_stumble[body] = STUMBLE_SECONDS


## Play `clip` from its first frame, then the groove. A plain play() does not restart a clip that is already playing, so the same arrow
## twice in a row showed no second move (2 of 42 hits, test_dance_clips).
func _restart(ap: AnimationPlayer, clip: String) -> void:
	ap.clear_queue()
	ap.play(clip, 0.05)
	ap.seek(0.0, true)
	ap.queue("dance/groove")


## Again right before drawing: the AnimationPlayer switches to the queued groove in its own step, after _physics_process, and the
## groove then started at frame 0, up to a beat off, for one frame (test_dance_clips).
func _process(_delta: float) -> void:
	_pulse_boombox()
	if queen != null and is_instance_valid(queen) and queen.state == queen.State.DANCE:
		_lock_groove(queen.anim())
	if battle != null and _player.posing:
		_lock_groove(_player.anim())
	_update_focus()


## On every HEARD beat (the song clock) the boombox thumps: scale 1.00 -> 1.03 and the display's glow jumps, both fading over a quarter beat.
func _pulse_boombox() -> void:
	if boombox == null or not is_instance_valid(beat_player) or not beat_player.playing:
		return
	var phase := fposmod(song_time(), DanceBeat.beat_seconds()) / DanceBeat.beat_seconds()
	var thump := maxf(1.0 - phase * 4.0, 0.0)
	boombox.scale = Vector3.ONE * (1.0 + BOOMBOX_PULSE * thump)
	if boombox_display != null:
		boombox_display.emission_energy_multiplier = DISPLAY_GLOW + DISPLAY_FLASH * thump


## The real groove's knee dips (frames 0 and 18) sit on the heard beat: whenever it plays (after a move, a power move), it is put at the
## song's place in its two-beat loop.
func _lock_groove(ap: AnimationPlayer) -> void:
	if ap == null or ap.current_animation != "dance/groove" or not ap.is_playing():
		return
	var loop := 2.0 * DanceBeat.beat_seconds()
	var want := fposmod(song_time(), loop)
	var off := absf(ap.current_animation_position - want)
	if minf(off, loop - off) > GROOVE_SLACK:
		ap.seek(want, true)


## After each round: the crowd cheers (a burst of shouts), or groans for Bob's lost round.
func on_round_result(bob_won_round: bool) -> void:
	for k in 2:
		_shout()
	if not bob_won_round:
		_dialogue.bubble(queen, "Too slow!", 1.2, SHOUT_HEIGHT, QUEEN_NAME)


func _on_battle_ended(bob_won: bool) -> void:
	if _aborted:
		return
	_finale(bob_won)
	if bob_won:
		hud.announce("YOU WIN!", Color(0.4, 1.0, 0.5), 1.6)
		hud.banner("")
		for npc in crowd:
			if _crowd_info.has(npc):
				_crowd_info[npc]["style"] = "pump_hop" # everybody jumps
		_dialogue.bubble(queen, "OK, OK... you go first!", WIN_DELAY, SHOUT_HEIGHT, QUEEN_NAME)
		await get_tree().create_timer(WIN_DELAY, false).timeout
		if _aborted:
			return
		_end_battle()
		battle_won.emit()
	else:
		hud.announce("SHE WINS!", Color(1.0, 0.3, 0.6), 1.0)
		_level.bob_shat() # Stage 6d: every loss, the lost battle too (the rematch follows as before)
		_dialogue.bubble(queen, "Ha! AGAIN!", REMATCH_DELAY, SHOUT_HEIGHT, QUEEN_NAME)
		await get_tree().create_timer(REMATCH_DELAY, false).timeout
		if _aborted:
			return
		rematches += 1
		_start_battle()


## The battle's winner does the worm (the finale, owner "O = rounds"), then holds `victory`; the loser plays `defeat`. When SHE wins, the
## rematch starts right after her worm (REMATCH_DELAY), so her `victory` is cut: holding it would cost 1.5 s more of the clock per loss.
func _finale(bob_won: bool) -> void:
	var win: AnimationPlayer = _player.anim() if bob_won else queen.anim()
	var lose: AnimationPlayer = queen.anim() if bob_won else _player.anim()
	win.clear_queue()
	win.play("dance/worm", 0.05)
	win.queue("dance/victory")
	lose.clear_queue()
	lose.play("dance/defeat", 0.1)


## Bob won: lights, camera and HUD back, Bob free; the queue walks back to its spots, the walkers and she stay in the room; the beat fades.
func _end_battle() -> void:
	circle_ready = false
	_disco_off()
	_restore_view()
	if is_instance_valid(hud):
		hud.queue_free()
	hud = null
	for npc in crowd:
		if not is_instance_valid(npc):
			continue
		var m: Node3D = npc.get_node("Model")
		m.position = Vector3.ZERO
		m.rotation.x = 0.0
		m.rotation.z = 0.0
		if npc in _level.population.queue:
			npc.queue_at(npc.home)
		else:
			npc.state = npc.State.IDLE
	queen.state = queen.State.IDLE
	queen.get_node("Model").position = Vector3.ZERO
	queen.get_node("Model").rotation = Vector3(0.0, queen.get_yaw(), 0.0)
	Sfx.fade_out(beat_player, 1.5)
	if is_instance_valid(battle):
		battle.set_physics_process(false)
		battle.set_process_input(false)


## Turn start (dance_battle.gd `_on_phase`): the camera glides in on the dancer (`bob` true = Bob), holds, and is back home
## FOCUS_MARGIN s before the turn's `seconds` are up.
func camera_focus(bob: bool, seconds: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(queen) or not is_instance_valid(_player):
		return
	var home := Transform3D(Basis(), CAM_POS).looking_at(CAM_LOOK, Vector3.UP)
	camera.global_transform = home
	var dancer: Node3D = _player if bob else queen
	var partner: Node3D = queen if bob else _player
	var cam_at := FOCUS_SPOT * Vector3(1.0, 1.0, 1.0 if bob else -1.0)
	var chest := Vector3.UP * 0.7 # the dancers are small: the head bone sits at about 0.82 m
	var aim := (partner.global_position + chest).lerp(dancer.global_position + chest, FOCUS_AIM)
	var focus := Transform3D(Basis(), cam_at).looking_at(aim, Vector3.UP)
	# Frame the pair in the free part of the screen, right of the arrow lanes: turn so the middle of the two dancers lands in the middle
	# of that part (the first screenshot had Bob half under the lanes on her turn).
	var aspect := frame_aspect()
	var free_mid := DanceHud.lanes_right() / maxf(1152.0, 648.0 * aspect) # -1..1 across the screen; the free part's middle
	var target := atan(free_mid * tan(deg_to_rad(camera.fov) / 2.0) * aspect)
	var mid := 0.0
	for body: Node3D in [dancer, partner]:
		var local := focus.affine_inverse() * (body.global_position + chest)
		mid += atan2(local.x, -local.z) / 2.0
	focus.basis = Basis(Vector3.UP, target - mid) * focus.basis
	_focus_home = home
	_focus_to = focus
	_focus_hold = clampf(seconds - FOCUS_IN - FOCUS_OUT - FOCUS_MARGIN, 0.0, FOCUS_HOLD_MAX)
	_focus_start = song_time()


## The glide, on the SONG clock like the turns themselves (a Tween on frame time was still gliding back in the next turn at 9-13 FPS).
func _update_focus() -> void:
	if _focus_start < 0.0 or not is_instance_valid(camera):
		return
	var t := song_time() - _focus_start
	var w := 0.0
	if t < FOCUS_IN:
		w = 0.5 - 0.5 * cos(PI * maxf(t, 0.0) / FOCUS_IN)
	elif t < FOCUS_IN + _focus_hold:
		w = 1.0
	elif t < FOCUS_IN + _focus_hold + FOCUS_OUT:
		w = 0.5 + 0.5 * cos(PI * (t - FOCUS_IN - _focus_hold) / FOCUS_OUT)
	else:
		_focus_start = -1.0
	camera.global_transform = _focus_home.interpolate_with(_focus_to, w)


## The window's width / height (tests: headless windows are square, so they set `test_aspect` to the game's 16:9).
func frame_aspect() -> float:
	if test_aspect > 0.0:
		return test_aspect
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)


## Bob and his camera and the level's HUD back (after a win, a timeout, a reset).
func _restore_view() -> void:
	_focus_start = -1.0
	for pair: Array in _hidden:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	_hidden.clear()
	if is_instance_valid(_player):
		_player.posing = false
		_player.busy = false
		var m: Node3D = _player.model()
		m.rotation.x = 0.0
		m.rotation.z = 0.0
	if is_instance_valid(_prev_camera):
		_prev_camera.make_current()


func _shout() -> void:
	if crowd.is_empty():
		return
	var npc: Node3D = crowd[_rng.randi() % crowd.size()]
	if battle != null and is_instance_valid(camera): # shouts over the arrow lanes hid the arrows (screenshot): pick someone right of them
		var right: Array = crowd.filter(func(n: Node3D) -> bool:
			return is_instance_valid(n) and camera.unproject_position(n.global_position + Vector3.UP * SHOUT_HEIGHT).x > DanceHud.lanes_right() + 60.0)
		if right.is_empty():
			return
		npc = right[_rng.randi() % right.size()]
	if is_instance_valid(npc):
		_dialogue.bubble(npc, SHOUTS[_rng.randi() % SHOUTS.size()], 1.6, SHOUT_HEIGHT if circle_ready else Dialogue.BUBBLE_HEIGHT)
		shouts += 1


func _form_circle() -> void:
	var n := crowd.size()
	for i in n:
		var npc: Node3D = crowd[i]
		if not is_instance_valid(npc):
			continue
		var t := RING_GAP + (TAU - 2.0 * RING_GAP) * (i + 0.5) / n
		var pos := ROOM_CENTER + Vector3(RING.x * cos(t), 0.0, RING.y * sin(t))
		npc.stop_walking()
		npc.velocity = Vector3.ZERO
		npc.walk_speed = _crowd_info[npc]["speed"]
		npc.global_position = pos
		npc.state = npc.State.DANCE
		var m: Node3D = npc.get_node("Model")
		m.rotation = Vector3.ZERO
		m.position = Vector3.ZERO
		var yaw := atan2(ROOM_CENTER.x - pos.x, ROOM_CENTER.z - pos.z)
		npc.face_yaw(yaw)
		var style: String = STYLES[i % STYLES.size()]
		_crowd_info[npc] = {"style": style, "yaw": yaw, "phase": _rng.randf() * TAU, "speed": npc.walk_speed}
		var npc_ap: AnimationPlayer = npc.anim()
		_add_groove(npc_ap)
		npc_ap.play("dance/pump" if style.begins_with("pump") else "dance/groove")
		npc_ap.seek(_rng.randf() * npc_ap.current_animation_length, true)
	queen.global_position = QUEEN_SPOT
	queen.state = queen.State.DANCE
	notes.visible = false # they were for finding her; in the ring they sat on top of the timer (screenshot)
	queen.anim().play("dance/groove")
	queen.face_yaw(_yaw_toward(QUEEN_SPOT, BOB_SPOT, 0.9))
	_player.global_position = Vector3(BOB_SPOT.x, _player.global_position.y, BOB_SPOT.z)
	_player.velocity = Vector3.ZERO
	_player.posing = true
	var bob_dir := BOB_SPOT.direction_to(QUEEN_SPOT) + Vector3(0.9, 0.0, 0.0)
	_player.face_direction(bob_dir.normalized())
	var ap: AnimationPlayer = _player.anim()
	_add_groove(ap) # Bob dances too: the groove and the four arrow moves
	Pose.ensure_loop(ap, "idle")
	ap.play("idle", 0.2)
	ap.speed_scale = 1.0
	boombox.global_position = ROOM_CENTER + Vector3(-1.25, 0.0, 0.0)
	boombox.rotation.y = PI / 2.0 # speakers toward the camera
	_prev_camera = _player.get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "BattleCamera"
	camera.fov = CAM_FOV
	add_child(camera)
	camera.global_position = CAM_POS
	camera.look_at(CAM_LOOK, Vector3.UP)
	camera.make_current()
	_hidden.clear()
	for path: String in MOVE_HUD:
		var node := _level.get_node_or_null(path) as CanvasItem
		if node:
			_hidden.append([node, node.visible])
			node.visible = false
	_disco_on()
	if hud == null:
		hud = DanceHud.new()
		add_child(hud)
	hud.announce("DANCE BATTLE!", BATTLE_COLOR, 1.4)
	_next_shout = 0.8
	circle_ready = true
	circle_formed.emit()


func is_disco_light(l: Light3D) -> bool:
	return _disco != null and _disco.is_ancestor_of(l)


func room_energy(l: Light3D) -> float:
	return _room_energy.get(l, l.light_energy)


func room_exposure() -> float:
	return _room_exposure


## Instant (the screen is black while this runs): the fade-in reveals the disco.
func _disco_on() -> void:
	beat_as_music(true)
	_room_energy.clear()
	for node in _level.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		_room_energy[l] = l.light_energy
		l.light_energy *= ROOM_DIM
	var env := _environment()
	if env:
		_room_exposure = env.tonemap_exposure
		env.tonemap_exposure = DISCO_EXPOSURE
	_disco = Node3D.new()
	_disco.name = "Disco"
	add_child(_disco)
	disco_spots.clear()
	for k in DISCO_COLORS.size():
		var s := _spot(DISCO_COLORS[k], DISCO_ENERGY, 20.0)
		s.position = ROOM_CENTER + Vector3(1.2 if k % 2 == 0 else -1.2, DISCO_HEIGHT, 0.9 if k < 2 else -0.9)
		disco_spots.append(s)
	bob_spot_light = _spot(Color(1.0, 1.0, 0.95), WHITE_ENERGY, 16.0)
	bob_spot_light.position = Vector3(BOB_SPOT.x + 1.0, DISCO_HEIGHT, BOB_SPOT.z + 0.2)
	queen_spot_light = _spot(Color(1.0, 1.0, 0.95), WHITE_ENERGY, 16.0)
	queen_spot_light.position = Vector3(QUEEN_SPOT.x + 1.0, DISCO_HEIGHT, QUEEN_SPOT.z - 0.2)
	bob_spot_light.look_at(BOB_SPOT + Vector3.UP * 0.8, Vector3.UP)
	queen_spot_light.look_at(QUEEN_SPOT + Vector3.UP * 0.8, Vector3.UP)
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	_ball.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.metallic = 1.0
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.6
	_ball.material_override = mat
	_ball.position = ROOM_CENTER + Vector3(0.0, 2.45, 0.0)
	_disco.add_child(_ball)
	_sweep(0.0)


## The beat as battle music (true) or as her boombox in the room (false), see BATTLE_BEAT_DB.
func beat_as_music(on: bool) -> void:
	if not is_instance_valid(beat_player):
		return
	beat_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED if on else AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	beat_player.attenuation_filter_db = 0.0 if on else BEAT_FILTER_DB
	beat_player.volume_db = BATTLE_BEAT_DB if on else BEAT_DB
	# the crowd's spoken shouts sit UNDER the music: at the normal bubble level two of them on a drum hit reached 0 dB (probe_level5_sound:
	# 0 dB in 2 of 5 recorded runs; with the shout voices off, -3.0 dB in 3 of 3)
	_dialogue.bubble_voice_db = BATTLE_SHOUT_DB if on else Dialogue.BUBBLE_VOICE_DB


## The battle's disco is on (ambience.gd stays quiet then: the beat is the music).
func is_disco() -> bool:
	return _disco != null and _disco.visible


func _disco_off() -> void:
	beat_as_music(false)
	for l in _room_energy:
		if is_instance_valid(l):
			l.light_energy = _room_energy[l]
	var env := _environment()
	if env and _disco != null:
		env.tonemap_exposure = _room_exposure
	if _disco != null:
		for node in _disco.find_children("*", "Light3D", true, false):
			(node as Light3D).light_energy = 0.0
			(node as Light3D).visible = false
		_disco.visible = false


func _spot(color: Color, energy: float, angle: float) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_angle = angle
	s.spot_range = 5.0
	s.spot_attenuation = 0.5
	s.shadow_enabled = false
	_disco.add_child(s)
	return s


## The coloured beams trace an ellipse on the floor, each a quarter turn apart, one lap every 8 beats.
func _sweep(beats: float) -> void:
	for k in disco_spots.size():
		var a := TAU * (beats / 8.0 + float(k) / disco_spots.size()) * (1.0 if k % 2 == 0 else -1.0)
		disco_spots[k].look_at(ROOM_CENTER + Vector3(SWEEP.x * cos(a), 0.0, SWEEP.y * sin(a)), Vector3.UP)
	if _ball:
		_ball.rotation.y = beats * 0.5


func _environment() -> Environment:
	var world := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	return world.environment if world != null else null


## The yaw that faces from `from` toward `to`, turned `toward_camera` of the way to the camera side (+X) so faces show.
func _yaw_toward(from: Vector3, to: Vector3, toward_camera: float) -> float:
	var d := from.direction_to(to) + Vector3(toward_camera, 0.0, 0.0)
	return atan2(d.x, d.z)


func _fade_to(alpha: float) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 9
		add_child(layer)
		_fade = ColorRect.new()
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.color = Color(0.0, 0.0, 0.0, 0.0)
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
	await tw.finished


## Level timeout or reset: Bob and his camera back, the HUD back, the crowd free for the kick.
func abort() -> void:
	_aborted = true
	circle_ready = false
	_disco_off()
	if is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if is_instance_valid(battle):
		battle.queue_free()
	battle = null
	_restore_view()
	if _fade:
		_fade.color.a = 0.0


func _physics_process(delta: float) -> void:
	if queen == null or not is_instance_valid(queen):
		return
	_clock += delta
	_count_loops()
	var beats := song_time() / DanceBeat.beat_seconds() # the bounce and the crowd follow the heard beat too
	if queen.state == queen.State.DANCE:
		_lock_groove(queen.anim()) # the real groove dips on the beat by itself (the stand-in needed a code bounce here)
	if battle != null and _player.posing:
		_lock_groove(_player.anim())
	if notes:
		notes.position.y = NOTES_HEIGHT + 0.08 * absf(sin(PI * beats))
		notes.rotation.z = 0.15 * sin(PI * beats * 0.5)
	if circle_ready:
		_crowd_moves(beats, delta)
		_sweep(beats)
	for body in _stumble.keys():
		var left: float = _stumble[body] - delta
		if not is_instance_valid(body):
			_stumble.erase(body)
			continue
		var m: Node3D = body.get_node("Model")
		m.rotation.x = -STUMBLE * sin(PI * clampf(1.0 - left / STUMBLE_SECONDS, 0.0, 1.0))
		if left <= 0.0:
			m.rotation.x = 0.0
			_stumble.erase(body)
		else:
			_stumble[body] = left


## Cheering on the beat: hoppers hop on every 2nd beat (their own offset), everyone dips and turns a little left and right.
func _crowd_moves(beats: float, delta: float) -> void:
	for npc: Node3D in crowd:
		if not is_instance_valid(npc) or npc.state != npc.State.DANCE:
			continue
		var info: Dictionary = _crowd_info[npc]
		var m: Node3D = npc.get_node("Model")
		var phase: float = info["phase"]
		# the real groove dips by itself; the stand-in fist pump still gets the code dip
		var y := -BOUNCE * absf(sin(PI * beats)) if String(info["style"]).begins_with("pump") else 0.0
		if String(info["style"]).ends_with("hop"):
			var own := beats + phase / PI # each hopper on its own beat
			if int(floor(own)) % 2 == 0:
				y = HOP * sin(PI * fposmod(own, 1.0))
		m.position.y = y
		m.rotation.z = SWAY * 0.6 * sin(PI * beats + phase)
		npc.face_yaw(float(info["yaw"]) + WOBBLE * sin(PI * beats * 0.25 + phase))
	_next_shout -= delta
	if _next_shout <= 0.0:
		_shout()
		_next_shout = _rng.randf_range(1.0, 2.0)


## The "dance" library: the factory's REAL dance clips (republished 2026-09-25, same names on Bob and Jijio; 100 BPM, in place, all
## chaining through one stance): groove (looped here: the glb's loop flag does not survive export), move0..3 = move_left / move_down /
## move_up / move_right (the lanes' order), flare, headspin, worm, victory, defeat. Only `pump` (the crowd's fist pump) is still a stand-in
## cut from `punch` (guard -> fist out -> guard over one beat) until the crowd clips come.
func _add_groove(ap: AnimationPlayer) -> void:
	if ap.has_animation("dance/groove"):
		return
	var lib := AnimationLibrary.new()
	var groove: Animation = ap.get_animation("groove").duplicate()
	groove.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("groove", groove)
	lib.add_animation("pump", Fight._slice(ap.get_animation(PUMP[0]), PUMP[1], _spread(PUMP[1].size(), 1.0)))
	for lane in MOVES.size():
		lib.add_animation("move%d" % lane, ap.get_animation(MOVES[lane]).duplicate())
	for clip: String in ["flare", "headspin", "worm", "victory", "defeat"]:
		lib.add_animation(clip, ap.get_animation(clip).duplicate())
	ap.add_animation_library("dance", lib)


## `count` key times spread evenly over `beats` beats.
static func _spread(count: int, beats: float) -> Array:
	var times: Array = []
	for k in count:
		times.append(DanceBeat.beat_seconds() * beats * k / (count - 1))
	return times


## The factory boombox (boombox-prop.glb: origin = floor centre, speakers +Z, 0.50 x 0.30 x 0.18 m) on the floor beside her (no
## collision), playing the beat loop. Owner C1 (2026-09-27): it pulses 3 % and its cyan display flashes on every beat (_pulse_boombox).
func _build_boombox() -> void:
	boombox = BoomboxProp.instantiate()
	boombox.name = "Boombox"
	add_child(boombox)
	var side := out.cross(Vector3.UP).normalized()
	boombox.global_position = spot - out * 0.25 + side * 0.55
	boombox.rotation.y = _yaw
	var mesh: MeshInstance3D = boombox.find_child("SM_Boombox", true, false)
	for s in mesh.mesh.get_surface_count():
		var mat := mesh.mesh.surface_get_material(s)
		if mat != null and mat.resource_name == "M_DisplayCyan":
			boombox_display = (mat as StandardMaterial3D).duplicate()
			mesh.set_surface_override_material(s, boombox_display)
	if _beat_stream == null:
		_beat_stream = DanceBeat.build()
	beat_player = AudioStreamPlayer3D.new()
	beat_player.stream = _beat_stream
	beat_player.volume_db = BEAT_DB
	beat_player.unit_size = 3.0
	beat_player.max_db = Sfx.MAX_3D_DB # the default +3 dB touched 0 dB in the mix when Bob walked up to her (probe_level5_sound)
	beat_player.max_distance = 30.0
	beat_player.position.y = 0.2
	boombox.add_child(beat_player)
	beat_player.play()
	_clock = 0.0


## Music notes floating over her head, bouncing on the beat: from down the corridor Bob's own head hid her (first screenshot), the
## notes sit above it. NOT shown through walls: she is found by following the sound, then seen.
func _build_notes() -> void:
	notes = Label3D.new()
	notes.name = "Notes"
	notes.text = NOTES_TEXT
	notes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	notes.pixel_size = 0.006
	notes.font_size = 72
	notes.outline_size = 16
	notes.modulate = QUEEN_COLOR.lightened(0.25)
	notes.outline_modulate = Color(0.15, 0.0, 0.1)
	notes.position = Vector3(0.0, NOTES_HEIGHT, 0.0)
	queen.add_child(notes)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat
