extends SceneTree
## Stall doors and Godot-built collision: 20 doors and 20 occupants, E opens the door in front of Bob through
## the real input path, and a closed door stops him.
const T := preload("res://tests/t.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var p: CharacterBody3D = lvl.get_node("Player")
	var stalls = lvl.get_node("NavRegion/Stalls")
	var pop: Node3D = lvl.get_node("Population")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	T.check(stalls.doors.size() == 20, "20 doors")
	T.check(pop.occupants.size() == 20, "20 seated occupants")
	T.check(pop.queue.size() == 9, "9 queue Jijios")
	var boxes := 0
	for c in stalls.get_children():
		if c is StaticBody3D and String(c.name).begins_with("Box_"):
			boxes += 1
	T.check(boxes >= 100, "Godot-built collision boxes exist (%d)" % boxes)

	p.global_position = Vector3(2.6, 0.05, 0.3)
	p.set_facing(0.0) # looking -Z at stall 2
	Input.action_press("move_forward")
	await T.wait(self, 2.0)
	Input.action_release("move_forward")
	T.check(p.global_position.z > -0.9, "a closed door stops Bob (z %.2f)" % p.global_position.z)
	T.check(prompt.text == "E  open door", "open-door prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.6)
	T.check(stalls.doors[1].is_open, "E opened the door")
	T.check(prompt.text == "E  close door", "prompt flips to close ('%s')" % prompt.text)
	T.finish(self)
