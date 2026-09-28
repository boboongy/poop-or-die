extends SceneTree
## Level 4 fail paths in the real level: (1) Bob KO'd in a fist fight -> "KNOCKED OUT!" (timer stopped, Bob's own camera on, normal
## time), R reloads Level 4; (2) the same in WATER WAR (shooter.gd), where "K.O." holds KO_SECONDS first (owner D); (3) the timer runs
## out MID fist fight and (4) MID WATER WAR -> the fight is aborted at once (Bob's camera, controls, normal time and third person back,
## walkers shown again, no E prompt on the cutters) and the usual kick-out screen follows.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Shooter := preload("res://scripts/shooter.gd")

const STALL := 3


func _level() -> Node:
	var lvl := T.level(self, true) # walkers on: they are hidden during a fight and must come back after an abort
	current_scene = lvl
	await T.wait(self, 0.8)
	return lvl


## Start the fight with cutter `i` straight away (the argument is covered by test_cutters / test_level4_chain); for BOSSY the other
## two count as down first.
func _fight(lvl: Node, i: int) -> Node:
	var cm: Node = lvl.cutters
	await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 30.0)
	if i == 2:
		cm.fights_won = 2
	cm._start_fight(i)
	var f: Node = cm.fight
	await T.wait_for(self, func() -> bool: return f.fighting(), 3.0)
	return f


func cm_fight(lvl: Node) -> Node:
	return lvl.cutters.fight


func _check_handed_back(lvl: Node, what: String) -> void:
	var p = lvl.player
	var own: Camera3D = p.get_node("CameraPivot/SpringArm3D/Camera3D")
	T.check(p.get_viewport().get_camera_3d() == own, "%s: Bob's own camera is on" % what)
	T.check(is_equal_approx(Engine.time_scale, 1.0) and p.shoulder == 0.0, "%s: normal time, camera behind Bob" % what)
	var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
	T.check(arm.spring_length > 2.1 and p.model().is_visible_in_tree(), "%s: third person, Bob visible (arm %.2f)" % [what, arm.spring_length])
	var prompts: Array = lvl.cutters.cutters.filter(func(c: Dictionary) -> bool: return c["body"].is_in_group("interactable") and c["state"] != "waiting")
	T.check(prompts.is_empty(), "%s: no E prompt on a cutter who fought or is down (%s)" % [what, prompts.map(func(c: Dictionary) -> String: return c["name"])])


func _init() -> void:
	Progress.level = 4
	Cutters.force_stall = STALL
	seed(3)

	# 1 + 2. KO'd in a fist fight, then in the water fight
	for i: int in [0, 2]:
		var what := "KO'd by %s" % Cutters.DEFS[i]["name"]
		var lvl: Node = await _level()
		lvl._time_left = 100000.0
		var f: Node = await _fight(lvl, i)
		if i == 2:
			f.bob_hp = 1.0 # the crew shoot Bob standing at the start
			f.since_hit = -1000.0 # no regen
			await T.wait_for(self, func() -> bool: return not is_instance_valid(f) or f.over, 20.0) # freed = it ended at once (a bug)
			var ko_up: bool = is_instance_valid(f) and f.over and f.hud.big.text == "K.O." and not lvl._result.visible
			T.check(ko_up, "%s: K.O. first, no fail screen yet" % what)
			if ko_up:
				await T.wait(self, Shooter.KO_SECONDS - 0.2)
				T.check(not lvl._result.visible and is_instance_valid(f) and cm_fight(lvl) == f, "%s: K.O. still up %.1f s later" % [what, Shooter.KO_SECONDS - 0.2])
		else:
			f.bob.hp = 1.0
		await T.wait_for(self, func() -> bool: return lvl._result.visible, 20.0)
		await T.wait(self, 0.4) # the camera's 0.3 s slide back to third person
		T.check(lvl._result.visible and lvl._result.text.begins_with("KNOCKED OUT!"), "%s: fail screen ('%s')" % [what, lvl._result.text.replace("\n", " | ")])
		T.check(not lvl._running and lvl._game_over, "%s: the timer stopped" % what)
		_check_handed_back(lvl, what)
		await T.key(self, KEY_R)
		await T.wait(self, 0.8)
		var fresh: Node = current_scene
		T.check(fresh != lvl and fresh.level_number == 4 and fresh.cutters != null and fresh.cutters.fights_won == 0, "%s: R reloads Level 4 from the start" % what)
		fresh.queue_free()
		await process_frame
		await physics_frame

	# 3 + 4. the timer runs out mid-fight
	for i: int in [0, 2]:
		var what := "timeout mid-fight with %s" % Cutters.DEFS[i]["name"]
		var lvl: Node = await _level()
		lvl._time_left = 100000.0
		var f: Node = await _fight(lvl, i)
		f.ai_enabled = false
		lvl._time_left = 0.05
		await T.wait(self, 0.2)
		T.check(lvl.cutters.fight == null and not is_instance_valid(f), "%s: the fight is aborted (and freed with its HUD)" % what)
		await T.wait(self, 0.3) # the camera's slide back to third person
		_check_handed_back(lvl, what)
		T.check(lvl.population.walkers.all(func(w: Node3D) -> bool: return w.visible), "%s: walkers shown again" % what)
		await T.wait_for(self, func() -> bool: return lvl._result.visible, 25.0)
		T.check(lvl._result.text.begins_with("THEY KICKED YOU OUT"), "%s: the kick-out screen ('%s')" % [what, lvl._result.text.replace("\n", " | ")])
		lvl.queue_free()
		await process_frame
		await physics_frame

	Cutters.force_stall = -1
	T.finish(self)
