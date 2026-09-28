extends SceneTree
## PROBE (windowed, real audio; not run by run.sh). SPEC Stage 4 plan: "a windowed sound probe with the SND log, 3 runs, both channels".
## Records the Master bus BEFORE the limiter in the real level (first person, the shooter) and prints every sound that starts ("SND"):
## (a) 4 s of fire at the east wall from 2.5 m (shots + splashes close by); (b) fire at a crew's head from 6 m until the kill, twice
## (ding, chime, splashes on them); (c) 1.5 s on an empty tank (dry clicks); (d) slice 6: WATER WAR's real start, the crew's barks and
## shots for 14 s, then the hose with Bob's "SUPER SOAKER!".
## Run: "<console exe>" --path . --script tests/probe_shooter_sound.gd -- out=<folder>   then  python tools/peaks.py <wav> -6
const Shooter := preload("res://scripts/shooter.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"
var rec: AudioEffectRecord
var p: CharacterBody3D
var _t0 := 0
var _seen := 0


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		while _seen < Sfx.played.size():
			if rec.is_recording_active():
				print("SND %.2f s %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, Sfx.played[_seen]])
			_seen += 1


func _start(name: String) -> void:
	rec.set_recording_active(true)
	_t0 = Time.get_ticks_msec()
	_seen = Sfx.played.size()
	print("REC start ", name)


func _stop(name: String) -> void:
	rec.set_recording_active(false)
	rec.get_recording().save_to_wav("%s/%s.wav" % [out, name])
	print("REC ", name)


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(640, 360)
	Input.parse_input_event(ev)


func _aim(at: Vector3) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var d := at - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_root().size = Vector2i(1280, 720)
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	Walkers.enabled = false
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	await _pause(3.0)
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(10.1, 0.0, 0.3)
	p.face_direction(Vector3.RIGHT)
	await _pause(0.3)
	var sh: Node = Shooter.new()
	lvl.add_child(sh)
	sh.start(p)
	await _pause(0.6)
	_aim(Vector3(12.6, 1.1, 0.3))
	_start("a_fire_wall")
	_mouse(true)
	await _pause(4.0)
	_mouse(false)
	await _pause(0.6)
	_stop("a_fire_wall")
	p.global_position = Vector3(2.0, 0.0, 0.3)
	await _pause(0.3)
	sh.tank = Shooter.TANK
	_start("b_kills")
	for i in 2:
		var crew = sh.spawn_crew("CREW %d" % (i + 1), Vector3(8.0, 0.0, 0.3), -PI / 2.0)
		await _pause(0.3)
		_aim(crew.head_center())
		_mouse(true)
		var end := Time.get_ticks_msec() + 3000
		while not crew.down and Time.get_ticks_msec() < end:
			_aim(crew.head_center())
			await _pause(0.02)
		_mouse(false)
		await _pause(1.0)
		crew.body.visible = false
	_stop("b_kills")
	sh.tank = 0
	_start("c_dry")
	_mouse(true)
	await _pause(1.5)
	_mouse(false)
	await _pause(0.3)
	_stop("c_dry")
	# (d) slice 6: the real round-3 start (begin_war), the live crew shooting and barking for 14 s at Bob standing at START (kept
	# alive), then Q for the hose and Bob's "SUPER SOAKER!" (voice lines printed as VOICE)
	sh.abort()
	sh.queue_free()
	var war: Node = Shooter.new()
	lvl.add_child(war)
	war.begin_war(p)
	var spoken0: int = lvl.dialogue.spoken.size()
	_start("d_war_barks")
	var end_d := Time.get_ticks_msec() + int((Shooter.INTRO_SECONDS + 14.0) * 1000.0)
	while Time.get_ticks_msec() < end_d:
		war.bob_hp = Shooter.BOB_HP
		await _pause(0.1)
	war.ult = Shooter.ULT_FULL
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.physical_keycode = KEY_Q
	q.pressed = true
	Input.parse_input_event(q)
	await _pause(0.1)
	q = q.duplicate()
	q.pressed = false
	Input.parse_input_event(q)
	await _pause(Shooter.HOSE_SECONDS + 0.5)
	_stop("d_war_barks")
	for sp: String in lvl.dialogue.spoken.slice(spoken0):
		print("VOICE ", sp)
	print("BARKS ", war.barks)
	quit()
