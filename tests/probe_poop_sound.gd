extends SceneTree
## PROBE (windowed, real audio; not in run.sh). Owner 2026-09-28 (Stage 6b): "I don't hear an explosive poop or fart when pooping",
## although test_toilet_sequence says `poop_blast` fires. Records the game's real output (Master bus, AudioEffectRecord) through the
## whole toilet sequence (E at the stall -> pants_down -> sit -> poop), printing WHICH sounds start when ("SND <s> <event>"), plus a
## control: the same event fired at Bob's feet in the waiting room. Measure the WAVs with `python tools/peaks.py <wav> -40`.
## Run: "<console exe>" --path . --script tests/probe_poop_sound.gd -- out=<folder>
const Sfx := preload("res://scripts/sfx.gd")
const Walkers := preload("res://scripts/walkers.gd")
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord
var _t0 := 0
var _seen := 0


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		_log_new()
		await process_frame


func _log_new() -> void:
	while _seen < Sfx.played.size():
		print("SND %6.2f %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, Sfx.played[_seen]])
		_seen += 1


func _start(name: String) -> void:
	_seen = Sfx.played.size()
	_t0 = Time.get_ticks_msec()
	print("SEGMENT %s" % name)
	rec.set_recording_active(true)


func _stop(name: String) -> void:
	_log_new()
	rec.set_recording_active(false)
	rec.get_recording().save_to_wav("%s/%s.wav" % [out, name])
	print("REC %s.wav" % name)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		ev.keycode = code as Key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	Walkers.enabled = false
	Intro.enabled = false
	Progress.level = 1
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(2.0)
	lvl._time_left = 100000.0
	var p: Node3D = lvl.get_node("Player")
	var pop: Node3D = lvl.get_node("Population")
	var sess = lvl.get_node("ToiletSession")
	var status: Label = lvl.get_node("HUD/StatusLabel")

	# control: the event fired at Bob's feet, standing in the waiting room
	_start("control")
	for i in 2:
		Sfx.play_at(p, "poop_blast", p.global_position)
		await _pause(3.0)
	_stop("control")

	var idx: int = pop.pick_free_stall()
	await pop.reward_release(idx)
	sess.setup(idx)
	await _pause(4.0)
	var f := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + f * 0.9
	p.face_direction(-f)
	await _pause(0.6)
	print("INFO stall %d, Bob %s, camera %s" % [idx, p.global_position, get_root().get_camera_3d().global_position])
	_start("sequence")
	await _key(KEY_E)
	var waited := 0.0
	while not status.text.begins_with("Pooping") and waited < 8.0:
		await _pause(0.05)
		waited += 0.05
	print("INFO pooping from %.2f s; camera %s, listener = camera: %s" % [(Time.get_ticks_msec() - _t0) / 1000.0,
		get_root().get_camera_3d().global_position, get_root().get_camera_3d().name])
	await _pause(sess.poop_seconds + 1.5)
	_stop("sequence")
	print("INFO Master volume %.1f dB, muted %s; buses %d" % [AudioServer.get_bus_volume_db(0), AudioServer.is_bus_mute(0), AudioServer.bus_count])
	quit()
