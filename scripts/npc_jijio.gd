extends CharacterBody3D
## Jijio NPC (grey-box). Stands still until told to chase Bob, then walks to a slot
## in a ring around him and lunges at him. `idle`/`walk`/`run`/`sit`/`wash`/`stand_up` are real baked clips
## (FACTORY_TODO batches 1-2); the "kick" is still code-driven (see FACTORY_TODO.md).

const Pose := preload("res://scripts/pose.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Footsteps := preload("res://scripts/footsteps.gd")
const WebMerge := preload("res://scripts/web_merge.gd")

signal arrived
signal reached ## finished walking to a go_to() spot

enum State { IDLE, SIT, QUEUED, CHASE, KICK, WALK, WASH, SLIP, FIGHT, DANCE } ## FIGHT: Level 4, fight.gd drives the body and the clips; DANCE: Level 5, dance.gd does

const SLIDE_SECONDS := 1.0 ## slip: slides on their back, then lies still, then gets up (stand-ins for the factory's slip clip)
const LIE_SECONDS := 0.6
const GETUP_SECONDS := 0.5
const SLIP_IMMUNE_SECONDS := 3.0 ## after getting up they can walk out of the puddle without falling again

@export var speed := 4.0
@export var ring_radius := 0.8
@export var turn_speed := 10.0
@export var count_radius := 3.0 ## within this distance of Bob, the Jijio counts as having reached him
@export var make_way_clearance := 0.6 ## how far from Bob's path a queued Jijio stands when he walks through
@export var make_way_reach := 2.4 ## how far ahead of Bob a queued Jijio starts stepping aside
@export var shuffle_speed := 2.5
@export var walk_speed := 1.6
const ANIM_WALK_RUN_MID := 2.8 ## m/s: between walk_speed 1.6 and the chase speed 4.0
const SHOVE_SIDE_SPEED := 2.0 ## m/s sideways off Bob's line while he pushes into them (PROPOSAL until played)
const SHOVE_AHEAD_SPEED := 1.2 ## m/s along his line: when the side is a wall, Bob pushes them ahead at this pace
var _shove_side := 1.0
var _shove_frame := -1

var state := State.IDLE

var _target: Node3D
var _ring_angle := 0.0
var _time := 0.0
var _repath := 0.0
var _counted := false
var _walk_target := Vector3.ZERO
var _wash_yaw := 0.0

var interaction_prompt := ""
var priority := 0.0 ## metres of head start in Bob's E-prompt scan (player.gd); SHUFFLE QUEEN beats the stall doors beside her
var talking := false ## in a conversation with Bob: stands still
var talk_reach := 0.0 ## m: how close Bob must be for this Jijio's E prompt (0 = his own `reach`); queue_talk.gd sets 1.5 on the queue
var _interact_callback := Callable()

var home := Vector3.ZERO ## queue spot
var _bob: CharacterBody3D
var _heading := Vector3.ZERO ## last direction Bob was walking
var _hold := 0.0 ## seconds the step-aside stays after Bob stops
var _side := 1.0
var _kick_high := false ## the thrust is at its peak (one kick sound per thrust)
var _slip_time := 0.0
var _slip_dir := Vector3.ZERO
var _slip_immune := 0.0
var _resume_walk := false ## they were walking somewhere when they fell: carry on afterwards
## Stage 6c E: a queue Jijio standing on its spot is never static: every 4-8 s (random per Jijio) it switches clip, `talk` toward a
## neighbour 50 %, `squirm` 30 %, `twerk` 20 %, no plain idle. Stops at once when it moves (makes way, the queue moves, a scene).
const FIDGET_MIN := 4.0
const FIDGET_MAX := 8.0
const FIDGET_NEIGHBOUR := 1.3 ## m: a queued Jijio this close can be talked to
var fidget_clip := "" ## the clip playing now ("" = none: locomotion drives the clips)
var _fidget_t := -1.0
var _fidget_rest_yaw := 0.0
## Level 2 "The flood" (flood_water.gd): once the water is SWIM_DEPTH deep this Jijio floats at the surface, drifting round the spot where
## the water lifted it: queue and walkers `swim_panic`, stall occupants `tread_water`, every FLOAT_ON_BACK_EVERY-th occupant `float`s on
## its back (owner D1, 2026-09-27). The factory clips' origin is the WATER SURFACE: the model is lifted from the body to it. It never
## blocks Bob: its body stops colliding and Bob's swimming pushes it aside. When the water is shallow again it stands where it is and `landed` fires.
signal landed
var leaving := false ## stand_up() is playing: still State.SIT, but on the way out
var water: Node = null
var floating := false
const FLOAT_DEPTH := 0.62 ## same as Bob: the body's feet this far under the surface
const FLOAT_ON_BACK_EVERY := 4
const FLOAT_BACK_SHIFT := 0.25 ## m toward the stall door for the `float` (on the back) occupants (Stage 6c B, test_jijio_walls)
static var _occupants_floated := 0
const FLOAT_WANDER := 0.5 ## m: how far they drift from where they floated up
const FLOAT_SPEED := 0.3
const FLOAT_PUSH_RADIUS := 0.75 ## Bob closer than this pushes them away...
const FLOAT_PUSH_SPEED := 2.2 ## ... this fast (Bob swims at 2.2)
var _float_anchor := Vector3.ZERO
var _float_goal := Vector3.ZERO
var _float_phase := 0.0
var _float_layer := 0
var _float_was_sitting := false
var _float_seat := Vector3.ZERO
## Stage 6c (B), owner screenshot 2026-09-28 (the kick-out crowd in the flood level): no Jijio's head or chest ever shows inside a wall,
## a door leaf or a sink. The swim and float poses reach 0.4-0.5 m past the 0.2 m body and a swinging door leaf can close on a body, so
## whenever one of these bones overlaps the level the body is pushed out along the contact (tests/test_jijio_walls.gd).
const CLEAR_BONES := ["DEF-spine.006", "DEF-spine.003"] ## head, chest
const CLEAR_RADIUS := 0.1
const KICK_REACH := 0.56 ## m: how far the kick's thrust (0.25) and lean (0.35 rad at head height) carry the head forward
static var _char_rids: Array[RID] = [] ## Bob and every Jijio: the wall guard ignores characters
static var _char_rids_frame := -1
var _skeleton: Skeleton3D
var _clear_ids: Array[int] = []
var _clear_q := PhysicsShapeQueryParameters3D.new()
var _kick_scale := 1.0 ## the kick's thrust and lean shrink to the room in front of the kicker
var _kick_room_check := 0.0

@onready var _model: Node3D = $Model
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false)


func _ready() -> void:
	add_child(Footsteps.new())
	add_to_group("jijio")
	if WebMerge.wanted(): # the web build: her 9 meshes drawn as 3 (WebGL draw calls were the 3-4 FPS)
		WebMerge.merge(_model)


## Make this Jijio interactable: Bob gets `prompt_text` next to them and E calls `callback(player)`.
func set_interaction(prompt_text: String, callback: Callable) -> void:
	interaction_prompt = prompt_text
	_interact_callback = callback
	add_to_group("interactable")


func clear_interaction() -> void:
	interaction_prompt = ""
	_interact_callback = Callable()
	remove_from_group("interactable")


func prompt() -> String:
	return interaction_prompt


## The object whose method E calls (null without a prompt): queue_talk.gd only clears prompts it set itself.
func interaction_owner() -> Object:
	return _interact_callback.get_object() if _interact_callback.is_valid() else null


func interaction_point() -> Vector3:
	return global_position


func interact(player: Node3D) -> void:
	if _interact_callback.is_valid():
		_interact_callback.call(player)


func get_yaw() -> float:
	return _model.rotation.y


func set_expression(key: String, value: float) -> void:
	Pose.set_blend(_model, key, value)


func face_yaw(yaw: float) -> void:
	_model.rotation.y = yaw


## Seated on the toilet: the baked `sit` clip (loops). The model's own position stays where it was spawned
## (the seat spot, see population.gd) -- the clip bakes the hip height itself, no y offset needed.
func sit() -> void:
	leaving = false
	Pose.ensure_loop(_anim, "sit")
	_anim.play("sit")
	state = State.SIT


## Undo sit(): play the baked `stand_up` clip (chains from `sit`, ends standing 0.34 m in front of the seat spot,
## same anchor the whole time -- see FACTORY_TODO batch 2 notes), then walk to `spot` (in front of the toilet).
func stand_up(spot: Vector3) -> void:
	leaving = true # the state stays SIT for the whole clip; the soundscape must not groan from a Jijio already getting up (test_ambience L4)
	_anim.play("stand_up")
	while _anim.is_playing():
		await get_tree().physics_frame
		if not is_inside_tree(): # the level was unloaded mid-clip (F4, N, R): get_tree() is null now (test_level_flow)
			return
	var tween := create_tween()
	tween.tween_property(self, "global_position", spot, 0.4)
	await tween.finished
	state = State.IDLE


func anim() -> AnimationPlayer:
	return _anim


func is_sitting() -> bool:
	return state == State.SIT


func is_walking() -> bool:
	return state == State.WALK


func is_washing() -> bool:
	return state == State.WASH


## Stop washing: the next frame's Pose.locomotion() blends the AnimationPlayer from `wash` to `idle`.
func stop_washing() -> void:
	if state != State.WASH:
		return
	state = State.IDLE


## Stop walking where they are.
func stop_walking() -> void:
	_resume_walk = false
	if state == State.WALK:
		velocity = Vector3.ZERO
		state = State.IDLE


## Walk (calmly, along the navmesh) to `spot`; emits `reached` on arrival. Someone lying on the floor gets up first.
func go_to(spot: Vector3) -> void:
	_walk_target = spot
	_repath = 0.0
	if state == State.SLIP:
		_resume_walk = true
	else:
		state = State.WALK


func is_slipping() -> bool:
	return state == State.SLIP


## Fall on wet floor while walking. `dir` is the way they were going. Returns false if they don't fall
## (not walking, or they only just got up).
func slip(dir: Vector3) -> bool:
	dir.y = 0.0
	if state != State.WALK or _slip_immune > 0.0 or dir.length() < 0.01:
		return false
	_slip_dir = dir.normalized()
	_slip_time = 0.0
	_resume_walk = true
	_slip_immune = SLIDE_SECONDS + LIE_SECONDS + GETUP_SECONDS + SLIP_IMMUNE_SECONDS
	state = State.SLIP
	Sfx.play_at(self, "slip", global_position + Vector3(0.0, 0.3, 0.0))
	return true


func _slip(delta: float) -> void:
	_slip_time += delta
	var t := _slip_time
	var fall := 0.0
	var slide := 0.0
	if t < SLIDE_SECONDS:
		fall = minf(t / 0.3, 1.0)
		slide = 2.4 * (1.0 - t / SLIDE_SECONDS)
	elif t < SLIDE_SECONDS + LIE_SECONDS:
		fall = 1.0
	elif t < SLIDE_SECONDS + LIE_SECONDS + GETUP_SECONDS:
		fall = 1.0 - (t - SLIDE_SECONDS - LIE_SECONDS) / GETUP_SECONDS
	else:
		_end_slip()
		return
	_model.rotation.x = -1.35 * fall # on their back
	velocity.x = _slip_dir.x * slide
	velocity.z = _slip_dir.z * slide
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()


func _end_slip() -> void:
	_model.rotation.x = 0.0
	velocity = Vector3.ZERO
	state = State.WALK if _resume_walk else State.IDLE
	_resume_walk = false


## Stand at a sink facing `yaw` and scrub hands: the baked `wash` clip (loops).
func start_washing(yaw: float) -> void:
	_wash_yaw = yaw
	Pose.ensure_loop(_anim, "wash")
	_anim.play("wash")
	state = State.WASH


func _walk(delta: float) -> void:
	if talking: # Bob is talking to them: stand still and keep the walk target for afterwards
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	_repath -= delta
	if _repath <= 0.0:
		_agent.target_position = _walk_target
		_repath = 0.25
	var flat := Vector3(_walk_target.x - global_position.x, 0.0, _walk_target.z - global_position.z)
	if flat.length() < 0.12:
		velocity = Vector3.ZERO
		state = State.IDLE
		reached.emit()
		return
	var next := _agent.get_next_path_position()
	var dir := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	velocity = dir * walk_speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


func _wash(delta: float) -> void:
	if not talking: # while talking they keep facing Bob
		_model.rotation.y = lerp_angle(_model.rotation.y, _wash_yaw, turn_speed * delta)



func start_kicking(bob: Node3D, ring_angle: float) -> void:
	_resume_walk = false
	_model.rotation.x = 0.0 # a fallen walker gets up to join the kick
	_target = bob
	_ring_angle = ring_angle
	state = State.CHASE
	_counted = false
	_repath = 0.0


## Put this Jijio in the queue at `spot`: it stays there, steps aside when Bob walks toward it, and returns.
func queue_at(spot: Vector3) -> void:
	home = spot
	state = State.QUEUED


func _physics_process(delta: float) -> void:
	_slip_immune = maxf(_slip_immune - delta, 0.0)
	if fidget_clip != "" and (state != State.QUEUED or floating):
		fidget_clip = "" # a scene took them over: it sets their facing, keep it
		_fidget_t = -1.0
	if water != null and state != State.FIGHT and state != State.DANCE:
		var deep: bool = water.depth >= water.SWIM_DEPTH
		if deep and not floating:
			_start_float()
		elif floating and not deep:
			_end_float()
		if floating:
			_float(delta)
			_keep_out_of_walls()
			return
	match state:
		State.SLIP:
			_slip(delta)
		State.QUEUED:
			_queued(delta)
		State.WALK:
			_walk(delta)
		State.WASH:
			_wash(delta)
		State.CHASE:
			_chase(delta)
		State.KICK:
			_kick(delta)
	if state == State.KICK or state == State.SLIP:
		Pose.stop_locomotion(_anim) # those poses still drive the skeleton directly, out of scope for now
	elif state == State.SIT or state == State.WASH or state == State.FIGHT or state == State.DANCE:
		pass # sit()/start_washing() already started the looping clip; leave the AnimationPlayer alone
	elif talking:
		Pose.talk(_anim) # Stage 6b E: in a talk with Bob (standing still, see _queued/_walk)
	elif fidget_clip != "":
		pass # _fidget() plays it
	else:
		Pose.locomotion(_anim, Vector3(velocity.x, 0.0, velocity.z).length(), ANIM_WALK_RUN_MID)
	_keep_out_of_walls()


func _characters() -> Array[RID]:
	var f := Engine.get_physics_frames()
	if f != _char_rids_frame:
		_char_rids_frame = f
		_char_rids.clear()
		for n in get_tree().get_nodes_in_group("jijio") + get_tree().get_nodes_in_group("player"):
			if n is CollisionObject3D:
				_char_rids.append(n.get_rid())
	return _char_rids


## Push the body out of the level wherever the head or chest overlaps it (see CLEAR_BONES). Horizontal only.
func _keep_out_of_walls() -> void:
	if state == State.FIGHT or state == State.SIT or not is_visible_in_tree(): # a floating occupant stays in its stall (FLOAT_BACK_SHIFT)
		return
	if _skeleton == null:
		var found := _model.find_children("*", "Skeleton3D", true, false)
		if found.is_empty():
			return
		_skeleton = found[0]
		for b: String in CLEAR_BONES:
			_clear_ids.append(_skeleton.find_bone(b))
		var sphere := SphereShape3D.new()
		sphere.radius = CLEAR_RADIUS
		_clear_q.shape = sphere
		_clear_q.collision_mask = 1
	var space := get_world_3d().direct_space_state
	_clear_q.exclude = _characters()
	for id in _clear_ids:
		var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(id).origin
		for attempt in 3:
			_clear_q.transform = Transform3D(Basis(), at)
			var pts := space.collide_shape(_clear_q, 8)
			var push := Vector3.ZERO
			for i in range(0, pts.size(), 2):
				var d: Vector3 = pts[i + 1] - pts[i] # from the point of the sphere deepest in the wall to the wall's surface
				d.y = 0.0
				if d.length() > push.length():
					push = d
			if push.length() < 0.001:
				break
			push += push.normalized() * 0.06 # clear of a door leaf that keeps swinging (its tip moves about 0.045 m a frame)
			global_position += push
			at += push


func _start_float() -> void:
	floating = true
	_float_was_sitting = state == State.SIT
	_float_seat = global_position
	if state == State.WASH:
		stop_washing()
	_resume_walk = false
	_model.rotation.x = 0.0
	_float_anchor = Vector3(global_position.x, 0.0, global_position.z)
	_float_goal = _float_anchor
	_float_phase = randf() * TAU
	_float_layer = collision_layer
	collision_layer = 0 # Bob swims through; the push below moves them aside
	var clip := "swim_panic"
	if _float_was_sitting:
		_occupants_floated += 1
		clip = "float" if _occupants_floated % FLOAT_ON_BACK_EVERY == 0 else "tread_water"
		if clip == "float": # lying back, the head reaches 0.39 m behind the seat, into the stall's back wall: float nearer the door
			var yaw := _model.rotation.y
			global_position += Vector3(sin(yaw), 0.0, cos(yaw)) * FLOAT_BACK_SHIFT
	Pose.ensure_loop(_anim, clip)
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.3)


func _float(delta: float) -> void:
	_time += delta
	var target_y: float = water.surface_y() - FLOAT_DEPTH + sin(_time * 2.2 + _float_phase) * 0.04
	var flat := Vector3.ZERO
	if not _float_was_sitting: # a stall occupant just bobs up and down inside the stall
		if Vector2(_float_goal.x - global_position.x, _float_goal.z - global_position.z).length() < 0.1:
			var a := randf() * TAU
			_float_goal = _float_anchor + Vector3(cos(a), 0.0, sin(a)) * randf() * FLOAT_WANDER
		var to_goal := Vector3(_float_goal.x - global_position.x, 0.0, _float_goal.z - global_position.z)
		if to_goal.length() > 0.05:
			flat = to_goal.normalized() * FLOAT_SPEED
		if _bob == null:
			_bob = get_tree().get_first_node_in_group("player")
		if _bob != null:
			var away := Vector3(global_position.x - _bob.global_position.x, 0.0, global_position.z - _bob.global_position.z)
			if away.length() < FLOAT_PUSH_RADIUS:
				var push := away.normalized() if away.length() > 0.01 else Vector3.RIGHT
				flat = push * FLOAT_PUSH_SPEED
				_float_anchor = Vector3(global_position.x, 0.0, global_position.z) + push * 0.4 # they stay pushed aside
				_float_goal = _float_anchor
	velocity = Vector3(flat.x, clampf((target_y - global_position.y) * 5.0, -2.0, 2.0), flat.z)
	if _float_was_sitting:
		global_position.y += velocity.y * delta
	else:
		move_and_slide()
	# the clip's origin on the surface (eased: the water lifts them off their feet or their seat)
	_model.position.y = move_toward(_model.position.y, maxf(water.surface_y() - global_position.y, 0.0), 3.0 * delta)


func _end_float() -> void:
	floating = false
	collision_layer = _float_layer
	_model.rotation.x = 0.0
	_model.position = Vector3.ZERO
	_anim.speed_scale = 1.0
	velocity = Vector3.ZERO
	if _float_was_sitting:
		global_position = _float_seat
		sit()
	else:
		_repath = 0.0 # a walk or a chase carries on from where the water put them down; gravity lands them
		if state == State.WASH or state == State.SIT:
			state = State.IDLE
	landed.emit()


func _queued(delta: float) -> void:
	if talking:
		if fidget_clip != "": # the talk code owns the facing now; afterwards it restores the queue facing, not the fidget's turn
			set_meta("yaw_before_talk", _fidget_rest_yaw)
			fidget_clip = ""
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _bob == null:
		_bob = get_tree().get_first_node_in_group("player")
		if _bob == null:
			return
	var target := home
	var v := Vector3(_bob.velocity.x, 0.0, _bob.velocity.z)
	if v.length() > 0.5:
		_heading = v.normalized()
		_hold = 1.0
	else:
		_hold -= delta
	if _hold > 0.0 and _heading != Vector3.ZERO:
		# Where the spot is relative to Bob's walking line: `ahead` along it, `perp` across it.
		var d := home - _bob.global_position
		d.y = 0.0
		var lateral := Vector3(-_heading.z, 0.0, _heading.x)
		var ahead := d.dot(_heading)
		var perp := d.dot(lateral)
		if ahead > -0.3 and ahead < make_way_reach:
			if absf(perp) > 0.05:
				_side = signf(perp)
			var need := make_way_clearance - absf(perp)
			if need > 0.0:
				target = home + lateral * _side * need
	var to := target - global_position
	to.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	if to.length() > 0.03:
		var step := to.normalized() * minf(shuffle_speed, to.length() / delta)
		velocity.x = step.x
		velocity.z = step.z
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	_fidget(delta, Vector2(velocity.x, velocity.z).length() > 0.05 or _hold > 0.0)


## Stage 6c E (see FIDGET_MIN). `moving`: shuffling or making way for Bob = back to locomotion at once.
func _fidget(delta: float, moving: bool) -> void:
	if moving:
		stop_fidget()
		_fidget_t = randf_range(0.5, 1.5) # soon after it settles again
		return
	if _fidget_t < 0.0:
		_fidget_t = randf_range(0.0, FIDGET_MAX) # the first switch at a random time: the line never moves in sync
	_fidget_t -= delta
	if _fidget_t > 0.0:
		return
	_fidget_t = randf_range(FIDGET_MIN, FIDGET_MAX)
	var neighbour := _queue_neighbour()
	var r := randf()
	var clip := "twerk"
	if r < 0.5 and neighbour != null:
		clip = "talk"
	elif r < 0.8: # no neighbour to talk to: squirm instead
		clip = "squirm"
	if not _anim.has_animation(clip):
		return
	if fidget_clip == "":
		_fidget_rest_yaw = _model.rotation.y
	_model.rotation.y = Pose.talk_yaw(global_position, neighbour.global_position) if clip == "talk" else _fidget_rest_yaw
	fidget_clip = clip
	Pose.ensure_loop(_anim, clip)
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.25)


## The nearest other Jijio standing in the queue within FIDGET_NEIGHBOUR, or null.
func _queue_neighbour() -> Node3D:
	var best: Node3D = null
	var best_d := FIDGET_NEIGHBOUR
	for n in get_tree().get_nodes_in_group("jijio"):
		if n == self or not (n is Node3D) or n.get("state") != State.QUEUED:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## Back to the normal clips (and the queue facing) right away.
func stop_fidget() -> void:
	if fidget_clip == "":
		return
	fidget_clip = ""
	_model.rotation.y = _fidget_rest_yaw


## Bob (at `bob_pos`, walking along `dir`) presses into this Jijio: it is pushed sideways off his line and a little ahead of him,
## sliding along walls (its mask is the world only), so he is never stuck and never walks through it (Stage 6c A, player.gd
## `_push_walkers`). Two side by side in a 1.6 m corridor cannot go sideways: they are pushed ahead until the corridor opens up.
func shove(bob_pos: Vector3, dir: Vector3, delta: float) -> void:
	var f := Engine.get_physics_frames()
	if f == _shove_frame or state == State.SIT or state == State.FIGHT or state == State.DANCE:
		return
	_shove_frame = f
	var lateral := Vector3(-dir.z, 0.0, dir.x)
	var perp := (global_position - bob_pos).dot(lateral)
	if absf(perp) > 0.03:
		_shove_side = signf(perp)
	var step := (lateral * _shove_side * SHOVE_SIDE_SPEED + dir * SHOVE_AHEAD_SPEED) * delta
	var hit := move_and_collide(step)
	if hit != null:
		move_and_collide(hit.get_remainder().slide(hit.get_normal()))


## Ring slot around Bob, snapped to the nearest walkable spot (Bob may be against a wall).
func _slot() -> Vector3:
	var slot := _target.global_position + Vector3(sin(_ring_angle), 0.0, cos(_ring_angle)) * ring_radius
	return NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), slot)


func _chase(delta: float) -> void:
	var slot := _slot()
	_repath -= delta
	if _repath <= 0.0:
		_agent.target_position = slot
		_repath = 0.25
	var flat := Vector3(slot.x - global_position.x, 0.0, slot.z - global_position.z)
	var to_bob := global_position.distance_to(_target.global_position)
	# In a narrow corridor the front of the crowd blocks the rest, so "reached Bob" counts from a distance.
	if not _counted and to_bob < count_radius:
		_counted = true
		arrived.emit()
	# Kick from the slot, or from wherever the crowd has filled the slot.
	if flat.length() < 0.2 or to_bob < ring_radius * 1.25:
		velocity = Vector3.ZERO
		state = State.KICK
		return
	var next := _agent.get_next_path_position()
	var dir := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	velocity = dir * speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


func _kick(delta: float) -> void:
	_time += delta
	var to_bob := Vector3(_target.global_position.x - global_position.x, 0.0, _target.global_position.z - global_position.z)
	var yaw := atan2(to_bob.x, to_bob.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, turn_speed * delta)
	# Placeholder kick: lean into Bob and thrust toward him, out of step with the others.
	var k := maxf(0.0, sin(_time * 7.0 + _ring_angle * 3.0))
	if k > 0.9 and not _kick_high:
		_kick_high = true
		var hit_at := _target.global_position + Vector3(0.0, 0.6, 0.0)
		Sfx.play_at(self, "kick", hit_at)
		if not _target.has_meta("hurt_played"): # Bob cries out at the first kick only
			_target.set_meta("hurt_played", true)
			Sfx.play_at(self, "bob_ouch", hit_at) # Stage 6: his own voice
	elif k < 0.5:
		_kick_high = false
	_kick_room_check -= delta
	if _kick_room_check <= 0.0:
		_kick_room_check = 0.25
		var room := _room_ahead(Vector3(sin(yaw), 0.0, cos(yaw)), KICK_REACH + 0.3)
		_kick_scale = clampf((room - CLEAR_RADIUS - 0.05) / KICK_REACH, 0.0, 1.0)
	k *= _kick_scale
	_model.rotation.x = 0.35 * k
	_model.position = Vector3(sin(yaw), 0.0, cos(yaw)) * 0.25 * k


## Free distance from the body along `dir` at chest and head height (level geometry only, characters ignored), at most `max_len`.
func _room_ahead(dir: Vector3, max_len: float) -> float:
	var space := get_world_3d().direct_space_state
	var room := max_len
	for h: float in [0.75, 0.9]:
		var from := global_position + Vector3.UP * h
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_len, 1, _characters())
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			room = minf(room, from.distance_to(hit.position))
	return room
