extends SceneTree
## PROBE (windowed, real audio; not run by run.sh): does the arrows' clock (dance.gd song_time, advanced on physics ticks) drift from the
## beat the player HEARS (the boombox's playback position)? Prints both, modulo the 4.8 s loop, every 5 s for 40 s, and the drift.
## Run: "<console exe>" --path . --script tests/probe_dance_sync.gd
const Progress := preload("res://scripts/progress.gd")
const DanceBeat := preload("res://scripts/dance_beat.gd")


func _init() -> void:
	get_root().size = Vector2i(1280, 720)
	Progress.level = 5
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	current_scene = lvl
	lvl._time_left = 1000.0
	var d: Node = lvl.dance
	var loop := DanceBeat.beat_seconds() * 4.0 * DanceBeat.BARS
	print("INFO  output latency %.3f s" % AudioServer.get_output_latency())
	print("INFO  audio clock in use: %s" % d.use_audio_clock)
	var start := Time.get_ticks_msec()
	var next := 2000
	var last := -1.0
	var back_jumps := 0
	var worst_back := 0.0
	var first_song := 0.0
	var first_wall := 0.0
	while Time.get_ticks_msec() - start < 41000:
		await process_frame
		var s: float = d.song_time()
		var wall := (Time.get_ticks_msec() - start) / 1000.0
		if last < 0.0:
			first_song = s
			first_wall = wall
		elif s < last - 0.005:
			back_jumps += 1
			worst_back = maxf(worst_back, last - s)
		last = s
		if Time.get_ticks_msec() - start >= next:
			next += 5000
			var tick_clock: float = d._clock - AudioServer.get_output_latency()
			print("INFO  t %4.1f s: song time %.3f (loop %d), the old tick clock would say %+.3f s, FPS %d" % [wall, s, d._loops,
					tick_clock - s, Engine.get_frames_per_second()])
	var rate := (last - first_song) / ((Time.get_ticks_msec() - start) / 1000.0 - first_wall)
	print("INFO  backward jumps over 5 ms: %d (worst %.3f s); song time ran at %.4f x real time over 40 s" % [back_jumps, worst_back, rate])
	lvl.queue_free()
	await process_frame
	quit()
