extends SceneTree
## Owner 2026-09-25: "the wiping animation should be third person instead of first". The code already asked for the third-person
## view, but a stall is 0.95 m wide: the spring arm can be shortened by the walls until the camera sits in his head, which looks
## like first person. On EVERY stall of one row (`-- row1` / `-- row2`, both in run.sh), through the real toilet sequence:
## during the whole `wipe` clip the REAL camera must stay at least WIPE_MIN m from his head and the head must be shown.
## Prints each stall's closest distance.
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")

const WIPE_MIN := 1.2


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
		p.global_position = sess._stand_spot() + sess._forward * 0.9
		p.face_direction(-sess._forward)
		await T.wait(self, 0.3)
		var sk: Skeleton3D = Pose.skeleton_of(p.model())
		var cam: Camera3D = p.get_node("CameraPivot/SpringArm3D/Camera3D")
		var ap: AnimationPlayer = p.anim()
		var head := sk.find_bone("DEF-spine.006")
		await T.key(self, KEY_E)
		var closest := 99.0
		var wipe_frames := 0
		var seen_wipe := false
		var hidden_frames := 0
		var tissue_pressed := false
		for i in 60 * 14:
			await process_frame
			if not tissue_pressed and prompt.text == "E  grab tissue":
				tissue_pressed = true
				await T.key(self, KEY_E)
			# The owner's "wiping" is the tissue grab (tearing and folding the paper, 3 s, was first person staring at the
			# stall wall: screenshots 2026-09-25) AND the wipe: both are seen from the doorway now.
			if ap.current_animation == "wipe" or ap.current_animation == "tissue_grab":
				wipe_frames += 1
				var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
				# the first 0.35 s of the grab is the switch from the seated view
				if ap.current_animation == "wipe" or ap.current_animation_position > 0.35:
					closest = minf(closest, cam.global_position.distance_to(head_pos))
					if sk.get_bone_pose_scale(head).x < 0.5:
						hidden_frames += 1
				if ap.current_animation == "wipe":
					seen_wipe = true
			elif seen_wipe:
				break
		var good := wipe_frames > 250 and closest >= WIPE_MIN and hidden_frames == 0
		T.check(good, "stall %d (row %d): wipe seen from %.2f m at the closest (%d wipe frames, %d with the head hidden)" % [k + 1, row, closest, wipe_frames, hidden_frames])
		if good:
			ok += 1
		sess.abort()
		lvl.queue_free()
		await process_frame
		await physics_frame
	print("INFO  row %d: %d of 10 stalls show the wipe in third person" % [row, ok])
	T.finish(self)
