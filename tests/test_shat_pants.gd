extends SceneTree
## Stage 6d (DECIDED 2026-09-28): EVERY loss = a brown patch spreads on the seat of Bob's shorts in 1.5 s with a wet squelch, a 1 s cut to
## behind Bob, the patch stays until R. Here: the timeout kick-out (Level 1), caught in hide-and-seek (Level 2), the fight K.O. (Level 4);
## the lost dance battle is checked in test_dance_battle. Also: no patch before a loss, the shared shorts material is untouched, R clears it.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Shat := preload("res://scripts/shat_stain.gd")


func _init() -> void:
	seed(3)
	T.check(is_equal_approx(Shat.SPREAD_SECONDS, 1.5) and is_equal_approx(Shat.CUT_SECONDS, 1.0), "spreads in 1.5 s, the cut lasts 1 s (DECIDED)")
	await _loss("timeout", 1)
	await _loss("caught", T.HIDE_LEVEL)
	await _loss("ko", 4)
	T.finish(self)


func _loss(kind: String, level_no: int) -> void:
	Progress.level = level_no
	var lvl := T.level(self)
	current_scene = lvl
	await T.wait(self, 0.8)
	var p: CharacterBody3D = lvl.player
	var shorts: MeshInstance3D = p.find_child("Bob_Shorts", true, false)
	var shared_mat: Material = shorts.get_active_material(0)
	T.check(not lvl.shat_stain.is_shat() and shorts.material_overlay == null, "%s: clean shorts before the loss" % kind)
	var squelch := Sfx.count("shat")
	match kind:
		"timeout":
			lvl._time_left = 0.2
		"caught":
			lvl._time_left = 100000.0
			lvl.hide_seek.hide_seconds = 1.0
			p.global_position = Vector3(6.0, 0.05, 0.05) # in the open corridor: found
		"ko":
			lvl._time_left = 100000.0
			lvl.cutters.bob_lost.emit()
	await T.wait_for(self, func() -> bool: return lvl.shat_stain.is_shat(), 60.0)
	T.check(lvl._game_over and lvl.shat_stain.is_shat(), "%s: the loss shows the patch" % kind)
	T.check(Sfx.count("shat") == squelch + 1, "%s: one wet squelch" % kind)
	await T.wait(self, 0.2)
	var early: float = lvl.shat_stain.spread()
	T.check(early > 0.02 and early < 0.8, "%s: it spreads (%.2f after 0.2 s)" % [kind, early])
	await T.wait(self, 0.4)
	var cam := get_root().get_camera_3d()
	T.check(cam == lvl.shat_stain.cut_camera and cam != null, "%s: the camera cuts to behind Bob" % kind)
	if cam != null:
		var to_cam := cam.global_position - p.global_position
		var facing: Vector3 = p.model().global_transform.basis.z
		to_cam.y = 0.0
		facing.y = 0.0
		T.check(to_cam.normalized().dot(facing.normalized()) < -0.5, "%s: the cut camera is BEHIND him (dot %.2f)" % [kind, to_cam.normalized().dot(facing.normalized())])
		var seat := p.global_position + Vector3.UP * 0.42
		# the seat in view, in the lower part of the frame (the result text is in the middle): its screen y past 60 % of the height
		var sy: float = cam.unproject_position(seat).y / cam.get_viewport().get_visible_rect().size.y
		T.check(cam.is_position_in_frustum(seat) and sy > 0.6 and sy < 0.95, "%s: the seat of his shorts is in view, under the result text (at %.0f %% of the height)" % [kind, sy * 100.0])
	await T.wait(self, 1.2)
	T.check(is_equal_approx(lvl.shat_stain.spread(), 1.0), "%s: the full patch after 1.5 s (%.2f)" % [kind, lvl.shat_stain.spread()])
	T.check(get_root().get_camera_3d() != lvl.shat_stain.cut_camera and get_root().get_camera_3d() != null, "%s: after 1 s the view is back" % kind)
	T.check(shorts.get_active_material(0) == shared_mat and shorts.material_overlay != null, "%s: an overlay on Bob's own shorts, the shared material untouched" % kind)
	var arr := shorts.mesh.surface_get_arrays(0)
	T.check(arr[Mesh.ARRAY_COLOR] != null and shorts.mesh.get_blend_shape_count() == 2 and shorts.skin != null, "%s: the shorts copy keeps its 2 blend shapes and skin, with the rest-position colours" % kind)
	await T.wait(self, 3.0)
	T.check(is_equal_approx(lvl.shat_stain.spread(), 1.0), "%s: the patch stays" % kind)
	if kind == "timeout": # R = try again: a fresh level, clean shorts
		await T.key(self, KEY_R)
		await T.wait(self, 0.8)
		var fresh: Node = current_scene
		T.check(fresh != lvl and not fresh.shat_stain.is_shat() and fresh.player.find_child("Bob_Shorts", true, false).material_overlay == null, "R clears the patch")
		fresh.queue_free()
	else:
		lvl.queue_free()
	await process_frame
