extends SceneTree
## Owner report 2026-09-21: "I can't find the tissue in Level 1, it seems to be missing." Cause found by screenshots: the box was a small pale
## blue-white cube on a white, glossy, green-washed floor, nearly invisible. This tests EVERY one of its three spots: the spot is open
## floor, reachable from Bob's start on the navmesh, the E prompt and the pickup work there, and the box STANDS OUT (a strongly coloured,
## glowing material that the green light cannot wash out; the real judgement is by eye, see the screenshots in HISTORY.md).
const T := preload("res://tests/t.gd")
const FindTissue := preload("res://scripts/missions/find_tissue.gd")


func _level_with_box(spot_index: int) -> Array:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var mm = lvl.get_node("MissionManager")
	lvl.ctx["needy"] = lvl.population.pick_free_stall() # what the queue talk decides
	mm.mission("ask").finish()
	await T.wait(self, 0.2)
	var box: Node3D = mm.mission("find")._box
	box.global_position = FindTissue.SPOTS[spot_index]
	return [lvl, box]


func _init() -> void:
	seed(51)
	for i in FindTissue.SPOTS.size():
		var spot: Vector3 = FindTissue.SPOTS[i]
		var tag := "spot %d %s" % [i + 1, str(spot)]
		var made: Array = await _level_with_box(i)
		var lvl: Node = made[0]
		var box: Node3D = made[1]
		var p: CharacterBody3D = lvl.get_node("Player")
		var prompt: Label = lvl.get_node("HUD/PromptLabel")

		# open floor: nothing solid at the box's position
		var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
		var q := PhysicsPointQueryParameters3D.new()
		q.position = spot + Vector3(0.0, 0.1, 0.0)
		T.check(space.intersect_point(q).is_empty(), "%s: nothing solid where the box lies" % tag)

		# reachable on foot from Bob's start
		var map: RID = lvl.get_node("NavRegion").get_navigation_map()
		var y: float = lvl.population.nav_height()
		var path := NavigationServer3D.map_get_path(map, Vector3(p.global_position.x, y, p.global_position.z), Vector3(spot.x, y, spot.z), true)
		var end := path[path.size() - 1] if path.size() > 0 else Vector3(INF, INF, INF)
		T.check(path.size() > 1 and Vector2(end.x - spot.x, end.z - spot.z).length() < 0.4, "%s: a walking route from Bob's start reaches it (%d points, ends %.2f m away)" % [tag, path.size(), Vector2(end.x - spot.x, end.z - spot.z).length()])

		# the prompt and the pickup, with the real E key, from the side Bob would come from
		var side := Vector3(0.7, 0.0, 0.0) if spot.x < 10.0 else Vector3(-0.7, 0.0, 0.0)
		p.global_position = spot + side
		p.set_facing(atan2(-(spot.x - p.global_position.x), -(spot.z - p.global_position.z)))
		await T.wait(self, 0.4)
		T.check(prompt.text == "E  pick up the tissue", "%s: pickup prompt ('%s')" % [tag, prompt.text])
		await T.key(self, KEY_E)
		await T.wait(self, 2.0)
		T.check(lvl.get_node("MissionManager").is_done("find") and p.carrying != null, "%s: E picks it up, mission 'find' done" % tag)

		# it stands out: a saturated, glowing material (the light in the toilet is green, a plain colour is washed out)
		var mesh: MeshInstance3D = box.find_child("*", true, false) as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D if mesh else null
		T.check(mat != null and mat.emission_enabled and mat.emission_energy_multiplier >= 1.0, "%s: the box glows (emission on)" % tag)
		if mat != null:
			var c: Color = mat.emission
			T.check(c.s >= 0.5 and c.v >= 0.8 and (c.h < 0.12 or c.h > 0.85), "%s: warm, saturated, bright (hue %.2f, sat %.2f, value %.2f): not a green or white that vanishes on the floor" % [tag, c.h, c.s, c.v])
		lvl.queue_free()
		await T.wait(self, 0.2)
	T.finish(self)
