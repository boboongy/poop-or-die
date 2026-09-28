extends SceneTree
## WINDOWED player-eye pass (not in run.sh) for the factory swim clips (SPEC Stage 6 Slice A): the real Level 2 flow in real time, walkers
## on, Bob's own camera. Waits for the full 1.6 m, then: Bob swimming east along corridor A, treading water (camera in front of him),
## the floating crowd in the waiting room, a dive (duck_dive -> swim_under) and coming back up.
##   "<console exe>" --path . --script tests/shot_swim_clips.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")

var _out := "C:/Users/bobo/AppData/Local/Temp/swim_clips"
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


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 3 # the flood (Level 3 since Stage 6b)
	(load("res://scripts/intro.gd") as GDScript).set("enabled", false) # the intro waits for Enter; the flood starts at once without it
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _wait_s(1.5)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	while lvl.water.depth < 1.55:
		await process_frame
	lvl._time_left = 100000.0
	# 1. swimming along the east end (open water, away from the plunger and the crowd), Bob's camera behind him
	p.global_position = Vector3(11.4, lvl.water.surface_y() - p.FLOAT_DEPTH, 0.0)
	p.set_facing(0.0)
	p.auto_move = Vector3(0.0, 0.0, -1.0)
	await _wait_s(1.0)
	print("swim clip ", p.anim().current_animation, " speed ", p.velocity.length())
	await _snap("swim, behind")
	p.set_camera(1.2, -0.25) # from his side
	await _wait_s(0.5)
	await _snap("swim, side")
	# 2. treading water, the camera in front of him
	p.auto_move = Vector3.ZERO
	await _wait_s(0.8)
	p.set_camera(PI, -0.2)
	await _wait_s(0.6)
	print("tread clip ", p.anim().current_animation)
	await _snap("tread_water, front")
	# 3. the floating crowd in the waiting room
	p.global_position = Vector3(-1.0, lvl.water.surface_y() - p.FLOAT_DEPTH, 0.3)
	p.set_camera(-PI / 2.0 + PI, -0.3) # looking west into the waiting room
	await _wait_s(1.0)
	await _snap("crowd, waiting room")
	# 4. a dive and back up (the task dives call these)
	p.global_position = Vector3(3.5, lvl.water.surface_y() - p.FLOAT_DEPTH, 0.1)
	p.set_camera(-PI / 2.0 + 1.2, -0.2)
	await _wait_s(0.6)
	p.busy = true
	var story: Node3D = lvl.flood_story
	story._dive_down(p)
	await _wait_s(0.3)
	await _snap("duck_dive")
	await _wait_s(1.2)
	await _snap("swim_under")
	story._dive_up(p)
	await _wait_s(0.25)
	await _snap("surfacing")
	await _wait_s(0.6)
	p.busy = false
	print("bob swimming ", p.swimming, " diving ", p.diving)
	quit()
