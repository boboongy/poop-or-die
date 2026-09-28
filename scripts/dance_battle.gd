extends Node
## Level 5: the rhythm battle, best of 3 rounds (SPEC "Level 5"; numbers are PROPOSAL, tune by playtest). Every round is 20 beats
## (12 s at 100 BPM), all on the beat clock of dance.gd (`now()`, the song time):
##   beats 0-2 "ROUND n" | 2-8 SHUFFLE QUEEN's turn (she dances her own chart; her score is QUEEN_ACC) | 8-10 "YOUR TURN!" (the first
##   arrows are already rising) | 10-18 Bob's turn: NOTES[n] arrows on the half-beat grid | 18-20 the round's result.
## Bob presses the arrow keys (or W A S D) as each arrow crosses the line: PERFECT within PERFECT s (100 points), GREAT within GREAT s (75),
## GOOD within GOOD s (50), an arrow that passes unhit is a MISS. Stage 7 E1 (owner 2026-09-28): EVERY press is judged: a press with no
## arrow in reach is EARLY or LATE (toward the lane's nearest arrow) and breaks the combo (it used to show nothing, so only MISS ever
## appeared). Bob wins a round when his accuracy (points / 100 per note) is at least hers. First to two rounds wins (`ended`).

signal ended(bob_won: bool)
signal judged(lane: int, result: String)

const DanceBeat := preload("res://scripts/dance_beat.gd")

const LANES := ["left", "down", "up", "right"]
const LANE_KEYS := [[KEY_LEFT, KEY_A], [KEY_DOWN, KEY_S], [KEY_UP, KEY_W], [KEY_RIGHT, KEY_D]]
const NOTES := [12, 14, 16] ## Bob's arrows per round
const QUEEN_NOTES := [7, 8, 9] ## her arrows per round (shown, played by her)
const QUEEN_ACC := [0.7, 0.8, 0.9]
const PERFECT := 0.07
const GREAT := 0.12 ## Stage 7 E1 (PROPOSAL)
const GOOD := 0.20 ## Stage 7 E1 DECIDED: 0.15 -> 0.20
const POINTS := {"PERFECT": 100, "GREAT": 75, "GOOD": 50}
const INTRO_BEATS := 2
const QUEEN_BEATS := 6
const CALL_BEATS := 2
const BOB_BEATS := 8
const RESULT_BEATS := 2
const ROUND_BEATS := INTRO_BEATS + QUEEN_BEATS + CALL_BEATS + BOB_BEATS + RESULT_BEATS ## rounds 1-2 (round 3 is longer, round_beats())
## Power moves by round (owner 2026-09-25, "O = rounds"): round 1 arrow steps only; from round 2 each dancer ends their turn with the
## round's power move, she in the call, Bob in the result. The worm is the battle winner's finale (dance.gd). Beats = clip length at 100 BPM.
const POWER := {2: "flare", 3: "headspin"}
const POWER_BEATS := {"flare": 2, "headspin": 4}
const APPROACH := 1.6 ## seconds an arrow is on screen before it reaches the line

var dance ## dance.gd (untyped: its clock and move methods are called)
var round_number := 1
var rounds_bob := 0
var rounds_queen := 0
var notes: Array = [] ## Bob's arrows this round: {"t", "lane", "hit": "" / PERFECT / GOOD / MISS}
var queen_notes: Array = [] ## hers: {"t", "lane", "ok", "done"}
var phase := "" ## intro, queen, call, bob, result
var over := false
var bob_won := false
var perfects := 0
var greats := 0
var goods := 0
var misses := 0
var off_beat := 0 ## EARLY / LATE presses
var best_combo := 0
var combo := 0
var round_log: Array = [] ## {"round", "bob", "queen", "winner"}
var auto_miss := true ## arrows that pass unhit become MISSES (tests switch it off to call judge() by hand)

var _round_start := 0.0
var _points := 0
var _rng := RandomNumberGenerator.new()


func now() -> float:
	return dance.song_time()


func beat() -> float:
	return DanceBeat.beat_seconds()


## Round 1 starts at song time `at` (a beat).
func start(dance_node, at: float, rng_seed: int = 1) -> void:
	dance = dance_node
	_rng.seed = rng_seed
	_begin_round(1, at)


func round_start() -> float:
	return _round_start


func bob_turn_start() -> float:
	return _round_start + (INTRO_BEATS + QUEEN_BEATS + call_beats(round_number)) * beat()


## The call and the result stretch to fit that round's power move (the headspin is 4 beats).
static func call_beats(r: int) -> int:
	return maxi(CALL_BEATS, POWER_BEATS.get(POWER.get(r, ""), 0))


static func result_beats(r: int) -> int:
	return maxi(RESULT_BEATS, POWER_BEATS.get(POWER.get(r, ""), 0))


static func round_beats(r: int) -> int:
	return INTRO_BEATS + QUEEN_BEATS + call_beats(r) + BOB_BEATS + result_beats(r)


## Bob's accuracy this round so far (0..1), counting every note of the round.
func accuracy() -> float:
	return float(_points) / (100.0 * notes.size()) if notes.size() > 0 else 0.0


func queen_accuracy() -> float:
	return QUEEN_ACC[round_number - 1]


func _begin_round(r: int, at: float) -> void:
	round_number = r
	_round_start = at
	phase = ""
	_points = 0
	notes = make_chart(r, bob_turn_start(), _rng)
	queen_notes = _queen_chart(r, at + INTRO_BEATS * beat())


## Bob's arrows for round `r`, starting at `from`: every beat of his 8, plus random half-beats (12 / 14 / 16 notes). The same arrow never
## comes twice on neighbouring half-beats.
static func make_chart(r: int, from: float, rng: RandomNumberGenerator) -> Array:
	var half := DanceBeat.beat_seconds() / 2.0
	var slots: Array[int] = []
	for s in BOB_BEATS:
		slots.append(s * 2)
	var off: Array[int] = []
	for s in BOB_BEATS:
		off.append(s * 2 + 1)
	for k in NOTES[r - 1] - BOB_BEATS:
		slots.append(off.pop_at(rng.randi() % off.size()))
	slots.sort()
	var chart: Array = []
	var last_lane := -1
	var last_slot := -10
	for s in slots:
		var lane := rng.randi() % 4
		if s - last_slot == 1 and lane == last_lane:
			lane = (lane + 1 + rng.randi() % 3) % 4
		chart.append({"t": from + s * half, "lane": lane, "hit": ""})
		last_lane = lane
		last_slot = s
	return chart


## Her show-off: every beat of her 6 plus random half-beats; exactly round((1 - accuracy) * n) of them she fumbles.
func _queen_chart(r: int, from: float) -> Array:
	var half := beat() / 2.0
	var slots: Array[int] = []
	for s in QUEEN_BEATS:
		slots.append(s * 2)
	var off: Array[int] = []
	for s in QUEEN_BEATS:
		off.append(s * 2 + 1)
	for k in QUEEN_NOTES[r - 1] - QUEEN_BEATS:
		slots.append(off.pop_at(_rng.randi() % off.size()))
	slots.sort()
	var chart: Array = []
	for s in slots:
		chart.append({"t": from + s * half, "lane": _rng.randi() % 4, "ok": true, "done": false})
	var fumbles := int(round((1.0 - QUEEN_ACC[r - 1]) * chart.size()))
	var order := range(chart.size())
	for k in fumbles:
		chart[order.pop_at(_rng.randi() % order.size())]["ok"] = false
	return chart


## Judge a press of `lane` at song time `t`: the nearest unjudged arrow of that lane within GOOD = PERFECT, GREAT or GOOD. No arrow in
## reach = EARLY (the lane's nearest unjudged arrow is still coming, or none is left) or LATE (it has gone by); the combo breaks.
func judge(lane: int, t: float) -> String:
	var best: Dictionary = {}
	var best_off := INF
	var nearest_dt := INF # signed (note time - press) of the lane's nearest arrow, for EARLY / LATE
	for note: Dictionary in notes:
		if note["lane"] != lane:
			continue
		var dt: float = float(note["t"]) - t
		if note["hit"] == "" and absf(dt) < absf(nearest_dt):
			nearest_dt = dt
		if note["hit"] != "":
			continue
		var off := absf(dt)
		if off <= GOOD and off < best_off:
			best = note
			best_off = off
	if best.is_empty():
		var off_result := "LATE" if nearest_dt < 0.0 else "EARLY"
		off_beat += 1
		combo = 0
		judged.emit(lane, off_result)
		return off_result
	var result := "PERFECT" if best_off <= PERFECT else ("GREAT" if best_off <= GREAT else "GOOD")
	best["hit"] = result
	_points += POINTS[result]
	match result:
		"PERFECT":
			perfects += 1
		"GREAT":
			greats += 1
		_:
			goods += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	judged.emit(lane, result)
	if dance:
		dance.on_bob_move(lane, true)
	return result


func _input(event: InputEvent) -> void:
	if over or not (phase == "call" or phase == "bob"):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	for lane in LANE_KEYS.size():
		if event.physical_keycode in LANE_KEYS[lane] or event.keycode in LANE_KEYS[lane]:
			get_viewport().set_input_as_handled()
			judge(lane, now())
			return


func _physics_process(_delta: float) -> void:
	if over or dance == null:
		return
	var t := now()
	var b := (t - _round_start) / beat()
	var want := "intro"
	var call_n := call_beats(round_number)
	if b >= INTRO_BEATS + QUEEN_BEATS + call_n + BOB_BEATS:
		want = "result"
	elif b >= INTRO_BEATS + QUEEN_BEATS + call_n:
		want = "bob"
	elif b >= INTRO_BEATS + QUEEN_BEATS:
		want = "call"
	elif b >= INTRO_BEATS:
		want = "queen"
	if want != phase:
		phase = want
		_on_phase()
	for q: Dictionary in queen_notes:
		if not q["done"] and t >= float(q["t"]):
			q["done"] = true
			dance.on_queen_move(q["lane"], q["ok"])
	if auto_miss:
		for note: Dictionary in notes:
			if note["hit"] == "" and t - float(note["t"]) > GOOD:
				note["hit"] = "MISS"
				misses += 1
				combo = 0
				judged.emit(note["lane"], "MISS")
				dance.on_bob_move(note["lane"], false)
	if b >= round_beats(round_number):
		if rounds_bob >= 2 or rounds_queen >= 2:
			over = true
			bob_won = rounds_bob >= 2
			phase = "over"
			ended.emit(bob_won)
		else:
			_begin_round(round_number + 1, _round_start + round_beats(round_number) * beat())


func _on_phase() -> void:
	var hud = dance.hud
	match phase:
		"intro":
			if hud:
				hud.announce("ROUND %d" % round_number, Color.WHITE, 0.6)
		"queen":
			if hud:
				hud.banner("SHUFFLE QUEEN's turn: watch!")
			dance.camera_focus(false, QUEEN_BEATS * beat())
		"call":
			if hud:
				hud.announce("YOUR TURN!", Color(1.0, 0.85, 0.1), 0.6)
				hud.banner("YOUR TURN: arrow keys or W A S D")
			if POWER.has(round_number):
				dance.on_power_move(false, POWER[round_number]) # she ends her turn with it
		"bob":
			dance.camera_focus(true, BOB_BEATS * beat())
		"result":
			var acc := accuracy()
			var winner := "BOB" if acc >= queen_accuracy() else "SHUFFLE QUEEN"
			if winner == "BOB":
				rounds_bob += 1
			else:
				rounds_queen += 1
			round_log.append({"round": round_number, "bob": acc, "queen": queen_accuracy(), "winner": winner})
			if hud:
				hud.banner("")
				hud.announce("%s WINS ROUND %d" % ["BOB" if winner == "BOB" else "SHE", round_number],
						Color(0.4, 1.0, 0.5) if winner == "BOB" else Color(1.0, 0.3, 0.6), 0.8)
			dance.on_round_result(winner == "BOB")
			if POWER.has(round_number):
				dance.on_power_move(true, POWER[round_number]) # Bob ends his turn with it
