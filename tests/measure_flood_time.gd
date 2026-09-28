extends SceneTree
## MEASUREMENT TOOL (not in run.sh, it measures, it does not guard): how long does "The flood" (Level 3 since Stage 6b) take a bot that really WALKS and
## SWIMS? (SPEC Round 2 Stage 3: timer 150 s, "then check it with a bot".)
## Run: godot --headless --path . --fixed-fps 60 --script tests/measure_flood_time.gd -- [stall=N | all] [walkers] [verbose]
## From GO (the intro's time does not count: the clock waits) the bot does what a player must, nearest task first: the red plunger and
## the toilet (hold E), each running tap (E; a tap only counts once the rampage has turned it on), the plug (E), wait for the drain, the
## mop by the drain (E), every leftover puddle (walk up, face it, hold Q + right-click), wait for the freed stall, walk in, E until Bob
## sits (the timer stops). It walks the navmesh at Bob's real speed (slower wading, swimming 2.2 m/s, dives are automatic) with real key
## presses. It does NOT include a person's reading, hesitating, searching or mis-aiming, so a person is SLOWER.
## Prints one INFO line per stall: the game-clock second of each stage.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Flood := preload("res://scripts/flood.gd")
const FloodStory := preload("res://scripts/flood_story.gd")
const NORMAL_PITCH := -0.15

var lvl: Node
var p: CharacterBody3D
var story: Node3D
var start_left := 0.0
var verbose := false


func _now() -> float:
	return start_left - lvl._time_left


func _over() -> bool:
	return lvl._time_left <= 0.0


func _walk_to(target: Vector3, stop := 0.3, limit := 40.0, until := Callable()) -> bool:
	var map: RID = (lvl.get_node("NavRegion") as NavigationRegion3D).get_navigation_map()
	var h: float = lvl._navmesh_height()
	var t0 := _now()
	var path := PackedVector3Array()
	var idx := 0
	var replan := 0.0
	var arrived := false
	while not _over() and _now() - t0 < limit:
		var pos := p.global_position
		if Vector2(pos.x - target.x, pos.z - target.z).length() <= stop or (until.is_valid() and until.call()):
			arrived = true
			break
		if replan <= 0.0 or idx >= path.size():
			path = NavigationServer3D.map_get_path(map, Vector3(pos.x, h, pos.z), Vector3(target.x, h, target.z), true)
			idx = 0
			replan = 1.0
		if path.is_empty():
			break
		while idx < path.size() - 1 and Vector2(pos.x - path[idx].x, pos.z - path[idx].z).length() < 0.3:
			idx += 1
		var aim := path[idx]
		# Like a person: keep off the door line, where the clogged stall's OPEN door leaf reaches 0.65 m into the corridor (the navmesh does
		# not know it; the bot stood pinned against it for 40 s, stall 1). Not on the last leg into a stall.
		if idx < path.size() - 1 and aim.x > 0.3 and aim.x < 10.9 and Vector2(target.x - pos.x, target.z - pos.z).length() > 1.4:
			aim.z = maxf(aim.z, -0.2) if aim.z > -2.5 else minf(aim.z, -4.9)
		var to := Vector3(aim.x - pos.x, 0.0, aim.z - pos.z)
		if to.length() > 0.02:
			p.set_camera(atan2(-to.x, -to.z), NORMAL_PITCH)
			Input.action_press("move_forward")
		await physics_frame
		replan -= 1.0 / 60.0
		if verbose and Engine.get_physics_frames() % 180 == 0:
			var near := ""
			for n: Node3D in lvl.population.queue + lvl.population.walkers + lvl.population.occupants:
				if Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length() < 1.0:
					near += " %s@(%.1f,%.1f)st%d" % [n.name, n.global_position.x, n.global_position.z, n.state]
			print("INFO        walk: Bob (%.2f, %.2f) v %.1f -> path[%d/%d] (%.1f, %.1f)%s" % [pos.x, pos.z, Vector2(p.velocity.x, p.velocity.z).length(), idx, path.size(), path[idx].x, path[idx].z, near])
	Input.action_release("move_forward")
	return arrived


## Between corridor A (and the waiting room) and corridor B: through the middle of the open east end (measure_level2 lesson, 2026-09-21).
func _go(target: Vector3, stop := 0.3, limit := 40.0, until := Callable()) -> bool:
	var here_b := p.global_position.z < -3.5
	var there_b := target.z < -3.5
	var t0 := _now()
	if there_b and not here_b:
		await _walk_to(Vector3(11.5, 0.0, -0.3), 0.4, limit)
		await _walk_to(Vector3(11.5, 0.0, -5.0), 0.4, limit)
	elif here_b and not there_b:
		await _walk_to(Vector3(11.5, 0.0, -5.0), 0.4, limit)
		await _walk_to(Vector3(11.5, 0.0, -0.3), 0.4, limit)
	return await _walk_to(target, stop, maxf(limit - (_now() - t0), 5.0), until)


func _face(dir: Vector3) -> void:
	p.face_direction(dir)
	p.set_camera(atan2(-dir.x, -dir.z), NORMAL_PITCH)
	await T.wait(self, 0.25)


## Walk to a task spot, face it, press (or hold) E, wait until Bob is free again.
func _do(spot: Vector3, face: Vector3, hold := 0.0) -> void:
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	await _go(spot, 0.25, 40.0)
	await _face(face)
	if hold > 0.0:
		await T.key_down(self, KEY_E)
		await T.wait(self, hold)
		await T.key_up(self, KEY_E)
	else:
		await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	var guard := 0.0
	while (p.busy or story.acting) and guard < 6.0:
		await T.wait(self, 0.1)
		guard += 0.1
	if verbose:
		print("INFO      t=%.1f did '%s' at (%.1f, %.1f), water %.2f m" % [_now(), prompt.text, spot.x, spot.z, lvl.water.depth])


func _dist(a: Vector3) -> float:
	return Vector2(a.x - p.global_position.x, a.z - p.global_position.z).length() + (6.0 if (a.z < -3.5) != (p.global_position.z < -3.5) else 0.0)


func _next_cell() -> Array:
	var best_f = null
	var best_d := INF
	for f in lvl.floods:
		if f.wet_cells() == 0:
			continue
		var d := _dist(f.source)
		if d < best_d:
			best_d = d
			best_f = f
	if best_f == null:
		return []
	var best := Vector3.ZERO
	var best_score := 0.0
	for c in best_f.wet.size():
		if best_f.wet[c] <= 0.0:
			continue
		var at: Vector3 = best_f.cell_center(c % best_f.GRID, c / best_f.GRID)
		var score := 0.0
		for d in best_f.wet.size():
			if best_f.wet[d] > 0.0 and best_f.cell_center(d % best_f.GRID, d / best_f.GRID).distance_to(at) <= Flood.STROKE_RADIUS:
				score += best_f.wet[d]
		if score > best_score:
			best_score = score
			best = at
	return [best]


func _open(x: float, z: float) -> bool:
	return Flood.is_floor(x, z) or Flood.WAITING_ROOM.grow(-0.3).has_point(Vector2(x, z))


func _stand_for(cell: Vector3, attempt := 0) -> Vector3:
	var first := 1.1 if cell.x < 6.0 else -1.1
	var spots: Array[Vector3] = []
	for off: Vector2 in [Vector2(first, 0.0), Vector2(-first, 0.0), Vector2(0.0, 1.1), Vector2(0.0, -1.1), Vector2(first * 0.7, -0.8), Vector2(-first * 0.7, 0.8)]:
		var x: float = cell.x + off.x
		var z: float = cell.z + off.y
		if x > 0.3 and x < 10.9:
			z = clampf(z, -0.6, 0.3) if cell.z > -2.0 else clampf(z, -5.9, -4.5)
		if Vector2(x - cell.x, z - cell.z).length() <= 1.3 and _open(x, z):
			spots.append(Vector3(x, 0.05, z))
	if spots.is_empty():
		return Vector3(cell.x + 0.8, 0.05, cell.z)
	return spots[attempt % spots.size()]


func _mop_patch(cell: Vector3) -> void:
	var mop = lvl.mop
	await _go(_stand_for(cell), 0.25, 30.0)
	await T.key_down(self, KEY_Q)
	var tries := 0
	while not _over():
		var to := cell - p.global_position
		await _face(Vector3(to.x, 0.0, to.z).normalized())
		if mop.on_water or tries >= 3:
			break
		tries += 1
		await _go(_stand_for(cell, tries), 0.25, 10.0)
	var held := 0.0
	if mop.on_water:
		await T.right_down(self)
		while mop.on_water and held < 8.0 and not _over():
			await T.wait(self, 0.1)
			held += 0.1
		await T.right_up(self)
	await T.key_up(self, KEY_Q)


func _one(stall: int, walkers: bool) -> String:
	FloodStory.force_stall = stall
	lvl = T.level(self, walkers)
	await T.wait(self, 0.4)
	p = lvl.player
	story = lvl.flood_story
	start_left = lvl._time_left
	var marks := {}
	var door: Vector3 = story._door_floor
	var out: Vector3 = story._out
	# the tasks, nearest first
	var got_plunger := false
	var guard := 0
	while (story.clogged or story.taps_left() > 0) and not _over() and guard < 20:
		guard += 1
		var options: Array = []
		if story.clogged:
			options.append(["plunger" if not got_plunger else "toilet", door + out * 1.4 if not got_plunger else door - out * 0.25, -out])
		for k: int in story.taps_on.keys():
			options.append(["tap", Vector3(story._tap_point(k).x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)])
		if options.is_empty():
			await T.wait(self, 0.3) # the last taps are not on yet: wait for the rampage
			continue
		options.sort_custom(func(a: Array, b: Array) -> bool: return _dist(a[1]) < _dist(b[1]))
		var task: Array = options[0]
		match task[0]:
			"plunger":
				await _do(task[1], task[2])
				got_plunger = story.has_plunger
			"toilet":
				await _do(task[1], task[2], story.PLUNGE_SECONDS + story.DIVE_DOWN + 0.3)
			"tap":
				await _do(task[1], task[2])
	marks["tasks"] = _now()
	marks["peak"] = lvl.water.depth
	await _do(story.DRAIN_POS + Vector3(0.7, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	while not story.is_drained and not _over():
		await T.wait(self, 0.2)
	marks["drained"] = _now()
	await _do(story.MOP_POS + Vector3(0.0, 0.0, 0.7), Vector3(0.0, 0.0, -1.0))
	var rounds := 0
	while lvl.puddles_left() > 0 and not _over() and rounds < 60 and lvl.mop.owned:
		rounds += 1
		var next := _next_cell()
		if next.is_empty():
			await T.wait(self, 0.3)
			continue
		await _mop_patch(next[0])
	if lvl.puddles_left() == 0:
		marks["mopped"] = _now()
	var label: Label = lvl.get_node("HUD/MissionLabel")
	var waited := 0.0
	while marks.has("mopped") and not label.text.contains("is free") and not _over() and waited < 40.0:
		await T.wait(self, 0.2)
		waited += 0.2
	if label.text.contains("is free"):
		marks["free"] = _now()
		var sess = lvl.get_node("ToiletSession")
		var prompt: Label = lvl.get_node("HUD/PromptLabel")
		await _go(sess._stand_spot() + sess._forward * 1.0, 0.3, 30.0, func() -> bool: return prompt.text == "E  use toilet")
		if prompt.text != "E  use toilet":
			p.face_direction(-sess._forward)
		await T.wait(self, 0.3)
		await T.key(self, KEY_E)
		waited = 0.0
		while lvl._running and not _over() and waited < 30.0:
			await T.wait(self, 0.1)
			waited += 0.1
		if not lvl._running and not _over():
			marks["sat"] = _now()
	var parts: Array[String] = []
	for k: String in ["tasks", "drained", "mopped", "free", "sat"]:
		parts.append("%s=%s" % [k, ("%.1f" % marks[k]) if marks.has(k) else "-"])
	var line := "INFO  %s: peak water %.2f m | %s | %s" % [story.stall_text(), marks.get("peak", 0.0), ", ".join(parts),
		("SAT DOWN, %.1f s to spare" % lvl._time_left) if marks.has("sat") else "NOT DONE in 150 s"]
	print(line)
	lvl.queue_free()
	await T.wait(self, 0.3)
	return "%.1f" % marks["sat"] if marks.has("sat") else "-"


func _init() -> void:
	var stalls: Array[int] = [0]
	var walkers := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("stall="):
			stalls = [int(a.substr(6))]
		if a == "all":
			stalls.assign(range(20))
		walkers = walkers or a == "walkers"
		verbose = verbose or a == "verbose"
	seed(3)
	Progress.level = T.FLOOD_LEVEL
	var times: Array[String] = []
	for s in stalls:
		times.append(await _one(s, walkers))
	print("INFO  sat-down times (s of 150), stalls %s: %s" % [str(stalls), ", ".join(times)])
	FloodStory.force_stall = -1
	T.check(true, "measured")
	T.finish(self)
