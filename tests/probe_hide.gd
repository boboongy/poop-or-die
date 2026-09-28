extends SceneTree
## Level 3 probe (NOT a test, not in run.sh): prints the real numbers the hide-and-seek design depends on.
##   godot --headless --path . --fixed-fps 60 --script tests/probe_hide.gd
## Door gap, seat/lid/tank heights, stall interior size, where a sitting Jijio's lap, knees and feet are, Bob's capsule.
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var toilet: Node3D = lvl.get_node("NavRegion/Toilet")
	var doors: Array = lvl.stalls.doors
	print("INFO  doors: %d" % doors.size())
	# 1. Door gap and door size, all 20.
	var gap_min := INF
	var gap_max := -INF
	var top_min := INF
	for d: Node3D in doors:
		for mi in d.find_children("SM_*", "MeshInstance3D", true, false):
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			gap_min = minf(gap_min, box.position.y)
			gap_max = maxf(gap_max, box.position.y)
			top_min = minf(top_min, box.end.y)
	print("INFO  door bottom edge (the gap) over 20 doors: %.3f .. %.3f m; lowest door top %.3f m" % [gap_min, gap_max, top_min])
	# 2. One stall in each row: every mesh that belongs to it, with its box.
	for row in [1, 2]:
		var k := 3
		print("INFO  --- row %d stall %d meshes ---" % [row, k])
		for mi in toilet.find_children("SM_*", "MeshInstance3D", true, false):
			var n := String(mi.name)
			if n.contains("R%d_%02d" % [row, k]) or n.contains("Partition") and n.contains("R%d" % row) and n.ends_with("_%02d" % k) or n.contains("Partition") and n.contains("R%d" % row) and n.ends_with("_%02d" % (k + 1)):
				var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				print("INFO    %-34s x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f" % [n, b.position.x, b.end.x, b.position.y, b.end.y, b.position.z, b.end.z])
	# 3. Toilet parts for ALL 20: seat (lid top), body top, and the sitting Jijio's bones.
	var lid_min := INF
	var lid_max := -INF
	var body_top_min := INF
	var body_top_max := -INF
	for row in [1, 2]:
		for k in range(1, 11):
			var lid := toilet.find_child("SM_Toilet_R%d_%02d_Lid" % [row, k], true, false) as MeshInstance3D
			var body := toilet.find_child("SM_Toilet_R%d_%02d_Body" % [row, k], true, false) as MeshInstance3D
			var lb: AABB = lid.global_transform * lid.get_aabb()
			var bb: AABB = body.global_transform * body.get_aabb()
			lid_min = minf(lid_min, lb.end.y)
			lid_max = maxf(lid_max, lb.end.y)
			body_top_min = minf(body_top_min, bb.end.y)
			body_top_max = maxf(body_top_max, bb.end.y)
	print("INFO  lid top over 20 toilets %.3f..%.3f m; body top %.3f..%.3f m" % [lid_min, lid_max, body_top_min, body_top_max])
	var occ: Array = lvl.population.occupants
	print("INFO  occupants: %d" % occ.size())
	var foot_low := INF
	var foot_high := -INF
	var lap_min := INF
	var lap_max := -INF
	for npc: Node3D in occ:
		var sk: Skeleton3D = Pose.skeleton_of(npc.get_node("Model"))
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			var p := sk.global_transform * sk.get_bone_global_pose(i).origin
			if bn.begins_with("DEF-foot") or bn.begins_with("DEF-toe"):
				foot_low = minf(foot_low, p.y)
				foot_high = maxf(foot_high, p.y)
			if bn.begins_with("DEF-thigh"):
				lap_min = minf(lap_min, p.y)
				lap_max = maxf(lap_max, p.y)
	print("INFO  sitting Jijio foot/toe bones: y %.3f..%.3f m (door gap top is the door bottom edge above); thigh bone y %.3f..%.3f m" % [foot_low, foot_high, lap_min, lap_max])
	# 4. One sitting Jijio in detail (row 1 stall 3, row 2 stall 3): every leg/foot bone and the lowest mesh vertex y.
	for idx in [2, 12]:
		var npc: Node3D = occ[idx]
		var sk: Skeleton3D = Pose.skeleton_of(npc.get_node("Model"))
		print("INFO  --- occupant %d at %s ---" % [idx, str(npc.global_position)])
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			if bn.begins_with("DEF-thigh") or bn.begins_with("DEF-shin") or bn.begins_with("DEF-foot") or bn.begins_with("DEF-toe") or bn.begins_with("DEF-spine") or bn.begins_with("DEF-head") or bn.begins_with("DEF-hip") or bn.begins_with("DEF-pelvis"):
				var p := sk.global_transform * sk.get_bone_global_pose(i).origin
				print("INFO    %-22s (%.2f, %.2f, %.2f)" % [bn, p.x, p.y, p.z])
		var low := INF
		for mi in npc.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			low = minf(low, box.position.y)
		print("INFO    lowest mesh box y %.3f (loose bound, blend shapes / skinning can make it lower than the real body)" % low)
	# 5. Bob: capsule and height; stall doorway width; input keys already used.
	var bob: CharacterBody3D = lvl.player
	for cs in bob.find_children("*", "CollisionShape3D", true, false):
		var sh: Shape3D = (cs as CollisionShape3D).shape
		if sh is CapsuleShape3D:
			print("INFO  Bob capsule radius %.2f height %.2f, node y %.2f" % [(sh as CapsuleShape3D).radius, (sh as CapsuleShape3D).height, (cs as Node3D).position.y])
	var used: Array[String] = []
	for a in InputMap.get_actions():
		if String(a).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				used.append("%s=%s" % [a, OS.get_keycode_string((ev as InputEventKey).physical_keycode)])
	print("INFO  game input actions: %s" % str(used))
	quit(0)
