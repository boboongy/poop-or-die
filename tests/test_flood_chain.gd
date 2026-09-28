extends SceneTree
## Level 2 "The flood" (SPEC Round 2 Stage 3) from the first line of the intro to the reward stall, real key presses, real time:
## the intro (E through every line; the clock waits; the blast from the clogged stall), GO (the stall bursts open, the water trickles,
## the crowd rampages and turns on 4 taps), the tasks in the other order than test_flood_tasks (the taps first, then the plunger), the
## plug, the drain, the mop by the drain, every leftover puddle mopped with hold Q + right-click, and the reward stall (never the clogged
## one). `-- walkers` runs it with the walking Jijios. Prints how the time was spent.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Flood := preload("res://scripts/flood.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Intro := preload("res://scripts/intro.gd")
const NORMAL_PITCH := -0.15


func _first_wet(lvl: Node) -> Vector3:
	var best := Vector3.ZERO
	var best_score := 0.0
	for f in lvl.floods:
		for c in f.wet.size():
			if f.wet[c] <= 0.0:
				continue
			var at: Vector3 = f.cell_center(c % f.GRID, c / f.GRID)
			var score := 0.0
			for g in lvl.floods:
				for d in g.wet.size():
					if g.wet[d] > 0.0 and g.cell_center(d % g.GRID, d / g.GRID).distance_to(at) <= Flood.STROKE_RADIUS:
						score += g.wet[d]
			if score > best_score:
				best_score = score
				best = at
	return best


func _open(x: float, z: float) -> bool:
	return Flood.is_floor(x, z) or Flood.WAITING_ROOM.grow(-0.3).has_point(Vector2(x, z))


## Where Bob stands to mop `cell`: about 1.1 m away, on open floor (corridors, the east end, the waiting room by the drain).
func _stand_for(cell: Vector3, attempt := 0) -> Vector3:
	var first := 1.1 if cell.x < 6.0 else -1.1
	var spots: Array[Vector3] = []
	for off: Vector2 in [Vector2(first, 0.0), Vector2(-first, 0.0), Vector2(0.0, 1.1), Vector2(0.0, -1.1), Vector2(first * 0.7, -0.8), Vector2(-first * 0.7, 0.8)]:
		var x: float = cell.x + off.x
		var z: float = cell.z + off.y
		if x > 0.3 and x < 10.9: # inside the corridors: clear of the stall fronts and the sink wall
			z = clampf(z, -0.6, 0.3) if cell.z > -2.0 else clampf(z, -5.9, -4.5)
		if Vector2(x - cell.x, z - cell.z).length() <= 1.3 and _open(x, z):
			spots.append(Vector3(x, 0.05, z))
	if spots.is_empty():
		return Vector3(cell.x + 0.8, 0.05, cell.z)
	return spots[attempt % spots.size()]


func _place(p: CharacterBody3D, w: Node3D, at: Vector3, face: Vector3) -> void:
	p.global_position = Vector3(at.x, maxf(w.depth - p.FLOAT_DEPTH, 0.05), at.z)
	p.face_direction(face)
	await T.wait(self, 0.3)


func _init() -> void:
	seed(41)
	Progress.level = T.FLOOD_LEVEL
	T.intro = true
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var p: CharacterBody3D = lvl.player
	var mm = lvl.get_node("MissionManager")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var mission_label: Label = lvl.get_node("HUD/MissionLabel")
	var story: Node3D = lvl.flood_story
	var w: Node3D = lvl.water
	var d = lvl.dialogue
	T.check(lvl.level_number == T.FLOOD_LEVEL and lvl.intro_playing and not story.is_started, "The flood level opens with the intro; the flood has not started")
	var text := mission_label.text
	T.check(text.contains("LEVEL %d: The flood" % T.FLOOD_LEVEL) and text.contains("[ ] Unclog the toilet in " + story.stall_text()) and text.contains("[ ] Turn off the running taps (4 left)")
		and text.contains("[-] Pull the plug"), "checklist: unclog + taps open, the plug locked ('%s')" % text.replace("\n", " | "))
	# the intro: press E through every line
	var lines := 0
	var clock0: float = lvl._time_left
	while lvl.intro_playing and lines < 12:
		if d._waiting:
			lines += 1
			await T.key(self, KEY_E)
		await T.wait(self, 0.4)
	T.check(not lvl.intro_playing and lines == 6, "the intro has 6 lines to click through (%d)" % lines)
	T.check(Sfx.count("diarrhoea") == 1, "the blast from the clogged stall sounded once")
	T.check(absf(clock0 - 150.0) < 0.01, "the clock stood at 150 s during the intro")
	var spoken := ",".join(Dialogue.spoken)
	T.check(spoken.contains(Intro.FLOOD_SCREAM) and spoken.contains(Intro.FLOOD_BOB[2]) and Dialogue.missing.is_empty(), "every intro line was spoken (missing voices: %s)" % str(Dialogue.missing))
	var go_left: float = lvl._time_left
	await T.wait(self, 1.0)
	T.check(story.is_started and lvl._running and lvl._time_left < go_left and w.is_running("toilet"), "GO: the clock runs and the clogged toilet spills (%.1f s left)" % lvl._time_left)
	T.check(lvl.stalls.doors[story.stall].is_open, "the clogged stall's door burst open")
	await T.wait_for(self, func() -> bool: return story.taps_on.size() == 4, story.TAPS_FORCED_AT + 1.0)
	T.check(story.taps_on.size() == 4, "the rampage turned on the 4 taps %s" % str(story.sinks))
	print("INFO  taps on after %.1f s, water %.2f m" % [150.0 - lvl._time_left, w.depth])
	# the taps first
	for k: int in story.sinks.duplicate():
		await _place(p, w, Vector3(story._tap_point(k).x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
		await T.key(self, KEY_E)
		await T.wait(self, 1.8)
	T.check(story.taps_on.is_empty() and mm.is_done("taps"), "all 4 taps off (%.1f s left, water %.2f m)" % [lvl._time_left, w.depth])
	# then the plunger and the toilet
	var door: Vector3 = story._door_floor
	var out: Vector3 = story._out
	await _place(p, w, door + out * 1.4, -out)
	await T.key(self, KEY_E)
	await T.wait(self, 1.8)
	T.check(story.has_plunger, "the plunger is picked up")
	await _place(p, w, door - out * 0.25, -out)
	await T.key_down(self, KEY_E)
	await T.wait(self, story.PLUNGE_SECONDS + story.DIVE_DOWN + 0.4)
	await T.key_up(self, KEY_E)
	await T.wait(self, 1.0)
	T.check(not story.clogged and mm.is_done("plunge") and w.running_count() == 0, "the toilet is unclogged, nothing runs (%.1f s left, water %.2f m)" % [lvl._time_left, w.depth])
	var peak: float = w.depth
	# the plug
	await _place(p, w, story.DRAIN_POS + Vector3(0.7, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	T.check(mission_label.text.contains("[ ] Pull the plug"), "the plug task is open now")
	await T.key(self, KEY_E)
	await T.wait(self, 2.0)
	T.check(story.plug_out and w.draining, "the plug is out, the water drains")
	await T.wait_for(self, func() -> bool: return story.is_drained, w.DRAIN_SECONDS + 2.0)
	T.check(mm.is_done("plug") and mm.mission("find_mop").state == 1, "drained: 'pull the plug' done, 'grab the mop' open (%.1f s left)" % lvl._time_left)
	T.check(lvl.floods.size() == 4, "4 leftover puddles (%s)" % lvl.puddle_text())
	# the mop
	var prop: Node3D = mm.mission("find_mop")._prop
	await _place(p, w, prop.global_position + Vector3(0.0, 0.0, 0.7), Vector3(0.0, 0.0, -1.0))
	T.check(prompt.text == "E  pick up the mop", "by the drain: 'E  pick up the mop' ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 2.0)
	T.check(mm.is_done("find_mop") and lvl.mop.owned, "the mop is picked up")
	var mop = lvl.mop
	var guard := 0
	var stalled := 0
	while lvl.puddles_left() > 0 and guard < 40:
		guard += 1
		var cell := _first_wet(lvl)
		if cell == Vector3.ZERO:
			await T.wait(self, 0.5)
			continue
		var tries := 0
		var from := _stand_for(cell)
		await T.key_down(self, KEY_Q)
		while true:
			p.global_position = from
			var to := cell - from
			p.face_direction(Vector3(to.x, 0.0, to.z).normalized())
			p.set_camera(atan2(-to.x, -to.z), NORMAL_PITCH)
			await T.wait(self, 0.25)
			if mop.on_water or tries >= 5:
				break
			tries += 1
			from = _stand_for(cell, tries)
		var held := 0.0
		if mop.on_water:
			await T.right_down(self)
			while mop.on_water and held < 8.0:
				await T.wait(self, 0.1)
				held += 0.1
			await T.right_up(self)
		await T.key_up(self, KEY_Q)
		if held == 0.0:
			stalled += 1
	T.check(lvl.puddles_left() == 0, "all 4 leftover puddles mopped after %d patches (%d could not be aimed)" % [guard, stalled])
	await T.wait(self, 0.5)
	T.check(mm.is_done("mop") and lvl._all_done, "all missions done (%.1f s left)" % lvl._time_left)
	print("INFO  peak water %.2f m, %d mop strokes, %.1f s of 150 used (a bot with perfect steering; teleports between tasks)" % [peak, mop.strokes, 150.0 - lvl._time_left])
	p.global_position = Vector3(-3.7, 0.05, 0.4)
	var waited := 0.0
	while waited < 30.0 and not mission_label.text.contains("is free"):
		await T.wait(self, 0.25)
		waited += 0.25
	print("INFO  the reward stall was free after %.2f s" % waited)
	await T.wait(self, 9.0 - minf(waited, 9.0))
	var label := mission_label.text
	T.check(label.contains("is free"), "reward stall announced ('%s')" % label)
	T.check(not label.contains("Stall %d (row %d)" % [story.stall % 10 + 1, 1 if story.stall < 10 else 2]), "the reward is not the clogged stall (%s)" % story.stall_text())
	T.check(lvl.get_node("ToiletSession")._handle != null, "toilet session set up for the freed stall")
	T.check(lvl._running and lvl._time_left > 0.0, "time left (%.1f s)" % lvl._time_left)
	T.intro = false
	T.finish(self)
