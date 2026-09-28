extends SceneTree
## PROBE (not a test, not in run.sh): how far the factory `talk` clip turns the head and chest to the LEFT (bob/jijio_godot_notes.md: "chest
## and head turned a little that way"), so a talking pair can each turn right by that much and look at each other (Stage 6b E).
##   timeout 120 "<console exe>" --headless --path . --fixed-fps 60 --script tests/probe_talk_clip.gd

const Pose := preload("res://scripts/pose.gd")


func _init() -> void:
	for path in ["res://assets/characters/bob-character/bob.glb", "res://assets/characters/jijio-character/jijio.glb"]:
		var root: Node3D = (load(path) as PackedScene).instantiate()
		get_root().add_child(root)
		await process_frame
		var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
		var sk := Pose.skeleton_of(root)
		print(path.get_file(), " has talk: ", ap.has_animation("talk"), "  length ", ap.get_animation("talk").length if ap.has_animation("talk") else 0.0)
		for bone in ["DEF-spine.006", "DEF-spine.003"]:
			var i := sk.find_bone(bone)
			var yaws: Array[float] = []
			for anim_name in ["idle", "talk"]:
				ap.play(anim_name)
				var sum := 0.0
				var lo := INF
				var hi := -INF
				var n := 30
				for k in n:
					ap.seek(ap.get_animation(anim_name).length * k / n, true)
					var b: Basis = sk.get_bone_global_pose(i).basis # skeleton space = the model's own space (front +Z)
					var fwd := b.z
					fwd.y = 0.0
					var yaw := rad_to_deg(atan2(fwd.x, fwd.z))
					sum += yaw
					lo = minf(lo, yaw)
					hi = maxf(hi, yaw)
				yaws.append(sum / n)
				print("  %s %s: bone +Z yaw mean %.1f deg (min %.1f, max %.1f)  (+ = toward the model's +X)" % [bone, anim_name, sum / n, lo, hi])
			print("  %s talk minus idle: %.1f deg" % [bone, yaws[1] - yaws[0]])
		root.queue_free()
	quit(0)
