extends SceneTree
## PROBE (windowed, real audio; not in run.sh). Owner 2026-09-25: "footsteps don't have sound". Records the game's real output (Master bus,
## AudioEffectRecord) while Bob stands still (control) and while he walks, then sprints, and counts the "step" events fired.
## Measure the WAVs afterwards with ffmpeg volumedetect. Run: "<console exe>" --path . --script tests/probe_footsteps_sound.gd -- out=<folder>
const Sfx := preload("res://scripts/sfx.gd")
const Walkers := preload("res://scripts/walkers.gd")
const Progress := preload("res://scripts/progress.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _record(name: String, seconds: float) -> void:
	var before := Sfx.count("step")
	rec.set_recording_active(true)
	await _pause(seconds)
	rec.set_recording_active(false)
	var wav: AudioStreamWAV = rec.get_recording()
	wav.save_to_wav("%s/%s.wav" % [out, name])
	print("REC %s: %d step events" % [name, Sfx.count("step") - before])


func _hold(action_key: int, on: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = action_key as Key
	ev.keycode = action_key as Key
	ev.pressed = on
	Input.parse_input_event(ev)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	Walkers.enabled = false
	Progress.level = 1
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(2.0)
	lvl._time_left = 100000.0
	var p: Node3D = lvl.get_node("Player")
	print("INFO Bob at %s, camera %s" % [p.global_position, get_root().get_camera_3d().global_position])
	await _record("still", 2.0)
	# the same events fired by hand at Bob's feet, standing: the level of ONE step vs one door in the real mix
	for ev in ["step", "door_open", "kick", "knock", "slip", "punch_hit", "heavy_hit", "block_hit", "ko", "ui_choose", "ui_done"]:
		rec.set_recording_active(true)
		for i in 5:
			if ev.begins_with("ui_"): Sfx.play_ui(p, ev)
			else: Sfx.play_at(p, ev, p.global_position)
			await _pause(0.3)
		rec.set_recording_active(false)
		rec.get_recording().save_to_wav("%s/fired_%s.wav" % [out, ev])
		print("REC fired_%s" % ev)
	# walk out of the queue: turn toward the toilet doorway (+X) is not needed: W walks where the camera looks
	_hold(KEY_W, true)
	await _record("walk", 3.0)
	_hold(KEY_SHIFT, true)
	await _record("sprint", 2.0)
	_hold(KEY_SHIFT, false)
	_hold(KEY_W, false)
	print("INFO Bob ended at %s; played (newest last): %s" % [p.global_position, Sfx.played.slice(-8)])
	quit()
