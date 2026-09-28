extends SceneTree
## Level 3 from the first second to the win screen, in real (game) time with real key presses, twice: hiding in the EMPTY stall (E climb),
## and hiding in an OCCUPIED stall (talk: ask them to shush, E climb). Both start with the GHOST intro (intro.gd; owner 2026-09-25): the
## first run clicks through every line, the second skips it with Enter; the clock must not move while it plays, the ghost glows, floats and
## leaves the queue. The counting takes 20 s (HideSeek.HIDE_SECONDS), the seekers look in all 20 stalls, Bob
## climbs down by himself, the reward stall opens (never the empty stall and never the stall Bob stood in), he sits (the timer stops with
## time to spare), wipes, flushes, and "LEVEL 3 COMPLETE" appears. `-- walkers` runs it with the walking Jijios (they seek too).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _init() -> void:
	Progress.level = T.HIDE_LEVEL
	seed(9)
	await _run(true)
	await _run(false)
	T.finish(self)


func _run(empty: bool) -> void:
	var tag := "empty stall" if empty else "occupied stall"
	HideSeek.force_empty = 6
	T.intro = true
	var lvl := T.level(self)
	T.intro = false
	current_scene = lvl
	await T.wait(self, 0.8)
	var full: float = LevelDefs.get_level(T.HIDE_LEVEL)["time"]
	await _intro(lvl, tag, empty)
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	var mm = lvl.get_node("MissionManager")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var status: Label = lvl.get_node("HUD/StatusLabel")
	var sess = lvl.get_node("ToiletSession")
	sess.poop_seconds = 0.5
	var i := 6 if empty else 13
	var door: Node3D = lvl.stalls.doors[i]
	var inward := Vector3(0.0, 0.0, -1.0) if i < 10 else Vector3(0.0, 0.0, 1.0)
	T.check(lvl.get_node("HUD/MissionLabel").text.contains("Hide from the seekers") and mm.mission("hide").state == 1, "%s: the mission is on the list and active" % tag)
	p.global_position = Vector3(door.point.x, 0.05, door.point.z) + inward * 0.6
	p.face_direction(inward)
	door.set_open(false, 0.01)
	await T.wait(self, 0.4)
	if not empty:
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		await T.key(self, KEY_E)
		await T.wait(self, 0.1)
		await T.key(self, KEY_1)
		await T.wait(self, 0.1)
		await T.key(self, KEY_E)
		await T.wait(self, 0.3)
		T.check(hs.shushed.has(i), "%s: the Jijio agreed to keep quiet" % tag)
	T.check(prompt.text == "E  climb", "%s: the climb prompt ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait(self, 0.8)
	T.check(hs.hidden_in == i, "%s: Bob is up" % tag)

	# the counting, then the search, in game time
	var t0: float = lvl._time_left
	var ticks := 0
	while hs.phase == hs.Phase.HIDING and ticks < 60 * 30:
		await physics_frame
		ticks += 1
	var counted: float = full - lvl._time_left # the level clock at the moment the seekers start (Bob's own hop and talk are inside it)
	T.check(absf(counted - HideSeek.HIDE_SECONDS) < 1.5, "%s: the seekers start after about %.0f s of the level clock (%.1f s)" % [tag, HideSeek.HIDE_SECONDS, counted])
	T.check(hs.seekers.size() == 0 or hs.phase == hs.Phase.SEEKING, "%s: the search begins" % tag)
	ticks = 0
	while hs.phase == hs.Phase.SEEKING and ticks < 60 * 60:
		await physics_frame
		ticks += 1
	T.check(hs.phase == hs.Phase.OVER and hs.catches == 0, "%s: the search ended and Bob was not found (phase %d, %.1f s of searching)" % [tag, hs.phase, ticks / 60.0])
	var heard: Array = lvl.get_node("Ambience").heard
	T.check(heard.size() >= 5, "%s: the background sounds went on while Bob hid (%d random sounds so far)" % [tag, heard.size()])
	T.check(hs.checked.size() == 20 and hs.peeks.get(i, 0) >= 1, "%s: all 20 stalls were checked, Bob's own %d time(s)" % [tag, hs.peeks.get(i, 0)])
	while not lvl.get_node("HUD/MissionLabel").text.contains("is free") and ticks < 60 * 90:
		await physics_frame
		ticks += 1
	var label: String = lvl.get_node("HUD/MissionLabel").text
	T.check(label.contains("is free"), "%s: the reward stall is announced ('%s')" % [tag, label])
	var idx: int = (sess._row - 1) * 10 + sess._k - 1
	T.check(idx != hs.empty_stall and idx != i, "%s: the reward is neither the empty stall nor the one Bob stood in (stall index %d)" % [tag, idx])
	T.check(hs.hidden_in == -1 and p.global_position.y < 0.05 and not p.hiding, "%s: Bob has climbed down by himself" % tag)
	print("INFO  %s: time left when the reward stall was announced: %.1f s of %.0f" % [tag, lvl._time_left, full])
	T.check(lvl._time_left > 20.0, "%s: plenty of time left (%.1f s)" % [tag, lvl._time_left])

	# use the toilet
	var f := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + f * 0.9
	p.face_direction(-f)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  use toilet", "%s: use-toilet prompt ('%s')" % [tag, prompt.text])
	var running_before: bool = lvl._running
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return status.text.begins_with("Pooping"), 5.0)
	T.check(running_before and not lvl._running, "%s: the timer stopped when Bob sat down" % tag)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  grab tissue", 5.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  flush", 8.0) # tissue_grab + wipe
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return lvl._result.visible, 15.0) # press_flush + the bowl-swirl cutscene
	T.check(lvl._result.visible and lvl._result.text.begins_with("LEVEL %d COMPLETE" % T.HIDE_LEVEL), "%s: win screen ('%s')" % [tag, lvl._result.text.replace("\n", " | ")])
	print("INFO  %s: %.1f s from the start of the test round to the win screen at time left %.1f" % [tag, t0 - lvl._time_left, lvl._time_left])
	HideSeek.force_empty = -1
	lvl.queue_free()
	await process_frame
	await physics_frame


## The ghost intro with real keys: every line clicked through (`full_talk`), or skipped with Enter. The clock waits for it.
func _intro(lvl: Node, tag: String, full_talk: bool) -> void:
	var intro = lvl.intro
	T.check(intro != null and lvl.intro_playing and not lvl._running, "%s: the level opens with the start dialogue, clock paused" % tag)
	var clock: float = lvl._time_left
	var hs = lvl.hide_seek
	var queue_before: int = lvl.population.queue.size()
	var text: Label = lvl.dialogue._text
	var speaker: Label = lvl.dialogue._speaker
	var p: CharacterBody3D = lvl.player
	# Round 2 (SPEC Stage 2): it opens with a loud fart and a brown cloud filling the waiting room; Bob mocks the farter and walks up to it.
	T.check(intro.cloud != null and intro.cloud.visible and Sfx.count("fart_loud") >= 1, "%s: a loud fart and a brown cloud open the intro" % tag)
	if full_talk:
		await T.wait_for(self, func() -> bool: return speaker.text == "Bob", 6.0)
		var box: AABB = intro.cloud_bounds()
		T.check(box.position.x <= -4.5 and box.end.x >= -1.0 and box.position.z <= -1.5 and box.end.z >= 1.5 and box.end.y >= 2.0,
				"%s: the cloud fills the waiting room (x %.1f..%.1f, z %.1f..%.1f, top %.1f m)" % [tag, box.position.x, box.end.x, box.position.z, box.end.z, box.end.y])
		T.check(speaker.text == "Bob" and text.text.contains("smell"), "%s: Bob mocks the smell ('%s': '%s')" % [tag, speaker.text, text.text])
		var ghost_at: Vector3 = intro.ghost.global_position
		var far := Vector2(p.global_position.x - ghost_at.x, p.global_position.z - ghost_at.z).length()
		await T.key(self, KEY_E)
		await T.wait_for(self, func() -> bool: return speaker.text == "Bob" and text.text.begins_with("YOU!"), 6.0)
		var near := Vector2(p.global_position.x - ghost_at.x, p.global_position.z - ghost_at.z).length()
		T.check(text.text.begins_with("YOU!") and near < 1.6 and near < far - 0.5, "%s: Bob walks up to the farter (%.1f m -> %.1f m) and confronts it" % [tag, far, near])
		T.check(lvl._time_left > clock - 0.1, "%s: the clock waits during the fart scene (%.1f s left)" % [tag, lvl._time_left])
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
	T.check(lvl.dialogue._panel.visible and text.text.contains("Back of the line") or not full_talk, "%s: then the Jijio ahead answers ('%s')" % [tag, text.text])
	if full_talk:
		await T.key(self, KEY_2)
		await T.wait(self, 0.2)
		for n in 2: # the rebuttal, "You want MY place?"
			await T.key(self, KEY_E)
			await T.wait(self, 0.2)
		T.check(intro.is_ghostly() and lvl.dialogue._speaker.text == "GHOST", "%s: it turns out to be a GHOST ('%s': '%s')" % [tag, lvl.dialogue._speaker.text, text.text])
		await T.wait(self, 1.0)
		T.check(intro.ghost.global_position.y > 0.2, "%s: the ghost floats (%.2f m up)" % [tag, intro.ghost.global_position.y])
		for n in 3:
			await T.key(self, KEY_E)
			await T.wait(self, 0.2)
	else:
		await T.key(self, KEY_ENTER)
	# (after a skip the intro is over at once, so only the clock is checked then)
	T.check(lvl._time_left > clock - 0.1 and hs.phase == hs.Phase.HIDING and (not full_talk or not hs._started), "%s: the clock and the counting waited for the talk (%.1f s left, phase %d, started %s)" % [tag, lvl._time_left, hs.phase, hs._started])
	await T.wait_for(self, func() -> bool: return not lvl.intro_playing, 3.0)
	await T.wait(self, 0.2)
	T.check(not lvl.intro_playing and lvl._running and hs._started, "%s: after the intro the clock runs and the counting starts" % tag)
	T.check(not intro.ghost.visible and not lvl.population.queue.has(intro.ghost) and lvl.population.queue.size() == queue_before - 1,
			"%s: the ghost has vanished and left the queue (%d -> %d)" % [tag, queue_before, lvl.population.queue.size()])
	T.check(not lvl.dialogue._panel.visible and not lvl.player.busy and not lvl.player.frozen, "%s: the talk box is gone and Bob can move" % tag)
	await T.wait_for(self, func() -> bool: return not is_instance_valid(intro.cloud), 6.0)
	T.check(not is_instance_valid(intro.cloud), "%s: the cloud clears after GO" % tag)
