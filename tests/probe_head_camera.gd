extends SceneTree
## Probe (not in the suite): every frame of the toilet sequence, where the REAL camera is relative to Bob's head
## (the spring arm can be shortened by the stall walls; the pivot slides in front of the face in body view),
## whether the head is hidden, and which clip plays. Prints a line whenever the state changes.
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
	var cam: Camera3D = arm.get_node("Camera3D")
	var ap: AnimationPlayer = p.anim()
	var head := sk.find_bone("DEF-spine.006")
	await T.key(self, KEY_E)
	var last := ""
	var tissue_pressed := false
	var flush_pressed := false
	for i in 60 * 22:
		await process_frame
		if not tissue_pressed and prompt.text == "E  grab tissue":
			tissue_pressed = true
			await T.key(self, KEY_E)
		if not flush_pressed and prompt.text == "E  flush":
			flush_pressed = true
			await T.key(self, KEY_E)
		var hidden := sk.get_bone_pose_scale(head).x < 0.5
		var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
		var to_cam := cam.global_position - head_pos
		var fwd: Vector3 = p.model().global_transform.basis.z # models face +Z
		var ahead := to_cam.dot(fwd)
		var state := "%s hidden=%s view=%d" % [ap.current_animation, hidden, p._view]
		var line := "f%4d %-40s spring=%.2f hit=%.2f cam-head=%.2f ahead=%.2f" % [i, state, arm.spring_length, arm.get_hit_length(), to_cam.length(), ahead]
		if state != last or i % 20 == 0 or (hidden and ahead < -0.05):
			print(line)
			last = state
	T.finish(self)
