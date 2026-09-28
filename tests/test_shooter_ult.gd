extends SceneTree
## Stage 4 "WATER WAR" slice 5 (SPEC "Stage 4 plan" (5) and "slice 5 details DECIDED"): the SUPER-SOAKER hose. Real level, real Q key.
## The meter: every point of gun damage (288 not full, 300 exactly full, capped), real blobs count what they dealt, the hose's own
## damage never charges it and it restarts at 0. Q does nothing below full, when Bob is frozen, or twice. The hose: 5 s (300 frames +- 1),
## 60 dmg/s (a second = 60 +- 2), a number every 0.25 s, 10 m reach (hit at 9.5 m, never at 10.9 m), stopped by a stack, stops at the
## first enemy (the one behind is dry), pushes 3 m/s (+- 0.3) away, a wall stops the push, no tank use, the gun silent, Bob at 70 % speed
## and back after the end, after abort() and after a K.O. A hose kill: down, the chime's feed line, BOSSY's phase still follows.
## The stream is drawn only while hosing; the ring reads the meter.
## Run: timeout 240 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_shooter_ult.gd
const T := preload("res://tests/t.gd")
const Shooter := preload("res://scripts/shooter.gd")

const LANE_Z := -5.1 ## corridor B's middle: no sink in range, no stack on the line
const BOB_X := 0.8

var lvl: Node
var sh: Node
var p: CharacterBody3D
var hose_frames := 0
var bad_speed := 0
var stream_off := 0 ## frames hosing without a drawn stream, or a stream while not hosing
var slow_walk := 0.0


func _on_frame() -> void:
	if sh == null or not is_instance_valid(sh) or not sh.running:
		return
	if sh.hosing:
		hose_frames += 1
		if absf(p.walk_speed - slow_walk) > 0.001:
			bad_speed += 1
	if sh.hosing != (sh.hose_node != null and is_instance_valid(sh.hose_node) and sh.hose_node.visible):
		stream_off += 1


## Point the crosshair at a world point.
func _aim(at: Vector3) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var d := at - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _stand(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	await T.wait(self, 0.1)


func _crew(n: String, at: Vector3, hp: float):
	var e = sh.spawn_crew(n, at, -PI / 2.0)
	e.hp = hp
	e.max_hp = hp
	return e


func _chest(e) -> Vector3:
	return e.body.global_position + Vector3.UP * 0.6


func _new_shooter() -> void:
	sh = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.ai_enabled = false
	sh.start(p)
	await T.wait(self, 0.3)


func _drop_shooter() -> void:
	sh.abort()
	for e in sh.enemies:
		if is_instance_valid(e.body):
			e.body.queue_free()
	sh.queue_free()
	sh = null
	await T.wait(self, 0.3)


func _fill() -> void:
	sh.ult = Shooter.ULT_FULL


func _init() -> void:
	seed(1)
	physics_frame.connect(_on_frame)
	lvl = T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	p = lvl.player
	var walk0: float = p.walk_speed
	var sprint0: float = p.sprint_speed
	slow_walk = walk0 * Shooter.HOSE_SPEED
	await _stand(Vector3(BOB_X, 0.0, LANE_Z))
	await _new_shooter()
	T.check(Shooter.sink_distance(p.global_position) > Shooter.REFILL_RANGE + 0.3, "Bob's lane is out of refill range (%.2f m)" % Shooter.sink_distance(p.global_position))

	# --- the meter: gun damage only, exactly 300 ---
	var dummy = _crew("CREW 1", Vector3(6.0, 0.0, LANE_Z), 10000.0)
	await T.wait(self, 0.2)
	T.check(sh.ult == 0.0, "the meter starts empty (%.0f)" % sh.ult)
	for i in 24:
		sh._on_hit(dummy, false, _chest(dummy))
	T.check(is_equal_approx(sh.ult, 288.0), "24 body hits = 288 in the meter (%.1f)" % sh.ult)
	await T.key(self, KEY_Q)
	await T.wait(self, 0.1)
	T.check(not sh.hosing and sh.hose_uses == 0, "Q at 288 (96 %%) does nothing (hosing %s)" % sh.hosing)
	sh._on_hit(dummy, false, _chest(dummy))
	T.check(is_equal_approx(sh.ult, Shooter.ULT_FULL) and Shooter.ULT_FULL == 300.0, "one more = exactly 300: full (%.1f)" % sh.ult)
	sh._on_hit(dummy, true, _chest(dummy))
	T.check(is_equal_approx(sh.ult, 300.0), "the meter caps at 300 (%.1f)" % sh.ult)
	await T.wait(self, 0.1)
	T.check(sh.hud.ult_percent() == 100 and sh.hud.ult_ready(), "the ring reads 100 %% and shows Q (%d %%, ready %s)" % [sh.hud.ult_percent(), sh.hud.ult_ready()])
	p.frozen = true
	await T.key(self, KEY_Q)
	await T.wait(self, 0.1)
	T.check(not sh.hosing, "Q while Bob is frozen does nothing")
	p.frozen = false

	# real blobs: the meter gains what they dealt
	sh.ult = 0.0
	var hp0: float = dummy.hp
	var hits0: int = sh.hits.size()
	_aim(_chest(dummy))
	await T.left_down(self)
	for i in 60:
		_aim(_chest(dummy))
		await physics_frame
	await T.left_up(self)
	await T.wait(self, 0.6)
	var dealt: float = hp0 - dummy.hp
	T.check(sh.hits.size() - hits0 >= 5 and is_equal_approx(sh.ult, dealt), "real shots: %d hits dealt %.0f, the meter holds %.0f" % [sh.hits.size() - hits0, dealt, sh.ult])
	T.check(sh.hud.ult_percent() == floori(dealt / 3.0), "the ring reads %d %% (expect %d)" % [sh.hud.ult_percent(), floori(dealt / 3.0)])
	sh.tank = Shooter.TANK

	# --- the hose: duration, damage, push, tank, gun, speed ---
	dummy.body.global_position = Vector3(5.0, 0.0, LANE_Z)
	await T.wait(self, 0.2)
	# control: Bob's first-person walk forward without the hose (east: 4 m free; a strafe met corridor B's wall 0.75 m away)
	_aim(_chest(dummy))
	await T.key_down(self, KEY_W)
	var xc: float = p.global_position.x
	await T.wait(self, 0.5)
	var control_speed: float = absf(p.global_position.x - xc) / 0.5
	await T.key_up(self, KEY_W)
	await _stand(Vector3(BOB_X, 0.0, LANE_Z))
	_fill()
	_aim(_chest(dummy))
	var tank0: int = sh.tank
	var shots0: int = sh.shots_fired
	hose_frames = 0
	var numbers0: int = sh.hose_numbers
	await T.key(self, KEY_Q)
	T.check(sh.hosing and sh.hose_uses == 1, "Q at 300 starts the hose")
	T.check(sh.ult == 0.0, "the meter restarts at 0 when the hose starts (%.1f)" % sh.ult)
	T.check(sh.hud.shout_label.visible and sh.hud.shout_label.text == "SUPER SOAKER!" and not sh.hud.big.visible, "SUPER SOAKER! high on screen, the centre stays clear (%s)" % sh.hud.shout_label.text)
	var said: Array = sh.get_parent().dialogue.spoken.filter(func(x: String) -> bool: return x == "bob|SUPER SOAKER!")
	T.check(said.size() >= 1, "Bob shouts it in his own voice (slice 6, voice only)")
	await T.key(self, KEY_Q)
	T.check(sh.hose_uses == 1, "a second Q during the hose does not restart it")
	await T.left_down(self) # the trigger held all through
	# one measured second, tracking the target
	var x0: float = dummy.body.global_position.x
	var hp1: float = dummy.hp
	for i in 60:
		_aim(_chest(dummy))
		await physics_frame
	var push: float = dummy.body.global_position.x - x0
	var dmg: float = hp1 - dummy.hp
	T.check(absf(dmg - Shooter.HOSE_DPS) <= 2.0, "1 s of hose deals %.1f (60 +- 2)" % dmg)
	T.check(absf(push - Shooter.HOSE_PUSH) <= 0.3, "1 s of hose pushes the target %.2f m away (3 +- 0.3)" % push)
	var nums: int = sh.hose_numbers - numbers0
	T.check(nums >= 4 and nums <= 5, "damage numbers during that second: %d (one per 0.25 s)" % nums)
	T.check(is_equal_approx(sh.ult, 0.0), "hose damage does not charge the meter (%.1f)" % sh.ult)
	T.check(sh.hud.marker.visible, "the hit marker is on while the stream is on target")
	# Bob's speed: 70 % (checked every frame), and he really moves slower
	await T.key_down(self, KEY_W)
	var x1: float = p.global_position.x
	await T.wait(self, 0.5)
	var walked: float = absf(p.global_position.x - x1)
	await T.key_up(self, KEY_W)
	var ratio := (walked / 0.5) / control_speed
	T.check(absf(ratio - Shooter.HOSE_SPEED) < 0.05, "Bob walks %.2f m/s while hosing, %.2f m/s without: %.0f %% (70)" % [walked / 0.5, control_speed, ratio * 100.0])
	# the trigger was held 1.5 s of the hose: let go well before its end (holding on past it fires again, as it should)
	await T.left_up(self)
	T.check(sh.shots_fired == shots0, "the gun stays silent during the hose, trigger held 1.5 s (%d shots)" % (sh.shots_fired - shots0))
	T.check(sh.tank == tank0, "the hose uses no water (tank %d, was %d)" % [sh.tank, tank0])
	await _stand(Vector3(BOB_X, 0.0, LANE_Z))
	await T.wait_for(self, func() -> bool: return not sh.hosing, 6.0)
	T.check(absi(hose_frames - 300) <= 1, "the hose lasts %d frames (5 s = 300 +- 1)" % hose_frames)
	T.check(bad_speed == 0, "Bob at 70 %% speed on every hose frame (%d bad of %d)" % [bad_speed, hose_frames])
	T.check(is_equal_approx(p.walk_speed, walk0) and is_equal_approx(p.sprint_speed, sprint0), "speed back after the hose (%.2f / %.2f)" % [p.walk_speed, p.sprint_speed])
	T.check(sh.hose_node == null or not is_instance_valid(sh.hose_node) or not sh.hose_node.visible, "the stream is gone after the hose")
	T.check(sh.hose_sound == null or not is_instance_valid(sh.hose_sound), "the hose loop stopped")
	await T.wait(self, 1.5)
	T.check(not sh.hud.shout_label.visible, "SUPER SOAKER! goes away")
	T.check(sh.hud.ult_percent() == 0, "the ring is back at 0 %% (%d)" % sh.hud.ult_percent())

	# --- reach: 9.5 m hit, 10.9 m dry ---
	for pair: Array in [[9.5, true], [10.9, false]]:
		dummy.body.global_position = Vector3(BOB_X + float(pair[0]), 0.0, LANE_Z)
		dummy.hp = 10000.0
		await T.wait(self, 0.2)
		_fill()
		_aim(_chest(dummy))
		await T.key(self, KEY_Q)
		await T.wait(self, 0.5)
		sh.end_hose()
		var got: bool = dummy.hp < 10000.0
		T.check(got == bool(pair[1]), "target at %.1f m: %s (hp %.1f)" % [pair[0], "soaked" if got else "dry", dummy.hp])

	# --- the first enemy takes it all; a stack blocks; a wall stops the push ---
	var back = _crew("CREW 2", Vector3(7.0, 0.0, LANE_Z), 10000.0)
	dummy.body.global_position = Vector3(5.0, 0.0, LANE_Z)
	dummy.hp = 10000.0
	await T.wait(self, 0.2)
	_fill()
	_aim(_chest(dummy))
	await T.key(self, KEY_Q)
	await T.wait(self, 0.5)
	sh.end_hose()
	T.check(dummy.hp < 10000.0 and back.hp == 10000.0, "the stream stops at the first enemy (front %.0f, behind %.0f)" % [dummy.hp, back.hp])
	back.body.global_position = Vector3(20.0, 0.0, 20.0) # out of the way
	# a stack: Bob in corridor A west, the target behind the stack at x 5.6..6.4
	await _stand(Vector3(2.0, 0.0, -0.7))
	dummy.body.global_position = Vector3(8.0, 0.0, -0.7)
	dummy.hp = 10000.0
	await T.wait(self, 0.2)
	_fill()
	_aim(_chest(dummy))
	await T.key(self, KEY_Q)
	await T.wait(self, 0.5)
	sh.end_hose()
	T.check(dummy.hp == 10000.0, "a stack blocks the stream (hp %.0f)" % dummy.hp)
	# the east wall: pushed from x 11.8 for 1.5 s, it stays inside
	await _stand(Vector3(4.0, 0.0, LANE_Z))
	dummy.body.global_position = Vector3(11.8, 0.0, LANE_Z)
	await T.wait(self, 0.2)
	_fill()
	_aim(_chest(dummy))
	await T.key(self, KEY_Q)
	for i in 90:
		_aim(_chest(dummy))
		await physics_frame
	sh.end_hose()
	var wx: float = dummy.body.global_position.x
	T.check(wx > 12.0 and wx < 12.65 - 0.15, "the wall stops the push (x %.2f, wall at 12.65)" % wx)

	# --- a hose kill: down, feed, BOSSY after 2 crew ---
	sh.enemies.clear() # the dummies step aside: a real squad
	dummy.body.queue_free()
	back.body.queue_free()
	await T.wait(self, 0.2)
	var squad: Array = sh.spawn_squad()
	for e in squad:
		e.ai = e.Ai.OFF
	squad[0].damage(1000.0) # one crew down already
	squad[2].body.global_position = Vector3(6.0, 0.0, LANE_Z)
	await _stand(Vector3(BOB_X, 0.0, LANE_Z))
	_fill()
	_aim(_chest(squad[2]))
	var feed0: int = sh.hud.feed.get_child_count()
	await T.key(self, KEY_Q)
	var kill_frames := 0
	for i in 150:
		if squad[2].down:
			break
		kill_frames += 1
		_aim(_chest(squad[2]))
		await physics_frame
	T.check(squad[2].down, "the hose puts a crew (100 HP) down in %.2f s (expect about 1.67)" % (kill_frames / 60.0))
	await T.wait(self, 0.1)
	T.check(sh.hud.feed.get_child_count() > feed0, "the hose kill is in the kill feed")
	T.check(sh.boss != null, "BOSSY walks in after the hose's kill (2 crew down)")
	sh.end_hose()

	# --- abort and K.O. mid-hose put everything back ---
	_fill()
	await T.key(self, KEY_Q)
	await T.wait(self, 0.3)
	T.check(sh.hosing and p.walk_speed < walk0, "hosing before the K.O.")
	sh.bob_hp = 1.0
	sh._bob_hit({"from": "test", "damage": 5.0}, p.global_position)
	await T.wait(self, 0.2)
	T.check(not sh.hosing and is_equal_approx(p.walk_speed, walk0), "a K.O. ends the hose and gives the speed back (%.2f)" % p.walk_speed)
	T.check(sh.hose_sound == null or not is_instance_valid(sh.hose_sound), "no hose loop after the K.O.")
	await _drop_shooter()
	await _new_shooter()
	_fill()
	await T.key(self, KEY_Q)
	await T.wait(self, 0.3)
	T.check(sh.hosing, "hosing before abort()")
	var hose_node = sh.hose_node
	sh.abort()
	await T.wait(self, 0.2)
	T.check(is_equal_approx(p.walk_speed, walk0) and is_equal_approx(p.sprint_speed, sprint0), "abort() mid-hose gives the speed back (%.2f / %.2f)" % [p.walk_speed, p.sprint_speed])
	T.check(not is_instance_valid(hose_node), "abort() removes the stream")
	T.check(sh.hose_sound == null or not is_instance_valid(sh.hose_sound), "abort() stops the hose loop")
	T.check(stream_off == 0, "the stream is drawn exactly while hosing (%d bad frames)" % stream_off)
	sh.queue_free()
	lvl.queue_free()
	await process_frame
	T.finish(self)
