extends SceneTree
## PROBE (not run by run.sh): where does a dance circle fit? Samples the floor on a 0.25 m grid, keeps points that are on the navmesh
## (walkable), and measures the clearance = the shortest of 16 rays at 1.0 m height to a static collider (walls, stall blocks, sinks).
## Prints an ASCII map (digit = clearance in 0.5 m steps, '.' = not walkable) and the 12 roomiest points. NPCs are ignored.
const T := preload("res://tests/t.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	for npc in lvl.population.get_children(): # the queue Jijios are solid on the world layer; they will be in the circle, not in the way
		if npc is CollisionObject3D:
			npc.collision_layer = 0
	await T.wait(self, 0.1)
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	var map: RID = lvl.get_node("NavRegion").get_navigation_map()
	var best: Array = []
	var z := 3.0
	while z >= -7.5:
		var row := "z %5.2f " % z
		var x := -6.0
		while x <= 13.5:
			var p := Vector3(x, 0.0, z)
			var on := NavigationServer3D.map_get_closest_point(map, p)
			if Vector2(on.x - x, on.z - z).length() > 0.05:
				row += "."
			else:
				var c := 20.0
				for i in 16:
					var a := TAU * i / 16.0
					var from := p + Vector3.UP
					var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(sin(a), 0.0, cos(a)) * 6.0, 1)
					var hit := space.intersect_ray(q)
					c = minf(c, 6.0 if hit.is_empty() else from.distance_to(hit["position"]))
				row += str(mini(int(c / 0.5), 9))
				best.append([c, p])
			x += 0.25
		print(row)
		z -= 0.25
	# the waiting room's walls and ceiling, from its middle
	var mid := Vector3(-2.5, 1.0, 0.0)
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, mid + dir * 10.0, 1))
		print("room wall %s at %s" % [dir, hit["position"] if not hit.is_empty() else "none"])
	for zz in [-1.5, 1.5]: # the east side: is there a wall or an opening at these z?
		var from := Vector3(-2.5, 1.0, zz)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.RIGHT * 10.0, 1))
		print("room east wall at z %.1f: %s" % [zz, hit["position"] if not hit.is_empty() else "none"])
	best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in mini(12, best.size()):
		print("roomy %.2f m at %s" % [best[k][0], best[k][1]])
	lvl.queue_free()
	await process_frame
	quit()
