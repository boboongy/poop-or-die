extends SceneTree
## PROBE (windowed, real audio; not run by run.sh). SPEC Round 2 Stage 3: "measure the mix in a windowed recording when the water sounds
## are in (tools/peaks.py, several runs)". Records the Master bus BEFORE the limiter (the recorder is added first; the level adds its
## limiter after it) in the real Level 2 flow, walkers on:
## (a) the intro (voices, the blast from the stall, the scream, the crowd); (b) 15 s of the rampage and the rising water in corridor A
## by the running sinks; (c) 10 s swimming in deep water; (d) a dive at the toilet: plunger squelches, the glug, dive/surface, the muffle;
## (e) the taps off, the plug and 13 s of the drain's gurgle.
## Run: "<console exe>" --path . --script tests/probe_flood_sound.gd -- out=<folder>   then  python tools/peaks.py <wav> -6
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord
var lvl: Node


var _t0 := 0
var _seen := 0


## Waits, and prints every sound that starts while a segment records ("SND <s into the segment> <event>"), to name a peak's cause.
func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		while _seen < Sfx.played.size():
			if rec != null and rec.is_recording_active():
				print("SND %.2f s %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, Sfx.played[_seen]])
			_seen += 1


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _tap(code: int) -> void:
	await _key(code, true)
	await _key(code, false)


func _start(name: String) -> void:
	rec.set_recording_active(true)
	_t0 = Time.get_ticks_msec()
	_seen = Sfx.played.size()
	print("REC start ", name)


func _stop(name: String) -> void:
	rec.set_recording_active(false)
	rec.get_recording().save_to_wav("%s/%s.wav" % [out, name])
	print("REC ", name)


func _place(at: Vector3, face: Vector3) -> void:
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(at.x, maxf(lvl.water.depth - p.FLOAT_DEPTH, 0.05), at.z)
	p.face_direction(face)
	await _pause(0.4)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	await process_frame
	Progress.level = 3 # the flood (Level 3 since Stage 6b)
	lvl = load("res://scenes/level_toilet.tscn").instantiate()
	get_root().add_child(lvl)
	current_scene = lvl
	await _pause(1.5)
	var story: Node3D = lvl.flood_story
	var w: Node3D = lvl.water
	var d = lvl.dialogue
	# (a) the intro
	_start("a_intro")
	while lvl.intro_playing:
		if d._waiting:
			await _pause(2.4)
			await _tap(KEY_E)
		await _pause(0.2)
	await _pause(1.0)
	_stop("a_intro")
	# (b) the rampage and the rising water, standing in corridor A by the sinks
	var mid: int = story.sinks[1]
	await _place(Vector3(story._tap_point(mid).x, 0.0, -0.2), Vector3(1.0, 0.0, 0.0))
	_start("b_rising")
	await _pause(15.0)
	_stop("b_rising")
	# (c) swimming, deep water
	while w.depth < 1.2:
		await _pause(0.2)
	var p: CharacterBody3D = lvl.player
	await _place(Vector3(2.0, 0.0, 0.05), Vector3(1.0, 0.0, 0.0))
	_start("c_swim")
	p.auto_move = Vector3(1.0, 0.0, 0.0)
	await _pause(3.5)
	p.auto_move = Vector3(-1.0, 0.0, 0.0)
	await _pause(3.5)
	p.auto_move = Vector3(1.0, 0.0, 0.0)
	await _pause(3.0)
	p.auto_move = Vector3.ZERO
	_stop("c_swim")
	# (d) the plunger and a dive at the toilet
	var door: Vector3 = story._door_floor
	var o: Vector3 = story._out
	await _place(door + o * 1.4, -o)
	await _tap(KEY_E)
	await _pause(2.0)
	await _place(door - o * 0.25, -o)
	_start("d_dive_plunge")
	await _key(KEY_E, true)
	await _pause(story.PLUNGE_SECONDS + 1.0)
	await _key(KEY_E, false)
	await _pause(2.0)
	_stop("d_dive_plunge")
	# (e) taps off, the plug, the drain
	_start("e_taps_plug_drain")
	for k: int in story.sinks.duplicate():
		await _place(Vector3(story._tap_point(k).x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
		await _tap(KEY_E)
		await _pause(1.8)
	await _place(story.DRAIN_POS + Vector3(0.7, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	await _tap(KEY_E)
	await _pause(14.0)
	_stop("e_taps_plug_drain")
	print("drained ", story.is_drained, " unclogged ", not story.clogged)
	quit()
