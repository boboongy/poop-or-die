extends RefCounted
## A bot that plays WATER WAR (scripts/shooter.gd) with REAL input (W / Shift / Q key events, the left mouse button) and PERFECT
## aim: every frame it points the camera exactly at the nearest enemy head it can see and holds the trigger; with nobody in sight it
## walks along the U (shooter.gd U_PATH) toward the nearest enemy still up; Q as soon as the meter is full and someone is in sight;
## an empty tank sends it back to corridor A's sinks. It never dodges. Its time is a LOWER bound for a person (the aim is perfect).
## Use: `var bot := WarBot.new(tree, shooter)`, then `await bot.play(limit)` -> {"won", "seconds", "hp", "shots", "hoses", "refills"}.
## `human = true` (tests/measure_level4_time.gd only, a MEASURING guess, not a design): REACT s before firing at a new target, aims at
## the chest with an angle error (sigma AIM_SIGMA rad, a new one every AIM_EVERY s), walks instead of sprinting.
const T := preload("res://tests/t.gd")
const REACT := 0.35
const AIM_SIGMA := 0.03
const AIM_EVERY := 0.3

const LOOK_AHEAD := 1.5 ## m along the U to the next walking waypoint
const REFILL_AT := Vector3(4.0, 0.0, 0.3) ## corridor A, 0.5 m from sink 3's tap

var tree: SceneTree
var sh ## shooter.gd
var p ## player.gd
var _held := {}
var _fire := false
var log_lines: Array[String] = []
var human := false
var rng := RandomNumberGenerator.new()
var _last_target = null
var _react_left := 0.0
var _err := Vector2.ZERO
var _err_left := 0.0


func _init(scene_tree: SceneTree, shooter) -> void:
	tree = scene_tree
	sh = shooter
	p = shooter.bob
	sh.hit.connect(func(e, head: bool, _amount: float, killed: bool, at: Vector3) -> void:
		if killed:
			log_lines.append("%s down (head %s) at %s, Bob at %s, %.1f m" % [e.name, head, e.body.global_position, p.global_position, at.distance_to(sh.cam.global_position)]))


func _hold(code: int, on: bool) -> void:
	if bool(_held.get(code, false)) == on:
		return
	_held[code] = on
	T._key_event(code, on)


func _trigger(on: bool) -> void:
	if on == _fire:
		return
	_fire = on
	if on:
		T.left_down(tree)
	else:
		T.left_up(tree)


func release() -> void:
	for code: int in _held:
		if _held[code]:
			T._key_event(code, false)
	_held = {}
	_trigger(false)


## The nearest enemy whose head the camera can see, or null.
func target():
	var eye: Vector3 = sh.cam.global_position
	var best = null
	var best_d := INF
	for e in sh.enemies:
		if e.down:
			continue
		var h: Vector3 = e.head_center()
		var d := eye.distance_to(h)
		if d < sh.REACH - 0.5 and d < best_d and sh.clear_line(eye, h):
			best = e
			best_d = d
	return best


## A point on the U, `s` metres from its start.
func u_point(s: float) -> Vector3:
	var path: Array[Vector3] = sh.U_PATH
	for i in path.size() - 1:
		var seg: float = path[i].distance_to(path[i + 1])
		if s <= seg or i == path.size() - 2:
			return path[i].lerp(path[i + 1], clampf(s / seg, 0.0, 1.0))
		s -= seg
	return path[path.size() - 1]


func _look(at: Vector3) -> void:
	var d: Vector3 = at - sh.cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _walk_to(at: Vector3) -> void:
	var d: Vector3 = at - p.global_position
	p.set_camera(atan2(-d.x, -d.z), 0.0)
	_hold(KEY_W, Vector2(d.x, d.z).length() > 0.15)
	_hold(KEY_SHIFT, not human)


## Aim at `e` (perfect: the head; human: the chest plus the current error). False while a human is still reacting.
func _aim(e, delta: float) -> bool:
	if not human:
		_look(e.head_center())
		return true
	if e != _last_target:
		_last_target = e
		_react_left = REACT
	_err_left -= delta
	if _err_left <= 0.0:
		_err_left = AIM_EVERY
		_err = Vector2(rng.randfn(0.0, AIM_SIGMA), rng.randfn(0.0, AIM_SIGMA))
	var ax: Array[Vector3] = e.body_axis()
	_look((ax[0] + ax[1]) / 2.0 + Vector3.UP * 0.15)
	p.set_camera(p.get_camera_yaw() + _err.x, p.get_camera_pitch() + _err.y)
	_react_left -= delta
	return _react_left <= 0.0


## Walk along the U toward `goal_s` (metres along it).
func _walk_u(goal_s: float) -> void:
	var here: float = sh.u_param(p.global_position)
	var s := minf(here + LOOK_AHEAD, goal_s) if goal_s > here else maxf(here - LOOK_AHEAD, goal_s)
	var at := u_point(s)
	if absf(goal_s - here) < 0.3:
		at = u_point(goal_s)
	_walk_to(at)


func play(limit: float) -> Dictionary:
	var t := 0.0
	var refilling := false
	var stuck_t := 0.0
	var last_pos: Vector3 = p.global_position
	while sh.running and not sh.over and t < limit:
		await tree.physics_frame
		t += 1.0 / 60.0
		if not sh.fighting():
			continue
		if sh.tank <= 0:
			refilling = true
		if refilling and sh.tank >= sh.TANK:
			refilling = false
		var e = target()
		if refilling:
			_trigger(false)
			var s_goal: float = sh.u_param(REFILL_AT)
			if absf(sh.u_param(p.global_position) - s_goal) > 1.0 or sh.sink_distance(p.global_position) > sh.REFILL_RANGE - 0.2:
				if absf(sh.u_param(p.global_position) - s_goal) > 1.0:
					_walk_u(s_goal)
				else:
					_walk_to(REFILL_AT)
			else:
				_hold(KEY_W, false)
			continue
		if e != null:
			_hold(KEY_W, false)
			_hold(KEY_SHIFT, false)
			var ready := _aim(e, 1.0 / 60.0)
			if ready and sh.ult >= sh.ULT_FULL and not sh.hosing:
				log_lines.append("Q at t %.1f on %s (%.0f hp), ult %.0f" % [t, e.name, e.hp, sh.ult])
				await T.key(tree, KEY_Q)
			_trigger(ready and not sh.hosing)
			continue
		_last_target = null
		_trigger(false)
		# nobody in sight: toward the nearest enemy still up, along the U
		var here: float = sh.u_param(p.global_position)
		var goal := here
		var best := INF
		for x in sh.enemies:
			if x.down:
				continue
			var s: float = sh.u_param(x.body.global_position)
			if absf(s - here) < best:
				best = absf(s - here)
				goal = s
		if best == INF: # BOSSY not out yet: hold still
			_hold(KEY_W, false)
			continue
		_walk_u(goal)
		if p.global_position.distance_to(last_pos) < 0.01 and bool(_held.get(KEY_W, false)):
			stuck_t += 1.0 / 60.0
		else:
			stuck_t = 0.0
		last_pos = p.global_position
		if stuck_t > 2.0:
			log_lines.append("stuck at %s for 2 s (t %.1f)" % [p.global_position, t])
			stuck_t = -5.0
	release()
	log_lines.append("end t %.1f: %s" % [t, sh.enemies.map(func(x) -> String: return "%s %.0f hp%s" % [x.name, x.hp, " DOWN" if x.down else ""])])
	var boss_down: bool = sh.boss != null and sh.boss.down
	return {"won": boss_down, "seconds": t, "hp": sh.bob_hp, "shots": sh.shots_fired, "hoses": sh.hose_uses, "refills": sh.refills}
