extends RefCounted
## Stage 4 "WATER WAR": one enemy (a crew Jijio or BOSSY) and its hitboxes. The hitboxes follow the skeleton every time they are asked
## (tests/probe_shooter.gd, standing idle, the same for Bob and Jijio: head bone DEF-spine.006 at 0.90 m, the head mesh 0.88-1.30 m,
## eyes 0.99-1.13 m, body 0.05-0.88 m and 0.17 m either side). Head = a sphere HEAD_RADIUS round the head bone + HEAD_UP (along the
## model's up, so it follows a lean or a fall); body = a capsule from the feet to the chest bone.
## The AI (SPEC Stage 4 plan (3); numbers PROPOSAL): at a cover point it waits at the HIDE spot, steps out to the PEEK spot and fires
## bursts while it can see Bob, steps back; after UNSEEN_MOVE s without seeing him it walks (along the corridor middles, shooter.gd
## U_PATH) to the next free cover point toward him. It aims at Bob's chest where he IS (no lead), so moving dodges.

const Pose := preload("res://scripts/pose.gd")
const Props := preload("res://scripts/shooter_props.gd")

enum Ai { OFF, HIDE, PEEK, MOVE }

const HIDE_MIN := 1.5
const HIDE_MAX := 2.5
const PEEK_MIN := 1.2
const PEEK_MAX := 2.0
const UNSEEN_MOVE := 4.0
const REACTION := 0.35 ## s from arriving at the peek spot to the first shot
const BURST_GAP := 0.6 ## s between bursts while peeking
const STEP_SPEED := 2.5 ## m/s: the sidestep between hide and peek
const MOVE_SPEED := 2.6 ## m/s: walking to another cover point
const AIM_SCATTER := 0.05 ## rad
const CHEST := 0.9 ## where they look from
const MUZZLE_HOLD := Vector3(-0.3, 0.85, 0.3) ## the gun in the right hand, model space (water_fight.gd, first screenshot pass)

const HEAD_BONE := "DEF-spine.006"
const CHEST_BONE := "DEF-spine.003" ## 0.76 m: the capsule's top (its round end reaches 0.94, where the head starts)
const HEAD_UP := 0.19
const HEAD_RADIUS := 0.21
const BODY_RADIUS := 0.18
const BODY_FOOT := 0.15 ## the capsule's bottom end, above the feet
const KO_TILT := -1.35

var body: Node3D ## npc_jijio.gd
var name := ""
var hp := 100.0
var max_hp := 100.0
var down := false
# the AI
var ai := Ai.OFF
var cover := -1 ## index into shooter.gd COVERS
var burst := 3 ## shots per burst
var burst_rate := 5.0 ## shots/s inside a burst
var shot_damage := 6.0
var blob_speed := 18.0
var moves := 0 ## cover changes (tests)
var gun: Node3D
var unseen := 0.0 ## s since they last saw Bob
var seen_once := false ## the "THERE HE IS!" bark is for the first sight only

var _sh ## shooter.gd
var _rng: RandomNumberGenerator
var _left := 0.0 ## s left in HIDE / PEEK
var _fire_left := 0.0 ## s to the next shot (or burst)
var _burst_left := 0 ## shots left in this burst
var _path: Array[Vector3] = []
var _stuck := 0.0
var _sk: Skeleton3D
var _head := -1
var _chest := -1


func _init(npc: Node3D, enemy_name: String, hit_points: float) -> void:
	body = npc
	name = enemy_name
	hp = hit_points
	max_hp = hit_points
	_sk = Pose.skeleton_of(npc.get_node("Model"))
	_head = _sk.find_bone(HEAD_BONE)
	_chest = _sk.find_bone(CHEST_BONE)


func _bone(i: int) -> Vector3:
	return _sk.global_transform * _sk.get_bone_global_pose(i).origin


func _up() -> Vector3:
	return (body.get_node("Model") as Node3D).global_basis.y.normalized()


func head_center() -> Vector3:
	return _bone(_head) + _up() * HEAD_UP


## The body capsule's axis: [bottom, top].
func body_axis() -> Array[Vector3]:
	return [body.global_position + _up() * BODY_FOOT, _bone(_chest)]


## Where along the segment a -> b a blob first touches this enemy: {"t": metres from a, "head": bool}, or {} for a miss.
## `wide` makes both hitboxes that much fatter (the hose's stream).
func hit_along(a: Vector3, b: Vector3, wide := 0.0) -> Dictionary:
	if down:
		return {}
	var th := _sphere(a, b, head_center(), HEAD_RADIUS + wide)
	var ax := body_axis()
	var tb := _capsule(a, b, ax[0], ax[1], BODY_RADIUS + wide)
	if th < 0.0 and tb < 0.0:
		return {}
	if th >= 0.0 and (tb < 0.0 or th <= tb):
		return {"t": th, "head": true}
	return {"t": tb, "head": false}


## Take `amount`; true when this hit put the enemy down.
func damage(amount: float) -> bool:
	if down:
		return false
	hp = maxf(hp - amount, 0.0)
	if hp > 0.0:
		return false
	down = true
	ai = Ai.OFF
	body.velocity = Vector3.ZERO
	Pose.locomotion(body.anim(), 0.0, 2.8)
	var model: Node3D = body.get_node("Model")
	model.create_tween().tween_property(model, "rotation:x", KO_TILT, 0.4)
	return true


## One physics frame of being shoved at velocity `v` (the hose): walls and stacks stop it; their own walking velocity is kept.
func push(v: Vector3) -> void:
	if down:
		return
	var keep: Vector3 = body.velocity
	body.velocity = Vector3(v.x, 0.0, v.z)
	body.move_and_slide()
	body.velocity = keep


# --- AI ------------------------------------------------------------------------------------------------------------

## Start the AI at cover point `at` (standing at its hide spot), with a gun in the right hand.
func start_ai(shooter, at: int, rng: RandomNumberGenerator) -> void:
	_arm(shooter, rng)
	cover = at
	var c: Dictionary = _sh.COVERS[at]
	body.global_position = Vector3(c["hide"].x, body.global_position.y, c["hide"].z)
	ai = Ai.HIDE
	_left = _rng.randf_range(0.5, HIDE_MAX) # staggered: they do not all peek at once


## Start the AI walking in from where they stand to cover point `at` (BOSSY's entrance), then the usual loop.
func enter(shooter, at: int, rng: RandomNumberGenerator) -> void:
	_arm(shooter, rng)
	_path = _sh.path_between(body.global_position, at)
	cover = at
	ai = Ai.MOVE


func _arm(shooter, rng: RandomNumberGenerator) -> void:
	_sh = shooter
	_rng = rng
	gun = Props.make_gun(Props.BROWN_GUN)
	body.get_node("Model").add_child(gun)
	gun.position = MUZZLE_HOLD
	gun.rotation = Vector3(0.0, PI, 0.0)


func _eyes() -> Vector3:
	return body.global_position + Vector3.UP * CHEST


func tick(delta: float) -> void:
	if down or ai == Ai.OFF:
		return
	var sees: bool = _sh.clear_line(_eyes(), _sh.bob_head(), self)
	unseen = 0.0 if sees else unseen + delta
	if sees and not seen_once:
		seen_once = true
		_sh.bark(self, "seen")
	match ai:
		Ai.HIDE:
			_step_to(_sh.COVERS[cover]["hide"], STEP_SPEED, delta)
			_face_bob()
			_left -= delta
			if _left <= 0.0:
				if unseen >= UNSEEN_MOVE and _advance():
					return
				ai = Ai.PEEK
				_left = _rng.randf_range(PEEK_MIN, PEEK_MAX)
				_fire_left = REACTION
				_burst_left = 0
		Ai.PEEK:
			var there := _step_to(_sh.COVERS[cover]["peek"], STEP_SPEED, delta)
			_face_bob()
			if there:
				_left -= delta
				_shoot(delta, sees)
			if _left <= 0.0:
				ai = Ai.HIDE
				_left = _rng.randf_range(HIDE_MIN, HIDE_MAX)
		Ai.MOVE:
			if _path.is_empty():
				ai = Ai.HIDE
				_left = 0.8
				return
			if _step_to(_path[0], MOVE_SPEED, delta, true):
				_path.remove_at(0)


## Bursts: `burst` shots at `burst_rate`, BURST_GAP between bursts; only while Bob is in sight.
func _shoot(delta: float, sees: bool) -> void:
	_fire_left -= delta
	if _fire_left > 0.0:
		return
	if not sees:
		_burst_left = 0
		_fire_left = 0.1
		return
	if _burst_left <= 0:
		_burst_left = burst
		_sh.bark(self, "burst")
	_burst_left -= 1
	_fire_left = 1.0 / burst_rate if _burst_left > 0 else BURST_GAP
	var muzzle: Vector3 = (gun.get_node("Muzzle") as Node3D).global_position
	var aim: Vector3 = _sh.bob_chest() - muzzle
	var basis := Basis.looking_at(aim.normalized(), Vector3.UP)
	var angle := _rng.randf() * TAU
	var off := tan(AIM_SCATTER * sqrt(_rng.randf()))
	var dir := (aim.normalized() + (basis.x * cos(angle) + basis.y * sin(angle)) * off).normalized()
	_sh.enemy_fire(self, muzzle, dir)


## Walk to the next free cover point toward Bob along the U. False when there is none (they stay).
func _advance() -> bool:
	var s_bob: float = _sh.u_param(_sh.bob.global_position)
	var here: float = _sh.cover_s(cover)
	var step := -1 if s_bob < here else 1
	var i := cover + step
	while i >= 0 and i < _sh.COVERS.size():
		if absf(_sh.cover_s(i) - s_bob) >= absf(here - s_bob): # would not bring them nearer
			return false
		if not _sh.cover_taken(i, self):
			break
		i += step
	if i < 0 or i >= _sh.COVERS.size():
		return false
	_path = _sh.path_between(body.global_position, i)
	cover = i
	moves += 1
	unseen = 0.0
	ai = Ai.MOVE
	_sh.bark(self, "cover")
	return true


## Move toward `to` (floor point) with collisions; true when there. `turn`: face the way they walk.
func _step_to(to: Vector3, speed: float, delta: float, turn := false) -> bool:
	var d := Vector3(to.x - body.global_position.x, 0.0, to.z - body.global_position.z)
	var dist := d.length()
	if dist < 0.05:
		body.velocity = Vector3.ZERO
		Pose.locomotion(body.anim(), 0.0, 2.8)
		_stuck = 0.0
		return true
	var v := d / dist * minf(speed, dist / delta)
	body.velocity = Vector3(v.x, 0.0, v.z)
	var before: Vector3 = body.global_position
	body.move_and_slide()
	var moved := Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length()
	Pose.locomotion(body.anim(), moved / delta, 2.8)
	if turn:
		body.face_yaw(atan2(d.x, d.z))
	# blocked (by Bob standing in the way): after a second, count the point as reached
	_stuck = _stuck + delta if moved < speed * delta * 0.2 else 0.0
	if _stuck > 1.0:
		_stuck = 0.0
		return true
	return false


func _face_bob() -> void:
	var to: Vector3 = _sh.bob.global_position - body.global_position
	body.face_yaw(atan2(to.x, to.z))


## First touch of segment a -> b with a sphere, in metres from a; -1 for none.
static func _sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> float:
	var seg := b - a
	var length := seg.length()
	if length < 0.0001:
		return 0.0 if a.distance_to(c) <= r else -1.0
	var d := seg / length
	var m := a - c
	var bq := m.dot(d)
	var cq := m.dot(m) - r * r
	if cq <= 0.0:
		return 0.0 # starts inside
	var disc := bq * bq - cq
	if bq > 0.0 or disc < 0.0:
		return -1.0
	var t := -bq - sqrt(disc)
	return t if t <= length else -1.0


## First touch of segment a -> b with a capsule p-q (radius r), in metres from a; -1 for none. The closest approach of the two
## segments, stepped back to where the blob's line enters the radius (exact for a shot across the axis, which is how they fly here).
static func _capsule(a: Vector3, b: Vector3, p: Vector3, q: Vector3, r: float) -> float:
	var d1 := b - a
	var d2 := q - p
	var rr := a - p
	var aa := d1.dot(d1)
	var ee := d2.dot(d2)
	var ff := d2.dot(rr)
	var s := 0.0
	var t := 0.0
	if aa < 0.0001:
		t = clampf(ff / ee, 0.0, 1.0)
	else:
		var cc := d1.dot(rr)
		var bb := d1.dot(d2)
		var denom := aa * ee - bb * bb
		s = clampf((bb * ff - cc * ee) / denom, 0.0, 1.0) if denom > 0.000001 else 0.0
		t = (bb * s + ff) / ee
		if t < 0.0:
			t = 0.0
			s = clampf(-cc / aa, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((bb - cc) / aa, 0.0, 1.0)
	var c1 := a + d1 * s
	var c2 := p + d2 * t
	var dist := c1.distance_to(c2)
	if dist > r:
		return -1.0
	var length := sqrt(aa)
	var back := sqrt(r * r - dist * dist)
	return maxf(s * length - back, 0.0)
