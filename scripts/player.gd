extends CharacterBody3D
## Bob: third-person walker. `idle`/`walk`/`run` are real baked clips (FACTORY_TODO batch 1, wired 2026-09-23); the toilet
## sequence's own clips (pants_down/sit_down/sit/wipe/tissue_grab/press_flush/stand_up) are driven directly by
## `toilet_session.gd` while `posing` is true (see Pose.locomotion/stop_locomotion). Attacks are still code-driven.

@export var walk_speed := 3.0
@export var sprint_speed := 5.0
const ANIM_WALK_RUN_MID := 4.0 ## m/s: above this the run clip plays instead of walk (between walk_speed 3.0 and sprint_speed 5.0)
@export var mouse_sensitivity := 0.003
@export var turn_speed := 12.0

enum View { THIRD, FIRST_HIDDEN, FIRST_BODY } ## FIRST_BODY keeps Bob's body visible (his face parts are hidden)

const Pose := preload("res://scripts/pose.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Footsteps := preload("res://scripts/footsteps.gd")

signal prompt_changed(text: String)
signal carrying_changed(text: String)

@export var reach := 1.3

const FIRST_PERSON_DISTANCE := 0.4 ## camera closer than this to his eyes counts as first person
const FIRST_BODY_HIDE_DISTANCE := 0.12 ## body view: the head hides only this close (see _set_camera_distance)
const CAMERA_HEIGHT := 1.1
const CARRY_POSITION := Vector3(0.0, 0.7, 0.4) ## in front of Bob, in model space (his front is +Z)

var frozen := false
var busy := false ## true during the grab / hand-over, when Bob can't move
var posing := false ## true while another script (the toilet sequence) is driving the AnimationPlayer itself: leave it alone
var posing_focus: Node = null ## while `posing`, the ONLY interactable that can be focused (toilet_session sets it directly for
## its own tissue/flush prompts; without this, any ambient interactable Bob happens to be near, like the stall door behind
## him, would win the normal nearest-interactable scan and could fire from a stray E press mid-animation)
var carrying: Node3D = null
var sprint_blocked := false ## the mop is out: walking pace only
var floor_wet_fn := Callable() ## Level 2: takes a world position, true when the floor there is wet
var slip_left := 0.0 ## seconds of slide still to go (Bob cannot steer)
var hiding := false ## Level 3: standing on a seat or a lap in a closed stall: stays put, but E still works (climb down)
var clenching := false ## Level 3: holding in a fart (hold F): Bob cannot move
var shoulder := 0.0 ## Level 4 water fight: the camera pivot slides this far right (over the shoulder), less if a wall is nearer
var jump_speed := 0.0 ## Level 4 WATER WAR: Space jumps with this upward speed (0 = no jumping, every other level)
var jumps := 0 ## tests count them
var auto_move := Vector3.ZERO ## a cutscene walks Bob: a world direction (length 1 = walking pace); works while `frozen` blocks the keys
## Stage 6b E (owner): in a talk the camera pans TALK_PAN s into Bob's first person facing the Jijio, Bob plays `talk`; back out after.
const TALK_PAN := 0.5
const TALK_FACE_HEIGHT := 1.1 ## m: where the camera looks when the partner has no head bone
var talking := false
var _talk_saved := {} ## the camera and shoulder before the talk: restored after it
var _talk_tween: Tween

## Stage 6c C (owner, 2026-09-28): while a talk box is on screen the mouse may not swing the view off the partner's face; only this
## much free look is left, so the view is alive but the Jijio stays in it. `_talk_look` = the aim to stay near (INF: no box open).
const TALK_LOOK_LIMIT := deg_to_rad(15.0)
var _talk_look := Vector2.INF
var _dialogue: Node = null ## the level's Dialogue node (null outside a level scene: then nothing is locked)
## Level 2 "The flood" (flood_water.gd): Bob wades in shallow water and swims at the surface in deep water. He cannot sink or drown;
## only `diving` (an automatic dive to a tap, the toilet or the plug) takes him and the camera under.
var water: Node = null
var swimming := false
var diving := false
const WADE_START := 0.15 ## m of water: from here Bob slows down...
const WADE_SLOWEST := 0.55 ## ... to this fraction of his speed at SWIM_DEPTH
const SWIM_DEPTH := 0.75 ## deeper than this he swims
const FLOAT_DEPTH := 0.62 ## his feet hang this far under the surface: the water line is at his shoulders (he is 1.3 m tall; 0.85 hid his face)
const SWIM_SPEED := 2.2
const SWIM_SPRINT := 3.0
## The factory swim clips (bob_godot_notes.md "Swim clips") have their origin ON THE WATER SURFACE, not the floor: while Bob floats his
## model is lifted from the body (whose feet hang FLOAT_DEPTH under the surface) up to the surface. `swim` is in place, authored for about
## 0.7 m/s; Bob keeps 2.2 / 3.0 m/s (owner A1, 2026-09-27), so the stroke plays faster, at most SWIM_PLAY_MAX.
const SWIM_AUTHORED := 0.7
const SWIM_PLAY_MAX := 2.0
## Stage 6: the stroke splash plays when the `swim` clip reaches this phase (the hands' high point: tests/probe_swim_stroke.gd, both hands
## together at 0.19 and 0.83 of 1.2 s; they never break the surface). footsteps.gd reads swim_phase().
const SWIM_SPLASH_PHASE := 0.83
const DIVE_LIFT := 1.2 ## m: at the bottom of a dive the model origin sits this far above the body (swim_under: hands 0.95-1.11 m, duck_dive 1.21 m under the origin, probe_swim_clips.gd)
const LIFT_SPEED := 3.0 ## m/s the model eases to its lift
const CAMERA_ABOVE_WATER := 0.15 ## the camera stays at least this far over the surface (not while diving)
var _lift := 0.0 ## the model's height above the body origin (0 on land)
var _surfacing := false

const SLIP_SECONDS := 1.0
const SLIP_IMMUNE_SECONDS := 1.5 ## after a slip Bob can run through the puddle without slipping again
const SLIP_MIN_SPEED := 3.5 ## only running (sprint) slips; walking is safe
var walker_push_time := 0.0 ## seconds Bob has spent pushing walkers aside (`_push_walkers`; tests read it)

var _slip_dir := Vector3.ZERO
var _slip_speed := 0.0
var _slip_immune := 0.0

var _focus: Node = null
var _view := 0 ## View.THIRD
var _view_tween: Tween
var _fp_offset := 0.0 ## how far in front of the head the camera sits in FIRST_BODY
## In FIRST_BODY the eyes ride on the head bone: a clip that bends him forward (pants_down) moved the head 0.4-0.6 m
## away from a fixed camera, which then looked at the back of his hidden head (a headless Bob for about 1.5 s).
var _head_follow := 0.0 ## 0..1, tweened with the view
var _head_anchor := Vector3.ZERO ## the head bone's position (Bob's local space) when FIRST_BODY started
var _prompt_text := ""
var _yaw := 0.0
var _pitch := -0.15

@onready var _pivot: Node3D = $CameraPivot
@onready var _model: Node3D = $Model
@onready var _anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false)


func _ready() -> void:
	add_to_group("player")
	process_priority = 10 # after his AnimationPlayer: the first-person camera rides the head bone of THIS frame's pose
	collision_mask |= 2 # layer 2 = walking Jijios (they pass through each other but Bob cannot walk through them)
	add_child(Footsteps.new())
	_register_actions()
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Point the camera and Bob's body along a yaw (radians; 0 = looking toward -Z).
func set_facing(yaw: float) -> void:
	_kill_talk_pan()
	_yaw = yaw
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_model.rotation.y = yaw + PI # Bob's front is +Z in the model


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by(event.relative)
	elif event.is_action_pressed("interact") and _focus and not frozen and (not busy or posing):
		_focus.interact(self)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Turn the view by a mouse movement (pixels). While a talk box is open the view may stray at most TALK_LOOK_LIMIT from the aim the
## talk pan set (Stage 6c C): the Jijio's face cannot be lost. Called by _unhandled_input; the tests call it directly, because a
## headless run has no captured mouse.
func look_by(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -1.2, 0.5)
	if _talk_look != Vector2.INF:
		_yaw = _talk_look.x + clampf(wrapf(_yaw - _talk_look.x, -PI, PI), -TALK_LOOK_LIMIT, TALK_LOOK_LIMIT)
		_pitch = clampf(_pitch, _talk_look.y - TALK_LOOK_LIMIT, _talk_look.y + TALK_LOOK_LIMIT)
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


## The aim the free look is measured from: none while no talk box is open, and it follows the camera while the talk pan is still
## moving (the box opens before the pan has reached the face).
func _update_talk_look() -> void:
	if _dialogue == null or not is_instance_valid(_dialogue):
		_dialogue = get_parent().get_node_or_null("Dialogue") if get_parent() != null else null
	var open: bool = _dialogue != null and _dialogue.has_method("is_open") and _dialogue.is_open()
	if not open:
		_talk_look = Vector2.INF
	elif _talk_look == Vector2.INF or (_talk_tween != null and _talk_tween.is_running()):
		_talk_look = Vector2(_yaw, _pitch)


func _process(_delta: float) -> void:
	_update_talk_look()
	_pivot.position = Vector3(0.0, CAMERA_HEIGHT, 0.0) + Basis(Vector3.UP, _yaw) * Vector3(_shoulder_room(), 0.0, -_fp_offset)
	if _head_follow > 0.0:
		_pivot.position += (_head_local() - _head_anchor) * _head_follow
	if water:
		# In the flood the camera never dips under the surface: looking up is limited so the arm cannot swing it below.
		var most := INF
		if not diving:
			var above: float = global_position.y + _pivot.position.y - water.surface_y()
			var arm: SpringArm3D = $CameraPivot/SpringArm3D
			most = asin(clampf((above - CAMERA_ABOVE_WATER) / maxf(arm.spring_length, 0.01), -1.0, 1.0))
		_pivot.rotation.x = minf(_pitch, most)
	var best: Node = null
	if posing:
		best = posing_focus
	elif not frozen and not busy:
		best = _nearest_interactable()
	_focus = best
	var text: String = _focus.prompt() if _focus else ""
	if text != _prompt_text:
		_prompt_text = text
		prompt_changed.emit(text)


## How far right the camera pivot can slide: `shoulder`, or less when a wall is nearer (the spring arm only checks walls
## behind the pivot, so a pivot slid into a wall put the camera inside it: a dark wedge on screen, 2026-09-24).
func _shoulder_room() -> float:
	if shoulder <= 0.0:
		return 0.0
	var head := global_position + Vector3.UP * CAMERA_HEIGHT
	var side := Basis(Vector3.UP, _yaw) * Vector3.RIGHT
	var q := PhysicsRayQueryParameters3D.create(head, head + side * (shoulder + 0.15), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return shoulder
	return maxf(head.distance_to(hit["position"]) - 0.15, 0.0)


## Closest interactable within reach that Bob is roughly looking at.
func _nearest_interactable() -> Node:
	var forward := -_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.prompt() == "":
			continue
		var to: Vector3 = n.interaction_point() - global_position
		to.y = 0.0
		var d := to.length()
		var r: float = n.talk_reach if "talk_reach" in n and n.talk_reach > 0.0 else reach # the queue Jijios: 1.5 m (Stage 6c D)
		if d >= r or not (d < 0.4 or forward.dot(to / d) > 0.3):
			continue
		# `priority` (optional, in metres) makes a nearby interactable win over closer, less important ones
		# (the toilet over the stall door Bob is standing in).
		var score: float = d - (n.priority if "priority" in n else 0.0)
		if score < best_d:
			best = n
			best_d = score
	return best


## Switch between third person and first person. In FIRST_BODY the camera sits at Bob's eyes and looks
## down at his own body, with his head collapsed so the camera isn't inside it.
## The head (and shirt / body) is hidden only once the camera is close to his eyes and shown again as soon
## as it pulls back out, so he is never seen headless from a third-person camera.
func set_view(view: int, seconds := 0.3) -> void:
	_view = view
	var arm: SpringArm3D = $CameraPivot/SpringArm3D
	var first := view != View.THIRD
	if _view_tween:
		_view_tween.kill()
	_view_tween = create_tween().set_parallel(true)
	_view_tween.tween_method(_set_camera_distance, arm.spring_length, 2.2 if not first else 0.0, seconds)
	# Looking at his own body: put the camera just in front of the face (horizontally, whatever the
	# pitch), or it sits inside the head.
	_view_tween.tween_property(self, "_fp_offset", 0.22 if view == View.FIRST_BODY else 0.0, seconds)
	if view == View.FIRST_BODY and _head_follow == 0.0:
		_head_anchor = _head_local()
	_view_tween.tween_property(self, "_head_follow", 1.0 if view == View.FIRST_BODY else 0.0, seconds)
	$CameraPivot/SpringArm3D/Camera3D.near = 0.02 if view == View.FIRST_BODY else 0.05
	await _view_tween.finished


## The head bone's position in Bob's own (unrotated body) space.
func _head_local() -> Vector3:
	var sk := Pose.skeleton_of(_model)
	var i := sk.find_bone("DEF-spine.006") if sk else -1
	if i < 0:
		return _head_anchor
	return to_local(sk.global_transform * sk.get_bone_global_pose(i).origin)


func _set_camera_distance(length: float) -> void:
	$CameraPivot/SpringArm3D.spring_length = length
	# Body view hides the head only once the camera is really at the eyes: between 0.15 and 0.4 m the camera is still
	# behind him, looking at the back of a hidden head (the owner's "headless for a second").
	_apply_view_visibility(_view, length < (FIRST_BODY_HIDE_DISTANCE if _view == View.FIRST_BODY else FIRST_PERSON_DISTANCE))


func _apply_view_visibility(view: int, close_to_eyes: bool) -> void:
	_model.visible = not (view == View.FIRST_HIDDEN and close_to_eyes)
	var body_view := view == View.FIRST_BODY and close_to_eyes
	Pose.hide_head(Pose.skeleton_of(_model), body_view)
	# The shirt hem hides the shorts from eye level, so it is hidden while he looks at them.
	var shirt := _model.find_child("Bob_Shirt", true, false) as Node3D
	if shirt:
		shirt.visible = not body_view


## Turn only Bob's body (not the camera) toward a point, e.g. to face someone he is talking to.
func turn_toward(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_model.rotation.y = atan2(d.x, d.z)


## Turn Bob's body and the camera to face `dir` (a world direction on the floor plane).
func face_direction(dir: Vector3) -> void:
	set_facing(atan2(-dir.x, -dir.z))


## Move only the camera (yaw around the world, pitch up/down), leaving Bob's body as it is.
func set_camera(yaw: float, pitch: float) -> void:
	_kill_talk_pan()
	_yaw = yaw
	_pitch = pitch
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


## A talk starts (dialogue.gd begin()): Bob turns to `partner` (TALK_TURN right of it, the clip turns his head back), plays `talk`, and the
## camera pans into his first person aimed at the partner's face.
func start_talk_view(partner: Node3D) -> void:
	talking = true
	_model.rotation.y = Pose.talk_yaw(global_position, partner.global_position)
	if not hiding:
		Pose.talk(_anim)
	if _talk_saved.is_empty(): # a talk right after another (the ghost's lines) keeps the first camera to go back to
		_talk_saved = {"yaw": _yaw, "pitch": _pitch, "shoulder": shoulder}
	shoulder = 0.0 # first person: the eyes, not over the shoulder
	var face := partner.global_position + Vector3.UP * TALK_FACE_HEIGHT
	if partner.find_children("*", "Skeleton3D", true, false).size() > 0:
		var sk := Pose.skeleton_of(partner)
		var i := sk.find_bone("DEF-spine.006")
		if i >= 0:
			face = sk.global_transform * sk.get_bone_global_pose(i).origin
	var eye := global_position + Vector3.UP * CAMERA_HEIGHT
	var to := face - eye
	var yaw := atan2(-to.x, -to.z)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 0.5)
	_pan_camera(yaw, pitch)
	set_view(View.FIRST_HIDDEN, TALK_PAN)


## The talk ended (dialogue.gd end()): the camera pans back out to where it was; the next physics frame plays `idle` again.
func end_talk_view() -> void:
	if not talking:
		return
	talking = false
	set_view(View.THIRD, TALK_PAN)
	if not _talk_saved.is_empty():
		shoulder = _talk_saved["shoulder"]
		_pan_camera(_talk_saved["yaw"], _talk_saved["pitch"])
		_talk_saved = {}


func _pan_camera(yaw: float, pitch: float) -> void:
	_kill_talk_pan()
	var yaw0 := _yaw
	var pitch0 := _pitch
	var dyaw := wrapf(yaw - yaw0, -PI, PI) # the short way round
	_talk_tween = create_tween()
	_talk_tween.tween_method(func(t: float) -> void:
		_yaw = yaw0 + dyaw * t
		_pitch = lerpf(pitch0, pitch, t)
		_pivot.rotation = Vector3(_pitch, _yaw, 0.0), 0.0, 1.0, TALK_PAN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Another script takes the camera (a fight, WATER WAR, a cutscene): the talk pan stops where it is.
func _kill_talk_pan() -> void:
	if _talk_tween and _talk_tween.is_valid():
		_talk_tween.kill()
	_talk_tween = null


func get_camera_pitch() -> float:
	return _pitch


func get_camera_yaw() -> float:
	return _yaw


func set_body_collision(enabled: bool) -> void:
	$CollisionShape3D.set_deferred("disabled", not enabled)


func model() -> Node3D:
	return _model


func anim() -> AnimationPlayer:
	return _anim


## Grab a prop: the camera goes first person while the prop is lifted, then back to third person carrying it.
func grab(prop: Node3D) -> void:
	busy = true
	Sfx.play_ui(self, "pickup")
	var arm: SpringArm3D = $CameraPivot/SpringArm3D
	var cam: Camera3D = $CameraPivot/SpringArm3D/Camera3D
	var to_first := create_tween()
	to_first.tween_property(arm, "spring_length", 0.0, 0.3)
	await to_first.finished
	_model.visible = false
	prop.reparent(cam, true)
	var lift := create_tween().set_parallel(true)
	lift.tween_property(prop, "position", Vector3(0.22, -0.2, -0.55), 0.4)
	lift.tween_property(prop, "rotation", Vector3(0.3, 0.4, 0.0), 0.4)
	await lift.finished
	await get_tree().create_timer(0.4).timeout
	_model.visible = true
	prop.reparent(_model, true)
	var to_third := create_tween().set_parallel(true)
	to_third.tween_property(arm, "spring_length", 2.2, 0.3)
	to_third.tween_property(prop, "position", CARRY_POSITION, 0.3)
	to_third.tween_property(prop, "rotation", Vector3.ZERO, 0.3)
	await to_third.finished
	carrying = prop
	carrying_changed.emit("Carrying: %s" % prop.get_meta("carry_name", "tissue box"))
	busy = false


## Hand over what Bob is carrying. Returns the item, or null.
func take_carried() -> Node3D:
	var item := carrying
	carrying = null
	carrying_changed.emit("")
	return item


## Bob slides on: a fall backwards (stand-in for the factory's slip animation), he cannot steer for SLIP_SECONDS.
func start_slip(dir: Vector3) -> void:
	dir.y = 0.0
	if slip_left > 0.0 or dir.length() < 0.01:
		return
	_slip_dir = dir.normalized()
	_slip_speed = 4.5
	slip_left = SLIP_SECONDS
	_slip_immune = SLIP_SECONDS + SLIP_IMMUNE_SECONDS
	Sfx.play_at(self, "slip", global_position + Vector3(0.0, 0.3, 0.0))


func _slide(delta: float) -> void:
	slip_left = maxf(slip_left - delta, 0.0)
	var t := 1.0 - slip_left / SLIP_SECONDS
	var s := _slip_speed * (1.0 - 0.7 * t)
	velocity.x = _slip_dir.x * s
	velocity.z = _slip_dir.z * s
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	_model.rotation.x = -0.6 * sin(PI * t) # leans back and comes up again


## Stage 6c A (owner, DECIDED): Jijios are solid, Bob never walks through them, and one he walks into is PUSHED aside (npc_jijio.gd
## `shove`) so he is never stuck. Replaces the old safety net that let him pass through walkers after 1.2 s of being blocked
## (tests/test_jijio_solid.gd). Walkers (layer 2) only: the queue makes way by itself (`_queued`).
func _push_walkers(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var pushed := false
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is CollisionObject3D and (other.collision_layer & 2) != 0 and other.has_method("shove"):
			other.shove(global_position, dir.normalized(), delta)
			pushed = true
	if pushed:
		walker_push_time += delta


func _physics_process(delta: float) -> void:
	_slip_immune = maxf(_slip_immune - delta, 0.0)
	if busy or hiding:
		if diving:
			_dive_pose(delta)
		elif talking and not hiding: # hiding on a seat or a lap keeps its own pose
			Pose.talk(_anim) # stopping the AnimationPlayer here left him in the T-pose through every talk (owner, Stage 6b E)
		elif not posing:
			Pose.stop_locomotion(_anim) # grabs and hiding on a seat/lap pose Bob directly; `posing` = the toilet sequence is playing its own clips
		return
	if slip_left > 0.0:
		Pose.stop_locomotion(_anim)
		_slide(delta)
		return
	var dir := Vector3.ZERO
	if not frozen and not busy:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	if auto_move != Vector3.ZERO:
		dir = auto_move
	if clenching:
		dir = Vector3.ZERO
	var sprinting := Input.is_action_pressed("sprint") and not sprint_blocked and not clenching
	var speed := sprint_speed if sprinting else walk_speed
	var depth: float = water.depth_at(global_position) if water else 0.0
	swimming = depth >= SWIM_DEPTH
	if swimming:
		speed = SWIM_SPRINT if Input.is_action_pressed("sprint") and not clenching else SWIM_SPEED
		sprinting = false # no slipping in the water
	elif depth > WADE_START:
		speed *= lerpf(1.0, WADE_SLOWEST, clampf((depth - WADE_START) / (SWIM_DEPTH - WADE_START), 0.0, 1.0))
		sprinting = false
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if water and depth > FLOAT_DEPTH:
		velocity.y = clampf((float_target(dir) - global_position.y) * 6.0, -2.0, 2.0) # floats at the surface
	elif not is_on_floor():
		velocity.y -= 9.8 * delta
	elif jump_speed > 0.0 and not frozen and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
		jumps += 1
	move_and_slide()
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	if swimming:
		_swim_pose(hspeed, delta)
	else:
		Pose.locomotion(_anim, hspeed, ANIM_WALK_RUN_MID)
		_set_lift(0.0, delta)
	_push_walkers(dir, delta)
	# Running onto wet floor (Level 2): down he goes. Walking is safe.
	if sprinting and _slip_immune <= 0.0 and floor_wet_fn.is_valid() and Vector3(velocity.x, 0.0, velocity.z).length() >= SLIP_MIN_SPEED \
			and floor_wet_fn.call(global_position):
		start_slip(Vector3(velocity.x, 0.0, velocity.z))

	if dir.length() > 0.01:
		# Bob's front is +Z in the model, so yaw toward the move direction.
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


## Where Bob's feet hang while he floats: FLOAT_DEPTH under the surface, or lower to duck under a low ceiling just above or ahead of
## him. The waiting room's doorway into the toilet has a 2.1 m lintel; floating in 1.6 m of water his 1.3 m body reached 2.28 m and he
## could not swim through it (tests/test_flood_swim.gd, probe_flood_headroom.gd), so he dips his head under it like a person would.
const HEADROOM_AHEAD := 0.45 ## m: look this far ahead for a low ceiling (more than his 0.25 m radius)
const BODY_HEIGHT := 1.3


func float_target(move_dir := Vector3.ZERO) -> float:
	var target: float = water.surface_y() - FLOAT_DEPTH
	var space := get_world_3d().direct_space_state
	var ahead := Vector3(move_dir.x, 0.0, move_dir.z).normalized() if move_dir.length() > 0.01 else Vector3.ZERO
	# several samples: the lintel is only about 0.1 m thick, one ray 0.45 m ahead stepped right over it while his body already touched it
	for d: float in [0.0, 0.12, 0.24, 0.36, HEADROOM_AHEAD]:
		if d > 0.0 and ahead == Vector3.ZERO:
			break
		var from := global_position + ahead * d + Vector3.UP * 0.4
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * (BODY_HEIGHT + 1.0), 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			target = minf(target, (hit["position"] as Vector3).y - BODY_HEIGHT - 0.03)
	return maxf(target, 0.0)


## A dive (flood_story.gd): the camera comes in close and level, so it really goes under with him (with the normal 2.2 m arm it stayed at
## the surface behind him and the dive did not read, windowed screenshot 2026-09-27).
const DIVE_ARM := 1.1
const DIVE_PITCH := 0.05
var _arm_before := 2.2
var _pitch_before := 0.0


func set_dive_view(on: bool, seconds := 0.35) -> void:
	var arm: SpringArm3D = $CameraPivot/SpringArm3D
	var tw := create_tween().set_parallel(true)
	if on:
		_arm_before = arm.spring_length
		_pitch_before = _pitch
		tw.tween_property(arm, "spring_length", DIVE_ARM, seconds)
		tw.tween_property(self, "_pitch", DIVE_PITCH, seconds)
	else:
		tw.tween_property(arm, "spring_length", _arm_before, seconds)
		tw.tween_property(self, "_pitch", _pitch_before, seconds)


## Deep water: `swim` while moving, `tread_water` while still, the model's origin on the surface (the clips' face stays out by itself).
## Ducking under the lintel lowers only the body (its 1.3 m capsule); the swimming model reaches 0.34 m over the surface, under 2.1 m.
func _swim_pose(hspeed: float, delta: float) -> void:
	var clip := "swim" if hspeed > 0.3 else "tread_water"
	Pose.ensure_loop(_anim, clip)
	if _anim.current_animation != clip or not _anim.is_playing():
		_anim.play(clip, 0.25)
	_anim.speed_scale = clampf(hspeed / SWIM_AUTHORED, 1.0, SWIM_PLAY_MAX) if clip == "swim" else 1.0
	_set_lift(water.surface_y() - global_position.y, delta)


## Where the `swim` clip is in its cycle (0..1), or -1 when another clip plays.
func swim_phase() -> float:
	if _anim.current_animation != "swim" or _anim.current_animation_length <= 0.0:
		return -1.0
	return _anim.current_animation_position / _anim.current_animation_length


## A dive (flood_story.gd): `duck_dive` bridges into `swim_under` near the bottom; coming up (dive_surface) cross-fades back to `swim`
## over 0.4 s while the body rises (no `surface` clip yet, FACTORY_TODO R1b).
func _dive_pose(delta: float) -> void:
	if _surfacing:
		if _anim.current_animation != "swim":
			Pose.ensure_loop(_anim, "swim")
			_anim.play("swim", 0.4)
			_anim.speed_scale = 1.0
		_set_lift(water.surface_y() - global_position.y if water else 0.0, delta)
		return
	if not _anim.current_animation in ["duck_dive", "swim_under"]:
		Pose.ensure_loop(_anim, "swim_under")
		_anim.speed_scale = 1.0
		_anim.play("duck_dive", 0.15)
		_anim.queue("swim_under")
	_set_lift(minf(DIVE_LIFT, water.surface_y() - global_position.y) if water else DIVE_LIFT, delta)


## flood_story.gd calls this when a dive turns back up (and `diving` stays true until he is at the surface).
func dive_surface(on: bool) -> void:
	_surfacing = on
	if on:
		_dive_pose(0.0) # the cross-fade starts on this frame, not the next physics tick


func _set_lift(target: float, delta: float) -> void:
	_lift = move_toward(_lift, maxf(target, 0.0), LIFT_SPEED * delta)
	_model.position = Vector3(0.0, _lift, 0.0)


## Actions are registered in code so project.godot stays editor-owned.
## Controls are undecided (see SPEC.md): keyboard + mouse for now.
func _register_actions() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"mop_hold": KEY_Q,
		"clench": KEY_F, # Level 3: hold in a fart
		"jump": KEY_SPACE, # Level 4 WATER WAR only (jump_speed > 0)
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
