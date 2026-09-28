extends SceneTree
## Level 5 with the REAL dance clips (factory republish 2026-09-25; owner "O = rounds, P default, Q default"). On the real level, reached
## through the real flow, played by a perfect bot through real key presses:
##  - the "dance" library of Bob, SHUFFLE QUEEN and the crowd is built from the real clips (groove loops; move0..3 = move_left / down / up
##    / right; flare, headspin, worm, victory, defeat), not the old stand-ins cut from walk / punch / kick clips
##  - every hit plays that arrow's clip on Bob (checked on EVERY judged hit), every one of her good arrows plays hers
##  - between moves, `groove` is locked to the heard beat (its knee dips, frames 0 and 18, land on the beats), sampled every frame
##  - round 1: arrow steps only; round 2: she does the FLARE in the call, Bob in the result; round 3 (forced 1-1): the HEADSPIN, and its
##    call and result last 4 beats instead of 2
##  - the finale: the battle's winner does the WORM then `victory`, the loser `defeat`; for a win (Bob) and a loss (her, silent bot)
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Battle := preload("res://scripts/dance_battle.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")

const KEYS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const REAL := {"move0": "move_left", "move1": "move_down", "move2": "move_up", "move3": "move_right", "groove": "groove",
		"flare": "flare", "headspin": "headspin", "worm": "worm", "victory": "victory", "defeat": "defeat"}


func _init() -> void:
	seed(4)
	Progress.level = 5
	var lvl := await _to_battle(6)
	_library_checks(lvl)
	await _play_and_watch(lvl)
	lvl.queue_free()
	await process_frame
	lvl = await _to_battle(13)
	await _loss_finale(lvl)
	lvl.queue_free()
	await process_frame
	Dance.force_stall = -1
	T.finish(self)


## Same real flow as test_dance_battle: finesse talk, her challenge, the rush, the ring.
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
	T.check(d.battle != null, "stall %d: the battle starts" % (stall + 1))
	return lvl


func _same_clip(ap: AnimationPlayer, dance_name: String, real_name: String) -> bool:
	if not ap.has_animation("dance/" + dance_name) or not ap.has_animation(real_name):
		return false
	var a := ap.get_animation("dance/" + dance_name)
	var r := ap.get_animation(real_name)
	if absf(a.length - r.length) > 0.001 or a.get_track_count() != r.get_track_count():
		return false
	for i in r.get_track_count():
		if a.track_get_key_count(i) != r.track_get_key_count(i) or a.track_get_path(i) != r.track_get_path(i):
			return false
	return true


func _library_checks(lvl: Node) -> void:
	var d: Node = lvl.dance
	var bodies := {"Bob": lvl.player.anim(), "SHUFFLE QUEEN": d.queen.anim()}
	for who: String in bodies:
		var ap: AnimationPlayer = bodies[who]
		var bad: Array[String] = []
		for k: String in REAL:
			if not _same_clip(ap, k, REAL[k]):
				bad.append(k)
		T.check(bad.is_empty(), "%s: the dance library is the real clips (%d of %d; wrong: %s)" % [who, REAL.size() - bad.size(), REAL.size(), str(bad)])
		T.check(ap.get_animation("dance/groove").loop_mode == Animation.LOOP_LINEAR, "%s: groove loops" % who)
	var crowd_real := 0
	var crowd_groove := 0
	for npc: Node3D in d.crowd:
		var ap: AnimationPlayer = npc.anim()
		if ap.current_animation == "dance/groove":
			crowd_groove += 1
			if _same_clip(ap, "groove", "groove"):
				crowd_real += 1
	T.check(crowd_groove > 0 and crowd_real == crowd_groove, "the grooving crowd uses the real groove (%d of %d)" % [crowd_real, crowd_groove])


## The whole battle with a perfect bot; round 3 is forced by setting the score to 1-1 in round 2's result.
func _play_and_watch(lvl: Node) -> void:
	var d: Node = lvl.dance
	var bob_ap: AnimationPlayer = lvl.player.anim()
	var q_ap: AnimationPlayer = d.queen.anim()
	var hits := 0
	var hit_ok := 0
	var pending: Array = [] ## lanes judged this frame, checked next frame
	d.battle.judged.connect(func(lane: int, result: String) -> void:
		if result != "MISS":
			pending.append(lane))
	var q_moves := 0
	var q_ok := 0
	var groove_frames := 0
	var groove_worst := 0.0
	var seen := {} ## "round/phase/who" -> clip seen playing
	var call_len := {}
	var result_len := {}
	var phase_start := {}
	var forced := false
	var played := {}
	var t := 0.0
	var two_beats := 2.0 * DanceBeat.beat_seconds()
	while t < 90.0 and d.battle != null and not d.battle.over:
		var b: Node = d.battle
		var now: float = b.now()
		for note: Dictionary in b.notes:
			var id := "%d:%.3f" % [b.round_number, note["t"]]
			if not played.has(id) and note["hit"] == "" and absf(now - float(note["t"])) <= 1.0 / 120.0 + 0.0001:
				played[id] = true
				await T.key(self, KEYS[note["lane"]])
		await physics_frame
		t += 1.0 / 60.0
		if d.battle == null:
			break
		b = d.battle
		for lane: int in pending:
			hits += 1
			if bob_ap.current_animation == "dance/move%d" % lane:
				hit_ok += 1
			else:
				print("INFO  hit lane %d in round %d phase %s: Bob plays '%s'" % [lane, b.round_number, b.phase, bob_ap.current_animation])
		pending.clear()
		for q: Dictionary in b.queen_notes:
			if q["done"] and q["ok"] and not q.has("seen"):
				q["seen"] = true
				q_moves += 1
				if q_ap.current_animation == "dance/move%d" % q["lane"]:
					q_ok += 1
		var key := "%d/%s" % [b.round_number, b.phase]
		if not phase_start.has(key):
			phase_start[key] = b.now()
		if b.phase == "call":
			call_len[b.round_number] = b.now() - float(phase_start[key])
		elif b.phase == "result":
			result_len[b.round_number] = b.now() - float(phase_start[key])
		for pair: Array in [["bob", bob_ap], ["queen", q_ap]]:
			var ap: AnimationPlayer = pair[1]
			var clip := String(ap.current_animation)
			if clip in ["dance/flare", "dance/headspin"]:
				seen["%s/%s" % [key, pair[0]]] = clip
			if clip == "dance/groove" and ap.is_playing() and b.phase in ["queen", "bob"]:
				var want := fposmod(d.song_time(), two_beats)
				var off := absf(ap.current_animation_position - want)
				off = minf(off, two_beats - off)
				groove_frames += 1
				if off > 0.06 and off > groove_worst:
					print("INFO  %s groove %.3f s off (at %.3f, want %.3f) in round %d phase %s" % [pair[0], off, ap.current_animation_position, want, b.round_number, b.phase])
				groove_worst = maxf(groove_worst, off)
		if b.round_number == 2 and b.phase == "result" and not forced and b.rounds_bob == 2:
			forced = true
			b.rounds_bob = 1
			b.rounds_queen = 1
	T.check(hits >= 30 and hit_ok == hits, "every hit plays that arrow's real clip on Bob (%d of %d hits)" % [hit_ok, hits])
	T.check(q_moves >= 15 and q_ok == q_moves, "every good arrow of hers plays its real clip (%d of %d)" % [q_ok, q_moves])
	T.check(groove_frames > 300 and groove_worst < 0.06, "groove stays on the beat: worst %.3f s off over %d frames" % [groove_worst, groove_frames])
	T.check(not seen.has("1/call/queen") and not seen.has("1/result/bob"), "round 1: arrow steps only, no power move (%s)" % str(seen))
	T.check(seen.get("2/call/queen", "") == "dance/flare" and seen.get("2/result/bob", "") == "dance/flare",
			"round 2: she flares in the call, Bob in the result (%s / %s)" % [seen.get("2/call/queen", "-"), seen.get("2/result/bob", "-")])
	T.check(seen.get("3/call/queen", "") == "dance/headspin" and seen.get("3/result/bob", "") == "dance/headspin",
			"round 3: the headspin for both (%s / %s)" % [seen.get("3/call/queen", "-"), seen.get("3/result/bob", "-")])
	var beat := DanceBeat.beat_seconds()
	T.check(absf(float(call_len.get(2, 0.0)) - 2.0 * beat) < 0.1 and absf(float(call_len.get(3, 0.0)) - 4.0 * beat) < 0.1
			and absf(float(result_len.get(3, 0.0)) - 4.0 * beat) < 0.1,
			"the call/result last 2 beats in round 2 and 4 in round 3 (call %.2f / %.2f s, result R3 %.2f s)" % [call_len.get(2, 0.0), call_len.get(3, 0.0), result_len.get(3, 0.0)])
	var b2: Node = d.battle
	T.check(b2 != null and b2.over and b2.bob_won and b2.round_number == 3, "the perfect bot wins in round 3 (forced 1-1)")
	# the finale: Bob worms, then victory; she is defeated
	var worm := false
	var victory := false
	var defeat := false
	for i in 4 * 60:
		await physics_frame
		if bob_ap.current_animation == "dance/worm":
			worm = true
		if worm and bob_ap.current_animation == "dance/victory":
			victory = true
		if q_ap.current_animation == "dance/defeat":
			defeat = true
		if victory and defeat:
			break
	T.check(worm and victory, "Bob won: he does the worm, then victory (worm %s, victory %s)" % [worm, victory])
	T.check(defeat, "she plays defeat")


## The silent bot loses: she does the worm (no victory: the rematch cuts it), Bob defeat; the rematch starts with both grooving again.
func _loss_finale(lvl: Node) -> void:
	var d: Node = lvl.dance
	var bob_ap: AnimationPlayer = lvl.player.anim()
	var q_ap: AnimationPlayer = d.queen.anim()
	lvl._time_left = 500.0
	await T.wait_for(self, func() -> bool: return d.battle != null and d.battle.over, 60.0)
	var worm := false
	var victory := false
	var defeat := false
	for i in 4 * 60:
		await physics_frame
		if q_ap.current_animation == "dance/worm":
			worm = true
		if worm and q_ap.current_animation == "dance/victory":
			victory = true
		if bob_ap.current_animation == "dance/defeat":
			defeat = true
		if d.rematches >= 1:
			break
	# her victory is cut by the rematch on purpose (dance.gd _finale: it would cost 1.5 s of the clock per loss)
	T.check(worm and defeat and not victory, "she won: she does the worm, Bob defeat, then straight to the rematch (worm %s, defeat %s, victory %s)" % [worm, defeat, victory])
	await T.wait_for(self, func() -> bool: return d.rematches >= 1 and d.battle != null and d.battle.phase == "queen", 10.0)
	await T.wait(self, 0.5)
	T.check(bob_ap.current_animation == "dance/groove" and String(q_ap.current_animation).begins_with("dance/") and q_ap.current_animation != "dance/victory",
			"the rematch: both dance again (Bob %s, her %s)" % [bob_ap.current_animation, q_ap.current_animation])
