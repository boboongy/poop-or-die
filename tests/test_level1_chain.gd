extends SceneTree
## Level 1 from the first talk to the reward stall, with real key presses:
## talk (wrong answer repeats), find tissue, pick it up, deliver under the door, reward stall opens.
const T := preload("res://tests/t.gd")


func _init() -> void:
	seed(11)
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p = lvl.get_node("Player")
	var mm = lvl.get_node("MissionManager")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	T.check(lvl.level_number == 1, "level 1 loaded")
	T.check(prompt.text == "E  talk", "talk prompt at spawn ('%s')" % prompt.text)

	var t_start: float = lvl._time_left
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(p.busy, "Bob is frozen while talking")
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	await T.key(self, KEY_2) # "Not my problem"
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(not mm.is_done("ask") and not p.busy, "wrong answer: mission stays open, Bob is free again (retry only)")
	T.check(t_start - lvl._time_left < 3.0, "wrong answer costs no extra time")

	await T.wait(self, 0.5)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	await T.key(self, KEY_1) # "Yes"
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(mm.is_done("ask"), "right answer completes 'ask'")
	T.check(mm.mission("find").state == 1, "'find' became active")
	T.check(lvl.ctx.has("needy"), "a needy stall was chosen")

	var box: Node3D = mm.mission("find")._box
	T.check(box != null and box.is_inside_tree(), "tissue box spawned")
	var side := Vector3(0.7, 0.0, 0.0) if box.global_position.x < 10.0 else Vector3(-0.7, 0.0, 0.0)
	p.global_position = box.global_position + side
	p.set_facing(atan2(-(box.global_position.x - p.global_position.x), -(box.global_position.z - p.global_position.z)))
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  pick up the tissue", "pickup prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 2.0)
	T.check(mm.is_done("find") and p.carrying != null, "tissue picked up, mission 'find' done")

	var idx: int = lvl.ctx["needy"]
	var door = lvl.stalls.doors[idx]
	var front := Vector3(0, 0, 0.55) if idx < 10 else Vector3(0, 0, -0.55)
	p.global_position = Vector3(door.point.x, 0.05, door.point.z) + front
	p.set_facing(0.0 if idx < 10 else PI) # yaw 0 looks toward -Z (row 1 doors), PI toward +Z (row 2 doors)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  pass the tissue under the door", "delivery prompt at the needy door ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.5)
	T.check(mm.is_done("deliver") and lvl._all_done, "delivered: all missions done")
	await T.wait(self, 9.0)
	T.check(lvl.get_node("HUD/MissionLabel").text.contains("is free"), "reward stall announced")
	T.check(lvl.get_node("ToiletSession")._handle != null, "toilet session set up for the freed stall")
	T.finish(self)
