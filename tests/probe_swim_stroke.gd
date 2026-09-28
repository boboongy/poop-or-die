extends SceneTree
## PROBE (not in the suite): when each hand of Bob's `swim` clip enters the water (its height crosses the surface, y = 0 at the clip
## origin, going down). Stage 6 syncs the stroke splash to these phases (player.gd SWIM_SPLASH_PHASES).
##   timeout 120 "<console exe>" --headless --path . --script tests/probe_swim_stroke.gd

const STEPS := 120


func _init() -> void:
	var scene: PackedScene = load("res://assets/characters/bob-character/bob.glb")
	var root: Node3D = scene.instantiate()
	get_root().add_child.call_deferred(root)
	await process_frame
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var length := ap.get_animation("swim").length
	print("swim length %.3f s" % length)
	for bone in ["DEF-hand.L", "DEF-hand.R"]:
		var i := skel.find_bone(bone)
		var ys: Array[float] = []
		for k in STEPS:
			ap.play("swim")
			ap.seek(length * k / STEPS, true)
			skel.force_update_all_bone_transforms()
			ys.append((root.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(i)).origin.y)
		var lo: float = ys.min()
		var hi: float = ys.max()
		# 2026-09-28: the hands never break the surface (-0.23..-0.04 m), so the stroke = each hand's highest point (a local maximum)
		var line := "%s y %.2f..%.2f, highest at phase:" % [bone, lo, hi]
		for k in STEPS:
			if ys[k] >= ys[(k + STEPS - 1) % STEPS] and ys[k] > ys[(k + 1) % STEPS]:
				line += " %.3f (%.2f m)" % [float(k) / STEPS, ys[k]]
		print(line)
	root.queue_free()
	await process_frame
	quit()
