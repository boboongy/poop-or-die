extends Node3D
## One level of the game. Which level is decided by Progress.level and the data in LevelDefs; the missions
## come from the MissionManager. When every mission is done a random stall opens (reward), Bob uses it, and
## the timer stops when he sits down. If time runs out, the queued Jijios walk to Bob and kick him.

const Progress := preload("res://scripts/progress.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Walkers := preload("res://scripts/walkers.gd")
const Flood := preload("res://scripts/flood.gd")
const FloodWater := preload("res://scripts/flood_water.gd")
const FloodStory := preload("res://scripts/flood_story.gd")
const MopTool := preload("res://scripts/mop_tool.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Dance := preload("res://scripts/dance.gd")
const Intro := preload("res://scripts/intro.gd")
const Ambience := preload("res://scripts/ambience.gd")
const QueueTalk := preload("res://scripts/queue_talk.gd")
const MissionShouts := preload("res://scripts/mission_shouts.gd")
const ShatStain := preload("res://scripts/shat_stain.gd")

signal intro_done ## the start dialogue is over (or there is none): the clock runs

@export var kick_seconds := 3.0
## The kicked-out screen shows at most this long after the clock hits 0, even if the crowd is still running to Bob
## (owner 2026-09-25: from the far east end it took 6 s, from corridor B 8 s; test_kickout_time).
@export var kickout_max := 2.2

var level_number := 1
var ctx := {} ## shared notes between the missions of this level (e.g. which stall needs tissue)
var flood: Node3D ## Level 2: the first leftover puddle once the flood has drained (null before and in other levels)
var floods: Array[Node3D] = [] ## Level 2: the 4 leftover puddles (flood_story.gd), empty until the drain
var mop: Node ## Level 2: the mop in Bob's hands (null in other levels)
var water: Node3D ## Level 2 "The flood": the rising water (flood_water.gd; null in other levels)
var flood_story: Node3D ## Level 2 "The flood": the clogged stall, the rampage, the plunger, taps and plug (flood_story.gd)
var hide_seek: Node ## Level 3: the hide-and-seek director (null in other levels)
var cutters: Node ## Level 4: the three queue cutters and their fights (null in other levels)
var dance: Node ## Level 5: SHUFFLE QUEEN and the dance battle (null in other levels)
var intro: Node ## the start dialogue while it plays (null when the level has none, or in tests without `-- intro`)
var intro_playing := false ## the clock is paused until the start dialogue ends
var shat_stain: Node ## Stage 6d: the brown patch on a loss (shat_stain.gd)

var _time_left := 0.0
var _running := true
var _game_over := false

@onready var player = $Player
@onready var population = $Population
@onready var stalls = $NavRegion/Stalls
@onready var dialogue = $Dialogue
@onready var _manager = $MissionManager
@onready var _label: Label = $HUD/TimerLabel
@onready var _result: Label = $HUD/ResultLabel
@onready var _nav: NavigationRegion3D = $NavRegion
@onready var _prompt: Label = $HUD/PromptLabel
@onready var _fps: Label = $HUD/FpsLabel
@onready var _mission: Label = $HUD/MissionLabel
@onready var _carry: Label = $HUD/CarryLabel
@onready var _status: Label = $HUD/StatusLabel
@onready var _session = $ToiletSession


## A safety net at the end of the Master bus: nothing can clip. The mix itself is set to peak under -1 dB WITHOUT it (measured in
## windowed recordings, tests/probe_soundscape.gd, whose recorder sits before this limiter). project.godot is editor-owned: added in code.
static func ensure_limiter() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)


func _ready() -> void:
	ensure_limiter()
	level_number = Progress.level if LevelDefs.has_level(Progress.level) else 1
	var def := LevelDefs.get_level(level_number)
	_time_left = def["time"]
	intro_playing = def.has("intro") and Intro.enabled # first: Level 3's hide_seek.setup (below) already asks
	population.crowd_arrived.connect(_on_crowd_arrived)
	_session.status_changed.connect(func(text: String) -> void: _status.text = text)
	_session.sat_down.connect(_on_sat_down)
	_session.finished.connect(_on_finished)
	# The walkable area comes from the toilet's collision shapes.
	# A fine grid: the stall doorways are only 0.65 m wide and a 0.25 m grid rounds some of them shut.
	var map := _nav.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	_nav.bake_navigation_mesh(false)
	population.set_nav_height(_navmesh_height())
	var walkers := Walkers.new() # the Jijios walking about the corridors (random 2-6 per level)
	walkers.name = "Walkers"
	add_child(walkers)
	walkers.setup(self)
	var queue_talk := QueueTalk.new() # E on any queue Jijio: a small talk (Stage 6c D)
	queue_talk.name = "QueueTalk"
	add_child(queue_talk)
	queue_talk.setup(self)
	var ambience := Ambience.new() # the background soundscape: hum, chatter, flushes, farts, groans, taps
	ambience.name = "Ambience"
	ambience.setup(self)
	add_child(ambience)
	stalls.setup_doors() # after the bake, so closed doors don't cut the stalls off the navmesh
	if def.get("rising", false):
		_start_rising()
	if def.get("hide_seek", false):
		hide_seek = HideSeek.new()
		hide_seek.name = "HideSeek"
		add_child(hide_seek)
		hide_seek.setup(self)
	if def.get("cutters", false):
		_start_cutters()
	if def.get("dance", false):
		dance = Dance.new()
		dance.name = "Dance"
		add_child(dance)
		dance.setup(self)
		ctx["reward_stall"] = dance.stall # her stall opens only when Bob wins
	player.carrying_changed.connect(func(text: String) -> void: _carry.text = text)
	player.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	player.set_facing(-PI / 2.0) # Bob starts at the back of the queue, looking east toward the door
	_manager.changed.connect(_update_mission_text)
	_manager.all_done.connect(_on_all_missions_done)
	_manager.load_level(level_number, self)
	shat_stain = ShatStain.new() # Stage 6d: the loss patch
	shat_stain.name = "ShatStain"
	shat_stain.setup(player)
	add_child(shat_stain)
	var shouts := MissionShouts.new() # a Jijio shouts each new mission (Stage 6c G)
	shouts.name = "MissionShouts"
	shouts.setup(self, _manager)
	add_child(shouts)
	_update_label()
	if intro_playing:
		_running = false
		intro = Intro.new()
		intro.name = "Intro"
		add_child(intro)
		_play_intro.call_deferred(def["intro"])


## The start dialogue (intro.gd), then the clock starts.
func _play_intro(id: String) -> void:
	await intro.run(self, id)
	intro_playing = false
	if not _game_over:
		_running = true
	intro_done.emit()


## Level 2 "The flood" (SPEC Round 2 Stage 3): the rising water (flood_water.gd) and its story and tasks (flood_story.gd). The story
## starts at GO (after the intro, or at once when there is none); the leftover puddles and the mop come after the drain.
func _start_rising() -> void:
	water = FloodWater.new()
	water.name = "FloodWater"
	add_child(water)
	water.setup(self)
	player.water = water
	flood_story = FloodStory.new()
	flood_story.name = "FloodStory"
	add_child(flood_story)
	flood_story.setup(self, water)
	mop = MopTool.new()
	mop.name = "Mop"
	add_child(mop)
	mop.setup(self)
	player.floor_wet_fn = any_wet
	if intro_playing:
		intro_done.connect(flood_story.start, CONNECT_ONE_SHOT)
	elif FloodStory.auto_start:
		flood_story.start.call_deferred()


## Level 4: one random stall opens at the start (its Jijio goes to wash), and the three cutters come to block it
## (SPEC "Level 4"). The door plane and the corridor side come from the door and its occupant (row 1 opens to +Z, row 2 to -Z).
func _start_cutters() -> void:
	var index: int = Cutters.force_stall if Cutters.force_stall >= 0 else population.pick_free_stall()
	ctx["open_stall"] = index
	var door: Node3D = stalls.doors[index]
	var occupant: Node3D = population.occupants[index]
	var out := Vector3(0.0, 0.0, signf(door.point.z - occupant.global_position.z))
	# next frame (the door's sound cannot join the tree while the level is still being added), not awaited: the Jijio walks to the sink
	population.reward_release.call_deferred(index)
	cutters = Cutters.new()
	cutters.name = "Cutters"
	add_child(cutters)
	cutters.pass_through.append(occupant)
	cutters.setup(self, Vector3(door.point.x, 0.0, door.point.z), out)
	cutters.bob_lost.connect(_on_bob_lost)


## Level 4: Bob lost a fight. Like being caught in Level 3: the timer stops, R = try again.
func _on_bob_lost() -> void:
	if _game_over:
		return
	_game_over = true
	_running = false
	_session.abort()
	player.frozen = true
	(player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).make_current() # the fist fight's camera went with the fight
	_mission.text = ""
	Sfx.play_ui(self, "ui_lose")
	show_result("KNOCKED OUT!\nPress R to try again")
	bob_shat()


## Stage 6d: every loss = the brown patch on Bob's shorts, the squelch and a 1 s look from behind (shat_stain.gd).
func bob_shat() -> void:
	shat_stain.shat()


## True when the floor under `p` is wet in any of the puddles.
func any_wet(p: Vector3) -> bool:
	for f in floods:
		if f.wet_at(p):
			return true
	return false


## The puddles still to mop (still growing, or with water left).
func puddles_left() -> int:
	var n := 0
	for f in floods:
		if not f.is_clean():
			n += 1
	return n


## "stall 3 (first row), sink 6, stall 12 (back row) and sink 9" for hints.
func puddle_text() -> String:
	var names: Array[String] = []
	for f in floods:
		names.append(f.label())
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


## The baked navmesh floats a little above the floor; agents need to know by how much.
func _navmesh_height() -> float:
	var verts := _nav.navigation_mesh.get_vertices()
	var lowest := INF
	for v in verts:
		lowest = minf(lowest, v.y)
	return lowest if lowest != INF else 0.0


func _process(delta: float) -> void:
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if not _running:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_update_label()
	if _time_left <= 0.0:
		_running = false
		_session.abort()
		if cutters:
			cutters.abort() # a fight in progress hands Bob and his camera back first
		if dance:
			dance.abort() # the dance battle too
		player.frozen = true
		player.busy = false
		_label.text = "0.0"
		population.start_kicking(player)
		get_tree().create_timer(kickout_max).timeout.connect(_kicked_out)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_F3:
		_fps.visible = not _fps.visible
	elif event.keycode == KEY_F4: # debug: jump to the next level (back to 1 after the last one)
		Progress.level = level_number + 1 if LevelDefs.has_level(level_number + 1) else 1
		get_tree().reload_current_scene()
	elif _game_over and event.keycode == KEY_R:
		get_tree().reload_current_scene() # retry the same level
	elif _game_over and event.keycode == KEY_N and _won and LevelDefs.has_level(level_number + 1):
		Progress.level = level_number + 1
		get_tree().reload_current_scene()


var _won := false


func _update_mission_text() -> void:
	if _running and not _session_started():
		_mission.text = "LEVEL %d: %s\n%s" % [level_number, LevelDefs.get_level(level_number)["name"], _manager.checklist_text()]


func _session_started() -> bool:
	return _all_done


var _all_done := false


func _on_all_missions_done() -> void:
	_all_done = true
	var index: int
	if ctx.has("open_stall"): # Level 4: the stall has been open since the start, the cutters were in the way
		index = ctx["open_stall"]
	else:
		_mission.text = "ALL MISSIONS DONE! A stall is opening..."
		index = ctx.get("reward_stall", -1) # Level 5: the stall SHUFFLE QUEEN was waiting for
		if index < 0:
			index = population.pick_free_stall()
		await population.reward_release(index, player)
	if _game_over or not _running:
		return
	_session.setup(index)
	var row := 1 if index < 10 else 2
	_mission.text = "Stall %d (row %d) is free! Get in and use it before time runs out." % [index % 10 + 1, row]


## Level 3: a seeker found Bob. The timer stops and he is frozen; the jump scare shows the result screen (R = try again).
func on_caught() -> void:
	if _game_over:
		return
	_game_over = true
	_running = false
	_session.abort()
	player.frozen = true
	_mission.text = ""


func show_result(text: String) -> void:
	_result.text = text
	_result.visible = true


## Bob sat down: the timer stops now. Wiping and flushing can take as long as he likes.
func _on_sat_down() -> void:
	_running = false
	_mission.text = "Made it in time! Take your time: wipe and flush."
	_label.text = "%.1f" % _time_left


func _on_finished() -> void:
	_game_over = true
	_won = true
	Sfx.play_ui(self, "ui_win")
	if not LevelDefs.has_level(level_number + 1): # the finale (Level 5, SPEC "Level 5": "THE END" after the flush)
		_result.text = "THE END\nYou beat the queue in all %d levels!\n%.1f s to spare\nThanks for playing!\nR: play again    F4: back to Level 1" % [level_number, _time_left]
	else:
		_result.text = "LEVEL %d COMPLETE!\n%.1f s to spare\nN: next level    R: play again" % [level_number, _time_left]
	_result.visible = true


func _on_crowd_arrived() -> void:
	await get_tree().create_timer(kick_seconds).timeout
	_kicked_out()


func _kicked_out() -> void:
	if _game_over or _won:
		return
	_game_over = true
	Sfx.play_ui(self, "ui_lose")
	_result.text = "THEY KICKED YOU OUT\nPress R to try again"
	_result.visible = true
	bob_shat()


func _update_label() -> void:
	_label.text = "%.1f" % _time_left
