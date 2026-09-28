extends SceneTree
## The factory tissue props (SPEC Stage 6 Slice A, tissue-props_godot_notes.md) through the REAL toilet sequence on EVERY stall of one
## row (`-- row1` / `-- row2`, both in run.sh). Per stall:
## - the holder is on the stall wall at Bob's right (notes: TISSUE_MOUNT in his seated frame, 0.75 m high), its front into the stall,
##   ON the wall (a ray from the stall hits the wall within 3 cm behind the mount), not floating or inside it;
## - tissue_grab frames 22-38: the pulled paper reaches Bob's right hand (its end within 3 cm) and the roll spins;
## - frame 40: the paper tears (a `tear` sound), the long tail is gone;
## - from frame 44 until the wipe ends the folded sheet is shown in his right hand (within 12 cm of the hand bone);
## - after the wipe the sheet drops into the bowl and is hidden within 1 s.
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _init() -> void:
	var row := 2 if OS.get_cmdline_user_args().has("row2") else 1
	var ok := 0
	for k in 10:
		var stall := (row - 1) * 10 + k
		var lvl := T.level(self)
		await T.wait(self, 0.5)
		lvl._time_left = 100000.0
		var p = lvl.get_node("Player")
		var pop: Node3D = lvl.get_node("Population")
		var sess = lvl.get_node("ToiletSession")
		var prompt: Label = lvl.get_node("HUD/PromptLabel")
		sess.poop_seconds = 0.3
		await pop.reward_release(stall)
		sess.setup(stall)
		var tag := "stall %d (row %d)" % [k + 1, row]
		# where the holder is
		var holder: Node3D = sess.tissue_holder
		var right: Vector3 = sess._forward.cross(Vector3.UP)
		var want: Vector3 = sess._seat_spot() + Basis(Vector3.UP, atan2(sess._forward.x, sess._forward.z)) * sess.TISSUE_MOUNT
		var placed := holder != null and holder.global_position.distance_to(want) < 0.02 and holder.global_basis.z.normalized().dot(-right) > 0.95
		var q := PhysicsRayQueryParameters3D.create(Vector3(want.x, want.y, want.z) - right * 0.3, want + right * 0.3)
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		var wall_gap: float = (hit["position"] as Vector3).distance_to(want) if not hit.is_empty() else 99.0
		p.global_position = sess._stand_spot() + sess._forward * 0.9
		p.face_direction(-sess._forward)
		await T.wait(self, 0.3)
		var sk: Skeleton3D = Pose.skeleton_of(p.model())
		var ap: AnimationPlayer = p.anim()
		var tears_before := Sfx.count("tear")
		await T.key(self, KEY_E)
		var pull_frames := 0
		var pull_worst := 0.0
		var reach_gap := 99.0
		var roll_start := Basis()
		var roll_turned := 0.0
		var tail_after_tear := 0
		var sheet_frames := 0
		var sheet_missing := 0
		var sheet_worst := 0.0
		var seen_wipe := false
		var after_wipe := 0.0
		var hidden_after := false
		var tissue_pressed := false
		for i in 60 * 16:
			await process_frame
			if not tissue_pressed and prompt.text == "E  grab tissue":
				tissue_pressed = true
				await T.key(self, KEY_E)
			var hand: Vector3 = T.bone_at(p.model(), "DEF-hand.R")
			var clip := String(ap.current_animation) if ap.is_playing() else ""
			var f := ap.current_animation_position * 30.0
			if clip == "tissue_grab":
				if f >= 23.0 and f < 37.0:
					pull_frames += 1
					if pull_frames == 1:
						roll_start = sess._roll.global_basis
						# the grab itself: the hand is ON the hanging (unstretched) tail, so the paper does not jump to it
						var top: Vector3 = sess.tissue_holder.global_transform * sess._tail_rest.origin
						var bottom: Vector3 = sess.tissue_holder.global_transform * (sess._tail_rest * Vector3(0.0, -sess.TAIL_REST, 0.0))
						reach_gap = Geometry3D.get_closest_point_to_segment(hand, top, bottom).distance_to(hand)
					var tail_end: Vector3 = sess._tail.global_transform * Vector3(0.0, -sess.TAIL_REST, 0.0)
					pull_worst = maxf(pull_worst, tail_end.distance_to(hand))
					roll_turned = maxf(roll_turned, roll_start.get_rotation_quaternion().angle_to(sess._roll.global_basis.get_rotation_quaternion()))
				if f >= 41.0 and sess._tail.global_transform.basis.y.length() > 0.6:
					tail_after_tear += 1 # still the long pulled tail after the tear
			if (clip == "tissue_grab" and f >= 45.0) or clip == "wipe":
				sheet_frames += 1
				if not sess.sheet.is_visible_in_tree():
					sheet_missing += 1
				else:
					sheet_worst = maxf(sheet_worst, sess.sheet.global_position.distance_to(hand))
			if clip == "wipe":
				seen_wipe = true
			elif seen_wipe:
				after_wipe += 1.0 / 60.0
				if not sess.sheet.is_visible_in_tree():
					hidden_after = true
					break
				if after_wipe > 1.0:
					break
		var torn := Sfx.count("tear") - tears_before
		T.check(placed and wall_gap < 0.03, "%s: the holder is on the wall at Bob's right, 0.75 m high, facing into the stall (placed %s, wall %.3f m behind the mount)" % [tag, placed, wall_gap])
		T.check(reach_gap < 0.05, "%s: at the grab his hand is on the hanging paper (%.3f m from it)" % [tag, reach_gap])
		T.check(pull_frames > 10 and pull_worst < 0.03 and roll_turned > 0.5, "%s: frames 22-38 the paper follows his hand (worst %.3f m over %d frames), the roll turns %.1f rad" % [tag, pull_worst, pull_frames, roll_turned])
		T.check(torn == 1 and tail_after_tear == 0, "%s: it tears once at frame 40 (%d tear sounds, %d frames still long after)" % [tag, torn, tail_after_tear])
		T.check(sheet_frames > 150 and sheet_missing == 0 and sheet_worst < 0.12, "%s: the sheet is in his hand from frame 44 to the end of the wipe (%d frames, %d missing, worst %.3f m from the hand)" % [tag, sheet_frames, sheet_missing, sheet_worst])
		T.check(hidden_after, "%s: after the wipe the sheet goes into the bowl (hidden after %.2f s)" % [tag, after_wipe])
		sess.abort()
		lvl.queue_free()
		await process_frame
		await physics_frame
	T.finish(self)
