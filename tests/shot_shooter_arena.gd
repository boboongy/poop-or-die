extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 4 slice 4 through Bob's own first-person camera in the real level: the
## toilet-paper stacks from Bob's start, the east end, corridor B, BOSSY walking in after 2 crew are down, the tank refilling at a sink;
## plus a free-camera overview of the invisible wall's spot and the shut doors.
## Run: "<console exe>" --path . --script tests/shot_shooter_arena.gd -- out=<folder>
const Shooter := preload("res://scripts/shooter.gd")

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


## Stand at `at` and look at `target` through Bob's first-person camera.
func _look(at: Vector3, target: Vector3) -> void:
	p.global_position = at
	await _pause(0.15)
	var cam := p.get_viewport().get_camera_3d()
	var d := target - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _pause(0.3)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(3.0)
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(2.0, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	await _pause(0.3)
	var sh: Node = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)
	var squad: Array = sh.spawn_squad()
	sh.ai_enabled = false
	await _look(Vector3(2.0, 0.0, 0.3), Vector3(9.0, 0.8, 0.0))
	await _snap("b01_start_view_stack_A")
	await _look(Vector3(11.3, 0.0, 0.2), Vector3(11.8, 0.6, -4.5))
	await _snap("b02_east_end_stacks")
	await _look(Vector3(11.0, 0.0, -5.2), Vector3(4.0, 0.7, -4.8))
	await _snap("b03_corridor_B_stack")
	# BOSSY: two crew down, she walks in (Bob at the east end's north half)
	await _look(Vector3(11.3, 0.0, 0.3), Vector3(11.9, 0.9, -5.0))
	sh.ai_enabled = true
	for i in [1, 0]: # the kill goes through the real hit path (feed, BOSSY check)
		squad[i].hp = 1.0
		sh._on_hit(squad[i], false, squad[i].body.global_position)
	await _pause(0.6)
	await _snap("b04_bossy_appears")
	await _pause(1.5)
	await _snap("b05_bossy_walking_in")
	sh.ai_enabled = false
	# the tank refilling at sink 4
	sh.tank = 5
	await _look(Vector3(4.35, 0.0, 0.35), Vector3(7.0, 0.9, 0.0))
	await _pause(0.4)
	await _snap("b06_refilling_at_sink")
	var cam := Camera3D.new()
	lvl.add_child(cam)
	cam.global_position = Vector3(3.5, 2.6, -2.5)
	cam.look_at(Vector3(1.2, 0.5, 0.0), Vector3.UP)
	cam.current = true
	await _pause(0.3)
	await _snap("b07_overview_west_doors")
	quit()
