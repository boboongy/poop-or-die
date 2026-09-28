extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh), Stage 7 E1 dance feedback: the real Level 5 flow to the battle (as
## test_dance_battle `_to_battle`), then a bot hits Bob's arrows on time: shots at the 2x combo, at the 5x confetti, and after an EARLY press.
## Run: "<console exe>" --path . --script tests/shot_dance_feedback.gd -- out=<folder>
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
var out := "user://"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(name))
	print("saved ", name)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 5
	Dance.force_stall = 3
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
	await T.wait_for(self, func() -> bool: return d.battle != null, 15.0)
	var b: Node = d.battle
	await T.wait_for(self, func() -> bool: return b.phase == "bob" or b.phase == "call", 20.0)
	var shot2 := false
	var shot5 := false
	var early_done := false
	while b.phase == "call" or b.phase == "bob":
		await physics_frame
		var now: float = b.now()
		for note: Dictionary in b.notes:
			if note["hit"] == "" and now >= float(note["t"]) - 0.01:
				var keys := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
				await T.key(self, keys[int(note["lane"])])
		if b.combo == 2 and not shot2:
			shot2 = true
			await _snap("fb_1_combo2.png")
		if b.combo == 5 and not shot5:
			shot5 = true
			for i in 6:
				await process_frame
			await _snap("fb_2_combo5_confetti.png")
		if b.combo >= 7 and not early_done:
			early_done = true
			await T.key(self, KEY_LEFT) # a press with no arrow in reach: EARLY or LATE
			for i in 3:
				await process_frame
			await _snap("fb_3_early_late.png")
	quit()
