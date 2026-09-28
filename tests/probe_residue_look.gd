extends SceneTree
## WINDOWED probe (not in run.sh): the leftover puddles' look (skill 3c: readable on green-lit white tile from Bob's camera at ~3-5 m).
## Three looks side by side along corridor A (dry Level 2, no walkers), Bob looking along the corridor from 2.5 m behind the first:
## x 3 = variant 0, x 5 = variant 1, x 7 = variant 2 (colours below). Prints nothing; the shot is <out>/residue.png.
const Progress := preload("res://scripts/progress.gd")
const FloodStory := preload("res://scripts/flood_story.gd")
const Walkers := preload("res://scripts/walkers.gd")
const Flood := preload("res://scripts/flood.gd")
const Intro := preload("res://scripts/intro.gd")

const LOOKS := [
	{"deep": Color(0.42, 0.46, 0.33), "thin": Color(0.66, 0.70, 0.56), "glow": 0.45, "sparkle": 0.45}, # current
	{"deep": Color(0.22, 0.26, 0.16), "thin": Color(0.36, 0.40, 0.26), "glow": 0.25, "sparkle": 1.2}, # darker murk, strong glint
	{"deep": Color(0.30, 0.24, 0.10), "thin": Color(0.50, 0.44, 0.22), "glow": 0.55, "sparkle": 0.9}, # brown-olive murk, self-lit
]


func _init() -> void:
	var out := "C:/Users/bobo/AppData/Local/Temp/residue_look"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_root().size = Vector2i(1280, 720)
	Progress.level = 3 # the flood (Level 3 since Stage 6b)
	FloodStory.auto_start = false
	Walkers.enabled = false
	Intro.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	var end := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < end:
		await process_frame
	for i in LOOKS.size():
		var f: Node3D = Flood.new()
		lvl.add_child(f)
		f.setup(lvl)
		f.start_residue(Vector3(3.0 + 2.2 * i, 0.0, 0.05), "look %d" % i)
		var m: ShaderMaterial = f._material
		m.set_shader_parameter("deep_color", LOOKS[i]["deep"])
		m.set_shader_parameter("thin_color", LOOKS[i]["thin"])
		m.set_shader_parameter("glow", LOOKS[i]["glow"])
		m.set_shader_parameter("sparkle_amount", LOOKS[i]["sparkle"])
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(0.6, 0.05, 0.1)
	p.face_direction(Vector3(1.0, 0.0, 0.0))
	p.set_camera(-PI / 2.0, -0.3)
	end = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < end:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/residue.png")
	quit()
