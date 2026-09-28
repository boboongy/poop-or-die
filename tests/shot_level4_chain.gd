extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Level 4 in the REAL flow from Bob's own camera, walkers on: the start, the open
## stall, the cutters blocking it, an argument, a fist fight, WATER WAR reached through BOSSY's argument (the cut, both cards, the first
## look, firing, BOSSY out, SOAKED!, back at the stall), the win. Fist fights shortened (cutter at 1 hp); the war by tests/war_bot.gd. Run: "<console exe>" --path . --script tests/shot_level4_chain.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Walkers := preload("res://scripts/walkers.gd")
const WarBot := preload("res://tests/war_bot.gd")

const STALL := 5 ## row 1, stall 6

var out := "C:/tmp"
var p: Node3D


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _until(pred: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not pred.call() and Time.get_ticks_msec() < end:
		await process_frame


func _pause(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)


func _argue(body: Node3D) -> void:
	var at: Vector3 = body.global_position + Vector3(0.0, 0.0, 0.85)
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(Vector3(0.0, 0.0, -1.0))
	await _pause(0.4)
	await _key(KEY_E)
	await _pause(0.3)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	Progress.level = 4
	Cutters.force_stall = STALL
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	await _pause(2.0)
	p = lvl.player
	var cm: Node = lvl.cutters
	var door: Node3D = lvl.stalls.doors[STALL]
	await _snap("c00_start_in_queue")
	# look down corridor A at the open stall from a few metres
	p.global_position = Vector3(door.point.x - 3.2, p.global_position.y, 0.2)
	p.face_direction(Vector3(1.0, 0.0, -0.25).normalized())
	await _pause(0.5)
	await _snap("c01_open_stall")
	await _until(func() -> bool: return cm.cutters.size() == 3 and cm.cutters.all(func(c: Dictionary) -> bool: return c["state"] == "waiting"), 40.0)
	await _pause(0.3)
	await _snap("c02_cutters_block_the_door")
	lvl._time_left = 100000.0 # the rest is about how it looks, not the clock
	# PUSHY: the argument box, then the fist fight
	await _argue(cm.cutter("PUSHY")["body"])
	await _snap("c03_argument")
	await _key(KEY_1)
	await _pause(0.3)
	await _key(KEY_E)
	await _until(func() -> bool: return cm.fight != null and cm.fight.fighting(), 4.0)
	await _pause(0.3)
	await _snap("c04_fist_fight")
	for cname: String in ["PUSHY", "SNEAKY"]:
		if cname == "SNEAKY":
			await _argue(cm.cutter("SNEAKY")["body"])
			await _key(KEY_1)
			await _pause(0.3)
			await _key(KEY_E)
			await _until(func() -> bool: return cm.fight != null and cm.fight.fighting(), 4.0)
		var f: Node = cm.fight
		f.ai_enabled = false
		f.foe.pos = f.bob.pos + 0.7
		f.foe.hp = 1.0
		f._try("punch")
		if cname == "SNEAKY":
			await _until(func() -> bool: return f.foe.is_dizzy(), 3.0)
			await _pause(0.3)
			f._try("kick")
		await _until(func() -> bool: return cm.fight == null, 8.0)
	await _pause(0.4)
	await _snap("c05_back_after_two_fights")
	# BOSSY through the real argument: WATER WAR, played by the perfect-aim bot (tests/war_bot.gd) against the live crew
	await _argue(cm.cutter("BOSSY")["body"])
	await _key(KEY_1)
	await _pause(0.5)
	await _snap("c06_bossy_calls_her_crew")
	await _key(KEY_E)
	await _until(func() -> bool: return cm.fight != null, 2.0)
	var sh: Node = cm.fight
	await _pause(0.3)
	await _snap("c07_round3_card_fading_in")
	await _until(func() -> bool: return sh.hud.big.text == "WATER WAR!", 3.0)
	await _pause(0.3)
	await _snap("c08_water_war_card")
	await _until(func() -> bool: return sh.fighting(), 3.0)
	await _pause(0.2)
	await _snap("c09_war_first_look_east")
	var bot = WarBot.new(self, sh)
	bot.human = true # slower: more to see
	bot.play(60.0) # runs on its own (not awaited)
	var n0: int = sh.shots_fired
	await _until(func() -> bool: return sh.shots_fired >= n0 + 4 or sh.over, 20.0)
	await _snap("c10_war_firing")
	await _until(func() -> bool: return sh.boss != null or sh.over, 30.0)
	await _pause(0.6)
	await _snap("c11_war_bossy_out")
	await _until(func() -> bool: return sh.over, 40.0)
	await _pause(0.1)
	await _snap("c12_soaked")
	await _until(func() -> bool: return cm.fight == null, 5.0)
	await _pause(0.5)
	await _snap("c13_back_at_the_stall")
	var sess = lvl.get_node("ToiletSession")
	sess.poop_seconds = 0.5
	p.global_position = sess._stand_spot() + Vector3(0.0, 0.0, 0.9)
	p.face_direction(Vector3(0.0, 0.0, -1.0))
	await _pause(0.5)
	await _snap("c14_use_toilet_prompt")
	await _key(KEY_E)
	await _until(func() -> bool: return lvl.get_node("HUD/PromptLabel").text == "E  grab tissue", 8.0)
	await _key(KEY_E)
	await _until(func() -> bool: return lvl.get_node("HUD/PromptLabel").text == "E  flush", 10.0)
	await _key(KEY_E)
	await _until(func() -> bool: return lvl._result.visible, 20.0)
	await _pause(0.3)
	await _snap("c15_win")
	Cutters.force_stall = -1
	quit()
