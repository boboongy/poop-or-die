extends SceneTree
## The mop with real input, EVERY stall as the clogged one: hold Q (crosshair + circle appear, sprint is blocked), aim the
## screen-centre crosshair at the water in front of the door (the camera must be able to aim there in the narrow corridors),
## a real right-click is one stroke that dries a sixth of the patch. Right-click without Q does nothing, a stroke out of reach
## swings but dries nothing, a second click during a swing is ignored, six clicks dry the patch (checked on 4 stalls).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")
const MopProp := preload("res://scripts/mop_prop.gd")
const Flood := preload("res://scripts/flood.gd")


func _init() -> void:
	seed(24)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # the puddle model on its own (the game's puddles are the flood's leftovers)
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p: CharacterBody3D = lvl.get_node("Player")
	var fl = T.puddle(lvl)
	var mop = lvl.mop
	lvl._time_left = 100000.0 # this test is longer than the level's 70 s: no timeout kick in the middle of it
	var m := MopProp.make_mop()
	lvl.add_child(m)
	mop.give(m)
	await T.wait(self, 0.4)
	# Owner report 2026-09-21: "the moment I grab the mop it disappears". It must stay in Bob's hand, at his side, until Q raises it.
	T.check(mop.owned and mop._pivot.visible and mop.at_rest(), "the mop stays visible in Bob's hand, resting at his side, when Q is not held")
	T.check(lvl.get_node("HUD/CarryLabel").text.begins_with("Carrying: mop"), "the HUD says he carries the mop ('%s')" % lvl.get_node("HUD/CarryLabel").text)

	# right-click without Q does nothing
	fl.start(4)
	fl.advance(21.0)
	var wet_all: int = fl.wet_cells()
	await T.right_click(self)
	await T.wait(self, 0.7)
	T.check(mop.strokes == 0 and fl.wet_cells() == wet_all, "right-click without holding Q does nothing")

	for i in 20:
		fl.start(i)
		fl.advance(21.0)
		var door = lvl.stalls.doors[i]
		var tag := "stall %d (row %d)" % [i % 10 + 1, 1 if i < 10 else 2]
		var sgn := 1.0 if i < 10 else -1.0
		var target := Vector3(door.point.x, 0.0, door.point.z + 0.45 * sgn)
		var from := Vector3(door.point.x, 0.05, door.point.z + 1.3 * sgn)
		await T.key_down(self, KEY_Q)
		var off: float = await T.aim_at(self, p, mop, from, target)
		# (the circle snaps onto the wettest patch near the crosshair, so it need not be exactly where the crosshair points)
		T.check(mop.on_water and off < 0.8, "%s: aiming at the water in front of the door puts the circle on water (crosshair %.2f m from the wanted point)" % [tag, off])
		await T.wait(self, 0.4)
		T.check(mop.is_held() and mop._pivot.visible and not mop.at_rest() and mop._cross.visible, "%s: holding Q raises the mop to the floor in front and shows the crosshair" % tag)
		T.check(p.sprint_blocked, "%s: sprint is blocked while the mop is out" % tag)
		T.check(mop.in_reach and mop._marker.visible, "%s: the circle is on the water and within reach" % tag)
		var before: float = fl.wetness_at(mop.target)
		var wet_start: int = fl.wet_cells()
		Sfx.played.clear()
		var strokes_before: int = mop.strokes
		await T.right_click(self)
		await T.right_click(self) # a second click while the first stroke is still swinging
		await T.wait(self, 0.7)
		T.check(mop.strokes == strokes_before + 1, "%s: one right-click is one stroke; a click during the swing is ignored (%d)" % [tag, mop.strokes - strokes_before])
		var after: float = fl.wetness_at(mop.target)
		T.check(before > 0.99 and absf(after - (before - 1.0 / Flood.STROKES)) < 0.02, "%s: the stroke dried 1/%d (%.2f -> %.2f)" % [tag, Flood.STROKES, before, after])
		T.check(Sfx.count("mop") == 1, "%s: the stroke made its sound (%d)" % [tag, Sfx.count("mop")])
		if i == 0 or i == 9 or i == 10 or i == 19:
			for s in Flood.STROKES - 1:
				await T.wait(self, 0.05)
				await T.right_click(self)
				await T.wait(self, 0.6)
			# (the circle follows the wettest patch, so after each stroke it may move on: check the water that is gone, not one spot)
			T.check(wet_start - fl.wet_cells() >= 8, "%s: %d clicks dried a patch's worth of water (%d -> %d wet cells)" % [tag, Flood.STROKES, wet_start, fl.wet_cells()])
		await T.key_up(self, KEY_Q)
		await T.wait(self, 0.5)
		T.check(mop._pivot.visible and mop.at_rest() and not mop._cross.visible and not p.sprint_blocked, "%s: releasing Q lowers the mop to his side (still visible), hides the crosshair, frees sprint" % tag)

	# far from the water: the circle is clamped to the mop's reach (never out of reach), is red, and a stroke swings but dries nothing
	fl.start(4)
	fl.advance(21.0)
	var door4 = lvl.stalls.doors[4]
	await T.key_down(self, KEY_Q)
	p.global_position = Vector3(door4.point.x + 3.6, 0.05, door4.point.z + 0.9)
	p.face_direction(Vector3(-1.0, 0.0, 0.0))
	p.set_camera(PI / 2.0, -0.15) # looking west, toward the puddle 2.3 m away (its edge is beyond the 1.5 m reach)
	await T.wait(self, 0.4)
	var reach_dist := Vector2(mop.target.x - p.global_position.x, mop.target.z - p.global_position.z).length()
	T.check(mop.target_valid and mop.in_reach and reach_dist <= mop.REACH + 0.01 and not mop.on_water, "the circle is clamped to the reach (%.2f m) with no water under it" % reach_dist)
	T.check(mop._marker_mat.albedo_color.r > 0.9 and mop._marker_mat.albedo_color.g < 0.5, "and it is red")
	var wet_before: int = fl.wet_cells()
	var strokes2: int = mop.strokes
	await T.right_click(self)
	await T.wait(self, 0.7)
	T.check(mop.strokes == strokes2 + 1 and fl.wet_cells() == wet_before, "a stroke on dry floor swings but dries nothing")
	await T.key_up(self, KEY_Q)
	T.finish(self)
