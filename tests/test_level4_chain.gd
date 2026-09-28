extends SceneTree
## Level 4 from the first second to the win screen, in game time with real keys and clicks, once on a row-1 stall and once on a
## row-2 stall: one stall opens at the start (door open, its Jijio leaves), the mission is on the list, the three cutters walk in and
## block that door, the stall cannot be used yet; argue + win each fight (fist fights shortened by setting the cutter to 1 hp, FINISH
## HIM on the 2nd; WATER WAR for real: the perfect-aim bot (tests/war_bot.gd) against the live crew and BOSSY until SOAKED!); then the same stall is
## announced free, Bob sits (the timer stops), wipes, flushes, "LEVEL 4 COMPLETE". `-- walkers` runs it with the walking Jijios.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Shooter := preload("res://scripts/shooter.gd")
const WarBot := preload("res://tests/war_bot.gd")

var lvl: Node
var p: CharacterBody3D
var prompt: Label
var mission: Label


func _init() -> void:
	Progress.level = 4
	seed(4)
	await _run(4)
	await _run(16)
	Cutters.force_stall = -1
	T.finish(self)


## Bob stands in the corridor in front of the cutter, facing them, until his E prompt names them.
func _face(body: Node3D, out: Vector3, cname: String) -> bool:
	var at: Vector3 = body.global_position + out * 0.85
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-out)
	await T.wait(self, 0.3)
	return prompt.text.contains(cname)


func _run(stall: int) -> void:
	var tag := "stall %d (row %d)" % [stall % 10 + 1, 1 if stall < 10 else 2]
	Cutters.force_stall = stall
	lvl = T.level(self)
	current_scene = lvl
	await T.wait(self, 0.8)
	p = lvl.player # after the wait: the first level is added during _init, its _ready (and @onready) runs later
	prompt = lvl.get_node("HUD/PromptLabel")
	mission = lvl.get_node("HUD/MissionLabel")
	var sess = lvl.get_node("ToiletSession")
	sess.poop_seconds = 0.5
	var cm: Node = lvl.cutters
	var out := Vector3(0.0, 0.0, 1.0) if stall < 10 else Vector3(0.0, 0.0, -1.0)
	var door: Node3D = lvl.stalls.doors[stall]
	print("INFO  %s: %d walkers on" % [tag, lvl.population.walkers.size()])

	# 1. the start: Level 4, 150 s (SPEC Stage 4, was 90), the stall open and emptied, the mission listed
	T.check(lvl.level_number == 4 and cm != null and lvl.ctx.get("open_stall", -1) == stall, "%s: Level 4 with the cutters, this stall open" % tag)
	T.check(lvl._time_left > 148.0 and lvl._time_left <= 150.0, "%s: 150 s on the clock (%.1f left)" % [tag, lvl._time_left])
	T.check(door.is_open, "%s: its door is open" % tag)
	T.check(mission.text.contains("LEVEL 4") and mission.text.contains("Stop the queue cutters"), "%s: the mission is listed ('%s')" % [tag, mission.text.replace("\n", " | ")])
	await T.wait(self, 3.0)
	T.check(not lvl.population.occupants[stall].is_sitting(), "%s: its Jijio has left the seat" % tag)

	# 2. the cutters walk in and block that door; the stall is not usable yet
	var t_start: float = lvl._time_left
	await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 40.0)
	var placed: bool = cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting")
	print("INFO  %s: the cutters stand at the door with %.1f s left (%.1f s after the check started)" % [tag, lvl._time_left, t_start - lvl._time_left])
	T.check(placed, "%s: all three cutters reached the door" % tag)
	if not placed:
		for c: Dictionary in cm.cutters:
			var b: Node3D = c["body"]
			print("  %s state %s at %s, spot %s" % [c["name"], c["state"], b.global_position, cm.spots[cm.cutters.find(c)]])
		lvl.queue_free()
		await process_frame
		return
	for c: Dictionary in cm.cutters:
		var b: Node3D = c["body"]
		var d := Vector2(b.global_position.x - door.point.x, b.global_position.z - door.point.z).length()
		T.check(d < 1.2, "%s: %s stands in front of the door (%.2f m)" % [tag, c["name"], d])
	T.check(mission.text.contains("press E on one to argue"), "%s: the hint says what to do ('%s')" % [tag, mission.text.replace("\n", " | ")])
	T.check(not mission.text.contains("is free") and sess._use_spot == null, "%s: the stall is not usable while they block it" % tag)

	# 3. the three fights
	var n := 0
	for cname: String in ["PUSHY", "SNEAKY", "BOSSY"]:
		n += 1
		var c: Dictionary = cm.cutter(cname)
		T.check(await _face(c["body"], out, cname), "%s: E prompt names %s ('%s')" % [tag, cname, prompt.text])
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		await T.key(self, KEY_1)
		await T.wait(self, 0.2)
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		var f: Node = cm.fight
		T.check(f != null, "%s: fight %d against %s starts" % [tag, n, cname])
		if f == null:
			continue
		await T.wait_for(self, func() -> bool: return f.fighting(), 3.0)
		if n < 3:
			f.ai_enabled = false
			f.foe.pos = f.bob.pos + 0.7
			f.foe.hp = 1.0
			await T.key(self, KEY_SPACE)
			if n == 2:
				await T.wait_for(self, func() -> bool: return f.foe.is_dizzy(), 2.0)
				await T.wait(self, 0.3)
				await T.key(self, KEY_SPACE)
		else:
			T.check(f.get_script() == Shooter, "%s: BOSSY's round is WATER WAR" % tag)
			var clock0: float = lvl._time_left
			# the open stall's Jijio washes at a sink in corridor A (the arena): out of the way during the war (first screenshot pass)
			var washers: Array = cm.pass_through.filter(func(n: Node3D) -> bool: return is_instance_valid(n))
			T.check(not washers.is_empty() and washers.all(func(n: Node3D) -> bool: return not n.visible and n.collision_layer == 0),
				"%s: the open stall's Jijio is out of the arena during the war (%d)" % [tag, washers.size()])
			var bot := WarBot.new(self, f)
			var r: Dictionary = await bot.play(120.0)
			for line in bot.log_lines:
				print("INFO  %s bot: %s" % [tag, line])
			print("INFO  %s: WATER WAR by the perfect-aim bot: won %s in %.1f s (+%.1f s intro), Bob %.0f hp left, %d shots, %d hoses, %d refills, %d barks %s" % [
				tag, r["won"], r["seconds"] - Shooter.INTRO_SECONDS, Shooter.INTRO_SECONDS, r["hp"], r["shots"], r["hoses"], r["refills"], f.barks.size(),
				f.barks.map(func(b: Dictionary) -> String: return "%s:%s@%.1f" % [b["who"], b["kind"], b["t"]])])
			T.check(r["won"], "%s: the bot wins WATER WAR (%s)" % [tag, r])
			T.check(f.hud.big.text == "SOAKED!", "%s: SOAKED! on the screen" % tag)
			var gaps: Array = []
			for k in range(1, f.barks.size()):
				gaps.append(f.barks[k]["t"] - f.barks[k - 1]["t"])
			T.check(gaps.all(func(g: float) -> bool: return g >= Shooter.BARK_GAP - 0.001), "%s: %d barks, at least %.0f s apart (%s)" % [tag, f.barks.size(), Shooter.BARK_GAP, gaps])
			await T.wait_for(self, func() -> bool: return cm.fight == null, 3.0)
			print("INFO  %s: the level clock ran %.1f s during round 3" % [tag, clock0 - lvl._time_left])
			await T.wait(self, 0.4)
			var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
			T.check(arm.spring_length > 2.1 and p.model().is_visible_in_tree() and not p.frozen and is_equal_approx(Engine.time_scale, 1.0),
				"%s: after the win Bob is in third person, free, normal time (arm %.2f)" % [tag, arm.spring_length])
			T.check(Vector2(p.global_position.x - c["body"].global_position.x, p.global_position.z - c["body"].global_position.z).length() < 1.5,
				"%s: Bob is back in front of the stall" % tag)
			T.check(washers.all(func(n: Node3D) -> bool: return n.visible and n.collision_layer != 0), "%s: and the stall's Jijio is back" % tag)
		await T.wait_for(self, func() -> bool: return cm.fight == null, 8.0)
		T.check(cm.fights_won == n, "%s: %s is down (%d won)" % [tag, cname, cm.fights_won])
		if n < 3:
			T.check(mission.text.contains("(%d left)" % (3 - n)), "%s: the list counts down ('%s')" % [tag, mission.text.replace("\n", " | ")])

	# 4. the stall is announced free, Bob uses it, the timer stops, the win screen
	await T.wait_for(self, func() -> bool: return mission.text.contains("is free"), 3.0)
	T.check(mission.text.contains("Stall %d (row %d) is free" % [stall % 10 + 1, 1 if stall < 10 else 2]), "%s: the SAME stall is announced free ('%s')" % [tag, mission.text])
	print("INFO  %s: time left when the stall was free: %.1f s of 150 (fist fights shortened, WATER WAR by the bot)" % [tag, lvl._time_left])
	T.check(lvl._time_left > 0.0 and lvl._running, "%s: still in time (%.1f s left)" % [tag, lvl._time_left])
	var idx: int = (sess._row - 1) * 10 + sess._k - 1
	T.check(idx == stall, "%s: the toilet session is on this stall (%d)" % [tag, idx])
	var fwd := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + fwd * 0.9
	p.face_direction(-fwd)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  use toilet", "%s: use-toilet prompt ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return lvl.get_node("HUD/StatusLabel").text.begins_with("Pooping"), 5.0)
	T.check(not lvl._running, "%s: the timer stopped when Bob sat down" % tag)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  grab tissue", 5.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  flush", 8.0)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return lvl._result.visible, 15.0)
	T.check(lvl._result.visible and lvl._result.text.begins_with("LEVEL 4 COMPLETE"), "%s: win screen ('%s')" % [tag, lvl._result.text.replace("\n", " | ")])
	lvl.queue_free()
	await process_frame
	await physics_frame
