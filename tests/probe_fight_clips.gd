extends SceneTree
## PROBE (not run by run.sh): Bob's hand and foot positions (model space: +Z = his front, +Y up) through every attack clip,
## to check where each contact really points and to find a fists-up frame for the placeholder guard.
const CLIPS := ["punch", "punch_combo", "kick", "uppercut", "hook_right", "kick_double", "kick_spin"]
const BONES := ["DEF-hand.L", "DEF-hand.R", "DEF-foot.L", "DEF-foot.R", "DEF-spine.006"]


func _init() -> void:
	var bob: Node3D = load("res://assets/characters/bob-character/bob.glb").instantiate()
	get_root().add_child(bob)
	await process_frame
	var ap: AnimationPlayer = bob.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = bob.find_children("*", "Skeleton3D", true, false)[0]
	var names: Array = []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.contains("hand") or n.contains("foot"):
			names.append(n)
	print("hand/foot bones: ", names)
	var to_model: Transform3D = bob.global_transform.affine_inverse() * sk.global_transform
	for clip: String in CLIPS:
		var a := ap.get_animation(clip)
		var frames := int(round(a.length * 30.0))
		print("== ", clip, " (", frames, " f)")
		ap.play(clip)
		for fr in range(0, frames + 1, 2):
			ap.seek(fr / 30.0, true)
			var line := "f%02d" % fr
			for b: String in BONES:
				var i := sk.find_bone(b)
				if i < 0:
					line += "  %s ?" % b
					continue
				var p: Vector3 = to_model * sk.get_bone_global_pose(i).origin
				line += "  %s y%.2f z%+.2f" % [b.replace("DEF-", ""), p.y, p.z]
			print(line)
	quit()
