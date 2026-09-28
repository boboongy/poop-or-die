extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): the Level 5 camera focus (dance.gd `camera_focus`) in the real flow, walkers
## on, round 1: the home shot, her turn (gliding in, holding, back home), Bob's turn (holding on Bob while a bot plays his arrows).
## Run: "<console exe>" --path . --script tests/shot_dance_camera.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var d: Node


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name, "  phase ", d.battle.phase if d.battle else "-", "  cam ", d.camera.global_position if d.camera else Vector3.ZERO)
	var p: Node3D = current_scene.player
	var head: Vector3 = p.to_global(p._head_local())
	print("INFO  Bob body %s head %s on screen %s | her body %s" % [p.global_position, head,
			d.camera.unproject_position(head) if d.camera else Vector2.ZERO, d.queen.global_position])


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


## Waits `seconds` into the current phase while a bot hits every arrow that comes due.
func _play(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		var b: Node = d.battle
		if b != null and (b.phase == "call" or b.phase == "bob"):
			for note: Dictionary in b.notes:
				if note["hit"] == "" and absf(b.now() - float(note["t"])) < 0.035:
					await _key([KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT][note["lane"]])
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
	var p: Node3D = lvl.player
	d = lvl.dance
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
	await _until(func() -> bool: return d.battle != null and d.battle.phase == "intro", 12.0)
	await _pause(0.3)
	await _snap("c00_home")
	await _until(func() -> bool: return d.battle.phase == "queen", 6.0)
	await _pause(0.25)
	await _snap("c01_her_turn_gliding")
	await _pause(0.9)
	await _snap("c02_her_turn_hold")
	await _pause(1.2)
	await _snap("c03_her_turn_hold_later")
	await _pause(1.0)
	await _snap("c04_her_turn_back_home")
	await _until(func() -> bool: return d.battle.phase == "bob", 6.0)
	await _play(1.2)
	await _snap("c05_bob_turn_hold")
	await _play(1.5)
	await _snap("c06_bob_turn_hold_later")
	await _play(1.5)
	await _snap("c07_bob_turn_back_home")
	Dance.force_stall = -1
	lvl.queue_free()
	await _pause(0.3)
	quit()
