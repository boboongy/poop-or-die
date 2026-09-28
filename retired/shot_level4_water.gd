extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): BOSSY's water fight through Bob's OWN camera in the real level.
## Run: "<console exe>" --path . --script tests/shot_level4_water.gd -- out=<folder>
const WaterFight := preload("res://scripts/water_fight.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _until(pred: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not pred.call() and Time.get_ticks_msec() < end:
		await process_frame


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)


## Yaw the camera so the crosshair sits on BOSSY (the middle of the yaws that hit).
func _aim(wf: Node, p: Node3D) -> void:
	var to: Vector3 = wf.foe_body.global_position - p.global_position
	var base := atan2(-to.x, -to.z)
	var pitch: float = p.get_camera_pitch()
	var hits: Array = []
	var a := -0.5
	while a <= 0.5:
		p.set_camera(base + a, pitch)
		if wf.crosshair_on_foe():
			hits.append(a)
		a += 0.01
	var mid := 0.0 if hits.is_empty() else (float(hits[0]) + float(hits[hits.size() - 1])) / 2.0
	p.set_camera(base + mid, pitch)
	print("aim hits %d" % hits.size())


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _until(func() -> bool: return false, 3.0) # shaders compile, navmesh bakes
	lvl._time_left = 100000.0
	var p: Node3D = lvl.player
	var boss: Node3D = lvl.population.spawn_walker(Cutters.STAGE_CENTER + Cutters.STAGE_AXIS, 0.0)
	lvl.population.walkers.erase(boss)
	var cm: Node = Cutters.new() # only for BOSSY's orange tint, as in the game
	cm._tint(boss, Cutters.DEFS[2]["color"])
	cm.free()
	var wf: Node = WaterFight.new()
	lvl.add_child(wf)
	wf.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	wf.start(p, boss, Cutters.STAGE_CENTER, Cutters.STAGE_AXIS, "BOSSY", 1, 3)
	await _until(func() -> bool: return false, 0.35)
	await _snap("w00_round")
	await _until(func() -> bool: return wf.hud.big.text == "WATER FIGHT!", 3.0)
	await _until(func() -> bool: return false, 0.2)
	await _snap("w01_water_fight")
	await _until(func() -> bool: return wf.spraying, 4.0)
	await _until(func() -> bool: return false, 0.35)
	await _snap("w02_gun_on_floor_boss_spraying")
	await _until(func() -> bool: return wf.bob_hurt, 4.0)
	await _snap("w03_bob_hit")
	wf.ai_enabled = false
	wf.pickup.interact(p)
	await _until(func() -> bool: return false, 0.3)
	_aim(wf, p)
	await _until(func() -> bool: return false, 0.3)
	await _snap("w04_holding_gun_aimed")
	_mouse(true)
	await _until(func() -> bool: return false, 0.5)
	await _snap("w05_spraying_boss")
	await _until(func() -> bool: return wf.wet >= 0.6, 5.0)
	await _snap("w06_wet_meter_60")
	wf.ai_enabled = true
	await _until(func() -> bool: return wf.spraying, 4.0)
	await _until(func() -> bool: return false, 0.3)
	await _snap("w07_both_spraying")
	wf.ai_enabled = false
	_aim(wf, p)
	await _until(func() -> bool: return wf.hud.big.text == "SOAKED!", 5.0)
	await _until(func() -> bool: return false, 0.15)
	await _snap("w08_soaked")
	_mouse(false)
	await _until(func() -> bool: return not wf.running, 4.0)
	await _until(func() -> bool: return false, 0.3)
	await _snap("w09_after")
	quit()
