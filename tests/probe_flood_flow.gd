extends SceneTree
## WINDOWED probe (not in run.sh): the player-eye pass for the whole Level 2 flow (skill 3c), real level, real time, walkers on,
## Bob's own camera; the bot teleports between tasks and presses the real keys. Shots:
## a talk, b blast, c GO/rampage, d the plunger + trickle outside the stall, e deep water with the floating crowd, f the view from
## inside a dive, g the whirlpool while it drains, h/i the leftover puddles, j the mop by the drain.
##   "<console exe>" --path . --script tests/probe_flood_flow.gd -- out=<folder> [stall=N]
const Progress := preload("res://scripts/progress.gd")
const FloodStory := preload("res://scripts/flood_story.gd")

var _out := "C:/Users/bobo/AppData/Local/Temp/flood_flow"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, "  fps ", Engine.get_frames_per_second())


func _wait_s(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap(code: int) -> void:
	_key(code, true)
	await _wait_s(0.1)
	_key(code, false)


func _place(lvl: Node, at: Vector3, face: Vector3, pitch := -0.2) -> void:
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(at.x, maxf(lvl.water.depth - p.FLOAT_DEPTH, 0.05), at.z)
	p.face_direction(face)
	p.set_camera(atan2(-face.x, -face.z), pitch)
	await _wait_s(0.5)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		if a.begins_with("stall="):
			FloodStory.force_stall = int(a.substr(6))
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 3 # the flood (Level 3 since Stage 6b)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _wait_s(2.0)
	var story: Node3D = lvl.flood_story
	var w: Node3D = lvl.water
	var d = lvl.dialogue
	print("clogged ", story.stall_text(), " sinks ", story.sinks)
	# the intro: E through the lines, shots on the way
	var lines := 0
	while lvl.intro_playing:
		if d._waiting:
			lines += 1
			await _wait_s(1.2)
			if lines == 2:
				await _snap("a_talk")
			if lines == 5:
				await _snap("b_scream")
			await _tap(KEY_E)
		await _wait_s(0.3)
	await _wait_s(3.0)
	await _snap("c_go_rampage")
	var door: Vector3 = story._door_floor
	var out: Vector3 = story._out
	var along := Vector3(1.0, 0.0, 0.0) if door.x < 6.0 else Vector3(-1.0, 0.0, 0.0)
	await _place(lvl, door + out * 1.2 - along * 2.5, (along + out * -0.25).normalized())
	await _snap("d_plunger_trickle")
	while w.depth < 1.2:
		await process_frame
	await _place(lvl, door + out * 1.5 - along * 1.5, along)
	await _wait_s(1.0)
	await _snap("e_deep_crowd")
	# the plunger, then a dive at the toilet
	await _place(lvl, door + out * 1.4, -out)
	await _tap(KEY_E)
	await _wait_s(2.0)
	await _place(lvl, door - out * 0.25, -out)
	_key(KEY_E, true)
	await _wait_s(1.4)
	await _snap("f_dive_under")
	await _wait_s(2.6)
	_key(KEY_E, false)
	await _wait_s(1.2)
	print("unclogged: ", not story.clogged)
	for k: int in story.sinks.duplicate():
		await _place(lvl, Vector3(story._tap_point(k).x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
		await _tap(KEY_E)
		await _wait_s(2.0)
	print("running: ", w.running_count())
	await _place(lvl, story.DRAIN_POS + Vector3(0.7, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	await _tap(KEY_E)
	await _wait_s(2.5)
	await _place(lvl, story.DRAIN_POS + Vector3(2.2, 0.0, 0.6), (Vector3(-2.2, 0.0, -0.6)).normalized(), -0.45)
	await _wait_s(1.0)
	await _snap("g_whirlpool")
	while not story.is_drained:
		await process_frame
	await _wait_s(1.0)
	await _place(lvl, door + out * 1.3 - along * 3.0, (along + out * -0.3).normalized(), -0.3)
	await _snap("h_residue_stall")
	var mid: int = story.sinks[1]
	await _place(lvl, Vector3(story._tap_point(mid).x - 2.8, 0.0, -0.3), Vector3(1.0, 0.0, 0.1).normalized(), -0.3)
	await _snap("i_residue_sink")
	await _place(lvl, Vector3(-2.2, 0.0, -0.9), Vector3(-1.0, 0.0, 0.1).normalized(), -0.35)
	await _snap("j_drain_mop")
	quit()
