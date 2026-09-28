extends SceneTree
## Stage 6 SOUND slice 0 (SPEC Round 3): every player action is HEARD.
## (1) Loudness: each action's sound event peaks at -12 dB or louder (tools/sound_levels.py: the loudest file's peak + the event's db,
##     capped by max_db; both channels). Before Stage 6 the wipe, tear, mop and swim were -19 to -14 dB.
## (2) Walking and running sound different (C1 cartoon steps: running = its own faster, louder squeak set): 1.5 s of walking makes only
##     `step`, 1.5 s of running only `run_step`, 3 repeats each.
## The other new events (poop blast, OOFs, groans, gibberish, background bed) are checked where they are wired (test_audio, test_fight,
## test_ambience).
const T := preload("res://tests/t.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Progress := preload("res://scripts/progress.gd")
const ACTIONS := ["punch_hit", "heavy_hit", "kick", "step", "run_step", "wipe", "tear", "mop", "swim", "poop_blast", "oof", "oof_pushy",
	"oof_sneaky", "oof_bossy", "bob_ouch", "bob_groan", "bob_groan_bad", "bob_groan_desperate"]


func _levels() -> void:
	var out := []
	var code := OS.execute("python", PackedStringArray([ProjectSettings.globalize_path("res://tools/sound_levels.py"), "--check"] + ACTIONS), out, true)
	T.check(code != -1, "python ran tools/sound_levels.py (exit %d)" % code)
	var lines: PackedStringArray = "".join(out).strip_edges().split("\n")
	var seen := 0
	for line in lines:
		var l := line.strip_edges()
		if l.begins_with("ok") or l.begins_with("QUIET") or l.begins_with("MISSING"):
			seen += 1
			T.check(l.begins_with("ok"), "loud enough (>= -12 dB): %s" % l)
	T.check(seen == ACTIONS.size(), "every action measured (%d of %d)" % [seen, ACTIONS.size()])


## Stage 6b (owner playtest 2026-09-28, answers A-C): normal footsteps again, running = the SAME steps faster and louder; Bob's poop blast
## clearly loud (it fired but measured -16.7/-18.8 LUFS, 3D at -2 dB, dull: quieter than a footstep in a windowed recording,
## tests/probe_poop_sound.gd); the swim stroke a REAL recorded CC0 splash; the background bed +6 dB.
func _stage6b() -> void:
	var ev := Sfx.events()
	var step: Dictionary = ev["step"]
	var run: Dictionary = ev["run_step"]
	var squeaky := 0
	for f: String in step["files"] + run["files"]:
		squeaky += int(f.contains("squeak"))
	T.check(squeaky == 0, "6b A: no squeaky step files (%d)" % squeaky)
	T.check(step["files"] == run["files"], "6b A: running plays the same footsteps as walking")
	T.check(float(run.get("pitch_base", 1.0)) >= 1.2 and float(step.get("pitch_base", 1.0)) == 1.0,
		"6b A: running is pitched up (x%.2f), walking is not" % float(run.get("pitch_base", 1.0)))
	T.check(float(run["db"]) >= float(step["db"]) + 3.0 and float(run.get("max_db", 0.0)) >= float(step.get("max_db", 0.0)) + 3.0,
		"6b A: running is at least 3 dB louder (db %.0f vs %.0f, max_db %.0f vs %.0f)" % [run["db"], step["db"], run.get("max_db", 0.0), step.get("max_db", 0.0)])
	var blast: Dictionary = ev["poop_blast"]
	T.check(not blast.has("range"), "6b poop: the blast is Bob's own sound, 2D (not 3D from the seat)")
	var out := []
	OS.execute("python", PackedStringArray([ProjectSettings.globalize_path("res://tools/sound_levels.py"), "--lufs"] + blast["files"]), out, true)
	var lines := 0
	for line in "".join(out).strip_edges().split("\n"):
		if line.begins_with("LUFS"):
			lines += 1
			var lufs := float(line.split(" ")[1])
			# -15: louder than the ghost's fart (-13.8 LUFS at -3 = -16.8), the loudest body sound the owner has heard. At 0 dB it
			# peaked 0.0 dB in 3 of 3 windowed sequences, so it plays at -3.
			T.check(lufs + float(blast["db"]) >= -15.0, "6b poop: blast loudness %.1f LUFS + %.0f dB >= -15 (the ghost's fart: -16.8): %s" % [lufs, blast["db"], line])
	T.check(lines == blast["files"].size(), "6b poop: every blast file measured (%d)" % lines)
	var swim_made := 0
	for f: String in ev["swim"]["files"]:
		swim_made += int(f.contains("stroke_"))
	T.check(swim_made == 0 and ev["swim"]["files"].size() >= 3, "6b C: the swim stroke uses recorded CC0 splashes (%s)" % [ev["swim"]["files"]])
	T.check(float(ev["amb_bed"]["db"]) >= -7.0, "6b B: the background bed is +6 dB (db %.0f, was -13)" % ev["amb_bed"]["db"])


func _move(p: CharacterBody3D, run: bool) -> Array[int]:
	p.global_position = Vector3(3.0, 0.05, -5.2) # corridor B, nobody near (test_audio's walk spot)
	p.set_facing(-PI / 2.0)
	await T.wait(self, 0.8)
	Sfx.played.clear()
	if run:
		Input.action_press("sprint")
	Input.action_press("move_forward")
	await T.wait(self, 1.5)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await T.wait(self, 0.3)
	return [Sfx.count("step"), Sfx.count("run_step")]


func _init() -> void:
	seed(1)
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	_levels()
	_stage6b()
	var p: CharacterBody3D = lvl.player
	for i in 3:
		var w: Array[int] = await _move(p, false)
		T.check(w[0] >= 4 and w[1] == 0, "walk %d: only walking steps (step %d, run_step %d)" % [i + 1, w[0], w[1]])
		var r: Array[int] = await _move(p, true)
		T.check(r[1] >= 4 and r[0] == 0, "run %d: only running steps (step %d, run_step %d)" % [i + 1, r[0], r[1]])
	lvl.queue_free()
	await process_frame
	T.finish(self)
