extends SceneTree
## Stage 4 "WATER WAR" slice 3 (SPEC "Stage 4 plan" (3), (4), (6)): the crew's AI and their brown shots, Bob's HP, regen, splats, K.O., jump.
## Over 3 seeds (`-- seeds=N first=K`), real level, AI on, checked on EVERY physics frame: every enemy inside the arena and not inside a
## wall. Then: they shoot Bob when they see him, every shot had a clear line and every hit came along an unblocked path, each hit makes a
## splat and a sound, the ones who cannot see him advance toward him, regen waits 4 s then gives 10/s, Space jumps about 0.5 m, K.O. at 0
## stops everything. Seed 1 also: strafing (A/D) is hit clearly less often than standing still (a control run, the same crew).
## Run: timeout 400 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_shooter_ai.gd [-- seeds=3 first=1]
const T := preload("res://tests/t.gd")
const Shooter := preload("res://scripts/shooter.gd")
const Enemy := preload("res://scripts/shooter_enemy.gd")
const Sfx := preload("res://scripts/sfx.gd")

var sh: Node
var p: CharacterBody3D
var watching := false
var frames := 0
var outside := 0
var in_wall := 0
var first_bad := ""
var _sphere := SphereShape3D.new()


func _on_frame() -> void:
	if not watching or sh == null or not is_instance_valid(sh):
		return
	frames += 1
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var skip: Array[RID] = [p.get_rid()]
	for e in sh.enemies:
		skip.append(e.body.get_rid())
	for e in sh.enemies:
		if e.down:
			continue
		var at: Vector3 = e.body.global_position
		var inside := false
		for b: Array in Shooter.ARENA_BOXES:
			if at.x >= b[0] + 0.15 and at.x <= b[1] - 0.15 and at.z >= b[2] + 0.15 and at.z <= b[3] - 0.15:
				inside = true
		if not inside or absf(at.y) > 0.15:
			outside += 1
			if first_bad == "":
				first_bad = "%s at %s" % [e.name, at]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _sphere
		q.transform = Transform3D(Basis(), at + Vector3.UP * 0.6)
		q.collision_mask = 1
		q.exclude = skip
		if not space.intersect_shape(q, 1).is_empty():
			in_wall += 1
			if first_bad == "":
				first_bad = "%s in a wall at %s" % [e.name, at]


func _args() -> Array:
	var seeds := 3
	var first := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("first="):
			first = int(a.substr(6))
	return [seeds, first]


func _init() -> void:
	_sphere.radius = 0.15
	physics_frame.connect(_on_frame)
	var args := _args()
	for s in range(args[1], args[1] + args[0]):
		await _run(s)
	T.check(frames > 3000 and outside == 0 and in_wall == 0, "every enemy inside the arena and out of the walls on every frame (%d frames, %d outside, %d in a wall %s)" % [frames, outside, in_wall, first_bad])
	T.finish(self)


func _run(s: int) -> void:
	seed(s)
	var tag := "seed %d:" % s
	var lvl := T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(2.0, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	await T.wait(self, 0.2)
	sh = Shooter.new()
	lvl.add_child(sh)
	sh.start(p)
	var squad: Array = sh.spawn_squad()
	var start_gap := {}
	for e in squad:
		start_gap[e.name] = absf(sh.cover_s(e.cover) - sh.u_param(p.global_position))
	var ended := []
	sh.ended.connect(func(w: String, _f: bool) -> void: ended.append(w))
	Sfx.played.clear()
	watching = true

	# --- 16 s: Bob stands at the west end of corridor A ---
	await T.wait(self, 16.0)
	var shots: Array = sh.enemy_shots
	var hits: Array = sh.bob_hits
	var unclear := shots.filter(func(x: Dictionary) -> bool: return not x["clear"]).size()
	T.check(shots.size() >= 5 and unclear == 0, "%s they shoot when they see him: %d shots, %d without a clear line" % [tag, shots.size(), unclear])
	var blocked := 0
	for h: Dictionary in hits:
		if not sh.clear_line(h["from"], h["at"]):
			blocked += 1
	T.check(hits.size() >= 1 and blocked == 0, "%s %d hits on Bob, every one along an unblocked path (%d blocked)" % [tag, hits.size(), blocked])
	T.check(sh.hud.splats_made == hits.size() and Sfx.count("bob_splat") >= 1, "%s each hit leaves a splat (%d splats, %d hits), splat sound %d" % [tag, sh.hud.splats_made, hits.size(), Sfx.count("bob_splat")])
	T.check(sh.hud.splats.get_child_count() <= 8, "%s at most 8 splats on screen (%d)" % [tag, sh.hud.splats.get_child_count()])
	var total_moves := 0
	var further := []
	for e in squad:
		total_moves += e.moves
		var gap := absf(sh.cover_s(e.cover) - sh.u_param(p.global_position))
		if gap > float(start_gap[e.name]) + 0.01:
			further.append(e.name)
	T.check(total_moves >= 2 and further.is_empty(), "%s the ones who could not see him advanced (%d cover changes), nobody moved away (%s)" % [tag, total_moves, further])
	var dmg := 0.0
	for h: Dictionary in hits:
		dmg += float(h["damage"])
	T.check(dmg == hits.size() * 6.0, "%s a crew hit does 6 (%.0f for %d hits)" % [tag, dmg, hits.size()])
	_check_barks(tag, lvl)

	# --- regen: none for 4 s after a hit, then 10/s ---
	sh.ai_enabled = false
	await T.wait(self, 1.5) # the last blobs land
	sh.bob_hp = 60.0
	sh.since_hit = 0.0
	await T.wait(self, 3.9)
	T.check(is_equal_approx(sh.bob_hp, 60.0), "%s no regen in the first 4 s after a hit (hp %.1f)" % [tag, sh.bob_hp])
	await T.wait(self, 2.1) # 6.0 s after the hit
	T.check(absf(sh.bob_hp - 80.0) < 1.0, "%s then 10 hp/s: %.1f at 6 s (expect 80)" % [tag, sh.bob_hp])
	sh.bob_hp = 30.0
	await T.wait(self, 0.1)
	T.check(sh.hud.edge.visible, "%s the red edge shows under 40 hp" % tag)
	sh.bob_hp = 150.0
	await T.wait(self, 0.1)
	T.check(not sh.hud.edge.visible, "%s and goes at 150" % tag)

	# --- jump ---
	var y0: float = p.global_position.y
	var top := y0
	await T.key(self, KEY_SPACE)
	for i in 60:
		await physics_frame
		top = maxf(top, p.global_position.y)
	T.check(p.jumps == 1 and absf(top - y0 - Shooter.JUMP_HEIGHT) < 0.08 and absf(p.global_position.y - y0) < 0.02, "%s Space jumps %.2f m and lands" % [tag, top - y0])

	if s == 1:
		await _dodge(tag)

	# --- K.O. ---
	sh.bob_hp = 12.0
	sh.since_hit = 0.0
	sh.ai_enabled = true
	await T.wait_for(self, func() -> bool: return sh.over, 30.0)
	T.check(sh.over and ended.is_empty() and p.frozen and sh.hud.big.text == "K.O.", "%s at 0 hp: K.O., Bob frozen, not ended yet (%s)" % [tag, ended])
	await T.wait(self, Shooter.KO_SECONDS - 0.2)
	T.check(ended.is_empty() and is_equal_approx(Engine.time_scale, 1.0), "%s K.O. holds %.1f s at normal speed (%s)" % [tag, Shooter.KO_SECONDS - 0.2, ended])
	await T.wait(self, 0.4)
	T.check(ended == ["CREW"], "%s then ended(CREW) (%s)" % [tag, ended])
	var n_shots: int = sh.enemy_shots.size()
	var n_shot: int = sh.shots_fired
	await T.left_down(self)
	await T.wait(self, 2.0)
	await T.left_up(self)
	T.check(sh.enemy_shots.size() == n_shots and sh.shots_fired == n_shot, "%s after the K.O. nobody fires" % tag)

	watching = false
	sh.abort()
	lvl.queue_free()
	await T.wait(self, 0.2)


## The barks (owner B): at least one in 16 s, never two within BARK_GAP s, only the four lines, each one's voice asked for in a crew
## voice (generic Jijio casts; run.sh fails the file on a VOICE MISSING line), and only from someone who is up.
func _check_barks(tag: String, lvl: Node) -> void:
	var b: Array = sh.barks
	var bad_gap := 0
	for k in range(1, b.size()):
		if b[k]["t"] - b[k - 1]["t"] < Shooter.BARK_GAP - 0.001:
			bad_gap += 1
	var kinds := {}
	for x: Dictionary in b:
		kinds[x["kind"]] = true
	T.check(b.size() >= 1 and bad_gap == 0 and b.size() <= int(16.0 / Shooter.BARK_GAP) + 1,
		"%s %d barks in 16 s (%s), none within %.0f s of another" % [tag, b.size(), kinds.keys(), Shooter.BARK_GAP])
	var voiced := 0
	for x: Dictionary in b:
		var line: String = Shooter.BARKS[x["kind"]]
		for sp: String in lvl.dialogue.spoken:
			if sp.ends_with("|" + line) and sp.begins_with("jijio_"):
				voiced += 1
				break
	T.check(voiced == b.size(), "%s every bark spoken in a Jijio voice (%d of %d)" % [tag, voiced, b.size()])


## Seed 1: the same crew at the same cover shoots at Bob standing still for 20 s, then at Bob strafing (A/D every 0.5 s) for 20 s.
func _dodge(tag: String) -> void:
	var crew = null
	for e in sh.enemies:
		if e.name == "CREW 1":
			crew = e
		else:
			e.ai = Enemy.Ai.OFF
			e.body.visible = false
			e.body.global_position = Vector3(0.6, 0.0, -5.6) # out of the way, far down corridor B
			e.cover = -1
	crew.ai = Enemy.Ai.HIDE
	crew.cover = 1
	crew.body.global_position = Shooter.COVERS[1]["hide"]
	p.global_position = Vector3(4.0, 0.0, 0.0)
	p.face_direction(Vector3.RIGHT)
	sh.bob_hp = 100000.0
	sh.ai_enabled = true
	await T.wait(self, 1.0)
	var r := []
	for strafe in [false, true]:
		var s0: int = sh.enemy_shots.size()
		var h0: int = sh.bob_hits.size()
		var t := 0.0
		var k := KEY_D
		var held := false
		while t < 20.0:
			if strafe:
				if held:
					await T.key_up(self, k)
				k = KEY_A if k == KEY_D else KEY_D
				await T.key_down(self, k)
				held = true
				await T.wait(self, 0.25 if t == 0.0 else 0.5)
				t += 0.25 if t == 0.0 else 0.5
			else:
				await T.wait(self, 0.5)
				t += 0.5
		if held:
			await T.key_up(self, k)
		await T.wait(self, 1.0)
		var fired: int = sh.enemy_shots.size() - s0
		var got: int = sh.bob_hits.size() - h0
		r.append([fired, got])
		p.global_position = Vector3(4.0, 0.0, 0.0)
	var stand: float = float(r[0][1]) / maxf(r[0][0], 1.0)
	var move: float = float(r[1][1]) / maxf(r[1][0], 1.0)
	T.check(r[0][0] >= 15 and r[1][0] >= 15, "%s the dodge runs met enough shots: %d standing, %d strafing" % [tag, r[0][0], r[1][0]])
	T.check(stand >= 0.3 and move < stand * 0.6, "%s strafing dodges: hit %.0f %% standing (%d/%d), %.0f %% strafing (%d/%d)" % [tag, stand * 100.0, r[0][1], r[0][0], move * 100.0, r[1][1], r[1][0]])
	sh.bob_hp = 150.0
