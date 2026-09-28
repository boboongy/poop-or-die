extends SceneTree
## Owner report 2026-09-21: "there are moments I can't move if Jijios block my way." Random walkers (the real 2-6 plan, all jobs) on
## Level 2, MANY seeds: Bob walks both corridors in both directions (with the Level 2 puddle growing and walkers slipping in it) and must
## never be stuck for long. Also: an open conversation ends with E and Bob moves again. Stuck = he has not moved 2 cm for 0.1 s, counted
## in a row. Run: `bash tests/run.sh stress` (about 6 minutes). `-- seeds=N` changes the number of seeds.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

const MAX_STUCK := 3.0 ## seconds in a row Bob may be held up by a walker (they step aside within a few seconds)

var _overlaps := 0 ## 0.1 s samples with Bob inside a walker (Stage 6c A: he never walks through one)


## Bob walks along a corridor. Returns [reached, longest stuck run (s)].
func _walk(lvl: Node, from: Vector3, east: bool, to_x: float, max_seconds: float) -> Array:
	var p: CharacterBody3D = lvl.get_node("Player")
	p.global_position = from
	p.set_facing(-PI / 2.0 if east else PI / 2.0)
	await T.wait(self, 0.3)
	Input.action_press("move_forward")
	var t := 0.0
	var stuck := 0.0
	var stuck_max := 0.0
	var last := p.global_position
	var closest := INF ## closest any walker came to Bob (proves the walk really met walkers)
	while t < max_seconds and ((east and p.global_position.x < to_x) or (not east and p.global_position.x > to_x)):
		await T.wait(self, 0.1)
		t += 0.1
		for w: Node3D in lvl.population.walkers:
			closest = minf(closest, Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length())
		var moved := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length()
		last = p.global_position
		# sliding or lying-down time is not "blocked by a Jijio"
		stuck = stuck + 0.1 if (moved < 0.02 and p.slip_left == 0.0) else 0.0
		stuck_max = maxf(stuck_max, stuck)
		if stuck > 2.95 and stuck < 3.05: # once per stuck spell: who is around Bob?
			var walkers_info := []
			var wm = lvl.get_node("Walkers")
			for w: Node3D in lvl.population.walkers:
				walkers_info.append("%s state %d at (%.2f, %.2f) dist %.2f talking=%s" % [wm.job_of(w), w.state, w.global_position.x, w.global_position.z, Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length(), w.talking])
			print("INFO  STUCK at Bob (%.2f, %.2f), walking %s: %s" % [p.global_position.x, p.global_position.z, "east" if east else "west", " | ".join(walkers_info)])
	Input.action_release("move_forward")
	var reached := (east and p.global_position.x >= to_x) or (not east and p.global_position.x <= to_x)
	return [reached, stuck_max, closest]


func _init() -> void:
	var seeds := 8
	var first := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("first="):
			first = int(a.substr(6)) ## start at seed 100 + first (to replay one failing seed)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # walkers + one growing puddle (the old Level 2); the flood itself is test_flood_swim
	var worst := 0.0
	var not_reached := 0
	var encounters := 0
	var push_time := 0.0
	for s in range(first, first + seeds):
		seed(100 + s)
		var lvl := T.level(self, true)
		await T.wait(self, 1.5)
		lvl._time_left = 100000.0
		var p: CharacterBody3D = lvl.get_node("Player")
		var fl = T.puddle(lvl)
		fl.start(randi() % 20)
		p.floor_wet_fn = fl.wet_at
		var n: int = lvl.population.walkers.size()
		await T.wait(self, 4.0) # let the walkers get going and the puddle grow a little
		var runs := [
			["A west", Vector3(11.0, 0.05, 0.05), false, 1.6],
			["A east", Vector3(1.4, 0.05, 0.05), true, 10.5],
			["B east", Vector3(1.6, 0.05, -5.25), true, 10.5],
			["B west", Vector3(11.0, 0.05, -5.25), false, 1.6],
		]
		for r: Array in runs:
			var res: Array = await _walk(lvl, r[1], r[2], r[3], 30.0)
			worst = maxf(worst, res[1])
			if not res[0]:
				not_reached += 1
			if res[2] < 1.2:
				encounters += 1
			T.check(res[0] and res[1] <= MAX_STUCK, "seed %d (%d walkers), %s: reached the end, longest stuck %.1f s, closest walker %.2f m" % [100 + s, n, r[0], res[1], res[2]])
		push_time += p.walker_push_time
		lvl.queue_free()
		await T.wait(self, 0.3)
	print("INFO  Bob shoved walkers aside for %.1f s in all" % push_time)
	T.check(_overlaps == 0, "Bob never walked through a walker: %d samples inside one (every 0.1 s, %d walks)" % [_overlaps, seeds * 4])
	print("INFO  worst stuck time over %d seeds x 4 walks: %.1f s, walks that never got through: %d, walks that met a walker within 1.2 m: %d" % [seeds, worst, not_reached, encounters])
	T.check(encounters >= seeds, "the test really met walkers: %d of %d walks came within 1.2 m of one (a test that never meets them proves nothing)" % [encounters, seeds * 4])
	T.finish(self)
