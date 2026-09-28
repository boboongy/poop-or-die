extends SceneTree
## Bob spawns boxed in by the queue lines. Walking east must open a gap (make-way) so he reaches the door
## quickly, and every queue Jijio must be back on its own spot afterwards. If this fails Bob is soft-locked.
const T := preload("res://tests/t.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var pop: Node3D = lvl.get_node("Population")
	var p: CharacterBody3D = lvl.get_node("Player")
	Input.action_press("move_forward") # the camera looks east at spawn
	var ticks := 0
	var max_shift := 0.0
	while p.global_position.x < 1.0 and ticks < 900:
		await T.wait(self, 1.0 / 60.0)
		ticks += 1
		for n in pop.queue:
			max_shift = maxf(max_shift, Vector2(n.global_position.x - n.home.x, n.global_position.z - n.home.z).length())
	Input.action_release("move_forward")
	T.check(p.global_position.x >= 1.0, "Bob walked through the queue to the corridor in %.1f s" % (ticks / 60.0))
	T.check(ticks / 60.0 < 6.0, "under 6 s (not stuck)")
	T.check(max_shift > 0.2, "queue Jijios stepped aside (max %.2f m)" % max_shift)
	p.global_position = Vector3(4.0, 0.05, 0.4)
	await T.wait(self, 4.0)
	var worst := 0.0
	for n in pop.queue:
		worst = maxf(worst, Vector2(n.global_position.x - n.home.x, n.global_position.z - n.home.z).length())
	T.check(worst < 0.1, "every queue Jijio is back on its spot after 4 s (worst %.2f m)" % worst)
	T.finish(self)
