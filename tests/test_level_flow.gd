extends SceneTree
## Moving between levels with the real keys: N after winning Level 1 loads Level 2 (hide and seek, 90 s), R after a loss retries
## the same level, F4 (debug) jumps to the next level (Level 3 = the flood, 150 s) and wraps around to 1. The order is the owner's
## (SPEC "Stage 6b", asked twice: SWAP LEVELS 2 AND 3). This also proves the static Progress.level survives reloading the scene.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")


func _init() -> void:
	seed(41)
	# The order as data (owner, Stage 6b): 2 = hide and seek 90 s, 3 = the flood 150 s.
	var l2 := LevelDefs.get_level(2)
	var l3 := LevelDefs.get_level(3)
	T.check(l2["name"] == "Hide and seek" and l2["time"] == 90.0 and l2.get("hide_seek", false) and l2.get("intro", "") == "ghost",
			"Level 2 is hide and seek, 90 s, with the ghost intro")
	T.check(l3["name"] == "The flood" and l3["time"] == 150.0 and l3.get("rising", false) and l3.get("intro", "") == "flood",
			"Level 3 is the flood, 150 s, with the flood intro")

	Progress.level = 1
	var lvl := T.level(self)
	current_scene = lvl # so reload_current_scene() works in a script test
	await T.wait(self, 0.6)
	T.check(lvl.level_number == 1 and lvl.flood == null and lvl.hide_seek == null, "level 1 has no flood and no hide and seek")

	lvl._on_finished() # win Level 1
	T.check(lvl._result.text.contains("N: next level"), "the win screen offers the next level ('%s')" % lvl._result.text.replace("\n", " | "))
	await T.key(self, KEY_N)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(Progress.level == 2 and lvl.level_number == 2 and lvl.hide_seek != null and lvl.flood == null and lvl._time_left > 88.0,
			"N loads Level 2 = hide and seek, no flood, 90 s (%.1f left)" % lvl._time_left)
	T.check(lvl.get_node("HUD/MissionLabel").text.contains("LEVEL 2: Hide and seek"), "the checklist shows 'LEVEL 2: Hide and seek'")

	lvl._game_over = true # lose Level 2
	await T.key(self, KEY_R)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 2 and lvl.hide_seek != null and lvl.hide_seek.catches == 0, "R retries Level 2 (a fresh round)")

	await T.key(self, KEY_F4)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 3 and lvl.water != null and lvl.flood_story.is_started and lvl.hide_seek == null and lvl._time_left > 148.0,
			"F4 from Level 2 jumps to Level 3 = the flood, 150 s (%.1f left)" % lvl._time_left)
	T.check(lvl.get_node("HUD/MissionLabel").text.contains("LEVEL 3: The flood"), "the checklist shows 'LEVEL 3: The flood'")
	lvl._game_over = true # lose Level 3
	await T.key(self, KEY_R)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 3 and lvl.water != null and lvl.flood_story.is_started and lvl.water.depth < 0.1, "R retries Level 3 (fresh flood)")
	lvl._on_finished() # win Level 3: N goes on to Level 4
	await T.key(self, KEY_N)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 4 and lvl.cutters != null and lvl.water == null and lvl._time_left > 148.0,
			"N after Level 3 loads Level 4 (the cutters, 150 s; %.1f left)" % lvl._time_left)
	await T.key(self, KEY_F4)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 5 and lvl.dance != null and lvl.cutters == null and lvl._time_left > 73.0,
			"F4 from Level 4 jumps to Level 5 (the dance battle, 75 s; %.1f left)" % lvl._time_left)
	await T.key(self, KEY_F4)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 1 and lvl.flood == null and lvl.hide_seek == null and lvl.cutters == null and lvl.dance == null, "F4 after the last level wraps around to Level 1")
	await T.key(self, KEY_F4)
	await T.wait(self, 0.8)
	lvl = current_scene
	T.check(lvl.level_number == 2 and lvl.hide_seek != null and lvl.water == null, "F4 from Level 1 jumps to Level 2 (hide and seek)")
	T.finish(self)
