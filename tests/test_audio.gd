extends SceneTree
## Sounds. (1) Every sound file exists, loads, is listed in audio/SOURCES.md, and no file on disk is unused.
## (2) Every sound event fires from the real game action: footsteps (Bob, and NPCs), all 20 stall doors, all 10
## taps, the talk box, wrong answer, mission done, knocking, pick-up, the toilet sequence (fart, plop, wipe, flush,
## win) and the timeout kick. This proves the sounds are TRIGGERED; whether they sound right is for the owner's ears.
const T := preload("res://tests/t.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _files_on_disk(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ogg") or f.ends_with(".wav"):
			out.append((dir + "/" + f).trim_prefix("res://audio/"))
	for d in DirAccess.get_directories_at(dir):
		if d != "licenses" and d != "voices": # voices: test_voices checks them against audio/voices/manifest.json
			_files_on_disk(dir + "/" + d, out)


func _files() -> void:
	var listed: Array[String] = []
	for event: String in Sfx.events():
		for f: String in Sfx.events()[event]["files"]:
			if not listed.has(f):
				listed.append(f)
			var stream := load(Sfx.DIR + f) as AudioStream
			T.check(stream != null and stream.get_length() > 0.0, "%s: %s loads (%.2f s)" % [event, f, stream.get_length() if stream else 0.0])
	var sources := FileAccess.get_file_as_string("res://audio/SOURCES.md")
	var missing: Array[String] = []
	for f in listed:
		if not sources.contains(f):
			missing.append(f)
	T.check(missing.is_empty(), "every sound file is listed in SOURCES.md (missing: %s)" % ", ".join(missing))
	var on_disk: Array[String] = []
	_files_on_disk("res://audio", on_disk)
	var unused: Array[String] = []
	for f in on_disk:
		if not listed.has(f):
			unused.append(f)
	T.check(unused.is_empty(), "no sound file on disk is unused by an event (unused: %s)" % ", ".join(unused))
	var not_on_disk: Array[String] = []
	for f in listed:
		if not on_disk.has(f):
			not_on_disk.append(f)
	T.check(not_on_disk.is_empty(), "every listed file is on disk")


func _reset() -> void:
	Sfx.played.clear()


## Bob's footsteps, the stall doors and the taps.
func _world() -> void:
	_reset()
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p: CharacterBody3D = lvl.get_node("Player")
	var stalls = lvl.get_node("NavRegion/Stalls")
	var sinks = lvl.get_node("Sinks")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")

	# Standing still makes no steps; walking 1.5 s along corridor B (nobody else is near) makes about 5.
	p.global_position = Vector3(3.0, 0.05, -5.2)
	p.set_facing(-PI / 2.0)
	await T.wait(self, 1.0)
	T.check(Sfx.count("step") == 0, "no footsteps while everybody stands still (%d)" % Sfx.count("step"))
	Input.action_press("move_forward")
	await T.wait(self, 1.5)
	Input.action_release("move_forward")
	var steps := Sfx.count("step")
	T.check(steps >= 4 and steps <= 8, "Bob's walk makes footsteps (%d in 1.5 s)" % steps)
	await T.wait(self, 0.5)
	var after := Sfx.count("step")
	await T.wait(self, 1.0)
	T.check(Sfx.count("step") == after, "no footsteps once Bob stopped")

	# The real path: walk into a door and press E, twice.
	_reset()
	p.global_position = Vector3(2.6, 0.05, 0.3)
	p.set_facing(0.0)
	Input.action_press("move_forward")
	await T.wait(self, 2.0)
	Input.action_release("move_forward")
	await T.wait(self, 0.2)
	T.check(prompt.text == "E  open door", "at a door ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(Sfx.count("door_open") == 1, "E on a door plays the open sound (%d)" % Sfx.count("door_open"))
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(Sfx.count("door_close") == 1, "E again plays the close sound (%d)" % Sfx.count("door_close"))

	# Every instance: all 20 doors, all 10 taps.
	_reset()
	for door in stalls.doors:
		door.set_open(true)
	T.check(Sfx.count("door_open") == 20, "all 20 doors play the open sound (%d)" % Sfx.count("door_open"))
	for door in stalls.doors:
		door.set_open(false)
	T.check(Sfx.count("door_close") == 20, "all 20 doors play the close sound (%d)" % Sfx.count("door_close"))
	for k in range(1, 11):
		sinks.set_running(k, true)
	T.check(Sfx.count("tap") == 10, "all 10 taps start a running-water loop (%d)" % Sfx.count("tap"))
	var looping := 0
	for k in range(1, 11):
		var stream_node: Node = sinks.get_node("Stream%02d" % k)
		for c in stream_node.get_children():
			if c is AudioStreamPlayer3D and c.playing and c.stream.loop:
				looping += 1
	T.check(looping == 10, "each tap loop is playing and looping (%d of 10)" % looping)
	for k in range(1, 11):
		sinks.set_running(k, false)
	await T.wait(self, 0.1)
	var left := 0
	for k in range(1, 11):
		for c in sinks.get_node("Stream%02d" % k).get_children():
			if c is AudioStreamPlayer3D:
				left += 1
	T.check(left == 0, "turning the taps off stops every loop (%d left)" % left)
	lvl.queue_free()
	await T.wait(self, 0.1)


## The talk box, a wrong answer, a mission done, the knocking and the pick-up (Level 1's first two missions).
func _talk_and_find() -> void:
	seed(11)
	_reset()
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p = lvl.get_node("Player")
	var mm = lvl.get_node("MissionManager")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(Sfx.count("ui_open") == 1, "talking opens the box with a sound (%d)" % Sfx.count("ui_open"))
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	T.check(Sfx.count("ui_choose") == 1, "advancing a line makes a sound (%d)" % Sfx.count("ui_choose"))
	await T.key(self, KEY_2) # "Not my problem"
	await T.wait(self, 0.1)
	T.check(Sfx.count("ui_wrong") == 1, "the wrong answer makes the error sound (%d)" % Sfx.count("ui_wrong"))
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(Sfx.count("ui_close") == 1, "the box closes with a sound (%d)" % Sfx.count("ui_close"))
	T.check(Sfx.count("ui_done") == 0, "no mission-done sound yet")
	await T.wait(self, 0.5)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	await T.key(self, KEY_1) # "Yes"
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(mm.is_done("ask"), "the talk mission is done")
	T.check(Sfx.count("ui_done") == 1, "finishing a mission plays the done sound (%d)" % Sfx.count("ui_done"))
	T.check(Sfx.count("knock") >= 1, "the needy stall knocks as soon as the tissue hunt starts (%d)" % Sfx.count("knock"))

	var box: Node3D = mm.mission("find")._box
	var side := Vector3(0.7, 0.0, 0.0) if box.global_position.x < 10.0 else Vector3(-0.7, 0.0, 0.0)
	p.global_position = box.global_position + side
	p.set_facing(atan2(-(box.global_position.x - p.global_position.x), -(box.global_position.z - p.global_position.z)))
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  pick up the tissue", "pickup prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(Sfx.count("pickup") == 1, "picking up the tissue makes a sound (%d)" % Sfx.count("pickup"))
	lvl.queue_free()
	await T.wait(self, 0.1)


## The freed stall: the door, the Jijio walking to the sink and the tap, then poop, wipe, flush, win.
func _toilet_sequence() -> void:
	seed(3)
	_reset()
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var p = lvl.get_node("Player")
	var pop: Node3D = lvl.get_node("Population")
	var sess = lvl.get_node("ToiletSession")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var status: Label = lvl.get_node("HUD/StatusLabel")
	sess.poop_seconds = 2.6 # long enough for all three cues

	var idx: int = pop.pick_free_stall()
	await pop.reward_release(idx)
	var npc = pop.occupants[idx]
	sess.setup(idx)
	T.check(Sfx.count("door_open") >= 1, "the reward stall's door opens with a sound")
	var ticks := 0
	while npc.state != 6 and ticks < 60 * 30: # 6 = WASH
		await T.wait(self, 0.1)
		ticks += 6
	T.check(Sfx.count("step") > 0, "the Jijio's walk to the sink makes footsteps (Bob is standing still): %d" % Sfx.count("step"))
	T.check(Sfx.count("tap") >= 1, "the sink tap runs with a sound")
	T.check(Sfx.count("poop_blast") == 0 and Sfx.count("plop") == 0, "no poop sounds before Bob sits")

	var f := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + f * 0.9
	p.face_direction(-f)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  use toilet", "use-toilet prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  grab tissue", 15.0)
	T.check(prompt.text == "E  grab tissue", "grab-tissue prompt ('%s')" % prompt.text)
	# Stage 6 (1): one explosive diarrhoea + fart burst (its file carries its own splats and plops), then one last plop
	T.check(Sfx.count("poop_blast") == 1, "one poop blast while pooping (%d)" % Sfx.count("poop_blast"))
	T.check(Sfx.count("plop") == 1, "one last plop while pooping (%d)" % Sfx.count("plop"))
	T.check(Sfx.count("wipe") == 0, "no wiping sound before tissue_grab/wipe play")
	await T.key(self, KEY_E) # grab tissue
	T.check(Sfx.count("flush") == 0, "no flush before the handle")
	await T.wait_for(self, func() -> bool: return Sfx.count("wipe") >= 1, 8.0) # tissue_grab, then wipe's own cues
	T.check(Sfx.count("wipe") >= 1, "the baked wipe clip plays paper sounds (%d)" % Sfx.count("wipe"))
	await T.wait_for(self, func() -> bool: return prompt.text == "E  flush", 5.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return Sfx.count("flush") >= 1, 3.0)
	T.check(Sfx.count("flush") == 1, "the flush plays after press_flush (%d)" % Sfx.count("flush"))
	await T.wait_for(self, func() -> bool: return lvl._result.visible, 15.0)
	T.check(lvl._result.visible, "win screen shown")
	T.check(Sfx.count("ui_win") == 1, "the win screen plays the win sound (%d)" % Sfx.count("ui_win"))
	lvl.queue_free()
	await T.wait(self, 0.1)


## The timeout: kick sounds, one cry from Bob, the lose sound, and the chasers' footsteps.
func _kick() -> void:
	_reset()
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	lvl._time_left = 0.05
	var ticks := 0
	while ticks < 60 * 25 and not lvl._result.visible:
		await T.wait(self, 0.1)
		ticks += 6
	T.check(lvl._result.visible, "timeout result screen appears")
	T.check(Sfx.count("step") > 0, "the running crowd makes footsteps (%d)" % Sfx.count("step"))
	T.check(Sfx.count("kick") >= 3, "kicks make sounds (%d)" % Sfx.count("kick"))
	T.check(Sfx.count("bob_ouch") == 1, "Bob cries out once in his own voice, at the first kick (%d)" % Sfx.count("bob_ouch"))
	T.check(Sfx.count("ui_lose") == 1, "the kicked-out screen plays the lose sound (%d)" % Sfx.count("ui_lose"))
	lvl.queue_free()
	await T.wait(self, 0.1)


func _init() -> void:
	_files()
	await _world()
	await _talk_and_find()
	await _toilet_sequence()
	await _kick()
	T.finish(self)
