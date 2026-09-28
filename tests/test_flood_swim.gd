extends SceneTree
## Level 2 "The flood": swimming and floating (SPEC Round 2 Stage 3), in the real level with the real rampage, real time, walkers on.
## Wading slows Bob down; deep water: he swims at SWIM_SPEED (Shift faster), his head stays out, he cannot sink; every Jijio (queue,
## walkers, the 20 stall occupants) floats at the surface, the occupants inside their stalls; a swim route through the waiting room, both
## corridors and the east end never gets stuck on the floating crowd (counted: how often a floating Jijio was within 0.8 m of Bob).
## After the drain: Bob stands, the occupants sit again, the queue is back on its spots, the walkers have their jobs back.
## Every frame: Bob above the floor, and when the water is deep his root at the float line and the camera above the surface.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

## Through the middle of each open area (a straight line from the corridor to the east end clipped the stall block's corner).
const ROUTE: Array[Vector3] = [Vector3(-1.2, 0.0, 0.3), Vector3(1.0, 0.0, 0.05), Vector3(11.4, 0.0, 0.05), Vector3(11.4, 0.0, -2.5),
	Vector3(11.4, 0.0, -5.25), Vector3(1.4, 0.0, -5.25), Vector3(11.4, 0.0, -5.25), Vector3(11.4, 0.0, -2.5), Vector3(11.4, 0.0, 0.05),
	Vector3(1.0, 0.0, 0.05), Vector3(-1.2, 0.0, 0.3), Vector3(-4.2, 0.0, -1.5)]

var _bad := 0
var _note := ""
var _near := 0
var _ducks := 0 ## frames Bob ducked under a low ceiling (the lintel between the waiting room and the toilet)
var _wants: Array[float] = []
var _swim_frames := 0 ## deep-water frames Bob was moving (should play `swim`) ...
var _tread_frames := 0 ## ... and still (`tread_water`)
var _clip_bad := 0
var _clip_note := ""
var _npc_frames := 0 ## floating-Jijio frames checked
var _seated_frames := 0 ## ... of them occupants that floated up from their seat
var _npc_bad := 0
var _npc_note := ""
var _splash_count := 0 ## Sfx.count("swim") last frame
var _splashes := 0 ## stroke splashes heard while `swim` played
var _splash_bad := 0 ## ... not at the clip's stroke phase
var _splash_note := ""
const Sfx := preload("res://scripts/sfx.gd")
const DUCK_MAX := 0.3 ## m: the lintel at 2.1 m needs a 0.21 m dip at full depth; never deeper than this


func _check_frame(lvl: Node) -> void:
	var p: CharacterBody3D = lvl.player
	var w: Node3D = lvl.water
	if p.global_position.y < -0.05:
		_bad += 1
		_note = "Bob below the floor (%.2f)" % p.global_position.y
	if w.depth > p.FLOAT_DEPTH + 0.1 and not p.diving:
		var want: float = p.float_target(p.auto_move) # the float line, or lower while ducking under the 2.1 m lintel
		if want < w.surface_y() - p.FLOAT_DEPTH - 0.01:
			_ducks += 1
		# at the float line, or ducking by up to DUCK_MAX under it (the lintel: 0.2 m) and coming back up
		var line: float = w.surface_y() - p.FLOAT_DEPTH
		_wants.append(want) # he eases back up after a duck (about 0.1 s for half the gap): compare with the lowest target of the last 0.5 s
		if _wants.size() > 30:
			_wants.pop_front()
		var lowest: float = _wants.min()
		if p.global_position.y > line + 0.12 or p.global_position.y < minf(lowest, line) - 0.12 or p.global_position.y < line - DUCK_MAX:
			_bad += 1
			_note = "Bob y %.2f, float line %.2f" % [p.global_position.y, want]
		var cam := get_root().get_camera_3d()
		if cam.global_position.y < w.surface_y() + 0.1:
			_bad += 1
			_note = "camera %.2f, surface %.2f" % [cam.global_position.y, w.surface_y()]
	for npc: Node3D in lvl.population.queue + lvl.population.walkers:
		if npc.floating and Vector2(npc.global_position.x - p.global_position.x, npc.global_position.z - p.global_position.z).length() < 0.8:
			_near += 1
	# the factory swim clips (origin = the water surface): Bob swims moving / treads water still, his face out of the water
	if p.swimming and not p.diving and w.depth > p.SWIM_DEPTH + 0.05:
		var clip := T.clip_of(p.model())
		var hspeed := Vector2(p.velocity.x, p.velocity.z).length()
		var head := T.bone_at(p.model(), "DEF-spine.006").y
		if hspeed > 0.5:
			_swim_frames += 1
		elif hspeed < 0.1:
			_tread_frames += 1
		if (hspeed > 0.5 and clip != "swim") or (hspeed < 0.1 and clip != "tread_water") or head < w.surface_y() - 0.03:
			_clip_bad += 1
			_clip_note = "Bob clip %s at %.1f m/s, head bone %.2f, surface %.2f" % [clip, hspeed, head, w.surface_y()]
		# Stage 6: the stroke splash is synced to the `swim` clip (at the hands' high point, player.gd SWIM_SPLASH_PHASE)
		var splashes := Sfx.count("swim")
		if splashes > _splash_count and clip == "swim":
			_splashes += 1
			var ap: AnimationPlayer = p.model().find_child("AnimationPlayer", true, false)
			var phase := fposmod(ap.current_animation_position / ap.current_animation_length - p.SWIM_SPLASH_PHASE + 0.5, 1.0) - 0.5
			if absf(phase) > 0.07:
				_splash_bad += 1
				_splash_note = "a splash at clip phase %.2f" % (ap.current_animation_position / ap.current_animation_length)
		_splash_count = splashes
	# every floating Jijio: queue + walkers panic, stall occupants tread water or float on the back; the head at the surface
	if w.depth > p.SWIM_DEPTH + 0.05:
		for npc: Node3D in lvl.population.queue + lvl.population.walkers + lvl.population.occupants:
			if not npc.floating:
				continue
			_npc_frames += 1
			var clip := T.clip_of(npc._model)
			var ok_clips: Array = ["tread_water", "float"] if npc._float_was_sitting else ["swim_panic"] # the clogger ran out: it panics
			if npc in lvl.population.occupants and npc._float_was_sitting:
				_seated_frames += 1
			var head := T.bone_at(npc._model, "DEF-spine.006").y
			if not clip in ok_clips or head < w.surface_y() - 0.12:
				_npc_bad += 1
				_npc_note = "%s clip %s, head bone %.2f, surface %.2f" % [npc.name, clip, head, w.surface_y()]


func _wait(lvl: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		_check_frame(lvl)
		t += 1.0 / 60.0


func _speed(lvl: Node, sprint: bool) -> float:
	var p: CharacterBody3D = lvl.player
	if sprint:
		Input.action_press("sprint")
	Input.action_press("move_forward")
	await _wait(lvl, 0.5)
	var a := p.global_position
	await _wait(lvl, 0.5)
	var v := Vector2(p.global_position.x - a.x, p.global_position.z - a.z).length() / 0.5
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait(lvl, 0.3)
	return v


func _init() -> void:
	seed(21)
	Progress.level = T.FLOOD_LEVEL
	var lvl := T.level(self, true)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var w: Node3D = lvl.water
	var story: Node3D = lvl.flood_story
	var pop = lvl.population
	var homes := {}
	for npc: Node3D in pop.queue:
		homes[npc] = npc.home
	var seats := {}
	for i in pop.occupants.size():
		if i != story.stall:
			seats[pop.occupants[i]] = pop.occupants[i].global_position
	T.check(pop.walkers.size() >= 2, "walkers are on (%d)" % pop.walkers.size())
	# wading: corridor B, water about 0.45 m
	await T.wait_for(self, func() -> bool: return w.depth >= 0.45, 60.0)
	p.global_position = Vector3(2.0, 0.05, -5.25)
	p.set_facing(-PI / 2.0) # east along corridor B
	await _wait(lvl, 0.3)
	var wade_expect: float = p.walk_speed * lerpf(1.0, p.WADE_SLOWEST, clampf((w.depth - p.WADE_START) / (p.SWIM_DEPTH - p.WADE_START), 0.0, 1.0))
	var v_wade: float = await _speed(lvl, false)
	T.check(absf(v_wade - wade_expect) < 0.25 and not p.swimming, "wading in %.2f m of water Bob walks slower: %.2f m/s (expected %.2f, dry %.1f; at %s busy %s frozen %s slip %.1f)" % [w.depth, v_wade, wade_expect, p.walk_speed, str(p.global_position.snappedf(0.01)), p.busy, p.frozen, p.slip_left])
	# deep water: everyone floats
	await T.wait_for(self, func() -> bool: return w.depth >= 1.2, 60.0)
	await _wait(lvl, 1.5)
	var sinkers: Array[String] = []
	var off_line := 0.0
	for npc: Node3D in pop.queue + pop.walkers + pop.occupants:
		if not npc.floating:
			sinkers.append(npc.name)
		else:
			off_line = maxf(off_line, absf(npc.global_position.y - (w.surface_y() - npc.FLOAT_DEPTH)))
	T.check(sinkers.is_empty(), "in %.2f m of water all %d Jijios float (not floating: %s)" % [w.depth, pop.queue.size() + pop.walkers.size() + pop.occupants.size(), str(sinkers)])
	T.check(off_line < 0.12, "each floats at the water line, the surface at their shoulders (worst %.2f m off)" % off_line)
	var strays := 0
	for npc: Node3D in seats:
		var s: Vector3 = seats[npc]
		if Vector2(npc.global_position.x - s.x, npc.global_position.z - s.z).length() > 0.3:
			strays += 1
	T.check(strays == 0, "the 19 stall occupants float up inside their stalls (%d drifted out)" % strays)
	var on_back := 0
	for npc: Node3D in seats:
		if T.clip_of(npc._model) == "float":
			on_back += 1
	T.check(on_back >= 2 and on_back <= 9, "about 1 in 4 stall occupants floats on the back (%d of %d)" % [on_back, seats.size()])
	T.check(p.swimming, "Bob swims")
	p.global_position = Vector3(2.0, w.depth - p.FLOAT_DEPTH, -5.25)
	p.set_facing(-PI / 2.0)
	await _wait(lvl, 0.5)
	var v_swim: float = await _speed(lvl, false)
	var v_fast: float = await _speed(lvl, true)
	T.check(absf(v_swim - p.SWIM_SPEED) < 0.25 and absf(v_fast - p.SWIM_SPRINT) < 0.3, "swimming %.2f m/s, with Shift %.2f m/s (expected %.1f / %.1f)" % [v_swim, v_fast, p.SWIM_SPEED, p.SWIM_SPRINT])
	# the swim route, all areas, back through the floating queue
	p.global_position = Vector3(-3.7, w.depth - p.FLOAT_DEPTH, 0.4)
	await _wait(lvl, 0.3)
	var stuck := ""
	var route_time := 0.0
	for target in ROUTE:
		var best := INF
		var since_better := 0.0
		var leg := 0.0
		while Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length() > 0.45:
			var to := Vector3(target.x - p.global_position.x, 0.0, target.z - p.global_position.z).normalized()
			p.auto_move = to
			await _wait(lvl, 1.0 / 60.0)
			route_time += 1.0 / 60.0
			leg += 1.0 / 60.0
			var d := Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length()
			if d < best - 0.2:
				best = d
				since_better = 0.0
			else:
				since_better += 1.0 / 60.0
			if since_better > 2.0 or leg > 15.0: # no real progress for 2 s: stuck (jittering against something counts)
				stuck = "stuck on the way to %s at %s" % [str(target), str(p.global_position)]
				break
		if stuck != "":
			break
	p.auto_move = Vector3.ZERO
	T.check(stuck == "", "the swim route through the waiting room, both corridors and the east end (%.0f s) never gets stuck %s" % [route_time, stuck])
	T.check(_near > 30, "the route really met the floating crowd: a floating Jijio within 0.8 m of Bob on %d frames" % _near)
	print("INFO  route %.0f s, floating Jijio within 0.8 m on %d frames, ducking on %d frames, water %.2f m" % [route_time, _near, _ducks, w.depth])
	T.check(_clip_bad == 0 and _swim_frames > 300 and _tread_frames > 30, "every deep-water frame: Bob plays swim moving (%d frames) and tread_water still (%d), his head bone above the surface (%d bad: %s)" % [_swim_frames, _tread_frames, _clip_bad, _clip_note])
	# one splash per stroke: _swim_frames / 60 s at up to 2 x 1.2 s cycles; at least one per 1.2 s of swimming
	T.check(_splashes >= _swim_frames / 72 and _splash_bad == 0, "the stroke splash is synced to the swim clip: %d splashes in %d swim frames, %d off the stroke phase (%s)" % [_splashes, _swim_frames, _splash_bad, _splash_note])
	T.check(_npc_bad == 0 and _npc_frames > 3000 and _seated_frames > 1000, "every floating-Jijio frame (%d, %d of them seated occupants): queue + walkers swim_panic, occupants tread_water / float, head at the surface (%d bad: %s)" % [_npc_frames, _seated_frames, _npc_bad, _npc_note])
	T.check(_ducks > 0 and w.depth > 1.5, "the route went under the doorway's lintel in deep water (%.2f m) and Bob ducked there (%d frames)" % [w.depth, _ducks])
	# drain: switch everything off by the code (the key presses are test_flood_tasks)
	for id in ["toilet"] + story.sinks.map(func(k: int) -> String: return "sink%d" % k):
		w.remove_source(id)
	story.clogged = false
	story.taps_on.clear()
	T.check(w.start_drain(story.DRAIN_POS), "the plug comes out")
	await _wait(lvl, w.DRAIN_SECONDS + 2.0)
	T.check(w.depth == 0.0 and p.is_on_floor() and absf(p.global_position.y) < 0.1, "drained: Bob stands on the floor (y %.2f)" % p.global_position.y)
	var still_floating := 0
	for npc: Node3D in pop.queue + pop.walkers + pop.occupants:
		if npc.floating:
			still_floating += 1
	T.check(still_floating == 0, "nobody floats any more (%d still do)" % still_floating)
	var not_seated := 0
	for npc: Node3D in seats:
		var s: Vector3 = seats[npc]
		if not npc.is_sitting() or npc.global_position.distance_to(s) > 0.05:
			not_seated += 1
	T.check(not_seated == 0, "the stall occupants sit on their toilets again (%d not)" % not_seated)
	var trace := {} # per queue Jijio: its state and position each second (the diagnostic when one never gets home)
	for sec in 25:
		await _wait(lvl, 1.0)
		for npc: Node3D in pop.queue:
			trace[npc] = str(trace.get(npc, "")) + " %d:%s" % [npc.state, str(Vector2(npc.global_position.x, npc.global_position.z).snappedf(0.1))]
	var away: Array[String] = []
	for npc: Node3D in pop.queue:
		var h: Vector3 = homes[npc]
		if Vector2(npc.global_position.x - h.x, npc.global_position.z - h.z).length() > 0.35 or npc.state != npc.State.QUEUED:
			away.append("%s %.1f m (state %d, at %s, home %s, walking %s)" % [npc.name, Vector2(npc.global_position.x - h.x, npc.global_position.z - h.z).length(),
				npc.state, str(npc.global_position.snappedf(0.01)), str(h), npc.is_walking()])
			print("TRACE %s (Bob at %s):%s" % [npc.name, str(p.global_position.snappedf(0.1)), trace[npc]])
	T.check(away.is_empty(), "25 s later the queue is back on its spots (away: %s)" % str(away))
	var busy_walkers := 0
	for npc: Node3D in pop.walkers:
		if npc.is_walking() or npc.is_washing():
			busy_walkers += 1
	T.check(not lvl.get_node("Walkers")._stopped and busy_walkers >= 1, "the walkers have their jobs back (%d walking or washing)" % busy_walkers)
	T.check(_bad == 0, "every frame: Bob above the floor, at the float line in deep water, the camera above the surface (%d bad: %s)" % [_bad, _note])
	lvl.queue_free()
	await process_frame
	T.finish(self)
