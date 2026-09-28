extends SceneTree
## Bob on the puddle, with EVERY stall as the clogged one (both rows): running (sprint) onto wet floor makes him slide about
## 1 s without steering, then he is immune for a moment; walking never slips; dry floor never slips; a mopped puddle never slips.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _init() -> void:
	seed(22)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # the puddle model on its own (the game's puddles are the flood's leftovers)
	var lvl := T.level(self)
	await T.wait(self, 0.6)
	var p: CharacterBody3D = lvl.get_node("Player")
	var fl = T.puddle(lvl)
	lvl._time_left = 100000.0 # this test is longer than the level's 70 s: no timeout kick in the middle of it
	p.floor_wet_fn = fl.wet_at
	for i in 30: # the 20 clogged stalls, then the 10 overflowing sinks
		if i < 20:
			fl.start(i)
		else:
			fl.start_sink(i - 19)
		fl.advance(21.0)
		var src: Vector3 = fl.source
		var tag := "stall %d (row %d)" % [i % 10 + 1, 1 if i < 10 else 2] if i < 20 else "sink %d" % (i - 19)
		var z: float = src.z + 0.6 * fl.dir # a line through the wet band in front of the door or basin, clear of the pilasters
		var east: bool = src.x > 6.0 # run in from the side with room: toward the puddle from the middle of the corridor
		var start_x: float = src.x + (-2.4 if east else 2.4)
		p.global_position = Vector3(start_x, 0.05, z)
		p.set_facing(-PI / 2.0 if east else PI / 2.0)
		Sfx.played.clear()
		await T.wait(self, 0.3)
		T.check(not fl.wet_at(p.global_position) and p.slip_left == 0.0, "%s: Bob starts dry and upright" % tag)
		# --- run into the puddle
		Input.action_press("sprint")
		Input.action_press("move_forward")
		var t := 0.0
		while p.slip_left == 0.0 and t < 2.0:
			await T.wait(self, 0.05)
			t += 0.05
		var slipped: bool = p.slip_left > 0.0
		T.check(slipped, "%s: running onto the wet floor makes Bob slip (after %.2f s)" % [tag, t])
		if slipped:
			var dir0: Vector3 = p._slip_dir
			var on_wet: bool = fl.wet_at(p.global_position)
			T.check(on_wet, "%s: he slipped on a wet cell" % tag)
			# try to steer back while sliding: held keys must not matter
			Input.action_release("move_forward")
			Input.action_press("move_back")
			var t_slide := 0.0
			var steered := false
			while p.slip_left > 0.0 and t_slide < 2.0:
				await T.wait(self, 0.05)
				t_slide += 0.05
				var v := Vector3(p.velocity.x, 0.0, p.velocity.z)
				# only while he is still sliding: the moment it ends he gets the controls back (and then follows the keys)
				# (a wall he slides into, like the entrance jamb at the west end, bends the slide too: that is not steering)
				if p.slip_left > 0.05 and p.get_slide_collision_count() == 0 and v.length() > 0.5 and v.normalized().dot(dir0) < 0.9:
					steered = true
			T.check(t_slide >= 0.8 and t_slide <= 1.15, "%s: the slide lasts about 1 s (%.2f s)" % [tag, t_slide])
			T.check(not steered, "%s: Bob cannot steer while sliding" % tag)
			T.check(absf(p.model().rotation.x) < 0.01, "%s: he is upright again after the slide" % tag)
			Input.action_release("move_back")
			Input.action_press("move_forward")
			await T.wait(self, 0.8)
			T.check(Sfx.count("slip") == 1, "%s: one slip only, immune while he runs on (%d slips)" % [tag, Sfx.count("slip")])
		Input.action_release("move_forward")
		Input.action_release("sprint")
		# --- walking through the same puddle is safe
		await T.wait(self, 2.0) # let the immunity run out
		Sfx.played.clear()
		p.global_position = Vector3(src.x + (1.0 if east else -1.0), 0.05, z)
		p.set_facing(PI / 2.0 if east else -PI / 2.0) # walk back across the wet band
		Input.action_press("move_forward")
		var crossed := false # was he really standing on wet floor while he walked?
		for k in 10:
			await T.wait(self, 0.1)
			if fl.wet_at(p.global_position):
				crossed = true
		Input.action_release("move_forward")
		T.check(p.slip_left == 0.0 and Sfx.count("slip") == 0 and crossed, "%s: walking through the wet band does not slip (on wet floor: %s, %d slips)" % [tag, crossed, Sfx.count("slip")])
		# --- once mopped dry, running through it is fine
		while fl.wet_cells() > 0:
			var found := Vector3.ZERO
			for c in fl.wet.size():
				if found == Vector3.ZERO and fl.wet[c] > 0.0:
					found = fl.cell_center(c % fl.GRID, c / fl.GRID)
			fl.mop(found)
		if i % 5 == 0: # a few stalls are enough for this control
			p.global_position = Vector3(start_x, 0.05, z)
			p.set_facing(-PI / 2.0 if east else PI / 2.0)
			await T.wait(self, 0.3)
			Input.action_press("sprint")
			Input.action_press("move_forward")
			await T.wait(self, 1.2)
			Input.action_release("move_forward")
			Input.action_release("sprint")
			T.check(p.slip_left == 0.0 and Sfx.count("slip") == 0, "%s: running through a mopped floor does not slip" % tag)
	# running on dry floor with the flood far away
	p.global_position = Vector3(3.0, 0.05, -5.25)
	p.set_facing(-PI / 2.0)
	fl.start(4) # first row, stall 5: nowhere near corridor B
	fl.advance(21.0)
	Sfx.played.clear()
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await T.wait(self, 1.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	T.check(p.slip_left == 0.0 and Sfx.count("slip") == 0, "running on dry floor (back corridor, puddle is in the front one) does not slip")
	T.finish(self)
