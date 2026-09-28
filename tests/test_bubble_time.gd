extends SceneTree
## Owner report 2026-09-25 (Level 5): "could not fully digest the dialogue since too fast". The timed speech bubbles (dialogue.gd bubble())
## were given 1.2-1.6 s whatever their length ("Not here! WAITING ROOM, everybody!" 1.4 s). Every bubble must now stay readable for at
## least Dialogue.READ_BASE + READ_PER_WORD per word, even when the caller asks for less; a caller asking for MORE keeps its time.
## Checked on every bubble line Level 5 uses (her lines and all the crowd shouts), sampled while the bubble lives.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")
const Dialogue := preload("res://scripts/dialogue.gd")


func _life(lvl: Node, text: String, asked: float) -> float:
	var npc: Node3D = lvl.population.queue[0]
	# her lines in her voice (every line said must have a voice file: dialogue.gd prints VOICE MISSING, run.sh fails the test)
	lvl.dialogue.bubble(npc, text, asked, Dialogue.BUBBLE_HEIGHT, Dance.QUEEN_NAME if not Dance.SHOUTS.has(text) else "Jijio")
	var label: Label3D = null
	for c in npc.get_children():
		if c is Label3D and (c as Label3D).text == text:
			label = c
	var t := 0.0
	while is_instance_valid(label) and label.modulate.a > 0.5 and t < 20.0:
		await physics_frame
		t += 1.0 / 60.0
	return t


func _init() -> void:
	Progress.level = 5
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var D = lvl.dialogue
	var lines: Array = ["Not here! WAITING ROOM, everybody!", "Too slow!", "OK, OK... you go first!", "Ha! AGAIN!"]
	lines.append_array(Dance.SHOUTS)
	var worst := INF
	for text: String in lines:
		var words := text.split(" ", false).size()
		var need: float = D.READ_BASE + D.READ_PER_WORD * words
		var lived: float = await _life(lvl, text, 1.2)
		worst = minf(worst, lived - need)
		T.check(lived >= need - 0.05, "'%s' (%d words) stays readable %.1f s (needs %.1f s)" % [text, words, lived, need])
	var long_asked: float = await _life(lvl, "WOOO!", 5.0) # a real one-word line (a crowd shout)
	T.check(long_asked >= 4.9, "a caller asking for longer keeps its time (%.1f s of 5.0)" % long_asked)
	print("INFO  %d bubble lines checked; smallest margin over the reading time %.2f s" % [lines.size(), worst])
	lvl.queue_free()
	await process_frame
	T.finish(self)
