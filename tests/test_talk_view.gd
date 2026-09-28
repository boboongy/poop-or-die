extends SceneTree
## Stage 6b E (owner playtest 2026-09-28, "yes to all"; SPEC "Stage 6b FIXES"): in a talk, Bob and the Jijio play the factory `talk` clip
## (no more T-pose) and the camera pans (0.5 s) into Bob's first-person view facing the Jijio, and back out after.
## The `talk` clip turns head and chest ~22 deg to the character's LEFT (tests/probe_talk_clip.gd: head 21.6, chest 25.0, both rigs), so
## each body turns that much to the right of its partner and the head looks straight at them.
## Cases: (1) the Level 1 queue Jijio, real E presses, every frame of the talk sampled; (2) a walker's small talk, left with W;
## (3) a seated stall occupant keeps its `sit` clip while Bob still goes first person.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Pose := preload("res://scripts/pose.gd")

const FIRST := 1 ## player.gd View.FIRST_HIDDEN


func _arm(p: Node) -> float:
	return (p.get_node("CameraPivot/SpringArm3D") as SpringArm3D).spring_length


## Angle (rad) between where the camera looks and the NPC's face.
func _aim_error(p: Node, npc: Node3D) -> float:
	var cam: Camera3D = p.get_node("CameraPivot/SpringArm3D/Camera3D")
	var sk := Pose.skeleton_of(npc)
	var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("DEF-spine.006")).origin
	return (-cam.global_basis.z).angle_to(head - cam.global_position)


## Horizontal angle (deg) between a character's head bone facing and the direction to `other`.
func _head_off(who: Node3D, other: Node3D) -> float:
	var sk := Pose.skeleton_of(who)
	var i := sk.find_bone("DEF-spine.006")
	var head: Transform3D = sk.global_transform * sk.get_bone_global_pose(i)
	var fwd := head.basis.z
	fwd.y = 0.0
	var to := other.global_position - who.global_position
	to.y = 0.0
	return rad_to_deg(fwd.angle_to(to))


func _clip(n: Node) -> String:
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	return ap.current_animation if ap.is_playing() else "(stopped: T-pose)"


func _queue_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var npc: Node3D = lvl.population.queue[4] # the Jijio just ahead of Bob: "E talk" at spawn
	var yaw_before: float = p.get_camera_yaw()
	var pitch_before: float = p.get_camera_pitch()
	T.check(_arm(p) > 2.0 and p.get_node("Model").visible, "(1) before the talk: third person, Bob visible (arm %.2f)" % _arm(p))
	await T.key(self, KEY_E)
	await T.wait(self, 0.25)
	T.check(_arm(p) > 0.3 and _arm(p) < 1.9, "(1) 0.25 s in, the camera is still on its way in (a pan, not a cut; arm %.2f m)" % _arm(p))
	await T.wait(self, 0.4)
	T.check(_arm(p) < 0.05 and p._view == FIRST and not p.get_node("Model").visible, "(1) after the 0.5 s pan: Bob's first person (arm %.2f, model hidden)" % _arm(p))
	T.check(_aim_error(p, npc) < 0.12, "(1) the camera looks at the Jijio's face (%.3f rad off)" % _aim_error(p, npc))
	T.check(_clip(p) == "talk" and _clip(npc) == "talk", "(1) both play the talk clip (Bob '%s', Jijio '%s')" % [_clip(p), _clip(npc)])
	T.check(_head_off(npc, p) < 8.0, "(1) the Jijio's head faces Bob (%.1f deg off; the clip turns it 22 deg left)" % _head_off(npc, p))
	T.check(_head_off(p, npc) < 8.0, "(1) Bob's head faces the Jijio (%.1f deg off)" % _head_off(p, npc))
	# every frame while the box is open: nobody in a T-pose
	var frames := 0
	var bad := 0
	var worst := ""
	var d = lvl.dialogue
	await T.key(self, KEY_E) # next line: the question
	for k in 60:
		await physics_frame
		if d.is_open():
			frames += 1
			if _clip(p) != "talk" or _clip(npc) != "talk":
				bad += 1
				worst = "Bob '%s', Jijio '%s'" % [_clip(p), _clip(npc)]
	T.check(frames >= 50 and bad == 0, "(1) %d frames of the talk sampled, %d with a clip other than talk %s" % [frames, bad, worst])
	await T.key(self, KEY_2) # "Not my problem": the talk ends
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.25)
	T.check(not d.is_open() and _arm(p) > 0.3 and _arm(p) < 1.9, "(1) the talk ended: the camera is on its way out (arm %.2f m)" % _arm(p))
	await T.wait(self, 0.5)
	T.check(_arm(p) > 2.0 and p._view == 0 and p.get_node("Model").visible, "(1) back in third person, Bob visible (arm %.2f)" % _arm(p))
	T.check(absf(wrapf(p.get_camera_yaw() - yaw_before, -PI, PI)) < 0.05 and absf(p.get_camera_pitch() - pitch_before) < 0.05,
			"(1) the camera is back where it was before the talk")
	T.check(_clip(p) == "idle" and _clip(npc) != "talk" and not npc.talking, "(1) after: Bob '%s', the Jijio '%s'" % [_clip(p), _clip(npc)])
	# Bob walks again
	var before := p.global_position
	Input.action_press("move_left")
	await T.wait(self, 0.4)
	Input.action_release("move_left")
	T.check(p.global_position.distance_to(before) > 0.3 and _clip(p) == "walk", "(1) Bob walks again ('%s')" % _clip(p))
	lvl.queue_free()
	await T.wait(self, 0.3)


func _walker_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var walkers = lvl.get_node("Walkers")
	var p: CharacterBody3D = lvl.player
	await walkers.clear()
	var w: Node3D = lvl.population.spawn_walker(Vector3(6.0, 0.0, 0.3), 0.0) # as test_talk_leave.gd
	w.set_interaction("E  talk", walkers._talk.bind(w))
	p.global_position = Vector3(6.0, 0.05, -0.4)
	p.set_facing(PI)
	await T.wait(self, 0.4)
	await T.key(self, KEY_E)
	await T.wait(self, 0.65)
	T.check(_arm(p) < 0.05 and _aim_error(p, w) < 0.12 and _clip(w) == "talk" and _clip(p) == "talk",
			"(2) walker: first person on its face (%.3f rad), both talk (Bob '%s', walker '%s')" % [_aim_error(p, w), _clip(p), _clip(w)])
	await T.key(self, KEY_W) # leave the small talk
	await T.wait(self, 0.65)
	T.check(_arm(p) > 2.0 and p.get_node("Model").visible and _clip(w) != "talk", "(2) W leaves: third person again (arm %.2f), walker '%s'" % [_arm(p), _clip(w)])
	lvl.queue_free()
	await T.wait(self, 0.3)


func _seated_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var occ: Node3D = null
	for o in lvl.population.occupants:
		if o != null and o.state == o.State.SIT:
			occ = o
			break
	T.check(occ != null, "(3) a seated occupant exists")
	if occ == null:
		lvl.queue_free()
		return
	var d = lvl.dialogue
	d.begin(occ, p)
	d.say(occ, "A HUNDRED YEARS.", false, "GHOST") # a line that has a voice file (a new one prints VOICE MISSING and run.sh fails)
	await T.wait(self, 0.65)
	T.check(_arm(p) < 0.05 and _clip(occ) == "sit" and _clip(p) == "talk", "(3) seated: Bob first person and talking, the occupant keeps '%s'" % _clip(occ))
	d.force_close()
	d.end(occ, p)
	await T.wait(self, 0.65)
	T.check(_arm(p) > 2.0 and _clip(occ) == "sit", "(3) after: third person, the occupant still sits")
	lvl.queue_free()
	await T.wait(self, 0.3)


func _init() -> void:
	seed(5)
	await _queue_talk()
	await _walker_talk()
	await _seated_talk()
	T.finish(self)
