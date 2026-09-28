extends SceneTree
## Timeout: from three places the result screen must appear within 20 s, and 4 stall Jijios must have
## left their stalls to join the queue.
const T := preload("res://tests/t.gd")


func _case(label: String, bob_pos: Vector3) -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var pop: Node3D = lvl.get_node("Population")
	var p: CharacterBody3D = lvl.get_node("Player")
	p.global_position = bob_pos
	await T.wait(self, 0.2)
	lvl._time_left = 0.05
	var ticks := 0
	while ticks < 60 * 25 and not lvl._result.visible:
		await T.wait(self, 0.1)
		ticks += 6
	T.check(lvl._result.visible, "%s: result screen appears (%.1f s)" % [label, ticks / 60.0])
	T.check(ticks / 60.0 < 20.0, "%s: within 20 s" % label)
	var out := 0
	var clogger: int = lvl.ctx.get("clogged", -1) if lvl.flood_story != null else -1 # Level 2: the clogger ran out at GO, not to kick
	for i in pop.occupants.size():
		if not pop.occupants[i].is_sitting() and i != clogger:
			out += 1
	T.check(out == 4, "%s: 4 stall Jijios left their stalls (%d)" % [label, out])
	T.check(lvl._result.text.begins_with("THEY KICKED YOU OUT"), "%s: kicked-out text" % label)
	lvl.queue_free()
	await T.wait(self, 0.1)


func _init() -> void:
	await _case("Bob far east of corridor A", Vector3(11.0, 0.05, 0.5))
	await _case("Bob in corridor B", Vector3(3.0, 0.05, -5.2))
	await _case("Bob at spawn", Vector3(-3.7, 0.05, 0.4))
	T.finish(self)
