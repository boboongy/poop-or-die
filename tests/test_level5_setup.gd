extends SceneTree
## Level 5 "Dance battle", steps 1-2 of the approved plan (SPEC "Level 5"): the beat loop, SHUFFLE QUEEN dancing outside a random
## stall on EVERY stall (all 20, both rows), and the talk chain: the finesse talk with the queue Jijio ahead of Bob, then her challenge.
## Written before dance.gd existed (it hung/failed on the missing script first).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")
const MissionBase := preload("res://scripts/missions/mission.gd")


## The factory boombox (boombox-prop.glb, SPEC Stage 6 Slice A, owner C1): the real mesh stands on the floor, and over two beats it
## pulses (scale up to about 1.03 and back to 1.00) and its cyan display flashes (emission energy up and down).
func _boombox_checks(d: Node, stall: int) -> void:
	var mesh: MeshInstance3D = d.boombox.find_child("SM_Boombox", true, false)
	var lowest := 99.0
	if mesh != null:
		lowest = (mesh.global_transform * mesh.get_aabb()).position.y
	T.check(mesh != null and absf(lowest) < 0.02, "stall %d: the boombox is the factory model, standing on the floor (bottom at %.3f m)" % [stall + 1, lowest])
	var smin := 9.0
	var smax := 0.0
	var emin := 99.0
	var emax := -1.0
	for i in 60:
		await physics_frame
		await process_frame
		var s: float = d.boombox.scale.y
		smin = minf(smin, s)
		smax = maxf(smax, s)
		var e: float = d.boombox_display.emission_energy_multiplier if d.boombox_display != null else -1.0
		emin = minf(emin, e)
		emax = maxf(emax, e)
	T.check(smax >= 1.025 and smax <= 1.035 and smin <= 1.005, "stall %d: the boombox pulses on the beat (scale %.3f..%.3f)" % [stall + 1, smin, smax])
	T.check(emin >= 0.0 and emax - emin >= 1.0, "stall %d: its cyan display flashes with the beat (emission %.2f..%.2f)" % [stall + 1, emin, emax])


func _init() -> void:
	seed(5)
	_beat_checks()
	Progress.level = 5
	var placed := 0
	for stall in 20:
		Dance.force_stall = stall
		var lvl := T.level(self)
		await T.wait(self, 0.6)
		var d: Node = lvl.dance
		if d == null:
			T.check(false, "stall %d: the level has a dance director" % stall)
			lvl.queue_free()
			await process_frame
			continue
		var q: Node3D = d.queen
		var door: Node3D = lvl.stalls.doors[stall]
		var occupant: Node3D = lvl.population.occupants[stall]
		var out := signf(door.point.z - occupant.global_position.z) # the corridor side of this door
		var off_z: float = (q.global_position.z - door.point.z) * out
		var along := absf(q.global_position.x - door.point.x)
		var ok: bool = off_z > 0.4 and off_z < 0.75 and along < 0.2 and not door.is_open and occupant.is_sitting()
		ok = ok and q.anim().current_animation == "dance/groove" and q.anim().is_playing()
		ok = ok and d.beat_player != null and d.beat_player.playing and d.boombox.visible
		ok = ok and d.is_tinted(q, Dance.QUEEN_COLOR)
		T.check(ok, "stall %d (row %d): SHUFFLE QUEEN dances %.2f m out from the shut door (%.2f m along), groove + beat + boombox + pink"
				% [stall % 10 + 1, 1 if stall < 10 else 2, off_z, along])
		if ok:
			placed += 1
		# she keeps her spot (walkers pass through her, she never walks off)
		if stall % 5 == 0:
			var before := q.global_position
			await T.wait(self, 1.5)
			T.check(before.distance_to(q.global_position) < 0.05, "stall %d: she stays on her spot while dancing" % (stall + 1))
		if stall == 0 or stall == 17:
			await _boombox_checks(d, stall)
		if stall == 3 or stall == 14:
			await _talk_chain(lvl, d)
		lvl.queue_free()
		await process_frame
		await physics_frame
	print("INFO  SHUFFLE QUEEN placed correctly on %d of 20 stalls" % placed)
	Dance.force_stall = -1
	T.finish(self)


func _beat_checks() -> void:
	var s: AudioStreamWAV = DanceBeat.build()
	var beat := 60.0 / DanceBeat.BPM
	T.check(absf(s.get_length() - beat * 4.0 * DanceBeat.BARS) < 0.01, "the beat loop is exactly %d bars at %d BPM (%.2f s)" % [DanceBeat.BARS, DanceBeat.BPM, s.get_length()])
	T.check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end > 0, "the beat loops")
	# loud on the beat (the kick), quiet just before the next one
	var on := DanceBeat.peak(s, 0.0, 0.05)
	var off := DanceBeat.peak(s, beat * 0.5 - 0.06, beat * 0.5 - 0.02)
	T.check(on > 0.5 and on > off * 2.0, "the kick lands on the beat (peak %.2f on it, %.2f between)" % [on, off])


func _talk_chain(lvl: Node, d: Node) -> void:
	var p: CharacterBody3D = lvl.player
	lvl._time_left = 100000.0
	var m: Node = lvl.get_node("MissionManager")
	var fin: Node = m.mission("finesse")
	var find: Node = m.mission("find_dancer")
	T.check(fin != null and fin.state == MissionBase.State.ACTIVE and find != null and find.state == MissionBase.State.LOCKED, "at the start: finesse talk active, finding her locked")
	T.check(d.queen.prompt() == "", "before the finesse talk she only dances (no E prompt)")
	var npc: Node3D = lvl.population.queue[4]
	T.check(npc.prompt() != "", "the Jijio ahead of Bob can be talked to")
	npc.interact(p)
	await T.wait(self, 0.2)
	await T.key(self, KEY_1) # "It's an emergency!"
	await T.wait(self, 0.1)
	await T.key(self, KEY_E) # the rebuttal
	await T.wait(self, 0.1)
	await T.key(self, KEY_E) # the music hint
	await T.wait(self, 0.2)
	T.check(fin.state == MissionBase.State.DONE, "every excuse fails but the finesse talk is done")
	T.check(find.state == MissionBase.State.ACTIVE and find.hint.contains("stall"), "now: find another way in (%s)" % find.hint)
	T.check(not find.hint.contains("row"), "the hint does not name her stall or row (%s)" % find.hint)
	T.check(d.queen.prompt().contains("SHUFFLE QUEEN"), "now she can be talked to (%s)" % d.queen.prompt())
	T.check(not p.busy, "Bob is free after the talk")
	# Found by the first screenshot: next to her the neighbouring stall door won the E prompt ("E open door"). Bob walking up to her from
	# either end of the corridor or straight across, 0.6-1.25 m away (Bob's reach is 1.3 m) and facing her, must get HER prompt every time.
	var q: Vector3 = d.queen.global_position
	var won := 0
	var tries := 0
	for dir: Vector3 in [Vector3(-1, 0, 0), Vector3(1, 0, 0), d.out, (d.out + Vector3(1, 0, 0)).normalized(), (d.out - Vector3(1, 0, 0)).normalized()]:
		for dist in [0.6, 0.85, 1.1, 1.25]:
			var at: Vector3 = q + dir * dist
			p.global_position = Vector3(at.x, p.global_position.y, at.z)
			p.face_direction(-dir)
			await T.wait(self, 0.1)
			tries += 1
			if p._focus == d.queen:
				won += 1
			else:
				print("  from %s at %.2f m the prompt was '%s'" % [dir, dist, p._focus.prompt() if p._focus else ""])
	T.check(won == tries, "her E prompt wins next to the stall doors: %d of %d approach spots" % [won, tries])
	d.queen.interact(p)
	await T.wait(self, 0.2)
	await T.key(self, KEY_2)
	await T.wait(self, 0.1)
	await T.key(self, KEY_E) # "Then DANCE for it!"
	await T.wait(self, 0.2)
	T.check(find.state == MissionBase.State.DONE and d.challenged, "any reply ends in her challenge: finding her is done")
