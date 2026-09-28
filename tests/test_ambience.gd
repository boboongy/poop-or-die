extends SceneTree
## The background soundscape (SPEC "Round 2" Stage 2, owner 2026-09-27 "yes to all"): a room hum everywhere, the queue muttering in the
## waiting room, and random 3D sounds from where they happen: flushes, farts and groans from OCCUPIED stalls, taps at sinks. In ALL 5
## levels, 60 s of game time each: the hum and the chatter play; at least 8 random sounds come, of at least 3 kinds (all 4 over the whole
## run); each comes from a stall occupant (its exact spot) or a sink spout; never from within Ambience.MIN_DISTANCE of Bob, a tap never
## within TAP_MIN_DISTANCE (its water does not show); at most MAX_AT_ONCE at a time; nothing new after the level is over.
## Stage 6 (owner 2026-09-28 "yes to all" + "constant background"): the CONSTANT bed loop plays in every level; a random sound every
## 1-3 s (at least one per 4.5 s of running level), max 3 at once, seven kinds (flush, tap, fart, groan, plop, tummy, complaint).
## Bob's holding-it groans (B): mild while time is plenty, more often and desperate in the last 20 s (every 4 s), none while busy or talking.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Ambience := preload("res://scripts/ambience.gd")
const Sinks := preload("res://scripts/sinks.gd")


func _near_source(lvl: Node, event: String, at: Vector3) -> bool:
	if event == "amb_tap":
		for k in range(1, Sinks.SINK_COUNT + 1):
			var spout := Vector3(Sinks.SINK_X_FIRST + Sinks.SINK_X_STEP * (k - 1), 0.0, 0.0) + Sinks.SPOUT
			if spout.distance_to(at) < 0.3:
				return true
		return false
	for o: Node3D in lvl.population.occupants:
		# exact spot: stalls are 0.95 m apart, so a loose "within 0.8 m" let a sound 1.5 m off pass as the next stall's (sabotage run)
		# x/z only: in Level 2 the occupants float up inside their stalls after the sound was heard (the flood, 2026-09-27)
		# a floating occupant on its back also moved 0.25 m toward the door (npc_jijio.gd FLOAT_BACK_SHIFT): its seat counts too
		var srcs: Array[Vector3] = [o.global_position]
		if o.floating and o._float_was_sitting:
			srcs.append(o._float_seat)
		for p: Vector3 in srcs:
			var src := p + Vector3.UP * Ambience.OCCUPANT_UP
			if is_instance_valid(o) and Vector2(src.x - at.x, src.z - at.z).length() < 0.1:
				return true
	return false


## For a failure message: the occupant nearest to `at` now, its state and where it is.
func _who(lvl: Node, at: Vector3) -> String:
	var best := ""
	var bd := INF
	for i in lvl.population.occupants.size():
		var o: Node3D = lvl.population.occupants[i]
		var dd := Vector2(o.global_position.x - at.x, o.global_position.z - at.z).length()
		if dd < bd:
			bd = dd
			best = "occupant %d state %d at (%.1f, %.1f)" % [i, o.state, o.global_position.x, o.global_position.z]
	return best


func _init() -> void:
	seed(5)
	var kinds_all := {}
	var total := 0
	for level in range(1, 6):
		Progress.level = level
		var lvl := T.level(self)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		var amb: Node = lvl.get_node_or_null("Ambience")
		T.check(amb != null, "L%d: the level has a soundscape" % level)
		if amb == null:
			lvl.queue_free()
			await process_frame
			continue
		T.check(is_instance_valid(amb.hum) and amb.hum.playing and is_instance_valid(amb.chatter) and amb.chatter.playing,
				"L%d: the room hum and the queue's chatter play" % level)
		T.check(is_instance_valid(amb.bed) and amb.bed.playing, "L%d: the constant background bed plays" % level)
		var most := 0
		var t := 0.0
		var running := 0.0 ## Level 3 ends early: the seekers find Bob, who does not hide in this test
		while t < 60.0:
			await physics_frame
			t += 1.0 / 60.0
			if lvl._running:
				running += 1.0 / 60.0
			most = maxi(most, amb.playing_now())
		var kinds := {}
		var bad: Array[String] = []
		for e: Dictionary in amb.heard:
			var event: String = e["event"]
			var at: Vector3 = e["at"]
			var bob: Vector3 = e["bob"]
			kinds[event] = true
			kinds_all[event] = true
			var d := Vector2(at.x - bob.x, at.z - bob.z).length()
			var min_d: float = Ambience.TAP_MIN_DISTANCE if event == "amb_tap" else Ambience.MIN_DISTANCE
			if not _near_source(lvl, event, at) or d < min_d:
				bad.append("%s at (%.1f, %.1f) %.1f m from Bob (now nearest: %s)" % [event, at.x, at.z, d, _who(lvl, at)])
		total += amb.heard.size()
		# Stage 6: one sound every 1-3 s (a draw is skipped while 3 play): at least one per 4.5 s of running level (13 in 60 s)
		T.check(amb.heard.size() >= int(running / 4.5) and amb.heard.size() >= 3 and kinds.size() >= 4,
				"L%d: %d random sounds in %.0f s of running level, %d kinds %s" % [level, amb.heard.size(), running, kinds.size(), str(kinds.keys())])
		T.check(bad.is_empty(), "L%d: every sound comes from an occupied stall or a sink, away from Bob %s" % [level, str(bad)])
		T.check(most <= Ambience.MAX_AT_ONCE, "L%d: at most %d random sounds at once (%d)" % [level, Ambience.MAX_AT_ONCE, most])
		# the level ends: no new sounds
		lvl._running = false
		var before: int = amb.heard.size()
		await T.wait(self, 20.0)
		T.check(amb.heard.size() == before, "L%d: no new sounds once the level is over (%d -> %d)" % [level, before, amb.heard.size()])
		lvl.queue_free()
		await process_frame
	var limiters := 0
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			limiters += 1
	T.check(limiters == 1, "the Master bus ends in exactly one limiter after 5 level loads (%d)" % limiters)
	T.check(kinds_all.size() == Ambience.WEIGHTS.size() and Ambience.WEIGHTS.size() == 7, "all seven kinds were heard over the 5 levels %s" % str(kinds_all.keys()))
	print("INFO  %d random sounds in 5 x 60 s" % total)
	await _bob_groans()
	T.finish(self)


const Sfx := preload("res://scripts/sfx.gd")


## Bob's holding-it groans in Level 1 (75 s): plenty of time = mild ones about every 12 s; the last 20 s = desperate ones every 4 s;
## none while he is busy (a sequence) or a talk box is open.
func _bob_groans() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	var counts := func() -> Array: return [Sfx.count("bob_groan"), Sfx.count("bob_groan_bad"), Sfx.count("bob_groan_desperate")]
	# plenty of time: 74 -> 44 s left in 30 s
	lvl._time_left = 74.0
	Sfx.played.clear()
	await T.wait(self, 30.0)
	var early: Array = counts.call()
	T.check(early[0] >= 2 and early[0] <= 3 and early[2] == 0, "plenty of time: mild groans about every 12 s, no desperate ones (%s in 30 s)" % [early])
	# the last 20 s: 18 -> 2 s left in 16 s
	lvl._time_left = 18.0
	Sfx.played.clear()
	await T.wait(self, 16.0)
	var late: Array = counts.call()
	T.check(late[2] >= 3 and late[0] == 0, "the last 20 s: desperate groans about every 4 s (%s in 16 s)" % [late])
	# busy (his own sequence) or talking: none
	lvl._time_left = 18.0
	lvl.player.busy = true
	Sfx.played.clear()
	await T.wait(self, 8.0)
	var busy: int = Sfx.count("bob_groan") + Sfx.count("bob_groan_bad") + Sfx.count("bob_groan_desperate")
	lvl.player.busy = false
	lvl._time_left = 18.0
	lvl.dialogue._panel.visible = true # the talk box is open (a real say() would wait for a key)
	Sfx.played.clear()
	await T.wait(self, 8.0)
	var talking: int = Sfx.count("bob_groan") + Sfx.count("bob_groan_bad") + Sfx.count("bob_groan_desperate")
	lvl.dialogue._panel.visible = false
	T.check(busy == 0 and talking == 0, "no groans while Bob is busy (%d) or a talk box is open (%d), 8 s each" % [busy, talking])
	lvl.queue_free()
	await process_frame
