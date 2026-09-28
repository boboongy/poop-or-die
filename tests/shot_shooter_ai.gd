extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 4 slice 3 through Bob's own first-person camera in the real level (walkers
## off, as in the arena): the squad live, a crew peeking and shooting, a brown blob in flight, the splats on the screen after hits, the
## red edge when low, the K.O.; plus one overview from a free camera of the east end (the crew at their cover, their guns).
## Run: "<console exe>" --path . --script tests/shot_shooter_ai.gd -- out=<folder>
const Shooter := preload("res://scripts/shooter.gd")
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


func _pause(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(3.0)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(3.0, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	await _pause(0.3)
	var sh: Node = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)
	sh.spawn_squad()
	await _pause(0.5)
	await _snap("a01_squad_start")
	await _until(func() -> bool: return sh.enemy_blobs.size() >= 2, 8.0)
	await _snap("a02_crew_shooting_blob_in_flight")
	var n: int = sh.bob_hits.size()
	await _until(func() -> bool: return sh.bob_hits.size() >= n + 3, 8.0)
	await _snap("a03_splats")
	sh.bob_hp = 35.0
	sh.since_hit = 0.0
	await _pause(0.3)
	await _snap("a04_low_red_edge")
	await _until(func() -> bool: return sh.over, 15.0)
	await _pause(0.2)
	await _snap("a05_ko")
	var cam := Camera3D.new()
	lvl.add_child(cam)
	cam.global_position = Vector3(11.0, 2.3, 0.7)
	cam.look_at(Vector3(11.9, 0.6, -3.5), Vector3.UP)
	cam.current = true
	await _pause(0.3)
	await _snap("a06_overview_east_end")
	quit()
