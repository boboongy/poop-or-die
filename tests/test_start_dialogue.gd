extends SceneTree
## Stage 6b D (owner "yes to all" 2026-09-28): Levels 1, 4 and 5 open with a short start dialogue, like Levels 2 and 3. For each level:
## the clock waits (frozen Bob, full clock), Bob speaks first, then the Jijio just ahead of him (queue[4]) answers, 2 lines clicked with E,
## GO: the clock runs. Level 4 (A): the cutters arrive ARRIVE_AT s after GO, not after the load. Then a second load of each level:
## Enter skips the whole dialogue at once.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Cutters := preload("res://scripts/cutters.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")


func _init() -> void:
	seed(3)
	T.intro = true
	for n in [1, 4, 5]:
		await _clicked_through(n)
		await _skipped(n)
	T.finish(self)


func _load(n: int) -> Node:
	Progress.level = n
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	return lvl


func _unload(lvl: Node) -> void:
	lvl.queue_free()
	await T.wait(self, 0.2)


func _clicked_through(n: int) -> void:
	var said_before := Dialogue.spoken.size() # before the load: Bob's line is logged in the first 0.5 s
	var lvl := await _load(n)
	var p: CharacterBody3D = lvl.player
	var d = lvl.dialogue
	var full: float = LevelDefs.get_level(n)["time"]
	T.check(lvl.level_number == n and lvl.intro_playing and p.frozen, "L%d opens with the start dialogue, Bob frozen" % n)
	var lines := 0
	var arrived_during := false
	var clock_during := full # the lowest clock seen while the talk plays
	while lvl.intro_playing and lines < 6:
		clock_during = minf(clock_during, lvl._time_left)
		if lvl.cutters != null and not lvl.cutters.cutters.is_empty():
			arrived_during = true
		if d._waiting:
			lines += 1
			await T.key(self, KEY_E)
		await T.wait(self, 0.4)
	T.check(not lvl.intro_playing and lines == 2, "L%d: 2 lines to click through (%d)" % [n, lines])
	T.check(absf(clock_during - full) < 0.01, "L%d: the clock stood at %.0f s during the talk (%.2f)" % [n, full, clock_during])
	var said := Dialogue.spoken.slice(said_before)
	var k := Intro.CUT_IN_LEVELS.find(n)
	T.check(said.size() >= 2 and said[0] == "bob|" + Intro.CUT_IN_BOB[k] and said[1].ends_with("|" + Intro.CUT_IN_JIJIO[k])
		and not said[1].begins_with("bob|"), "L%d: Bob asks first, a Jijio answers (%s)" % [n, str(said.slice(0, 2))])
	T.check(Dialogue.missing.is_empty(), "L%d: every line has a voice (missing: %s)" % [n, str(Dialogue.missing)])
	var to_ahead: Vector3 = lvl.population.queue[4].global_position - p.global_position
	await T.wait(self, 1.0)
	T.check(lvl._running and lvl._time_left < full and not p.frozen, "L%d GO: the clock runs, Bob can move (%.1f s left)" % [n, lvl._time_left])
	if n != 4: # the mission's opening bubble from the same Jijio waits for GO instead of talking over Bob
		var hook := "Psst! You look as desperate as I feel..." if n == 1 else "Don't even THINK about cutting in."
		var after := Dialogue.spoken.slice(said_before + 2)
		T.check(after.any(func(s: String) -> bool: return s.ends_with("|" + hook)), "L%d: the mission's bubble comes after GO (%s)" % [n, str(after)])
	if n == 4:
		T.check(not arrived_during, "L4: no cutter came during the talk")
		var go_at: float = lvl._time_left + 1.0
		await T.wait_for(self, func() -> bool: return not lvl.cutters.cutters.is_empty(), Cutters.ARRIVE_AT + 3.0)
		var after_go: float = go_at - lvl._time_left
		T.check(absf(after_go - Cutters.ARRIVE_AT) < 0.5, "L4: the cutters arrive %.0f s after GO (%.2f s)" % [Cutters.ARRIVE_AT, after_go])
	print("INFO L%d: Bob to the Jijio ahead %.2f m" % [n, Vector3(to_ahead.x, 0, to_ahead.z).length()])
	await _unload(lvl)


func _skipped(n: int) -> void:
	var lvl := await _load(n)
	T.check(lvl.intro_playing, "L%d (2nd load): the start dialogue plays again" % n)
	await T.key(self, KEY_ENTER)
	await T.wait(self, 0.5)
	T.check(not lvl.intro_playing and lvl._running and not lvl.player.frozen, "L%d: Enter skips the whole dialogue, the clock runs" % n)
	await _unload(lvl)
