extends SceneTree
## SCREENSHOTS (windowed, real time; not run by run.sh): Stage 6c D, talking to queue Jijios through Bob's own camera (walkers on, the
## start dialogue skipped with Enter): Level 1 queue[8] (back of the line) from 1.4 m: the prompt, then the talk in first person; queue[5]
## (middle of the snake) as far as the neighbours allow; Level 4 queue[0] (front of the line) in first person.
## Run: "<console exe>" --path . --script tests/shot_queue_talk.gd -- out=<folder>
const Progress := preload("res://scripts/progress.gd")
const Walkers := preload("res://scripts/walkers.gd")

var out := "C:/tmp"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("SHOT ", name)


func _pause(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _level(n: int) -> Node:
	Progress.level = n
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	get_root().add_child(lvl)
	current_scene = lvl
	return lvl


## Bob as far as possible (1.4 m down to 0.6 m) from `npc`, inside the waiting room, facing it, where the E prompt picks it (the same
## search as test_queue_talk).
func _stand(lvl: Node, npc: Node3D) -> void:
	var p: CharacterBody3D = lvl.player
	for dist in [1.4, 1.2, 1.0, 0.8, 0.6]:
		for k in 16:
			var a := TAU * k / 16.0
			var spot: Vector3 = npc.global_position + Vector3(sin(a), 0.0, cos(a)) * dist
			spot.y = p.global_position.y
			if spot.x < -4.7 or spot.x > -0.3 or absf(spot.z) > 1.6:
				continue
			var clear := true
			for other: Node3D in lvl.population.queue:
				if other != npc and Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length() < 0.6:
					clear = false
			if not clear:
				continue
			p.global_position = spot
			p.velocity = Vector3.ZERO
			var to: Vector3 = npc.global_position - spot
			p.set_facing(atan2(-to.x, -to.z))
			await _pause(0.15)
			if p._focus == npc:
				await _pause(0.3)
				print("stand %.1f m from the target, prompt '%s'" % [dist, p._prompt_text])
				return
	print("NO SPOT for ", npc)


func _talk_shot(lvl: Node, name: String) -> void:
	await _key(KEY_E)
	await _pause(0.8)
	await _snap(name)
	await _key(KEY_W) # small talk: W leaves at once
	await _pause(0.8)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	get_root().size = Vector2i(1280, 720)
	Walkers.enabled = true
	await process_frame
	var lvl := _level(1)
	await _pause(1.0)
	await _key(KEY_ENTER) # skip the start dialogue
	await _pause(1.8)
	lvl._time_left = 100000.0
	var q: Array = lvl.population.queue
	await _stand(lvl, q[8])
	await _snap("q1_prompt_back_of_line")
	await _talk_shot(lvl, "q2_talk_back_of_line")
	await _stand(lvl, q[5])
	await _talk_shot(lvl, "q3_talk_middle")
	lvl.queue_free()
	await _pause(0.3)
	lvl = _level(4)
	await _pause(1.0)
	await _key(KEY_ENTER)
	await _pause(1.8)
	lvl._time_left = 100000.0
	await _stand(lvl, lvl.population.queue[0])
	await _talk_shot(lvl, "q4_talk_front_L4")
	quit()
