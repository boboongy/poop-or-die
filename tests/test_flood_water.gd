extends SceneTree
## Level 2 "The flood" (SPEC Round 2 Stage 3): the water itself, in the real level with the real story.
## At GO only the clogged toilet runs (a trickle that spreads from the stall); the rampage turns on the 4 taps by TAPS_FORCED_AT at the
## latest; the rise is RATE_PER_SOURCE per running source (checked with 5, 3 and 0 sources); it reaches 1.6 m in about 60 s and holds;
## the plug refuses while anything runs (Bob presses E at it for real) and drains the room in 12 s once all is off.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _rate(lvl: Node, seconds: float) -> float:
	var d0: float = lvl.water.depth
	await T.wait(self, seconds)
	return (lvl.water.depth - d0) / seconds


func _init() -> void:
	seed(5)
	Progress.level = T.FLOOD_LEVEL
	var lvl := T.level(self)
	var go_frame := Engine.get_physics_frames() # the story starts the frame after the level loads
	await T.wait(self, 0.3)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var w: Node3D = lvl.water
	var story: Node3D = lvl.flood_story
	var per: float = w.RATE_PER_SOURCE
	T.check(w != null and story != null and story.is_started, "Level 2 has the rising water and its story has started (no intro in tests)")
	T.check(w.running_count() == 1 and w.is_running("toilet"), "at GO only the clogged toilet runs (%d sources)" % w.running_count())
	T.check(p.water == w, "Bob knows the water")
	T.check(Sfx.count("trickle") >= 1, "the trickle sounds from the stall")
	# the trickle: water only near the stall at first, then everywhere
	var door: Vector3 = story._door_floor
	await T.wait(self, 1.5)
	T.check(w.depth > 0.0 and w.depth < w.COVER_DEPTH and w.depth_at(door) > 0.0 and w.depth_at(Vector3(-4.0, 0.0, 1.5)) == 0.0,
		"early on the water is only round the stall (%.3f m there, %.3f m in the waiting room)" % [w.depth_at(door), w.depth_at(Vector3(-4.0, 0.0, 1.5))])
	await T.wait_for(self, func() -> bool: return w.running_count() == 5, story.TAPS_FORCED_AT + 1.0)
	T.check(w.running_count() == 5 and story.taps_on.size() == 4, "by %.0f s the rampage has turned on all 4 taps %s (%d sources)" % [story.TAPS_FORCED_AT, str(story.sinks), w.running_count()])
	for k in story.sinks:
		T.check(lvl.get_node("Sinks")._streams[k - 1].visible, "sink %d runs (its stream shows)" % k)
	var r5: float = await _rate(lvl, 3.0)
	T.check(absf(r5 - 5.0 * per) < 0.1 * per, "5 sources: the water rises %.4f m/s (expected %.4f)" % [r5, 5.0 * per])
	# the plug refuses while anything runs: Bob at the drain, E for real
	p.global_position = story.DRAIN_POS + Vector3(0.7, 0.0, 0.0)
	p.face_direction(Vector3(-1.0, 0.0, 0.0))
	await T.wait(self, 0.3)
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	T.check(prompt.text == "E  pull the plug", "at the drain the prompt says 'E  pull the plug' ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(not w.draining and story.last_toast().contains("(5 left)"), "with 5 sources running the plug won't budge ('%s')" % story.last_toast())
	T.check(not w.start_drain(story.DRAIN_POS) and not w.draining, "the water itself refuses to drain while a source runs (not only the prompt)")
	# two taps off by the code (the real key presses are test_flood_tasks): 3 sources
	w.remove_source("sink%d" % story.sinks[0])
	w.remove_source("sink%d" % story.sinks[1])
	var r3: float = await _rate(lvl, 3.0)
	T.check(absf(r3 - 3.0 * per) < 0.1 * per, "3 sources: %.4f m/s (expected %.4f)" % [r3, 3.0 * per])
	w.add_source("sink%d" % story.sinks[0], Vector3.ZERO)
	w.add_source("sink%d" % story.sinks[1], Vector3.ZERO)
	var waited := 0.0
	while not w.is_full() and waited < 90.0:
		await T.wait(self, 0.5)
		waited += 0.5
	T.check(w.is_full(), "the water reaches %.1f m" % w.MAX_DEPTH)
	var at_full: float = (Engine.get_physics_frames() - go_frame) / 60.0 # --fixed-fps 60: frames are game time
	T.check(at_full > 50.0 and at_full < 75.0, "about 60 s after GO it is full (%.0f s)" % at_full)
	await T.wait(self, 3.0)
	T.check(absf(w.depth - w.MAX_DEPTH) < 0.001, "and it holds there (%.3f m)" % w.depth)
	for id in ["toilet", "sink%d" % story.sinks[0], "sink%d" % story.sinks[1], "sink%d" % story.sinks[2], "sink%d" % story.sinks[3]]:
		w.remove_source(id)
	var d0: float = w.depth
	await T.wait(self, 2.0)
	T.check(absf(w.depth - d0) < 0.001, "0 sources: the water stays put (%.3f -> %.3f)" % [d0, w.depth])
	T.check(w.start_drain(story.DRAIN_POS), "with nothing running the plug comes out")
	var drained := [false]
	w.drained.connect(func() -> void: drained[0] = true)
	var took := 0.0
	while not drained[0] and took < 20.0:
		await T.wait(self, 0.1)
		took += 0.1
	T.check(drained[0] and absf(took - w.DRAIN_SECONDS) < 0.5, "the room drains in %.1f s (expected %.0f)" % [took, w.DRAIN_SECONDS])
	T.check(w.depth == 0.0 and not w._sheet.visible, "no water left, the sheet is hidden")
	lvl.queue_free()
	await process_frame
	T.finish(self)
