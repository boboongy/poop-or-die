extends Node
## Bob using the freed stall: step in front of the toilet, then the baked toilet-sequence clips take over
## (pants_down, sit_down, sit, tissue_grab, wipe, press_flush, stand_up -- FACTORY_TODO batch 2, wired 2026-09-23).
## The timer stops the moment Bob sits down to poop (`sat_down`). Only the shorts pull-up (no baked "pants up"
## clip exists yet) and the flush FX (`toilet_fx.gd`) are still code-driven.
##
## Positioning fact (probed 2026-09-23, tests/probe_toilet_anim.gd): every one of these clips has ZERO root-motion
## tracks, and the hip bone's LOCAL-space Z is identical across all of them at the seams (pants_down stays at local
## z 0.336 = "standing 0.34 m out"; sit_down travels 0.336 -> -0.006 = "seated at the seat spot"; sit/wipe/
## tissue_grab/press_flush all sit at -0.006; stand_up reverses 0.336). So the whole sequence uses ONE FIXED
## model position (`_seat_spot()`, the same anchor `sit` was authored at) from `pants_down` through `stand_up` --
## the "0.34 m in front" the factory notes describe is entirely a bone-space illusion, not a node move.

const Pose := preload("res://scripts/pose.gd")
const SimpleInteractable := preload("res://scripts/simple_interactable.gd")
const Sfx := preload("res://scripts/sfx.gd")
const TissueProps := preload("res://assets/environments/tissue-props/tissue-props.glb")

## The factory tissue props (tissue-props_godot_notes.md): the holder's mount point in Bob's SEATED frame (origin = _seat_spot(), +Z =
## _forward, his right = -X), and the `tissue_grab` frames (30 fps) the game reacts to.
const TISSUE_MOUNT := Vector3(-0.45, 0.75, -0.03)
const TAIL_REST := 0.12 ## m: SM_TissueTail's length at scale 1
const TAIL_LEFT := 0.35 ## the short tail left on the roll after the tear (scale)
const GRAB_FRAME := 22.0
const TEAR_FRAME := 40.0
const SHEET_FRAME := 44.0
const ROLL_SPIN := 14.0 ## rad/s while the paper is pulled (0.055 m radius: about the hand's 0.75 m/s)
const SHEET_ALONG := 0.035 ## m along DEF-hand.R from the wrist

## Player.View values (passed as ints)
const VIEW_THIRD := 0
const VIEW_FIRST_HIDDEN := 1
const VIEW_FIRST_BODY := 2

signal status_changed(text: String)
signal sat_down ## Bob sat down to poop: the timer stops here (wiping and flushing can take as long as needed)
signal finished ## the flush animation is over

@export var poop_seconds := 3.0

var _row := 1
var _k := 1
var _forward := Vector3.BACK ## from the toilet toward the stall door
var _seat := Vector3.ZERO ## seat centre in the world (y = top of the seat)
var _aborted := false
var _use_spot: Node3D
var _tissue: Node3D
var _handle: Node3D
var tissue_holder: Node3D ## SM_TissueHolder with SM_TissueRoll + SM_TissueTail under it
var sheet: Node3D ## SM_TissueSheet: hidden until frame 44, then in Bob's right hand until the wipe is over
var _roll: Node3D
var _tail: Node3D
var _tail_rest := Transform3D()
var _torn := false
var _sheet_attach: BoneAttachment3D

@onready var _player = $"../Player"
@onready var _fx = $"../ToiletFx"
@onready var _toilet: Node3D = $"../NavRegion/Toilet"


## Make stall `index` (0-9 row 1, 10-19 row 2) usable by Bob.
func setup(index: int) -> void:
	_row = 1 if index < 10 else 2
	_k = index % 10 + 1
	_forward = Vector3.BACK if _row == 1 else Vector3.FORWARD
	var lid := _toilet.find_child("SM_Toilet_R%d_%02d_Lid" % [_row, _k], true, false) as MeshInstance3D
	var box := lid.global_transform * lid.get_aabb()
	_seat = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	_fx.prepare(_row, _k)

	_use_spot = SimpleInteractable.new()
	_use_spot.prompt_text = "E  use toilet"
	_use_spot.point = _stand_spot()
	_use_spot.used.connect(func(_p: Node3D) -> void: _use())
	add_child(_use_spot)

	_tissue = SimpleInteractable.new()
	_tissue.prompt_text = "E  grab tissue"
	_tissue.enabled = false
	_tissue.point = _tissue_position()
	add_child(_tissue)
	_add_tissue_props()

	_handle = SimpleInteractable.new()
	_handle.prompt_text = "E  flush"
	_handle.enabled = false
	_handle.point = _handle_position()
	add_child(_handle)
	_add_handle_mesh()


## If the timer runs out mid-way, stop the sequence and give Bob back.
func abort() -> void:
	_aborted = true
	if _use_spot:
		_use_spot.enabled = false
	if _tissue:
		_tissue.enabled = false
	if _handle:
		_handle.enabled = false
	_drop_sheet(false)
	_player.busy = false
	_player.posing = false
	_player.posing_focus = null
	_player.set_body_collision(true)
	_player.set_view(VIEW_THIRD, 0.2)
	status_changed.emit("")


func _stand_spot() -> Vector3:
	return Vector3(_seat.x, 0.0, _seat.z) + _forward * 0.72


## The one anchor `pants_down` through `stand_up` all use (see the file header note).
func _seat_spot() -> Vector3:
	return Vector3(_seat.x, 0.0, _seat.z) + _forward * 0.15 # a little forward on the seat, like the Jijios


func _handle_position() -> Vector3:
	# On the front face of the tank (the tank is at the back of the seat), left of centre.
	return Vector3(_seat.x - 0.15, 0.8, _seat.z - _forward.z * 0.10)


## Bob's seated frame: facing _forward (the model's +Z).
func _seat_basis() -> Basis:
	return Basis(Vector3.UP, atan2(_forward.x, _forward.z))


## The tissue holder's mount point on the stall wall at Bob's right (tissue-props notes; the E prompt's point too).
func _tissue_position() -> Vector3:
	return _seat_spot() + _seat_basis() * TISSUE_MOUNT


func _add_handle_mesh() -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.03, 0.03)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.8)
	mat.metallic = 1.0
	mat.roughness = 0.3
	mesh.material_override = mat
	add_child(mesh)
	mesh.global_position = _handle_position()


## The holder (roll + tail under it) on the wall, its front (+Z) into the stall; the sheet kept hidden until the grab folds it.
func _add_tissue_props() -> void:
	var props: Node3D = TissueProps.instantiate()
	tissue_holder = props.find_child("SM_TissueHolder", true, false)
	sheet = props.find_child("SM_TissueSheet", true, false)
	for n: Node3D in [tissue_holder, sheet]:
		n.get_parent().remove_child(n)
		n.owner = null
		add_child(n)
	props.free()
	tissue_holder.global_transform = Transform3D(_seat_basis() * Basis(Vector3.UP, PI / 2.0), _tissue_position())
	_roll = tissue_holder.find_child("SM_TissueRoll", true, false)
	_tail = tissue_holder.find_child("SM_TissueTail", true, false)
	_tail_rest = _tail.transform
	sheet.visible = false


## Each frame of `tissue_grab`: frames 22-38 the roll spins and the tail stretches from its top to the hand, frame 40 it tears (a short
## tail stays), from frame 44 the folded sheet is in DEF-hand.R.
func _drive_tissue(ap: AnimationPlayer) -> void:
	var f := ap.current_animation_position * 30.0
	var sk := Pose.skeleton_of(_player.model())
	if f >= GRAB_FRAME and f < TEAR_FRAME:
		_roll.rotate_object_local(Vector3.RIGHT, ROLL_SPIN * get_process_delta_time())
		var top: Vector3 = tissue_holder.global_transform * _tail_rest.origin
		var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("DEF-hand.R")).origin
		var along := hand - top
		if along.length() > 0.01:
			var y := -along.normalized() # the tail hangs along its local -Y
			var x: Vector3 = tissue_holder.global_basis.x.normalized()
			x = (x - y * x.dot(y)).normalized()
			_tail.global_transform = Transform3D(Basis(x, y * (along.length() / TAIL_REST), x.cross(y)), top)
	elif f >= TEAR_FRAME and not _torn:
		_torn = true
		_tail.transform = _tail_rest.scaled_local(Vector3(1.0, TAIL_LEFT, 1.0))
		Sfx.play_at(self, "tear", tissue_holder.global_position)
	if f >= SHEET_FRAME and _sheet_attach == null:
		_sheet_attach = BoneAttachment3D.new()
		_sheet_attach.bone_name = "DEF-hand.R"
		sk.add_child(_sheet_attach)
		sheet.reparent(_sheet_attach, false)
		sheet.transform = Transform3D(Basis(), Vector3(0.0, SHEET_ALONG, 0.0))
		sheet.visible = true


## After the wipe the sheet drops into the bowl and is gone (`into_bowl` false: just hide it, e.g. on abort).
func _drop_sheet(into_bowl: bool) -> void:
	if sheet == null or not is_instance_valid(sheet):
		return
	if _sheet_attach != null and is_instance_valid(_sheet_attach):
		sheet.reparent(self, true)
		_sheet_attach.queue_free()
	_sheet_attach = null
	if not into_bowl or not sheet.visible:
		sheet.visible = false
		return
	var tw := create_tween()
	tw.tween_property(sheet, "global_position", Vector3(_seat.x, _seat.y - 0.15, _seat.z), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: sheet.visible = false)


func _use() -> void:
	_aborted = false
	_use_spot.enabled = false
	var p = _player
	var model: Node3D = p.model()
	var sk := Pose.skeleton_of(model)
	var ap: AnimationPlayer = p.anim()
	p.busy = true
	p.posing = true
	p.set_body_collision(false)
	status_changed.emit("")

	# 1. Step in front of the toilet, then onto the seat spot: the one anchor every clip below assumes.
	p.face_direction(_forward)
	await _tween(p, "global_position", _stand_spot(), 0.5)
	if _aborted: return
	await _tween(p, "global_position", _seat_spot(), 0.3)
	if _aborted: return

	# 2. First person, the urgent yank (baked, shorts go DOWN).
	p.set_camera(atan2(-_forward.x, -_forward.z), -0.15)
	p.set_view(VIEW_FIRST_BODY, 0.4)
	await _tween_pitch(p, -1.35, 0.6)
	if _aborted: return
	Pose.set_blend(model, "sk_expr_urgency", 1.0)
	status_changed.emit("Pulling down pants...")
	await _play(ap, "pants_down")
	if _aborted: return

	# 3. Onto the seat (chains straight from pants_down): third person, in view of the door.
	p.set_camera(atan2(_forward.x, _forward.z), -0.2) # camera looks back at Bob from the door side
	p.set_view(VIEW_THIRD, 0.4)
	await _play(ap, "sit_down")
	if _aborted: return

	# 4. Poop. The timer stops now: the rest can take as long as he likes. `sit` loops while it plays.
	Pose.ensure_loop(ap, "sit")
	ap.play("sit")
	sat_down.emit()
	var t := 0.0
	# [seconds into the poop, sound]. Stage 6 (1): an explosive diarrhoea + fart burst (2.4-2.8 s, its own splats and plops), one last plop
	var cues: Array = [[0.3, "poop_blast"], [2.4, "plop"]]
	while t < poop_seconds:
		status_changed.emit("Pooping...  " + _bar(t / poop_seconds))
		if not cues.is_empty() and t >= cues[0][0]:
			if cues[0][1] == "poop_blast": # 2D: Bob's own (Stage 6b, he did not hear it as a 3D sound from the seat)
				Sfx.play_ui(self, "poop_blast")
			else:
				Sfx.play_at(self, cues[0][1], _seat)
			cues.pop_front()
		await get_tree().process_frame
		if _aborted: return
		t += get_process_delta_time()
	Pose.set_blend(model, "sk_expr_urgency", 0.0)
	Pose.set_blend(model, "sk_expr_relief", 1.0)

	# 5. Grab tissue (E, first person), then wipe (auto, third person; the clip's own timing carries it now).
	# The camera must already be looking roughly at the holder before waiting, or the "is Bob looking at it"
	# reach check in player.gd never lets the prompt appear (it's 0.75 m away, past the close-range bypass).
	status_changed.emit("")
	var to_tissue := _tissue_position() - _seat_spot()
	to_tissue.y = 0.0
	p.set_camera(atan2(-to_tissue.x, -to_tissue.z), -0.3)
	if not await _wait_prompt(_tissue):
		return # aborted while waiting
	# Owner 2026-09-25: the wiping is seen in third person. The grab used to be first person (the 2026-09-19 "grab props"
	# rule) but from the eyes it only showed the stall wall; the grab and the wipe now share the doorway view.
	p.set_camera(atan2(_forward.x, _forward.z), -0.2)
	p.set_view(VIEW_THIRD, 0.3)
	await _play(ap, "tissue_grab", [], _drive_tissue)
	if _aborted: return

	status_changed.emit("Wiping...")
	# 4 strokes at frames 16-56/30fps (bob_godot_notes.md): paper sounds timed to the baked clip, not held-E anymore.
	await _play(ap, "wipe", [[0.55, "wipe"], [0.9, "wipe"], [1.25, "wipe"], [1.6, "wipe"]])
	if _aborted: return
	_drop_sheet(true)

	# 6. Flush (E), still seated -- the seated slap, then the existing bowl-swirl cutscene.
	status_changed.emit("")
	if not await _wait_prompt(_handle):
		return
	await _play(ap, "press_flush")
	if _aborted: return
	p.set_camera(atan2(_forward.x, _forward.z), -1.0)
	p.set_view(VIEW_FIRST_HIDDEN, 0.4)
	status_changed.emit("")
	await _fx.flush(_row, _k)
	await get_tree().create_timer(0.6).timeout
	if _aborted: return
	finished.emit()

	# 7. Stand up (chains from `sit`, ends back at the 0.34 m stance) and pull the shorts back up.
	p.set_view(VIEW_THIRD, 0.3)
	await _play(ap, "stand_up")
	if _aborted: return
	p.posing = false
	status_changed.emit("")
	await _tween_method(func(v: float) -> void: Pose.set_shorts_slide(sk, model, model, v), 1.0, 0.0, 0.8)
	if _aborted: return
	await _tween(p, "global_position", _stand_spot(), 0.4)
	if _aborted: return

	# 8. Hand control back.
	p.busy = false
	p.set_body_collision(true)


func _bar(fraction: float) -> String:
	var n := clampi(int(fraction * 10.0), 0, 10)
	return "#".repeat(n) + "-".repeat(10 - n)


func _tween(node: Object, property: String, to: Variant, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property, to, seconds)
	await tween.finished


func _tween_pitch(p: Node, pitch: float, seconds: float) -> void:
	var from: float = p.get_camera_pitch()
	var yaw: float = atan2(-_forward.x, -_forward.z)
	await _tween_method(func(v: float) -> void: p.set_camera(yaw, v), from, pitch, seconds)


func _tween_method(callable: Callable, from: float, to: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(callable, from, to, seconds)
	await tween.finished


## Play a one-shot clip and wait for it to finish (or for `abort()` to set `_aborted`). `cues`, optional:
## [[seconds into the clip, sfx event], ...], played once each in order as the clip's own position reaches them.
## `each`, optional: called with `ap` on every frame of the clip (the tissue props follow `tissue_grab`).
func _play(ap: AnimationPlayer, clip: String, cues: Array = [], each := Callable()) -> void:
	ap.play(clip)
	await get_tree().process_frame # let it start before the is_playing() check below
	while ap.is_playing() and not _aborted:
		if not cues.is_empty() and ap.current_animation_position >= cues[0][0]:
			Sfx.play_at(self, cues[0][1], _seat)
			cues.pop_front()
		if each.is_valid():
			each.call(ap)
		await get_tree().process_frame


## Enable `spot` as the ONLY focusable interactable (player.posing_focus: while posing, an ambient interactable
## like the stall door behind Bob must not be able to steal a stray E press) and wait for the player to press E
## on it, or for `abort()`. Returns false if aborted.
## `pressed` is a one-element array, not a captured local: a lambda cannot reassign one (skill section 7).
func _wait_prompt(spot: Node3D) -> bool:
	spot.enabled = true
	_player.posing_focus = spot
	var pressed := [false]
	var cb := func(_p: Node3D) -> void: pressed[0] = true
	spot.used.connect(cb)
	while not pressed[0] and not _aborted:
		await get_tree().process_frame
	if spot.used.is_connected(cb):
		spot.used.disconnect(cb)
	spot.enabled = false
	_player.posing_focus = null
	return not _aborted
