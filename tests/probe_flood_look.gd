extends SceneTree
## WINDOWED probe (not in run.sh): the player-eye pass for Level 2's rising water (skill 3c). Real level, real time, walkers on,
## Bob's own camera. Shots: the start, 0.3 m, 1.0 m, 1.6 m (in the waiting room, then Bob moved into corridor A, looking east
## along the sinks and back at the stall doors).
##   "<console exe>" --path . --script tests/probe_flood_look.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")

var _out := "C:/Users/bobo/AppData/Local/Temp/flood_look"
var _jump := false


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, "  fps ", Engine.get_frames_per_second())


func _wait_depth(lvl: Node, d: float) -> void:
	if _jump: # look tuning only: set the depth at once (the real-flow pass runs without `jump`)
		lvl.water.depth = d
		await _wait_s(1.5)
	while lvl.water.depth < d:
		await process_frame


func _wait_s(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		_jump = _jump or a == "jump"
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 3 # the flood (Level 3 since Stage 6b)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _wait_s(1.5)
	var p: CharacterBody3D = lvl.player
	print("clogged stall index ", lvl.ctx.get("clogged", -1))
	if _jump:
		lvl.water.set_physics_process(false) # hold each depth while it is shot
	await _wait_s(1.5)
	await _snap("a_start")
	await _wait_depth(lvl, 0.3)
	await _snap("b_waiting_0.3")
	p.global_position = Vector3(2.2, 0.0, 0.2)
	p.set_facing(-PI / 2.0) # east, along corridor A
	await _wait_s(0.5)
	await _snap("c_corridor_0.3")
	await _wait_depth(lvl, 1.0)
	await _snap("d_corridor_1.0")
	p.set_camera(PI / 2.0, -0.35) # looking back west over the stall doors
	await _wait_s(0.4)
	await _snap("e_corridor_1.0_west")
	await _wait_depth(lvl, 1.6)
	p.set_camera(-PI / 2.0, -0.15)
	await _wait_s(0.6)
	print("bob y ", p.global_position.y, " swimming ", p.swimming, " water ", lvl.water.depth)
	await _snap("f_corridor_1.6")
	p.set_camera(0.0, -0.5) # toward the stall doors (row 1), looking down at the water
	await _wait_s(0.4)
	await _snap("g_corridor_1.6_doors")
	p.set_camera(-PI / 2.0, 0.5) # trying to look up: the camera must stay above the surface
	await _wait_s(0.4)
	print("camera y ", get_root().get_camera_3d().global_position.y, " under ", lvl.water.is_camera_under())
	await _snap("h_look_up")
	quit()
