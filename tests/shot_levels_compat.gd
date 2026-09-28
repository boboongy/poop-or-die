extends SceneTree
## Stage 8 look check (windowed, real time; not run by run.sh): every level from the game's default camera, 3 s in, plus the average FPS
## over 4 s. Run it with the web build's renderer:
##   "<console exe>" --path . --rendering-method gl_compatibility --script tests/shot_levels_compat.gd -- out=<dir> [tag=compat]
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")
var out := "user://"
var tag := "compat"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(name))


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("tag="):
			tag = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Intro.enabled = false
	print("renderer: ", RenderingServer.get_current_rendering_method())
	for n in range(1, 6):
		Progress.level = n
		var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
		await process_frame
		get_root().add_child(lvl)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
		await _snap("%s_level%d.png" % [tag, n])
		var frames := 0
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			await process_frame
			frames += 1
		print("L%d  %.0f FPS" % [n, frames / 4.0])
		lvl.queue_free()
		await process_frame
	quit()
