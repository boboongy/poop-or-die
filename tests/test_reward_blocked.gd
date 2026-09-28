extends SceneTree
## The freed Jijio must get out even when Bob stands in front of its door. Owner report 2026-09-21: "I mopped all the puddles but still get
## kicked". Measured with a walking bot (tests/measure_flood_time.gd, 32 runs): in one, Bob finished mopping in front of the reward stall,
## the freed Jijio could not get past him (Jijios are solid), `Population.reward_release` waits until the Jijio is 1.1 m from the doorway,
## so "the stall is free" never came and the timer ran out. Here, for ALL 20 stalls: the level says all missions are done, Bob stands still
## 1 m in front of the reward door, and within 8 s the level must announce the free stall; Bob is not shoved and no collision exception is
## left behind afterwards.
const T := preload("res://tests/t.gd")

const WAIT_MAX := 8.0 ## seconds allowed for the Jijio to get out (with a clear door it takes about 2 s)


func _init() -> void:
	seed(5)
	var slowest := 0.0
	for idx in 20:
		var lvl := T.level(self)
		await T.wait(self, 0.6)
		lvl._time_left = 100000.0
		var p: CharacterBody3D = lvl.get_node("Player")
		var pop: Node3D = lvl.get_node("Population")
		var only: Array[int] = []
		for i in 20:
			if i != idx:
				only.append(i)
		pop.blocked_stalls.assign(only) # pick_free_stall can now only return `idx`
		var door: Node3D = lvl.stalls.doors[idx]
		var dir := Vector3(0.0, 0.0, 1.0) if idx < 10 else Vector3(0.0, 0.0, -1.0) # doors open toward +Z (row 1) / -Z (row 2)
		var away := OS.get_cmdline_user_args().has("away") # control: Bob far from the door, nothing may block the Jijio
		# Row 1: the sink is straight ahead, so the Jijio walks out along +Z. Row 2: it walks out diagonally toward the east (the
		# corridors join at the east end); measured with the control run: it leaves the doorway toward (+1.05, -0.36).
		var in_the_way := Vector3(door.point.x, 0.05, door.point.z) + dir * 1.0 if idx < 10 else Vector3(door.point.x + 0.85, 0.05, door.point.z - 0.29)
		p.global_position = Vector3(-3.7, 0.05, 0.4) if away else in_the_way
		p.face_direction(-dir)
		await T.wait(self, 0.3)
		var placed: Vector3 = p.global_position
		lvl._on_all_missions_done()
		var label: Label = lvl.get_node("HUD/MissionLabel")
		var t := 0.0
		while not label.text.contains("is free") and t < WAIT_MAX:
			await T.wait(self, 0.1)
			t += 0.1
		var npc: Node3D = pop.occupants[idx]
		if idx == 0 or idx == 10 or idx == 5 or idx == 15:
			print("INFO  stall index %d: door.point (%.2f, %.2f), Bob placed at (%.2f, %.2f), Jijio ended at (%.2f, %.2f), Bob at (%.2f, %.2f)" % [idx, door.point.x, door.point.z, placed.x, placed.z, npc.global_position.x, npc.global_position.z, p.global_position.x, p.global_position.z])
		var name :="stall %d (row %d)" % [idx % 10 + 1, 1 if idx < 10 else 2]
		var free := label.text.contains("is free")
		T.check(free, "%s: Bob stands in the Jijio's way, the stall is still announced free (%.1f s; '%s')" % [name, t, label.text.replace("\n", " | ")])
		if free:
			slowest = maxf(slowest, t)
		T.check(placed.distance_to(p.global_position) < 0.2, "%s: Bob was not shoved (moved %.2f m)" % [name, placed.distance_to(p.global_position)])
		p.global_position = Vector3(-3.7, 0.05, 0.4) # Bob walks off (into the stall in the real game): the exceptions must clear themselves
		await T.wait(self, 0.5)
		T.check(p.get_collision_exceptions().is_empty() and npc.get_collision_exceptions().is_empty(), "%s: once Bob has left, no collision exception is left behind" % name)
		lvl.queue_free()
		await T.wait(self, 0.3)
	print("INFO  slowest announcement over 20 stalls: %.1f s" % slowest)
	T.finish(self)
