extends SceneTree
## NOT a test (not in run.sh): how long Level 4 takes with WATER WAR (SPEC Stage 4 slice 6, owner F: 3 seeds x both rows, min / median /
## max against the 150 s clock). Each run is the whole level on the level clock, with real keys and the live AI everywhere:
##   the three cutters walk in (the clock runs); Bob is placed in front of each one (no walking: the three stand side by side at the
##   stall he must reach anyway, and the walk from the spawn is shorter than their arrival); argue with key presses;
##   fist fights 1 and 2 by the MASHER bot of tests/measure_fight_difficulty.gd (walks in, taps J, a K now and then) against the real AI;
##   WATER WAR by tests/war_bot.gd, once PERFECT (exact head aim, sprints: a lower bound) and once HUMAN (0.35 s reaction, chest aim with
##   a 0.03 rad error, walks: a guess at a person, not a measurement of one).
## Printed per run: time used when the stall is free, and each part. A lost fight or war counts as a fail (clock used so far).
##   "<console exe>" --headless --path . --fixed-fps 60 --script tests/measure_level4_time.gd [-- seeds=3]
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Shooter := preload("res://scripts/shooter.gd")
const WarBot := preload("res://tests/war_bot.gd")

const LIMIT := 150.0

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


func _face(body: Node3D, out: Vector3) -> void:
	var at: Vector3 = body.global_position + out * 0.85
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-out)
	await T.wait(self, 0.3)


## The masher against the real AI until someone is down (or dizzy on fight 2: then the FINISH HIM key).
func _mash(f: Node, rng: RandomNumberGenerator) -> void:
	var t := 0.0
	var next_press := 0.0
	while is_instance_valid(f) and f.running and not (f.bob.is_ko() or f.foe.is_ko() or f.foe.is_dizzy()) and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		var dist: float = absf(f.foe.pos - f.bob.pos)
		_hold(KEY_D if f.foe.pos >= f.bob.pos else KEY_A, dist > 0.75)
		_hold(KEY_A if f.foe.pos >= f.bob.pos else KEY_D, false)
		if t >= next_press and dist <= 0.95:
			next_press = t + rng.randf_range(0.15, 0.3)
			await T.key(self, KEY_SPACE if rng.randf() < 0.2 else KEY_SPACE)
	_release_all()
	if is_instance_valid(f) and f.foe.is_dizzy():
		await T.wait(self, 0.3)
		await T.key(self, KEY_SPACE)


func _run(s: int, stall: int, human: bool) -> Dictionary:
	seed(s)
	Cutters.force_stall = stall
	lvl = T.level(self)
	current_scene = lvl
	await T.wait(self, 0.8)
	p = lvl.player
	var cm: Node = lvl.cutters
	var out := Vector3(0.0, 0.0, 1.0) if stall < 10 else Vector3(0.0, 0.0, -1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + stall
	var parts := {}
	var used := func() -> float: return LIMIT - float(lvl._time_left)
	await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 40.0)
	parts["arrive"] = used.call()
	var ok := true
	for cname: String in ["PUSHY", "SNEAKY", "BOSSY"]:
		var t0: float = used.call()
		var c: Dictionary = cm.cutter(cname)
		await _face(c["body"], out)
		await T.key(self, KEY_E)
		await T.wait(self, 0.6) # reading the opening line
		await T.key(self, KEY_1)
		await T.wait(self, 1.0) # the retort
		await T.key(self, KEY_E)
		await T.wait(self, 0.2)
		var f: Node = cm.fight
		if f == null:
			ok = false
			break
		if cname == "BOSSY":
			var bot := WarBot.new(self, f)
			bot.human = human
			bot.rng.seed = s * 7 + stall
			var r: Dictionary = await bot.play(LIMIT)
			parts["war_hp"] = r["hp"]
			parts["war_hoses"] = r["hoses"]
			ok = r["won"]
		else:
			await T.wait_for(self, func() -> bool: return not is_instance_valid(f) or f.fighting(), 5.0)
			if is_instance_valid(f):
				await _mash(f, rng)
		await T.wait_for(self, func() -> bool: return cm.fight == null or lvl._result.visible, 10.0)
		parts[cname] = used.call() - t0
		if lvl._result.visible or cm.fights_won < ["PUSHY", "SNEAKY", "BOSSY"].find(cname) + 1:
			ok = false
			break
	var total: float = used.call()
	lvl.queue_free()
	await T.wait(self, 0.2)
	return {"ok": ok and total <= LIMIT, "total": total, "parts": parts}


func _init() -> void:
	Progress.level = 4
	var seeds := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
	for human: bool in [false, true]:
		var totals: Array[float] = []
		var fails := 0
		for s in range(1, seeds + 1):
			for stall: int in [4, 16]:
				var r: Dictionary = await _run(s, stall, human)
				var pr: Dictionary = r["parts"]
				print("  %s seed %d stall %d (row %d): %s, %.1f s used of %.0f | arrive %.1f, PUSHY %.1f, SNEAKY %.1f, BOSSY+WAR %.1f (Bob %.0f hp left, %d hoses)" % [
					"HUMAN  " if human else "PERFECT", s, stall % 10 + 1, 1 if stall < 10 else 2, "ok" if r["ok"] else "FAIL", r["total"], LIMIT,
					pr.get("arrive", -1.0), pr.get("PUSHY", -1.0), pr.get("SNEAKY", -1.0), pr.get("BOSSY", -1.0), pr.get("war_hp", -1.0), pr.get("war_hoses", -1)])
				totals.append(r["total"])
				if not r["ok"]:
					fails += 1
		totals.sort()
		print("INFO  %s war bot: %d runs, %d failed; time used min %.1f / median %.1f / max %.1f s of %.0f" % [
			"HUMAN" if human else "PERFECT", totals.size(), fails, totals[0], (totals[(totals.size() - 1) / 2] + totals[totals.size() / 2]) / 2.0, totals[totals.size() - 1], LIMIT])
	Cutters.force_stall = -1
	quit()
