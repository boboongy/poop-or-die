extends Node
## Level 4 "Cutting the queue" (SPEC "Level 4", owner defaults T-W 2026-09-24): three tinted cutter Jijios, PUSHY (red),
## SNEAKY (blue) and BOSSY (orange), walk in from the back of the waiting room ARRIVE_AT seconds in and stand in front of
## the open stall's door, blocking it. E on one = an argument (numbered replies, every reply ends in a fight), then the
## screen cuts to the fight stage (the open east end: the corridors are too narrow for a side view) and back to where
## Bob stood. BOSSY refuses until the other two are down. Fight n has AI level n; the 2nd fight is the last fist fight,
## so its cutter gets FINISH HIM. The 3rd (BOSSY) is WATER WAR, the first-person shooter (shooter.gd, SPEC Stage 4): BOSSY calls
## her crew, the cutter herself steps out (the shooter spawns its own BOSSY later) and Bob is back in front of the stall after a win.
## A KO'd cutter is taken away (hidden).

signal all_down ## all three KO'd: the stall is free
signal bob_lost ## Bob was KO'd (the level shows its fail screen)
signal fight_started(cutter_name: String)
signal fight_ended ## after every fight, won or lost (the mission list recounts)
signal arrived ## the three have spawned and are walking in

const Fight := preload("res://scripts/fight.gd")
const Shooter := preload("res://scripts/shooter.gd")

const ARRIVE_AT := 5.0
## Per fist fight (1, 2). Owner 2026-09-25 "too easy": at 30 hp a key-masher won 10 of 10 in about 3.5 s
## (tests/measure_fight_difficulty.gd). PROPOSAL numbers, tune by playtest.
const CUTTER_HPS := [60.0, 75.0]
const ENTRANCE := Vector3(-4.6, 0.0, 0.2) ## back of the waiting room (tests/probe_level4_space.gd: open floor)
const STAGE_CENTER := Vector3(11.5, 0.0, -2.5) ## the open east end: 7.1 m clear along Z
const STAGE_AXIS := Vector3(0.0, 0.0, -1.0)
const SPOT_OUT := 0.55 ## how far into the corridor from the door plane they stand
const SPOT_SIDE := 0.7 ## spacing along the corridor
## They first walk to a point this much further out, then step straight in: the open stall's door leaf reaches 0.65 m into the
## corridor and the navmesh (baked with the doors shut) does not know it, so walking along the door line jammed two of them on it.
const WAYPOINT_OUT := 0.6
const BOSS := "BOSSY"
const DEFS := [
	{"name": "PUSHY", "color": Color(0.95, 0.15, 0.1),
		"open": "Outta my way, shorty! I'm going first.",
		"replies": ["I was here first. Back of the line!", "Excuse me, there's a queue.", "Move it or lose it."],
		"retort": "Oh yeah? Make me!"},
	{"name": "SNEAKY", "color": Color(0.15, 0.4, 1.0),
		"open": "Shhh... nobody saw me slip in, right?",
		"replies": ["I saw you. Get out of the line.", "Nice try, sneaky.", "The queue starts back there, buddy."],
		"retort": "Then I'll just have to shut you up!"},
	{"name": "BOSSY", "color": Color(1.0, 0.55, 0.05),
		"open": "I own this toilet. Everybody out!",
		"replies": ["Your crew is on the floor. You're next.", "Nobody owns a toilet.", "I really, REALLY need to go."],
		"retort": "You beat my crew? Cute. CREW! BROWN WATER, NOW!"}, # then round 3, WATER WAR (owner A, slice 6)
]
const WAIT_BOSS := "Deal with my crew first, shorty!"

static var force_stall := -1 ## tests: the level opens this stall (index 0-19) instead of a random one

var pass_through: Array[Node3D] = [] ## other bodies they push through, like the queue (the level adds the open stall's Jijio, who
## washes at the sink straight across the corridor and stopped the middle cutter 0.14 m short)
var cutters: Array = [] ## {"name", "def", "body", "state": coming / waiting / talking / fighting / down}
var fights_won := 0
var fight: Node = null ## the fight in progress
var spots: Array[Vector3] = []

var _level: Node
var _player
var _population
var _dialogue
var _saved_pos := Vector3.ZERO
var _yaw_to_lobby := 0.0
var _out := Vector3.BACK
var _hud_items: Array = []


## `door_point`: the open stall's door (floor level); `corridor_dir`: from the door into the corridor.
func setup(level: Node, door_point: Vector3, corridor_dir: Vector3, arrive_at: float = ARRIVE_AT) -> void:
	_level = level
	_player = level.player
	_population = level.population
	_dialogue = level.dialogue
	for path in ["HUD/MissionLabel", "HUD/PromptLabel", "HUD/StatusLabel", "HUD/CarryLabel"]:
		var n := level.get_node_or_null(path)
		if n:
			_hud_items.append(n)
	var out := Vector3(corridor_dir.x, 0.0, corridor_dir.z).normalized()
	_out = out
	var side := out.cross(Vector3.UP).normalized()
	var base := Vector3(door_point.x, 0.0, door_point.z) + out * SPOT_OUT
	spots.assign([base - side * SPOT_SIDE, base, base + side * SPOT_SIDE])
	_yaw_to_lobby = atan2(-1.0, 0.0) # the waiting room is west (-X): they face where Bob comes from
	if level.intro_playing: # Stage 6b A (owner 2026-09-28): counted from GO, not from the load
		await level.intro_done
	get_tree().create_timer(arrive_at, false).timeout.connect(_arrive)


func _arrive() -> void:
	for i in DEFS.size():
		var def: Dictionary = DEFS[i]
		var body: Node3D = _population.spawn_walker(ENTRANCE + Vector3(0.0, 0.0, 0.6 * (i - 1)), PI / 2.0)
		_population.walkers.erase(body) # nobody else steers a cutter
		for q: Node3D in _population.queue + pass_through: # they push through the queue (solid on the world layer, which blocked them)
			if is_instance_valid(q):
				body.add_collision_exception_with(q)
		body.name = "Cutter_" + String(def["name"])
		_tint(body, def["color"])
		var c := {"name": def["name"], "def": def, "body": body, "state": "coming"}
		cutters.append(c)
		body.set_interaction("E  argue with %s" % def["name"], _on_talk.bind(i))
		body.reached.connect(_on_reached.bind(i))
		body.go_to(spots[i] + _out * WAYPOINT_OUT)
	arrived.emit()


func _on_reached(i: int) -> void:
	var c: Dictionary = cutters[i]
	if c["state"] == "coming": # at the waypoint: now straight in to the spot
		c["state"] = "stepping"
		c["body"].go_to(spots[i])
		return
	if c["state"] == "stepping":
		c["state"] = "waiting"
	c["body"].face_yaw(_yaw_to_lobby)


## Hair and shirt in the cutter's colour, self-lit a little so it reads in the green-lit room (skill 3c).
static func _tint(body: Node3D, color: Color) -> void:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not (m.name.contains("Hair") or m.name.contains("Shirt")):
			continue
		for s in m.get_surface_override_material_count():
			var base := m.get_active_material(s)
			var mat: StandardMaterial3D = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new())
			mat.albedo_texture = null
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.35
			m.set_surface_override_material(s, mat)


static func is_tinted(body: Node3D, color: Color) -> bool:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.contains("Shirt"):
			var mat := m.get_surface_override_material(0) as StandardMaterial3D
			return mat != null and mat.albedo_color.is_equal_approx(color)
	return false


func _on_talk(player: Node3D, i: int) -> void:
	var c: Dictionary = cutters[i]
	if fight != null or not (c["state"] in ["waiting", "coming", "stepping"]):
		return
	var body: Node3D = c["body"]
	var def: Dictionary = c["def"]
	if c["name"] == BOSS and fights_won < 2:
		_dialogue.begin(body, player)
		await _dialogue.say(body, WAIT_BOSS, false, BOSS)
		_dialogue.end(body, player)
		return
	c["state"] = "talking"
	body.stop_walking()
	_dialogue.begin(body, player)
	await _dialogue.choose(body, def["open"], def["replies"], def["name"])
	await _dialogue.say(body, def["retort"], false, def["name"])
	_dialogue.end(body, player)
	_start_fight(i)


func _start_fight(i: int) -> void:
	var c: Dictionary = cutters[i]
	var body: Node3D = c["body"]
	c["state"] = "fighting"
	body.clear_interaction()
	_saved_pos = _player.global_position
	_freeze_walkers(true)
	var number := fights_won + 1
	if c["name"] == BOSS:
		_take_away(body) # she may stand in the arena (the open stall's door); the shooter's BOSSY walks in later
		fight = Shooter.new()
		fight.name = "WaterWar"
		_level.add_child(fight)
		fight.hide_nodes = _hud_items
		fight.bystanders.assign(pass_through.filter(func(n: Node3D) -> bool: return is_instance_valid(n))) # she washes in corridor A
		fight.begin_war(_player)
	else:
		fight = Fight.new()
		_level.add_child(fight)
		fight.hide_nodes = _hud_items
		fight.start(_player, body, STAGE_CENTER, STAGE_AXIS, c["name"], CUTTER_HPS[number - 1], number == 2, number, number, number)
	fight.ended.connect(_on_fight_ended.bind(i), CONNECT_ONE_SHOT)
	fight_started.emit(c["name"])


func _on_fight_ended(winner: String, _finished: bool, i: int) -> void:
	var c: Dictionary = cutters[i]
	var body: Node3D = c["body"]
	if fight is Shooter:
		fight.abort() # first person off, the arena, doors, walkers and E prompts back...
		body.clear_interaction() # ... including her "argue" prompt, which must stay gone
	fight.queue_free()
	fight = null
	_freeze_walkers(false)
	if winner != "BOB":
		fight_ended.emit()
		bob_lost.emit()
		return
	c["state"] = "down"
	_take_away(body) # carried off the stage
	fights_won += 1
	_player.global_position = _saved_pos
	fight_ended.emit()
	if fights_won == DEFS.size():
		all_down.emit()


func _take_away(body: Node3D) -> void:
	body.visible = false
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.collision_layer = 0
	body.collision_mask = 0


## During a fight no walker may wander onto the stage: all of them stop and are hidden until it ends.
func _freeze_walkers(on: bool) -> void:
	for w: Node3D in _population.walkers:
		if not is_instance_valid(w):
			continue
		w.visible = not on
		w.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func cutter(cutter_name: String) -> Dictionary:
	for c: Dictionary in cutters:
		if c["name"] == cutter_name:
			return c
	return {}


## Level timeout or reset mid-fight.
func abort() -> void:
	if fight != null:
		fight.abort()
		fight.queue_free()
		fight = null
		for c: Dictionary in cutters: # the shooter's abort() put every E prompt back
			if c["state"] in ["fighting", "down"]:
				c["body"].clear_interaction()
	_freeze_walkers(false)
