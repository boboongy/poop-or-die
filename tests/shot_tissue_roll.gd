extends SceneTree
## WINDOWED player-eye pass (not in run.sh): Level 1's tissue roll (the factory SM_TissueRoll, SPEC Stage 6 Slice A, owner B1) at each of
## its three spots, from Bob's own camera 4 m away and 1.5 m away, then carried in his hands. Walkers on.
##   "<console exe>" --path . --script tests/shot_tissue_roll.gd -- out=<folder>
const FindTissue := preload("res://scripts/missions/find_tissue.gd")

var _out := "C:/Users/bobo/AppData/Local/Temp/tissue_roll"
var _n := 0


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_root().get_texture().get_image().save_png("%s/shot_%02d.png" % [_out, _n])
	print("SHOT %02d %s" % [_n, name])


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
	(load("res://scripts/intro.gd") as GDScript).set("enabled", false)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _wait_s(1.5)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var mm = lvl.get_node("MissionManager")
	lvl.ctx["needy"] = lvl.population.pick_free_stall()
	mm.mission("ask").finish()
	await _wait_s(0.3)
	var box: Node3D = mm.mission("find")._box
	# the way a player walks up to each spot: along corridor A from the west, along corridor B from the east, into the waiting room
	var approach: Array[Vector3] = [Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, -0.35)]
	for i in FindTissue.SPOTS.size():
		var spot: Vector3 = FindTissue.SPOTS[i]
		box.global_position = spot
		var back := approach[i].normalized()
		for d: float in [4.0, 1.8]:
			var from := spot + back * d
			p.global_position = Vector3(from.x, 0.05, from.z)
			p.face_direction(-back)
			p.set_camera(atan2(back.x, back.z) + 0.35, -0.35) # a little off to the side, as a player turns to look
			await _wait_s(0.8)
			await _snap("spot %d from %.1f m" % [i, d])
	# a free camera 1.2 m from the roll (at the last spot), to see what it looks like at all
	var cam := Camera3D.new()
	lvl.add_child(cam)
	cam.global_position = box.global_position + Vector3(1.0, 0.7, 0.3)
	cam.look_at(box.global_position + Vector3(0.0, 0.1, 0.0))
	cam.make_current()
	await _wait_s(0.5)
	print("roll at ", box.global_position, " mesh visible ", box._mesh.is_visible_in_tree(), " aabb ", box._mesh.get_aabb(), " scale ", box._mesh.scale)
	await _snap("close-up, free camera")
	cam.queue_free()
	await _wait_s(0.2)
	p.global_position = Vector3(box.global_position.x, 0.05, box.global_position.z) + (Vector3(4.0, 0.0, -2.5) - box.global_position).normalized() * 0.8
	p.face_direction((box.global_position - p.global_position) * Vector3(1, 0, 1))
	await _wait_s(0.5)
	box.interact(p)
	await _wait_s(1.5)
	await _snap("carried")
	quit()
