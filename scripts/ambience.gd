extends Node
## The toilet's background soundscape (SPEC "Round 2" Stage 2, owner 2026-09-27 "yes to all"), in every level: a fluorescent hum
## everywhere, the queue muttering in the waiting room (3D), and every few seconds a random sound from where it happens: a flush, a fart
## or a groan from an OCCUPIED stall, a tap running at a sink for a few seconds. Never right next to Bob (his own stall) and a tap only
## from farther away (its water is not shown). Random sounds stop when the level is over. Files: tools/make_ambience.py, sfx.gd "amb_*".
## Stage 6 (SPEC Round 3, owner 2026-09-28 "yes to all"): a CONSTANT bed loop of farts, plops, flushes, sinks and groans through the walls
## (owner's addition); the queue is high Jijio gibberish; a random sound every 1-3 s, max 3 at once, plus plops, tummy rumbles and
## complaints; (D) during a fight, the dance battle or the start dialogue: half as often and 6 dB quieter; (B) Bob groans while holding it
## in, more often and more desperate as the level timer runs low, never while he is busy or a talk box is open.

const Sfx := preload("res://scripts/sfx.gd")
const Sinks := preload("res://scripts/sinks.gd")
const NpcJijio := preload("res://scripts/npc_jijio.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")

const GAP := Vector2(1.0, 3.0) ## s between two random sounds
const WEIGHTS := {"amb_flush": 2, "amb_tap": 2, "amb_fart": 4, "amb_groan": 3, "amb_plop": 3, "amb_tummy": 2, "amb_complain": 3}
## s a sound counts as playing (the files' longest); a tap: its run
const LENGTH := {"amb_flush": 7.0, "amb_fart": 2.0, "amb_groan": 4.0, "amb_plop": 0.4, "amb_tummy": 2.2, "amb_complain": 2.6}
const TAP_SECONDS := Vector2(2.0, 4.5)
const MIN_DISTANCE := 2.0 ## m (floor plan): no random sound this close to Bob
const TAP_MIN_DISTANCE := 5.0
const MAX_AT_ONCE := 3
const CHATTER_AT := Vector3(-2.7, 1.4, 0.2) ## the middle of the queue in the waiting room
const OCCUPANT_UP := 0.5 ## m: a stall sound comes from the sitting occupant's middle
const CHATTER_DUCKED_DB := -40.0
const BUSY_DUCK_DB := -8.0 ## (D) the bed and the random sounds during a fight, the dance battle or the start dialogue (probe_level5_sound)
const BUSY_GAP_FACTOR := 2.0 ## (D) half as often
## (B) Bob's groans: every GROAN_GAP_CALM s with plenty of time, down to GROAN_GAP_LATE in the last GROAN_LATE_SECONDS
const GROAN_GAP_CALM := 12.0
const GROAN_GAP_LATE := 4.0
const GROAN_LATE_SECONDS := 20.0

var hum: AudioStreamPlayer
var bed: AudioStreamPlayer
var chatter: AudioStreamPlayer3D
var heard: Array[Dictionary] = [] ## {event, at, bob, t} for every random sound (tests)
var _level: Node
var _clock := 0.0
var _next := 1.5
var _next_groan := GROAN_GAP_CALM
var _total_time := 60.0 ## the level's full timer (s)
var _ends: Array[float] = [] ## when each playing random sound ends
var _rng := RandomNumberGenerator.new()


func setup(level: Node) -> void:
	_level = level
	# from the global RNG, not randomize(): its sounds draw from the global RNG too (sfx.gd), and unseeded timing made seeded tests
	# differ run to run (test_walkers failed 1 suite run in 2). The game still varies: Godot randomizes the global RNG at startup.
	_rng.seed = randi()
	_total_time = float(LevelDefs.get_level(level.level_number if LevelDefs.has_level(level.level_number) else 1)["time"])


func _ready() -> void:
	hum = Sfx.loop_ui(self, "amb_hum")
	bed = Sfx.loop_ui(self, "amb_bed")
	var spot := Node3D.new()
	spot.name = "ChatterSpot"
	add_child(spot)
	spot.position = CHATTER_AT
	chatter = Sfx.loop_at(spot, "amb_chatter")


func playing_now() -> int:
	return _ends.size()


## (D) A fight, the dance battle or the start dialogue: the background steps back.
func busy_scene() -> bool:
	if _level == null:
		return false
	if _level.intro_playing:
		return true
	if _level.cutters != null and _level.cutters.fight != null:
		return true
	return _level.dance != null and _level.dance.is_disco()


func _physics_process(delta: float) -> void:
	_clock += delta
	_ends = _ends.filter(func(end: float) -> bool: return end > _clock)
	var busy := busy_scene()
	# Level 5's battle ring stands in the waiting room: the chatter fades out under the beat (it clipped the recorded mix with it)
	var disco: bool = _level != null and _level.dance != null and _level.dance.is_disco()
	if is_instance_valid(chatter):
		chatter.volume_db = move_toward(chatter.volume_db, CHATTER_DUCKED_DB if disco else float(Sfx.EVENTS["amb_chatter"]["db"]), 30.0 * delta)
	if is_instance_valid(bed):
		bed.volume_db = move_toward(bed.volume_db, float(Sfx.EVENTS["amb_bed"]["db"]) + (BUSY_DUCK_DB if busy else 0.0), 12.0 * delta)
	_bob_groan_frame()
	if _clock < _next or _level == null or not _level._running:
		return
	# The dance battle: no random sounds at all (only the ducked bed). Its beat + the crowd's shouts already peak near -2 dB; a ducked
	# fart on top reached -0.7 dB and a stack 0.0 dB in the windowed recordings (probe_level5_sound, Stage 6, 2 of 9 runs).
	if disco:
		return
	_next = _clock + _rng.randf_range(GAP.x, GAP.y) * (BUSY_GAP_FACTOR if busy else 1.0)
	if _ends.size() >= MAX_AT_ONCE:
		return
	var event := _pick_event()
	var at: Variant = null
	if event == "amb_tap":
		at = _tap_spot()
	else:
		at = _stall_spot()
	if at == null:
		return
	var bob: Vector3 = _level.player.global_position
	heard.append({"event": event, "at": at, "bob": bob, "t": _clock})
	if event == "amb_tap":
		var seconds := _rng.randf_range(TAP_SECONDS.x, TAP_SECONDS.y)
		_ends.append(_clock + seconds)
		_run_tap(at, seconds, busy)
	else:
		_ends.append(_clock + float(LENGTH[event]))
		var p := Sfx.play_at(self, event, at)
		if p != null and busy:
			p.volume_db += BUSY_DUCK_DB


## (B) Bob holding it in: a groan every GROAN_GAP_CALM s, closing in to GROAN_GAP_LATE s over the level; in the last GROAN_LATE_SECONDS
## they are desperate, from half time bad. Only while the clock runs and Bob is free (not in a sequence, a fight or a talk).
func _bob_groan_frame() -> void:
	if _level == null or not _level._running or _level.player == null:
		_next_groan = maxf(_next_groan, _clock + GROAN_GAP_LATE)
		return
	var talking: bool = _level.dialogue != null and _level.dialogue.is_open()
	if _level.player.busy or talking or busy_scene():
		_next_groan = maxf(_next_groan, _clock + GROAN_GAP_LATE)
		return
	if _clock < _next_groan:
		return
	var left: float = _level._time_left
	var event := "bob_groan"
	var gap := GROAN_GAP_LATE
	if left <= GROAN_LATE_SECONDS:
		event = "bob_groan_desperate"
	else:
		var calm := clampf((left - GROAN_LATE_SECONDS) / maxf(_total_time - GROAN_LATE_SECONDS, 1.0), 0.0, 1.0)
		gap = lerpf(GROAN_GAP_LATE, GROAN_GAP_CALM, calm)
		event = "bob_groan" if left > _total_time * 0.5 else "bob_groan_bad"
	_next_groan = _clock + gap * _rng.randf_range(0.9, 1.1)
	Sfx.play_ui(self, event)


func _pick_event() -> String:
	var total := 0
	for e: String in WEIGHTS:
		total += WEIGHTS[e]
	var r := _rng.randi() % total
	for e: String in WEIGHTS:
		r -= WEIGHTS[e]
		if r < 0:
			return e
	return "amb_flush"


func _far_from_bob(at: Vector3, min_distance: float) -> bool:
	var bob: Vector3 = _level.player.global_position
	return Vector2(at.x - bob.x, at.z - bob.z).length() >= min_distance


## A random stall occupant still sitting in its stall (not walking out, not hidden, not seeking or kicking), away from Bob.
func _stall_spot() -> Variant:
	var spots: Array[Vector3] = []
	for o: Node3D in _level.population.occupants:
		if is_instance_valid(o) and o.visible and o.state == NpcJijio.State.SIT and not o.leaving:
			var at := o.global_position + Vector3.UP * OCCUPANT_UP
			if _far_from_bob(at, MIN_DISTANCE):
				spots.append(at)
	if spots.is_empty():
		return null
	return spots[_rng.randi() % spots.size()]


func _tap_spot() -> Variant:
	var spots: Array[Vector3] = []
	for k in range(1, Sinks.SINK_COUNT + 1):
		var at := Vector3(Sinks.SINK_X_FIRST + Sinks.SINK_X_STEP * (k - 1), 0.0, 0.0) + Sinks.SPOUT
		if _far_from_bob(at, TAP_MIN_DISTANCE):
			spots.append(at)
	if spots.is_empty():
		return null
	return spots[_rng.randi() % spots.size()]


## Someone washing their hands: the tap runs for a few seconds, then fades.
func _run_tap(at: Vector3, seconds: float, quiet: bool) -> void:
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = at
	var loop := Sfx.loop_at(spot, "amb_tap")
	if quiet:
		loop.volume_db += BUSY_DUCK_DB
	await get_tree().create_timer(seconds, false).timeout
	Sfx.fade_out(loop, 0.6)
	await get_tree().create_timer(0.7, false).timeout
	if is_instance_valid(spot):
		spot.queue_free()
