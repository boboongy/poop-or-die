extends SceneTree
## Measure (not in the suite): how hard the Level 4 fist fights are. Two bots press REAL keys against the real AI:
##   masher: walks in and taps J (a kick now and then): the "too easy" player the owner beat without trying;
##   good:   blocks (hold back, or L on the old controls) when the cutter starts an attack in range, 0.2 s human reaction,
##           then punishes with S D J; pokes with J/K otherwise.
## Per fight number (1, 2) and bot: wins of N seeds, average fight time, Bob's hp left. Cutter hp from cutters.gd.
## Run: godot --headless --fixed-fps 60 --script tests/measure_fight_difficulty.gd [-- seeds=10]
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Fight := preload("res://scripts/fight.gd")
const Fighter := preload("res://scripts/fighter.gd")
const Cutters := preload("res://scripts/cutters.gd")

const CENTER := Vector3(11.5, 0.0, -2.5)
const AXIS := Vector3(0.0, 0.0, -1.0)
const REACT := 0.2
const LIMIT := 60.0 ## s: a fight still running after this counts as a loss (the level has 90 s for everything)

var lvl: Node
var p: CharacterBody3D
var _held := {}


func _hold(code: int, on: bool) -> void:
	if bool(_held.get(code, false)) == on:
		return
	_held[code] = on
	T._key_event(code, on)


func _release_all() -> void:
	for code: int in _held:
		if _held[code]:
			T._key_event(code, false)
	_held = {}


func _cutter_hp(n: int) -> float:
	var consts: Dictionary = (Cutters as Script).get_script_constant_map()
	if consts.has("CUTTER_HPS"):
		return float(consts["CUTTER_HPS"][n - 1])
	return float(consts["CUTTER_HP"])


## Keys that walk toward / away from the foe (Bob is on the fight line; +pos is screen-right = D).
func _toward_key(f: Node) -> int:
	return KEY_D if f.foe.pos >= f.bob.pos else KEY_A


func _away_key(f: Node) -> int:
	return KEY_A if f.foe.pos >= f.bob.pos else KEY_D


func _one(n: int, bot: String, s: int) -> Array:
	var npc: Node3D = lvl.population.spawn_walker(CENTER + AXIS * 2.0, 0.0)
	lvl.population.walkers.erase(npc)
	var f: Node = Fight.new()
	lvl.add_child(f)
	f.intro_seconds = 0.0
	f.start(p, npc, CENTER, AXIS, "CUTTER", _cutter_hp(n), n == 2, n, s, n)
	await process_frame
	var tally := {"bob_hit": 0, "bob_blocked": 0, "foe_hit": 0, "foe_blocked": 0}
	f.hit_landed.connect(func(e: Dictionary) -> void:
		var who := "bob" if e["victim"] == "BOB" else "foe"
		tally[who + ("_blocked" if e["blocked"] else "_hit")] += 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + n
	var t := 0.0
	var seen_attack := -1.0 ## when the good bot noticed the cutter's attack
	var next_press := 0.0
	var hold_back := false
	var last_foe_move := 9.0 ## s since the cutter's last move ended
	while f.running and t < LIMIT and not (f.bob.is_ko() or f.foe.is_ko() or f.foe.is_dizzy()):
		await physics_frame
		t += 1.0 / 60.0
		var dist: float = absf(f.foe.pos - f.bob.pos)
		if bot == "masher":
			_hold(_toward_key(f), dist > 0.75)
			if t >= next_press and dist <= 0.95:
				next_press = t + rng.randf_range(0.15, 0.3)
				await T.key(self, KEY_SPACE if rng.randf() < 0.2 else KEY_SPACE)
			continue
		# good bot
		var foe_attacking: bool = f.foe.state == Fighter.State.MOVE and dist < 1.5
		if foe_attacking and seen_attack < 0.0:
			seen_attack = t
		if not foe_attacking:
			seen_attack = -1.0
		var want_block := seen_attack >= 0.0 and t - seen_attack >= REACT
		if want_block != hold_back:
			hold_back = want_block
			_hold(_away_key(f), want_block)
		if want_block:
			_hold(_toward_key(f), false)
			continue
		# patient: punish the cutter's recovery (just after its move) with the flurry or a kick; otherwise hover at kick
		# range and poke with the kick now and then
		var foe_open: bool = f.foe.state == Fighter.State.HIT or (f.foe.state == Fighter.State.IDLE and last_foe_move < 0.35)
		if f.foe.state == Fighter.State.MOVE:
			last_foe_move = 0.0
		else:
			last_foe_move += 1.0 / 60.0
		_hold(_toward_key(f), dist > (0.75 if foe_open else 1.2) and f.bob.can_act())
		if t >= next_press and f.bob.can_act():
			if foe_open and dist <= 0.95:
				next_press = t + 0.3
				_hold(_toward_key(f), false)
				for k: int in [KEY_S, _toward_key(f), KEY_SPACE]:
					await T.key(self, k)
			elif dist <= 1.3 and rng.randf() < 0.25:
				next_press = t + rng.randf_range(0.5, 0.9)
				await T.key(self, KEY_SPACE)
	_release_all()
	var won: bool = f.foe.is_ko() or f.foe.is_dizzy()
	var bob_hp: float = f.bob.hp
	f.abort()
	f.queue_free()
	npc.queue_free()
	await T.wait(self, 0.1)
	if s <= 2:
		print("  fight %d %s seed %d: won=%s %.1f s, Bob took %d hits / blocked %d, cutter took %d / blocked %d" % [n, bot, s, won, t, tally["bob_hit"], tally["bob_blocked"], tally["foe_hit"], tally["foe_blocked"]])
	return [won, t, bob_hp]


func _init() -> void:
	var seeds := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
	Progress.level = 1
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 1.0e9
	p = lvl.player
	for n in [1, 2]:
		for bot in ["masher", "good"]:
			var wins := 0
			var time_sum := 0.0
			var hp_sum := 0.0
			for s in seeds:
				var r: Array = await _one(n, bot, s + 1)
				if r[0]:
					wins += 1
					hp_sum += float(r[2])
				time_sum += float(r[1])
			print("INFO  fight %d (cutter %.0f hp), %-6s: won %d of %d, average %.1f s, Bob's hp left when winning %.0f" % [n, _cutter_hp(n), bot, wins, seeds, time_sum / seeds, hp_sum / maxf(wins, 1)])
	quit()
