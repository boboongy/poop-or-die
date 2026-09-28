extends SceneTree
## Level 3, part 3: noise, the fart Bob has to hold in, and the occupant who shouts. Sight is switched off (`see_range = 0`) in the tests
## that need Bob to stand in the open, and the search is stopped from ending early by a few unchecked stalls where needed.
##  N1 sprinting makes noise (a "sprint" entry every 0.5 s), walking makes none.
##  N2 a door toggled near Bob makes a "door" noise, and one far from him does not; a hop while the seekers search makes a "hop" noise.
##  N3 a noise near a seeker sends the nearest one to peek at the stall nearest the noise (6 different stalls).
##  N4 the fart meter: fills 0.1/s, clenching (hold F) fills it about 3x slower and Bob cannot move, at full it lets go: a fart sound,
##     a "fart" noise, the meter drops to 0.3. Letting go of F lets Bob walk again.
##  N5 an unshushed occupant shouts when a seeker comes within 6 m of Bob's stall (a "shout" noise, the stall is marked); a shushed one
##     never does.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")
const Sfx := preload("res://scripts/sfx.gd")

## Seconds after the search starts until each stall is first peeked at when NOBODY makes a noise (queue only, no walkers; measured
## 2026-09-22 with a control script; the queue positions are fixed, so it is the same every run). Only stalls a seeker has not already
## claimed at the start are used.
const NATURAL := {19: 8.4, 16: 8.5, 13: 5.9, 12: 5.9, 9: 5.3, 7: 4.5, 6: 4.2, 3: 2.0}


func _init() -> void:
	Progress.level = T.HIDE_LEVEL
	seed(77)
	await _n1_sprint()
	await _n2_door_hop()
	await _n3_redirect()
	await _n4_fart()
	await _n5_shout()
	T.finish(self)


## A level whose seekers have started (sight off), Bob in the open.
func _seeking(sight := false) -> Node:
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var hs = lvl.hide_seek
	hs.hide_seconds = 0.5
	if not sight:
		hs.see_range = 0.0
	while hs.phase != hs.Phase.SEEKING:
		await physics_frame
	return lvl


func _free(lvl: Node) -> void:
	lvl.queue_free()
	await process_frame
	await physics_frame


func _count(hs, kind: String) -> int:
	var n := 0
	for e: Dictionary in hs.noises:
		if e["kind"] == kind and e["phase"] == hs.Phase.SEEKING:
			n += 1
	return n


func _n1_sprint() -> void:
	var lvl := await _seeking()
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(2.0, 0.05, 0.05)
	p.face_direction(Vector3.RIGHT)
	await T.wait(self, 0.2)
	await T.key_down(self, KEY_W)
	await T.wait(self, 1.5) # walking: 4.5 m
	T.check(_count(hs, "sprint") == 0, "walking makes no noise (%d sprint noises, moved to x %.1f)" % [_count(hs, "sprint"), p.global_position.x])
	await T.key_down(self, KEY_SHIFT)
	await T.wait(self, 1.2)
	var n := _count(hs, "sprint")
	T.check(n >= 2 and n <= 3, "1.2 s of sprinting: about one noise every 0.5 s (%d)" % n)
	await T.key_up(self, KEY_SHIFT)
	await T.key_up(self, KEY_W)
	await _free(lvl)


func _n2_door_hop() -> void:
	var lvl := await _seeking()
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	var door: Node3D = lvl.stalls.doors[5]
	p.global_position = Vector3(door.point.x, 0.05, door.point.z + 0.7)
	door.interact(p)
	T.check(_count(hs, "door") == 1, "opening a door next to Bob makes a door noise (%d)" % _count(hs, "door"))
	p.global_position = Vector3(door.point.x + 6.0, 0.05, door.point.z + 0.7)
	door.interact(p)
	T.check(_count(hs, "door") == 1, "the same door toggled by nobody near it makes none (%d)" % _count(hs, "door"))
	door.set_open(false, 0.01)
	var i := 4
	if i == hs.empty_stall:
		i = 3
	else:
		hs.shushed[i] = true
	var door4: Node3D = lvl.stalls.doors[i]
	door4.set_open(false, 0.01)
	p.global_position = Vector3(hs.hide_spot(i).x, 0.05, door4.point.z - 0.6)
	await hs.hop(i)
	T.check(_count(hs, "hop") == 1, "a hop while the seekers search makes a hop noise (%d)" % _count(hs, "hop"))
	await _free(lvl)


func _n3_redirect() -> void:
	var tested := 0
	for i in [19, 16, 13, 12, 9, 7, 6, 3]:
		var lvl := await _seeking()
		var hs = lvl.hide_seek
		if hs._claimed.has(i):
			# a seeker is already on its way there (each of the 9 claims the nearest stall when the search starts): no noise needed
			await _free(lvl)
			continue
		var p: CharacterBody3D = lvl.player
		var door: Node3D = lvl.stalls.doors[i]
		var inward := Vector3(0.0, 0.0, -1.0) if i < 10 else Vector3(0.0, 0.0, 1.0)
		p.global_position = Vector3(door.point.x, 0.05, door.point.z) + inward * 0.6
		door.set_open(false, 0.01)
		# a noise from inside the stall, heard by everybody
		hs.noise(p.global_position, 100.0, "test")
		var heard := 0
		var heard_stall := -1
		for npc in hs._redirect:
			heard += 1
			heard_stall = hs._redirect[npc]
		T.check(heard == 1 and heard_stall == i, "stall %d: exactly one seeker is sent, to the stall the noise came from (%d sent, to stall %d)" % [i, heard, heard_stall])
		var t := 0.0
		while hs.peeks.get(i, 0) == 0 and t < 12.0 and hs.phase == hs.Phase.SEEKING:
			await physics_frame
			t += 1.0 / 60.0
		T.check(hs.peeks.get(i, 0) >= 1 and t < NATURAL[i] - 1.0, "stall %d: peeked at after %.1f s, at least 1 s sooner than the %.1f s it takes with no noise" % [i, t, NATURAL[i]])
		tested += 1
		await _free(lvl)
	T.check(tested >= 4, "at least four stalls tested (%d; the rest were already claimed at the start)" % tested)


func _n4_fart() -> void:
	var lvl := await _seeking()
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	hs.hold_search_open = true # the search would end (about 10 s) before the meter test is over
	p.global_position = Vector3(3.0, 0.05, 0.05)
	p.face_direction(Vector3.RIGHT)
	hs.pressure = 0.0
	await T.wait(self, 4.0)
	T.check(absf(hs.pressure - 0.4) < 0.06, "the meter fills about 0.1 per second (0.40 expected after 4 s: %.2f)" % hs.pressure)
	# hold in: slower, and Bob cannot move
	hs.pressure = 0.0
	var x0 := p.global_position.x
	await T.key_down(self, KEY_F)
	await T.key_down(self, KEY_W)
	await T.wait(self, 3.0)
	T.check(hs.pressure > 0.05 and hs.pressure < 0.15, "clenching: about 3x slower (0.10 expected after 3 s: %.2f)" % hs.pressure)
	T.check(absf(p.global_position.x - x0) < 0.1, "Bob cannot walk while he clenches (moved %.2f m)" % absf(p.global_position.x - x0))
	await T.key_up(self, KEY_F)
	await T.wait(self, 0.6)
	T.check(absf(p.global_position.x - x0) > 1.0, "let go of F and he walks again (moved %.2f m)" % absf(p.global_position.x - x0))
	await T.key_up(self, KEY_W)
	# the release
	var farts := Sfx.count("fart")
	var f0: int = hs.farts
	hs.pressure = 0.97
	await T.wait(self, 0.6)
	T.check(hs.farts == f0 + 1, "at full pressure it lets go once (%d)" % (hs.farts - f0))
	T.check(Sfx.count("fart") == farts + 1, "the fart sound plays")
	T.check(_count(hs, "fart") == 1, "and it is a loud noise (%d fart noises)" % _count(hs, "fart"))
	T.check(hs.pressure > 0.25 and hs.pressure < 0.4, "the meter falls back to about 0.3 (%.2f)" % hs.pressure)
	await _free(lvl)


func _n5_shout() -> void:
	# an unshushed occupant, Bob standing inside on the floor: the seekers arrive, the occupant shouts
	var shouts := 0
	var quiet := 0
	for k in 4:
		var lvl := await _seeking(true)
		var hs = lvl.hide_seek
		var p: CharacterBody3D = lvl.player
		var i := 2 + k * 5
		if i == hs.empty_stall:
			i += 1
		var door: Node3D = lvl.stalls.doors[i]
		var inward := Vector3(0.0, 0.0, -1.0) if i < 10 else Vector3(0.0, 0.0, 1.0)
		p.global_position = Vector3(door.point.x, 0.05, door.point.z) + inward * 0.6
		door.set_open(false, 0.01)
		var t := 0.0
		while hs.phase == hs.Phase.SEEKING and t < 30.0:
			await physics_frame
			t += 1.0 / 60.0
		var shouted := _count(hs, "shout")
		T.check(shouted == 1 and hs.snitched.has(i), "stall %d, not shushed: the occupant shouts once as the seekers come (%d)" % [i, shouted])
		shouts += shouted
		await _free(lvl)
	T.check(shouts == 4, "all four unshushed stalls shouted")
	# shushed and hiding on the lap: never a shout
	var lvl := await _seeking(true)
	var hs = lvl.hide_seek
	var i := 6
	if i == hs.empty_stall:
		i = 7
	var door: Node3D = lvl.stalls.doors[i]
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(door.point.x, 0.05, door.point.z - 0.6)
	door.set_open(false, 0.01)
	hs.shushed[i] = true
	await hs.hop(i)
	var t := 0.0
	while hs.phase == hs.Phase.SEEKING and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
	quiet = _count(hs, "shout")
	T.check(hs.phase == hs.Phase.OVER and quiet == 0, "shushed and standing on the lap: the search ends and nobody shouted (phase %d, %d shouts)" % [hs.phase, quiet])
	await _free(lvl)
