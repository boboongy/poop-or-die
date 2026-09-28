extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 4 "WATER WAR" through Bob's own first-person camera in the real level
## (walkers off, as in the arena). Slice 1: the view, firing at a crew Jijio, a headshot, the kill, the empty tank.
## Run: "<console exe>" --path . --script tests/shot_shooter.gd -- out=<folder>
const Shooter := preload("res://scripts/shooter.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var p: CharacterBody3D


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


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)


func _aim(at: Vector3) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var d := at - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = false # the arena hides the walkers (SPEC Stage 4 plan (2)); with them on, one stood in front of the crew
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(3.0) # shaders compile, navmesh bakes
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(2.0, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	await _pause(0.3)
	var sh: Node = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)
	var crew = sh.spawn_crew("CREW 1", Vector3(9.0, 0.0, 0.3), -PI / 2.0)
	await _pause(0.8)
	await _snap("s01_first_person")
	_aim(crew.body.global_position + Vector3.UP * 0.5)
	var n: int = sh.hits.size()
	_mouse(true)
	await _until(func() -> bool: return sh.hits.size() > n + 1, 2.0)
	await _snap("s02_body_hit_marker_number")
	await _pause(0.12)
	await _snap("s03_firing_chest_b")
	_mouse(false)
	await _pause(0.5)
	crew.hp = crew.max_hp
	_aim(crew.head_center())
	n = sh.hits.size()
	_mouse(true)
	await _until(func() -> bool: return sh.hits.size() > n, 2.0)
	await _snap("s03b_head_hit")
	await _until(func() -> bool: return crew.down, 3.0)
	_mouse(false)
	await _snap("s03c_kill_marker_feed")
	await _pause(0.5)
	await _snap("s04_crew_down")
	# splashes on the wall from 2.5 m
	p.global_position = Vector3(10.1, 0.0, 0.3)
	_aim(Vector3(12.6, 1.1, 0.0))
	_mouse(true)
	await _pause(0.6)
	await _snap("s04b_wall_splashes")
	_mouse(false)
	p.global_position = Vector3(2.0, 0.0, 0.3)
	await _pause(0.2)
	sh.tank = 3
	_aim(Vector3(12.6, 1.2, 0.3))
	_mouse(true)
	await _pause(0.8)
	await _snap("s05_empty")
	_mouse(false)
	# look at a sink and a stall door close up: the gun against the room's colours
	p.set_camera(p.get_camera_yaw() + 1.2, -0.25)
	await _pause(0.3)
	await _snap("s06_look_left_down")
	print("shots %d hits %d wall %d" % [sh.shots_fired, sh.hits.size(), sh.wall_hits])
	quit()
