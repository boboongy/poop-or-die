extends Node
## Walking Jijios: 2 to 6 per level (random), each with one job for the whole level, also random:
##  - "wash": walk to a free sink, wash hands 8-14 s with the tap running, dry off, go to another sink, repeat
##  - "pace": walk back and forth 2.5-4 m along one corridor, pausing at each end
##  - "walk": stroll between waypoints along both corridors and round the east end that joins them
## Only in the walkways inside the toilet, never in the waiting room; the queue and stall occupants stay as they are.
## When Bob walks toward one, it steps to the corridor wall so the 1.4 m corridors are never blocked.
## Bob can talk to them (E): a random line, then a hint about the level. At the timeout they run to Bob and kick him.
## ("Sitting" walkers are undecided, see SPEC.md.)

const LevelDefs := preload("res://scripts/level_defs.gd")

static var enabled := true ## tests switch this off so a walker cannot wander into an unrelated test

const MIN_WALKERS := 2
const MAX_WALKERS := 6
const JOBS: Array[String] = ["wash", "pace", "walk"]

## Measured from the baked navmesh (2026-09-21): corridor A (front) z -0.65..0.75, corridor B (back) z -6.05..-4.45,
## both walled on both sides for x 1.2..9.8 and open to the east end (x > 9.8) that joins them. The bands are where a
## walker may stand to make room (a little inside the navmesh edge).
const CORRIDOR_A_Z := Vector2(-0.55, 0.65)
const CORRIDOR_B_Z := Vector2(-5.95, -4.55)
const CORRIDOR_X := Vector2(1.2, 9.8)
const A_CENTER_Z := 0.05
const B_CENTER_Z := -5.25
const WAYPOINTS: Array[Vector3] = [
	Vector3(2.0, 0.0, 0.05), Vector3(6.0, 0.0, 0.05), Vector3(9.5, 0.0, 0.05),
	Vector3(2.0, 0.0, -5.25), Vector3(6.0, 0.0, -5.25), Vector3(10.0, 0.0, -5.25),
	Vector3(11.4, 0.0, -2.6),
]
## NOT a waypoint: the west end of the corridors (x < 1, e.g. (0.5, -2.6)) is an isolated pocket of navmesh. The two
## corridors join ONLY at the east end, so the walkway is a U (A, east end, B), not a loop. A walker started in
## the pocket never gets out (found by test_walkers, 2026-09-21).
const GO_TIMEOUT := 30.0 ## seconds a walk may take before the walker gives up and picks something else
## Door fronts (owner 2026-09-25: "the idle Jijio in the walkway blocks the door and Bob from moving past it or into the toilet"). Row-1
## doors are on corridor A's low-z wall (door line z -1.02), row-2 doors on corridor B's high-z wall (z -4.08); an open leaf reaches 0.65 m
## into the corridor. A walker must never stand still within DOOR_ZONE of a door line; the other wall (sinks in A, back wall in B) is free.
const DOOR_ZONE := 0.9
const ROW1_DOOR_Z := -1.02
const ROW2_DOOR_Z := -4.08
const PARK_Z_A := 0.45 ## where a parked walker waits in corridor A (the sink side, where washers stand)
const PARK_Z_B := -5.7 ## where a parked walker waits in corridor B (the back wall)
const CROSS_MIN := 1.6 ## m: a walker making way crosses to the door-free wall only while Bob is at least this far (never across his path)
const TALK_PRIORITY := -1.0 ## a walker's "E talk" loses to a stall door up to 1 m farther (it stole "E open door" even from 0.28 m BEHIND Bob, test_walker_doors)

const CHATTER := {
	"wash": ["These taps are freezing.", "I've been scrubbing for ages. Some smells just don't come off.", "Don't look at my hands. Wait, do look. They're very clean."],
	"pace": ["I'm not waiting for a stall. I'm just... walking. Around. Yes.", "Fourteen laps so far. Don't ask.", "Sorry, I can't stand still. Too much coffee."],
	"walk": ["Just stretching my legs. The queue isn't moving.", "Oh, hello. Nice corridor, isn't it?", "I lost my friend in here. Have you seen a Jijio? Never mind, everyone is a Jijio."],
}

var _level: Node3D
var _player: CharacterBody3D
var _sinks: Node3D
var _map: RID
var _nav_y := 0.0
var _stopped := false
var _hint := ""
var _jobs := {} ## walker -> job name
var _pace_points := {} ## pacing walker -> [end 0, end 1]
var _sink_owner := {} ## sink number -> the walker washing there (or walking there)
var _leave := {} ## walkers told to leave their sink
var _blocked_sink := 0 ## the sink the reward Jijio uses: nobody picks it, its tap is not switched off by walkers
var _forced_sink := {} ## walker -> sink it must use first (tests)
var _overflow_sinks := {} ## sink number -> true while it overflows (Level 2): nobody washes there and walkers never switch its tap off
var _parked := {} ## walker -> true while it waits on the door-free wall (Level 3's counting and after the search), see park()


## The random jobs for one level: MIN..MAX walkers, each "wash", "pace" or "walk".
static func plan() -> Array[String]:
	var out: Array[String] = []
	for i in randi_range(MIN_WALKERS, MAX_WALKERS):
		out.append(JOBS[randi() % JOBS.size()])
	return out


func setup(level: Node3D) -> void:
	_level = level
	_player = level.player
	_sinks = level.get_node("Sinks")
	_map = level.get_node("NavRegion").get_navigation_map()
	_nav_y = level.population.nav_height()
	level.population.walker_manager = self
	_hint = LevelDefs.get_level(level.level_number).get("walker_hint", "")
	if enabled:
		# The navmesh map only answers queries after its first synchronisation (a level reload keeps the old map,
		# so also give it two physics frames): snapping start points earlier returns garbage.
		await get_tree().physics_frame
		await get_tree().physics_frame
		while NavigationServer3D.map_get_iteration_id(_map) == 0:
			await get_tree().physics_frame
		spawn(plan())


## Create one walker per job in `jobs` and start them. Returns the walkers (in the same order).
func spawn(jobs: Array) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var taken: Array[Vector3] = []
	for job in jobs:
		var start := _free_waypoint(taken)
		var pace := []
		if job == "pace":
			var cz := A_CENTER_Z if randf() < 0.5 else B_CENTER_Z
			var x0 := randf_range(1.6, 6.0)
			pace = [Vector3(x0, 0.0, cz), Vector3(x0 + randf_range(2.5, 4.0), 0.0, cz)]
			start = pace[0]
		taken.append(start)
		start = _snap(start)
		var npc: Node3D = _level.population.spawn_walker(start, randf() * TAU)
		_jobs[npc] = job
		if job == "pace":
			_pace_points[npc] = pace
		npc.set_interaction("E  talk", _talk.bind(npc))
		npc.priority = TALK_PRIORITY
		made.append(npc)
		_run(npc, job)
	return made


## A washer whose first sink is `sink` (tests use this; the game picks sinks at random).
func spawn_washer_at(sink: int) -> Node3D:
	var made := spawn(["wash"])
	_forced_sink[made[0]] = sink
	return made[0]


## Forget every walker (tests use this to set up a known scene).
func clear() -> void:
	_stopped = true
	stop_all()
	for npc in _level.population.walkers.duplicate():
		_level.population.remove_walker(npc)
	_jobs.clear()
	_pace_points.clear()
	await get_tree().physics_frame
	_stopped = false


func job_of(npc: Node3D) -> String:
	return _jobs.get(npc, "")


## The timeout: nobody keeps their route. Taps off, arms down, no more talking.
func stop_all() -> void:
	_stopped = true
	for k: int in _sink_owner.keys():
		var npc: Node3D = _sink_owner[k]
		if is_instance_valid(npc):
			npc.stop_washing()
		if k != _blocked_sink and not _overflow_sinks.has(k):
			_sinks.set_running(k, false)
	_sink_owner.clear()
	for npc: Node3D in _level.population.walkers:
		npc.stop_walking()
		npc.stop_washing()
		npc.clear_interaction()


## Level 2 after the flood drains: every walker takes up its job again (stop_all() ended their routes when the rampage began).
func resume_all() -> void:
	_stopped = false
	for npc: Node3D in _level.population.walkers:
		npc.set_interaction("E  talk", _talk.bind(npc))
		npc.priority = TALK_PRIORITY
		_run(npc, _jobs.get(npc, "walk"))


## Level 3's counting phase: every walker drops its job and waits on the door-free wall of its corridor (it used to freeze where it
## stood, often right in front of a stall door, for the whole 20 s Bob has to hide).
func park_all() -> void:
	stop_all()
	for npc: Node3D in _level.population.walkers:
		park(npc)


## One walker waits on the door-free wall (Level 3 after the search, too). It keeps out of the door fronts and makes way along the
## wall when Bob walks into it. Ends with unpark() / unpark_all() (the seekers are then driven by hide_seek.gd).
func park(npc: Node3D) -> void:
	if _parked.has(npc):
		return
	_parked[npc] = true
	_park_loop(npc)


func unpark_all() -> void:
	_parked.clear()


func is_parked(npc: Node3D) -> bool:
	return _parked.has(npc)


## True if `pos` is in front of a stall door (within DOOR_ZONE of a door line, inside a corridor).
static func in_door_zone(pos: Vector3) -> bool:
	if pos.x < CORRIDOR_X.x - 0.5 or pos.x > CORRIDOR_X.y + 0.8:
		return false
	return (pos.z > ROW1_DOOR_Z - 0.1 and pos.z < ROW1_DOOR_Z + DOOR_ZONE) or (pos.z < ROW2_DOOR_Z + 0.1 and pos.z > ROW2_DOOR_Z - DOOR_ZONE)


func _park_spot(pos: Vector3) -> Vector3:
	var band := _band(pos)
	if band == CORRIDOR_A_Z:
		return _snap(Vector3(pos.x, 0.0, PARK_Z_A))
	if band == CORRIDOR_B_Z:
		return _snap(Vector3(pos.x, 0.0, PARK_Z_B))
	if in_door_zone(pos): # the ends of the corridors, just outside the band
		return _snap(Vector3(pos.x, 0.0, PARK_Z_A if pos.z > -2.5 else PARK_Z_B))
	return pos


## Untyped `npc` (see _alive): the level can be freed while this runs.
func _park_loop(npc) -> void:
	var spot := _park_spot(npc.global_position)
	if spot.distance_to(npc.global_position) > 0.1:
		npc.go_to(spot)
	var pushed := 0.0
	while is_instance_valid(npc) and npc.is_inside_tree() and _parked.has(npc):
		await get_tree().physics_frame
		if not (is_instance_valid(npc) and npc.is_inside_tree() and _parked.has(npc)):
			return
		if npc.is_walking() or npc.is_slipping():
			continue
		if in_door_zone(npc.global_position):
			npc.go_to(_park_spot(npc.global_position))
			continue
		# Bob right against it and still pushing: shuffle 0.9 m along the wall, away from him.
		var to := Vector2(npc.global_position.x - _player.global_position.x, npc.global_position.z - _player.global_position.z)
		var pushing := to.length() < 0.75 and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.3
		pushed = pushed + get_physics_process_delta_time() if pushing else 0.0
		if pushed > 0.25:
			pushed = 0.0
			var side := signf(to.x) if absf(to.x) > 0.05 else 1.0
			npc.go_to(_snap(npc.global_position + Vector3(side * 0.9, 0.0, 0.0)))


## Level 2: `sink` overflows. A walker washing or heading there moves on; from now on nobody picks it and its tap is left alone.
func block_sink(sink: int) -> void:
	_overflow_sinks[sink] = true
	var owner_npc: Node3D = _sink_owner.get(sink)
	if owner_npc != null:
		_leave[owner_npc] = true


func unblock_sink(sink: int) -> void:
	_overflow_sinks.erase(sink)


## The reward Jijio is about to use `sink`: a walker washing or heading there moves on and the tap stays as it is.
func evict(sink: int) -> void:
	_blocked_sink = sink
	var owner_npc: Node3D = _sink_owner.get(sink)
	if owner_npc != null:
		_leave[owner_npc] = true


## The walker helpers below take an UNTYPED `npc` on purpose: their coroutines keep running for a frame after the
## walker is freed (clear(), a level reload), and a typed parameter errors on a freed object. Every `await` is
## followed by an _alive() check before the walker is touched again.
func _alive(npc) -> bool:
	return not _stopped and is_instance_valid(npc) and not npc.is_queued_for_deletion() and npc.is_inside_tree()


func _run(npc, job: String) -> void:
	await get_tree().physics_frame # let the level finish loading
	while _alive(npc):
		match job:
			"wash":
				await _wash_once(npc)
			"pace":
				await _pace_once(npc)
			_:
				await _stroll_once(npc)


func _pace_once(npc) -> void:
	var ends: Array = _pace_points[npc]
	await _go(npc, ends[1])
	await _wait(npc, randf_range(0.8, 2.2))
	if not _alive(npc):
		return
	await _go(npc, ends[0])
	await _wait(npc, randf_range(0.8, 2.2))


func _stroll_once(npc) -> void:
	await _go(npc, _far_waypoint(npc))
	await _wait(npc, randf_range(0.5, 2.0))


## A random waypoint at least 2.5 m from the walker (8 tries).
func _far_waypoint(npc) -> Vector3:
	var target: Vector3 = WAYPOINTS[randi() % WAYPOINTS.size()]
	for i in 8:
		if target.distance_to(npc.global_position) >= 2.5:
			break
		target = WAYPOINTS[randi() % WAYPOINTS.size()]
	return target


## Walk to a free sink, wash for a while, dry off. Leaves at once if evicted (the reward Jijio needs the sink).
func _wash_once(npc) -> void:
	var k := _pick_sink()
	if _forced_sink.has(npc):
		k = _forced_sink[npc]
		_forced_sink.erase(npc)
	if k == 0:
		await _wait(npc, 2.0)
		return
	_sink_owner[k] = npc
	var spot: Vector3 = _sinks.stand_spot(k)
	var arrived := await _go(npc, spot, true, true)
	if arrived and _alive(npc) and not _leave.has(npc):
		var settle := create_tween() # step exactly in front of the basin, like the reward Jijio
		settle.tween_property(npc, "global_position", spot, 0.25)
		await settle.finished
		if _alive(npc):
			npc.start_washing(0.0)
			_sinks.set_running(k, true)
			var t := 0.0
			var length := randf_range(8.0, 14.0)
			while _alive(npc) and t < length and not _leave.has(npc):
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
			if is_instance_valid(npc):
				npc.stop_washing()
			if _blocked_sink != k and not _overflow_sinks.has(k) and _sink_owner.get(k) == npc:
				_sinks.set_running(k, false)
	if _sink_owner.get(k) == npc:
		_sink_owner.erase(k)
	var was_evicted := _leave.has(npc)
	_leave.erase(npc)
	if not _alive(npc):
		return
	if was_evicted:
		# away from the reward Jijio's sink: a FAR waypoint (a random one could be next to the sink: the walker stopped 0.41 m from the
		# reward Jijio's spot, test_walkers sink 5, 2026-09-27)
		await _go(npc, _far_waypoint(npc))
	await _wait(npc, randf_range(1.0, 2.5)) # drying hands


func _pick_sink() -> int:
	var free: Array[int] = []
	for k in range(1, 11):
		if k != _blocked_sink and not _overflow_sinks.has(k) and not _sink_owner.has(k):
			free.append(k)
	return free[randi() % free.size()] if not free.is_empty() else 0


## Walk to `target`. True on arrival, false if the walk was stopped, timed out, or (for a sink walk) the walker was evicted.
func _go(npc, target: Vector3, allow_yield := true, to_sink := false) -> bool:
	if not _alive(npc):
		return false
	var goal := _snap(target)
	npc.stop_washing()
	npc.go_to(goal)
	var waited := 0.0
	while _alive(npc):
		await get_tree().physics_frame
		if not _alive(npc):
			return false
		if to_sink and _leave.has(npc):
			npc.stop_walking()
			return false
		if npc.is_slipping():
			continue # fell on the wet floor: the route carries on by itself once they are up
		if not npc.is_walking() and not npc.talking:
			return true
		if not npc.talking:
			waited += get_physics_process_delta_time()
		if waited > GO_TIMEOUT:
			npc.stop_walking()
			return false
		if allow_yield and _bob_coming(npc):
			await _step_aside(npc)
			if _alive(npc):
				npc.go_to(goal)
	return false


func _wait(npc, seconds: float) -> void:
	var t := 0.0
	while _alive(npc) and t < seconds:
		await get_tree().physics_frame
		if not _alive(npc):
			return
		t += get_physics_process_delta_time()
		if _bob_coming(npc):
			await _step_aside(npc)


## Bob is close and walking toward this walker (or right next to it), inside a corridor.
func _bob_coming(npc) -> bool:
	if npc.talking or _band(npc.global_position) == Vector2.ZERO:
		return false
	var to: Vector3 = _player.global_position - npc.global_position
	to.y = 0.0
	var d: float = to.length()
	if d > 2.4:
		return false
	var v := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if d < 1.1:
		return v.length() > 0.3 # right next to him: only while he moves (a still Bob is walked round)
	return v.length() > 0.5 and v.normalized().dot(-to / d) > 0.3


## Walk to the corridor wall farthest from Bob and wait there until he has passed (or stopped) or 8 s are up.
func _step_aside(npc) -> void:
	if not _alive(npc):
		return
	var band := _band(npc.global_position)
	if band == Vector2.ZERO:
		return
	var mid := (band.x + band.y) / 2.0
	# Stay on the walker's OWN side of Bob and hug that wall: never cross his path (owner: "I can't move when Jijios block my way").
	# The old rule (the wall farthest from Bob) sent a walker across him whenever he was near the middle, and two walkers then
	# deadlocked with him in a 1.6 m corridor (test_walkers_stress, seed 103). Exactly level with him: the farthest wall.
	var dz: float = npc.global_position.z - _player.global_position.z
	var edge := band.y if dz > 0.0 else band.x
	if absf(dz) <= 0.05:
		edge = band.x if _player.global_position.z > mid else band.y
	# The door-free wall when that does not cross Bob's path now: a walker hugging the door wall stood in the door's way.
	var free_edge := band.y if band == CORRIDOR_A_Z else band.x
	var bob_d := Vector2(npc.global_position.x - _player.global_position.x, dz).length()
	if edge != free_edge and bob_d >= CROSS_MIN:
		edge = free_edge
	npc.stop_washing()
	npc.go_to(_snap(Vector3(npc.global_position.x, 0.0, edge)))
	var t := 0.0
	var still := 0.0
	while _alive(npc) and t < 8.0:
		await get_tree().physics_frame
		if not _alive(npc):
			return
		var dt := get_physics_process_delta_time()
		t += dt
		var d := Vector2(npc.global_position.x - _player.global_position.x, npc.global_position.z - _player.global_position.z).length()
		# Waiting on the door wall right where Bob is: he may want THAT door. Slide 1 m along the wall, away from him.
		var dx: float = npc.global_position.x - _player.global_position.x
		if not npc.is_walking() and in_door_zone(npc.global_position) and absf(dx) < 0.9 and d < CROSS_MIN:
			npc.go_to(_snap(Vector3(_player.global_position.x + (1.0 if dx >= 0.0 else -1.0) * 1.3, 0.0, npc.global_position.z)))
		var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
		still = still + dt if speed < 0.3 else 0.0
		# Bob stood still 2 s and the walker is at its wall spot: carry on (it stood frozen 8 s next to a still Bob, test_walkers 2026-09-28)
		if d > 3.0 or (still > 2.0 and (d > 1.2 or not npc.is_walking())):
			break


## The z range (wall to wall) of the corridor the point is in, or Vector2.ZERO in the open ends.
func _band(pos: Vector3) -> Vector2:
	if pos.x < CORRIDOR_X.x or pos.x > CORRIDOR_X.y:
		return Vector2.ZERO
	if pos.z > -1.0 and pos.z < 1.0:
		return CORRIDOR_A_Z
	if pos.z < -4.3 and pos.z > -6.3:
		return CORRIDOR_B_Z
	return Vector2.ZERO


## The nearest walkable floor point (y = 0: NPCs stand on the floor, the navmesh floats above it).
func _snap(p: Vector3) -> Vector3:
	var c := NavigationServer3D.map_get_closest_point(_map, Vector3(p.x, _nav_y, p.z))
	if c == Vector3.ZERO: # the map has not synchronised yet: keep the point as it is
		return Vector3(p.x, 0.0, p.z)
	return Vector3(c.x, 0.0, c.z)


func _free_waypoint(taken: Array[Vector3]) -> Vector3:
	var options: Array[Vector3] = []
	for w in WAYPOINTS:
		var spaced := true
		for t in taken:
			if w.distance_to(t) < 2.0:
				spaced = false
		if spaced:
			options.append(w)
	if options.is_empty():
		return WAYPOINTS[randi() % WAYPOINTS.size()]
	return options[randi() % options.size()]


func _talk(player: Node3D, npc: Node3D) -> void:
	if _stopped:
		return
	var d = _level.dialogue
	d.begin(npc, player)
	var lines: Array = CHATTER[_jobs.get(npc, "walk")]
	await d.say(npc, lines[randi() % lines.size()], true) # small talk: W/A/S/D or Esc leave it at once
	if _hint != "" and not d.cancelled:
		await d.say(npc, _hint, true)
	d.end(npc, player)
