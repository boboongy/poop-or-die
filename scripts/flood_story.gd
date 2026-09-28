extends Node3D
## Level 2 "The flood" (SPEC Round 2 Stage 3, plan approved 2026-09-27): the story and the tasks around flood_water.gd.
## setup(): a random stall is clogged (its Jijio is the "clogger"), 4 random sinks of 10 are picked. The intro (intro.gd "flood") plays
## the diarrhoea blast and the scream; start() (at GO) bursts the stall open, the water trickles out of it and the crowd (queue + walkers
## + the clogger) rampages: 4 of them run to the 4 sinks and slap the taps on (forced on by TAPS_FORCED_AT). Everyone floats once the
## water is deep (npc_jijio.gd `_float`).
## Tasks, any order: pick up the red plunger floating outside the stall and HOLD E at the toilet (PLUNGE_SECONDS); E at each running tap;
## then E at the drain in the waiting room, which only works when nothing runs. When the water is gone: the queue goes back, the walkers
## go back to their jobs, 4 leftover puddles (flood.gd start_residue) wait for the mop, which lies by the drain (flood_find_mop.gd).
## Deep water: every task starts with an automatic dive (Bob and the camera go under) and ends with him coming back up.

const Sfx := preload("res://scripts/sfx.gd")
const SimpleInteractable := preload("res://scripts/simple_interactable.gd")
const FloodScript := preload("res://scripts/flood.gd")
const SinksScript := preload("res://scripts/sinks.gd")
const MopProp := preload("res://scripts/mop_prop.gd")

signal started ## GO: the stall burst open, the rampage began
signal tap_on(sink: int)
signal unclogged
signal tap_closed(sink: int)
signal plug_pulled
signal drained

static var auto_start := true ## tests of the puddle/mop mechanics switch this off (t.gd `dry`): Level 2 then stays dry
static var force_stall := -1 ## tests: the clogged stall (0-19)
static var force_sinks: Array[int] = [] ## tests: the 4 sinks (1-10)

const DRAIN_POS := Vector3(-4.6, 0.0, -1.2) ## the free west part of the waiting room (the queue stands in the middle), 1.3 m behind Bob
const MOP_POS := Vector3(-4.6, 0.0, -0.2) ## 1 m from the drain, toward Bob's start
const PLUNGER_OUT := 0.8 ## m outside the clogged stall's door line
const PLUNGE_SECONDS := 3.0 ## holding E (progress is kept when E is let go)
const PUMPS := 4
const TAP_SECONDS := 0.5
const GLUG_DELAY := 0.35
const DIVE_DOWN := 0.5 ## s: under the water...
const DIVE_UP := 0.5 ## ... and back up
const DIVE_FLOOR_Y := 0.05 ## Bob's feet at the bottom of a dive
const RAMPAGE_RUN_SPEED := 3.4
const RAMPAGE_STAGGER := 0.07 ## s between one Jijio setting off and the next
const TAPS_FORCED_AT := 10.0 ## s after GO: a tap nobody reached comes on anyway
const RAMPAGE_SHOUTS := ["WHEEE!", "TURN IT ALL ON!"]
const SINK_FRONT_Z := 0.6 ## the basin's front edge, where it overflows onto the floor
const TAP_POINT_Z := 0.5 ## where Bob presses E for a tap
## Where the rampaging crowd runs to (the navmesh takes them round the walls): waiting room, both corridors, the east end.
const RAMPAGE_POINTS: Array[Vector3] = [
	Vector3(-4.5, 0.0, 1.4), Vector3(-1.0, 0.0, -1.5), Vector3(-3.2, 0.0, 0.8), Vector3(2.0, 0.0, 0.05), Vector3(5.0, 0.0, 0.05),
	Vector3(8.5, 0.0, 0.05), Vector3(11.3, 0.0, -1.2), Vector3(11.3, 0.0, -3.8), Vector3(8.0, 0.0, -5.25), Vector3(4.0, 0.0, -5.25),
	Vector3(1.6, 0.0, -5.25),
]
## The fourth leftover puddle: somewhere along the walkways, at least RESIDUE_GAP from the other three.
const RESIDUE_SPOTS: Array[Vector3] = [
	Vector3(2.4, 0.0, 0.05), Vector3(4.3, 0.0, 0.05), Vector3(6.2, 0.0, 0.05), Vector3(8.1, 0.0, 0.05), Vector3(11.3, 0.0, -1.0),
	Vector3(11.3, 0.0, -2.6), Vector3(11.3, 0.0, -4.2), Vector3(8.1, 0.0, -5.25), Vector3(6.2, 0.0, -5.25), Vector3(4.3, 0.0, -5.25),
	Vector3(2.4, 0.0, -5.25),
]
const RESIDUE_GAP := 2.6

var level: Node3D
var water: Node3D
var stall := -1
var sinks: Array[int] = []
var clogger: Node3D
var clogged := true
var plunge_progress := 0.0
var has_plunger := false
var plug_out := false
var is_drained := false
var is_started := false
var acting := false ## Bob is busy with a task (a dive, plunging, a tap, the plug)
var taps_on := {} ## sink -> true while it runs
var residue: Array[Node3D] = [] ## the leftover puddles (also in level.floods)

var _plunger: Node3D
var _plunger_spot: Node3D
var _toilet_spot: Node3D
var _seat := Vector3.ZERO
var _door_floor := Vector3.ZERO
var _out := Vector3.ZERO ## from the clogged stall's door into the corridor
var _tap_spots := {}
var _drain_spot: Node3D
var _plug: Node3D
var _toast: Label
var _toast_tween: Tween
var _overflow := {} ## sink -> falling-water particles over the basin's edge
var _trickle: CPUParticles3D
var _gurgle: AudioStreamPlayer3D
var _crowd: Array[Node3D] = []
var _go_time := 0.0


func setup(level_node: Node3D, water_node: Node3D) -> void:
	level = level_node
	water = water_node
	stall = force_stall if force_stall >= 0 else randi() % 20
	if force_sinks.size() == 4:
		sinks.assign(force_sinks)
	else:
		var all: Array = range(1, 11)
		all.shuffle()
		sinks.assign(all.slice(0, 4))
		sinks.sort()
	level.ctx["clogged"] = stall
	level.ctx["flood_sinks"] = sinks
	level.population.blocked_stalls.append(stall) # never the reward
	clogger = level.population.occupants[stall]
	_seat = clogger.global_position
	var door: Node3D = level.stalls.doors[stall]
	_door_floor = Vector3(door.point.x, 0.0, door.point.z)
	_out = Vector3(0.0, 0.0, 1.0 if stall < 10 else -1.0)
	_build_toilet_spot()
	_build_taps()
	_build_drain()
	_build_plunger()
	_build_toast()
	water.drained.connect(_on_drained)


## "stall 7 (row 1)"
func stall_text() -> String:
	return "stall %d (row %d)" % [stall % 10 + 1, 1 if stall < 10 else 2]


func sinks_text(only_running := true) -> String:
	var names: Array[String] = []
	for k in sinks:
		if not only_running or taps_on.has(k):
			names.append(str(k))
	return ", ".join(names)


## Taps Bob still has to turn off (running now, or not yet slapped on).
func taps_left() -> int:
	return sinks.size() - _taps_done


var _taps_done := 0


## The intro's blast: the clogger lets go (loud, wet), the door rattles.
func blast() -> void:
	Sfx.play_at(level, "diarrhoea", _seat + Vector3.UP * 0.6)
	var door: Node3D = level.stalls.doors[stall]
	var tw := create_tween()
	for i in 6:
		tw.tween_property(door, "rotation:y", 0.05 * (1.0 if i % 2 == 0 else -1.0), 0.06)
	tw.tween_property(door, "rotation:y", 0.0, 0.06)


## GO: the stall bursts open, the water trickles out, the crowd rampages.
func start() -> void:
	if is_started:
		return
	is_started = true
	_go_time = Time.get_ticks_msec() / 1000.0
	var walkers := level.get_node_or_null("Walkers")
	for k in sinks:
		if walkers != null:
			walkers.block_sink(k) # nobody washes there, and a walker never switches that tap off (at GO: a dry test level keeps all 10 sinks)
	var door: Node3D = level.stalls.doors[stall]
	door.set_open(true)
	water.add_source("toilet", _door_floor)
	_source_loop("toilet", _door_floor + Vector3.UP * 0.3, "trickle")
	_trickle.emitting = true
	_plunger.visible = true
	_plunger_spot.enabled = true
	started.emit()
	_rampage()


func _physics_process(_delta: float) -> void:
	if water == null:
		return
	for group: Array in [level.population.queue, level.population.occupants, level.population.walkers]:
		for npc: Node3D in group:
			if npc.water == null:
				npc.water = water
	# Walkers spawn a few frames after the level (they wait for the navmesh): one that appears after GO joins the rampage too (without
	# the intro GO came first, and a late walker kept its job and stood in Bob's way, test_flood_swim).
	if is_started and not is_drained:
		for npc: Node3D in level.population.walkers:
			if not _crowd.has(npc):
				var walkers := level.get_node_or_null("Walkers")
				if walkers != null:
					walkers.stop_all()
				_rampager(npc, level.player)
				_crowd.append(npc)
				if water.depth < water.SWIM_DEPTH:
					_run_about(npc)


func _process(_delta: float) -> void:
	if _plunger != null and not has_plunger and _plunger.is_inside_tree():
		var base := _door_floor + _out * PLUNGER_OUT
		_plunger.global_position = Vector3(base.x, maxf(water.depth, 0.0) - 0.06 + sin(Time.get_ticks_msec() / 400.0) * 0.02, base.z)
		_plunger_spot.point = Vector3(base.x, 0.0, base.z)
	for k: int in _overflow:
		var p: CPUParticles3D = _overflow[k]
		p.emitting = taps_on.has(k) and water.depth < 0.8 # once the basin is under water there is nothing to fall
	_trickle.emitting = is_started and clogged and water.depth < 0.25


# --- the rampage ------------------------------------------------------------------------------------------------------------------

func _rampage() -> void:
	var walkers := level.get_node_or_null("Walkers")
	if walkers != null:
		walkers.stop_all()
	_crowd.clear()
	for npc: Node3D in level.population.walkers:
		_crowd.append(npc)
	for npc: Node3D in level.population.queue:
		_crowd.append(npc)
	var player: Node3D = level.player
	for npc in _crowd:
		_rampager(npc, player)
	# 4 of them run to the 4 sinks: the walkers first (they are in the corridors), then the queue. Each sets off RAMPAGE_STAGGER after
	# the one before (all at once put their first steps and shouts on one frame: 0 dB in the recorded mix).
	for i in sinks.size():
		if i < _crowd.size():
			_slap(_crowd[i], sinks[i], i * RAMPAGE_STAGGER)
	# the clogger bursts out and joins in
	_clogger_out(player)
	for k in RAMPAGE_SHOUTS.size():
		get_tree().create_timer(0.6 + 1.1 * k, false).timeout.connect(func() -> void:
			if _crowd.size() > k * 3 and is_instance_valid(_crowd[k * 3]):
				level.dialogue.bubble(_crowd[k * 3], RAMPAGE_SHOUTS[k], 1.8))
	get_tree().create_timer(TAPS_FORCED_AT, false).timeout.connect(func() -> void:
		for k in sinks:
			if not taps_on.has(k) and not _tap_done_for(k):
				_tap_on(k))
	for i in _crowd.size():
		if not _is_slapper(_crowd[i]):
			_run_about(_crowd[i], i * RAMPAGE_STAGGER)


var _slappers := {} ## npc -> sink
var _closed := {} ## sink -> true once Bob turned it off


func _tap_done_for(k: int) -> bool:
	return _closed.has(k)


func _is_slapper(npc: Node3D) -> bool:
	return _slappers.has(npc)


func _rampager(npc: Node3D, player: Node3D) -> void:
	npc.stop_walking()
	npc.walk_speed = RAMPAGE_RUN_SPEED
	npc.add_collision_exception_with(player) # a running crowd never pins Bob in a 2 m corridor
	player.add_collision_exception_with(npc)


func _slap(npc: Node3D, k: int, delay := 0.0) -> void:
	_slappers[npc] = k
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
		if not is_inside_tree() or not is_instance_valid(npc):
			return
	var spot: Vector3 = level.get_node("Sinks").stand_spot(k)
	npc.go_to(spot)
	await npc.reached
	if not is_inside_tree():
		return
	if not taps_on.has(k) and not _closed.has(k):
		_tap_on(k)
	_slappers.erase(npc)
	_run_about(npc)


## Untyped `npc`: the level may be freed while this runs (skill 7).
func _run_about(npc, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	while is_inside_tree() and is_instance_valid(npc) and not is_drained:
		if npc.floating:
			await get_tree().create_timer(0.5, false).timeout
			continue
		if water.depth >= water.SWIM_DEPTH:
			break
		npc.go_to(RAMPAGE_POINTS[randi() % RAMPAGE_POINTS.size()])
		await get_tree().create_timer(randf_range(1.2, 2.2), false).timeout


func _clogger_out(player: Node3D) -> void:
	await clogger.stand_up(level.population._stand_spot(stall))
	if not is_inside_tree():
		return
	_rampager(clogger, player)
	_crowd.append(clogger)
	_run_about(clogger)


var _loops := {} ## source id -> its looping sound


func _source_loop(id: String, at: Vector3, event: String) -> void:
	var marker := Node3D.new()
	marker.name = "Sound_" + id
	add_child(marker)
	marker.global_position = at
	_loops[id] = Sfx.loop_at(marker, event)


func _stop_source_loop(id: String) -> void:
	if _loops.has(id):
		Sfx.fade_out(_loops[id], 0.6)
		_loops.erase(id)


func _tap_on(k: int) -> void:
	_source_loop("sink%d" % k, _tap_point(k) + Vector3.UP * 0.8, "gush")
	taps_on[k] = true
	level.get_node("Sinks").set_running(k, true)
	water.add_source("sink%d" % k, Vector3(SinksScript.SINK_X_FIRST + SinksScript.SINK_X_STEP * (k - 1), 0.0, SINK_FRONT_Z))
	(_tap_spots[k] as Node).enabled = true
	Sfx.play_at(level, "tap_squeak", _tap_point(k) + Vector3.UP * 0.9)
	tap_on.emit(k)


# --- the tasks --------------------------------------------------------------------------------------------------------------------

func _tap_point(k: int) -> Vector3:
	return Vector3(SinksScript.SINK_X_FIRST + SinksScript.SINK_X_STEP * (k - 1), 0.0, TAP_POINT_Z)


func _build_taps() -> void:
	for k in sinks:
		var spot: Node3D = SimpleInteractable.new()
		spot.name = "Tap%d" % k
		spot.prompt_text = "E  turn off the tap"
		spot.point = _tap_point(k)
		spot.enabled = false
		spot.enabled_fn = func() -> bool: return taps_on.has(k) and not acting
		spot.used.connect(func(_p: Node3D) -> void: _turn_off(k))
		add_child(spot)
		_tap_spots[k] = spot
		var p := _falling_water(Vector3(spot.point.x, 0.74, SINK_FRONT_Z), 0.9)
		_overflow[k] = p


func _turn_off(k: int) -> void:
	if acting or not taps_on.has(k):
		return
	acting = true
	var p: CharacterBody3D = level.player
	p.busy = true
	p.turn_toward(_tap_point(k) + Vector3(0.0, 0.0, 1.0))
	var dive := await _dive_down(p)
	await get_tree().create_timer(TAP_SECONDS, false).timeout
	if is_inside_tree():
		taps_on.erase(k)
		_closed[k] = true
		_taps_done += 1
		level.get_node("Sinks").set_running(k, false)
		water.remove_source("sink%d" % k)
		_stop_source_loop("sink%d" % k)
		Sfx.play_at(level, "tap_squeak", _tap_point(k) + Vector3.UP * 0.9)
		tap_closed.emit(k)
	if dive:
		await _dive_up(p)
	p.busy = false
	acting = false


func _build_toilet_spot() -> void:
	_toilet_spot = SimpleInteractable.new()
	_toilet_spot.name = "CloggedToilet"
	_toilet_spot.point = Vector3(_seat.x, 0.0, _seat.z)
	_toilet_spot.priority = 1.2 # over the open door Bob stands in
	_toilet_spot.enabled_fn = func() -> bool: return is_started and clogged and not acting
	_toilet_spot.used.connect(func(_p: Node3D) -> void: _plunge())
	add_child(_toilet_spot)
	_update_toilet_prompt()
	_trickle = _falling_water(_door_floor + _out * 0.05 + Vector3.UP * 0.05, 0.5, true)


func _update_toilet_prompt() -> void:
	_toilet_spot.prompt_text = "E (hold)  plunge the toilet" if has_plunger else "Clogged! Get the red plunger outside"


func _plunge() -> void:
	if acting or not clogged or not has_plunger:
		return
	acting = true
	var p: CharacterBody3D = level.player
	p.busy = true
	p.turn_toward(_toilet_spot.point)
	var dive := await _dive_down(p)
	var next_pump := 0.0
	while is_inside_tree() and clogged and Input.is_action_pressed("interact"):
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		plunge_progress += dt
		var phase := fmod(plunge_progress, PLUNGE_SECONDS / PUMPS) / (PLUNGE_SECONDS / PUMPS)
		if is_instance_valid(_plunger):
			_plunger.position = p.CARRY_POSITION + Vector3(0.0, -0.15 * sin(phase * PI), 0.25)
		if plunge_progress >= PLUNGE_SECONDS:
			_unclog()
		elif plunge_progress >= next_pump: # PUMPS squelches; not a 5th one on the finishing frame (it landed with the glug and the chime: 0 dB)
			next_pump += PLUNGE_SECONDS / PUMPS
			Sfx.play_at(level, "plunge", _toilet_spot.point + Vector3.UP * 0.5)
	if dive:
		await _dive_up(p)
	if is_instance_valid(_plunger) and has_plunger and clogged:
		_plunger.position = p.CARRY_POSITION
	p.busy = false
	acting = false


func _unclog() -> void:
	clogged = false
	water.remove_source("toilet")
	_stop_source_loop("toilet")
	# the glug a moment after the mission's chime (together they peaked at 0 dB in the recorded mix, probe_flood_sound)
	get_tree().create_timer(GLUG_DELAY, false).timeout.connect(func() -> void:
		if is_inside_tree():
			Sfx.play_at(level, "glug", _toilet_spot.point + Vector3.UP * 0.5))
	var item: Node3D = level.player.take_carried()
	if item != null:
		item.queue_free() # done with the plunger
	_plunger = null
	unclogged.emit()


func _build_plunger() -> void:
	_plunger = Node3D.new()
	_plunger.name = "Plunger"
	_plunger.set_meta("carry_name", "plunger")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.08, 0.05)
	red.emission_enabled = true # saturated + self-lit: it must read on murky water in a green room (skill 3c)
	red.emission = Color(0.6, 0.02, 0.0)
	red.roughness = 0.35
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.42, 0.2)
	wood.emission_enabled = true
	wood.emission = Color(0.2, 0.12, 0.04)
	var cup := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.08
	s.is_hemisphere = true
	cup.mesh = s
	cup.material_override = red
	cup.rotation.x = PI # the open side down
	cup.position = Vector3(0.0, 0.07, 0.0)
	_plunger.add_child(cup)
	var handle := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.015
	c.bottom_radius = 0.015
	c.height = 0.6
	handle.mesh = c
	handle.material_override = wood
	handle.position = Vector3(0.0, 0.37, 0.0)
	_plunger.add_child(handle)
	_plunger.visible = false
	add_child(_plunger)
	_plunger_spot = SimpleInteractable.new()
	_plunger_spot.name = "PlungerSpot"
	_plunger_spot.prompt_text = "E  pick up the plunger"
	_plunger_spot.enabled = false
	_plunger_spot.priority = 1.5
	_plunger_spot.enabled_fn = func() -> bool: return not has_plunger and not acting
	_plunger_spot.used.connect(_take_plunger)
	add_child(_plunger_spot)


func _take_plunger(p: Node3D) -> void:
	if has_plunger or acting:
		return
	has_plunger = true
	_plunger_spot.enabled = false
	_update_toilet_prompt()
	await p.grab(_plunger)


func _build_drain() -> void:
	var grate := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.01
	grate.mesh = disc
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05)
	dark.metallic = 0.8
	dark.roughness = 0.3
	grate.material_override = dark
	add_child(grate)
	grate.global_position = DRAIN_POS + Vector3.UP * 0.006
	_plug = Node3D.new()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.035
	torus.outer_radius = 0.055
	ring.mesh = torus
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.95, 0.8, 0.15) # brass, self-lit a little so it is findable under murky water
	chrome.emission_enabled = true
	chrome.emission = Color(0.5, 0.35, 0.0)
	chrome.metallic = 0.6
	chrome.roughness = 0.25
	ring.material_override = chrome
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0.0, 0.06, 0.0)
	_plug.add_child(ring)
	add_child(_plug)
	_plug.global_position = DRAIN_POS + Vector3.UP * 0.01
	_drain_spot = SimpleInteractable.new()
	_drain_spot.name = "Drain"
	_drain_spot.prompt_text = "E  pull the plug"
	_drain_spot.point = DRAIN_POS
	_drain_spot.priority = 1.0
	_drain_spot.enabled_fn = func() -> bool: return is_started and not plug_out and water.depth > 0.0 and not acting
	_drain_spot.used.connect(func(_p: Node3D) -> void: _pull_plug())
	add_child(_drain_spot)


func _pull_plug() -> void:
	if acting or plug_out:
		return
	var n: int = water.running_count()
	if n > 0:
		Sfx.play_ui(level, "ui_wrong")
		toast("It won't budge! Water's still coming in (%d left)" % n)
		return
	acting = true
	var p: CharacterBody3D = level.player
	p.busy = true
	p.turn_toward(DRAIN_POS)
	var dive := await _dive_down(p)
	await get_tree().create_timer(0.6, false).timeout
	if is_inside_tree() and water.start_drain(DRAIN_POS):
		plug_out = true
		var tw := create_tween()
		tw.tween_property(_plug, "global_position", DRAIN_POS + Vector3(0.25, 0.01, 0.1), 0.3)
		Sfx.play_at(level, "plug_pop", DRAIN_POS + Vector3.UP * 0.3)
		_gurgle = Sfx.loop_at(_drain_spot, "gurgle")
		plug_pulled.emit()
	if dive:
		await _dive_up(p)
	p.busy = false
	acting = false


## Deep water: Bob (and his camera) go down to the floor. Returns true when he dived (the caller brings him back up).
func _dive_down(p: CharacterBody3D) -> bool:
	if water.depth < p.SWIM_DEPTH:
		return false
	p.diving = true
	p.set_dive_view(true, DIVE_DOWN)
	Sfx.play_at(level, "dive", p.global_position + Vector3.UP * 0.6)
	var tw := create_tween()
	tw.tween_property(p, "global_position:y", DIVE_FLOOR_Y, DIVE_DOWN)
	await tw.finished
	return true


func _dive_up(p: CharacterBody3D) -> void:
	p.set_dive_view(false, DIVE_UP)
	p.dive_surface(true)
	var tw := create_tween()
	tw.tween_property(p, "global_position:y", maxf(water.surface_y() - p.FLOAT_DEPTH, 0.0), DIVE_UP)
	await tw.finished
	p.dive_surface(false)
	p.diving = false
	Sfx.play_at(level, "surface", p.global_position + Vector3.UP * 1.0)


# --- after the drain --------------------------------------------------------------------------------------------------------------

func _on_drained() -> void:
	is_drained = true
	if _gurgle != null:
		Sfx.fade_out(_gurgle, 1.0)
		_gurgle = null
	_leave_residue()
	for npc: Node3D in level.population.queue:
		_go_home(npc)
	if is_instance_valid(clogger):
		clogger.walk_speed = 1.6
		clogger.go_to(_door_floor + _out * 0.9)
	var walkers := level.get_node_or_null("Walkers")
	if walkers != null:
		for npc: Node3D in level.population.walkers:
			npc.walk_speed = 1.6
		walkers.resume_all()
	drained.emit()


## Back to the queue spot. The queue spots are 0.8 m apart in lines 1.1 m apart: walking back between Jijios already home jammed two
## of them for 25 s (test_flood_swim), so queue Jijios pass through each other and the walkers (they never needed to collide).
func _go_home(npc: Node3D) -> void:
	for other: Node3D in level.population.queue + level.population.walkers + [clogger]:
		if other != npc and is_instance_valid(other):
			npc.add_collision_exception_with(other)
	npc.walk_speed = 1.6
	npc.go_to(npc.home)
	await npc.reached
	if is_instance_valid(npc) and is_inside_tree():
		npc.queue_at(npc.home)
		if is_instance_valid(level.player):
			npc.remove_collision_exception_with(level.player)
			level.player.remove_collision_exception_with(npc)


## The 4 leftover puddles: outside the clogged stall, by the middle running sink, by the drain, and one more along the walkways.
func residue_spots() -> Array:
	var mid: int = sinks[1]
	var spots: Array = [
		{"pos": _door_floor + _out * 0.9, "name": "outside " + stall_text()},
		{"pos": Vector3(SinksScript.SINK_X_FIRST + SinksScript.SINK_X_STEP * (mid - 1), 0.0, 0.1), "name": "by sink %d" % mid},
		{"pos": DRAIN_POS + Vector3(0.3, 0.0, 0.0), "name": "by the drain"},
	]
	var options: Array[Vector3] = []
	for s in RESIDUE_SPOTS:
		var ok := true
		for d: Dictionary in spots:
			var q: Vector3 = d["pos"]
			if Vector2(s.x - q.x, s.z - q.z).length() < RESIDUE_GAP:
				ok = false
		if ok:
			options.append(s)
	var extra: Vector3 = options[randi() % options.size()] if not options.is_empty() else RESIDUE_SPOTS[5]
	var where := "corridor A" if extra.z > -0.5 else ("corridor B" if extra.z < -4.5 else "the far end")
	spots.append({"pos": extra, "name": where})
	return spots


func _leave_residue() -> void:
	for d: Dictionary in residue_spots():
		var f: Node3D = FloodScript.new()
		f.name = "Residue%d" % (residue.size() + 1)
		level.add_child(f)
		f.setup(level)
		f.start_residue(d["pos"], d["name"])
		residue.append(f)
		level.floods.append(f)
	level.flood = level.floods[0]


# --- helpers ----------------------------------------------------------------------------------------------------------------------

## Water pouring over an edge (a basin, the gap under the stall door): white-grey drops falling to the floor.
func _falling_water(at: Vector3, width: float, spill := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60 if not spill else 40
	p.lifetime = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.3, 0.01, 0.02)
	p.direction = Vector3(0.0, -1.0, 0.0) if not spill else _out
	p.spread = 12.0 if not spill else 40.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6 if not spill else 1.2
	p.gravity = Vector3(0.0, -9.8, 0.0)
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.8, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.38, 0.32)
	drop.material = mat
	p.mesh = drop
	p.emitting = false
	add_child(p)
	p.global_position = at
	return p


func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-400, -190)
	_toast.size = Vector2(800, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


## A short message over the prompt, gone after 2.5 s (no voice: the numbers change).
func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func last_toast() -> String:
	return _toast.text if _toast.modulate.a > 0.0 else ""
