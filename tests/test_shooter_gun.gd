extends SceneTree
## Stage 4 "WATER WAR" slice 1 (SPEC "Stage 4 plan APPROVED 2026-09-27"): first person, the gun, firing, the tank, one crew that takes
## damage. Real level, real mouse button and keys. Checks: the view on EVERY physics frame (camera at the eyes, Bob's body hidden, the gun
## on a 16:9 screen), the rate (8 shots/s), recoil and the gun's kick, body 12 / head 24 damage, a kill, a wall blocking every blob, the
## tank (60 shots, then none, a dry click and the EMPTY message), and third person back after abort.
## Run: timeout 180 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_shooter_gun.gd
const T := preload("res://tests/t.gd")
const Shooter := preload("res://scripts/shooter.gd")

var sh: Node
var p: CharacterBody3D
var watching := false
var frames := 0
var bad_cam := 0
var bad_body := 0
var bad_gun := 0
var far_blobs := 0
var first_bad := ""


## The screen position of a camera-space point on a 16:9 frame (Godot keeps the vertical FOV), -1..1 on both axes.
func _ndc(cam: Camera3D, world: Vector3) -> Vector2:
	var local: Vector3 = cam.global_transform.affine_inverse() * world
	var t := tan(deg_to_rad(cam.fov) / 2.0)
	return Vector2(local.x / (-local.z * t * 16.0 / 9.0), -local.y / (-local.z * t))


func _gun_on_screen(cam: Camera3D) -> bool:
	var g: Node3D = sh.gun
	if not is_instance_valid(g) or not g.is_visible_in_tree():
		return false
	# the muzzle and the blue tank (what says "water gun") on screen; the grip may be cut by the bottom edge, as in any shooter
	var tank: Node3D = null
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh is SphereMesh:
			tank = mi
	for c: Vector3 in [(g.get_node("Muzzle") as Node3D).global_position, tank.global_position]:
		if (cam.global_transform.affine_inverse() * c).z >= -cam.near:
			return false
		var s := _ndc(cam, c)
		if absf(s.x) > 0.95 or absf(s.y) > 0.95:
			return false
	# lower right: the gun's middle is right of and below the crosshair
	var mid := _ndc(cam, g.global_position)
	return mid.x > 0.2 and mid.y > 0.2


func _on_frame() -> void:
	if not watching:
		return
	frames += 1
	var cam := p.get_viewport().get_camera_3d()
	var eye := cam.global_position - p.global_position
	var flat := Vector2(eye.x, eye.z).length()
	if eye.y < 0.99 or eye.y > 1.13 or flat > 0.05:
		bad_cam += 1
		if first_bad == "":
			first_bad = "camera at y %.2f, %.2f m off Bob's middle" % [eye.y, flat]
	if p.model().is_visible_in_tree():
		bad_body += 1
	if not _gun_on_screen(cam):
		bad_gun += 1
	for b: Dictionary in sh.blobs:
		if float(b["travel"]) > Shooter.REACH + Shooter.BLOB_SPEED / 60.0 + 0.01:
			far_blobs += 1


## Point the crosshair at a world point (the camera sits at the pivot: its ray is the pivot's -Z).
func _aim(at: Vector3) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var d := at - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


## Hold the trigger for `seconds`, re-aiming at `at` every frame (a player tracking the target), then let go and let the blobs land.
func _fire_at(at: Callable, seconds: float) -> void:
	_aim(at.call()) # the first shot leaves on the press frame
	await T.left_down(self)
	for i in int(seconds * 60.0):
		_aim(at.call())
		await physics_frame
	await T.left_up(self)
	await T.wait(self, 0.6)


func _init() -> void:
	seed(1)
	var lvl := T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	p = lvl.player
	physics_frame.connect(_on_frame)
	p.global_position = Vector3(2.0, 0.0, -0.5) # 1.37 m from the nearest tap: out of refill range (slice 4)
	p.face_direction(Vector3.RIGHT)
	await T.wait(self, 0.2)

	sh = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)
	var crew = sh.spawn_crew("CREW 1", Vector3(9.0, 0.0, 0.3), -PI / 2.0)
	await T.wait(self, 0.5)
	watching = true
	T.check(sh.tank == Shooter.TANK and Shooter.TANK == 60, "the tank starts full: %d / 60" % sh.tank)
	T.check(not lvl.get_node("HUD/MissionLabel").visible, "the level checklist is hidden during the shooter")

	# --- rate, recoil, kick: aim at the wall well above the crew ---
	var wall_up := Vector3(12.6, 2.0, 0.3)
	_aim(wall_up)
	await T.wait(self, 0.1)
	var pitch0: float = p.get_camera_pitch()
	var rest_z: float = sh.gun.position.z
	await T.left_down(self)
	await physics_frame
	var kick: float = sh.gun.position.z - rest_z
	var climb: float = p.get_camera_pitch() - pitch0
	T.check(sh.shots_fired == 1, "the first shot leaves at once (%d shots)" % sh.shots_fired)
	T.check(climb > 0.006 and climb <= Shooter.RECOIL_KICK + 0.001, "one shot kicks the camera up %.4f rad (%.3f per shot)" % [climb, Shooter.RECOIL_KICK])
	T.check(kick > 0.015 and kick <= Shooter.GUN_KICK + 0.001, "the gun kicks back %.3f m" % kick)
	await T.wait(self, 3.0 - 1.0 / 60.0)
	await T.left_up(self)
	var in3: int = sh.shots_fired
	T.check(absf(in3 - (1.0 + 3.0 * Shooter.RATE)) <= 1.0, "holding 3 s fires %d shots (8/s: expect 25 +- 1)" % in3)
	T.check(sh.tank == Shooter.TANK - in3, "each shot takes 1 from the tank: %d / 60" % sh.tank)
	await T.wait(self, 1.0)
	var pitch_rest: float = p.get_camera_pitch()
	T.check(absf(pitch_rest - pitch0) < 0.002, "the recoil recovers: pitch %.4f back to %.4f" % [pitch_rest, pitch0])
	T.check(absf(sh.gun.position.z - rest_z) < 0.002, "the gun is back at rest")
	T.check(crew.hp == 100.0, "shots at the wall above the crew never hit them (hp %.0f)" % crew.hp)
	sh.tank = Shooter.TANK

	# --- body shots at 7 m ---
	var mid := func() -> Vector3: return crew.body.global_position + Vector3.UP * 0.5
	var hits_before: int = sh.hits.size()
	await _fire_at(mid, 0.6) # 5 shots = 60: the crew stays up (9 hits = 108 put them down)
	var body_hits := 0
	var head_hits := 0
	for h: Dictionary in sh.hits.slice(hits_before):
		if h["head"]:
			head_hits += 1
		else:
			body_hits += 1
	var fired: int = sh.shots_fired - in3
	T.check(fired >= 5 and body_hits == fired and head_hits == 0, "aimed at the chest from 7 m: %d body hits, %d head of %d shots" % [body_hits, head_hits, fired])
	T.check(is_equal_approx(crew.hp, 100.0 - Shooter.BODY_DAMAGE * body_hits), "a body hit does 12: hp %.0f after %d" % [crew.hp, body_hits])
	crew.hp = crew.max_hp

	# --- head shots, then the kill ---
	var head := func() -> Vector3: return crew.head_center()
	hits_before = sh.hits.size()
	var shots_before: int = sh.shots_fired
	_aim(head.call())
	await T.left_down(self)
	for i in 3:
		_aim(head.call())
		await physics_frame
	# held 4 frames (0.067 s): released before the 2nd shot (0.125 s)
	await T.left_up(self)
	await T.wait(self, 0.5)
	var heads: Array = sh.hits.slice(hits_before).filter(func(h: Dictionary) -> bool: return h["head"])
	T.check(sh.shots_fired - shots_before == 1 and heads.size() == 1 and is_equal_approx(crew.hp, 100.0 - Shooter.HEAD_DAMAGE),
			"one shot at the head = 1 headshot for 24 (hp %.0f)" % crew.hp)
	await _fire_at(head, 1.0)
	T.check(crew.down and crew.hp <= 0.0, "5 headshots put the crew down (hp %.0f, down %s)" % [crew.hp, crew.down])
	var kills: Array = sh.hits.filter(func(h: Dictionary) -> bool: return h.get("kill", false))
	T.check(kills.size() == 1, "exactly one hit is the kill (%d)" % kills.size())
	var after_down: int = sh.hits.size()
	await _fire_at(head, 0.5)
	T.check(sh.hits.size() == after_down, "a downed crew takes no more hits")

	# --- a wall blocks: Bob in corridor B, the crew in corridor A, the stall rows between ---
	sh.tank = Shooter.TANK
	var crew2 = sh.spawn_crew("CREW 2", Vector3(6.0, 0.0, 0.3), PI)
	p.global_position = Vector3(6.0, 0.0, -5.3)
	await T.wait(self, 0.5)
	var through := func() -> Vector3: return crew2.body.global_position + Vector3.UP * 0.5
	var shots_w: int = sh.shots_fired
	var walled: int = sh.wall_hits
	await _fire_at(through, 1.0)
	T.check(sh.shots_fired - shots_w >= 8 and crew2.hp == 100.0, "through the stall rows: %d shots, crew hp %.0f" % [sh.shots_fired - shots_w, crew2.hp])
	T.check(sh.wall_hits - walled == sh.shots_fired - shots_w, "every one of them splashed on a wall (%d)" % (sh.wall_hits - walled))

	# --- a bystander (a walker, layer 2) between Bob and a crew takes the blobs (first screenshot: they flew through one) ---
	p.global_position = Vector3(2.0, 0.0, 0.3) # in line with the walker (the tank is not checked here, so the sink does not matter)
	# (CREW 2 still stands at x 6: CREW 3 goes in front of them)
	var crew3 = sh.spawn_crew("CREW 3", Vector3(5.5, 0.0, 0.3), -PI / 2.0)
	var bystander: Node3D = lvl.population.spawn_walker(Vector3(4.0, 0.0, 0.3), PI / 2.0)
	lvl.population.walkers.erase(bystander)
	await T.wait(self, 0.3)
	var shots_b: int = sh.shots_fired
	walled = sh.wall_hits
	var crew3_mid := func() -> Vector3: return crew3.body.global_position + Vector3.UP * 0.5
	await _fire_at(crew3_mid, 0.6)
	T.check(sh.shots_fired - shots_b >= 5 and crew3.hp == 100.0 and sh.wall_hits - walled == sh.shots_fired - shots_b,
			"a walker in the line takes all %d blobs (crew hp %.0f)" % [sh.shots_fired - shots_b, crew3.hp])
	lvl.population.remove_walker(bystander)
	await T.wait(self, 0.2)
	await _fire_at(crew3_mid, 0.3)
	T.check(crew3.hp < 100.0, "control: with the walker gone the same aim hits (hp %.0f)" % crew3.hp)
	crew3.body.queue_free()
	sh.enemies.erase(crew3)

	# --- the tank runs dry ---
	p.global_position = Vector3(2.0, 0.0, -0.5) # out of refill range again
	await T.wait(self, 0.3)
	_aim(wall_up)
	sh.tank = Shooter.TANK
	var s0: int = sh.shots_fired
	await T.left_down(self)
	await T.wait(self, 9.0)
	var fired_all: int = sh.shots_fired - s0
	T.check(fired_all == 60 and sh.tank == 0, "a full tank fires exactly 60 shots in 9 s of holding (%d, tank %d)" % [fired_all, sh.tank])
	T.check(sh.dry_clicks >= 1, "holding on empty dry-clicks (%d)" % sh.dry_clicks)
	T.check(sh.hud.empty_label.visible and sh.hud.empty_label.text.begins_with("EMPTY"), "the HUD says EMPTY: refill at a sink")
	await T.left_up(self)
	var clicks: int = sh.dry_clicks
	await T.left_down(self)
	await T.wait(self, 0.3)
	await T.left_up(self)
	T.check(sh.shots_fired - s0 == 60 and sh.dry_clicks > clicks, "a new press on empty: no shot, a dry click")

	# --- walking while shooting keeps the view ---
	sh.tank = Shooter.TANK
	await T.key_down(self, KEY_W)
	await T.left_down(self)
	await T.wait(self, 1.0)
	await T.left_up(self)
	await T.key_up(self, KEY_W)
	await T.key_down(self, KEY_A)
	await T.wait(self, 0.5)
	await T.key_up(self, KEY_A)

	watching = false
	T.check(frames > 1000 and bad_cam == 0, "camera at the eyes on every frame (%d frames, %d bad %s)" % [frames, bad_cam, first_bad])
	T.check(bad_body == 0, "Bob's body hidden on every frame (%d bad)" % bad_body)
	T.check(bad_gun == 0, "the gun whole on a 16:9 screen, lower right, on every frame (%d bad)" % bad_gun)
	T.check(far_blobs == 0, "no blob ever flies past the %.0f m reach (%d)" % [Shooter.REACH, far_blobs])
	var gun_node: Node3D = sh.gun

	# --- back to third person ---
	sh.abort()
	await T.wait(self, 0.6)
	var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
	T.check(arm.spring_length > 2.1 and p.model().is_visible_in_tree(), "after abort: third person again (arm %.2f), Bob visible" % arm.spring_length)
	T.check(not is_instance_valid(gun_node) and sh.blobs.is_empty(), "the gun and the blobs are gone")
	T.check(lvl.get_node("HUD/MissionLabel").visible, "the level checklist is back")
	T.check(not is_instance_valid(sh.hud), "the shooter HUD is gone")

	lvl.queue_free()
	await process_frame
	T.finish(self)
