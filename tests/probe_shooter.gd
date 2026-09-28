extends SceneTree
## PROBE (not run by run.sh): the numbers the Stage 4 shooter codes against (SPEC "Stage 4 plan"): Bob's head bone height (the
## first-person eyes), the Jijio bones the hitboxes are built from (standing idle), the collision shapes, and the free line along
## corridor A from Bob's start (2.0, 0.3) east. Run: "<console exe>" --headless --path . --script tests/probe_shooter.gd
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")

const BONES := ["DEF-spine", "DEF-spine.001", "DEF-spine.003", "DEF-spine.004", "DEF-spine.005", "DEF-spine.006", "DEF-foot.L", "DEF-toe.L"]


func _bones(tag: String, body: Node3D) -> void:
	var sk := Pose.skeleton_of(body.get_node("Model"))
	var line := "%s (feet y %.3f):" % [tag, body.global_position.y]
	for b: String in BONES:
		var i := sk.find_bone(b)
		if i < 0:
			line += "  %s MISSING" % b
			continue
		var wp: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
		line += "  %s y %.3f fwd %.3f" % [b, wp.y - body.global_position.y, (wp - body.global_position).dot(body.get_node("Model").global_basis.z.normalized())]
	print(line)
	var names: Array = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.contains("eye") or n.contains("head") or n.contains("jaw") or n.contains("nose"):
			names.append(n)
	print("  face bones: ", names)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.global_transform * m.get_aabb()
		print("  mesh %s y %.2f..%.2f  x %.2f..%.2f" % [m.name, bb.position.y - body.global_position.y, bb.end.y - body.global_position.y,
				bb.position.x - body.global_position.x, bb.end.x - body.global_position.x])
	for c in body.find_children("*", "CollisionShape3D", true, false):
		var s: Shape3D = (c as CollisionShape3D).shape
		if s is CapsuleShape3D:
			print("  capsule r %.2f h %.2f at y %.2f" % [s.radius, s.height, (c as Node3D).global_position.y - body.global_position.y])
		else:
			print("  shape ", s, " at y %.2f" % ((c as Node3D).global_position.y - body.global_position.y))


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0, 1)
	var hit := space.intersect_ray(q)
	return 30.0 if hit.is_empty() else from.distance_to(hit["position"])


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(2.0, 0.0, 0.3)
	await T.wait(self, 0.5)
	_bones("BOB", p)
	var cam: Camera3D = p.get_viewport().get_camera_3d()
	print("Bob camera y %.3f (third person), pivot height %.2f" % [cam.global_position.y - p.global_position.y, p.CAMERA_HEIGHT])
	var j: Node3D = lvl.population.spawn_walker(Vector3(9.0, 0.0, 0.3), -PI / 2.0)
	lvl.population.walkers.erase(j)
	await T.wait(self, 1.0)
	_bones("JIJIO idle", j)
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	for x: float in [1.4, 2.0, 4.0, 6.0, 8.0, 9.0, 10.0]:
		var from := Vector3(x, 1.0, 0.3)
		print("corridor A x %.1f: +Z %.2f  -Z %.2f" % [x, _ray(space, from, Vector3.BACK), _ray(space, from, Vector3.FORWARD)])
	for h: float in [0.5, 1.0, 1.1]:
		var from := Vector3(2.0, h, 0.3)
		print("from (2.0, %.1f, 0.3) east free %.2f, west free %.2f" % [h, _ray(space, from, Vector3.RIGHT), _ray(space, from, Vector3.LEFT)])
	for z: float in [-1.5, -2.5, -3.5]:
		var from := Vector3(11.5, 1.0, z)
		print("east end z %.1f: +X %.2f  -X %.2f" % [z, _ray(space, from, Vector3.RIGHT), _ray(space, from, Vector3.LEFT)])
	for x: float in [2.0, 6.0, 10.0]:
		var from := Vector3(x, 1.0, -5.3)
		print("corridor B x %.1f: +Z %.2f  -Z %.2f" % [x, _ray(space, from, Vector3.BACK), _ray(space, from, Vector3.FORWARD)])
	# the arena's ends and corners (slice 3: the AI's cover points)
	for z: float in [0.3, -5.1]:
		var from := Vector3(5.0, 1.0, z)
		print("z %.1f from x 5: west free %.2f, east free %.2f" % [z, _ray(space, from, Vector3.LEFT), _ray(space, from, Vector3.RIGHT)])
	for x: float in [10.8, 11.6, 12.4]:
		var from := Vector3(x, 1.0, -2.5)
		print("east end x %.1f from z -2.5: north (+Z) free %.2f, south (-Z) free %.2f" % [x, _ray(space, from, Vector3.BACK), _ray(space, from, Vector3.FORWARD)])
	for z: float in [-0.95, -1.2, -2.5, -3.9, -4.15]:
		var from := Vector3(12.0, 1.0, z)
		print("stall block east face at z %.2f: x %.2f" % [z, 12.0 - _ray(space, from, Vector3.LEFT)])
	for x: float in [2.0, 6.0, 9.0]:
		for z: float in [0.3, -5.2]:
			var from := Vector3(x, 0.3, z)
			print("low (0.3 m) at x %.1f z %.1f: +Z %.2f -Z %.2f" % [x, z, _ray(space, from, Vector3.BACK), _ray(space, from, Vector3.FORWARD)])
	# the shooter's crew: where they stand, which way they face, their colours
	p.global_position = Vector3(2.0, 0.0, 0.3)
	var sh: Node = preload("res://scripts/shooter.gd").new()
	lvl.add_child(sh)
	sh.start(p)
	var crew = sh.spawn_crew("CREW 1", Vector3(9.0, 0.0, 0.3), -PI / 2.0)
	for t in 3:
		await T.wait(self, 0.5)
		var m: Node3D = crew.body.get_node("Model")
		var front: Vector3 = m.global_basis.z
		print("crew t %.1f: at %s visible %s state %d front (%.2f, %.2f) yaw %.2f" % [0.5 * (t + 1), crew.body.global_position, crew.body.is_visible_in_tree(), crew.body.state, front.x, front.z, m.rotation.y])
	for mi in crew.body.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.name.contains("Hair") or mm.name.contains("Shirt"):
			var mat := mm.get_active_material(0) as StandardMaterial3D
			print("  %s surfaces %d override count %d active colour %s" % [mm.name, mm.mesh.get_surface_count(), mm.get_surface_override_material_count(), mat.albedo_color if mat else "not standard"])
	lvl.queue_free()
	await process_frame
	quit()
