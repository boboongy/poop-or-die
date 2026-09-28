extends SceneTree
## NOT a test (not in run.sh): how long does a person need to get hidden in hide and seek (Level 2 since Stage 6b)? The counting lasts 12 s. This measures the real
## navmesh walking distance from Bob's spawn to the front of each of the 20 stalls and converts it to time at walk (3 m/s) and sprint
## (5 m/s) speed, plus a fixed time for what he must then do (numbers from the chain test, real key presses at a person's pace):
##   empty stall:    open the door 0.4 s, step in 0.5 s, close it 0.4 s, climb (E) 0.5 s  = 1.8 s (+ about 1 s for a person to react)
##   occupied stall: the same + the shush talk (E, E, 1, E about 4 key presses at 0.8 s = 3.2 s) = 5 s (+ 1 s)
##   godot --headless --path . --fixed-fps 60 --script tests/measure_hide_time.gd
## It WALKS NOTHING: a straight-line-of-the-navmesh estimate with perfect steering and no aiming, so a real player needs more.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

const WALK := 3.0
const SPRINT := 5.0
const EMPTY_ACTIONS := 2.8
const OCCUPIED_ACTIONS := 6.0
const COUNT := 12.0


func _init() -> void:
	Progress.level = T.HIDE_LEVEL
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	var map: RID = lvl.get_node("NavRegion").get_navigation_map()
	var start: Vector3 = lvl.player.global_position
	var nav_y: float = lvl.population.nav_height()
	var walk_ok := 0
	var sprint_ok := 0
	var worst_walk := 0.0
	for i in 20:
		var door: Node3D = lvl.stalls.doors[i]
		var outward := Vector3(0.0, 0.0, 0.7) if i < 10 else Vector3(0.0, 0.0, -0.7)
		var goal := Vector3(door.point.x, nav_y, door.point.z) + outward
		var path := NavigationServer3D.map_get_path(map, Vector3(start.x, nav_y, start.z), goal, true)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		var occupied_actions := OCCUPIED_ACTIONS
		var tw := length / WALK + occupied_actions
		var ts := length / SPRINT + occupied_actions
		var te_w := length / WALK + EMPTY_ACTIONS
		var te_s := length / SPRINT + EMPTY_ACTIONS
		print("INFO  stall %2d (row %d no %2d): path %5.1f m | walk: empty %4.1f s, occupied %4.1f s | sprint: empty %4.1f s, occupied %4.1f s" % [i, 1 if i < 10 else 2, i % 10 + 1, length, te_w, tw, te_s, ts])
		if tw <= COUNT:
			walk_ok += 1
		if ts <= COUNT:
			sprint_ok += 1
		worst_walk = maxf(worst_walk, tw)
	print("INFO  of 20 stalls, hidden within %.0f s WALKING (occupied stall, with the talk): %d; SPRINTING: %d; the farthest needs %.1f s walking" % [COUNT, walk_ok, sprint_ok, worst_walk])
	quit(0)
