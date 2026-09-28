extends SceneTree
## Owner 2026-09-25 (Level 5): "during her turn move the camera to point at her with Bob still in frame for a few seconds, then shift back to
## the original; the same on Bob's turn, pointing at Bob with her in frame." One stall per row, walkers on (they join the ring).
## Sampled every frame of round 1: in the middle of HER turn the camera is at least FOCUS_GAIN m closer to her than the home shot, both
## dancers' heads and hips are on screen and no crowd body stands on the line of sight to either; before her turn ends it is back home;
## the same for Bob's turn (closer to Bob). Written before the camera code.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")

const FOCUS_GAIN := 0.5
const BODY_RADIUS := 0.28 ## a crowd Jijio's half-width at chest height
const Pose := preload("res://scripts/pose.gd")
const DanceHud := preload("res://scripts/dance_hud.gd")
const GAME_W := 1152.0
const GAME_ASPECT := 1152.0 / 648.0
const SCREEN_MARGIN := 0.95


func _init() -> void:
	seed(5)
	Dance.test_aspect = GAME_ASPECT
	Progress.level = 5
	for stall in [6, 13]:
		Dance.force_stall = stall
		var lvl := T.level(self, true)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		await _to_challenge(lvl)
		await _check(lvl, stall)
		lvl.queue_free()
		await process_frame
		await physics_frame
	Dance.force_stall = -1
	Dance.test_aspect = 0.0
	T.finish(self)


func _to_challenge(lvl: Node) -> void:
	var p: CharacterBody3D = lvl.player
	var d: Node = lvl.dance
	lvl.population.queue[4].interact(p)
	await T.wait(self, 0.2)
	for k in [KEY_1, KEY_E, KEY_E]:
		await T.key(self, k)
		await T.wait(self, 0.1)
	var at: Vector3 = d.queen.global_position + d.out * 0.9
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-d.out)
	await T.wait(self, 0.2)
	d.queen.interact(p)
	await T.wait(self, 0.2)
	await T.key(self, KEY_3)
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)


## On screen in the GAME's window: headless windows are square (1152 x 1152, and resizing is ignored) while the game's is 1152 x 648
## (16:9, stretch "expand"); the camera keeps the HEIGHT, so `is_position_in_frustum` here would be 16 deg narrower each side than what
## the player sees. A point counts when it is inside the frame by SCREEN_MARGIN AND right of the arrow-lane panel (DanceHud.lanes_right,
## 356 px of 1152): the first screenshot showed Bob "in frame" on her turn but half under the panel.
func _on_screen(cam: Camera3D, pt: Vector3) -> bool:
	var local := cam.global_transform.affine_inverse() * pt
	if local.z >= -0.05:
		return false
	var half_h := tan(deg_to_rad(cam.fov) / 2.0)
	var nx := local.x / -local.z / (half_h * GAME_ASPECT) # -1 left edge .. +1 right edge
	var ny := local.y / -local.z / half_h
	var px := (nx + 1.0) * 0.5 * GAME_W
	return absf(ny) <= SCREEN_MARGIN and nx <= SCREEN_MARGIN and px >= DanceHud.lanes_right()


## A dancer's face (the head bone DEF-spine.006, 0.15 m up: the bone sits at the jaw, about 0.82 m for Bob) and hips, following the dance
## moves (the first version used fixed heights of 1.45 / 0.8 m: above both heads).
func _points(body: Node3D) -> Array:
	var sk := Pose.skeleton_of(body.get_node("Model"))
	var i := sk.find_bone("DEF-spine.006") if sk else -1
	var head := body.global_position + Vector3.UP * 0.95
	if i >= 0:
		head = (sk.global_transform * sk.get_bone_global_pose(i).origin) + Vector3.UP * 0.15
	return [head, body.global_position + Vector3.UP * 0.45]


## The nearest crowd body (other than the dancers) to the segment camera -> point, measured at the height where the segment passes.
func _blocked(d: Node, cam: Camera3D, point: Vector3) -> bool:
	var a := cam.global_position
	for npc: Node3D in d.crowd:
		if not is_instance_valid(npc) or npc == d.queen:
			continue
		var c := npc.global_position
		var ab := point - a
		var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		if q.y < c.y + 0.3 or q.y > c.y + 1.7: # the sight line passes over or under this body there
			continue
		if Vector2(q.x - c.x, q.z - c.z).length() < BODY_RADIUS:
			return true
	return false


func _check(lvl: Node, stall: int) -> void:
	var d: Node = lvl.dance
	var p: Node3D = lvl.player
	var row := "stall %d row %d" % [stall % 10 + 1, 1 if stall < 10 else 2]
	await T.wait_for(self, func() -> bool: return d.battle != null and d.battle.phase == "intro", 20.0)
	var cam: Camera3D = d.camera
	var home := cam.global_position
	var home_to_queen := home.distance_to(d.queen.global_position)
	var home_to_bob := home.distance_to(p.global_position)
	var closest := {"queen": 99.0, "bob": 99.0}
	var off_screen := {"queen": 0, "bob": 0}
	var blocked := {"queen": 0, "bob": 0}
	var home_at_end := {"queen": false, "bob": false}
	var away := {"queen": 0, "bob": 0} ## frames the camera was more than 0.5 m from home
	var partner_nearer := {"queen": 0, "bob": 0} ## of those, frames the OTHER dancer was the nearer one
	var last_phase := ""
	var last_home_gap := 0.0
	for i in 60 * 14:
		await process_frame
		var ph: String = d.battle.phase
		if ph != last_phase:
			if last_phase in ["queen", "bob"]:
				home_at_end[last_phase] = last_home_gap < 0.05
			last_phase = ph
		if d.battle.round_number > 1 or ph == "over":
			break
		last_home_gap = cam.global_position.distance_to(home)
		if ph == "queen" or ph == "bob":
			var target: Node3D = d.queen if ph == "queen" else p
			closest[ph] = minf(closest[ph], cam.global_position.distance_to(target.global_position))
			var other: Node3D = p if ph == "queen" else d.queen
			if last_home_gap > 0.5:
				away[ph] += 1
				if cam.global_position.distance_to(target.global_position) >= cam.global_position.distance_to(other.global_position):
					partner_nearer[ph] += 1
			for body: Node3D in [d.queen, p]:
				for pt: Vector3 in _points(body):
					if not _on_screen(cam, pt):
						if off_screen[ph] == 0:
							print("INFO  %s: %s turn, first point off screen: %s at %s, camera-space %s, cam %s" % [row, ph,
									"Bob" if body == p else "her", pt, cam.global_transform.affine_inverse() * pt, cam.global_position])
						off_screen[ph] += 1
					elif _blocked(d, cam, pt):
						blocked[ph] += 1
	T.check(closest["queen"] < home_to_queen - FOCUS_GAIN, "%s: her turn, the camera moves in on her (%.2f m, home %.2f m)" % [row, closest["queen"], home_to_queen])
	T.check(closest["bob"] < home_to_bob - FOCUS_GAIN, "%s: Bob's turn, the camera moves in on Bob (%.2f m, home %.2f m)" % [row, closest["bob"], home_to_bob])
	for ph in ["queen", "bob"]:
		T.check(off_screen[ph] == 0, "%s: %s turn, both dancers' faces and hips stay on screen, right of the arrow lanes (%d point-frames off)" % [row, ph, off_screen[ph]])
		T.check(blocked[ph] == 0, "%s: %s turn, no crowd body blocks either dancer (%d point-frames)" % [row, ph, blocked[ph]])
		T.check(away[ph] > 30 and partner_nearer[ph] == 0, "%s: %s turn, whoever dances is nearer the camera than the partner (%d of %d frames away from home)" % [row, ph, partner_nearer[ph], away[ph]])
		T.check(home_at_end[ph],"%s: %s turn, the camera is back home before the turn ends" % [row, ph])
