extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): the Level 4 cutters from Bob's own third-person camera: pushing
## through the waiting room, blocking the stall door, the argument box, and the cut to the stage.
## Run: "<console exe>" --path . --script tests/shot_level4_cutters.gd -- out=<folder>
const Cutters := preload("res://scripts/cutters.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


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


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _until(func() -> bool: return false, 3.0)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var cm: Node = Cutters.new()
	lvl.add_child(cm)
	var door: Node3D = lvl.stalls.door_for(1, 5)
	var dp: Vector3 = door.interaction_point()
	cm.setup(lvl, Vector3(dp.x, 0.0, -1.0), Vector3(0.0, 0.0, 1.0), 0.5)
	# Bob in the queue, looking into the waiting room: the cutters push past
	p.face_direction(Vector3(-1.0, 0.0, -0.3).normalized())
	await _until(func() -> bool: return cm.cutters.size() == 3, 5.0)
	await _until(func() -> bool: return false, 1.5)
	await _snap("c01_pushing_in")
	await _until(func() -> bool: return cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 40.0)
	# Bob walks up the corridor: the three stand in front of the stall door
	p.global_position = Vector3(dp.x - 3.0, p.global_position.y, 0.3)
	p.face_direction(Vector3(1.0, 0.0, -0.25).normalized())
	await _until(func() -> bool: return false, 1.0)
	await _snap("c02_blocking_door")
	# argue with PUSHY
	var pushy: Dictionary = cm.cutter("PUSHY")
	var body: Node3D = pushy["body"]
	p.global_position = Vector3(body.global_position.x, p.global_position.y, body.global_position.z + 0.85)
	p.face_direction(Vector3(0.0, 0.0, -1.0))
	await _until(func() -> bool: return false, 0.6)
	await _snap("c03_prompt")
	await _key(KEY_E)
	await _until(func() -> bool: return false, 0.6)
	await _snap("c04_argument")
	await _key(KEY_1)
	await _until(func() -> bool: return false, 0.4)
	await _snap("c05_retort")
	await _key(KEY_E)
	await _until(func() -> bool: return false, 0.5)
	await _snap("c06_round1")
	quit()
