extends SceneTree
## Level 4 on EVERY stall of one row (`-- row1` or `-- row2`; both run in run.sh): the level opens that stall (door open, its Jijio
## goes to wash across the corridor) and the three cutters must all reach their spots in front of that door. Found by the chain test:
## the open door leaf (0.65 m into the corridor, not in the navmesh) and the washing Jijio each jammed a cutter on some stalls.
## Prints each stall's arrival time (level clock) and the slowest.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")


func _init() -> void:
	Progress.level = 4
	seed(7)
	var row := 2 if OS.get_cmdline_user_args().has("row2") else 1
	var slowest := 0.0
	var ok := 0
	for k in 10:
		var stall := (row - 1) * 10 + k
		Cutters.force_stall = stall
		var lvl := T.level(self)
		await T.wait(self, 0.5)
		var cm: Node = lvl.cutters
		var door: Node3D = lvl.stalls.doors[stall]
		var start: float = lvl._time_left
		await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 45.0)
		var took: float = start - lvl._time_left + 0.5
		var placed: bool = cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting")
		var worst := 0.0
		for i in cm.cutters.size():
			var b: Node3D = cm.cutters[i]["body"]
			var spot: Vector3 = cm.spots[i]
			worst = maxf(worst, Vector2(b.global_position.x - spot.x, b.global_position.z - spot.z).length())
			if not placed:
				print("  stall %d: %s %s at %s, spot %s" % [stall, cm.cutters[i]["name"], cm.cutters[i]["state"], b.global_position, spot])
		T.check(placed and worst < 0.4 and door.is_open, "stall %d (row %d): door open, all three at their spots after %.1f s of the level (worst %.2f m off)" % [k + 1, row, took, worst])
		if placed:
			ok += 1
			slowest = maxf(slowest, took)
		lvl.queue_free()
		await process_frame
		await physics_frame
	print("INFO  row %d: %d of 10 stalls blocked; slowest arrival %.1f s into the level (90 s level)" % [row, ok, slowest])
	Cutters.force_stall = -1
	T.finish(self)
