extends SceneTree
## PROBE (windowed, real audio; not run by run.sh). SPEC Round 2 Stage 2: "the soundscape measured for clipping". Records what the game
## actually outputs (the Master bus, AudioEffectRecord) in the real flow, walkers on: (a) 25 s in the waiting room at the back of the queue
## (hum, chatter, random stall sounds, walkers' steps); (b) a spoken conversation (Level 1: the tissue asker, Bob's spoken reply);
## (c) Level 3's intro (the big fart, the crowd's shouts, Bob's lines). Measure afterwards with ffmpeg volumedetect (mean / max dB).
## Run: "<console exe>" --path . --script tests/probe_soundscape.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
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


func _record(name: String, seconds: float, keys: Array = [], gap := 0.0) -> void:
	rec.set_recording_active(true)
	var start := Time.get_ticks_msec()
	for k: int in keys:
		await _pause(gap)
		await _key(k)
	await _pause(maxf(seconds - (Time.get_ticks_msec() - start) / 1000.0, 0.0))
	rec.set_recording_active(false)
	rec.get_recording().save_to_wav("%s/%s.wav" % [out, name])
	print("REC ", name)


func _level(n: int) -> Node:
	Progress.level = n
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	get_root().add_child(lvl)
	current_scene = lvl
	return lvl


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	Walkers.enabled = true
	await process_frame
	var lvl := _level(1)
	await _pause(2.0)
	lvl._time_left = 1000.0
	await _record("a_waiting_room_25s", 25.0)
	var amb: Node = lvl.get_node("Ambience")
	print("INFO random sounds during the recording: ", amb.heard.map(func(e: Dictionary) -> String: return e["event"]))
	# (b) the tissue asker (the Jijio ahead of Bob): her lines and Bob's spoken reply
	lvl.population.queue[4].interact(lvl.player)
	await _record("b_talk", 14.0, [KEY_E, KEY_E, KEY_1, KEY_E], 2.6)
	lvl.queue_free()
	await _pause(0.5)
	var l3 := _level(2) # the ghost's fart intro = hide and seek (Level 2 since Stage 6b)
	await _record("c_level3_fart_intro", 10.0, [KEY_E], 5.0)
	l3.queue_free()
	await _pause(0.3)
	quit()
