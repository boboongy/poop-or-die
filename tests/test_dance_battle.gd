extends SceneTree
## Level 5 step 5-6: the rhythm battle (dance_battle.gd) on the real level, reached through the real rush and circle. Checks the note
## charts (12/14/16 notes, on the half-beat grid, inside Bob's turn), the timing windows (PERFECT +-0.07 s, GOOD +-0.15 s), and whole
## battles played by bots through REAL key presses: perfect (wins 2-0, the stall opens), silent (loses, instant rematch, the timer keeps
## running), 75 % (wins round 1 vs 70 %, loses round 2 vs 80 %), and a level timeout in the middle of a round. Written before the code.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Battle := preload("res://scripts/dance_battle.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")
const MissionBase := preload("res://scripts/missions/mission.gd")

const KEYS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]


func _init() -> void:
	seed(3)
	Progress.level = 5
	_chart_checks()
	var lvl := await _to_battle(6)
	await _window_checks(lvl)
	lvl.queue_free()
	await process_frame
	lvl = await _to_battle(6)
	await _perfect_bot(lvl)
	lvl.queue_free()
	await process_frame
	lvl = await _to_battle(13)
	await _silent_bot(lvl)
	lvl.queue_free()
	await process_frame
	lvl = await _to_battle(13)
	await _partial_bot(lvl)
	lvl.queue_free()
	await process_frame
	lvl = await _to_battle(2)
	await _timeout_mid_round(lvl)
	lvl.queue_free()
	await process_frame
	Dance.force_stall = -1
	T.finish(self)


func _chart_checks() -> void:
	var rng := RandomNumberGenerator.new()
	var half := DanceBeat.beat_seconds() / 2.0
	for r in [1, 2, 3]:
		for s in 8: # several random charts per round
			rng.seed = s * 10 + r
			var start := 12.3 # any time: the chart starts at Bob's turn
			var chart: Array = Battle.make_chart(r, start, rng)
			var n_ok: bool = chart.size() == Battle.NOTES[r - 1]
			var grid_ok := true
			var inside := true
			var repeat_ok := true
			for i in chart.size():
				var t: float = chart[i]["t"]
				var steps := (t - start) / half
				grid_ok = grid_ok and absf(steps - round(steps)) < 0.001
				inside = inside and t >= start - 0.001 and t < start + Battle.BOB_BEATS * DanceBeat.beat_seconds() - 0.001
				if i > 0:
					var gap: float = t - chart[i - 1]["t"]
					inside = inside and gap > half * 0.5
					if gap < half * 1.5 and chart[i]["lane"] == chart[i - 1]["lane"]:
						repeat_ok = false # the same arrow twice on neighbouring half-beats is a finger twister
			if not (n_ok and grid_ok and inside and repeat_ok):
				T.check(false, "round %d chart seed %d: %d notes, grid %s, inside %s, no quick repeats %s" % [r, s, chart.size(), grid_ok, inside, repeat_ok])
				return
	T.check(true, "24 charts: 12/14/16 notes, all on the half-beat grid inside Bob's 8 beats, sorted, no same arrow on neighbouring half-beats")


## The real flow up to the moment the battle exists: finesse talk, her challenge, the rush, the ring. Returns the level.
func _to_battle(stall: int) -> Node:
	Dance.force_stall = stall
	var lvl := T.level(self, true)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var d: Node = lvl.dance
	lvl.population.queue[4].interact(p)
	await T.wait(self, 0.2)
	for k in [KEY_2, KEY_E, KEY_E]:
		await T.key(self, k)
		await T.wait(self, 0.1)
	var at: Vector3 = d.queen.global_position + d.out * 0.9
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-d.out)
	await T.wait(self, 0.2)
	d.queen.interact(p)
	await T.wait(self, 0.2)
	await T.key(self, KEY_1)
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return d.battle != null, 10.0)
	T.check(d.battle != null, "stall %d: the battle starts after the ring forms" % (stall + 1))
	return lvl


## Timing windows through the judge (no keys): PERFECT within 0.07 s either side, GREAT within 0.12 s, GOOD within 0.20 s (Stage 7 E1,
## DECIDED 0.15 -> 0.20); outside = EARLY (pressed before the arrow) or LATE (after it), never nothing.
func _window_checks(lvl: Node) -> void:
	var b: Node = lvl.dance.battle
	b.auto_miss = false # this check calls judge() itself
	T.check(is_equal_approx(b.GOOD, 0.20) and is_equal_approx(b.PERFECT, 0.07), "GOOD window 0.20 s (DECIDED), PERFECT 0.07 s")
	var cases := [[0.0, "PERFECT"], [0.06, "PERFECT"], [-0.06, "PERFECT"], [0.1, "GREAT"], [-0.1, "GREAT"], [0.15, "GOOD"], [-0.18, "GOOD"],
		[0.25, "LATE"], [-0.25, "EARLY"], [1.5, "LATE"], [-1.5, "EARLY"]]
	var ok := 0
	for c: Array in cases:
		var t: float = 50.0
		b.notes.assign([{"t": t, "lane": 1, "hit": ""}])
		var got: String = b.judge(1, t + float(c[0]))
		if got == c[1]:
			ok += 1
		else:
			print("  off %.2f s: got '%s', want '%s'" % [c[0], got, c[1]])
	b.notes.assign([{"t": 50.0, "lane": 1, "hit": ""}])
	var wrong_lane: String = b.judge(2, 50.0)
	T.check(ok == cases.size() and wrong_lane in ["EARLY", "LATE"] and b.notes[0]["hit"] == "", "timing windows: %d of %d cases right; the wrong arrow hits nothing but is still judged ('%s')" % [ok, cases.size(), wrong_lane])
	# the HUD: the combo from 2 hits ("2X COMBO!"), confetti + a crowd cheer at 5x; an EARLY press breaks it
	var hud: Node = lvl.dance.hud
	var notes: Array = []
	for k in 6:
		notes.append({"t": 60.0 + k, "lane": 0, "hit": ""})
	b.notes.assign(notes)
	b.combo = 0
	var bursts: int = hud.confetti_bursts
	var cheers: int = lvl.dance.combo_cheers
	b.judge(0, 60.0)
	T.check(hud.combo_shown == "", "1 hit: no combo yet ('%s')" % hud.combo_shown)
	b.judge(0, 61.0)
	T.check(hud.combo_shown == "2X COMBO!", "2 hits: '2X COMBO!' ('%s')" % hud.combo_shown)
	for k in range(2, 5):
		b.judge(0, 60.0 + k)
	T.check(hud.combo_shown == "5X COMBO!" and hud.confetti_bursts == bursts + 1 and lvl.dance.combo_cheers == cheers + 1, "5x: confetti (%d) and the crowd cheers (%d)" % [hud.confetti_bursts - bursts, lvl.dance.combo_cheers - cheers])
	b.judge(0, 64.5)
	T.check(b.combo == 0 and hud.combo_shown == "", "an EARLY press breaks the combo")


## Presses the right arrow key on the physics tick nearest each note of Bob's turn, until the battle ends or `max_seconds` pass.
## `skill` (0..1): the share of notes it plays; the others it lets pass (a MISS).
func _bot(lvl: Node, skill: float, max_seconds: float, stop_after_round := 0) -> void:
	var d: Node = lvl.dance
	var played := {}
	var waited := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	while waited < max_seconds and d.battle != null and not d.battle.over:
		if stop_after_round > 0 and d.battle.round_number > stop_after_round:
			return
		var b: Node = d.battle
		var now: float = b.now()
		for note: Dictionary in b.notes:
			var id := "%d:%.3f" % [b.round_number, note["t"]]
			if played.has(id) or note["hit"] != "":
				continue
			if absf(now - float(note["t"])) <= 1.0 / 120.0 + 0.0001:
				played[id] = true
				if rng.randf() < skill:
					await T.key(self, KEYS[note["lane"]])
		await physics_frame
		waited += 1.0 / 60.0


func _perfect_bot(lvl: Node) -> void:
	var d: Node = lvl.dance
	var m: Node = lvl.get_node("MissionManager")
	var start: float = lvl._time_left
	await _bot(lvl, 1.0, 60.0)
	var b: Node = d.battle
	T.check(b != null and b.over and b.bob_won and b.rounds_bob == 2 and b.rounds_queen == 0,
			"perfect bot wins 2-0 (%s)" % ("%d-%d" % [b.rounds_bob, b.rounds_queen] if b else "no battle"))
	T.check(b != null and b.round_log.size() == 2 and b.round_log.all(func(r: Dictionary) -> bool: return is_equal_approx(float(r["bob"]), 1.0)),
			"perfect bot scores 100%% in every round (%s)" % [b.round_log if b else []])
	T.check(b != null and b.perfects == 12 + 14, "every note of rounds 1-2 judged PERFECT (%d of 26)" % (b.perfects if b else 0))
	var took: float = start - lvl._time_left
	print("INFO  a 2-0 battle took %.1f s of the level clock" % took)
	await T.wait_for(self, func() -> bool: return m.mission("battle").state == MissionBase.State.DONE, 6.0)
	T.check(m.mission("battle").state == MissionBase.State.DONE, "winning completes 'Win the dance battle'")
	var p: CharacterBody3D = lvl.player
	await T.wait_for(self, func() -> bool: return not p.busy and not p.posing, 6.0)
	T.check(not p.busy and not p.posing and get_root().get_camera_3d() != d.camera, "after the win Bob is free and has his own camera")
	var env: Environment = lvl.get_node("WorldEnvironment").environment
	T.check(absf(env.tonemap_exposure - d.room_exposure()) < 0.01, "after the win the room lights are back (exposure %.2f)" % env.tonemap_exposure)
	var door: Node3D = lvl.stalls.doors[d.stall]
	var label: Label = lvl.get_node("HUD/MissionLabel")
	var want := "Stall %d" % (d.stall % 10 + 1)
	# the occupant needs about 1.4 s to stand up, and the stall is announced once they are out of the doorway
	await T.wait_for(self, func() -> bool: return door.is_open and label.text.contains(want), 8.0)
	if not label.text.contains(want):
		print("  after the win: all_done %s, running %s, door open %s, mission text '%s', occupant state %d" % [lvl._all_done,
				lvl._running, door.is_open, label.text, lvl.population.occupants[d.stall].state])
	T.check(door.is_open and not lvl.population.occupants[d.stall].is_sitting(), "her stall opens and its Jijio comes out")
	T.check(label.visible and label.text.contains(want), "the checklist is back and names the free stall (%s)" % label.text)


func _silent_bot(lvl: Node) -> void:
	var d: Node = lvl.dance
	lvl._time_left = 500.0
	var before: float = lvl._time_left
	var first: Node = d.battle
	await T.wait_for(self, func() -> bool: return d.rematches >= 1, 60.0)
	T.check(d.rematches == 1, "pressing nothing loses the battle: instant rematch")
	T.check(d.battle != null and d.battle != first and d.battle.round_number == 1 and not d.battle.over, "the rematch starts again at round 1")
	T.check(lvl._time_left < before - 20.0 and lvl._running, "the timer kept running through the lost battle (%.1f s used)" % (before - lvl._time_left))
	T.check(first.misses == 12 + 14 and first.rounds_queen == 2, "all 26 notes of two rounds were MISSES, SHUFFLE QUEEN won 2-0 (misses %d)" % first.misses)
	T.check(lvl.player.posing and get_root().get_camera_3d() == d.camera, "Bob stays in the ring for the rematch")
	T.check(lvl.shat_stain.is_shat() and is_equal_approx(lvl.shat_stain.spread(), 1.0) and lvl.shat_stain.cuts >= 1, "Stage 6d: the lost battle = the brown patch (spread %.2f), the look from behind (%d cuts), then the ring camera again" % [lvl.shat_stain.spread(), lvl.shat_stain.cuts])


## Plays about 75 % of the notes: beats her 70 % in round 1, loses to her 80 % in round 2 (the round result compares the accuracies).
func _partial_bot(lvl: Node) -> void:
	var d: Node = lvl.dance
	await _bot(lvl, 0.75, 40.0, 2)
	var b: Node = d.battle
	var log: Array = b.round_log
	T.check(log.size() >= 2, "two rounds were played (%d)" % log.size())
	if log.size() >= 2:
		var r1: Dictionary = log[0]
		var r2: Dictionary = log[1]
		var r1_ok: bool = (float(r1["bob"]) >= 0.7) == (r1["winner"] == "BOB")
		var r2_ok: bool = (float(r2["bob"]) >= 0.8) == (r2["winner"] == "BOB")
		T.check(r1_ok and r2_ok and is_equal_approx(float(r1["queen"]), 0.7) and is_equal_approx(float(r2["queen"]), 0.8),
				"round winners follow the accuracies: R1 Bob %.0f%% vs 70%% -> %s, R2 Bob %.0f%% vs 80%% -> %s"
				% [float(r1["bob"]) * 100.0, r1["winner"], float(r2["bob"]) * 100.0, r2["winner"]])


func _timeout_mid_round(lvl: Node) -> void:
	var d: Node = lvl.dance
	await T.wait_for(self, func() -> bool: return d.battle.phase == "bob", 20.0)
	lvl._time_left = 0.5
	await T.wait(self, 1.5)
	var p: CharacterBody3D = lvl.player
	T.check(not lvl._running and d.battle == null, "timeout in Bob's turn: the battle stops")
	T.check(not p.posing and get_root().get_camera_3d() != d.camera and d.hud == null, "timeout: Bob's own camera, no dance HUD")
	var env: Environment = lvl.get_node("WorldEnvironment").environment
	T.check(absf(env.tonemap_exposure - d.room_exposure()) < 0.01, "timeout: the lights are back for the kick-out")
	var chasing := 0
	for npc: Node3D in d.crowd:
		if npc.state == npc.State.CHASE or npc.state == npc.State.KICK:
			chasing += 1
	T.check(chasing >= d.crowd.size() - 1, "timeout: the crowd goes for Bob (%d of %d)" % [chasing, d.crowd.size()])
