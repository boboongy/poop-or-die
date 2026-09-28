extends SceneTree
## Walking Jijios on the puddle, with EVERY stall as the clogged one (both rows): a walker that walks onto wet floor slips
## (slides, lies, gets up: the slip state and pose), then carries on to where it was going and does not fall again on the way out.
## Also: nobody slips on a dry (mopped) floor, and a walker that is hit by the timeout kick while lying down gets up and kicks.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")


## Walk a new walker from one side of the puddle to the other. Returns [slipped, slip seconds, arrived, slips heard].
func _walk_through(lvl: Node, fl: Node) -> Array:
	var src: Vector3 = fl.source
	var z: float = src.z + 0.55 * fl.dir
	var from_east: bool = src.x < 6.0
	var start_x: float = src.x + (1.6 if from_east else -1.6)
	var goal_x: float = maxf(src.x - 1.6, 0.6) if from_east else minf(src.x + 1.6, 12.0)
	Sfx.played.clear()
	var npc: Node3D = lvl.population.spawn_walker(Vector3(start_x, 0.0, z), PI / 2.0 if from_east else -PI / 2.0)
	await T.wait(self, 0.3)
	var goal := Vector3(goal_x, 0.0, z)
	var arrived := [false]
	npc.reached.connect(func() -> void: arrived[0] = true)
	npc.go_to(goal)
	var slipped := false
	var slip_time := 0.0
	var t := 0.0
	var tilt_max := 0.0
	while t < 9.0 and not arrived[0]:
		await T.wait(self, 0.05)
		t += 0.05
		if npc.is_slipping():
			slipped = true
			slip_time += 0.05
			tilt_max = maxf(tilt_max, absf(npc.get_node("Model").rotation.x))
	var upright := absf(npc.get_node("Model").rotation.x) < 0.01
	var heard := Sfx.count("slip")
	print("INFO  walk-through %s: slipped=%s %.2f s, arrived=%s, final state %d at %s, goal %s" % [fl.label(), slipped, slip_time, arrived[0], npc.state, str(npc.global_position), str(goal)])
	lvl.population.remove_walker(npc)
	await T.wait(self, 0.1)
	return [slipped, slip_time, arrived[0], heard, tilt_max, upright]


func _init() -> void:
	seed(23)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # the puddle model on its own (the game's puddles are the flood's leftovers)
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var fl = T.puddle(lvl)
	lvl._time_left = 100000.0 # this test is longer than the level's 70 s: no timeout kick in the middle of it
	for i in 30: # the 20 clogged stalls, then the 10 overflowing sinks
		if i < 20:
			fl.start(i)
		else:
			fl.start_sink(i - 19)
		fl.advance(21.0)
		var tag := "stall %d (row %d)" % [i % 10 + 1, 1 if i < 10 else 2] if i < 20 else "sink %d" % (i - 19)
		var r: Array = await _walk_through(lvl, fl)
		T.check(r[0], "%s: a Jijio walking onto the puddle slips" % tag)
		T.check(r[1] >= 1.9 and r[1] <= 2.3, "%s: slide + lie + get up take about 2.1 s (%.2f s)" % [tag, r[1]])
		T.check(r[4] > 1.0 and r[5], "%s: lying on their back while down (tilt %.2f), upright afterwards" % [tag, r[4]])
		T.check(r[2], "%s: they carry on and reach where they were going" % tag)
		T.check(r[3] == 1, "%s: one fall, not several (%d slip sounds)" % [tag, r[3]])
	# a dry floor: nobody falls
	fl.start(7)
	fl.advance(21.0)
	while fl.wet_cells() > 0:
		var found := Vector3.ZERO
		for c in fl.wet.size():
			if found == Vector3.ZERO and fl.wet[c] > 0.0:
				found = fl.cell_center(c % fl.GRID, c / fl.GRID)
		fl.mop(found)
	var dry: Array = await _walk_through(lvl, fl)
	T.check(not dry[0] and dry[2] and dry[3] == 0, "a Jijio walking over the mopped floor does not slip")
	# the timeout kick reaches a walker who is lying on the floor: it stands up straight and joins in
	fl.start(2)
	fl.advance(21.0)
	var door = lvl.stalls.doors[2]
	var npc: Node3D = lvl.population.spawn_walker(Vector3(door.point.x + 1.6, 0.0, door.point.z + 0.55), PI / 2.0)
	await T.wait(self, 0.3)
	npc.go_to(Vector3(door.point.x - 1.6, 0.0, door.point.z + 0.55))
	var guard := 0.0
	while not npc.is_slipping() and guard < 6.0:
		await T.wait(self, 0.05)
		guard += 0.05
	await T.wait(self, 0.4)
	T.check(npc.is_slipping(), "the walker is down on the floor")
	npc.start_kicking(lvl.get_node("Player"), 0.0)
	await T.wait(self, 0.2)
	T.check(not npc.is_slipping() and absf(npc.get_node("Model").rotation.x) < 0.01, "a fallen walker that is sent to kick gets up at once")
	T.finish(self)
