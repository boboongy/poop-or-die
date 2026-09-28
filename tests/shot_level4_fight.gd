extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): the Level 4 fight through its own side camera in the real level.
## Run: "<console exe>" --path . --script tests/shot_level4_fight.gd -- out=<folder>
## Poses are started by calling the fight's own button handler, and each shot waits for the fight state (not wall-clock).
const Fight := preload("res://scripts/fight.gd")
const Walkers := preload("res://scripts/walkers.gd")

const CENTER := Vector3(11.5, 0.0, -2.5)
const AXIS := Vector3(0.0, 0.0, -1.0)

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits until `pred` is true (checked every frame), max `seconds` of wall clock.
func _until(pred: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not pred.call() and Time.get_ticks_msec() < end:
		await process_frame


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
	var npc: Node3D = lvl.population.spawn_walker(CENTER + AXIS, 0.0)
	lvl.population.walkers.erase(npc)
	var f: Node = Fight.new()
	lvl.add_child(f)
	f.ai_enabled = false
	f.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/PromptLabel"), lvl.get_node("HUD/StatusLabel")]
	f.start(lvl.player, npc, CENTER, AXIS, "CUTTER", 1000.0, true, 1)
	await _until(func() -> bool: return false, 0.35)
	await _snap("00a_round")
	await _until(func() -> bool: return f.hud.big.text == "FIGHT!", 3.0)
	await _until(func() -> bool: return false, 0.2)
	await _snap("00b_fight")
	await _until(func() -> bool: return f.fighting(), 3.0)
	await _until(func() -> bool: return false, 0.6)
	await _snap("01_stance")

	f.foe.pos = f.bob.pos + 0.75
	await _frames(3)
	f._try("punch")
	await _until(func() -> bool: return f.hitstop_left > 0.0, 2.0)
	await _snap("02_punch_contact")
	await _until(func() -> bool: return f.bob.can_act(), 3.0)
	await _until(func() -> bool: return f.foe.can_act(), 3.0)
	f._try("punch")
	await _frames(2)
	f._try("punch")
	await _until(func() -> bool: return f.bob.combo >= 5, 4.0)
	await _snap("02b_combo")
	await _until(func() -> bool: return f.bob.can_act() and f.foe.can_act(), 4.0)

	Input.action_press("fight_block")
	await _until(func() -> bool: return false, 0.4)
	await _snap("03_block")
	Input.action_release("fight_block")
	await _until(func() -> bool: return false, 0.3)

	f._try("kick")
	await _until(func() -> bool: return f.hitstop_left > 0.0, 2.0)
	await _snap("04_kick_contact")
	await _until(func() -> bool: return f.bob.can_act() and f.foe.can_act(), 3.0)

	f._try("jump")
	await _until(func() -> bool: return f.bob.t >= 0.33, 2.0)
	await _snap("05_jump_peak")
	await _until(func() -> bool: return f.bob.can_act(), 3.0)

	f._try("uppercut") # D S D J (keyboard specials, 2026-09-25): its name flashes under Bob's bar
	await _until(func() -> bool: return f.hitstop_left > 0.0, 2.0)
	await _snap("06_uppercut_contact")
	await _until(func() -> bool: return f.bob.can_act() and f.foe.can_act(), 3.0)
	f.foe.pos = f.bob.pos + 0.9
	await _frames(3)
	f._try("spin") # S A K
	await _until(func() -> bool: return f.hitstop_left > 0.0, 3.0)
	await _snap("06a_spin_kick_contact")
	await _until(func() -> bool: return f.bob.can_act() and f.foe.can_act(), 3.0)

	f.bob.meter = 100.0
	await _until(func() -> bool: return false, 0.3)
	await _snap("06b_super_ready")
	f._try("super")
	await _until(func() -> bool: return f.hitstop_left > 0.0, 2.0)
	await _snap("07_super_contact")
	await _until(func() -> bool: return f.bob.can_act() and f.foe.can_act(), 4.0)

	f.foe.hp = 1.0
	f._try("punch")
	await _until(func() -> bool: return f.foe.is_dizzy(), 3.0)
	await _until(func() -> bool: return false, 0.8)
	await _snap("08_dizzy")
	f._try("kick")
	await _until(func() -> bool: return f.hitstop_left > 0.0, 5.0)
	await _snap("09_finisher_contact")
	await _until(func() -> bool: return f.foe.is_ko(), 4.0)
	await _until(func() -> bool: return false, 0.25)
	await _snap("09b_toiletality")
	await _until(func() -> bool: return not f.running, 6.0)
	# after the fight: look at the KO'd body from the side camera's spot
	f.camera.make_current()
	await _until(func() -> bool: return false, 0.3)
	await _snap("10_ko")
	quit()
