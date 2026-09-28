extends SceneTree
## Slice 2 probe (NOT a test, not in run.sh): checks the real AnimationPlayer state for Bob's and Jijio's
## toilet-sequence clips before any wiring code is written (build-verify-workflow section 3.1: probe first).
##   godot --headless --path . --fixed-fps 60 --script tests/probe_toilet_anim.gd
## Confirms: clip presence/length/loop flag as Godot actually imported them, whether any track touches the
## root node (the factory notes say every clip is "in place", bones only) vs only Skeleton3D bone tracks,
## and whether frame-0 poses chain without a jump (sit_down end -> sit start, pants_down end -> sit_down start,
## wipe/tissue_grab/press_flush start/end -> sit frame 0), by comparing a few key bone positions numerically.
const T := preload("res://tests/t.gd")
const Pose := preload("res://scripts/pose.gd")


func _dump_clip(ap: AnimationPlayer, name: String) -> void:
	if not ap.has_animation(name):
		print("INFO    %-14s MISSING" % name)
		return
	var a := ap.get_animation(name)
	var root_tracks := 0
	var bone_tracks := 0
	var blend_tracks := 0
	var other_tracks := 0
	for i in a.get_track_count():
		var path := String(a.track_get_path(i))
		var t := a.track_get_type(i)
		if t == Animation.TYPE_BLEND_SHAPE:
			blend_tracks += 1
		elif path.contains(":"):
			bone_tracks += 1
		elif path == "." or path == "":
			root_tracks += 1
		else:
			other_tracks += 1
	print("INFO    %-14s len %.3fs loop_mode(as imported)=%d tracks: bone=%d blend=%d root=%d other=%d" % [name, a.length, a.loop_mode, bone_tracks, blend_tracks, root_tracks, other_tracks])


## Sample a bone's global position at a given animation time, with the AnimationPlayer actually playing.
func _bone_pos_at(ap: AnimationPlayer, sk: Skeleton3D, clip: String, t: float, bone: String) -> Vector3:
	ap.play(clip)
	ap.seek(t, true)
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p: CharacterBody3D = lvl.player
	var ap: AnimationPlayer = p.anim()
	var sk := Pose.skeleton_of(p.model())
	print("INFO  === Bob toilet clips ===")
	for n in ["sit", "sit_down", "stand_up", "wipe", "tissue_grab", "pants_down", "press_flush"]:
		_dump_clip(ap, n)

	# chaining checks: hip and right-hand position at the seam between clips (frame 0 vs last frame)
	var hip := "DEF-hip.L" if sk.find_bone("DEF-hip.L") >= 0 else "DEF-spine"
	print("INFO  --- chain deltas (hip bone '%s', world position, metres) ---" % hip)
	var sit0 := _bone_pos_at(ap, sk, "sit", 0.0, hip)
	var sit_down_len: float = ap.get_animation("sit_down").length if ap.has_animation("sit_down") else 0.0
	if sit_down_len > 0.0:
		var sit_down_end := _bone_pos_at(ap, sk, "sit_down", sit_down_len - 0.001, hip)
		print("INFO    sit_down end vs sit start: %.4f m" % sit_down_end.distance_to(sit0))
	var pants_down_len: float = ap.get_animation("pants_down").length if ap.has_animation("pants_down") else 0.0
	if pants_down_len > 0.0 and ap.has_animation("sit_down"):
		var pants_down_end := _bone_pos_at(ap, sk, "pants_down", pants_down_len - 0.001, hip)
		var sit_down0 := _bone_pos_at(ap, sk, "sit_down", 0.0, hip)
		print("INFO    pants_down end vs sit_down start: %.4f m" % pants_down_end.distance_to(sit_down0))
	for n in ["wipe", "tissue_grab", "press_flush"]:
		if not ap.has_animation(n):
			continue
		var start := _bone_pos_at(ap, sk, n, 0.0, hip)
		var len: float = ap.get_animation(n).length
		var end := _bone_pos_at(ap, sk, n, len - 0.001, hip)
		print("INFO    %-12s start vs sit frame0: %.4f m | end vs sit frame0: %.4f m" % [n, start.distance_to(sit0), end.distance_to(sit0)])
	var stand_up_len: float = ap.get_animation("stand_up").length if ap.has_animation("stand_up") else 0.0
	if stand_up_len > 0.0:
		var stand_up0 := _bone_pos_at(ap, sk, "stand_up", 0.0, hip)
		print("INFO    stand_up start vs sit frame0: %.4f m" % stand_up0.distance_to(sit0))

	# Local-skeleton-space check (independent of where the model node actually sits in the world): does the
	# hip bone travel forward (toward the seat) INSIDE the bone tracks themselves, or does it stay put (meaning
	# the game would have to physically move the model node between clips instead)?
	print("INFO  --- local-space hip Z per clip (skeleton-local, independent of model placement) ---")
	for n in ["pants_down", "sit_down", "sit", "stand_up"]:
		if not ap.has_animation(n):
			continue
		ap.play(n)
		ap.seek(0.0, true)
		var z0: float = sk.get_bone_global_pose(sk.find_bone(hip)).origin.z
		var len: float = ap.get_animation(n).length
		ap.seek(len - 0.001, true)
		var z1: float = sk.get_bone_global_pose(sk.find_bone(hip)).origin.z
		print("INFO    %-12s local hip z: frame0 %.3f -> last frame %.3f (delta %.3f)" % [n, z0, z1, z1 - z0])

	ap.stop()
	sk.reset_bone_poses()

	print("INFO  === Jijio clips (occupant 0) ===")
	var occ: Node3D = lvl.population.occupants[0]
	var jap: AnimationPlayer = occ.anim()
	for n in ["wash", "sit", "sit_down", "stand_up"]:
		_dump_clip(jap, n)

	lvl.queue_free()
	await process_frame
	quit(0)
