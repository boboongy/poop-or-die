extends SceneTree
## PROBE (not in the suite): heights of the swim clips (origin = the WATER SURFACE, bob_godot_notes.md "Swim clips") and, for
## comparison, the floor-origin idle. Prints per clip the min/max over 24 samples of the head bone, the top of the head (head bone
## + HEAD_TOP), the hands and the feet, all relative to the model origin. Also Bob's right hand in tissue_grab at the notes' frames.
##   timeout 120 "<console exe>" --headless --path . --script tests/probe_swim_clips.gd

const HEAD_TOP := 0.25 ## m above DEF-spine.006 to the crown (rough: printed so a reader can judge)
const BONES := {"head": "DEF-spine.006", "hand_r": "DEF-hand.R", "hand_l": "DEF-hand.L", "foot_l": "DEF-foot.L", "foot_r": "DEF-foot.R", "hips": "DEF-spine"}


func _init() -> void:
	for who in ["bob", "jijio"]:
		var scene: PackedScene = load("res://assets/characters/%s-character/%s.glb" % [who, who])
		var root: Node3D = scene.instantiate()
		get_root().add_child.call_deferred(root)
		await process_frame
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		print("== ", who)
		for clip in ["idle", "swim", "tread_water", "float", "swim_panic", "duck_dive", "swim_under"]:
			if not ap.has_animation(clip):
				continue
			var mins := {}
			var maxs := {}
			var length := ap.get_animation(clip).length
			for k in 24:
				ap.play(clip)
				ap.seek(length * k / 24.0, true)
				skel.force_update_all_bone_transforms()
				for key: String in BONES:
					var i := skel.find_bone(BONES[key])
					if i < 0:
						continue
					var y: float = (root.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(i)).origin.y
					mins[key] = minf(mins.get(key, INF), y)
					maxs[key] = maxf(maxs.get(key, -INF), y)
			var line := "  %-12s" % clip
			for key: String in BONES:
				if mins.has(key):
					line += " %s %.2f..%.2f" % [key, mins[key], maxs[key]]
			line += " | crown max %.2f" % (float(maxs["head"]) + HEAD_TOP)
			print(line)
		if who == "bob":
			var hr := skel.find_bone("DEF-hand.R")
			for f in [0, 16, 22, 30, 38, 40, 44, 60, 72, 89]:
				ap.play("tissue_grab")
				ap.seek(f / 30.0, true)
				skel.force_update_all_bone_transforms()
				var at: Vector3 = (root.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(hr)).origin
				print("  tissue_grab f%d hand.R %s" % [f, at])
		root.queue_free()
		await process_frame
	quit()
