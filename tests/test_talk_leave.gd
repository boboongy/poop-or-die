extends SceneTree
## Owner request 2026-09-21 ("for talkbox yes"): a walker's small talk can be left at once with W, A, S, D or Esc (Bob is frozen while a
## talk box is open, and E next to a walker starts one; that felt like being blocked). Mission conversations (the queue Jijio's question in
## Level 1) stay locked: they need an answer. E still continues line by line.
const T := preload("res://tests/t.gd")


func _walker_talk(key: int, key_name: String, at_second_line: bool) -> void:
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var dialogue = lvl.get_node("Dialogue")
	var p: CharacterBody3D = lvl.get_node("Player")
	await walkers.clear()
	# a standing walker (no job) in corridor A, Bob a clear 0.7 m from it and more than 0.4 m from any stall door (a door within 0.4 m wins the E prompt), made talkable like the real ones
	var w: Node3D = lvl.population.spawn_walker(Vector3(6.0, 0.0, 0.3), 0.0)
	w.set_interaction("E  talk", walkers._talk.bind(w))
	p.global_position = Vector3(6.0, 0.05, -0.4)
	p.set_facing(PI) # toward +Z, at the walker
	await T.wait(self, 0.4)
	var tag := "%s%s" % [key_name, " at the second line" if at_second_line else ""]
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(p.busy and w.talking and dialogue._panel.visible, "%s: E opens the walker's chat, Bob is frozen" % tag)
	if at_second_line:
		await T.key(self, KEY_E)
		await T.wait(self, 0.3)
		T.check(p.busy and dialogue._panel.visible, "%s: the second line (the hint) is showing" % tag)
	await T.key(self, key)
	await T.wait(self, 0.4)
	T.check(not p.busy and not w.talking and not dialogue._panel.visible, "%s: the chat closes at once, Bob and the walker are free" % tag)
	# Bob can really walk again right away
	var before := p.global_position
	Input.action_press("move_left")
	await T.wait(self, 0.4)
	Input.action_release("move_left")
	T.check(p.global_position.distance_to(before) > 0.3, "%s: and Bob walks (%.2f m)" % [tag, p.global_position.distance_to(before)])
	lvl.queue_free()
	await T.wait(self, 0.3)


func _init() -> void:
	seed(71)
	for k: Array in [[KEY_W, "W"], [KEY_A, "A"], [KEY_S, "S"], [KEY_D, "D"], [KEY_ESCAPE, "Esc"]]:
		await _walker_talk(k[0], k[1], false)
	await _walker_talk(KEY_W, "W", true)
	await _walker_talk(KEY_ESCAPE, "Esc", true)

	# E still walks through the walker's two lines and closes the box
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	var walkers = lvl.get_node("Walkers")
	var dialogue = lvl.get_node("Dialogue")
	var p: CharacterBody3D = lvl.get_node("Player")
	await walkers.clear()
	var w: Node3D = lvl.population.spawn_walker(Vector3(6.0, 0.0, 0.3), 0.0)
	w.set_interaction("E  talk", walkers._talk.bind(w))
	p.global_position = Vector3(6.0, 0.05, -0.4)
	p.set_facing(PI)
	await T.wait(self, 0.4)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(p.busy and dialogue._panel.visible, "E advances to the second line")
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(not p.busy and not w.talking, "E on the last line closes the box")
	lvl.queue_free()
	await T.wait(self, 0.3)

	# a mission conversation cannot be skipped: W, A, S, D and Esc do nothing to the queue Jijio's question
	var l1 := T.level(self)
	await T.wait(self, 0.6)
	var d1 = l1.get_node("Dialogue")
	var p1: CharacterBody3D = l1.get_node("Player")
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(p1.busy and d1._panel.visible, "Level 1: E opens the queue Jijio's talk")
	for k: Array in [[KEY_W, "W"], [KEY_A, "A"], [KEY_S, "S"], [KEY_D, "D"], [KEY_ESCAPE, "Esc"]]:
		await T.key(self, k[0])
		await T.wait(self, 0.2)
		T.check(p1.busy and d1._panel.visible, "Level 1: %s does NOT leave the mission conversation" % k[1])
	T.finish(self)
