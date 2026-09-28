extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Level 5 steps 1-2 from Bob's own camera, walkers on: the start, the finesse
## talk, SHUFFLE QUEEN seen from down the corridor (row 1 and row 2), close up with the E prompt, and her challenge.
## Run: "<console exe>" --path . --script tests/shot_level5_setup.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var p: Node3D


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _until(pred: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not pred.call() and Time.get_ticks_msec() < end:
		await process_frame


func _pause(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _load(stall: int) -> Node:
	Dance.force_stall = stall
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	await _pause(2.0)
	p = lvl.player
	return lvl


func _stand(at: Vector3, look: Vector3) -> void:
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(Vector3(look.x, 0.0, look.z).normalized())
	await _pause(0.6)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	Progress.level = 5
	var lvl := await _load(5) # row 1, stall 6
	var d: Node = lvl.dance
	await _snap("d00_start")
	await _key(KEY_E) # the Jijio ahead of Bob
	await _pause(0.4)
	await _snap("d01_finesse_question")
	await _key(KEY_1)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(0.3)
	await _snap("d02_music_hint")
	await _key(KEY_E)
	await _pause(0.5)
	var q: Vector3 = d.queen.global_position
	await _stand(Vector3(q.x - 4.5, 0.0, 0.2), Vector3(1.0, 0.0, -0.1))
	await _snap("d03_row1_from_4m")
	await _stand(Vector3(q.x - 1.0, 0.0, q.z + 0.35), Vector3(1.0, 0.0, -0.35)) # 1.06 m: inside Bob's 1.3 m reach
	await _snap("d04_row1_close_prompt")
	await _key(KEY_E)
	await _pause(0.4)
	await _snap("d05_her_question")
	await _key(KEY_2)
	await _pause(0.3)
	await _snap("d06_challenge")
	await _key(KEY_E)
	lvl.queue_free()
	await _pause(0.5)
	lvl = await _load(13) # row 2, stall 4: Bob comes round the east end, so he sees her from the east
	d = lvl.dance
	q = d.queen.global_position
	await _stand(Vector3(q.x + 4.5, 0.0, -5.25), Vector3(-1.0, 0.0, 0.1))
	await _snap("d07_row2_from_4m")
	Dance.force_stall = -1
	lvl.queue_free()
	await _pause(0.3)
	quit()
