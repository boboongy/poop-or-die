extends SceneTree
## Owner 2026-09-25: "Level 4 took them a while before the kick-out even when the game is over". The result screen used to wait
## for 5 kickers to REACH Bob plus 3 s (up to 15 s + 3 s when Bob stood at the far east end, where the fights are).
## In EVERY level (1-5) and from three places, "THEY KICKED YOU OUT" must show within KICKOUT_MAX s of the clock hitting 0.
## Prints each case's time.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

const KICKOUT_MAX := 2.5
const SPOTS := {"far east (fight stage)": Vector3(11.0, 0.05, -2.5), "corridor B": Vector3(3.0, 0.05, -5.2), "spawn": Vector3(-3.7, 0.05, 0.4)}


func _init() -> void:
	var slowest := 0.0
	for level in [1, 2, 3, 4, 5]:
		for label in SPOTS:
			Progress.level = level
			var lvl := T.level(self)
			await T.wait(self, 0.5)
			var p: CharacterBody3D = lvl.get_node("Player")
			p.global_position = SPOTS[label]
			await T.wait(self, 0.2)
			lvl._time_left = 0.05
			await T.wait_for(self, func() -> bool: return lvl._time_left <= 0.0, 2.0)
			var ticks := 0
			while ticks < 60 * 25 and not lvl._result.visible:
				await physics_frame
				ticks += 1
			var took := ticks / 60.0
			slowest = maxf(slowest, took)
			T.check(lvl._result.visible and lvl._result.text.begins_with("THEY KICKED YOU OUT") and took <= KICKOUT_MAX, "level %d, Bob at %s: kicked out after %.1f s" % [level, label, took])
			lvl.queue_free()
			await T.wait(self, 0.1)
	Progress.level = 1
	print("INFO  slowest kick-out %.1f s (limit %.1f s)" % [slowest, KICKOUT_MAX])
	T.finish(self)
