extends Node
## The Level 3 jump scare (stand-in until the owner's real one). The seeker who found Bob gets the ONLY under-light (a pale green lamp
## just below its chin, like a torch held under the face).
## The third-person camera is useless here: inside a 0.95 m stall it sits 0.4 m behind Bob and fills the screen with his hair (seen
## 2026-09-22). So the scare has its own cameras:
##  - found by PEEKING: first the seeker's own view through the door gap, at floor level, looking at Bob's shoes lit from below (this is
##    the clue the player has to notice: they were seen by their feet), then the door bangs open;
##  - then, both ways: Bob's own eyes, the face lunges at the camera (white flash, loud sound), and the result screen says press R.
## Called once (hide_seek.gd `_caught` guards it).

const Sfx := preload("res://scripts/sfx.gd")

const LIGHT_COLOR := Color(0.75, 1.0, 0.8)
const FACE_DISTANCE := 0.85 ## m from Bob's eyes to the lunging face
const HEAD_HEIGHT := 1.15 ## m: a Jijio's head centre above its feet
const GLOW_ENERGY := 0.7## the under-light while the face peeks (5.0 blew the gap view out to pure white, 2026-09-22)
const LUNGE_ENERGY := 1.5 ## and at the lunge (12.0 hid the face in a white blob)
const ROOM_DIM := 0.3 ## the other lights fall to this fraction during the scare
const DARK_EXPOSURE := 0.3 ## and the picture's exposure falls to this (1.0 = normal)

var _flash: ColorRect


func play(level: Node3D, seeker, door: Node3D) -> void:
	var player: CharacterBody3D = level.player
	var model: Node3D = seeker.get_node("Model")
	seeker.collision_layer = 0
	seeker.collision_mask = 0
	var light := OmniLight3D.new()
	light.name = "UnderLight"
	light.light_color = LIGHT_COLOR
	light.light_energy = 0.0
	light.omni_range = 2.0
	light.shadow_enabled = false
	model.add_child(light)
	light.position = Vector3(0.0, 0.85, 0.3) # below and in front of the chin (the model's front is +Z, the head is about 1.15 m up)
	_make_flash()
	_dim_room(level)
	var glow := create_tween()
	glow.tween_property(light, "light_energy", GLOW_ENERGY, 0.3)
	if door == null:
		# seen in the open: it runs at Bob first (at most 3 s, the normal camera sees it come), then the lunge
		seeker.start_kicking(player, 0.0)
		var t := 0.0
		while is_instance_valid(seeker) and t < 3.0 and seeker.global_position.distance_to(player.global_position) > 1.4:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		if not is_instance_valid(seeker):
			return
		seeker.state = seeker.State.IDLE
		seeker.velocity = Vector3.ZERO
	else:
		_gap_view(player, door)
		await get_tree().create_timer(1.2).timeout # the lit shoes, seen from the gap
		if not is_instance_valid(seeker):
			return
		door.set_open(true, 0.08)
		Sfx.play_at(door, "door_open", door.global_position)
		await get_tree().create_timer(0.15).timeout
	_lunge(player, seeker, light)
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(get_parent()) and is_instance_valid(level):
		var dark := create_tween()
		dark.tween_property(_flash, "color", Color(0.0, 0.0, 0.0, 0.55), 0.5)
		level.show_result("THEY FOUND YOU!\nPress R to try again")
		level.bob_shat() # Stage 6d


## The seeker's eyes: on the corridor side of the door, 0.2 m above the floor, looking at Bob's feet.
func _gap_view(player: CharacterBody3D, door: Node3D) -> void:
	var cam := Camera3D.new()
	cam.name = "GapCamera"
	cam.fov = 85.0
	cam.near = 0.02
	add_child(cam)
	var door_z: float = door.point.z
	var outward := Vector3(0.0, 0.0, 1.0) if door_z > -2.5 else Vector3(0.0, 0.0, -1.0) # row 1 doors face +Z, row 2 doors -Z
	cam.global_position = Vector3(door.point.x, 0.2, door.point.z) + outward * 0.12
	cam.look_at(player.global_position + Vector3(0.0, 0.1, 0.0), Vector3.UP)
	cam.current = true


## Bob's own eyes, the face jumps to 0.85 m in front of them, turned to look into the lens, white flash and a loud sound.
func _lunge(player: CharacterBody3D, seeker, light: OmniLight3D) -> void:
	var model: Node3D = seeker.get_node("Model")
	var eye := player.global_position + Vector3(0.0, 1.0, 0.0)
	player.model().visible = false # the camera is inside his head
	var cam := Camera3D.new()
	cam.name = "EyeCamera"
	cam.fov = 75.0
	cam.near = 0.02
	add_child(cam)
	cam.global_position = eye
	var head_now: Vector3 = seeker.global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
	var dir := head_now - eye
	if dir.length() < 0.2:
		dir = Vector3(0.0, 0.0, 1.0)
	cam.look_at(eye + dir, Vector3.UP)
	cam.current = true
	var head := eye + dir.normalized() * FACE_DISTANCE
	var feet := Vector3(head.x, head.y - HEAD_HEIGHT, head.z)
	var back := eye - head # from the face to the lens
	var flat := Vector2(back.x, back.z).length()
	seeker.face_yaw(atan2(back.x, back.z))
	Sfx.play_ui(self, "scare")
	var lunge := create_tween().set_parallel(true)
	lunge.tween_property(seeker, "global_position", feet, 0.22)
	lunge.tween_property(model, "rotation:x", -atan2(back.y, flat), 0.22) # tilt the face toward the lens
	lunge.tween_property(light, "light_energy", LUNGE_ENERGY, 0.22)
	_flash.color = Color(1.0, 1.0, 1.0, 0.8)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.18)


## The toilet is so brightly lit that a lamp under a chin only whites the face out (seen 2026-09-22). A face lit from below needs a dark
## room around it: every other light fades down to ROOM_DIM of its strength.
func _dim_room(level: Node3D) -> void:
	for node in level.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.name != "UnderLight":
			create_tween().tween_property(light, "light_energy", light.light_energy * ROOM_DIM, 0.4)
	# most of the brightness is global illumination from the glowing panels, so the lights alone do little: lower the exposure too
	var world := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		create_tween().tween_property(world.environment, "tonemap_exposure", DARK_EXPOSURE, 0.4)


func _make_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	layer.add_child(_flash)
