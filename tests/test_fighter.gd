extends SceneTree
## Level 4 fight core (scripts/fighter.gd): pure logic, no scene. Moves hit at their clip's contact time, reach, block chip,
## hit-stun interrupts an attack, jump dodges punches but not kicks/uppercuts, KO, fighters never overlap, every move.
const T := preload("res://tests/t.gd")
const Fighter := preload("res://scripts/fighter.gd")

const DT := 1.0 / 60.0


## Two fighters `gap` apart, a on the left facing right.
func _pair(gap: float) -> Array:
	var a: Fighter = Fighter.new("A", 100.0)
	var b: Fighter = Fighter.new("B", 100.0)
	a.pos = 0.0
	b.pos = gap
	a.face(b)
	b.face(a)
	return [a, b]


## Steps both for `seconds`, returns every hit event fired by either.
func _run(a: Fighter, b: Fighter, seconds: float) -> Array:
	var hits: Array = []
	var t := 0.0
	while t < seconds:
		hits.append_array(a.step(DT, b))
		hits.append_array(b.step(DT, a))
		t += DT
	return hits


func _init() -> void:
	# 1. every move: starts, lands its hits inside reach, none outside reach, total damage as tabled
	for move: String in Fighter.MOVES.keys():
		var m: Dictionary = Fighter.MOVES[move]
		var p := _pair(float(m["reach"]) - 0.05)
		var a: Fighter = p[0]
		var b: Fighter = p[1]
		a.meter = Fighter.METER_MAX # the super needs a full meter
		T.check(a.start_move(move), "%s: starts from idle" % move)
		var hits := _run(a, b, Fighter.length_of(move) + 0.2)
		var total := 0.0
		for h: Dictionary in hits:
			total += float(h["damage"])
		var expected: int = Fighter.hits_of(move).size()
		T.check(hits.size() == expected, "%s: %d hits fired (got %d)" % [move, expected, hits.size()])
		T.check(is_equal_approx(total, 100.0 - b.hp), "%s: damage taken equals damage reported (%.1f)" % [move, total])
		T.check(a.can_act(), "%s: attacker free again after the clip" % move)
		var q := _pair(float(m["reach"]) + 0.3)
		var a2: Fighter = q[0]
		var b2: Fighter = q[1]
		a2.meter = Fighter.METER_MAX
		a2.start_move(move)
		var miss := _run(a2, b2, Fighter.length_of(move) + 0.2)
		T.check(miss.is_empty() and b2.hp == 100.0, "%s: out of reach hits nothing" % move)

	# 2. the first hit lands at the clip's contact time, not at once
	var p2 := _pair(0.6)
	var a3: Fighter = p2[0]
	var b3: Fighter = p2[1]
	a3.start_move("punch")
	var early := _run(a3, b3, 0.05)
	T.check(early.is_empty(), "punch: no hit in the first 0.05 s (the wind-up)")

	# 3. block: 20% damage, and only while blocking
	var p3 := _pair(0.6)
	var a4: Fighter = p3[0]
	var b4: Fighter = p3[1]
	b4.set_block(true)
	a4.start_move("punch")
	var blocked := _run(a4, b4, 1.0)
	T.check(blocked.size() == 1 and blocked[0]["blocked"] == true, "blocked punch is reported blocked")
	T.check(is_equal_approx(b4.hp, 100.0 - 8.0 * Fighter.BLOCK_FACTOR), "blocked punch does 20%% damage (hp %.2f)" % b4.hp)

	# 4. a hit interrupts the victim's attack (hit-stun), then they can act again
	var p4 := _pair(0.6)
	var a5: Fighter = p4[0]
	var b5: Fighter = p4[1]
	a5.start_move("kick") # first contact 16 frames in: slower than the punch below
	b5.start_move("punch")
	_run(a5, b5, 0.36) # punch lands at 0.31 s, the kick would land at 0.38 s
	T.check(a5.hp < 100.0, "the faster punch landed on the kicker (hp %.1f)" % a5.hp)
	T.check(b5.hp == 100.0, "the interrupted kick never landed")
	_run(a5, b5, 1.0)
	T.check(a5.can_act(), "hit-stun ends and the fighter can act again")

	# 5. jump: dodges a punch, does not dodge a kick or an uppercut
	for move: String in ["punch", "kick", "uppercut"]:
		var p5 := _pair(0.6)
		var a6: Fighter = p5[0]
		var b6: Fighter = p5[1]
		b6.jump()
		a6.start_move(move)
		_run(a6, b6, 0.5) # every contact is before 0.4 s; the jump lasts 0.7 s
		var dodged := b6.hp == 100.0
		var expect_dodge := move == "punch"
		T.check(dodged == expect_dodge, "jump vs %s: %s" % [move, "dodged" if expect_dodge else "still hit"])

	# 6. KO: hp 0 ends the fight, a KO'd fighter does not act, and the attacker stops hitting
	var p6 := _pair(0.6)
	var a7: Fighter = p6[0]
	var b7: Fighter = p6[1]
	b7.hp = 5.0
	a7.start_move("kick")
	_run(a7, b7, 1.0)
	T.check(b7.is_ko() and b7.hp == 0.0, "hp clamps at 0 and the fighter is KO'd")
	T.check(not b7.start_move("punch"), "a KO'd fighter cannot start a move")
	T.check(not a7.is_ko(), "the winner is not KO'd")

	# 7. walking: speed, and fighters never overlap
	var p7 := _pair(1.0)
	var a8: Fighter = p7[0]
	var b8: Fighter = p7[1]
	for i in 120:
		a8.walk(1.0, DT, b8)
	T.check(absf(b8.pos - a8.pos) >= Fighter.MIN_GAP - 0.001, "walking into the opponent stops at the minimum gap (%.2f)" % absf(b8.pos - a8.pos))
	var start: float = a8.pos
	a8.walk(-1.0, 1.0, b8)
	T.check(is_equal_approx(start - a8.pos, Fighter.WALK_SPEED), "walking away covers WALK_SPEED in one second")

	# 8. mirrored: the same attack from the right side hits the same way
	var p8 := _pair(0.6)
	var a9: Fighter = p8[1]
	var b9: Fighter = p8[0]
	a9.start_move("uppercut")
	_run(a9, b9, 1.0)
	T.check(b9.hp < 100.0, "an attack from the right side hits too")

	# 9. super meter (SPEC N-S "P"): the super needs a full meter and empties it; landing and blocking hits fill it
	var p9 := _pair(0.6)
	var a10: Fighter = p9[0]
	var b10: Fighter = p9[1]
	T.check(not a10.start_move("super"), "super refused with an empty meter")
	a10.start_move("punch")
	_run(a10, b10, 1.0)
	T.check(a10.meter > 0.0, "landing a hit fills the attacker's meter (%.0f)" % a10.meter)
	var gained_hit: float = a10.meter
	b10.set_block(true)
	var b_before: float = b10.meter
	a10.start_move("punch")
	_run(a10, b10, 1.0)
	T.check(b10.meter > b_before, "blocking a hit fills the defender's meter too")
	a10.meter = Fighter.METER_MAX
	T.check(a10.start_move("super"), "super starts with a full meter")
	T.check(a10.meter == 0.0, "starting the super empties the meter")
	T.check(gained_hit < Fighter.METER_MAX, "one punch does not fill the whole meter")

	# 10. punch -> combo chain: a second punch press before the punch's contact switches to the combo; after contact it does not
	var p10 := _pair(0.6)
	var a11: Fighter = p10[0]
	var b11: Fighter = p10[1]
	a11.start_move("punch")
	_run(a11, b11, 0.1)
	T.check(a11.chain_punch() and a11.move == "combo", "second punch early in the swing chains into the combo")
	var p11 := _pair(0.6)
	var a12: Fighter = p11[0]
	var b12: Fighter = p11[1]
	a12.start_move("punch")
	_run(a12, b12, 0.4) # past the punch's contact (0.31 s)
	T.check(not a12.chain_punch() and a12.move == "punch", "a late second punch does not chain")

	# 11. combo counter: every jab of the combo lands on a stunned foe, so the count climbs to 6; a single punch is 1
	var p12 := _pair(0.6)
	var a13: Fighter = p12[0]
	var b13: Fighter = p12[1]
	a13.start_move("combo")
	var ch := _run(a13, b13, 2.0)
	var top := 0
	for h: Dictionary in ch:
		top = maxi(top, int(h["combo"]))
	T.check(top == 6, "the combo's six hits count as a 6 hit combo (got %d)" % top)
	var p13 := _pair(0.6)
	var a14: Fighter = p13[0]
	var b14: Fighter = p13[1]
	a14.start_move("punch")
	var one := _run(a14, b14, 1.0)
	T.check(one.size() == 1 and int(one[0]["combo"]) == 1, "a lone punch is a 1 hit combo")

	# 12. FINISH HIM (SPEC "O"): a finishable fighter at 0 hp is dizzy (not KO), cannot act or block, the next hit finishes;
	# left alone, the dizzy runs out into a plain KO. A non-finishable fighter goes straight to KO (section 6).
	var p14 := _pair(0.6)
	var a15: Fighter = p14[0]
	var b15: Fighter = p14[1]
	b15.finishable = true
	b15.hp = 5.0
	a15.start_move("punch")
	_run(a15, b15, 1.0)
	T.check(b15.is_dizzy() and not b15.is_ko(), "finishable fighter at 0 hp is dizzy, not KO")
	b15.set_block(true)
	T.check(not b15.blocking and not b15.start_move("punch"), "a dizzy fighter cannot block or attack")
	a15.start_move("finisher")
	_run(a15, b15, 2.0)
	T.check(b15.is_ko() and b15.finished, "the finisher KOs the dizzy fighter and marks it finished")
	var p15 := _pair(0.6)
	var a16: Fighter = p15[0]
	var b16: Fighter = p15[1]
	b16.finishable = true
	b16.hp = 5.0
	a16.start_move("punch")
	_run(a16, b16, Fighter.DIZZY_SECONDS + 1.0)
	T.check(b16.is_ko() and not b16.finished, "unfinished, the dizzy runs out into a plain KO")

	# block pushback: the defender slides away from the attacker
	var a17: Fighter = Fighter.new("A", 100.0)
	var b17: Fighter = Fighter.new("B", 100.0)
	b17.pos = 0.7
	b17.blocking = true
	a17.start_move("punch")
	_run(a17, b17, 1.0)
	T.check(b17.pos > 0.7 + 0.1, "a blocked punch pushes the defender back (pos 0.70 -> %.2f)" % b17.pos)
	# Stage 7 keys: the sweep hits a crouching foe, a jumping one is not hit; the jump kick lands once per jump
	var a18: Fighter = Fighter.new("A", 100.0)
	var b18: Fighter = Fighter.new("B", 100.0)
	b18.pos = 0.9
	b18.crouching = true
	a18.start_move("sweep")
	_run(a18, b18, 0.3)
	T.check(b18.hp < 100.0, "the sweep hits a crouching foe (hp %.1f)" % b18.hp)
	var a19: Fighter = Fighter.new("A", 100.0)
	var b19: Fighter = Fighter.new("B", 100.0)
	b19.pos = 0.9
	b19.jump()
	a19.start_move("sweep")
	_run(a19, b19, 0.4)
	T.check(b19.hp == 100.0, "a jumping foe is not swept (hp %.1f)" % b19.hp)
	var a20: Fighter = Fighter.new("A", 100.0)
	var b20: Fighter = Fighter.new("B", 100.0)
	b20.pos = 1.0
	a20.jump()
	T.check(a20.jump_kick() and not a20.jump_kick(), "one jump kick per jump")
	_run(a20, b20, 0.5)
	T.check(is_equal_approx(b20.hp, 100.0 - Fighter.JUMP_KICK["damage"]), "the jump kick lands once (hp %.1f)" % b20.hp)
	T.check(not a20.jump_kick(), "no jump kick on the ground")

	T.finish(self)
