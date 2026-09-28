extends SceneTree
## TEMPLATE for a new test (copy to tests/test_<name>.gd, add the name to FAST_TESTS in tests/run.sh). Not run by run.sh.
## Run one by hand, ALWAYS with a timeout (a script error inside a test never calls quit and hangs):
##   timeout 120 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_<name>.gd [-- walkers seeds=4 first=1]
## Checklist (skill references/testing.md): write the test BEFORE the code and watch it fail; test EVERY instance of anything repeated; print
## how often the test met the situation; give a "sooner/more often" check a control run without the effect; sabotage the fix once.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")


func _init() -> void:
	seed(1)
	Progress.level = 1 # 1-5; use T.HIDE_LEVEL / T.FLOOD_LEVEL, never a bare 2 or 3 (or pass `-- flood` to T.level)
	var lvl := T.level(self) # add `true` (or `-- walkers`) for the walking Jijios
	await T.wait(self, 0.8) # the navmesh and the walkers need a moment
	lvl._time_left = 100000.0 # a long test must park the level timer, or the timeout kick fires mid-test
	var p: CharacterBody3D = lvl.player

	# Untyped access gives Variants: write the type (`var x: float = lvl.thing`), `:=` is a parse error there.
	T.check(p != null, "the player exists")

	# Real key presses: await T.key(self, KEY_E); wait for a frame that updates things before you read them.
	lvl.queue_free()
	await process_frame
	T.finish(self)
