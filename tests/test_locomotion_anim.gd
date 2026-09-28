extends SceneTree
## FACTORY_TODO batch 1, wired 2026-09-23: Bob's idle/walk/run clips (Pose.locomotion/stop_locomotion, player.gd).
## Checks: idle when standing, walk when walking (with the right speed_scale), run when sprinting (with the right speed_scale),
## every clip actually loops past its own length, and stop_locomotion (busy/hiding/slip) leaves the AnimationPlayer stopped.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")


func _init() -> void:
	seed(1)
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var ap: AnimationPlayer = p.anim()
	T.check(ap != null, "Bob has an AnimationPlayer")

	# --- standing still: idle
	await T.wait(self, 0.3)
	T.check(ap.current_animation == "idle" and ap.is_playing(), "standing still plays idle (got '%s')" % ap.current_animation)
	T.check(ap.get_animation("idle").loop_mode == Animation.LOOP_LINEAR, "idle loops (the glb's own loop flag does not survive export)")
	var before := ap.current_animation_position
	await T.wait(self, 3.5) # idle is 3.0 s long: this proves it looped instead of stopping
	T.check(ap.is_playing(), "idle is still playing past its own 3.0 s length (looped)")

	# --- walking: KEY_W held
	await T.key_down(self, KEY_W)
	await T.wait(self, 0.3)
	T.check(ap.current_animation == "walk", "walking plays 'walk' (got '%s')" % ap.current_animation)
	var walk_speed: float = Vector3(p.velocity.x, 0.0, p.velocity.z).length()
	var expected_walk_scale: float = walk_speed / 1.0 # authored at 1.0 m/s
	T.check(absf(ap.speed_scale - expected_walk_scale) < 0.05, "walk speed_scale matches real speed / authored 1.0 m/s (got %.2f, want %.2f)" % [ap.speed_scale, expected_walk_scale])
	await T.wait(self, 1.0) # walk is 0.667 s: proves it looped
	T.check(ap.is_playing() and ap.current_animation == "walk", "walk is still playing/looping after more than one cycle")

	# --- sprinting: hold shift too
	await T.key_down(self, KEY_SHIFT)
	await T.wait(self, 0.3)
	T.check(ap.current_animation == "run", "sprinting plays 'run' (got '%s')" % ap.current_animation)
	var run_speed: float = Vector3(p.velocity.x, 0.0, p.velocity.z).length()
	var expected_run_scale: float = run_speed / 3.1 # authored at 3.1 m/s
	T.check(absf(ap.speed_scale - expected_run_scale) < 0.05, "run speed_scale matches real speed / authored 3.1 m/s (got %.2f, want %.2f)" % [ap.speed_scale, expected_run_scale])
	await T.key_up(self, KEY_SHIFT)
	await T.key_up(self, KEY_W)
	await T.wait(self, 0.3)
	T.check(ap.current_animation == "idle", "letting go returns to idle (got '%s')" % ap.current_animation)

	# --- busy stops the locomotion clip (grabs / the toilet sequence pose Bob directly, see player.gd _physics_process)
	await T.key_down(self, KEY_W) # walking again first, so there is something playing to stop
	await T.wait(self, 0.3)
	T.check(ap.is_playing(), "walking again before the busy check")
	p.busy = true
	await T.wait(self, 0.2)
	T.check(not ap.is_playing(), "busy stops the locomotion clip")
	p.busy = false
	await T.key_up(self, KEY_W)

	lvl.queue_free()
	await process_frame
	T.finish(self)
