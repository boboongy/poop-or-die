extends SceneTree
## PROBE (not in run.sh): how much headroom the doorways and openings have, for Bob floating at 1.6 m of water (his capsule then spans
## y 0.98..2.28). Casts rays straight up from y 0.5 on a grid over the whole floor and prints the openings lower than 2.4 m.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")


func _init() -> void:
	Progress.level = T.FLOOD_LEVEL
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var space: PhysicsDirectSpaceState3D = (lvl as Node3D).get_world_3d().direct_space_state
	var p: CharacterBody3D = lvl.player
	var shape: CapsuleShape3D = p.get_node("CollisionShape3D").shape
	print("Bob capsule radius %.2f height %.2f, shape offset y %.2f" % [shape.radius, shape.height, p.get_node("CollisionShape3D").position.y])
	var lows := {}
	for ix in range(-54, 128):
		for iz in range(-62, 21):
			var x := ix * 0.1
			var z := iz * 0.1
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.5, z), Vector3(x, 3.5, z), 1, [p.get_rid()])
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var y: float = hit["position"].y
			if y > 0.55 and y < 2.4:
				var key := "%.1f" % y
				lows[key] = lows.get(key, []) + ["(%.1f,%.1f)" % [x, z]]
	for k in lows.keys():
		var pts: Array = lows[k]
		if pts.size() < 400:
			print("ceiling at y %s over %d spots, e.g. %s" % [k, pts.size(), ", ".join(pts.slice(0, 8))])
	# the waiting room -> corridor A opening
	for z in [-0.8, -0.4, 0.0, 0.4, 0.8]:
		for x in [-0.4, -0.15, 0.1]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 0.5, z), Vector3(x, 3.5, z), 1, [p.get_rid()])
			var hit: Dictionary = space.intersect_ray(q)
			print("up from (%.2f, %.2f): %s" % [x, z, "open" if hit.is_empty() else "%.2f (%s)" % [hit["position"].y, hit["collider"].name]])
	lvl.queue_free()
	await process_frame
	quit()
