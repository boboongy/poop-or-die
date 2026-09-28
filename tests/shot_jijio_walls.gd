extends SceneTree
## WINDOWED player-eye pass (not in run.sh) for Stage 6c (B), the owner's screenshot of kick-out Jijios stuck in the walls: the flood
## level with the water forced deep (1.2 m), the timeout kick-out with Bob at the far east end (two camera angles) and in corridor B,
## then Level 1's dry kick-out at the far east end (the kick thrust used to lean them into the stall end wall). Bob's own camera.
##   "<console exe>" --path . --script tests/shot_jijio_walls.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")

var _out := "C:/Users/bobo/AppData/Local/Temp/jijio_walls"
var _n := 0


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_root().get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, _n])
	print("SHOT %02d %s  fps %d" % [_n, name, Engine.get_frames_per_second()])


func _wait_s(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _kickout(level: int, deep: bool, spot: Vector3, cams: Array) -> void:
	Progress.level = level
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	get_root().add_child(lvl)
	await _wait_s(1.5)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	if deep:
		lvl.water.depth = 1.2
		await _wait_s(1.5)
		p.global_position = spot + Vector3.UP * (lvl.water.surface_y() - p.FLOAT_DEPTH)
	else:
		p.global_position = spot
	await _wait_s(0.5)
	lvl._time_left = 0.05
	await _wait_s(5.0)
	for c: Array in cams:
		p.set_camera(c[0], c[1])
		await _wait_s(0.6)
		await _snap("level %d %s kick-out at %s, camera yaw %.1f" % [level, "deep" if deep else "dry", spot, c[0]])
	lvl.queue_free()
	await _wait_s(0.3)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().size = Vector2i(1280, 720)
	(load("res://scripts/intro.gd") as GDScript).set("enabled", false)
	await process_frame
	await _kickout(3, true, Vector3(11.0, 0.0, -2.5), [[PI * 0.5, -0.35], [-PI * 0.5, -0.35]])
	await _kickout(3, true, Vector3(3.0, 0.0, -5.2), [[PI * 0.5, -0.35]])
	await _kickout(1, false, Vector3(11.0, 0.05, -2.5), [[PI * 0.5, -0.35]])
	quit()
