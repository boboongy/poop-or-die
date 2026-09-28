extends SceneTree
## Level 4 fight scene (scripts/fight.gd) in the real level with the real input path: the fight takes Bob over (side camera,
## no free movement), every button plays its real clip (punch, combo chain, kick, S+punch uppercut, Q super, finisher),
## hits land with hit-stop, jump lifts the body, block holds, the AI attacks, KO = slow motion then Bob gets his controls
## back, FINISH HIM, and the two bodies never overlap on any frame.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Fight := preload("res://scripts/fight.gd")
const Fighter := preload("res://scripts/fighter.gd")
const Sfx := preload("res://scripts/sfx.gd")

const CENTER := Vector3(11.5, 0.0, -2.5) ## the open east end (tests/probe_level4_space.gd: 7.1 m clear along Z)
const AXIS := Vector3(0.0, 0.0, -1.0)

var lvl: Node
var p: CharacterBody3D
var min_gap_seen := 100.0
var frames_seen := 0


func _fight(finishable: bool, ai: bool) -> Node:
	var npc: Node3D = lvl.population.spawn_walker(CENTER + AXIS * 2.0, 0.0)
	lvl.population.walkers.erase(npc) # a walker only in body: nobody else steers it
	var f: Node = Fight.new()
	lvl.add_child(f)
	f.ai_enabled = ai
	f.intro_seconds = 0.0 # the ROUND/FIGHT! intro is tested in test_fight_hud
	f.start(p, npc, CENTER, AXIS, "CUTTER", 30.0, finishable, 1)
	f.hit_landed.connect(_voice_after_hit)
	await process_frame
	return f


## Stage 6 E: after each clean hit, was a voice played in the same call (fight._on_hit plays it before emitting hit_landed)?
var _foe_hits := 0
var _foe_oofs := 0
var _bob_hits := 0
var _bob_ouches := 0
func _voice_after_hit(e: Dictionary) -> void:
	if bool(e["blocked"]):
		return
	var last: String = Sfx.played.back() if not Sfx.played.is_empty() else ""
	if e["victim"] == "BOB":
		_bob_hits += 1
		_bob_ouches += 1 if last == "bob_ouch" else 0
	else:
		_foe_hits += 1
		_foe_oofs += 1 if last == "oof" else 0 # "CUTTER" has no own cast: the generic Jijio voices


func _clear(f: Node) -> void:
	var npc: Node = f.foe_body
	f.abort()
	f.queue_free()
	npc.queue_free()
	await T.wait(self, 0.1)


## Samples the world gap between the two bodies on every physics frame of `seconds`.
func _watch(f: Node, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame
		if not is_instance_valid(f) or not f.running:
			return
		var a: Vector3 = f.bob_body.global_position
		var b: Vector3 = f.foe_body.global_position
		min_gap_seen = minf(min_gap_seen, Vector2(a.x - b.x, a.z - b.z).length())
		frames_seen += 1


func _clip(n: Node3D) -> String:
	var ap: AnimationPlayer = n.anim()
	return ap.current_animation


func _init() -> void:
	seed(1)
	Progress.level = 1
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	p = lvl.player

	# 1. start: Bob is taken over, side camera, both on the line 2 m apart facing each other
	var f: Node = await _fight(false, false)
	f.foe.hp = 1000.0 # a sparring partner for sections 2-7: punch + combo alone would KO a 30 hp cutter
	T.check(p.busy and p.posing, "the fight takes Bob over (busy + posing)")
	T.check(f.camera.current, "the fight's side camera is the current camera")
	var gap: float = p.global_position.distance_to(f.foe_body.global_position)
	T.check(absf(gap - 2.0) < 0.05, "fighters start 2 m apart (%.2f)" % gap)
	var to_foe: Vector3 = (f.foe_body.global_position - p.global_position).normalized()
	var bob_front: Vector3 = p.model().global_basis.z
	T.check(bob_front.dot(to_foe) > 0.95, "Bob faces the foe (dot %.2f)" % bob_front.dot(to_foe))
	var screen_right: Vector3 = f.camera.global_basis.x
	T.check(screen_right.dot(to_foe) > 0.95, "the foe is on screen-right of Bob (side view along the line)")
	await _watch(f, 0.3)
	T.check(_clip(p) == "fight/stance" and _clip(f.foe_body) == "fight/stance", "both stand in the fight stance")
	T.check(p.anim().callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, "Bob's clips run on the physics tick during the fight")

	# 2. D walks toward the foe (screen right), and the walk clip plays
	var before: float = f.bob.pos
	await T.key_down(self, KEY_D)
	await _watch(f, 0.4)
	T.check(_clip(p) == "walk", "walking plays the walk clip (got '%s')" % _clip(p))
	await T.key_up(self, KEY_D)
	T.check(f.bob.pos > before + 0.3, "D moves Bob toward the foe (%.2f -> %.2f)" % [before, f.bob.pos])
	# close in to punching range
	await T.key_down(self, KEY_D)
	await _watch(f, 1.0)
	await T.key_up(self, KEY_D)
	await _watch(f, 0.2)
	T.check(absf(f.foe.pos - f.bob.pos) <= 0.9, "walked into punch range (gap %.2f)" % absf(f.foe.pos - f.bob.pos))

	# 3. keyboard only (owner 2026-09-25: "I don't like the clicking, it's boring; the keyboard should be the combo, like Street Fighter"):
	# a mouse click does nothing now; J = punch clip at its speed; the hit lands, with hit-stop freezing both clips
	await T.left_click(self)
	await process_frame
	T.check(_clip(p) != "punch" and f.bob.state != Fighter.State.MOVE, "a left click no longer punches (got '%s')" % _clip(p))
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(_clip(p) == "punch", "J plays 'punch' (got '%s')" % _clip(p))
	var stops_before: int = f.hitstop_count
	var froze := false
	for i in 60:
		await physics_frame
		if f.hitstop_left > 0.0 and p.anim().speed_scale == 0.0 and f.foe_body.anim().speed_scale == 0.0:
			froze = true
	T.check(f.foe.hp < 1000.0, "the punch landed (foe hp %.1f)" % f.foe.hp)
	T.check(Sfx.count("punch_hit") > 0, "a landed jab makes the punch sound (owner: 'punching sound also don't have')")
	T.check(f.hitstop_count == stops_before + 1 and froze, "one clean hit = one hit-stop, both clips frozen during it")
	await _watch(f, 1.0)

	# 4. J, J quickly = the combo chain
	await T.key(self, KEY_SPACE)
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(_clip(p) == "punch_combo", "a quick second J chains into 'punch_combo' (got '%s')" % _clip(p))
	await _watch(f, 2.0)

	# 5. WASD + Space (owner 2026-09-28): toward the foe (D) + Space = kick; K does nothing any more
	await T.key(self, KEY_K)
	await process_frame
	T.check(f.bob.state != Fighter.State.MOVE, "K no longer kicks")
	f.foe.pos = f.bob.pos + 1.2
	await T.key_down(self, KEY_D)
	await T.key(self, KEY_SPACE)
	await process_frame
	await T.key_up(self, KEY_D)
	T.check(_clip(p) == "kick", "D + Space plays 'kick' (got '%s')" % _clip(p))
	await _watch(f, 1.5)
	# S + Space = the low sweep, and it hits a crouching foe
	f.foe.pos = f.bob.pos + 0.9
	f.foe.crouching = true
	var sweep_hp: float = f.foe.hp
	await T.key_down(self, KEY_S)
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(_clip(p) == "move_down", "S + Space plays the sweep 'move_down' (got '%s')" % _clip(p))
	await _watch(f, 0.6)
	await T.key_up(self, KEY_S)
	T.check(f.foe.hp < sweep_hp, "the sweep hits a crouching foe (hp %.1f -> %.1f)" % [sweep_hp, f.foe.hp])
	f.foe.crouching = false
	await _watch(f, 1.0)
	# Space in the air = the jump kick, once per jump; it lands on a foe in reach
	f.foe.pos = f.bob.pos + 1.0
	var air_hp: float = f.foe.hp
	await T.key(self, KEY_W)
	await _watch(f, 0.1)
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(f.bob.is_airborne() and f.bob.air_kick and _clip(p) == "kick", "Space in the air = the jump kick, in the kick pose (got '%s')" % _clip(p))
	await _watch(f, 0.3)
	T.check(f.foe.hp < air_hp, "the jump kick lands (hp %.1f -> %.1f)" % [air_hp, f.foe.hp])
	await _watch(f, 1.0)

	# 6. motion specials (the foe is to Bob's right, so D = forward, A = back): each typed with real keys, each shows its name
	var hud_special: Label = f.hud.special_label
	for sp: Array in [[[KEY_S, KEY_D, KEY_SPACE], "punch_combo", "FLURRY"], [[KEY_D, KEY_S, KEY_D, KEY_SPACE], "uppercut", "UPPERCUT"],
			[[KEY_S, KEY_A, KEY_SPACE], "kick_spin", "SPIN KICK"]]:
		f.foe.pos = f.bob.pos + 0.8
		for k: int in sp[0]:
			await T.key(self, k)
		await process_frame
		T.check(_clip(p) == sp[1], "%s typed as %s plays '%s' (got '%s')" % [sp[2], str(sp[0]), sp[1], _clip(p)])
		T.check(hud_special.visible and hud_special.text.contains(sp[2]), "%s: its name flashes on screen ('%s')" % [sp[2], hud_special.text])
		await _watch(f, 2.0)
	# too slow: S ... (1 s) ... D J is a plain punch, not a special
	f.foe.pos = f.bob.pos + 0.8
	await T.key(self, KEY_S)
	await _watch(f, 1.0)
	await T.key(self, KEY_D)
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(_clip(p) == "punch", "a motion typed too slowly is just a punch (got '%s')" % _clip(p))
	await _watch(f, 1.5)

	# 7. the SUPER: S D S D J with a full meter; with an empty meter the same keys are the uppercut; Q does nothing any more
	f.bob.meter = Fighter.METER_MAX
	await T.key(self, KEY_Q)
	await process_frame
	T.check(_clip(p) != "kick_double", "Q no longer fires the super")
	await _watch(f, 0.3)
	f.bob.meter = 0.0
	for k: int in [KEY_S, KEY_D, KEY_S, KEY_D, KEY_SPACE]:
		await T.key(self, k)
	await process_frame
	T.check(_clip(p) == "uppercut", "S D S D J with an empty meter is the UPPERCUT (its last D S D J; got '%s')" % _clip(p))
	await _watch(f, 2.0)
	f.bob.meter = Fighter.METER_MAX
	f.foe.pos = f.bob.pos + 0.9
	for k: int in [KEY_S, KEY_D, KEY_S, KEY_D, KEY_SPACE]:
		await T.key(self, k)
	await process_frame
	T.check(_clip(p) == "kick_double", "S D S D J with a full meter plays the super 'kick_double' (got '%s')" % _clip(p))
	await _watch(f, 2.0)

	# 8. W = jump (Space no longer jumps: it punches); L and Shift no longer block (hold away does, 8b)
	for jump_key: int in [KEY_W]:
		var floor_y: float = p.global_position.y
		await T.key(self, jump_key)
		var top := floor_y
		for i in 50:
			await physics_frame
			top = maxf(top, p.global_position.y)
		T.check(top > floor_y + 0.3, "%s jumps (peak +%.2f m)" % [OS.get_keycode_string(jump_key), top - floor_y])
		await _watch(f, 0.5)
		T.check(absf(p.global_position.y - floor_y) < 0.01, "Bob lands back on the floor")
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(not f.bob.is_airborne() and _clip(p) == "punch", "Space punches, it does not jump (got '%s')" % _clip(p))
	await _watch(f, 1.0)
	for block_key: int in [KEY_L, KEY_SHIFT]:
		await T.key_down(self, block_key)
		await _watch(f, 0.2)
		T.check(not f.bob.blocking, "holding %s no longer blocks" % OS.get_keycode_string(block_key))
		await T.key_up(self, block_key)
	var ctl: String = f.hud.controls.text
	T.check(ctl.contains("SPACE") and not ctl.contains("J ") and not ctl.to_lower().contains("click") and not ctl.contains("(or L)"), "the controls line shows WASD + Space ('%s')" % ctl)

	# 8b. Street Fighter controls (owner 2026-09-25): holding AWAY (A: the foe is to the right) walks back AND guards;
	# holding toward (D) does not guard; S held = crouch (crouch pose, no walking), a jab passes over a crouch, a kick does not.
	var start_pos: float = f.bob.pos
	await T.key_down(self, KEY_A)
	await _watch(f, 0.3)
	T.check(f.bob.blocking and _clip(p) == "fight/guard", "holding back (A) guards, in the guard pose (got '%s')" % _clip(p))
	T.check(f.bob.pos < start_pos - 0.1, "holding back also walks back (%.2f -> %.2f)" % [start_pos, f.bob.pos])
	await T.key_up(self, KEY_A)
	await T.key_down(self, KEY_D)
	await _watch(f, 0.2)
	T.check(not f.bob.blocking, "holding toward the foe (D) does not guard")
	await T.key_up(self, KEY_D)
	await T.key_down(self, KEY_S)
	await _watch(f, 0.2)
	T.check(f.bob.crouching and _clip(p) == "fight/crouch", "holding S crouches, in the crouch pose (got '%s')" % _clip(p))
	var crouch_pos: float = f.bob.pos
	await T.key_down(self, KEY_D)
	await _watch(f, 0.3)
	T.check(absf(f.bob.pos - crouch_pos) < 0.01, "no walking while crouched")
	await T.key_up(self, KEY_D)
	f.foe.pos = f.bob.pos + 0.7
	var hp_before: float = f.bob.hp
	f.foe.start_move("punch")
	await _watch(f, 0.8)
	T.check(f.bob.hp == hp_before, "a jab passes over the crouching Bob (hp %.1f -> %.1f)" % [hp_before, f.bob.hp])
	f.foe.pos = f.bob.pos + 0.7
	f.foe.start_move("kick")
	await _watch(f, 1.0)
	T.check(f.bob.hp < hp_before, "a kick still hits a crouching Bob (hp %.1f -> %.1f)" % [hp_before, f.bob.hp])
	T.check(Sfx.count("heavy_hit") > 0, "a landed kick makes the heavy hit sound")
	await T.key_up(self, KEY_S)
	await _watch(f, 0.5)
	T.check(not f.bob.crouching, "releasing S stands up")
	# a blocked hit pushes the defender back (block pushback)
	# (holding away also walks back, so the push distance is checked in test_fighter; here: the hit is guarded)
	f.bob.pos = -f.LINE_HALF # at the stage's back edge: holding away cannot walk him out of the jab's reach
	f.foe.pos = f.bob.pos + 0.7
	await T.key_down(self, KEY_A)
	await _watch(f, 0.1)
	var guard_hp: float = f.bob.hp
	f.foe.pos = f.bob.pos + 0.7
	f.foe.start_move("punch")
	await _watch(f, 0.5)
	T.check(Sfx.count("block_hit") > 0 and guard_hp - f.bob.hp < 8.0 * 0.5, "holding away guards a jab: block sound, little damage (%.1f)" % (guard_hp - f.bob.hp))
	await T.key_up(self, KEY_A)
	await _clear(f)

	# 8. the AI closes in and attacks: Bob (not blocking) loses hp and the foe plays an attack clip
	f = await _fight(false, true)
	var attacked := false
	for i in 8 * 60:
		await physics_frame
		if f.foe.state == Fighter.State.MOVE and _clip(f.foe_body) == Fighter.MOVES[f.foe.move]["clip"]:
			attacked = true
		if f.bob.hp < 100.0 and attacked:
			break
	T.check(attacked and f.bob.hp < 100.0, "the AI attacks with a real clip and hurts Bob (hp %.1f)" % f.bob.hp)
	await _clear(f)

	# 9. KO: slow motion, then 'ended', and Bob gets his controls and camera back
	f = await _fight(false, false)
	var result: Array = []
	f.ended.connect(func(winner: String, fin: bool) -> void: result.append([winner, fin]))
	f.foe.pos = f.bob.pos + 0.7
	f.foe.hp = 1.0
	await T.key(self, KEY_SPACE)
	var slow := false
	for i in 4 * 60:
		await physics_frame
		if Engine.time_scale < 0.5:
			slow = true
		if not result.is_empty():
			break
	T.check(slow, "a KO plays in slow motion")
	T.check(result.size() == 1 and result[0][0] == "BOB" and result[0][1] == false, "'ended' says Bob won, not finished (%s)" % [result])
	T.check(Engine.time_scale == 1.0, "time scale is back to normal after the KO")
	T.check(Sfx.count("ko") > 0, "the KO makes the KO sound")
	T.check(not p.busy and not p.posing and p.get_viewport().get_camera_3d() != f.camera, "Bob gets his controls and camera back")
	T.check(p.anim().callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "Bob's clips are back on the render frame")
	T.check(f.foe_body.get_node("Model").rotation.x < -1.0, "the KO'd foe lies on their back")
	await _clear(f)

	# 10. FINISH HIM: a finishable foe at 0 hp is dizzy; any attack button now plays the finisher, slow, and ends 'finished'
	f = await _fight(true, false)
	result = []
	f.ended.connect(func(winner: String, fin: bool) -> void: result.append([winner, fin]))
	f.foe.pos = f.bob.pos + 0.7
	f.foe.hp = 1.0
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.foe.is_dizzy(), 2.0)
	T.check(f.foe.is_dizzy(), "the last cutter at 0 hp is dizzy (FINISH HIM)")
	await _watch(f, 0.5)
	await T.key(self, KEY_SPACE)
	await process_frame
	T.check(_clip(p) == "kick_spin", "an attack on a dizzy foe plays the finisher 'kick_spin' (got '%s')" % _clip(p))
	T.check(Engine.time_scale < 1.0, "the finisher plays in slow motion")
	await T.wait_for(self, func() -> bool: return not result.is_empty(), 6.0)
	T.check(result.size() == 1 and result[0][1] == true, "'ended' reports the foe finished (%s)" % [result])
	await _clear(f)

	# 11. Bob KO'd: 'ended' names the foe
	f = await _fight(false, true)
	result = []
	f.ended.connect(func(winner: String, fin: bool) -> void: result.append([winner, fin]))
	f.bob.hp = 1.0
	await T.wait_for(self, func() -> bool: return not result.is_empty(), 12.0)
	T.check(result.size() == 1 and result[0][0] == "CUTTER", "Bob KO'd: 'ended' names the cutter (%s)" % [result])
	T.check(Engine.time_scale == 1.0, "time scale restored after Bob's KO")
	T.check(Sfx.count("bob_ouch") > 0, "Bob's KO: he cries out")
	await _clear(f)

	# Stage 6 E: the cutter says OOF on about every other clean hit, Bob cries out on each (one voice at a time: max_voices 1 may drop one)
	T.check(_foe_hits >= 6 and _foe_oofs >= _foe_hits * 0.35 and _foe_oofs <= _foe_hits * 0.65,
		"the cutter OOFs on about every other clean hit (%d of %d)" % [_foe_oofs, _foe_hits])
	T.check(_bob_hits >= 1 and _bob_ouches >= _bob_hits * 0.5, "Bob cries out when hit (%d of %d)" % [_bob_ouches, _bob_hits])

	# per-frame invariant over every fight above
	T.check(min_gap_seen >= Fighter.MIN_GAP - 0.02, "bodies never closer than MIN_GAP on %d sampled frames (min %.2f)" % [frames_seen, min_gap_seen])

	lvl.queue_free()
	await process_frame
	T.finish(self)
