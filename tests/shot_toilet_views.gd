extends SceneTree
## Screenshots (windowed, real time) through Bob's own camera during the toilet sequence: the pants_down stretch (was the
## headless moment), the switch to third person, the tissue grab and the wipe. `-- stall=N` (0-19, default 3).
## Output: <scratch>/toilet_<stall>_<label>.png
const T := preload("res://tests/t.gd")

var _dir := "C:/Users/bobo/AppData/Local/Temp/claude/c--Users-bobo-Documents-mi-godot/f2b28624-0af0-4b46-82fb-d8abbfc4e204/scratchpad/"


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)


func _init() -> void:
	var stall := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("stall="):
			stall = int(a.substr(6))
		if a.begins_with("out="):
			_dir = a.substr(4) + "/"
	DirAccess.make_dir_recursive_absolute(_dir)
	get_root().size = Vector2i(1280, 720)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	var p = lvl.get_node("Player")
	var pop: Node3D = lvl.get_node("Population")
	var sess = lvl.get_node("ToiletSession")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	sess.poop_seconds = 1.0
	await pop.reward_release(stall)
	sess.setup(stall)
	p.global_position = sess._stand_spot() + sess._forward * 0.9
	p.face_direction(-sess._forward)
	await T.wait(self, 0.5)
	var ap: AnimationPlayer = p.anim()
	await T.key(self, KEY_E)
	# tissue_grab at frames 19 (paper hanging), 30 (pulled, roll turning), 43 (torn), 66 (the folded sheet in his hand)
	var shots := {"pants_down": [0.3, 0.8, 1.3, 1.9], "sit_down": [0.05, 0.3], "tissue_grab": [0.63, 1.0, 1.43, 2.2], "wipe": [0.2, 1.0, 2.0]}
	var taken := {}
	var tissue_pressed := false
	for i in 60 * 25:
		await process_frame
		if not tissue_pressed and prompt.text == "E  grab tissue":
			tissue_pressed = true
			await _snap(_dir + "toilet_%d_prompt.png" % stall)
			await T.key(self, KEY_E)
		var clip := ap.current_animation
		if shots.has(clip):
			for at in shots[clip]:
				var key := "%s_%.2f" % [clip, at]
				if not taken.has(key) and ap.current_animation_position >= at:
					taken[key] = true
					await _snap(_dir + "toilet_%d_%s.png" % [stall, key])
		if taken.size() >= 13:
			await T.wait(self, 0.2)
			await _snap(_dir + "toilet_%d_zz_after_wipe.png" % stall) # the sheet dropped into the bowl
			break
	print("shots: ", taken.keys())
	quit()
