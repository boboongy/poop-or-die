extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 6b E, a talk through Bob's own camera in the real flow (walkers on, the start
## dialogue on): Level 1's queue Jijio (mid-pan in, first person, mid-pan out, back in third person), then Level 2's ghost (first line, reveal).
## Run: "<console exe>" --path . --script tests/shot_talk_view.gd -- out=<folder>
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
	Walkers.enabled = true
	await process_frame
	var lvl := _level(1)
	await _pause(1.0)
	await _key(KEY_ENTER) # skip the start dialogue (third person, not a talk box)
	await _pause(1.8) # GO!
	await _snap("t1_0_before")
	await _key(KEY_E) # talk to the Jijio ahead
	await _pause(0.22)
	await _snap("t1_1_pan_in")
	await _pause(0.6)
	await _snap("t1_2_first_person")
	# Stage 6c C: the mouse pushed hard to the 15-degree free-look limit (look_by, as in test_talk_frozen: no captured mouse)
	var p: CharacterBody3D = lvl.player
	var sweeps := {"look_1_left": Vector2(3000.0, 0.0), "look_2_right": Vector2(-6000.0, 0.0),
			"look_3_up": Vector2(3000.0, -3000.0), "look_4_down": Vector2(0.0, 6000.0)}
	for shot in sweeps:
		p.look_by(sweeps[shot])
		await _pause(0.15)
		await _snap(shot)
	p.look_by(Vector2(0.0, -3000.0)) # back to the middle
	await _key(KEY_E)
	await _pause(0.5)
	await _snap("t1_3_question")
	await _key(KEY_2)
	await _pause(0.2)
	await _key(KEY_E)
	await _pause(0.22)
	await _snap("t1_4_pan_out")
	await _pause(0.6)
	await _snap("t1_5_after")
	lvl.queue_free()
	await _pause(0.5)
	lvl = _level(2)
	await _pause(4.0) # the fart scene: Bob's first line
	await _key(KEY_E)
	await _pause(2.6) # he walks up and accuses
	await _key(KEY_E)
	await _pause(0.8)
	await _snap("t2_1_ghost_first_line")
	await _key(KEY_2)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(1.1)
	await _snap("t2_2_ghost_reveal")
	quit(0)
