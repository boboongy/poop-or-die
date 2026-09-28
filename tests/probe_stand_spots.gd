extends SceneTree
## Probe (Stage 6c B): for every stall, open the door fully and test a Jijio body (the capsule, 0.2 x 1.3 m) at the stand spot
## population.gd `_stand_spot` sends a released occupant to. Prints what it overlaps.
## Run: timeout 120 "<console exe>" --headless --path . --fixed-fps 60 --script tests/probe_stand_spots.gd
const T := preload("res://tests/t.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var pop: Node = lvl.population
	for d: Node in pop._stalls.doors:
		d.set_open(true, 0.01)
	await T.wait(self, 0.3)
	var space: PhysicsDirectSpaceState3D = lvl.player.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.2
	cap.height = 1.3
	var skip: Array[RID] = [lvl.player.get_rid()]
	for n in get_nodes_in_group("jijio"):
		skip.append(n.get_rid())
	for i in pop._stalls.doors.size():
		var spot: Vector3 = pop._stand_spot(i)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), spot + Vector3.UP * 0.65)
		q.collision_mask = 1
		q.exclude = skip
		var names: Array[String] = []
		for h: Dictionary in space.intersect_shape(q, 4):
			var c: Node = h.collider
			names.append(c.get_parent().name + "/" + c.name)
		print("stall %2d %s door point %s spot %s overlaps %s" % [i, pop._stalls.doors[i].name, pop._stalls.doors[i].point, spot, names])
	T.finish(self)
