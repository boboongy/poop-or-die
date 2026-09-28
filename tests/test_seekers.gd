extends SceneTree
## Level 3, part 2: the seekers, over MANY seeds (`-- seeds=N first=K`, default 4; add `walkers` to run with the 2-6 walking Jijios too).
## Per seed, three fresh levels:
##  A "hidden"  Bob properly hidden (on the seat or the lap of a random stall): every queue Jijio and walker seeks, ALL 20 stalls are
##              checked, somebody peeked at Bob's own stall (the test met the situation), Bob is NOT caught, the search ends, the mission
##              is done, Bob is back on the floor and the reward stall is coming.
##  B "floor"   Bob inside a random closed stall with his feet on the floor: the seeker who peeks at that stall catches him ("peek").
##  C "open"    Bob standing in a corridor: a seeker with a line of sight catches him ("sight").
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")

var _times: Array[float] = []
var _peeked := 0
var _met := 0


func _init() -> void:
	Progress.level = T.HIDE_LEVEL
	var seeds := 4
	var first := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a.begins_with("first="):
			first = int(a.substr(6))
	for s in range(first, first + seeds):
		seed(300 + s)
		await _hidden(s)
		await _floor(s)
		await _open(s)
	if not _times.is_empty():
		var worst := 0.0
		var total := 0.0
		for t in _times:
			worst = maxf(worst, t)
			total += t
		print("INFO  seek time (start of the search to 'all stalls checked') over %d hidden runs: mean %.1f s, worst %.1f s" % [_times.size(), total / _times.size(), worst])
	T.check(_met == seeds, "the test really met the situation: a seeker peeked at Bob's stall in %d of %d hidden runs" % [_met, seeds])
	T.finish(self)


func _load() -> Node:
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0 # long test: park the level timer
	var hs = lvl.hide_seek
	hs.hide_seconds = 1.0
	return lvl


## Wait until the phase leaves SEEKING (or `limit` seconds pass). Returns the seconds the search took.
func _wait_end(hs, limit: float) -> float:
	var t := 0.0
	while hs.phase == hs.Phase.HIDING and t < 20.0:
		await physics_frame
		t += 1.0 / 60.0
	var t0 := t
	while hs.phase == hs.Phase.SEEKING and t - t0 < limit:
		await physics_frame
		t += 1.0 / 60.0
	return t - t0


func _stall_pos(lvl: Node, i: int) -> Vector3:
	var door: Node3D = lvl.stalls.doors[i]
	var inward := Vector3(0.0, 0.0, -1.0) if i < 10 else Vector3(0.0, 0.0, 1.0)
	return Vector3(door.point.x, 0.05, door.point.z) + inward * 0.6


func _hidden(s: int) -> void:
	var lvl := await _load()
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	var i := randi_range(0, 19)
	var tag := "seed %d hidden in stall %d (empty %d)" % [s, i, hs.empty_stall]
	p.global_position = _stall_pos(lvl, i)
	lvl.stalls.doors[i].set_open(false, 0.01)
	if i != hs.empty_stall:
		hs.shushed[i] = true
	await hs.hop(i)
	T.check(hs.hidden_in == i, "%s: Bob is up" % tag)
	var took: float = await _wait_end(hs, 120.0)
	T.check(hs.seekers.size() == 9 + lvl.population.walkers.size(), "%s: every queue Jijio and walker seeks (%d)" % [tag, hs.seekers.size()])
	T.check(hs.phase == hs.Phase.OVER, "%s: the search ended without finding Bob (phase %d, %.1f s)" % [tag, hs.phase, took])
	T.check(hs.checked.size() == 20, "%s: all 20 stalls were checked (%d)" % [tag, hs.checked.size()])
	var peeks: int = hs.peeks.get(i, 0)
	if peeks >= 1:
		_met += 1
	T.check(peeks >= 1, "%s: a seeker really peeked at Bob's stall (%d times)" % [tag, peeks])
	T.check(hs.catches == 0, "%s: never caught" % tag)
	T.check(lvl.get_node("MissionManager").is_done("hide"), "%s: the mission 'hide' is done" % tag)
	await T.wait(self, 1.0)
	T.check(hs.hidden_in == -1 and p.global_position.y < 0.05 and not p.hiding, "%s: Bob is back on the floor (y %.2f)" % [tag, p.global_position.y])
	if phase_ok(hs):
		_times.append(took)
	lvl.queue_free()
	await process_frame
	await physics_frame


func phase_ok(hs) -> bool:
	return hs.phase == hs.Phase.OVER


func _floor(s: int) -> void:
	var lvl := await _load()
	var hs = lvl.hide_seek
	var i := randi_range(0, 19)
	var tag := "seed %d on the floor of stall %d" % [s, i]
	lvl.player.global_position = _stall_pos(lvl, i)
	lvl.stalls.doors[i].set_open(false, 0.01)
	await T.wait(self, 0.2)
	T.check(hs.feet_visible(i), "%s: his feet show" % tag)
	var took: float = await _wait_end(hs, 120.0)
	T.check(hs.phase == hs.Phase.CAUGHT, "%s: caught (phase %d after %.1f s)" % [tag, hs.phase, took])
	T.check(hs.catches == 1 and hs.caught_mode == "peek" and hs.caught_stall == i, "%s: by a peek at that stall (mode '%s', stall %d, %d catches)" % [tag, hs.caught_mode, hs.caught_stall, hs.catches])
	T.check(lvl._game_over and not lvl._running, "%s: the level is over (timer stopped)" % tag)
	lvl.queue_free()
	await process_frame
	await physics_frame


func _open(s: int) -> void:
	var lvl := await _load()
	var hs = lvl.hide_seek
	var tag := "seed %d in the corridor" % s
	lvl.player.global_position = Vector3(randf_range(3.0, 8.0), 0.05, 0.05)
	await T.wait(self, 0.2)
	var took: float = await _wait_end(hs, 60.0)
	T.check(hs.phase == hs.Phase.CAUGHT and hs.caught_mode == "sight", "%s: seen by a seeker (phase %d, mode '%s', %.1f s)" % [tag, hs.phase, hs.caught_mode, took])
	lvl.queue_free()
	await process_frame
	await physics_frame
