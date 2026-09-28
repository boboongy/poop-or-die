extends SceneTree
## Stage 6c G (DECIDED 2026-09-28): a new mission line = the nearest Jijio Bob can see shouts it (a voiced bubble); repeated every 20 s
## while not done. All 5 levels: every mission id has a line; the first active mission is shouted within 1 s of the start, again 20 s
## later (not sooner), by a Jijio in Bob's view when one is; the bubble shows over that Jijio. run.sh fails on VOICE MISSING.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")
const Shouts := preload("res://scripts/mission_shouts.gd")


func _init() -> void:
	seed(7)
	T.check(is_equal_approx(Shouts.REPEAT, 20.0), "repeat every 20 s (DECIDED)")
	var no_line: Array[String] = []
	var ids := 0
	for n in range(1, 6):
		for path: String in LevelDefs.get_level(n)["missions"]:
			var m: Node = load(path).new()
			ids += 1
			if not Shouts.SHOUTS.has(m.id):
				no_line.append("L%d %s" % [n, m.id])
			m.free()
	T.check(no_line.is_empty() and ids >= 13, "every mission line in the 5 levels has a shout (%d missions; without: %s)" % [ids, str(no_line)])
	for n in range(1, 6):
		await _level(n)
	T.finish(self)


func _level(n: int) -> void:
	Progress.level = n
	var lvl := T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	var shouts: Node = lvl.get_node("MissionShouts")
	T.check(shouts.shouted.size() >= 1, "L%d: the first mission is shouted at the start (%s)" % [n, str(shouts.shouted)])
	var bubble_on := false
	for npc in root.get_tree().get_nodes_in_group("jijio"):
		for c in npc.get_children():
			if c is Label3D and c.text in Shouts.SHOUTS.values():
				bubble_on = true
	T.check(bubble_on, "L%d: the shout shows as a bubble over a Jijio" % n)
	var who: Node3D = shouts.shouter()
	var cam := lvl.get_viewport().get_camera_3d()
	T.check(who != null and cam.is_position_in_frustum(who.global_position + Vector3.UP * 1.3), "L%d: the shouter is a Jijio in Bob's view (%s)" % [n, who.name if who else "none"])
	# its bubble readable: not a Jijio right at the camera (the bubble filled the top of the screen), the bubble itself on screen
	var cam_d: float = cam.global_position.distance_to(who.global_position + Vector3.UP * 1.3) if who else 0.0
	T.check(cam_d >= 2.5 and cam.is_position_in_frustum(who.global_position + Vector3.UP * 2.1), "L%d: the shouter is 2.5 m+ from the camera (%.1f m) with its bubble on screen" % [n, cam_d])
	var first: int = shouts.shouted.size()
	await T.wait(self, 17.0)
	var early: int = shouts.shouted.filter(func(s: String) -> bool: return s.begins_with(shouts.shouted[0].split("@")[0])).size()
	await T.wait(self, 5.0)
	var later: int = shouts.shouted.filter(func(s: String) -> bool: return s.begins_with(shouts.shouted[0].split("@")[0])).size()
	T.check(early == 1 and later == 2, "L%d: not done = shouted again after 20 s, not sooner (%d at 18 s, %d at 23 s; all: %s)" % [n, early, later, str(shouts.shouted)])
	T.check(first >= 1, "L%d: %d shout(s) at the start" % [n, first])
	lvl.queue_free()
	await process_frame
