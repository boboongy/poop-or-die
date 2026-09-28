extends Node
## Level 3 "Hide and seek" (owner-decided 2026-09-22, SPEC.md "Level 3"). One random stall is EMPTY. Bob has `hide_seconds` to hide,
## then every queue Jijio and walker sprints off and looks under the door of every stall. The stall occupants stay where they are.
## Peek rule: a seeker peeking under a door sees any of Bob's feet lower than PEEK_HEIGHT (the doors start 0.30 m above the floor), or
## everything if the door is open. Standing on the toilet seat (empty stall) or on top of the sitting Jijio (after asking them to
## shush -- ends up near their head, see LAP_OFFSET) lifts his feet above that. Nothing the player reads says so: they have to
## work it out from the jump scare.

const Sfx := preload("res://scripts/sfx.gd")
const Walkers := preload("res://scripts/walkers.gd")
const HideSpot := preload("res://scripts/hide_spot.gd")
const JumpScare := preload("res://scripts/jump_scare.gd")

signal tick ## once a second while counting down, and when a phase changes (the mission hint follows it)
signal search_over ## every stall has been checked and Bob was not found
signal caught(seeker) ## a seeker found Bob

enum Phase { HIDING, SEEKING, OVER, CAUGHT, STOPPED }

const STALLS := 20
const PEEK_HEIGHT := 0.42 ## m: feet lower than this show under the door (gap 0.30 m, seat 0.505 m, on top of the occupant about 0.9 m; measured, SPEC.md)
## FACTORY_TODO #13, measured by the factory in Blender against the real Jijio sit-pose mesh, 0 vertex overlap: added to the
## occupant's own global_position, rotated by the occupant's yaw so it lands correctly in either row. Despite the name this is
## no longer literally the lap: there is no clear gap at lap height for a second full-size body, so Bob ends up near Jijio's
## head (owner approved the render, reads as slapstick for a hide-and-seek game).
const LAP_OFFSET := Vector3(-0.15, 0.90, -0.04)
const HOP_SECONDS := 0.35
const HIDE_PITCH := -1.1 ## rad: the camera while Bob hides (the player may still move the mouse)
const HOP_REACH := 1.2 ## m from the seat: the climb prompt shows
const STALL_HALF_WIDTH := 0.48
const STALL_DEPTH := 1.55
const HIDE_SECONDS := 20.0 ## owner 2026-09-25 (was 12: "very hard to win"; walking reached only 10 of 20 stalls in 12 s)
const SEEKER_SPEED := 4.5 ## they SPRINT (owner: it should look scary from above)
const SEE_RANGE := 8.0 ## m: a seeker with a clear line of sight this close catches Bob
const PEEK_LEAN := 1.35 ## rad: the seeker bends right over, face at the gap (stand-in for a crouch clip)
const PEEK_SECONDS := 1.5
const PEEK_DISTANCE := 1.05 ## m in front of the door line: the leaning face ends up right at the gap
const CHECK_TIMEOUT := 25.0 ## s a seeker may take to reach a stall before it tries another
const LOOK_INTERVAL := 0.15
const HEAR_SPRINT := 6.0 ## m: noise radii
const HEAR_DOOR := 3.5
const HEAR_HOP := 3.5
const HEAR_FART := 8.0
const HEAR_SHOUT := 8.0
const SHOUT_RANGE := 6.0 ## m: a seeker this close to an unshushed occupant's stall makes them shout (PROPOSAL numbers, tune by playtest)
const FILL_RATE := 0.1 ## the fart meter fills in about 10 s
const CLENCH_FACTOR := 0.33 ## holding F: 3x slower
const PRESSURE_AFTER := 0.3 ## the meter after a release

static var force_empty := -1 ## tests: which stall is the empty one (-1 = random)

var phase := Phase.HIDING
var empty_stall := 0
var hidden_in := -1 ## the stall Bob is standing hidden in (on the seat or the lap), -1 = none
var shushed := {} ## occupied stall -> true once Bob asked the Jijio inside to keep quiet
var hide_seconds := HIDE_SECONDS

var seekers: Array = [] ## the queue Jijios and walkers, once the search starts
var checked := {} ## stall -> true once a seeker has looked under (or through) its door
var peeks := {} ## stall -> how many times a seeker peeked (tests: did the test meet the situation?)
var catches := 0
var caught_by: Node
var caught_mode := "" ## "peek" (feet under the door) or "sight" (seen in the open)
var caught_stall := -1
var noises: Array = [] ## every noise made: {kind, pos, phase} (tests read it)
var pressure := 0.0 ## the fart Bob is holding in, 0..1 (fills while the seekers search)
var farts := 0
var snitched := {} ## stall -> true once its unshushed occupant has shouted
var see_range := SEE_RANGE ## tests set 0 to stand Bob in the open without being seen
var hold_search_open := false ## tests: do not end the search when every stall is checked

var level: Node3D
var player: CharacterBody3D
var population: Node
var doors: Array = []

var _seat: Array[Vector3] = [] ## per stall: centre of the seat, y = top of the seat
var _fwd: Array[Vector3] = [] ## per stall: from the toilet toward the door
var _phase_time := 0.0
var _hopping := false
var _talking := false
var _started := false
var _claimed := {} ## stall -> the seeker on the way to it
var _redirect := {} ## seeker -> stall it heard something at
var _fails := {} ## stall -> times a seeker gave up reaching it
var _peeking := {} ## seekers bent over at a door right now
var _look_time := 0.0
var _sprint_time := 0.0
var _bar: Label
var _pitch_before := -0.15
var _tilted := false


## The random empty stall (tests can force one).
static func pick_empty() -> int:
	return force_empty if force_empty >= 0 else randi_range(0, STALLS - 1)


func setup(level_node: Node3D) -> void:
	level = level_node
	player = level.player
	population = level.population
	doors = level.stalls.doors
	empty_stall = pick_empty()
	population.hide_away(empty_stall)
	var toilet: Node3D = level.get_node("NavRegion/Toilet")
	for i in STALLS:
		var row := 1 if i < 10 else 2
		var lid := toilet.find_child("SM_Toilet_R%d_%02d_Lid" % [row, i % 10 + 1], true, false) as MeshInstance3D
		var box := lid.global_transform * lid.get_aabb()
		_seat.append(Vector3(box.get_center().x, box.end.y, box.get_center().z))
		_fwd.append(Vector3.BACK if row == 1 else Vector3.FORWARD)
		_make_spots(i)
		doors[i].toggled.connect(_on_door.bind(i))
	_make_hud()
	_begin()


## The fart meter, bottom left above the "Carrying" line. It says nothing about where to hide.
func _make_hud() -> void:
	_bar = Label.new()
	_bar.name = "PressureLabel"
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 12.0
	_bar.offset_top = -100.0
	_bar.offset_right = 460.0
	_bar.offset_bottom = -58.0
	_bar.add_theme_font_size_override("font_size", 22)
	_bar.visible = false
	level.get_node("HUD").add_child(_bar)


## A stall is only 0.95 m wide: the normal camera would sit 0.4 m behind Bob and fill the screen with his hair (seen 2026-09-22). Whenever
## he is inside one during the round the camera looks steeply down from above the partitions instead; walking out puts the pitch back.
func _camera_frame() -> void:
	var here := stall_of(player.global_position)
	var round_on := phase == Phase.HIDING or phase == Phase.SEEKING or phase == Phase.OVER
	var inside := here >= 0 and round_on and here != _reward_stall() # the toilet sequence in the reward stall works its own camera
	if inside and not _tilted:
		_tilted = true
		_pitch_before = player.get_camera_pitch()
		player.set_camera(player._yaw, HIDE_PITCH)
	elif not inside and _tilted:
		_tilted = false
		player.set_camera(player._yaw, _pitch_before)


## The stall the toilet sequence uses once the reward is announced, else -1 (index 0-9 row 1, 10-19 row 2).
func _reward_stall() -> int:
	var session = level.get_node("ToiletSession")
	if session._use_spot == null:
		return -1
	return (session._row - 1) * 10 + session._k - 1


func _process(_delta: float) -> void:
	if _bar == null:
		return
	_camera_frame()
	_bar.visible = phase == Phase.SEEKING
	var n := clampi(int(pressure * 10.0), 0, 10)
	_bar.text = "Holding it in  [%s%s]   hold F" % ["#".repeat(n), "-".repeat(10 - n)]


func _make_spots(i: int) -> void:
	var climb := HideSpot.new()
	climb.name = "Climb%d" % i
	climb.point = Vector3(_seat[i].x, 0.0, _seat[i].z)
	climb.prompt_fn = _climb_prompt.bind(i)
	climb.use_fn = func(_p: Node3D) -> void: _climb_pressed(i)
	add_child(climb)
	var talk := HideSpot.new()
	talk.name = "Talk%d" % i
	talk.point = Vector3(_seat[i].x, 0.0, _seat[i].z) + _fwd[i] * 0.15
	talk.prompt_fn = _talk_prompt.bind(i)
	talk.use_fn = func(_p: Node3D) -> void: _talk(i)
	add_child(talk)


## Wait for the walkers to appear (they spawn a few frames after the level loads), then everybody stops counting-side: the walkers
## stand still, the hiding phase begins.
func _begin() -> void:
	if level.intro_playing: # the ghost starts the game: nobody counts before it has spoken (the level clock is paused too)
		await level.intro_done
	for n in 300:
		if not Walkers.enabled or not population.walkers.is_empty():
			break
		await get_tree().physics_frame
	if population.walker_manager:
		population.walker_manager.park_all() # they count on the door-free wall (frozen where they stood, they blocked stall doors)
	_started = true
	phase = Phase.HIDING
	_phase_time = 0.0
	tick.emit()


func hide_left() -> float:
	return maxf(hide_seconds - _phase_time, 0.0)


func _physics_process(delta: float) -> void:
	if not _started:
		return
	if phase == Phase.HIDING or phase == Phase.SEEKING:
		if not level._running: # timeout, or Bob sat down: the round is over whatever the seekers were doing
			phase = Phase.STOPPED
			player.clenching = false
			return
	if phase == Phase.HIDING:
		var before := int(ceil(hide_left()))
		_phase_time += delta
		if int(ceil(hide_left())) != before:
			tick.emit()
		if _phase_time >= hide_seconds:
			_start_seeking()
	elif phase == Phase.SEEKING:
		_seeking_frame(delta)


## Everybody who is not a stall occupant stops counting and sprints off to look in every stall.
func _start_seeking() -> void:
	phase = Phase.SEEKING
	if population.walker_manager:
		population.walker_manager.unpark_all()
	seekers.clear()
	for npc in population.queue:
		seekers.append(npc)
	for npc in population.walkers:
		seekers.append(npc)
	for npc in seekers:
		npc.talking = false
		if npc.is_in_group("interactable"):
			npc.clear_interaction()
		npc.stop_washing()
		npc.collision_layer = 2 # like the walkers: they pass through each other (nine sprinting in a 1.6 m corridor would jam)
		npc.collision_mask = 1
		npc.walk_speed = SEEKER_SPEED
	tick.emit()
	for npc in seekers:
		_seek_loop(npc)


func _seeking_frame(delta: float) -> void:
	_look_time += delta
	if _look_time >= LOOK_INTERVAL:
		_look_time = 0.0
		_look_for_bob()
		if phase != Phase.SEEKING:
			return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed > 4.0 and not player.busy and not player.hiding:
		_sprint_time += delta
		if _sprint_time >= 0.5:
			_sprint_time = 0.0
			noise(player.global_position, HEAR_SPRINT, "sprint")
	_fart_frame(delta)
	_shout_frame()
	if checked.size() == STALLS and _peeking.is_empty() and not hold_search_open:
		_finish_search()


## The fart Bob holds in: fills while the seekers search; hold F to clench (3x slower, cannot move); at full it lets go, loudly.
func _fart_frame(delta: float) -> void:
	var clench := Input.is_action_pressed("clench")
	player.clenching = clench
	pressure += delta * FILL_RATE * (CLENCH_FACTOR if clench else 1.0)
	if pressure >= 1.0:
		farts += 1
		pressure = PRESSURE_AFTER
		var at := player.global_position + Vector3(0.0, 0.5, 0.0)
		Sfx.play_at(player, "fart", at)
		noise(at, HEAR_FART, "fart")


## Bob is inside an occupied stall and the Jijio there was not asked to keep quiet: as a seeker comes near, they shout.
func _shout_frame() -> void:
	var i := stall_of(player.global_position)
	if i < 0 or i == empty_stall or shushed.has(i) or snitched.has(i):
		return
	var door: Node3D = doors[i]
	for npc in seekers:
		if _alive(npc) and Vector2(npc.global_position.x - door.point.x, npc.global_position.z - door.point.z).length() < SHOUT_RANGE:
			snitched[i] = true
			var occupant: Node3D = population.occupants[i]
			level.dialogue.bubble(occupant, "Hey! Somebody's in here with me!", 3.0)
			Sfx.play_at(occupant, "oof", occupant.global_position + Vector3(0.0, 0.8, 0.0)) # Stage 6: a Jijio voice, not the old cry
			noise(door.point, HEAR_SHOUT, "shout")
			return


# ---------------------------------------------------------------- where Bob is, and what a peeking seeker sees

## The stall whose floor space (inside the door) contains `pos`, or -1.
func stall_of(pos: Vector3) -> int:
	for i in STALLS:
		if absf(pos.x - _seat[i].x) > STALL_HALF_WIDTH:
			continue
		var door: Node3D = doors[i]
		var door_z: float = door.point.z
		var inside: float = (door_z - pos.z) if i < 10 else (pos.z - door_z) # metres past the door line
		if inside > 0.0 and inside < STALL_DEPTH:
			return i
	return -1


## True when a seeker who looks under the door of stall `i` sees Bob's feet: he is inside, and either the door is open or his feet are
## lower than PEEK_HEIGHT.
func feet_visible(i: int) -> bool:
	if stall_of(player.global_position) != i:
		return false
	return doors[i].is_open or player.global_position.y < PEEK_HEIGHT


func _inside_closed(i: int) -> bool:
	return stall_of(player.global_position) == i and not doors[i].is_open


func _active() -> bool:
	return _started and (phase == Phase.HIDING or phase == Phase.SEEKING)


# ---------------------------------------------------------------- the prompts

func _climb_prompt(i: int) -> String:
	if not _active() or _hopping or _talking or player.busy:
		return ""
	if hidden_in == i:
		return "E  climb down"
	if hidden_in >= 0 or not _inside_closed(i):
		return ""
	if i != empty_stall and not shushed.has(i):
		return "" # an occupied stall: talk to the Jijio first
	if Vector2(player.global_position.x - _seat[i].x, player.global_position.z - _seat[i].z).length() > HOP_REACH:
		return ""
	return "E  climb"


func _talk_prompt(i: int) -> String:
	if not _active() or _hopping or _talking or player.busy or hidden_in >= 0:
		return ""
	if i == empty_stall or shushed.has(i) or not _inside_closed(i):
		return ""
	return "E  talk"


func _climb_pressed(i: int) -> void:
	if hidden_in == i:
		hop_down()
	elif hidden_in < 0:
		hop(i)


# ---------------------------------------------------------------- the hop

## Bob's standing place for stall `i`: on the seat (empty stall) or on top of the sitting Jijio (occupied; see LAP_OFFSET).
func hide_spot(i: int) -> Vector3:
	if i == empty_stall:
		var flat := Vector3(_seat[i].x, 0.0, _seat[i].z)
		return flat + _fwd[i] * 0.15 + Vector3(0.0, _seat[i].y, 0.0)
	var occupant: Node3D = population.occupants[i]
	return occupant.global_position + Basis(Vector3.UP, occupant.get_yaw()) * LAP_OFFSET


func hop(i: int) -> void:
	if hidden_in >= 0 or _hopping:
		return
	_hopping = true
	var start := player.global_position
	var target := hide_spot(i)
	player.busy = true
	player.set_body_collision(false)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: player.global_position = start.lerp(target, t) + Vector3(0.0, sin(t * PI) * 0.3, 0.0), 0.0, 1.0, HOP_SECONDS)
	await tween.finished
	player.global_position = target
	player.turn_toward(target + _fwd[i])
	player.busy = false
	player.hiding = true
	hidden_in = i
	_hopping = false
	noise(target, HEAR_HOP, "hop")


func hop_down() -> void:
	if hidden_in < 0 or _hopping:
		return
	_hopping = true
	var i := hidden_in
	var start := player.global_position
	var target := Vector3(_seat[i].x, 0.0, _seat[i].z) + _fwd[i] * 0.72
	player.busy = true
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: player.global_position = start.lerp(target, t) + Vector3(0.0, sin(t * PI) * 0.15, 0.0), 0.0, 1.0, HOP_SECONDS)
	await tween.finished
	player.global_position = target
	player.hiding = false
	player.busy = false
	player.set_body_collision(true)
	hidden_in = -1
	_hopping = false


# ---------------------------------------------------------------- the seekers
## Every helper below takes an UNTYPED `npc`: the coroutines outlive a level reload by a frame, and a typed parameter errors on a freed
## object (skill section 7). Every `await` is followed by an _alive() check.

func _alive(npc) -> bool:
	return is_instance_valid(npc) and not npc.is_queued_for_deletion() and npc.is_inside_tree()


## Check stalls one after the other until none is left.
func _seek_loop(npc) -> void:
	while phase == Phase.SEEKING and _alive(npc):
		var s := _next_stall(npc)
		if s < 0:
			break
		_claimed[s] = npc
		var arrived: bool = await _walk_to_check(npc, s)
		if phase != Phase.SEEKING or not _alive(npc):
			_claimed.erase(s)
			return
		if arrived:
			await _peek(npc, s)
		_claimed.erase(s)
		if phase != Phase.SEEKING or not _alive(npc):
			return
	if phase == Phase.SEEKING and _alive(npc):
		npc.stop_walking() # nothing left to check


## A stall the seeker heard something at, else the nearest one nobody has checked or is heading for.
func _next_stall(npc) -> int:
	if _redirect.has(npc):
		var heard: int = _redirect[npc]
		_redirect.erase(npc)
		if not _claimed.has(heard):
			return heard
	var best := -1
	var best_score := INF
	for i in STALLS:
		if checked.has(i) or _claimed.has(i):
			continue
		var score: float = npc.global_position.distance_to(_check_spot(i)) + 20.0 * _fails.get(i, 0)
		if score < best_score:
			best = i
			best_score = score
	return best


## Where a seeker stands to look under the door of stall `i` (PEEK_DISTANCE in front of the door line, on the navmesh).
func _check_spot(i: int) -> Vector3:
	var door: Node3D = doors[i]
	var flat := Vector3(door.point.x, 0.0, door.point.z) + _fwd[i] * PEEK_DISTANCE
	var map: RID = level.get_node("NavRegion").get_navigation_map()
	var closest := NavigationServer3D.map_get_closest_point(map, Vector3(flat.x, population.nav_height(), flat.z))
	if closest == Vector3.ZERO: # the map has not synchronised yet
		return flat
	return Vector3(closest.x, 0.0, closest.z)


## Sprint to the stall. True on arrival; false if the walk was dropped (heard a noise elsewhere, timed out, the round ended).
func _walk_to_check(npc, s: int) -> bool:
	npc.go_to(_check_spot(s))
	var waited := 0.0
	while phase == Phase.SEEKING and _alive(npc):
		await get_tree().physics_frame
		if not _alive(npc):
			return false
		if _redirect.has(npc):
			return false
		if not npc.is_walking():
			return true
		waited += get_physics_process_delta_time()
		if waited > CHECK_TIMEOUT:
			npc.stop_walking()
			_fails[s] = _fails.get(s, 0) + 1
			return false
	return false


## Bend right over and look under the door. The feet rule decides whether Bob is found.
func _peek(npc, s: int) -> void:
	_peeking[npc] = true
	npc.face_yaw(atan2(-_fwd[s].x, -_fwd[s].z)) # looking into the stall
	var model: Node3D = npc.get_node("Model")
	var down := create_tween()
	down.tween_property(model, "rotation:x", PEEK_LEAN, 0.4)
	await down.finished
	if not _alive(npc) or phase != Phase.SEEKING:
		_peeking.erase(npc)
		return
	peeks[s] = peeks.get(s, 0) + 1
	checked[s] = true
	if feet_visible(s):
		_peeking.erase(npc)
		_caught(npc, "peek", s)
		return
	await get_tree().create_timer(PEEK_SECONDS - 0.4).timeout
	if _alive(npc):
		var up := create_tween()
		up.tween_property(model, "rotation:x", 0.0, 0.3)
		await up.finished
	_peeking.erase(npc)


## Anyone with a clear line of sight to Bob within SEE_RANGE catches him (a closed stall door and its partitions block the view).
func _look_for_bob() -> void:
	if hidden_in >= 0 and not doors[hidden_in].is_open:
		return # cheap early out: the door and partitions block every ray
	if see_range <= 0.0:
		return
	var space := player.get_world_3d().direct_space_state
	var target := player.global_position + Vector3(0.0, 0.65, 0.0)
	for npc in seekers:
		if not _alive(npc) or _peeking.has(npc):
			continue
		var eye: Vector3 = npc.global_position + Vector3(0.0, 1.05, 0.0)
		if eye.distance_to(target) > see_range:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
		query.exclude = [npc.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] == player:
			_caught(npc, "sight", -1)
			return


func _caught(npc, mode: String, s: int) -> void:
	if phase != Phase.SEEKING:
		return
	phase = Phase.CAUGHT
	caught_by = npc
	caught_mode = mode
	caught_stall = s
	catches += 1
	player.clenching = false
	for other in seekers:
		if other != npc and _alive(other):
			other.stop_walking()
	level.on_caught()
	caught.emit(npc)
	var scare := JumpScare.new()
	scare.name = "JumpScare"
	add_child(scare)
	scare.play(level, npc, doors[s] if mode == "peek" else null)


## Every stall is checked and Bob was not found: he climbs down, the seekers go back, the mission is done (the reward stall opens).
func _finish_search() -> void:
	if phase != Phase.SEEKING:
		return
	phase = Phase.OVER
	player.clenching = false
	if hidden_in >= 0:
		population.blocked_stalls.append(hidden_in) # the Jijio Bob stood on is not the reward
		hop_down()
	for npc in seekers:
		if not _alive(npc):
			continue
		npc.walk_speed = 1.6
		npc.stop_walking()
		if population.queue.has(npc):
			npc.reached.connect(npc.queue_at.bind(npc.home), CONNECT_ONE_SHOT)
			npc.go_to(npc.home)
		elif population.walker_manager:
			population.walker_manager.park(npc) # off the door fronts (the last peek left them right at a door)
	search_over.emit()


# ---------------------------------------------------------------- noise

## Something loud happened at `pos`. The nearest seeker within `radius` who is not busy peeking goes to check the stall nearest to it.
func noise(pos: Vector3, radius: float, kind: String) -> void:
	noises.append({"kind": kind, "pos": pos, "phase": phase})
	if phase != Phase.SEEKING:
		return
	var best = null
	var best_d := radius
	for npc in seekers:
		if not _alive(npc) or _peeking.has(npc) or _redirect.has(npc):
			continue
		var d: float = npc.global_position.distance_to(pos)
		if d <= best_d:
			best = npc
			best_d = d
	if best == null:
		return
	var s := _nearest_stall(pos, 4.0)
	if s >= 0 and not _claimed.has(s):
		_redirect[best] = s


func _nearest_stall(pos: Vector3, within: float) -> int:
	var best := -1
	var best_d := within
	for i in STALLS:
		var door: Node3D = doors[i]
		var d := Vector2(door.point.x - pos.x, door.point.z - pos.z).length()
		if d < best_d:
			best = i
			best_d = d
	return best


func _on_door(_open: bool, i: int) -> void:
	if phase == Phase.SEEKING and player.global_position.distance_to(doors[i].point) < 2.5:
		noise(doors[i].point, HEAR_DOOR, "door")


# ---------------------------------------------------------------- asking the Jijio to shush

func _talk(i: int) -> void:
	if _talking:
		return
	_talking = true
	var npc: Node3D = population.occupants[i]
	var d = level.dialogue
	d.begin(npc, player)
	await d.say(npc, "Hey! This is MY stall. What do you think you're doing in here?")
	var pick: int = await d.choose(npc, "What do you say?", ["Shhh! Please keep quiet. Please!", "Get out of my way, I'm hiding in here."])
	if pick == 1:
		Sfx.play_ui(level, "ui_wrong")
		await d.say(npc, "How rude! Out! Out! Go and ask nicely.")
		d.end(npc, player)
		_talking = false
		return # stays unshushed: try again, no time lost
	await d.say(npc, "...Fine. My lips are sealed. Not a sound.")
	shushed[i] = true
	d.end(npc, player)
	_talking = false
