extends SceneTree
## Owner report 2026-09-25: "in all levels, especially Level 3, the idle Jijio in the walkway tends to block the door and Bob from moving
## past it or into the toilet." Level 3 freezes every walker where it stands for the whole counting phase (hide_seek.gd `_begin` ->
## stop_all), and a walker making way hugs the wall on its own side, which in both corridors is the row of stall doors.
## Here, for ALL 20 stalls (both rows): Level 3 with the walkers on, counting phase, one walker standing in front of the stall's door where
## a stepped-aside walker ends up (0.47 m out from the door line, inside the door leaf's 0.65 m swing). Bob walks up to the door the way a
## player does (from 2 m along the corridor to 1.1 m in front of the door), presses E and walks in. He must be inside within IN_MAX s
## WITHOUT the pass-through safety net (player.gd `_walker_pass_through`: 1.2 s of pushing, which is what the owner felt as "blocked"),
## with the door opened by his FIRST E (the walker must not take the prompt, or stand in the leaf's way).
## Before the fix (2026-09-25): control 0.5 s; Level 3 20 of 20 needed the pass-through (walk-in up to 1.7 s).
## `-- control`: no walker in front of the door (baseline times). `-- flood`: the flood level (walkers keep their jobs and their "E talk").
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

const IN_MAX := 1.2 ## s from reaching the door front to standing inside the stall (the control run takes 0.5 s)
const APPROACH := 1.1 ## m in front of the door line: where Bob stops to open it
const WALKER_OUT := 0.47 ## m out from the door line: where a walker hugging the door-side wall stands


func _yaw_to(p: Node3D, target: Vector3) -> float:
	var d := target - p.global_position
	return atan2(-d.x, -d.z)


## Steer Bob to `target` (real movement key held). Returns the seconds it took, or -1 if not reached in `limit`.
func _walk_to(p: CharacterBody3D, target: Vector3, limit: float) -> float:
	var t := 0.0
	Input.action_press("move_forward")
	while t < limit:
		var flat := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		if flat.length() < 0.12:
			Input.action_release("move_forward")
			return t
		p.set_facing(_yaw_to(p, target))
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")
	return -1.0


func _init() -> void:
	seed(7)
	var control := OS.get_cmdline_user_args().has("control")
	var level2 := OS.get_cmdline_user_args().has("flood") # the flood level (walkers keep their jobs and their "E talk")
	var slowest := 0.0
	var first_e_fails := 0
	var skipped := 0 ## stalls where E went to a level item (Level 2's mop), not a walker
	var met := 0 ## runs where the walker was still within 1 m of the doorway when Bob arrived (the test met the situation)
	for idx in 20:
		Progress.level = T.FLOOD_LEVEL if level2 else T.HIDE_LEVEL
		var lvl := T.level(self, true)
		await T.wait(self, 1.0)
		lvl._time_left = 100000.0
		if lvl.hide_seek:
			lvl.hide_seek.hide_seconds = 100000.0 # stay in the counting phase
		var p: CharacterBody3D = lvl.player
		var pop: Node = lvl.population
		var door: Node3D = lvl.stalls.doors[idx]
		var row := 1 if idx < 10 else 2
		var out := Vector3(0.0, 0.0, 1.0) if row == 1 else Vector3(0.0, 0.0, -1.0) # from the door line into the corridor
		var line := Vector3(door.point.x, 0.0, door.point.z)
		var name := "stall %d (row %d)" % [idx % 10 + 1, row]
		# Every walker far away (the east end), then one in front of this door (or none for the control).
		var walkers: Array = pop.walkers.duplicate()
		T.check(walkers.size() >= 2, "%s: the level has walkers (%d)" % [name, walkers.size()])
		for i in walkers.size():
			var w: Node3D = walkers[i]
			w.global_position = Vector3(-4.6, 0.0, -1.5 + 0.6 * i) # the far corner of the waiting room (they walk back in later)
		var blocker: Node3D = null
		if not control and not walkers.is_empty():
			blocker = walkers[0]
			for w: Node3D in walkers: # not a washer mid-wash: teleported, it would go on "washing" at the door (never happens in the game)
				if lvl.get_node("Walkers").job_of(w) != "wash" and not w.is_washing():
					blocker = w
					break
			if blocker.is_washing():
				blocker.stop_washing()
			blocker.global_position = line + out * WALKER_OUT
		# Bob comes along the corridor from 2 m west (east for the last stall of each row, next to the corridor end).
		var along := -2.0 if idx % 10 >= 2 else 2.0
		var front := line + out * APPROACH
		p.global_position = front + Vector3(along, 0.05, 0.0)
		await T.wait(self, 0.3)
		var t_front := await _walk_to(p, Vector3(front.x, 0.0, front.z), 6.0)
		T.check(t_front >= 0.0, "%s: Bob reaches the door front (%.1f s)" % [name, t_front])
		if blocker and Vector2(blocker.global_position.x - line.x, blocker.global_position.z - line.z).length() < 1.0:
			met += 1
		var push_before: float = p.walker_push_time # pushing along the corridor is test_walkers_stress's business; here only from the door front on
		# Face the door, press E once: the door must open.
		p.set_facing(_yaw_to(p, line))
		await T.wait(self, 0.15)
		var focus_before: String = str(p._focus.name) if p._focus else "none"
		if focus_before != door.name:
			print("INFO  %s: before E Bob's focus is %s (%s), busy %s" % [name, focus_before, p._focus.prompt() if p._focus else "", p.busy])
		await T.key(self, KEY_E)
		await T.wait(self, 0.45)
		var opened: bool = door.is_open
		var other_item := focus_before != door.name and not focus_before.begins_with("@CharacterBody3D") # e.g. Level 2's mop lying there: by design
		if not opened and other_item:
			skipped += 1
			print("INFO  %s: E went to another item, not a walker (%s): stall skipped" % [name, focus_before])
			lvl.queue_free()
			await T.wait(self, 0.3)
			continue
		if not opened:
			first_e_fails += 1
			await T.key(self, KEY_E) # a second try, so the walk-in is still measured
			await T.wait(self, 0.45)
		T.check(opened, "%s: Bob's first E opens the door (focus was %s; busy %s frozen %s; Bob to door %.2f m)" % [name, str(p._focus.name) if p._focus else "none", p.busy, p.frozen, Vector2(p.global_position.x - line.x, p.global_position.z - line.z).length()])
		var inside := line - out * 0.55
		var t_in := await _walk_to(p, Vector3(inside.x, 0.0, inside.z), IN_MAX)
		if t_in < 0.0:
			for w: Node3D in pop.walkers:
				print("INFO  %s: walker %s at (%.2f, %.2f) state %d, %.2f m from Bob" % [name, lvl.get_node("Walkers").job_of(w), w.global_position.x, w.global_position.z, w.state, Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length()])
		if t_in < 0.0 or idx in [0, 9, 10, 19]:
			var wpos := blocker.global_position if blocker else Vector3.ZERO
			var wstate: String = "state %d job %s parked %s" % [blocker.state, lvl.get_node("Walkers").job_of(blocker), lvl.get_node("Walkers").is_parked(blocker)] if blocker else ""
			print("INFO  %s: Bob at (%.2f, %.2f) aiming (%.2f, %.2f); walker at (%.2f, %.2f) %s; door open %s; pushing %.1f s" % [name, p.global_position.x, p.global_position.z, inside.x, inside.z, wpos.x, wpos.z, wstate, door.is_open, p.walker_push_time - push_before])
		T.check(t_in >= 0.0, "%s: Bob gets into the stall within %.1f s (%.1f s)" % [name, IN_MAX, t_in])
		# the old check was "no pass-through" (Bob blocked 1.2 s at the door); the same bar now: under 1.2 s of shoving a walker
		T.check(p.walker_push_time - push_before < 1.2, "%s: walkers keep out of the door, Bob need not shove one there (%.1f s of pushing)" % [name, p.walker_push_time - push_before])
		if t_in >= 0.0:
			slowest = maxf(slowest, t_in)
		lvl.queue_free()
		await T.wait(self, 0.3)
	print("INFO  %s: slowest walk-in %.1f s; first E did not open the door %d of 20; walker still at the doorway when Bob arrived %d of 20; skipped (a level item took E) %d" % ["control" if control else ("flood level" if level2 else "hide-and-seek level"), slowest, first_e_fails, met, skipped])
	T.check(skipped <= 2, "at most 2 of 20 stalls skipped (%d)" % skipped)
	T.finish(self)
