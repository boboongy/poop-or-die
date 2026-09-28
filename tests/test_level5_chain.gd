extends SceneTree
## Level 5 from the level start to "THE END", real keys where the player presses keys: the finesse talk (E, a reply), SHUFFLE QUEEN
## found and challenged (E, a reply), the rush and the ring, a perfect bot winning the battle with the arrow keys, her stall announced
## free, Bob sits (the timer stops), wipes, flushes, and the finale screen. Stall 7 (row 1) and stall 4 (row 2); `-- walkers` with the
## walking Jijios. Bob is moved (not walked) between places: walking routes are covered by the stall/walker tests.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")

const KEYS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]


func _init() -> void:
	seed(21)
	Progress.level = 5
	for stall in [6, 13]:
		await _run(stall)
	Dance.force_stall = -1
	T.finish(self)


func _run(stall: int) -> void:
	Dance.force_stall = stall
	var tag := "stall %d row %d" % [stall % 10 + 1, 1 if stall < 10 else 2]
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	var p: CharacterBody3D = lvl.player
	var d: Node = lvl.dance
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var mission: Label = lvl.get_node("HUD/MissionLabel")
	var start: float = lvl._time_left
	T.check(mission.text.contains("LEVEL 5: Dance battle") and mission.text.contains("Talk your way to the front"), "%s: start checklist" % tag)
	# 1. the finesse talk from where Bob spawns
	T.check(prompt.text == "E  talk", "%s: 'E  talk' at the start ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	for k in [KEY_3, KEY_E, KEY_E]:
		await T.key(self, k)
		await T.wait(self, 0.15)
	await T.wait(self, 0.2)
	T.check(mission.text.contains("[x] Talk your way to the front") and mission.text.contains("follow the music"), "%s: finesse done, now find her" % tag)
	# 2. up to her, E, a reply, E
	var at: Vector3 = d.queen.global_position + d.out * 0.9 + Vector3(-0.3, 0.0, 0.0)
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction((d.queen.global_position - at).normalized())
	await T.wait(self, 0.3)
	T.check(prompt.text.contains("SHUFFLE QUEEN"), "%s: her prompt ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	await T.key(self, KEY_1)
	await T.wait(self, 0.15)
	await T.key(self, KEY_E)
	# 3. the rush, the ring, the battle, won by a perfect bot
	await T.wait_for(self, func() -> bool: return d.battle != null, 10.0)
	T.check(d.battle != null, "%s: the battle started" % tag)
	var played := {}
	var waited := 0.0
	while waited < 60.0 and d.battle != null and not d.battle.over:
		var b: Node = d.battle
		for note: Dictionary in b.notes:
			var id := "%d:%.3f" % [b.round_number, note["t"]]
			if not played.has(id) and note["hit"] == "" and absf(b.now() - float(note["t"])) <= 1.0 / 120.0 + 0.0001:
				played[id] = true
				await T.key(self, KEYS[note["lane"]])
		await physics_frame
		waited += 1.0 / 60.0
	T.check(d.battle != null and d.battle.over and d.battle.bob_won, "%s: Bob won the battle" % tag)
	# 4. her stall is announced free; Bob uses it
	await T.wait_for(self, func() -> bool: return mission.text.contains("is free"), 10.0)
	T.check(mission.text.contains("Stall %d (row %d) is free" % [stall % 10 + 1, 1 if stall < 10 else 2]), "%s: HER stall is announced free ('%s')" % [tag, mission.text])
	print("INFO  %s: %.1f s of the 75 s used when the stall was free (talks and walks by teleport, battle won 2-0 by a perfect bot)" % [tag, start - lvl._time_left])
	var sess: Node = lvl.get_node("ToiletSession")
	var idx: int = (sess._row - 1) * 10 + sess._k - 1
	T.check(idx == stall, "%s: the toilet session is on her stall" % tag)
	var fwd := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + fwd * 0.9
	p.face_direction(-fwd)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  use toilet", "%s: use-toilet prompt ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return lvl.get_node("HUD/StatusLabel").text.begins_with("Pooping"), 5.0)
	T.check(not lvl._running, "%s: the timer stopped when Bob sat down" % tag)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  grab tissue", 5.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  flush", 8.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return lvl._result.visible, 15.0)
	var text: String = lvl._result.text
	T.check(text.begins_with("THE END") and text.contains("R: play again") and not text.contains("N: next level"),
			"%s: the finale screen ('%s')" % [tag, text.replace("\n", " | ")])
	lvl.queue_free()
	await process_frame
	await physics_frame
