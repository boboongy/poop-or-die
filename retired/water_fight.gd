extends Node
## Level 4, the 3rd cutter: BOSSY's WATER FIGHT (SPEC "Water fight"; details = the plan the owner approved 2026-09-24, numbers
## are PROPOSAL, tune by playtest). Same stage as the fist fights, but Bob keeps his own over-the-shoulder camera (slid right so
## the crosshair is not on his head) and moves freely: a placeholder water gun lies on the floor near him, E picks it up, HOLD
## left click sprays along the screen-centre crosshair; SOAK_SECONDS of hits fill BOSSY's WET meter = SOAKED! (slow motion).
## BOSSY keeps 3-5 m away, sidesteps, and sprays in bursts; the aim trails Bob and wobbles, so moving (or ducking round a
## wall) dodges it; standing in the stream costs HURT_PER_SECOND. Bob at 0 hp = K.O. `ended(winner, finished)` like fight.gd.

signal ended(winner: String, finished: bool) ## winner "BOB" or the foe's name; finished is always false (no FINISH HIM here)

const FightHud := preload("res://scripts/fight_hud.gd")
const Pose := preload("res://scripts/pose.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Interactable := preload("res://scripts/simple_interactable.gd")

const INTRO_SECONDS := 1.6 ## ROUND n, then WATER FIGHT! at FIGHT_CALL before the end; nobody can act until it ends
const FIGHT_CALL := 0.6
const START_GAP := 4.2
const BOB_HP := 100.0
const RANGE := 6.0 ## both guns reach this far (from the shooter)
const SOAK_SECONDS := 4.0 ## seconds of hits to fill BOSSY's WET meter
const HIT_RADIUS := 0.35 ## the crosshair ray passing this near BOSSY's middle (sideways) is a hit
const HURT_PER_SECOND := 8.0 ## Bob's hp lost per second inside BOSSY's stream
const STREAM_HALF_WIDTH := 0.4 ## BOSSY's stream hits Bob when it passes this near him
const BURST_ON := 1.5
const BURST_OFF := 1.0
const FIRST_BURST := 0.4 ## after the intro
const AIM_TURN := 1.0 ## rad/s: how fast BOSSY's aim follows Bob (sprinting past at 4 m outruns it)
const AIM_WOBBLE := 0.12 ## rad: BOSSY's aim sways this much either side
const BOSS_SPEED := 1.4
const KEEP_NEAR := 3.0
const KEEP_FAR := 5.0
## The open east end (tests/probe_level4_space.gd from the stage centre: 0.85 m to the west wall, 1.15 m east, 3.5/3.6 m along):
## BOSSY stays inside this rectangle round the stage centre.
const STAGE_HALF_WIDTH := 0.5
const STAGE_HALF_LENGTH := 3.0
const CAM_SHOULDER := 0.55 ## Bob's camera slides this far right: over the shoulder, the crosshair is not on his head
const CHEST := 0.9
## The gun in the RIGHT hand, model space: the models' front is +Z, so their right is -X (at +X it sat on Bob's left, hidden by his
## body from the right-shoulder camera; first screenshot pass).
const HOLD_POS := Vector3(-0.3, 0.85, 0.3)
const KO_SLOWMO := 0.3
const KO_SLOWMO_SECONDS := 1.0 ## real seconds
const KO_TILT := -1.35
const BLUE := Color(0.25, 0.7, 1.0)
const RED := Color(1.0, 0.15, 0.1)
const BOB_GUN := Color(1.0, 0.85, 0.1)
const BOSS_GUN := Color(0.35, 1.0, 0.2)

var bob_body ## the player (untyped: frozen, model(), turn_toward() are used)
var foe_body ## BOSSY (npc_jijio.gd)
var foe_name := ""
var bob_hp := BOB_HP
var wet := 0.0 ## BOSSY's WET meter, 0..1
var has_gun := false
var gun: Node3D ## Bob's gun: on the floor, then in his hand
var boss_gun: Node3D
var bob_stream: CPUParticles3D
var boss_stream: CPUParticles3D
var pickup ## simple_interactable.gd on the gun
var hud ## fight_hud.gd in water mode
var running := false
var ai_enabled := true
var spraying := false ## BOSSY is in a burst
var bob_hurt := false ## Bob is in BOSSY's stream this frame
var bursts := 0 ## how many bursts BOSSY started (tests count them)
var start_point := Vector3.ZERO
var hide_nodes: Array = [] ## the level's HUD items to hide during the fight, shown again after

var _center := Vector3.ZERO
var _axis := Vector3.FORWARD
var _side := Vector3.RIGHT
var _cam: Camera3D
var _hidden: Array = []
var _intro_left := 0.0
var _ending := false
var _rng := RandomNumberGenerator.new()
var _aim_yaw := 0.0
var _burst_left := FIRST_BURST
var _strafe_dir := 0.0
var _strafe_left := 0.0
var _time := 0.0
var _bob_sound: AudioStreamPlayer3D
var _boss_sound: AudioStreamPlayer3D


func start(player, npc, center: Vector3, axis: Vector3, name_of_foe: String, rng_seed: int = 1, round_number: int = 3) -> void:
	_rng.seed = rng_seed
	bob_body = player
	foe_body = npc
	foe_name = name_of_foe
	_center = center
	_axis = Vector3(axis.x, 0.0, axis.z).normalized()
	_side = _axis.cross(Vector3.UP).normalized()
	var floor_y: float = player.global_position.y
	start_point = Vector3(center.x, floor_y, center.z) - _axis * START_GAP / 2.0
	player.global_position = start_point
	player.velocity = Vector3.ZERO
	player.model().rotation = Vector3(0.0, player.model().rotation.y, 0.0)
	player.face_direction(_axis)
	player.frozen = true
	npc.state = npc.State.FIGHT
	npc.velocity = Vector3.ZERO
	npc.global_position = Vector3(center.x, npc.global_position.y, center.z) + _axis * START_GAP / 2.0
	_aim_yaw = atan2(-_axis.x, -_axis.z)
	npc.face_yaw(_aim_yaw)
	# Bob's own camera, slid to the shoulder
	_cam = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.shoulder = CAM_SHOULDER # the pivot slides, so the spring arm still keeps the camera out of walls (h_offset did not)
	# the guns: Bob's lies on the floor a step ahead and to the side, BOSSY's is in BOSSY's hand
	gun = _make_gun(BOB_GUN)
	add_child(gun)
	gun.global_position = start_point + _axis * 1.0 + _side * 0.45 + Vector3.UP * 0.07
	gun.rotation = Vector3(0.0, atan2(_side.x, _side.z), PI / 2.0) # on its side
	bob_stream = _make_stream(BOB_GUN.lerp(BLUE, 0.7))
	gun.add_child(bob_stream)
	pickup = Interactable.new()
	pickup.prompt_text = "E  pick up the water gun"
	pickup.point = gun.global_position
	pickup.used.connect(_on_pickup)
	add_child(pickup)
	boss_gun = _make_gun(BOSS_GUN)
	npc.get_node("Model").add_child(boss_gun)
	boss_gun.position = HOLD_POS
	boss_gun.rotation = Vector3(0.0, PI, 0.0)
	boss_stream = _make_stream(BLUE)
	boss_gun.add_child(boss_stream)
	_bob_sound = Sfx.loop_at(gun, "spray")
	_boss_sound = Sfx.loop_at(boss_gun, "spray")
	_bob_sound.stream_paused = true
	_boss_sound.stream_paused = true
	_hidden = []
	for n in hide_nodes:
		if is_instance_valid(n):
			_hidden.append([n, n.visible])
			n.visible = false
	hud = FightHud.new()
	add_child(hud)
	hud.setup("BOB", foe_name)
	hud.water_mode(foe_name)
	hud.announce("ROUND %d" % round_number, Color.WHITE)
	_intro_left = INTRO_SECONDS
	running = true
	hud.update_water(1.0, 0.0, false, false, 0.0)


## True while both can act (after the intro, before the end).
func fighting() -> bool:
	return running and _intro_left <= 0.0 and not _ending


## Stop at once (level timeout or reset): Bob free again, his camera back, normal time.
func abort() -> void:
	running = false
	Engine.time_scale = 1.0
	if is_instance_valid(bob_body):
		bob_body.frozen = false
	_restore_camera()
	_restore_hidden()
	_free_props()
	if is_instance_valid(hud):
		hud.queue_free()


## True when the screen-centre crosshair is on BOSSY within reach (no wall between).
func crosshair_on_foe() -> bool:
	return bool(_crosshair()["on"])


func _physics_process(delta: float) -> void:
	if not running:
		return
	_time += delta
	if _intro_left > 0.0:
		var before := _intro_left
		_intro_left = maxf(_intro_left - delta, 0.0)
		if before > FIGHT_CALL and _intro_left <= FIGHT_CALL:
			hud.announce("WATER FIGHT!", Color(1.0, 0.8, 0.1), 0.5)
		if _intro_left <= 0.0:
			bob_body.frozen = false
		_boss_walk_clip(0.0)
		hud.update_water(bob_hp / BOB_HP, wet, false, false, delta)
		return
	if _ending:
		_boss_walk_clip(0.0)
		return
	_bob(delta)
	if ai_enabled:
		_ai(delta)
	else:
		spraying = false
		bob_hurt = false
		_boss_walk_clip(0.0)
	boss_stream.emitting = spraying
	_boss_sound.stream_paused = not spraying
	hud.update_water(bob_hp / BOB_HP, wet, has_gun, bob_hurt, delta)
	if wet >= 1.0:
		_end(true)
	elif bob_hp <= 0.0:
		_end(false)


# --- Bob -------------------------------------------------------------------------------------------------------------

func _on_pickup(_player: Node3D) -> void:
	if has_gun or not fighting():
		return
	has_gun = true
	pickup.enabled = false
	Sfx.play_ui(self, "pickup")
	gun.reparent(bob_body.model(), false)
	gun.position = HOLD_POS
	gun.rotation = Vector3(0.0, PI, 0.0)


func _bob(delta: float) -> void:
	var holding: bool = has_gun and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not bob_body.frozen
	bob_stream.emitting = holding
	_bob_sound.stream_paused = not holding
	if not holding:
		if has_gun:
			gun.position = HOLD_POS
			gun.rotation = Vector3(0.0, PI, 0.0)
		return
	var aim := _crosshair()
	var end: Vector3 = aim["end"]
	bob_body.turn_toward(end)
	gun.position = HOLD_POS
	gun.look_at(end, Vector3.UP)
	if aim["on"]:
		wet = minf(wet + delta / SOAK_SECONDS, 1.0)


## The crosshair ray (camera centre, including the shoulder offset): where the stream lands ("end") and whether it is on
## BOSSY ("on": the ray passes within HIT_RADIUS of BOSSY sideways, at body height, before any wall, BOSSY within RANGE of Bob).
func _crosshair() -> Dictionary:
	var o: Vector3 = _cam.global_position + _cam.global_basis.x * _cam.h_offset + _cam.global_basis.y * _cam.v_offset
	var dir: Vector3 = -_cam.global_basis.z
	# start level with Bob, not at the camera: the spring arm can leave the camera in or behind the wall at his back (it stood
	# at z 1.26 behind the stage's wall at z 1.0), and a ray from there hits that wall's back face first
	var chest: Vector3 = bob_body.global_position + Vector3.UP * CHEST
	o += dir * maxf((chest - o).dot(dir), 0.0)
	var far := RANGE + 0.5
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * far, 1, [bob_body.get_rid(), foe_body.get_rid()])
	var hit: Dictionary = bob_body.get_world_3d().direct_space_state.intersect_ray(q)
	var wall: float = far if hit.is_empty() else o.distance_to(hit["position"])
	var result := {"end": o + dir * wall, "on": false}
	var foot: Vector3 = foe_body.global_position
	var c := foot + Vector3.UP * CHEST
	var t := (c - o).dot(dir)
	if t <= 0.0 or t >= wall:
		return result
	var at := o + dir * t
	var bob_pos := chest
	var sideways := Vector2(at.x - c.x, at.z - c.z).length()
	var h := at.y - foot.y
	var reach := Vector2(foot.x - bob_pos.x, foot.z - bob_pos.z).length()
	if sideways < HIT_RADIUS and h > 0.1 and h < 1.6 and reach <= RANGE:
		result["on"] = true
		result["end"] = at
	return result


# --- BOSSY -----------------------------------------------------------------------------------------------------------

func _ai(delta: float) -> void:
	var boss: Vector3 = foe_body.global_position
	var bob_pos: Vector3 = bob_body.global_position
	var to := Vector3(bob_pos.x - boss.x, 0.0, bob_pos.z - boss.z)
	var dist := to.length()
	var toward := to / dist if dist > 0.01 else _axis
	# keep KEEP_NEAR..KEEP_FAR from Bob, sidestep now and then, never leave the stage
	var move := Vector3.ZERO
	if dist < KEEP_NEAR:
		move -= toward
	elif dist > KEEP_FAR:
		move += toward
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_left = _rng.randf_range(0.6, 1.4)
		_strafe_dir = [-1.0, 0.0, 1.0][_rng.randi_range(0, 2)]
	move += _side * _strafe_dir * 0.8
	if move.length() > 1.0:
		move = move.normalized()
	var np := _on_stage(boss + move * BOSS_SPEED * delta)
	_boss_walk_clip(Vector2(np.x - boss.x, np.z - boss.z).length() / delta)
	foe_body.global_position = np
	# the aim trails Bob and sways
	var want := atan2(toward.x, toward.z)
	_aim_yaw = rotate_toward(_aim_yaw, want, AIM_TURN * delta)
	var shown := _aim_yaw + AIM_WOBBLE * sin(_time * 3.1)
	foe_body.face_yaw(shown)
	# bursts
	_burst_left -= delta
	if _burst_left <= 0.0:
		spraying = not spraying
		_burst_left = BURST_ON if spraying else BURST_OFF
		if spraying:
			bursts += 1
	bob_hurt = false
	if not spraying or dist > RANGE:
		return
	var off := angle_difference(shown, want)
	if absf(off) < PI / 2.0 and absf(dist * sin(off)) < STREAM_HALF_WIDTH and _clear(boss, bob_pos):
		bob_hurt = true
		bob_hp = maxf(bob_hp - HURT_PER_SECOND * delta, 0.0)


func _on_stage(at: Vector3) -> Vector3:
	var rel := at - _center
	var along := clampf(rel.dot(_axis), -STAGE_HALF_LENGTH, STAGE_HALF_LENGTH)
	var across := clampf(rel.dot(_side), -STAGE_HALF_WIDTH, STAGE_HALF_WIDTH)
	var p := _center + _axis * along + _side * across
	return Vector3(p.x, at.y, p.z)


## No wall between the two chests.
func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * CHEST, b + Vector3.UP * CHEST, 1, [bob_body.get_rid(), foe_body.get_rid()])
	return bob_body.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _boss_walk_clip(speed: float) -> void:
	Pose.locomotion(foe_body.anim(), speed, 2.8)


# --- the end ---------------------------------------------------------------------------------------------------------

func _end(bob_won: bool) -> void:
	_ending = true
	spraying = false
	boss_stream.emitting = false
	bob_stream.emitting = false
	_bob_sound.stream_paused = true
	_boss_sound.stream_paused = true
	Engine.time_scale = KO_SLOWMO
	hud.update_water(bob_hp / BOB_HP, wet, false, false, 0.0)
	hud.announce("SOAKED!" if bob_won else "K.O.", BLUE if bob_won else RED)
	var loser: Node3D = (foe_body if bob_won else bob_body).get_node("Model")
	var tw := loser.create_tween()
	tw.tween_property(loser, "rotation:x", KO_TILT, 0.4)
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.wait_time = KO_SLOWMO_SECONDS
	add_child(timer)
	timer.timeout.connect(_finish_end.bind(bob_won))
	timer.start()


func _finish_end(bob_won: bool) -> void:
	Engine.time_scale = 1.0
	running = false
	_restore_camera()
	_restore_hidden()
	_free_props()
	hud.finish(1.0)
	if bob_won:
		bob_body.frozen = false
	else:
		bob_body.frozen = true # he lies there; the level shows its fail screen
	ended.emit("BOB" if bob_won else foe_name, false)


func _restore_camera() -> void:
	if is_instance_valid(bob_body):
		bob_body.shoulder = 0.0


func _restore_hidden() -> void:
	for pair: Array in _hidden:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	_hidden = []


func _free_props() -> void:
	for n in [gun, boss_gun, pickup]:
		if is_instance_valid(n):
			n.queue_free()


# --- placeholder props -----------------------------------------------------------------------------------------------

## A chunky toy water gun (placeholder until the factory makes one): body, barrel along -Z, a tank on top, a grip. Self-lit
## so it reads in the green-lit white room (skill 3c).
static func _make_gun(color: Color) -> Node3D:
	var g := Node3D.new()
	g.name = "WaterGun"
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.13, 0.3)
	_part(g, box, Vector3.ZERO, Vector3.ZERO, color)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.025
	barrel.bottom_radius = 0.025
	barrel.height = 0.18
	_part(g, barrel, Vector3(0.0, 0.02, -0.23), Vector3(PI / 2.0, 0.0, 0.0), color.darkened(0.3))
	var tank := SphereMesh.new()
	tank.radius = 0.075
	tank.height = 0.15
	_part(g, tank, Vector3(0.0, 0.11, 0.04), Vector3.ZERO, BLUE)
	var grip := BoxMesh.new()
	grip.size = Vector3(0.06, 0.14, 0.06)
	_part(g, grip, Vector3(0.0, -0.12, 0.08), Vector3(-0.3, 0.0, 0.0), color.darkened(0.3))
	return g


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


## The water stream out of the muzzle (the gun's -Z): bright self-lit drops flying about RANGE metres.
static func _make_stream(color: Color) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.name = "Stream"
	s.position = Vector3(0.0, 0.02, -0.33)
	s.emitting = false
	s.amount = 90
	s.lifetime = 0.55
	s.local_coords = false
	s.direction = Vector3(0.0, 0.0, -1.0)
	s.spread = 2.5
	s.initial_velocity_min = 10.0
	s.initial_velocity_max = 11.0
	s.gravity = Vector3(0.0, -3.0, 0.0)
	s.scale_amount_min = 0.6
	s.scale_amount_max = 1.3
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	drop.material = mat
	s.mesh = drop
	return s
