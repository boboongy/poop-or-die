extends SceneTree
## Level 4 cutters (scripts/cutters.gd) in the real level with the real E / number keys / clicks: all three arrive, stand
## in front of the open stall and are tinted; BOSSY refuses first; each argument (speaker = the cutter's name, any reply)
## leads to a fight on the stage with AI level = fight number and FINISH HIM on fight 2; winning takes the cutter away and
## puts Bob back where he stood; three wins = all_down; walkers are hidden during a fight (`-- walkers`); losing = bob_lost.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Fighter := preload("res://scripts/fighter.gd")
const Shooter := preload("res://scripts/shooter.gd")
const Player := preload("res://scripts/player.gd")

const OUT := Vector3(0.0, 0.0, 1.0) ## row 1 doors open into corridor A (+Z)

var lvl: Node
var p: CharacterBody3D
var cm: Node


## Bob stands in the corridor in front of the cutter, facing them, until his E prompt names them.
func _face(c: Dictionary) -> bool:
	var body: Node3D = c["body"]
	var at: Vector3 = body.global_position + OUT * 0.85
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-OUT)
	await T.wait(self, 0.3)
	return lvl._prompt.text.contains(c["name"])


## WATER WAR from the cut to the win: Bob at START in first person facing east, the squad out, the locked intro ("ROUND 3", then
## "WATER WAR!", nobody moves or fires, Bob frozen), then free; the crew and BOSSY are taken down with real hits (AI parked),
## BOSSY's last hit = "SOAKED!" in slow motion for WIN_SECONDS, then normal time.
func _water_war(f: Node, c: Dictionary) -> void:
	var cam: Camera3D = p.get_node("CameraPivot/SpringArm3D/Camera3D")
	var fwd := -cam.global_basis.z
	T.check(Vector2(p.global_position.x - Shooter.START.x, p.global_position.z - Shooter.START.z).length() < 0.05 and fwd.x > 0.99,
		"Bob at the west end of corridor A (%s), looking east (%s)" % [p.global_position, fwd])
	T.check(p._view == Player.View.FIRST_HIDDEN and p.get_viewport().get_camera_3d() == cam and f.gun.is_visible_in_tree(), "first person, his own camera, the gun in hand")
	T.check(not c["body"].visible and c["body"].collision_layer == 0, "the cutter BOSSY steps out (the shooter's BOSSY comes later)")
	T.check(f.enemies.size() == 3 and f.boss == null, "the squad of 3 is out, BOSSY not yet (%d)" % f.enemies.size())
	T.check(f.hud.big.visible and f.hud.big.text == "ROUND 3" and p.frozen and not f.fighting(), "the intro: ROUND 3, Bob locked")
	var start_pos: Array = f.enemies.map(func(e) -> Vector3: return e.body.global_position)
	await T.wait(self, Shooter.INTRO_SECONDS / 2.0)
	T.check(f.hud.big.text == "WATER WAR!" and p.frozen, "then WATER WAR!, still locked")
	await T.wait_for(self, func() -> bool: return f.fighting(), Shooter.INTRO_SECONDS)
	var moved: Array = []
	for i in f.enemies.size():
		if f.enemies[i].body.global_position.distance_to(start_pos[i]) > 0.05:
			moved.append(f.enemies[i].name)
	T.check(f.fighting() and not p.frozen and not f.hud.big.visible, "after %.1f s Bob is free, the card gone" % Shooter.INTRO_SECONDS)
	T.check(moved.is_empty() and f.enemy_shots.is_empty(), "nobody moved or fired during the intro (moved %s, %d shots)" % [moved, f.enemy_shots.size()])
	f.ai_enabled = false
	for e in f.enemies.duplicate():
		while not e.down:
			f._on_hit(e, true, e.head_center())
	T.check(f.boss != null, "BOSSY walked in after 2 crew")
	var boss = f.boss
	while boss.hp > Shooter.HEAD_DAMAGE:
		f._on_hit(boss, true, boss.head_center())
	f._on_hit(boss, true, boss.head_center())
	T.check(f.over and f.hud.big.text == "SOAKED!" and is_equal_approx(Engine.time_scale, Shooter.WIN_SLOWMO), "BOSSY down: SOAKED! in slow motion")
	await T.wait(self, Shooter.WIN_SECONDS - 0.3) # frames: the slow motion lasts real seconds
	T.check(cm.fight == f and is_equal_approx(Engine.time_scale, Shooter.WIN_SLOWMO), "still slow %.1f s later" % (Shooter.WIN_SECONDS - 0.3))


func _init() -> void:
	seed(1)
	Progress.level = 1
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	p = lvl.player
	var door: Node3D = lvl.stalls.door_for(1, 5)
	var dp: Vector3 = door.interaction_point()
	print("door point ", dp)
	cm = Cutters.new()
	lvl.add_child(cm)
	cm.setup(lvl, Vector3(dp.x, 0.0, -1.0), OUT, 1.0)
	var got: Array = []
	cm.all_down.connect(func() -> void: got.append("all_down"))
	cm.bob_lost.connect(func() -> void: got.append("bob_lost"))
	var walkers_on: bool = not lvl.population.walkers.is_empty()

	# 1. arrival: nobody before 1 s; all three walk to their spots in front of the door, tinted in their own colour
	await T.wait(self, 0.5)
	T.check(cm.cutters.is_empty(), "no cutters before their arrival time")
	var t0 := Time.get_ticks_msec()
	await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 30.0)
	for i in 3:
		var c: Dictionary = cm.cutters[i] if i < cm.cutters.size() else {}
		if c.is_empty():
			T.check(false, "cutter %d arrived" % i)
			continue
		var body: Node3D = c["body"]
		var spot: Vector3 = cm.spots[i]
		var d := Vector2(body.global_position.x - spot.x, body.global_position.z - spot.z).length()
		print("%s at %s, spot %s (%.2f m)" % [c["name"], body.global_position, spot, d])
		T.check(c["state"] == "waiting" and d < 0.4, "%s reached its spot in front of the door (%.2f m off)" % [c["name"], d])
		T.check(Vector2(spot.x - dp.x, spot.z - -1.0).length() < 1.0, "%s's spot blocks the stall door (within 1 m)" % c["name"])
		T.check(cm.is_tinted(body, Cutters.DEFS[i]["color"]), "%s is tinted its colour" % c["name"])

	# 2. BOSSY first: refuses ("deal with my crew first"), no fight
	var boss: Dictionary = cm.cutter("BOSSY")
	T.check(await _face(boss), "E prompt names BOSSY (got '%s')" % lvl._prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(lvl.dialogue._speaker.text == "BOSSY" and lvl.dialogue._text.text == Cutters.WAIT_BOSS, "BOSSY refuses while the crew stands (speaker '%s')" % lvl.dialogue._speaker.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(cm.fight == null and boss["state"] == "waiting", "no fight with BOSSY yet")

	# 3. every cutter in turn: argue, fight on the stage, win, Bob back at his spot
	var n := 0
	for cname: String in ["SNEAKY", "PUSHY", "BOSSY"]:
		n += 1
		var c: Dictionary = cm.cutter(cname)
		T.check(await _face(c), "E prompt names %s (got '%s')" % [cname, lvl._prompt.text])
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		T.check(lvl.dialogue._speaker.text == cname and lvl.dialogue._choices.text.begins_with("[1]"), "%s argues with numbered replies" % cname)
		await T.key(self, KEY_1 + (n % 3)) # any reply
		await T.wait(self, 0.2)
		T.check(lvl.dialogue._text.text == c["def"]["retort"], "%s squares up: '%s'" % [cname, lvl.dialogue._text.text])
		var before: Vector3 = p.global_position
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		var f: Node = cm.fight
		if n == 3: # BOSSY: WATER WAR (tests/test_shooter_*.gd cover the shooter in depth)
			T.check(f != null and f.get_script() == Shooter, "fight 3 against %s is WATER WAR" % cname)
			if f == null:
				continue
			await _water_war(f, c)
		else:
			T.check(f != null and f.foe.name == cname, "fight %d starts against %s" % [n, cname])
			if f == null:
				continue
			T.check(f.ai_level == n and f.foe.finishable == (n == 2), "fight %d: AI level %d, FINISH HIM only on fight 2 (%s)" % [n, f.ai_level, f.foe.finishable])
			var fcam: Camera3D = f.camera # the fight node is freed when it ends
			T.check(p.get_viewport().get_camera_3d() == fcam, "the fight's stage camera is on")
		if walkers_on:
			T.check(lvl.population.walkers.all(func(w: Node3D) -> bool: return not w.visible), "every walker is hidden during the fight")
		if n != 3:
			await T.wait_for(self, func() -> bool: return f.fighting(), 3.0)
			f.ai_enabled = false
			f.foe.pos = f.bob.pos + 0.7
			f.foe.hp = 1.0
			await T.key(self, KEY_SPACE)
		if n == 2:
			await T.wait_for(self, func() -> bool: return f.foe.is_dizzy(), 2.0)
			await T.wait(self, 0.3)
			await T.key(self, KEY_SPACE)
		await T.wait_for(self, func() -> bool: return cm.fight == null, 8.0)
		T.check(cm.fight == null and c["state"] == "down", "%s is down after the fight" % cname)
		var body: Node3D = c["body"]
		T.check(not body.visible, "%s is taken away" % cname)
		T.check(p.global_position.distance_to(before) < 0.05, "Bob is back where he stood (%.3f m)" % p.global_position.distance_to(before))
		T.check(not p.busy and not p.frozen and p.get_viewport().get_camera_3d() == p.get_node("CameraPivot/SpringArm3D/Camera3D"), "Bob has his controls and his own camera back")
		T.check(p._view == Player.View.THIRD and is_equal_approx(Engine.time_scale, 1.0), "third person, normal time after fight %d" % n)
		T.check(not c["body"].is_in_group("interactable"), "no E prompt left on %s" % cname)
		if walkers_on:
			T.check(lvl.population.walkers.all(func(w: Node3D) -> bool: return w.visible), "walkers are back after the fight")
		T.check(cm.fights_won == n, "fights won: %d" % cm.fights_won)
	T.check(got == ["all_down"], "all_down after the third win (%s)" % [got])

	# 4. losing: a fresh set of cutters, Bob at 1 hp against PUSHY's AI -> bob_lost
	var cm2: Node = Cutters.new()
	lvl.add_child(cm2)
	cm2.setup(lvl, Vector3(dp.x, 0.0, -1.0), OUT, 0.1)
	cm2.bob_lost.connect(func() -> void: got.append("bob_lost 2"))
	await T.wait_for(self, func() -> bool: return cm2.cutters.size() == 3 and cm2.cutters[0]["state"] == "waiting", 30.0)
	cm = cm2
	var pushy: Dictionary = cm2.cutter("PUSHY")
	await _face(pushy)
	await T.key(self, KEY_E)
	await T.key(self, KEY_1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	if cm2.fight != null:
		cm2.fight.bob.hp = 1.0
	await T.wait_for(self, func() -> bool: return got.has("bob_lost 2"), 15.0)
	T.check(got.has("bob_lost 2"), "Bob KO'd -> bob_lost")
	cm2.abort()

	lvl.queue_free()
	await process_frame
	T.finish(self)
