extends RefCounted
## Level 4 fight core: ONE fighter's state on a 1-D line (Street Fighter style). No nodes, so it is fast to test.
## Times come from bob_godot_notes.md: every move is a baked clip (30 fps) played at `speed`, and each hit fires at the clip's
## contact frame, so the fist lands when the animation shows it. Damage/reach/speed are PROPOSAL numbers, tune by playtest.

enum State { IDLE, MOVE, JUMP, HIT, DIZZY, KO }

const FPS := 30.0
const WALK_SPEED := 1.5 ## m/s along the fight line
const MIN_GAP := 0.5 ## fighters never get closer than this
const BLOCK_FACTOR := 0.2 ## a blocked hit does 20% damage
const HIT_STUN := 0.35 ## seconds a landed hit keeps the victim from acting (and cancels their move)
## A blocked hit pushes the defender back and leaves the attacker open a little longer (Street Fighter "block advantage"):
## without it, mashing into a guard cost nothing and a key-masher won 10 of 10 (tests/measure_fight_difficulty.gd).
const BLOCK_PUSHBACK := 0.3
const BLOCK_RECOVERY := 0.2
const JUMP_SECONDS := 0.7
const DIZZY_SECONDS := 3.0 ## FINISH HIM: a finishable fighter at 0 hp staggers this long, then drops (SPEC Level 4 "O")
const METER_MAX := 100.0 ## super meter (SPEC Level 4 "P")
const METER_ON_HIT := 8.0 ## per contact that lands clean
const METER_ON_BLOCK := 5.0 ## per contact the defender blocks
const METER_ON_HURT := 3.0 ## per contact taken (Street Fighter also pays the one getting hit a little)

## clip: the AnimationPlayer clip; frames: its length; speed: playback speed (the raw clips are slow for a fighting game);
## contacts: (frame, damage) per hit; reach: metres; jump_dodges: a jumping opponent is not hit (a punch swings under them);
## high: a crouching opponent is not hit (the jab passes over the head: Street Fighter's "crouch under a high attack").
const MOVES := {
	"punch": {"clip": "punch", "frames": 30, "speed": 1.5, "contacts": [[14, 8.0]], "reach": 0.9, "jump_dodges": true, "high": true},
	"combo": {"clip": "punch_combo", "frames": 48, "speed": 1.3, "contacts": [[12, 3.0], [16, 3.0], [20, 3.0], [24, 3.0], [28, 3.0], [38, 10.0]], "reach": 0.9, "jump_dodges": true, "high": true},
	"kick": {"clip": "kick", "frames": 42, "speed": 1.4, "contacts": [[16, 12.0]], "reach": 1.3, "jump_dodges": false},
	"uppercut": {"clip": "uppercut", "frames": 40, "speed": 1.2, "contacts": [[12, 15.0]], "reach": 0.8, "jump_dodges": false},
	## S A K (owner 2026-09-25, keyboard specials): the spinning roundhouse at full speed, 14 damage (PROPOSAL); the finisher below is the
	## same clip in slow motion.
	"spin": {"clip": "kick_spin", "frames": 54, "speed": 1.3, "contacts": [[33, 14.0]], "reach": 1.4, "jump_dodges": false},
	## S D S D J with a full meter (SPEC "P"): the flying double kick, contacts at frames 16-19 and 23-28.
	"super": {"clip": "kick_double", "frames": 54, "speed": 1.3, "contacts": [[17, 15.0], [24, 20.0]], "reach": 1.3, "jump_dodges": false, "meter": true},
	## S + Space (Stage 7 keys, owner 2026-09-28): the low sweep = the dance `move_down` clip (one leg sweeps a low arc, frames 4-13).
	## Low: it hits a crouching foe, a jumping one is not hit. 9 damage (PROPOSAL).
	"sweep": {"clip": "move_down", "frames": 18, "speed": 1.0, "contacts": [[9, 9.0]], "reach": 1.1, "jump_dodges": true},
	## FINISH HIM (SPEC "O"): the spinning roundhouse, contact at frames 32-37; played in slow motion by the fight scene.
	"finisher": {"clip": "kick_spin", "frames": 54, "speed": 1.0, "contacts": [[33, 10.0]], "reach": 1.4, "jump_dodges": false},
}

## Seconds the move's clip takes at its playback speed.
static func length_of(move_name: String) -> float:
	var m: Dictionary = MOVES[move_name]
	return float(m["frames"]) / FPS / float(m["speed"])


## [[seconds into the move, damage], ...]: each contact frame converted to game time.
static func hits_of(move_name: String) -> Array:
	var m: Dictionary = MOVES[move_name]
	var hits: Array = []
	for c: Array in m["contacts"]:
		hits.append([float(c[0]) / FPS / float(m["speed"]), float(c[1])])
	return hits


var name := ""
var max_hp := 100.0
var hp := 100.0
var pos := 0.0 ## along the fight line
var facing := 1.0 ## +1 looks toward +pos
var state := State.IDLE
var blocking := false
var crouching := false ## S held while free: high attacks (punches) pass over; the fighter cannot walk
var move := ""
var last_move := ""
var t := 0.0 ## seconds into the current move / stun / jump
var meter := 0.0 ## super meter, 0..METER_MAX
var combo := 0 ## hits in the current combo (a hit on a foe still stunned by the last one extends it)
var finishable := false ## at 0 hp: DIZZY first (FINISH HIM), instead of a KO at once
var finished := false ## KO'd by a hit while dizzy (the finisher)
## Space in the air (Stage 7 keys): one kick per jump, landing JUMP_KICK_AT s after the press (PROPOSAL numbers).
const JUMP_KICK := {"reach": 1.2, "jump_dodges": false, "damage": 10.0}
const JUMP_KICK_AT := 0.12
var air_kick := false ## the jump kick was pressed during this jump
var _air_t := 0.0
var _air_fired := false
var _fired := 0 ## how many of the current move's contacts have fired
var _recovery := 0.0 ## extra seconds added to the current move (it was blocked)


func _init(fighter_name: String = "", health: float = 100.0) -> void:
	name = fighter_name
	max_hp = health
	hp = health


func face(foe: RefCounted) -> void:
	var foe_pos: float = foe.get("pos")
	facing = 1.0 if foe_pos >= pos else -1.0


func can_act() -> bool:
	return state == State.IDLE


func is_ko() -> bool:
	return state == State.KO


func is_airborne() -> bool:
	return state == State.JUMP


func is_dizzy() -> bool:
	return state == State.DIZZY


func start_move(move_name: String) -> bool:
	if not can_act() or not MOVES.has(move_name):
		return false
	if bool((MOVES[move_name] as Dictionary).get("meter", false)):
		if meter < METER_MAX:
			return false
		meter = 0.0
	blocking = false
	crouching = false
	state = State.MOVE
	move = move_name
	last_move = move_name
	t = 0.0
	_fired = 0
	_recovery = 0.0
	return true


## A second punch press before the punch's fist lands turns it into the combo (five jabs + haymaker).
func chain_punch() -> bool:
	if state != State.MOVE or move != "punch" or _fired > 0:
		return false
	move = "combo"
	last_move = "combo"
	t = 0.0
	return true


func jump() -> bool:
	if not can_act():
		return false
	blocking = false
	crouching = false
	state = State.JUMP
	move = ""
	t = 0.0
	air_kick = false
	_air_fired = false
	return true


## Space while airborne: the jump kick (once per jump).
func jump_kick() -> bool:
	if state != State.JUMP or air_kick:
		return false
	air_kick = true
	_air_t = 0.0
	last_move = "jump_kick"
	return true


## Holding block only works while free (a fighter in a move, in the air or stunned cannot block).
func set_block(on: bool) -> void:
	blocking = on and can_act()


func set_crouch(on: bool) -> void:
	crouching = on and can_act()


## Walking toward the foe is not possible while guarding or crouching; walking AWAY while guarding is (Street Fighter:
## holding back walks back and blocks).
func walk(dir: float, delta: float, foe: RefCounted) -> void:
	if not can_act() or crouching or (blocking and signf(dir) == facing):
		return
	var foe_pos: float = foe.get("pos")
	var new_pos := pos + signf(dir) * WALK_SPEED * delta
	if absf(foe_pos - new_pos) < MIN_GAP and absf(foe_pos - new_pos) < absf(foe_pos - pos):
		new_pos = foe_pos + (1.0 if pos >= foe_pos else -1.0) * MIN_GAP
	pos = new_pos


## Advances this fighter by `delta` and fires any contact that is due against `foe`.
## Returns an Array of {"by": name, "move": name, "damage": float, "blocked": bool} for every hit that connected.
func step(delta: float, foe: RefCounted) -> Array:
	var events: Array = []
	if state == State.KO:
		return events
	if state == State.IDLE:
		face(foe)
	t += delta
	match state:
		State.MOVE:
			var m: Dictionary = MOVES[move]
			var hits: Array = hits_of(move)
			while _fired < hits.size() and t >= float((hits[_fired] as Array)[0]):
				var damage: float = (hits[_fired] as Array)[1]
				_fired += 1
				var event := _land(foe, m, damage)
				if not event.is_empty():
					events.append(event)
			if state == State.MOVE and t >= length_of(move) + _recovery:
				state = State.IDLE
				move = ""
		State.JUMP:
			if air_kick and not _air_fired:
				_air_t += delta
				if _air_t >= JUMP_KICK_AT:
					_air_fired = true
					move = "jump_kick"
					var event := _land(foe, JUMP_KICK, JUMP_KICK["damage"])
					move = ""
					if not event.is_empty():
						event["move"] = "jump_kick"
						events.append(event)
			if t >= JUMP_SECONDS:
				state = State.IDLE
				air_kick = false
		State.HIT:
			if t >= HIT_STUN:
				state = State.IDLE
		State.DIZZY:
			if t >= DIZZY_SECONDS:
				state = State.KO
	return events


func _land(foe: RefCounted, m: Dictionary, damage: float) -> Dictionary:
	var foe_pos: float = foe.get("pos")
	if bool(foe.call("is_ko")) or absf(foe_pos - pos) > float(m["reach"]):
		return {}
	if bool(foe.call("is_airborne")) and bool(m["jump_dodges"]):
		return {}
	if bool(foe.get("crouching")) and bool(m.get("high", false)):
		return {}
	var blocked: bool = bool(foe.get("blocking"))
	var dealt := damage * (BLOCK_FACTOR if blocked else 1.0)
	if blocked:
		combo = 0
		_recovery = BLOCK_RECOVERY
		foe.set("pos", foe_pos + signf(foe_pos - pos) * BLOCK_PUSHBACK)
	else:
		meter = minf(METER_MAX, meter + METER_ON_HIT)
		combo = combo + 1 if int(foe.get("state")) == State.HIT else 1
	foe.call("take_hit", dealt, blocked)
	return {"by": name, "move": move, "damage": dealt, "blocked": blocked, "combo": combo}


func take_hit(amount: float, blocked: bool) -> void:
	meter = minf(METER_MAX, meter + (METER_ON_BLOCK if blocked else METER_ON_HURT))
	if state == State.DIZZY:
		state = State.KO
		finished = true
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		state = State.DIZZY if finishable else State.KO
		t = 0.0
		blocking = false
		crouching = false
		move = ""
		return
	if not blocked:
		state = State.HIT
		blocking = false
		crouching = false
		move = ""
		t = 0.0
