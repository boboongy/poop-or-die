extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 4 slice 5 through Bob's own first-person camera in the real level: the
## ult ring at 0 / 50 / 100 % ("Q"), then the SUPER-SOAKER hose started with a real Q press: on a crew 7 m down corridor A, on a crew
## 3 m away in the east end, and on a toilet-paper stack.
## Run: "<console exe>" --path . --script tests/shot_shooter_ult.gd -- out=<folder>
const Shooter := preload("res://scripts/shooter.gd")

var out := "C:/tmp"
var p: CharacterBody3D
var sh: Node


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


## Stand at `at` and look at `target` through Bob's first-person camera.
func _look(at: Vector3, target: Vector3) -> void:
	p.global_position = at
	await _pause(0.15)
	var cam := p.get_viewport().get_camera_3d()
	var d := target - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _pause(0.3)


func _press_q() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_Q
		ev.keycode = KEY_Q
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await physics_frame


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(3.0)
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(2.0, 0.0, -0.5)
	p.face_direction(Vector3.RIGHT)
	await _pause(0.3)
	sh = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)
	sh.ai_enabled = false
	var crew = sh.spawn_crew("CREW 1", Vector3(9.0, 0.0, -0.2), -PI / 2.0)
	crew.hp = 10000.0
	await _look(Vector3(2.0, 0.0, -0.5), Vector3(9.0, 0.8, -0.2))
	await _snap("c01_ring_0")
	sh.ult = 150.0
	await _pause(0.2)
	await _snap("c02_ring_50")
	sh.ult = Shooter.ULT_FULL
	await _pause(0.5)
	await _snap("c03_ring_full_Q")
	# the hose on the crew, 7 m
	await _press_q()
	await _pause(0.4)
	await _snap("c04_hose_crew_7m_shout")
	await _pause(1.3)
	await _look(p.global_position, crew.body.global_position + Vector3.UP * 0.8)
	await _snap("c05_hose_crew_pushed")
	sh.end_hose()
	# close up in the east end
	crew.body.global_position = Vector3(11.8, 0.0, -2.8)
	await _look(Vector3(11.5, 0.0, 0.3), Vector3(11.8, 0.8, -2.8))
	sh.ult = Shooter.ULT_FULL
	await _press_q()
	await _pause(0.8)
	await _snap("c06_hose_crew_3m")
	sh.end_hose()
	# on a stack (corridor A's, from the west)
	crew.body.global_position = Vector3(20.0, 0.0, 20.0)
	await _look(Vector3(3.0, 0.0, -0.3), Vector3(5.6, 0.6, -0.7))
	sh.ult = Shooter.ULT_FULL
	await _press_q()
	await _pause(0.8)
	await _snap("c07_hose_on_stack")
	sh.end_hose()
	quit()
