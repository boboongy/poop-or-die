extends SceneTree
## The walking Jijios: the random plan (2-6, all three jobs, different every level), where they spawn, that each job
## really happens (wash at a sink with the tap running, pace, walk), that they stay in the walkways, that ALL 10 sinks
## work, that Bob is never stuck in the 1.4 m corridors (walkers step aside; both corridors, both directions), talking
## (real E key), the reward Jijio getting a sink a walker was using, and the timeout kick.
const T := preload("res://tests/t.gd")
const Walkers := preload("res://scripts/walkers.gd")

const CORRIDOR_A := 0.05
const CORRIDOR_B := -5.25


## Bob walks from (x0, z) east or west along a corridor. Returns [reached the far end, longest time stuck (s)].
func _walk_corridor(lvl: Node, from: Vector3, east: bool, to_x: float, max_seconds: float) -> Array:
	var p: CharacterBody3D = lvl.get_node("Player")
	p.global_position = from
	p.set_facing(-PI / 2.0 if east else PI / 2.0)
	await T.wait(self, 0.3)
	Input.action_press("move_forward")
	var t := 0.0
	var stuck := 0.0
	var stuck_max := 0.0
	var last := p.global_position
	while t < max_seconds and ((east and p.global_position.x < to_x) or (not east and p.global_position.x > to_x)):
		await T.wait(self, 0.1)
		t += 0.1
		var moved := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length()
		last = p.global_position
		stuck = stuck + 0.1 if moved < 0.02 else 0.0
		stuck_max = maxf(stuck_max, stuck)
	Input.action_release("move_forward")
	var reached := (east and p.global_position.x >= to_x) or (not east and p.global_position.x <= to_x)
	return [reached, stuck_max]


## The plan: 2 to 6 walkers, every job appears, and it differs from level to level.
func _plan() -> void:
	var min_n := 99
	var max_n := 0
	var seen := {}
	var plans := {}
	for s in 200:
		seed(s)
		var plan := Walkers.plan()
		min_n = mini(min_n, plan.size())
		max_n = maxi(max_n, plan.size())
		for job in plan:
			seen[job] = true
		if s < 12:
			plans[",".join(plan)] = true
	T.check(min_n == 2 and max_n == 6, "the plan has 2 to 6 walkers (seen %d..%d over 200 seeds)" % [min_n, max_n])
	T.check(seen.has("wash") and seen.has("pace") and seen.has("walk") and seen.size() == 3, "all three jobs occur, nothing else (%s)" % ", ".join(seen.keys()))
	T.check(plans.size() >= 6, "levels differ: %d different plans in 12 seeds" % plans.size())


## Every waypoint can reach every other waypoint and all 10 sink spots on the navmesh (an isolated pocket of navmesh
## at the west end once trapped walkers forever). Path found AND ending at the goal.
func _reachable() -> void:
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var sinks = lvl.get_node("Sinks")
	var pop = lvl.get_node("Population")
	var map: RID = lvl.get_node("NavRegion").get_navigation_map()
	var goals: Array[Vector3] = []
	for w in Walkers.WAYPOINTS:
		goals.append(w)
	for k in range(1, 11):
		goals.append(sinks.stand_spot(k))
	var broken: Array[String] = []
	var pairs := 0
	for from in Walkers.WAYPOINTS:
		for goal in goals:
			if from.distance_to(goal) < 0.1:
				continue
			var a: Vector3 = walkers._snap(from)
			var b: Vector3 = walkers._snap(goal)
			var path := NavigationServer3D.map_get_path(map, Vector3(a.x, pop.nav_height(), a.z), Vector3(b.x, pop.nav_height(), b.z), true)
			pairs += 1
			var end := path[path.size() - 1] if path.size() > 0 else Vector3(999, 0, 999)
			if Vector2(end.x - b.x, end.z - b.z).length() > 0.35:
				broken.append("%s -> %s" % [from, goal])
	T.check(broken.is_empty(), "all %d waypoint -> waypoint / sink routes reach their goal (broken: %s)" % [pairs, "; ".join(broken)])
	lvl.queue_free()
	await T.wait(self, 0.1)


## A real level load with walkers on: how many, where, interactable.
func _spawned() -> void:
	seed(5)
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var pop = lvl.get_node("Population")
	var p: CharacterBody3D = lvl.get_node("Player")
	var walkers = lvl.get_node("Walkers")
	var n: int = pop.walkers.size()
	T.check(n >= 2 and n <= 6, "the level has %d walkers (2-6)" % n)
	var bad := 0
	var why: Array[String] = []
	var non_talk := 0
	var map: RID = lvl.get_node("NavRegion").get_navigation_map()
	for w in pop.walkers:
		var c := NavigationServer3D.map_get_closest_point(map, Vector3(w.global_position.x, pop.nav_height(), w.global_position.z))
		# 0.5 m from the navmesh edge: a walker already on its way hugs a wall (the navmesh edge is inset from the wall)
		if Vector2(c.x - w.global_position.x, c.z - w.global_position.z).length() > 0.5 or w.global_position.x < 0.0 or w.global_position.distance_to(p.global_position) < 4.0:
			bad += 1
			why.append("at %s (nearest floor %s, Bob %s)" % [w.global_position, c, p.global_position])
		if not w.is_in_group("interactable") or w.prompt() != "E  talk":
			non_talk += 1
		if w.collision_layer != 2:
			bad += 1
			why.append("layer %d" % w.collision_layer)
	T.check(bad == 0, "every walker starts on the walkable floor, in the walkways (not the waiting room), 4 m+ from Bob (%d bad) %s" % [bad, "; ".join(why)])
	T.check(non_talk == 0, "every walker can be talked to ('E  talk')")
	T.check(pop.queue.size() == 9 and pop.occupants.size() == 20, "the queue (9) and the 20 stall occupants are still there")
	T.check(walkers.job_of(pop.walkers[0]) in Walkers.JOBS, "each walker has one of the three jobs")
	lvl.queue_free()
	await T.wait(self, 0.1)


## Each job really happens, everyone stays in the walkways for 25 s.
func _jobs() -> void:
	seed(9)
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var pop = lvl.get_node("Population")
	var walkers = lvl.get_node("Walkers")
	var sinks = lvl.get_node("Sinks")
	await walkers.clear()
	var jobs: Array[String] = ["wash", "pace", "walk", "pace", "walk", "wash"]
	var made: Array[Node3D] = walkers.spawn(jobs)
	var travelled := {}
	var washed := {}
	var last := {}
	var out_of_bounds := 0
	var tap_seen := 0 ## once-a-second samples with a walker washing AND a tap running
	for w in made:
		travelled[w] = 0.0
		last[w] = w.global_position
		washed[w] = false
	for i in 25 * 60:
		await T.wait(self, 1.0 / 60.0)
		for w in made:
			var here: Vector3 = w.global_position
			travelled[w] += Vector2(here.x - last[w].x, here.z - last[w].z).length()
			last[w] = here
			if w.is_washing():
				washed[w] = true
				if i % 60 == 0:
					for k in 10:
						if sinks._streams[k].visible:
							tap_seen += 1
							break
			# never in the waiting room, never inside the stall block (between the corridors), never sunk or flying
			var in_stalls: bool = here.x > 1.3 and here.x < 9.7 and here.z < -1.1 and here.z > -4.2
			if here.x < -0.2 or in_stalls or absf(here.y) > 0.3:
				out_of_bounds += 1
	T.check(out_of_bounds == 0, "for 25 s no walker enters the waiting room, a stall or leaves the floor (%d bad frames)" % out_of_bounds)
	for k in made.size():
		var w := made[k]
		match jobs[k]:
			"wash":
				T.check(washed[w], "walker %d (wash) reached a sink and washed" % k)
			"pace":
				T.check(travelled[w] > 3.0, "walker %d (pace) walked (%.1f m)" % [k, travelled[w]])
			_:
				T.check(travelled[w] > 5.0, "walker %d (walk) strolled (%.1f m)" % [k, travelled[w]])
	# a washer has its tap running (sampled once a second while one washes: at the end both may be walking to their next sink)
	T.check(tap_seen >= 1, "a tap is running for a washing walker (%d samples)" % tap_seen)
	lvl.queue_free()
	await T.wait(self, 0.1)


## Test EVERY sink: ten washers, one per sink, each at its own basin with the tap running.
func _all_sinks() -> void:
	seed(21)
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var sinks = lvl.get_node("Sinks")
	await walkers.clear()
	var jobs: Array[String] = []
	for i in 10:
		jobs.append("wash")
	var made: Array[Node3D] = walkers.spawn(jobs)
	# Washers cycle (wash, dry off, next sink), so "at the same instant" is the wrong question: every sink must be
	# used by a walker standing at its basin with the tap running at SOME time in 40 s.
	var used := {}
	var ticks := 0
	while ticks < 60 * 40 and used.size() < 10:
		await T.wait(self, 0.5)
		ticks += 30
		for k in range(1, 11):
			for w in made:
				if w.is_washing() and Vector2(w.global_position.x - sinks.stand_spot(k).x, w.global_position.z - sinks.stand_spot(k).z).length() < 0.3 and sinks._streams[k - 1].visible:
					used[k] = true
	T.check(used.size() == 10, "every one of the 10 sinks was used by a walker washing at the basin with the tap running (%d of 10, %.0f s)" % [used.size(), ticks / 60.0])
	# Bob walks corridor A end to end past ten washers (they stand at the sink wall)
	var r: Array = await _walk_corridor(lvl, Vector3(1.0, 0.05, CORRIDOR_A), true, 10.2, 12.0)
	T.check(r[0], "Bob walks the whole of corridor A past ten washers (never blocked)")
	T.check(r[1] < 1.5, "and is never stuck for long (%.1f s)" % r[1])
	lvl.queue_free()
	await T.wait(self, 0.1)


## A pacing walker walks straight at Bob in a 1.4 m corridor: it steps to the wall and Bob gets through.
func _step_aside() -> void:
	for corridor in [["A", CORRIDOR_A], ["B", CORRIDOR_B]]:
		seed(31)
		var lvl := T.level(self, true)
		await T.wait(self, 0.6)
		var walkers = lvl.get_node("Walkers")
		await walkers.clear()
		var made: Array[Node3D] = walkers.spawn(["pace", "pace"])
		var cz: float = corridor[1]
		for k in made.size():
			walkers._pace_points[made[k]] = [Vector3(3.0 + k * 2.5, 0.0, cz), Vector3(8.5 - k * 2.5, 0.0, cz)]
			made[k].global_position = Vector3(5.0 + k * 1.5, 0.0, cz)
		var east: Array = await _walk_corridor(lvl, Vector3(1.4, 0.05, cz), true, 9.8, 12.0)
		T.check(east[0], "corridor %s, Bob east past two pacing walkers: got through" % corridor[0])
		T.check(east[1] < 2.5, "corridor %s, east: never stuck for long (%.1f s)" % [corridor[0], east[1]])
		var west: Array = await _walk_corridor(lvl, Vector3(9.8, 0.05, cz), false, 1.6, 12.0)
		T.check(west[0], "corridor %s, Bob back west: got through" % corridor[0])
		T.check(west[1] < 2.5, "corridor %s, west: never stuck for long (%.1f s)" % [corridor[0], west[1]])
		lvl.queue_free()
		await T.wait(self, 0.1)


## Real E key on a washing walker: the box opens with a chatter line and the hint, the walker stands still and faces
## Bob, and afterwards goes back to washing. A walking walker freezes while `talking` and moves on afterwards.
func _talk() -> void:
	seed(41)
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var sinks = lvl.get_node("Sinks")
	var p: CharacterBody3D = lvl.get_node("Player")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	await walkers.clear()
	var made: Array[Node3D] = walkers.spawn(["wash"])
	var w: Node3D = made[0]
	var ticks := 0
	while not w.is_washing() and ticks < 60 * 40:
		await T.wait(self, 0.2)
		ticks += 12
	T.check(w.is_washing(), "the washer reached its sink (%.0f s)" % (ticks / 60.0))
	p.global_position = Vector3(w.global_position.x, 0.05, w.global_position.z - 0.75)
	p.set_facing(PI) # looking toward +Z, at the walker
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  talk", "talk prompt next to a walker ('%s')" % prompt.text)
	var spot := w.global_position
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(p.busy and w.talking, "Bob is frozen and the walker is talking")
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(p.busy, "second line: the walker's hint about the level")
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(not p.busy and not w.talking, "the box closes and both are free again")
	T.check(w.global_position.distance_to(spot) < 0.05 and w.is_washing(), "the walker stayed at the basin and kept washing")

	# a walking walker stands still while `talking` and moves on afterwards
	await walkers.clear()
	made = walkers.spawn(["walk"])
	w = made[0]
	await T.wait(self, 1.0)
	w.talking = true
	await T.wait(self, 0.2)
	var before := w.global_position
	await T.wait(self, 1.5)
	T.check(w.global_position.distance_to(before) < 0.05, "a walking walker stands still while Bob talks to it")
	w.talking = false
	var moved := 0.0
	for i in 12: # it may be pausing between two walks: give it up to 6 s
		await T.wait(self, 0.5)
		moved = maxf(moved, w.global_position.distance_to(before))
	T.check(moved > 0.5, "and walks on afterwards (moved %.1f m; walker at %s state %d walking %s, Bob at %s)" % [moved,
		str(w.global_position.snappedf(0.01)), w.state, w.is_walking(), str(p.global_position.snappedf(0.01))])
	lvl.queue_free()
	await T.wait(self, 0.1)


## The reward Jijio needs a sink a walker is washing at: the walker leaves, the tap stays on, the reward Jijio washes there.
func _reward_sink() -> void:
	for k in [1, 5, 10]:
		seed(50 + k)
		var lvl := T.level(self, true)
		await T.wait(self, 0.6)
		var walkers = lvl.get_node("Walkers")
		var sinks = lvl.get_node("Sinks")
		var pop = lvl.get_node("Population")
		await walkers.clear()
		# one washer sent to exactly the sink the reward Jijio will need, plus two more washers
		var owner_npc: Node3D = walkers.spawn_washer_at(k)
		walkers.spawn(["wash", "wash"])
		var spot: Vector3 = sinks.stand_spot(k)
		var ticks := 0
		while not (owner_npc.is_washing() and Vector2(owner_npc.global_position.x - spot.x, owner_npc.global_position.z - spot.z).length() < 0.3) and ticks < 60 * 40:
			await T.wait(self, 0.2)
			ticks += 12
		T.check(owner_npc.is_washing(), "sink %d: a walker is washing there (%.0f s)" % [k, ticks / 60.0])
		var idx: int = k - 1 # row 1 stall k uses sink k
		var reward = pop.occupants[idx]
		pop.reward_release(idx)
		await T.wait(self, 5.0)
		T.check(not owner_npc.is_washing() and owner_npc.global_position.distance_to(spot) > 0.8, "sink %d: the walker moved away from the sink (washing %s, %.2f m away, state %d)" % [k, owner_npc.is_washing(), owner_npc.global_position.distance_to(spot), owner_npc.state])
		ticks = 0
		while not reward.is_washing() and ticks < 60 * 30:
			await T.wait(self, 0.2)
			ticks += 12
		T.check(reward.is_washing() and Vector2(reward.global_position.x - spot.x, reward.global_position.z - spot.z).length() < 0.3, "sink %d: the reward Jijio is washing at the basin (%.0f s)" % [k, ticks / 60.0])
		T.check(sinks._streams[k - 1].visible, "sink %d: the tap is running" % k)
		lvl.queue_free()
		await T.wait(self, 0.1)


## The timeout: every walker runs to Bob and kicks; nobody keeps washing or walking their route.
func _kick() -> void:
	seed(61)
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var sinks = lvl.get_node("Sinks")
	var pop = lvl.get_node("Population")
	await walkers.clear()
	var jobs: Array[String] = ["wash", "wash", "pace", "walk", "pace", "walk"]
	var made: Array[Node3D] = walkers.spawn(jobs)
	await T.wait(self, 6.0)
	lvl._time_left = 0.05
	var ticks := 0
	while ticks < 60 * 25 and not lvl._result.visible:
		await T.wait(self, 0.1)
		ticks += 6
	T.check(lvl._result.visible, "timeout with 6 walkers: result screen appears (%.1f s)" % (ticks / 60.0))
	T.check(ticks / 60.0 < 20.0, "within 20 s")
	var chasing := 0
	var washing := 0
	for w in made:
		if w.state == 3 or w.state == 4: # CHASE or KICK
			chasing += 1
		if w.is_washing():
			washing += 1
	T.check(chasing == 6, "all 6 walkers chase or kick Bob (%d)" % chasing)
	T.check(washing == 0, "nobody is still washing")
	var taps := 0
	for k in range(1, 11):
		if sinks._streams[k - 1].visible:
			taps += 1
	T.check(taps == 0, "all taps are off (%d running)" % taps)
	var out := 0
	for npc in pop.occupants:
		if not npc.is_sitting():
			out += 1
	T.check(out == 4, "the 4 stall Jijios still join (%d)" % out)
	lvl.queue_free()
	await T.wait(self, 0.1)


func _init() -> void:
	_plan()
	await _reachable()
	await _spawned()
	await _jobs()
	await _all_sinks()
	await _step_aside()
	await _talk()
	await _reward_sink()
	await _kick()
	T.finish(self)
