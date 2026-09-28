extends SceneTree
## FACTORY_TODO batches 1-2: every Jijio's idle/walk/run/sit (queue, walkers, seekers, stall occupants all share
## npc_jijio.gd). Checks one instance of each relevant state: SIT (the baked 'sit' clip, looped), QUEUED standing
## (idle), WALK (walk, right speed_scale), CHASE (run, right speed_scale) -- not all 20 stalls, since the logic is
## identical for every Jijio regardless of which stall; tests/test_hide_hop.gd already covers all 20 for the hiding
## mechanics themselves.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")


func _init() -> void:
	seed(2)
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0

	# --- a sitting occupant: the baked 'sit' clip plays and loops
	var occ: Node3D = lvl.population.occupants[0]
	T.check(occ.is_sitting(), "occupant 0 sits at level start")
	await T.wait(self, 0.2)
	T.check(occ.anim().is_playing() and occ.anim().current_animation == "sit", "a sitting occupant plays the baked 'sit' clip (got '%s')" % occ.anim().current_animation)
	T.check(occ.anim().get_animation("sit").loop_mode == Animation.LOOP_LINEAR, "sit loops (the glb's own loop flag does not survive export)")
	await T.wait(self, 3.5) # sit is 3.0 s long: this proves it looped instead of stopping
	T.check(occ.anim().is_playing(), "sit is still playing past its own 3.0 s length (looped)")

	# --- a queue Jijio standing still: idle until its first queue clip, then talk / squirm / twerk (Stage 6c E, test_queue_fidget)
	var q: Node3D = lvl.population.queue[0]
	await T.wait(self, 0.3)
	T.check(q.anim().is_playing() and q.anim().current_animation in ["idle", "talk", "squirm", "twerk"], "a standing queue Jijio plays idle or a queue clip (got '%s')" % q.anim().current_animation)

	# --- the same Jijio walking: walk, right speed_scale, loops
	q.go_to(q.global_position + Vector3(3.0, 0.0, 0.0))
	await T.wait(self, 0.3)
	T.check(q.is_walking(), "told to walk, state is WALK")
	T.check(q.anim().current_animation == "walk", "walking plays 'walk' (got '%s')" % q.anim().current_animation)
	var walk_actual: float = Vector3(q.velocity.x, 0.0, q.velocity.z).length()
	T.check(absf(q.anim().speed_scale - walk_actual / 1.0) < 0.05, "walk speed_scale matches real speed / authored 1.0 m/s (got %.2f)" % q.anim().speed_scale)
	await T.wait(self, 0.8) # walk is 0.667 s: proves it looped
	T.check(q.anim().is_playing() and q.anim().current_animation == "walk", "still walking/looping after more than one cycle")

	# --- CHASE (the timeout-kick sprint): run, right speed_scale
	var p: CharacterBody3D = lvl.player
	q.start_kicking(p, 0.0)
	await T.wait(self, 0.3)
	T.check(q.anim().current_animation == "run", "chasing plays 'run' (got '%s')" % q.anim().current_animation)
	var run_actual: float = Vector3(q.velocity.x, 0.0, q.velocity.z).length()
	T.check(absf(q.anim().speed_scale - run_actual / 3.1) < 0.05, "run speed_scale matches real speed / authored 3.1 m/s (got %.2f)" % q.anim().speed_scale)

	lvl.queue_free()
	await process_frame
	T.finish(self)
