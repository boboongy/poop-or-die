extends SceneTree
## Spoken voices (SPEC "Round 2" Stage 2, owner 2026-09-27 "yes to all": Piper voices for every line, a voice per character, Bob speaks
## the reply the player picks). Files: audio/voices/<cast>/<md5 10>.ogg made by tools/make_voices.py; dialogue.gd finds them by the same
## name. Checks: (1) every file in the manifest loads and its name is the game's own hash of its text; (2) the lines the game can say,
## read from the GAME's constants (not from the tool), each have a voice for the cast that says them; (3) playback: a talk-box line plays
## its voice, Bob's picked reply plays in Bob's voice and the NPC's next line WAITS for it, E cuts a voice, a bubble plays a 3D voice
## on the NPC and lasts at least as long as it; generic Jijios keep one voice each and the queue uses more than one.
## Every other test also checks coverage: dialogue.gd prints VOICE MISSING and run.sh fails that test.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Walkers := preload("res://scripts/walkers.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")
const Dance := preload("res://scripts/dance.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Intro := preload("res://scripts/intro.gd")
const Finesse := preload("res://scripts/missions/finesse_queue.gd")
const Flood := preload("res://scripts/flood.gd")


func _has_voice(cast: String, text: String) -> bool:
	return ResourceLoader.exists(Dialogue.voice_path(cast, text))


func _check_lines(label: String, casts: Array, lines: Array) -> void:
	var missing: Array[String] = []
	for c: String in casts:
		for text: String in lines:
			if not _has_voice(c, text):
				missing.append("%s: %s" % [c, text])
	T.check(missing.is_empty(), "%s: %d lines x %d voices all have a file %s" % [label, lines.size(), casts.size(), "" if missing.is_empty() else str(missing)])


func _init() -> void:
	seed(3)
	# (1) the manifest
	var f := FileAccess.open("res://audio/voices/manifest.json", FileAccess.READ)
	T.check(f != null, "audio/voices/manifest.json exists")
	var manifest: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	var total := 0
	var bad: Array[String] = []
	var too_long := 0.0
	for cast: String in manifest:
		for k: String in manifest[cast]:
			total += 1
			var entry: Dictionary = manifest[cast][k]
			var text: String = entry["text"]
			var path := Dialogue.voice_path(cast, text)
			var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
			if stream == null or not path.ends_with(k + ".ogg") or absf(stream.get_length() - float(entry["seconds"])) > 0.15:
				bad.append("%s %s" % [cast, k])
			too_long = maxf(too_long, float(entry["seconds"]))
	T.check(total > 150 and bad.is_empty(), "%d voice files load, their names match the game's hash and their lengths the manifest %s" % [total, "" if bad.is_empty() else str(bad)])
	for c: String in Dialogue.JIJIO_CASTS + Dialogue.CAST_OF_WHO.values():
		T.check(manifest.has(c) and (manifest[c] as Dictionary).size() > 0, "cast '%s' has voice files" % c)
	print("INFO  %d voice files, longest %.1f s" % [total, too_long])
	var strays: Array[String] = []
	for c: String in DirAccess.get_directories_at("res://audio/voices"):
		for file: String in DirAccess.get_files_at("res://audio/voices/" + c):
			if file.ends_with(".ogg") and not (manifest.get(c, {}) as Dictionary).has(file.get_basename()):
				strays.append(c + "/" + file)
	T.check(strays.is_empty(), "no voice file on disk is missing from the manifest %s" % str(strays))

	# (2) coverage from the game's own constants
	var generic: Array = Dialogue.JIJIO_CASTS
	var chatter: Array = []
	for job: String in Walkers.CHATTER:
		chatter.append_array(Walkers.CHATTER[job])
	_check_lines("walker chatter", generic, chatter)
	var hints: Array = []
	for n in range(1, 6):
		var h: String = LevelDefs.get_level(n).get("walker_hint", "")
		if h != "":
			hints.append(h)
	_check_lines("walker hints of %d levels" % hints.size(), generic, hints)
	_check_lines("dance crowd shouts", generic, Dance.SHOUTS)
	_check_lines("SHUFFLE QUEEN's bubbles", ["queen"], ["Not here! WAITING ROOM, everybody!", "Too slow!", "OK, OK... you go first!", "Ha! AGAIN!"])
	_check_lines("finesse talk", generic, Finesse.REBUTTALS)
	_check_lines("Bob's finesse replies", ["bob"], Finesse.REPLIES)
	_check_lines("flood complaints", generic, Flood.COMPLAINTS)
	_check_lines("ghost intro (as a Jijio)", generic, Intro.GHOST_REBUTTALS)
	_check_lines("Bob's ghost replies", ["bob"], Intro.GHOST_REPLIES)
	for def: Dictionary in Cutters.DEFS:
		var c: String = Dialogue.CAST_OF_WHO[def["name"]]
		_check_lines("cutter %s" % def["name"], [c], [def["open"], def["retort"]])
		_check_lines("Bob's replies to %s" % def["name"], ["bob"], def["replies"])
	_check_lines("tissue asker, all 20 stalls", generic, _tissue_lines())

	# (3) playback in a real level
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var d = lvl.dialogue
	var p: CharacterBody3D = lvl.player
	var npc: Node3D = lvl.population.queue[0]
	var cast := Dialogue.cast_for(npc, "Jijio")
	T.check(cast in generic and Dialogue.cast_for(npc, "Jijio") == cast, "a generic Jijio keeps one voice (%s)" % cast)
	var used := {}
	for q: Node3D in lvl.population.queue:
		used[Dialogue.cast_for(q, "Jijio")] = true
	T.check(used.size() >= 2, "the queue speaks with %d different voices" % used.size())
	T.check(Dialogue.cast_for(npc, "GHOST") == "ghost" and Dialogue.cast_for(npc, "SHUFFLE QUEEN") == "queen" and Dialogue.cast_for(null, "Bob") == "bob", "named speakers get their own voice")

	var line: String = Finesse.REBUTTALS[0]
	d.begin(npc, p)
	d.say(npc, line)
	await T.wait(self, 0.1)
	T.check(d.voice_playing == Dialogue.voice_path(cast, line), "a talk-box line plays its voice (%s)" % d.voice_playing)
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	T.check(d.voice_playing == "", "E cuts the voice of the line it closes")

	var pick_box := [-1]
	var ask := func() -> void: pick_box[0] = await d.choose(npc, "What do you want? I'm not letting anybody in front of me.", Finesse.REPLIES)
	ask.call()
	await T.wait(self, 0.2)
	await T.key(self, KEY_2)
	await T.wait(self, 0.05)
	var bob_path := Dialogue.voice_path("bob", Finesse.REPLIES[1])
	T.check(pick_box[0] == 1 and d.voice_playing == bob_path, "Bob says the reply picked with 2 in his voice (%s)" % d.voice_playing)
	var bob_len: float = (load(bob_path) as AudioStream).get_length()
	d.say(npc, Finesse.REBUTTALS[1])
	await T.wait(self, 0.2)
	T.check(d.voice_playing == bob_path, "the NPC's answer waits while Bob is still speaking (%.1f s reply)" % bob_len)
	await T.wait(self, bob_len)
	T.check(d.voice_playing == Dialogue.voice_path(cast, Finesse.REBUTTALS[1]), "then the NPC's answer is spoken (%s)" % d.voice_playing)
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	d.end(npc, p)

	# a bubble: a 3D voice on the NPC, and the bubble lasts at least as long as the voice
	var shout := "Hey! Somebody's in here with me!"
	var voice_len: float = (load(Dialogue.voice_path(cast, shout)) as AudioStream).get_length()
	d.bubble(npc, shout, 0.5)
	await T.wait(self, 0.1)
	var player3d: AudioStreamPlayer3D = null
	var label: Label3D = null
	for c in npc.get_children():
		if c is AudioStreamPlayer3D and (c as AudioStreamPlayer3D).stream and (c as AudioStreamPlayer3D).stream.resource_path == Dialogue.voice_path(cast, shout):
			player3d = c
		if c is Label3D and (c as Label3D).text == shout:
			label = c
	T.check(player3d != null, "a bubble plays its voice from the NPC (3D)")
	var lived := 0.1
	while is_instance_valid(label) and label.modulate.a > 0.5 and lived < 20.0:
		await physics_frame
		lived += 1.0 / 60.0
	T.check(lived >= voice_len, "the bubble stays up while its voice speaks (%.1f s, voice %.1f s)" % [lived, voice_len])

	T.check(Dialogue.missing.is_empty(), "no line in this test was missing a voice %s" % str(Dialogue.missing))
	lvl.queue_free()
	await process_frame
	T.finish(self)


func _tissue_lines() -> Array:
	var out: Array = []
	for index in 20:
		var number := index % 10 + 1
		var row_name := "first row (along the corridor you walk in from)" if index < 10 else "back row (the corridor behind the stalls)"
		out.append("Ugh, that knocking again... The person in the %s, stall number %d from the entrance, has run out of tissue!" % [row_name, number])
	return out
