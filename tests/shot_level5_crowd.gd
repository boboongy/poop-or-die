extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Level 5 step 3 in the real flow, walkers on: the rush after SHUFFLE QUEEN's
## challenge (Bob's camera), then the ring in the waiting room from the battle camera at three moments (different beats).
## Run: "<console exe>" --path . --script tests/shot_level5_crowd.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Walkers := preload("res://scripts/walkers.gd")

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


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	Progress.level = 5
	Dance.force_stall = 5
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	await _pause(2.0)
	p = lvl.player
	var d: Node = lvl.dance
	lvl._time_left = 1000.0
	for k in [KEY_E, KEY_1, KEY_E, KEY_E]:
		await _key(k)
		await _pause(0.3)
	var q: Vector3 = d.queen.global_position
	p.global_position = Vector3(q.x - 1.0, p.global_position.y, q.z + 0.35)
	p.face_direction(Vector3(1.0, 0.0, -0.35).normalized())
	await _pause(0.6)
	await _key(KEY_E)
	await _pause(0.3)
	await _key(KEY_2)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(0.9)
	await _snap("e00_rush")
	await _pause(0.6)
	await _snap("e01_rush_shout")
	await _until(func() -> bool: return d.circle_ready, 6.0)
	await _pause(0.6)
	await _snap("e02_circle")
	await _pause(0.9)
	await _snap("e03_circle_later")
	await _pause(1.3)
	await _snap("e04_circle_later2")
	# the battle: her turn, the call, Bob's arrows (a bot plays about 80 % of them), the round's result
	await _until(func() -> bool: return d.battle != null and d.battle.phase == "queen", 8.0)
	await _pause(1.5)
	await _snap("f00_her_turn")
	await _until(func() -> bool: return d.battle.phase == "call", 6.0)
	await _pause(0.25)
	await _snap("f01_your_turn")
	var shots := 0
	var played := {}
	var next_shot := Time.get_ticks_msec() + 1500
	var rng := RandomNumberGenerator.new()
	while d.battle.phase == "call" or d.battle.phase == "bob":
		var b: Node = d.battle
		for note: Dictionary in b.notes:
			var id := "%.3f" % note["t"]
			if not played.has(id) and note["hit"] == "" and absf(b.now() - float(note["t"])) < 0.035:
				played[id] = true
				if rng.randf() < 0.8:
					var sent: float = b.now()
					await _key([KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT][note["lane"]])
					print("INFO  press lane %d: note %.3f, sent at %+.3f, now %+.3f after the key -> '%s'" % [note["lane"], note["t"],
							sent - float(note["t"]), b.now() - float(note["t"]), note["hit"]])
		if Time.get_ticks_msec() > next_shot and shots < 3:
			await _snap("f%02d_bob_turn" % (shots + 2))
			shots += 1
			next_shot = Time.get_ticks_msec() + 1700
		await process_frame
	await _pause(0.3)
	await _snap("f05_round_result")
	print("INFO  round 1: Bob %.0f%%, perfects %d goods %d misses %d" % [d.battle.round_log[0]["bob"] * 100.0, d.battle.perfects, d.battle.goods, d.battle.misses])
	# from here the bot plays every arrow until the battle is won (a lost battle restarts: keep going)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000 and not (d.battle != null and d.battle.over and d.battle.bob_won):
		var b: Node = d.battle
		if b != null and (b.phase == "call" or b.phase == "bob"):
			for note: Dictionary in b.notes:
				var id := "%d/%d/%.3f" % [d.rematches, b.round_number, note["t"]]
				if not played.has(id) and note["hit"] == "" and absf(b.now() - float(note["t"])) < 0.035:
					played[id] = true
					await _key([KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT][note["lane"]])
		await process_frame
	await _pause(0.4)
	await _snap("g00_you_win")
	await _until(func() -> bool: return get_root().get_camera_3d() != d.camera, 6.0)
	await _pause(0.8)
	await _snap("g01_back_in_the_toilet")
	var mission: Label = lvl.get_node("HUD/MissionLabel")
	await _until(func() -> bool: return mission.text.contains("is free"), 8.0)
	var sess: Node = lvl.get_node("ToiletSession")
	var fwd := Vector3(0, 0, 1) if d.stall < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + fwd * 0.9
	p.face_direction(-fwd)
	await _pause(0.6)
	await _snap("g02_stall_free")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	await _key(KEY_E)
	await _until(func() -> bool: return prompt.text == "E  grab tissue", 8.0)
	await _key(KEY_E)
	await _until(func() -> bool: return prompt.text == "E  flush", 10.0)
	await _key(KEY_E)
	await _until(func() -> bool: return lvl._result.visible, 20.0)
	await _pause(0.5)
	await _snap("g03_the_end")
	Dance.force_stall = -1
	lvl.queue_free()
	await _pause(0.3)
	quit()
