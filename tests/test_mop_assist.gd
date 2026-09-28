extends SceneTree
## Owner, 2026-09-21: "can't finish in time ... make controlling the mop easier". The mop now helps the player:
##  1. NO camera tilt needed: face the water (yaw only, the normal third-person pitch) and the circle is on it. The circle is clamped to
##     the mop's reach along the look direction instead of going out of reach when the crosshair is far away.
##  2. The circle snaps onto the wettest patch near the crosshair (within SNAP_RADIUS), and is green only when it is on water.
##  3. HOLD right-click to keep mopping (a stroke every 0.4 s); a single click is still one stroke.
## Checked for EVERY water source: the 20 clogged stalls and the 10 overflowing sinks.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Flood := preload("res://scripts/flood.gd")
const MopProp := preload("res://scripts/mop_prop.gd")
const NORMAL_PITCH := -0.15 ## the game's default camera pitch: nobody tilts it down


func _init() -> void:
	seed(81)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # the puddle model on its own (the game's puddles are the flood's leftovers)
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.get_node("Player")
	var fl = T.puddle(lvl)
	var mop = lvl.mop
	var m := MopProp.make_mop()
	lvl.add_child(m)
	mop.give(m)
	await T.key_down(self, KEY_Q)
	for i in 30: # the 20 clogged stalls, then the 10 overflowing sinks
		if i < 20:
			fl.start(i)
		else:
			fl.start_sink(i - 19)
		fl.advance(21.0)
		var tag: String = fl.label()
		# Bob stands 1.1 m from the source in the corridor, facing it, camera at the normal pitch
		var from := Vector3(fl.source.x, 0.05, fl.source.z + 1.1 * fl.dir)
		p.global_position = from
		var yaw := 0.0 if fl.dir > 0.0 else PI # yaw 0 looks toward -Z
		p.face_direction(Vector3(0.0, 0.0, -fl.dir))
		p.set_camera(yaw, NORMAL_PITCH)
		await T.wait(self, 0.4)
		T.check(mop.target_valid and mop.in_reach and mop.on_water, "%s: at the normal camera pitch the circle is on the water within reach (on water %s, %.2f m from Bob)" % [tag, mop.on_water, Vector2(mop.target.x - p.global_position.x, mop.target.z - p.global_position.z).length()])
		T.check(mop._marker.visible and mop._marker_mat.albedo_color.g > 0.9, "%s: the circle is shown, green" % tag)
		# a click there really mops
		var before: float = fl.wetness_at(mop.target)
		await T.right_click(self)
		await T.wait(self, 0.6)
		T.check(before > 0.99 and fl.wetness_at(mop.target) < before - 0.2, "%s: one click dried a quarter (%.2f -> %.2f)" % [tag, before, fl.wetness_at(mop.target)])

	# far from any water: the circle stays within reach (clamped), is not green, and a stroke dries nothing
	fl.start(4)
	fl.advance(21.0)
	p.global_position = Vector3(fl.source.x + 3.5, 0.05, 0.0)
	p.face_direction(Vector3(1.0, 0.0, 0.0))
	p.set_camera(-PI / 2.0, NORMAL_PITCH) # looking east, away from the water
	await T.wait(self, 0.4)
	var reach_dist := Vector2(mop.target.x - p.global_position.x, mop.target.z - p.global_position.z).length()
	T.check(mop.target_valid and reach_dist <= mop.REACH + 0.01 and not mop.on_water, "far from the water the circle is clamped to the mop's reach (%.2f m) and has no water under it" % reach_dist)
	T.check(mop._marker_mat.albedo_color.r > 0.9, "and it is red")
	var cells: int = fl.wet_cells()
	await T.right_click(self)
	await T.wait(self, 0.6)
	T.check(fl.wet_cells() == cells, "a stroke on dry floor dries nothing")
	# looking straight up: the circle goes 1 m ahead instead of vanishing
	p.set_camera(-PI / 2.0, 0.45)
	await T.wait(self, 0.3)
	var ahead := Vector2(mop.target.x - p.global_position.x, mop.target.z - p.global_position.z)
	T.check(mop.target_valid and absf(ahead.length() - 1.0) < 0.15 and ahead.x > 0.7, "looking up, the circle is about 1 m ahead of Bob (%.2f m)" % ahead.length())

	# the circle snaps onto water the crosshair only just misses (0.5 m beside the puddle)
	fl.start(4)
	fl.advance(21.0)
	var edge_x: float = fl.source.x + 1.25 + 0.45 # 0.45 m beyond the last wet cell along the corridor
	p.global_position = Vector3(edge_x + 0.5, 0.05, fl.source.z + 0.6)
	p.face_direction(Vector3(-1.0, 0.0, 0.0))
	p.set_camera(PI / 2.0, NORMAL_PITCH)
	await T.wait(self, 0.4)
	T.check(mop.on_water and mop.in_reach, "aiming just beside the puddle, the circle snaps onto the water (on water %s)" % mop.on_water)

	# hold right-click: strokes keep coming; a plain click is one stroke
	p.global_position = Vector3(fl.source.x, 0.05, fl.source.z + 1.1)
	p.face_direction(Vector3(0.0, 0.0, -1.0))
	p.set_camera(0.0, NORMAL_PITCH)
	await T.wait(self, 0.4)
	var strokes_before: int = mop.strokes
	await T.right_click(self)
	await T.wait(self, 0.7)
	T.check(mop.strokes == strokes_before + 1, "a plain click is exactly one stroke (%d)" % (mop.strokes - strokes_before))
	strokes_before = mop.strokes
	var wet_before: int = fl.wet_cells()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	down.position = root.get_visible_rect().size / 2.0
	Input.parse_input_event(down)
	await T.wait(self, 2.0)
	var during: int = mop.strokes - strokes_before
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = down.position
	Input.parse_input_event(up)
	await T.wait(self, 0.3)
	var after_release: int = mop.strokes
	await T.wait(self, 1.0)
	T.check(during >= 4 and during <= 6, "holding right-click for 2 s made %d strokes (about one every 0.4 s)" % during)
	T.check(fl.wet_cells() < wet_before, "and they dried water (%d -> %d wet cells)" % [wet_before, fl.wet_cells()])
	T.check(mop.strokes == after_release, "letting go stops the strokes")
	await T.key_up(self, KEY_Q)
	# without Q, holding right-click does nothing
	var s2: int = mop.strokes
	Input.parse_input_event(down)
	await T.wait(self, 1.0)
	Input.parse_input_event(up)
	T.check(mop.strokes == s2, "holding right-click without Q does not mop")
	T.finish(self)
