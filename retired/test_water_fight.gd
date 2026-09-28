extends SceneTree
## Level 4 step 5: BOSSY's water fight (scripts/water_fight.gd, SPEC "Water fight") in the real level with real keys and clicks:
## the intro locks Bob and BOSSY does not shoot; Bob's own camera slides to the shoulder; the gun lies on the floor near Bob;
## clicking without the gun sprays nothing; BOSSY's bursts hurt Bob in the open but not behind a wall (control + cover, bursts
## counted); BOSSY stays on the stage every frame; E picks the gun up; 1 s on BOSSY = a quarter soaked, a miss soaks nothing;
## soaked = SOAKED! and ended("BOB") with everything handed back; Bob at 0 hp = ended("BOSSY"); abort hands everything back.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const WaterFight := preload("res://scripts/water_fight.gd")
const Cutters := preload("res://scripts/cutters.gd")

const COVER := Vector3(9.6, 0.0, 0.0) ## corridor A, round the corner from the stage: a wall between Bob and BOSSY

var lvl: Node
var p: CharacterBody3D
var cam: Camera3D
var got: Array = []
var bosses: Array = []
var max_off_stage := 0.0 ## BOSSY's worst distance outside the stage rectangle, sampled every frame


func _new_fight(rng_seed: int) -> Node:
	var boss: Node3D = lvl.population.spawn_walker(Cutters.STAGE_CENTER + Cutters.STAGE_AXIS * 2.0, 0.0)
	lvl.population.walkers.erase(boss)
	bosses.append(boss)
	var wf: Node = WaterFight.new()
	lvl.add_child(wf)
	wf.start(p, boss, Cutters.STAGE_CENTER, Cutters.STAGE_AXIS, "BOSSY", rng_seed, 3)
	wf.ended.connect(func(w: String, _f: bool) -> void: got.append(w))
	return wf


## Turn the camera (yaw only) until the screen-centre crosshair is on BOSSY, then add `off` radians. False if no yaw hits.
func _aim(wf: Node, off: float) -> bool:
	var to: Vector3 = wf.foe_body.global_position - p.global_position
	var base := atan2(-to.x, -to.z)
	var pitch: float = p.get_camera_pitch()
	var hits: Array = []
	var a := -0.5
	while a <= 0.5:
		p.set_camera(base + a, pitch)
		if wf.crosshair_on_foe():
			hits.append(a)
		a += 0.01
	if hits.is_empty():
		p.set_camera(base, pitch)
		print("no hit: bob %s boss %s cam %s dir %s" % [p.global_position, wf.foe_body.global_position, cam.global_position, -cam.global_basis.z])
		return false
	p.set_camera(base + (float(hits[0]) + float(hits[hits.size() - 1])) / 2.0 + off, pitch)
	await physics_frame
	return true


func _stage_offset(wf: Node) -> float:
	var b: Vector3 = wf.foe_body.global_position
	var c := Cutters.STAGE_CENTER
	var dx := maxf(absf(b.x - c.x) - WaterFight.STAGE_HALF_WIDTH, 0.0)
	var dz := maxf(absf(b.z - c.z) - WaterFight.STAGE_HALF_LENGTH, 0.0)
	return maxf(dx, dz)


## Wait `seconds`, recording on every frame BOSSY's worst position off the stage and whether a wall stands between Bob's
## head and the camera (the shoulder offset once put the camera inside a wall: a dark wedge on screen).
func _watch(wf: Node, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame
		if is_instance_valid(wf) and wf.running:
			max_off_stage = maxf(max_off_stage, _stage_offset(wf))
			cam_frames += 1
			if _cam_blocked():
				cam_blocked += 1


var cam_frames := 0
var cam_blocked := 0


func _cam_blocked() -> bool:
	var head := p.global_position + Vector3.UP * 1.1
	var q := PhysicsRayQueryParameters3D.create(head, cam.global_position, 1, [p.get_rid()])
	return not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _handed_back(what: String, _unused: float) -> void:
	T.check(not p.frozen and not p.busy, "%s: Bob can move again" % what)
	T.check(p.shoulder == 0.0, "%s: the camera is back behind Bob (shoulder %.2f)" % [what, p.shoulder])
	T.check(p.get_viewport().get_camera_3d() == cam, "%s: Bob's own camera is on" % what)
	T.check(is_equal_approx(Engine.time_scale, 1.0), "%s: normal time (%.2f)" % [what, Engine.time_scale])


func _init() -> void:
	seed(1)
	Progress.level = 1
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	p = lvl.player
	cam = p.get_node("CameraPivot/SpringArm3D/Camera3D")
	var cam_offset0 := 0.0

	# 1. intro: ROUND 3, Bob locked, BOSSY quiet; shoulder camera; the gun on the floor near Bob
	var wf := _new_fight(1)
	var gun: Node3D = wf.gun
	T.check(wf.hud.big.text == "ROUND 3", "intro says ROUND 3 (got '%s')" % wf.hud.big.text)
	T.check(p.frozen and not wf.fighting(), "Bob cannot move during the intro")
	await T.wait(self, 0.1) # the pivot moves in the player's _process, after the process_frame signal
	var slid: float = (cam.global_position - p.global_position).dot(cam.global_basis.x)
	T.check(p.get_viewport().get_camera_3d() == cam and p.shoulder == WaterFight.CAM_SHOULDER and absf(slid - WaterFight.CAM_SHOULDER) < 0.05,
			"Bob's own camera, slid %.2f m to the shoulder" % slid)
	var gd := Vector2(gun.global_position.x - p.global_position.x, gun.global_position.z - p.global_position.z).length()
	T.check(gun.visible and gun.global_position.y - p.global_position.y < 0.3 and gd > 0.6 and gd < 1.3,
			"the gun lies on the floor %.2f m from Bob" % gd)
	await _watch(wf, WaterFight.INTRO_SECONDS - 0.3)
	T.check(wf.hud.big.text == "WATER FIGHT!", "then WATER FIGHT! (got '%s')" % wf.hud.big.text)
	T.check(wf.bob_hp == WaterFight.BOB_HP and wf.bursts == 0, "BOSSY does not shoot during the intro (hp %.1f)" % wf.bob_hp)
	await _watch(wf, 0.5)
	T.check(wf.fighting() and not p.frozen, "controls unlock after the intro")

	# 2. no gun yet: holding left click sprays nothing; BOSSY's bursts hurt Bob standing in the open (the control for 5.)
	await T.left_down(self)
	await _watch(wf, 1.0)
	T.check(wf.wet == 0.0 and not wf.bob_stream.emitting, "without the gun, left click sprays nothing")
	await T.left_up(self)
	var hp0: float = wf.bob_hp
	var b0: int = wf.bursts
	await _watch(wf, 4.0)
	var lost: float = hp0 - wf.bob_hp
	print("open: lost %.1f hp in 4 s over %d bursts" % [lost, wf.bursts - b0])
	T.check(wf.bursts - b0 >= 1 and lost > 0.0, "BOSSY's stream hurts Bob in the open (%.1f hp, %d bursts)" % [lost, wf.bursts - b0])
	T.check(lost <= WaterFight.HURT_PER_SECOND * 4.0 + 0.01, "no faster than %.0f hp/s (lost %.1f in 4 s)" % [WaterFight.HURT_PER_SECOND, lost])

	# 3. E picks up the gun (Bob steps back to it, as a player would)
	p.global_position = gun.global_position + (p.global_position - gun.global_position).normalized() * 0.5
	var to_gun := gun.global_position - p.global_position
	to_gun.y = 0.0
	p.face_direction(to_gun.normalized())
	await T.wait(self, 0.3)
	T.check(lvl._prompt.text.contains("water gun"), "E prompt for the gun (got '%s')" % lvl._prompt.text)
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	T.check(wf.has_gun and gun.get_parent() == p.model(), "Bob holds the gun")
	T.check(wf.hud.crosshair.visible, "the crosshair shows once he has it")
	T.check(lvl._prompt.text == "", "no gun prompt any more (got '%s')" % lvl._prompt.text)

	# 4. aim: 1 s on BOSSY = a quarter soaked; a miss soaks nothing (BOSSY still for exact numbers)
	wf.ai_enabled = false
	T.check(await _aim(wf, 0.0), "some yaw puts the crosshair on BOSSY")
	await T.left_down(self)
	await T.wait(self, 0.5)
	T.check(wf.bob_stream.emitting, "Bob's stream flows while left click is held")
	await T.wait(self, 0.5)
	await T.left_up(self)
	await T.wait(self, 0.1)
	var w1: float = wf.wet
	T.check(absf(w1 - 1.0 / WaterFight.SOAK_SECONDS) < 0.05, "1 s on BOSSY soaks %.2f (expect %.2f)" % [w1, 1.0 / WaterFight.SOAK_SECONDS])
	T.check(not wf.bob_stream.emitting, "the stream stops when the button is let go")
	await _aim(wf, 0.5)
	await T.left_down(self)
	await T.wait(self, 1.0)
	await T.left_up(self)
	T.check(is_equal_approx(wf.wet, w1), "aimed 0.5 rad off: nothing soaked (%.3f -> %.3f)" % [w1, wf.wet])

	# 5. cover: round the corner in corridor A, a wall between them, BOSSY's bursts do nothing
	wf.ai_enabled = true
	p.global_position = Vector3(COVER.x, p.global_position.y, COVER.z)
	hp0 = wf.bob_hp
	b0 = wf.bursts
	await _watch(wf, 4.0)
	print("cover: lost %.1f hp in 4 s over %d bursts" % [hp0 - wf.bob_hp, wf.bursts - b0])
	T.check(wf.bursts - b0 >= 1 and is_equal_approx(wf.bob_hp, hp0), "behind the wall BOSSY's bursts miss (%d bursts, %.1f hp lost)" % [wf.bursts - b0, hp0 - wf.bob_hp])
	T.check(max_off_stage < 0.01, "BOSSY stayed on the stage every frame (worst %.2f m off)" % max_off_stage)

	# 5b. Bob pressed against the stage's east wall, looking along the stage: the shoulder shrinks, the camera stays in the room
	var east := Vector3(Cutters.STAGE_CENTER.x + 0.85, p.global_position.y, Cutters.STAGE_CENTER.z + 1.0)
	p.global_position = east
	p.set_camera(0.0, p.get_camera_pitch()) # yaw 0 = looking toward -Z: his right is the east wall (+X)
	await _watch(wf, 0.5)
	var slid_east: float = (cam.global_position - p.global_position).dot(cam.global_basis.x)
	T.check(slid_east < WaterFight.CAM_SHOULDER - 0.1 and not _cam_blocked(), "against the east wall the shoulder shrinks to %.2f m, camera in the room" % slid_east)
	print("camera-behind-a-wall frames: %d of %d" % [cam_blocked, cam_frames])
	T.check(cam_frames > 300 and cam_blocked == 0, "no wall between Bob's head and the camera on any frame (%d of %d)" % [cam_blocked, cam_frames])

	# 6. win: back on the stage, hold on BOSSY until soaked
	wf.ai_enabled = false
	p.global_position = wf.start_point
	await T.wait(self, 0.1)
	await _aim(wf, 0.0)
	var t0 := Time.get_ticks_msec()
	await T.left_down(self)
	var held := 0.0
	while wf.wet < 1.0 and held < 8.0:
		await T.wait(self, 0.1)
		held += 0.1
	await T.left_up(self)
	var expect := (1.0 - w1) * WaterFight.SOAK_SECONDS
	T.check(wf.wet >= 1.0 and absf(held - expect) < 0.3, "soaked after %.1f s more (expect %.1f)" % [held, expect])
	T.check(wf.hud.big.text == "SOAKED!", "SOAKED! (got '%s')" % wf.hud.big.text)
	T.check(Engine.time_scale < 1.0, "slow motion on the soak (%.2f)" % Engine.time_scale)
	await T.wait_for(self, func() -> bool: return not got.is_empty(), 4.0)
	T.check(got == ["BOB"], "ended('BOB') (%s)" % [got])
	_handed_back("won", cam_offset0)
	T.check(not is_instance_valid(gun) or not gun.is_inside_tree(), "the gun is gone after the fight")
	print("win took %d ms of wall time" % (Time.get_ticks_msec() - t0))

	# 7. lose: Bob at 1 hp in the open, BOSSY's AI on
	got.clear()
	var wf2 := _new_fight(2)
	await T.wait(self, WaterFight.INTRO_SECONDS + 0.1)
	wf2.bob_hp = 1.0
	await T.wait_for(self, func() -> bool: return not got.is_empty(), 12.0)
	T.check(got == ["BOSSY"], "Bob at 0 hp: ended('BOSSY') (%s)" % [got])
	T.check(p.shoulder == 0.0, "lost: the camera is back behind Bob")
	T.check(is_equal_approx(Engine.time_scale, 1.0), "lost: normal time")
	p.frozen = false # the level shows its fail screen from here (cutters -> bob_lost)

	# 8. abort mid-fight (level timeout): everything handed back at once
	var wf3 := _new_fight(3)
	var gun3: Node3D = wf3.gun
	await T.wait(self, WaterFight.INTRO_SECONDS + 0.5)
	wf3.abort()
	await T.wait(self, 0.1)
	_handed_back("aborted", cam_offset0)
	T.check(not is_instance_valid(gun3) or not gun3.is_inside_tree(), "aborted: the gun is gone")
	T.check(not is_instance_valid(wf3.hud), "aborted: the fight HUD is gone")

	for b: Node3D in bosses:
		if is_instance_valid(b):
			b.queue_free()
	lvl.queue_free()
	await process_frame
	T.finish(self)
