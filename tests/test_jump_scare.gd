extends SceneTree
## Level 3, part 4: the jump scare, in both ways of being found.
##  - "peek": Bob on the floor of a closed stall. The seeker who peeks has the ONLY under-light (owner: the light is only on the Jijio
##    doing the jump scare), it hangs on that seeker's model, the door bangs open, the face lunges at the camera, one scare sound, then
##    the result screen says to press R. Nothing is lit before the catch.
##  - "sight": Bob in a corridor: the seeker runs at him and does the same.
##  - Being caught twice does not scare twice. R reloads Level 3 (a fresh round, phase HIDING, no catches).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _init() -> void:
	Progress.level = T.HIDE_LEVEL
	seed(41)
	await _scare("peek")
	await _scare("sight")
	T.finish(self)


func _lights(lvl: Node) -> Array:
	return lvl.find_children("UnderLight", "OmniLight3D", true, false)


func _scare(mode: String) -> void:
	var lvl := T.level(self)
	current_scene = lvl # so R (reload_current_scene) works
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var hs = lvl.hide_seek
	hs.hide_seconds = 1.0
	var p: CharacterBody3D = lvl.player
	var i := 8
	if mode == "peek":
		var door: Node3D = lvl.stalls.doors[i]
		p.global_position = Vector3(door.point.x, 0.05, door.point.z - 0.6)
		door.set_open(false, 0.01)
	else:
		p.global_position = Vector3(6.0, 0.05, 0.05)
	T.check(_lights(lvl).is_empty(), "%s: no under-light before anybody is caught" % mode)
	var scares := Sfx.count("scare")
	var t := 0.0
	while hs.phase != hs.Phase.CAUGHT and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
	T.check(hs.phase == hs.Phase.CAUGHT and hs.caught_mode == mode, "%s: caught that way (phase %d, '%s')" % [mode, hs.phase, hs.caught_mode])
	await T.wait(self, 0.5)
	var lights := _lights(lvl)
	T.check(lights.size() == 1, "%s: exactly ONE under-light in the level (%d)" % [mode, lights.size()])
	if lights.size() == 1:
		var light: OmniLight3D = lights[0]
		T.check(light.get_parent() == hs.caught_by.get_node("Model"), "%s: it hangs on the model of the seeker who caught him" % mode)
		T.check(light.visible and light.light_energy > 0.5 and light.position.y < 1.0, "%s: it is on and sits below the face (energy %.1f, y %.2f)" % [mode, light.light_energy, light.position.y])
	if mode == "peek":
		var gap_cam := get_root().get_camera_3d()
		var door: Node3D = lvl.stalls.doors[i]
		T.check(gap_cam != p.get_node("CameraPivot/SpringArm3D/Camera3D") and gap_cam.global_position.y < 0.3 and absf(gap_cam.global_position.z - door.point.z) < 0.4, "peek: the picture is the seeker's own view through the gap (camera y %.2f, %.2f m from the door line)" % [gap_cam.global_position.y, absf(gap_cam.global_position.z - door.point.z)])
		await T.wait(self, 1.2)
		T.check(lvl.stalls.doors[i].is_open, "peek: the door bangs open")
	var waited := 0.0
	while Sfx.count("scare") == scares and waited < 8.0: # seen in the open: the seeker first runs up to 8 m at Bob
		await physics_frame
		waited += 1.0 / 60.0
	print("INFO  %s: the scare sound came %.1f s after the catch" % [mode, waited + (1.7 if mode == "peek" else 0.5)])
	await T.wait(self, 0.5)
	var cam: Camera3D = get_root().get_camera_3d() # the scare camera: Bob's own eyes (the third-person camera is squashed inside a stall)
	var head: Vector3 = hs.caught_by.global_position + Vector3(0, 1.15, 0)
	var dist: float = head.distance_to(cam.global_position)
	T.check(dist > 0.6 and dist < 1.2, "%s: the face has lunged right at the camera (head %.2f m away)" % [mode, dist])
	T.check(cam.global_position.y > 0.8 and cam.global_position.distance_to(p.global_position + Vector3(0, 1.0, 0)) < 0.2, "%s: the camera is at Bob's eyes (y %.2f)" % [mode, cam.global_position.y])
	var to_cam: Vector3 = cam.global_position - hs.caught_by.global_position
	to_cam.y = 0.0
	var front: Vector3 = Vector3(sin(hs.caught_by.get_node("Model").rotation.y), 0.0, cos(hs.caught_by.get_node("Model").rotation.y))
	T.check(front.dot(to_cam.normalized()) > 0.9, "%s: and the face points at it, not the back of the head (dot %.2f)" % [mode, front.dot(to_cam.normalized())])
	T.check(Sfx.count("scare") == scares + 1, "%s: one scare sound (%d)" % [mode, Sfx.count("scare") - scares])
	await T.wait(self, 1.5)
	var result: Label = lvl.get_node("HUD/ResultLabel")
	T.check(result.visible and result.text.contains("Press R"), "%s: the result screen says press R ('%s')" % [mode, result.text.replace("\n", " / ")])
	# caught again: nothing more happens
	hs._caught(hs.caught_by, mode, 3)
	await T.wait(self, 0.3)
	T.check(_lights(lvl).size() == 1 and Sfx.count("scare") == scares + 1 and hs.catches == 1, "%s: a second catch does not scare again (%d lights, %d catches)" % [mode, _lights(lvl).size(), hs.catches])
	# R = a fresh round of the same level
	await T.key(self, KEY_R)
	await T.wait(self, 1.0)
	var fresh: Node = current_scene
	T.check(fresh != lvl and Progress.level == T.HIDE_LEVEL and fresh.hide_seek != null, "%s: R reloads the hide-and-seek level" % mode)
	T.check(fresh.hide_seek.catches == 0 and _lights(fresh).is_empty(), "%s: the new round starts clean" % mode)
	fresh.queue_free()
	await process_frame
	await physics_frame
