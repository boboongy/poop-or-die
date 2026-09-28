extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): the Stage 6b start dialogue of Levels 1, 4 and 5 in the real flow (walkers on,
## Bob's own camera): Bob's line, the Jijio's answer, and 1.5 s after GO (the mission's bubble from the same Jijio).
## Run: "<console exe>" --path . --script tests/shot_start_dialogue.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


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


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	for n in [1, 4, 5]:
		Progress.level = n
		var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
		await process_frame
		get_root().add_child(lvl)
		current_scene = lvl
		await _pause(1.5)
		await _snap("l%d_1_bob" % n)
		await _key(KEY_E)
		await _pause(1.5)
		await _snap("l%d_2_jijio" % n)
		await _key(KEY_E)
		await _pause(1.5)
		await _snap("l%d_3_after_go" % n)
		lvl.queue_free()
		await _pause(0.5)
	quit()
