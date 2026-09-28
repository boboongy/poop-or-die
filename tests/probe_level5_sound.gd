extends SceneTree
## PROBE (windowed, real audio; not run by run.sh). Owner 2026-09-25: "I could hear sounds walking near the pink Jijio, but during the
## game [the battle] I didn't hear anything, maybe my volume is too soft". Records what the game actually outputs (the Master bus, through
## an AudioEffectRecord) into WAV files: walking toward SHUFFLE QUEEN (footsteps + her boombox), her turn in the battle, Bob's turn.
## Measure them afterwards with ffmpeg volumedetect (mean / max dB).
## Run: "<console exe>" --path . --script tests/probe_level5_sound.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord
var _t0 := 0
var _seen := 0
var _dlg: Node
var _voices := 0
const Sfx := preload("res://scripts/sfx.gd")


## Waits, and prints every sound that starts while a segment records ("SND <s into the segment> <event>", as probe_flood_sound):
## Stage 6's first recordings peaked at -0.2 dB here and the probe could not name the cause.
func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		while _seen < Sfx.played.size():
			if rec != null and rec.is_recording_active():
				print("SND %.2f s %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, Sfx.played[_seen]])
			_seen += 1
		# speech-bubble voices (dialogue.gd, not Sfx): the crowd's shouts and hers
		if _dlg != null and rec != null and rec.is_recording_active() and int(_dlg._bubble_voices) > _voices:
			print("SND %.2f s bubble voice (%d playing)" % [(Time.get_ticks_msec() - _t0) / 1000.0, int(_dlg._bubble_voices)])
		if _dlg != null:
			_voices = int(_dlg._bubble_voices)


func _until(pred: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not pred.call() and Time.get_ticks_msec() < end:
		await process_frame


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _record(name: String, seconds: float) -> void:
	rec.set_recording_active(true)
	_t0 = Time.get_ticks_msec()
	_seen = Sfx.played.size()
	print("REC start ", name)
	await _pause(seconds)
	rec.set_recording_active(false)
	var wav: AudioStreamWAV = rec.get_recording()
	wav.save_to_wav("%s/%s.wav" % [out, name])
	print("REC ", name)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	print("INFO master bus volume %.1f dB, muted %s; output latency %.3f s" % [AudioServer.get_bus_volume_db(0), AudioServer.is_bus_mute(0), AudioServer.get_output_latency()])
	Walkers.enabled = true
	Progress.level = 5
	Dance.force_stall = 5
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	_dlg = lvl.get_node("Dialogue")
	await _pause(2.0)
	var p: Node3D = lvl.player
	var d: Node = lvl.dance
	lvl._time_left = 1000.0
	for k in [KEY_E, KEY_1, KEY_E, KEY_E]:
		await _key(k)
		await _pause(0.3)
	var q: Vector3 = d.queen.global_position
	# walking up to her along the corridor: footsteps + the boombox getting louder
	p.global_position = Vector3(q.x - 4.0, p.global_position.y, q.z + 0.35)
	p.face_direction(Vector3(1.0, 0.0, 0.0))
	await _pause(0.5)
	Input.action_press("move_forward")
	await _record("a_walk_to_her", 2.5)
	Input.action_release("move_forward")
	p.global_position = Vector3(q.x - 1.0, p.global_position.y, q.z + 0.35)
	p.face_direction(Vector3(1.0, 0.0, -0.35).normalized())
	await _pause(0.6)
	for k in [KEY_E, KEY_2, KEY_E]:
		await _key(k)
		await _pause(0.3)
	await _until(func() -> bool: return d.battle != null and d.battle.phase == "queen", 12.0)
	print("INFO battle camera %.2f m from the boombox; beat playing %s, volume %.1f dB, unit size %.1f" % [get_root().get_camera_3d().global_position.distance_to(d.boombox.global_position),
			d.beat_player.playing, d.beat_player.volume_db, d.beat_player.unit_size])
	await _record("b_battle_her_turn", 3.0)
	await _until(func() -> bool: return d.battle.phase == "bob", 8.0)
	await _record("c_battle_bob_turn", 3.0)
	quit()
