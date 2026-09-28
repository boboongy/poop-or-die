extends SceneTree
## SCREENSHOTS (windowed; not run by run.sh): one blob on the east wall from 2.5 m, frame by frame after it lands, to see the splash.
## Run: "<console exe>" --path . --script tests/shot_shooter_splash.gd -- out=<folder>
const Shooter := preload("res://scripts/shooter.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		await process_frame
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(10.1, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	var sh: Node = Shooter.new()
	lvl.add_child(sh)
	sh.start(p)
	for i in 30:
		await process_frame
	p.set_camera(-PI / 2.0, 0.0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	while sh.splashes == 0:
		await process_frame
	for f in 4:
		await _snap("sp%02d" % f)
		await process_frame
		await process_frame
	quit()
