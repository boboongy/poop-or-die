extends SceneTree
## SLOW (about 5 minutes). For EVERY stall: when it is the reward stall, its Jijio must stand up, leave through
## the doorway, walk to the sink and start washing within 45 s. (One sample stall hides doorway bugs: this
## once failed for 4 of 20 stalls while the samples passed.)
const T := preload("res://tests/t.gd")


func _init() -> void:
	for idx in range(20):
		var lvl := T.level(self)
		await T.wait(self, 0.4)
		var pop: Node3D = lvl.get_node("Population")
		var npc = pop.occupants[idx]
		pop.reward_release(idx) # not awaited: we watch the Jijio
		var ticks := 0
		while npc.state != 6 and ticks < 60 * 45: # 6 = WASH
			await T.wait(self, 0.2)
			ticks += 12
		T.check(npc.state == 6, "stall %d (row %d #%d) reached its sink and is washing (%.1f s)" % [idx, 1 if idx < 10 else 2, idx % 10 + 1, ticks / 60.0])
		lvl.queue_free()
		await T.wait(self, 0.1)
	T.finish(self)
