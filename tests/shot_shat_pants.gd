extends SceneTree
## Player-eye pass for Stage 6d (windowed, real time): the timeout loss in Level 1, shots from the game's own cut camera while the patch
## spreads, plus a close look with a free camera at the full patch. Writes shat_1..4.png to the folder given as `-- out=<dir>`.
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")
var out := "user://"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(name))
	print("saved ", out.path_join(name))


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 1
	Intro.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	for i in 30:
		await process_frame
	lvl._time_left = 0.1
	while not lvl.shat_stain.is_shat():
		await process_frame
	var t0 := Time.get_ticks_msec()
	var shots := [[500, "shat_1.png"], [1150, "shat_2.png"]]
	for s: Array in shots:
		while Time.get_ticks_msec() - t0 < int(s[0]):
			await process_frame
		await _snap(s[1])
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
	await _snap("shat_3.png") # back to the game camera: the result screen
	var p: Node3D = lvl.player
	var cam := Camera3D.new()
	lvl.add_child(cam)
	var back: Vector3 = -p.model().global_transform.basis.z
	back.y = 0.0
	var seat := p.global_position + Vector3.UP * 0.42
	cam.global_position = seat + back.normalized() * 0.55 + Vector3(0.25, 0.15, 0.0)
	cam.look_at(seat, Vector3.UP)
	cam.make_current()
	for i in 5:
		await process_frame
	await _snap("shat_4.png")
	if OS.get_cmdline_user_args().has("magenta"):
		lvl.shat_stain.material.set_shader_parameter("brown", Color.MAGENTA)
		lvl.shat_stain.material.set_shader_parameter("brown_dark", Color.MAGENTA)
		for i in 5:
			await process_frame
		await _snap("shat_5.png")
	quit()
