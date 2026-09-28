extends SceneTree
## Invariant for the first-person switch, sampled on EVERY frame of the toilet sequence:
##   - Bob's head is never hidden while the camera is far from him (no headless Bob in third person)
##   - his head is always hidden while the camera sits at his eyes in body view.
## (This bug was reported twice, once for each direction of the switch.)
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var p = lvl.get_node("Player")
	var pop: Node3D = lvl.get_node("Population")
	var sess = lvl.get_node("ToiletSession")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	sess.poop_seconds = 0.3
	await pop.reward_release(4)
	sess.setup(4)
	p.global_position = sess._stand_spot() + Vector3(0, 0, 0.9)
	p.face_direction(Vector3(0, 0, -1))
	await T.wait(self, 0.3)
	var sk: Skeleton3D = Pose.skeleton_of(p.model())
	var arm: SpringArm3D = p.get_node("CameraPivot/SpringArm3D")
	var head := sk.find_bone("DEF-spine.006")
	var cam: Camera3D = arm.get_node("Camera3D")
	await T.key(self, KEY_E) # use the toilet: pants_down starts the first-person stretch
	var headless_far := 0
	var behind_hidden := 0
	var worst_behind := 0.0
	var head_at_eyes := 0
	var fp_frames := 0
	var tissue_pressed := false
	var flush_pressed := false
	for i in 60 * 22: # long enough for the whole sequence: pants_down, sit_down, sit, tissue_grab, wipe, press_flush, the flush video
		await physics_frame
		if not tissue_pressed and prompt.text == "E  grab tissue":
			tissue_pressed = true
			await T.key(self, KEY_E)
		if not flush_pressed and prompt.text == "E  flush":
			flush_pressed = true
			await T.key(self, KEY_E)
		var hidden := sk.get_bone_pose_scale(head).x < 0.5
		if hidden and arm.spring_length > 0.45:
			headless_far += 1
		# Owner 2026-09-25 "headless for a second when he sits down": the REAL camera, not the spring length. A hidden
		# head is only fine while the camera is in front of the face; pants_down bent him forward, leaving the camera
		# 0.4-0.6 m BEHIND the hidden head for about 1.5 s.
		if hidden:
			var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
			var to_cam := cam.global_position - head_pos
			var ahead := to_cam.dot(p.model().global_transform.basis.z) # models face +Z
			if ahead < -0.05 and to_cam.length() > 0.2:
				behind_hidden += 1
				worst_behind = maxf(worst_behind, -ahead)
		if p._view == 2 and arm.spring_length < 0.05:
			fp_frames += 1
			if not hidden:
				head_at_eyes += 1
	T.check(tissue_pressed and flush_pressed, "both the tissue and flush prompts appeared and were pressed within the sample window")
	T.check(fp_frames > 60, "the sequence had first-person body-view frames (%d)" % fp_frames)
	T.check(headless_far == 0, "no headless frame with the camera far away (%d)" % headless_far)
	T.check(behind_hidden == 0, "the camera is never behind the hidden head (%d frames, worst %.2f m behind)" % [behind_hidden, worst_behind])
	T.check(head_at_eyes == 0, "no visible-head frame with the camera at his eyes (%d)" % head_at_eyes)
	T.check(sk.get_bone_pose_scale(head).x > 0.9, "head restored at the end")
	T.finish(self)
