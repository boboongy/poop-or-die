extends Node3D
## Places the Jijios that are already in the toilet when the level starts:
## a still snake queue in the waiting room (lobby) and one Jijio in every stall.

signal crowd_arrived

const NPC := preload("res://scenes/npc_jijio.tscn")

## Snake of three lines across the room (each line runs north-south), front of the line first.
## Everyone faces the person ahead; the front person faces the door. Bob is next in line after the last spot.
const QUEUE_SPOTS: Array[Vector3] = [
	Vector3(-1.5, 0.0, 0.0), Vector3(-1.5, 0.0, 0.8), Vector3(-1.5, 0.0, 1.6),
	Vector3(-2.6, 0.0, 1.2), Vector3(-2.6, 0.0, 0.4), Vector3(-2.6, 0.0, -0.4), Vector3(-2.6, 0.0, -1.2),
	Vector3(-3.7, 0.0, -1.2), Vector3(-3.7, 0.0, -0.4),
]

const STALL_JOINERS := 4 ## stall Jijios that join the kicking
const SEAT_FORWARD := 0.15
const STALL_COUNT := 10 # per row; row 1 faces +Z (doors at z -1.0), row 2 faces -Z (doors at z -4.1)

@export var arrive_needed := 5 ## Jijios that must reach Bob before the result screen starts
@export var arrive_timeout := 15.0

var queue: Array[Node3D] = []
var occupants: Array[Node3D] = [] ## stall occupants: row 1 stalls 1-10, then row 2 stalls 1-10
var walkers: Array[Node3D] = [] ## Jijios walking about the corridors (see walkers.gd)
var walker_manager: Node ## set by walkers.gd: stops the walkers at the timeout, frees a sink for the reward
var blocked_stalls: Array[int] = [] ## stalls that are never the reward (Level 2: the clogged one)
var _nav_height := 0.0
var _to_arrive := 0
var _finished := false

@onready var _toilet: Node3D = $"../NavRegion/Toilet"
@onready var _stalls: Node3D = $"../NavRegion/Stalls"
@onready var _nav: NavigationRegion3D = $"../NavRegion"
@onready var _sinks: Node3D = $"../Sinks"


func _ready() -> void:
	for i in QUEUE_SPOTS.size():
		var yaw := PI / 2.0
		if i > 0:
			var ahead := QUEUE_SPOTS[i - 1] - QUEUE_SPOTS[i]
			yaw = atan2(ahead.x, ahead.z)
		var npc := _spawn(QUEUE_SPOTS[i], yaw)
		npc.queue_at(QUEUE_SPOTS[i])
		queue.append(npc)
	# One Jijio sitting on every toilet, facing the door.
	for row in [1, 2]:
		for k in range(1, STALL_COUNT + 1):
			var lid := _toilet.find_child("SM_Toilet_R%d_%02d_Lid" % [row, k], true, false) as MeshInstance3D
			var box := lid.global_transform * lid.get_aabb()
			var c := box.get_center()
			var yaw := 0.0 if row == 1 else PI
			# Sit a little toward the front of the seat so the legs clear the bowl.
			var seat := Vector3(c.x, 0.0, c.z) + Vector3(sin(yaw), 0.0, cos(yaw)) * SEAT_FORWARD
			var npc := _spawn(seat, yaw)
			npc.sit()
			occupants.append(npc)


## Timeout: the whole queue plus the stall Jijios nearest Bob rush him. Stall Jijios open their
## door and stand up first.
func start_kicking(bob: Node3D) -> void:
	if walker_manager:
		walker_manager.stop_all() # taps off, arms down, nobody keeps walking their route
	var released := _nearest_occupants(bob, STALL_JOINERS)
	var total := queue.size() + released.size() + walkers.size()
	_to_arrive = mini(arrive_needed, total)
	var slot := 0
	for npc in queue:
		_send(npc, bob, TAU * slot / total)
		slot += 1
	for npc in walkers:
		_send(npc, bob, TAU * slot / total)
		slot += 1
	for i in released:
		_release(i, bob, TAU * slot / total)
		slot += 1
	# Stuck crowds shouldn't hold up the result forever.
	await get_tree().create_timer(arrive_timeout).timeout
	_finish()


func _send(npc: Node3D, bob: Node3D, angle: float) -> void:
	npc.arrived.connect(_on_arrived, CONNECT_ONE_SHOT)
	npc.start_kicking(bob, angle)


func _release(index: int, bob: Node3D, angle: float) -> void:
	var npc := occupants[index]
	_stalls.doors[index].set_open(true)
	await get_tree().create_timer(0.3).timeout
	await npc.stand_up(_stand_spot(index))
	if not is_inside_tree() or not is_instance_valid(npc):
		return
	_send(npc, bob, angle)


## Where a stall Jijio stands after getting up: between the bowl and the door.
func _stand_spot(index: int) -> Vector3:
	var door: Node3D = _stalls.doors[index]
	# Row 1 doors face +Z (inside of the stall is toward -Z); row 2 is the mirror image.
	var inside := -0.4 if index < STALL_COUNT else 0.4
	return Vector3(door.point.x, 0.0, door.point.z + inside) # in line with the doorway, not the toilet


## Indices of the `count` stall Jijios closest to Bob by walking distance.
func _nearest_occupants(bob: Node3D, count: int) -> Array[int]:
	var map := _nav.get_navigation_map()
	var scored: Array = []
	for i in occupants.size():
		if not occupants[i].is_sitting() or occupants[i].leaving:
			continue # already out of the stall (the freed one), or getting up (Level 2's clogger at GO: still SIT during its stand_up clip)
		var path := NavigationServer3D.map_get_path(map, _stand_spot(i), bob.global_position, true)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		scored.append([length if path.size() > 1 else INF, i])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[int] = []
	for k in mini(count, scored.size()):
		result.append(scored[k][1])
	return result


## Tell every Jijio how far above the floor the navmesh sits (see level_toilet.gd).
func nav_height() -> float:
	return _nav_height


func set_nav_height(height: float) -> void:
	_nav_height = height
	for child in get_children():
		var agent := child.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if agent:
			agent.path_height_offset = height


## A new walker at `pos`. Walkers are on physics layer 2: they collide with the world and Bob (the player's
## mask includes 2) but pass through each other and are not blocked by the queue or the reward Jijio's walk.
func spawn_walker(pos: Vector3, yaw: float) -> Node3D:
	var npc := _spawn(pos, yaw)
	npc.collision_layer = 2
	npc.collision_mask = 1
	var agent := npc.get_node("NavigationAgent3D") as NavigationAgent3D
	agent.path_height_offset = _nav_height
	walkers.append(npc)
	return npc


func remove_walker(npc: Node3D) -> void:
	walkers.erase(npc)
	npc.queue_free()


## Level 3: nobody sits in stall `index` (the one empty stall). The Jijio is switched off and hidden; they are not "sitting", so the reward
## and the kick never pick them.
func hide_away(index: int) -> void:
	var npc := occupants[index]
	npc.state = npc.State.IDLE
	npc.visible = false
	npc.collision_layer = 0
	npc.collision_mask = 0
	npc.process_mode = Node.PROCESS_MODE_DISABLED


## A random stall Jijio who is still sitting, for the reward (never one in `blocked_stalls`, e.g. the clogged toilet).
func pick_free_stall() -> int:
	var sitting: Array[int] = []
	for i in occupants.size():
		if occupants[i].is_sitting() and not blocked_stalls.has(i):
			sitting.append(i)
	return sitting[randi() % sitting.size()]


## Reward: stall `index` opens, its Jijio stands up, walks to the sink in front of that stall's column
## and washes hands with the tap running. Returns once the Jijio is out of the stall, so Bob can use it.
## `bob` (optional): if he stands in the way, the Jijio and he pass through each other until the Jijio is clear of the doorway and of
## him. Jijios are solid, so a Bob standing in front of the door used to trap it inside: the stall was never announced free and the timer
## ran out (owner: "I mopped all the puddles but still get kicked"; tests/test_reward_blocked.gd).
func reward_release(index: int, bob: PhysicsBody3D = null) -> void:
	var npc := occupants[index]
	var door: Node3D = _stalls.doors[index]
	if bob != null:
		npc.add_collision_exception_with(bob)
		bob.add_collision_exception_with(npc)
	door.set_open(true)
	await get_tree().create_timer(0.4).timeout
	await npc.stand_up(_stand_spot(index))
	if not is_inside_tree() or not is_instance_valid(npc):
		return
	var sink := index % STALL_COUNT + 1
	var spot: Vector3 = _sinks.stand_spot(sink)
	if walker_manager:
		walker_manager.evict(sink) # a walker washing there (or heading there) moves on; the tap stays on for the reward
	npc.reached.connect(func() -> void:
		# settle exactly on the spot in front of the basin, then wash facing +Z (the sink and the wall)
		var settle := create_tween()
		settle.tween_property(npc, "global_position", spot, 0.25)
		await settle.finished
		npc.start_washing(0.0)
		_sinks.set_running(sink, true), CONNECT_ONE_SHOT)
	npc.go_to(spot)
	var doorway := Vector3(door.point.x, 0.0, door.point.z)
	while npc.global_position.distance_to(doorway) < 1.1:
		await get_tree().process_frame
	if bob != null:
		_restore_collisions(npc, bob) # in the background: the stall is announced now, not when the two have parted


## Bob and the freed Jijio collide again once they no longer overlap (restoring it while they overlap would shove Bob aside). Gives up
## after 30 s, whatever happens.
func _restore_collisions(npc, bob) -> void: # untyped: either may be freed while we wait
	var waited := 0.0
	while is_instance_valid(bob) and is_instance_valid(npc) and npc.global_position.distance_to(bob.global_position) < 0.9 and waited < 30.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	if is_instance_valid(bob) and is_instance_valid(npc):
		npc.remove_collision_exception_with(bob)
		bob.remove_collision_exception_with(npc)


func _on_arrived() -> void:
	_to_arrive -= 1
	if _to_arrive == 0:
		_finish()


func _finish() -> void:
	if not _finished:
		_finished = true
		crowd_arrived.emit()


func _spawn(pos: Vector3, yaw: float) -> Node3D:
	var npc := NPC.instantiate()
	add_child(npc)
	npc.position = pos
	npc.face_yaw(yaw)
	return npc
