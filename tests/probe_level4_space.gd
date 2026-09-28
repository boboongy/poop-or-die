extends SceneTree
## PROBE (not run by run.sh): how much open floor is around candidate fight spots. Casts rays at 1.0 m height in 8 directions
## from each spot and prints the distance to the first static collider (walls, stall blocks, sinks). NPCs are ignored.
const T := preload("res://tests/t.gd")

const SPOTS := [Vector3(-0.9, 0.0, 1.4), Vector3(-2.6, 0.0, 0.2), Vector3(-0.3, 0.0, 0.3), Vector3(0.5, 0.0, 1.2), Vector3(11.5, 0.0, -2.5), Vector3(6.0, 0.0, -2.55),
		Vector3(3.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0), Vector3(6.0, 0.0, -5.3), Vector3(-2.6, 0.0, 2.0), Vector3(-4.0, 0.0, 0.2)]


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	for s: Vector3 in SPOTS:
		var line := "spot %s:" % s
		for i in 8:
			var a := TAU * i / 8.0
			var dir := Vector3(sin(a), 0.0, cos(a))
			var from := s + Vector3.UP
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 20.0, 1)
			var hit := space.intersect_ray(q)
			var d := 20.0 if hit.is_empty() else from.distance_to(hit["position"])
			line += "  %s %.2f" % [["+Z", "+X+Z", "+X", "+X-Z", "-Z", "-X-Z", "-X", "-X+Z"][i], d]
		print(line)
	lvl.queue_free()
	await process_frame
	quit()
