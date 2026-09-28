extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Level 3's ghost intro in the real flow (walkers on, Bob's own camera): the first
## line, the reveal, the vanish, GO!, then both corridors during the counting (where the walkers wait: the door-free wall).
## Run: "<console exe>" --path . --script tests/shot_hide_ghost.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


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
	Progress.level = 2 # hide and seek (Level 2 since Stage 6b)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	# Round 2: the fart scene first (the cloud bursting, filling the room, Bob's line, his walk, the accusation)
	await _pause(0.7)
	await _snap("l3_fart_1_burst")
	await _pause(3.3) # Bob speaks 3.6 s in (intro.gd FART_ALONE + BOB_AFTER_SHOUTS)
	await _snap("l3_fart_2_cloud_bob_line")
	await _key(KEY_E)
	await _pause(0.6)
	await _snap("l3_fart_3_walking")
	await _pause(1.6)
	await _snap("l3_fart_4_accuse")
	await _key(KEY_E)
	await _pause(0.5)
	await _snap("l3_intro_1_first_line")
	await _key(KEY_2)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(1.1)
	await _snap("l3_intro_2_ghost_reveal")
	await _key(KEY_E)
	await _pause(0.3)
	await _key(KEY_E)
	await _pause(0.3)
	await _snap("l3_intro_3_ghost_last_line")
	await _key(KEY_E)
	await _pause(0.45)
	await _snap("l3_intro_4_vanishing")
	await _pause(0.6)
	await _snap("l3_intro_5_go")
	print("INFO clock after the intro: %.1f (running %s), queue %d" % [lvl._time_left, lvl._running, lvl.population.queue.size()])
	await _pause(3.0)
	var p: Node3D = lvl.player
	p.global_position = Vector3(1.3, 0.05, 0.05)
	p.set_facing(-PI / 2.0)
	await _pause(0.6)
	await _snap("l3_counting_corridor_A")
	p.global_position = Vector3(1.3, 0.05, -5.25)
	p.set_facing(-PI / 2.0)
	await _pause(0.6)
	await _snap("l3_counting_corridor_B")
	for w: Node3D in lvl.population.walkers:
		print("INFO walker at (%.2f, %.2f) parked %s, in a door zone %s" % [w.global_position.x, w.global_position.z, lvl.get_node("Walkers").is_parked(w), Walkers.in_door_zone(w.global_position)])
	quit()
