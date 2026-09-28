extends SceneTree
## NOT a test (not in run.sh): does 75 s fit Level 5 for a person? Adds up, per stall (all 20), the real navmesh walking distances at
## Bob's sprint (5 m/s) with perfect steering: spawn -> her (she is 0.55 m out from the stall's door) and the ring's centre -> the stall's
## use spot; plus fixed times measured in test_level5_chain (the rush + fade + "DANCE BATTLE!" + round starts) and a person's reading pace
## for the talks. A lower bound: a person also has to SEARCH for her (the checklist does not say where she is).
##   godot --headless --path . --fixed-fps 60 --script tests/measure_level5_time.gd
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Battle := preload("res://scripts/dance_battle.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")

const SPRINT := 5.0
const TALKS := 12.0 ## finesse talk (3 lines + a choice) and her talk (a choice + a line) at about 2 s per box
const RUSH := 2.2 + 0.7 + 1.6 + 0.6 ## rush, fade out/in, "DANCE BATTLE!", waiting for the first beat (dance.gd)
const TIME := 75.0


func _init() -> void:
	Progress.level = 5
	var round_s := Battle.ROUND_BEATS * DanceBeat.beat_seconds()
	var worst := 0.0
	var best := INF
	for stall in 20:
		Dance.force_stall = stall
		var lvl := T.level(self)
		await T.wait(self, 0.6)
		var map: RID = lvl.get_node("NavRegion").get_navigation_map()
		var d: Node = lvl.dance
		var her: Vector3 = d.queen.global_position
		var to_her := _path(map, lvl.player.global_position, her + Vector3(d.out) * 0.6)
		var door: Node3D = lvl.stalls.doors[stall]
		var out: Vector3 = d.out
		var use_spot: Vector3 = Vector3(door.point.x, 0.0, door.point.z) + out * 0.6
		var back := _path(map, Dance.BOB_SPOT, use_spot)
		var walk := (to_her + back) / SPRINT
		var two_nil := walk + TALKS + RUSH + 2.0 * round_s
		var two_one := two_nil + round_s
		worst = maxf(worst, two_one)
		best = minf(best, two_nil)
		print("stall %2d row %d: to her %4.1f m, back %4.1f m = %4.1f s sprinting | won 2-0: %4.1f s, 2-1: %4.1f s of %.0f" % [stall % 10 + 1,
				1 if stall < 10 else 2, to_her, back, walk, two_nil, two_one, TIME])
		lvl.queue_free()
		await process_frame
		await physics_frame
	print("INFO  best case %.1f s (2-0, nearest stall), worst %.1f s (2-1, farthest), before any searching or a lost battle; the timer is %.0f s" % [best, worst, TIME])
	Dance.force_stall = -1
	quit()


func _path(map: RID, a: Vector3, b: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	return length
