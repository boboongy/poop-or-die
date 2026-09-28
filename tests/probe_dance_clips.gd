extends SceneTree
## PROBE (not run by run.sh): stand-in poses for Level 5's crowd (fist pump, arms up) and dance moves. For every 2nd frame of the attack
## clips, prints the hands' height above the floor, how far out they reach, and the hips' height (a frame with the hips high is airborne:
## slicing it would float the body). Jijio and Bob share the skeleton, so one Jijio is enough.
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")
const CLIPS := ["uppercut", "hook_right", "kick_spin", "punch_combo", "punch", "kick_double", "sit_down"]


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var npc: Node3D = lvl.population.queue[0]
	npc.state = npc.State.DANCE
	var ap: AnimationPlayer = npc.anim()
	var sk := Pose.skeleton_of(npc.get_node("Model"))
	var names := {}
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n in ["DEF-hand.R", "DEF-hand.L", "DEF-spine", "DEF-pelvis.L"]:
			names[n] = b
	print("bones found: ", names.keys())
	for clip: String in CLIPS:
		var a := ap.get_animation(clip)
		var frames := int(round(a.length * 30.0))
		print("== %s (%d frames)" % [clip, frames])
		ap.play(clip)
		ap.speed_scale = 0.0
		for f in range(0, frames + 1, 2):
			ap.seek(f / 30.0, true)
			await process_frame
			var root := sk.global_transform
			var line := "  f%02d" % f
			for n: String in ["DEF-hand.R", "DEF-hand.L", "DEF-spine"]:
				if names.has(n):
					var p: Vector3 = (root * sk.get_bone_global_pose(names[n])).origin - npc.global_position
					line += "  %s y %.2f out %.2f" % [n.substr(4), p.y, Vector2(p.x, p.z).length()]
			print(line)
	lvl.queue_free()
	await process_frame
	quit()
