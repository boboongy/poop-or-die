extends SceneTree
## Stage 6c C (owner playtest 2026-09-28, DECIDED): Bob cannot move while ANY talk box is open. This test walks every kind of talk
## box in the game and, while the box is on screen, HOLDS the movement keys for 0.8 s:
##   the start dialogue of all 5 levels (Levels 1/4/5 cut-in, the flood queue, the ghost), the Level 1 mission talk, a walker's small
##   talk, the hide-and-seek occupant, the dance queen's challenge, a queue cutter's argument.
## Checks per box: Bob's feet do not move (< MOVED), `frozen or busy` holds on EVERY physics frame, and the movement keys do not
## close the box (except a walker's small talk, which W/A/S/D leave on purpose: owner 2026-09-21, tests/test_talk_leave.gd).
## Short head bubbles (dialogue.bubble) are NOT a talk box and must never freeze Bob: checked at the end.
## Space and E are never pressed here: they advance the box (dialogue._input), they are not movement.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Intro := preload("res://scripts/intro.gd")

const HOLD_PAIRS := [[KEY_W, KEY_A], [KEY_S, KEY_D]] ## two passes: all four keys at once cancel out to no movement at all
const HOLD_FRAMES := 24 ## per pass, at 60 fps = 0.4 s
const MOVED := 0.05 ## m: more than this on the floor plane is Bob walking during a talk box

var boxes := 0 ## how often the test really met an open talk box (skill rule 5: say the sample size)


func _init() -> void:
	seed(17)
	for n in [1, 4, 5, T.HIDE_LEVEL, T.FLOOD_LEVEL]:
		await _start_dialogue(n)
	await _mission_talk()
	await _walker_talk()
	await _occupant_talk()
	await _queen_talk()
	await _cutter_talk()
	await _mouse_look_during_talk()
	await _bubble_is_free()
	print("INFO  %d talk boxes met and held against the movement keys" % boxes)
	T.check(boxes >= 9, "every kind of talk box was met (%d)" % boxes)
	T.finish(self)


## Hold the movement keys while the box is open. `keys` false = only watch (a skippable small talk closes on W).
func _hold(p: CharacterBody3D, d: Node, tag: String, keys := true) -> void:
	boxes += 1
	var before: Vector3 = p.global_position
	var free_frames := 0
	var frames := 0
	var closed := false
	for pair: Array in HOLD_PAIRS:
		if keys:
			await T.key_down(self, pair[0])
			await T.key_down(self, pair[1])
		for i in HOLD_FRAMES:
			await physics_frame
			frames += 1
			if not (p.frozen or p.busy):
				free_frames += 1
			if not d.is_open():
				closed = true
		if keys:
			await T.key_up(self, pair[0])
			await T.key_up(self, pair[1])
	var moved := Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length()
	T.check(moved < MOVED, "%s: Bob does not move while the talk box is open (%.3f m in %d frames)" % [tag, moved, frames])
	T.check(free_frames == 0, "%s: frozen or busy on every frame (%d of %d frames free)" % [tag, free_frames, frames])
	if keys:
		T.check(not closed, "%s: the movement keys do not close the box" % tag)


func _open(d: Node) -> void:
	await T.wait_for(self, func() -> bool: return d.is_open(), 15.0)


func _drop(lvl: Node) -> void:
	lvl.queue_free()
	await T.wait(self, 0.3)


# --- the five start dialogues -------------------------------------------------------------------------------------------

func _start_dialogue(n: int) -> void:
	T.intro = true
	Progress.level = n
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	T.intro = false
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	await _open(d)
	var tag := "L%d start dialogue" % n
	T.check(d.is_open(), "%s: the box is open" % tag)
	if d.is_open():
		await _hold(p, d, tag)
	await _drop(lvl)


# --- Level 1: the queue Jijio's mission talk ----------------------------------------------------------------------------

func _mission_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	await T.key(self, KEY_E) # Bob starts in the queue, facing the Jijio ahead
	await _open(d)
	T.check(d.is_open(), "L1 mission talk: the box is open")
	if d.is_open():
		await _hold(p, d, "L1 mission talk")
	await _drop(lvl)


# --- a walker's small talk (skippable: W/A/S/D leave it, so this one is only watched) ------------------------------------

func _walker_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self, true)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var walkers: Node = lvl.get_node("Walkers")
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	await walkers.clear()
	# the same standing walker as tests/test_talk_leave.gd: corridor A, 0.7 m from Bob, clear of every stall door
	var w: Node3D = lvl.population.spawn_walker(Vector3(6.0, 0.0, 0.3), 0.0)
	w.set_interaction("E  talk", walkers._talk.bind(w))
	p.global_position = Vector3(6.0, 0.05, -0.4)
	p.set_facing(PI)
	await T.wait(self, 0.4)
	await T.key(self, KEY_E)
	await _open(d)
	T.check(d.is_open(), "walker small talk: the box is open")
	if d.is_open():
		await _hold(p, d, "walker small talk", false)
	await _drop(lvl)


# --- hide-and-seek: the stall occupant Bob asks to shush ----------------------------------------------------------------

func _occupant_talk() -> void:
	Progress.level = T.HIDE_LEVEL
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	lvl.hide_seek._talk(0)
	await _open(d)
	T.check(d.is_open(), "hide-and-seek occupant: the box is open")
	if d.is_open():
		await _hold(p, d, "hide-and-seek occupant")
	await _drop(lvl)


# --- Level 5: the dance queen's challenge -------------------------------------------------------------------------------

func _queen_talk() -> void:
	Progress.level = 5
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	lvl.dance._on_talk(p)
	await _open(d)
	T.check(d.is_open(), "dance queen: the box is open")
	if d.is_open():
		await _hold(p, d, "dance queen")
	await _drop(lvl)


# --- Level 4: arguing with a queue cutter -------------------------------------------------------------------------------

func _cutter_talk() -> void:
	Progress.level = 4
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	var cm: Node = lvl.cutters
	await T.wait_for(self, func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(
			func(c: Dictionary) -> bool: return c["state"] == "waiting"), 60.0)
	var ready_now: bool = cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting")
	T.check(ready_now, "Level 4: the three cutters stand at the door (%d)" % cm.cutters.size())
	if ready_now:
		cm._on_talk(p, 0)
		await _open(d)
		T.check(d.is_open(), "cutter argument: the box is open")
		if d.is_open():
			await _hold(p, d, "cutter argument")
	await _drop(lvl)


# --- the mouse may not swing the view off the Jijio's face (Stage 6c C, owner "yes to all" 2026-09-28) -------------------
# `p.look_by()` is called directly, not through a mouse event: a headless run has no captured mouse (mouse_mode stays VISIBLE,
# so InputEventMouseMotion never reaches _unhandled_input). This tests the clamp, not the mouse_mode gate.

const LOOK_LIMIT := deg_to_rad(15.0) ## the DECIDED free look. Written out here on purpose: a test that reads the number from the
## code it checks cannot fail when that number is wrong (the first sabotage of this file passed because it used p.TALK_LOOK_LIMIT).
const LOOK_SLACK := deg_to_rad(1.0) ## rounding room on top of the 15 degrees

func _mouse_look_during_talk() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	var limit := LOOK_LIMIT
	T.check(absf(float(p.TALK_LOOK_LIMIT) - LOOK_LIMIT) < 0.001, "the free look in a talk box is %.0f degrees (owner: 15)"
			% rad_to_deg(float(p.TALK_LOOK_LIMIT)))

	# free before the talk: the same mouse sweep turns Bob's view right round
	var yaw_free: float = p._yaw
	for i in 20:
		p.look_by(Vector2(300.0, 0.0))
	await T.wait(self, 0.1)
	var turned := absf(wrapf(p._yaw - yaw_free, -PI, PI))
	T.check(turned > deg_to_rad(45.0), "no talk box: the mouse turns the view freely (%.0f degrees)" % rad_to_deg(turned))

	await T.key(self, KEY_E)
	await _open(d)
	T.check(d.is_open(), "mouse look: the talk box is open")
	if d.is_open():
		await T.wait(self, 1.2) # the 0.5 s talk pan has finished: the camera sits on the Jijio's face
		var aim: Vector2 = p._talk_look
		T.check(aim != Vector2.INF, "the talk box sets the aim the free look is measured from")
		var worst := 0.0
		var worst_pitch := 0.0
		for sweep: Vector2 in [Vector2(300.0, 0.0), Vector2(-300.0, 0.0), Vector2(0.0, 300.0), Vector2(0.0, -300.0)]:
			for i in 20:
				p.look_by(sweep)
				worst = maxf(worst, absf(wrapf(p._yaw - aim.x, -PI, PI)))
				worst_pitch = maxf(worst_pitch, absf(p._pitch - aim.y))
			await physics_frame
		T.check(worst <= limit + LOOK_SLACK, "a full mouse sweep in a talk box stays %.0f degrees from the Jijio (limit %.0f)"
				% [rad_to_deg(worst), rad_to_deg(limit)])
		T.check(worst_pitch <= limit + LOOK_SLACK, "and %.0f degrees up or down (limit %.0f)"
				% [rad_to_deg(worst_pitch), rad_to_deg(limit)])
		T.check(worst > deg_to_rad(5.0), "but the view is not dead: it still moves (%.0f degrees)" % rad_to_deg(worst))

		# and free again the moment the box is gone
		d.force_close()
		d.hide_box()
		await T.wait(self, 0.3)
		var yaw_after: float = p._yaw
		for i in 20:
			p.look_by(Vector2(300.0, 0.0))
		await T.wait(self, 0.1)
		var after := absf(wrapf(p._yaw - yaw_after, -PI, PI))
		T.check(after > deg_to_rad(45.0), "after the box closes the mouse is free again (%.0f degrees)" % rad_to_deg(after))
	await _drop(lvl)


# --- a head bubble is NOT a talk box: Bob keeps walking -----------------------------------------------------------------

func _bubble_is_free() -> void:
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	lvl._time_left = 100000.0
	var d: Node = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(6.0, 0.05, 0.0)
	await T.wait(self, 0.3)
	# an existing voiced line (a new line of test-only text would print VOICE MISSING and fail the file in run.sh)
	d.bubble(lvl.population.queue[4], Intro.CUT_IN_BOB[0], 3.0, Dialogue.BUBBLE_HEIGHT, "Bob")
	await T.wait(self, 0.2)
	T.check(not d.is_open() and not p.frozen and not p.busy, "a head bubble is not a talk box: Bob is free")
	var before: Vector3 = p.global_position
	await T.key_down(self, KEY_W)
	await T.wait(self, 0.6)
	await T.key_up(self, KEY_W)
	var moved := Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length()
	T.check(moved > 0.3, "and he walks under the bubble (%.2f m)" % moved)
	await _drop(lvl)
