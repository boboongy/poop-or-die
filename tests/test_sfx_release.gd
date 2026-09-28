extends SceneTree
## Sound voices are given back. Owner run 2026-09-21: "Cannot convert argument 2 from Object to Object" from `Sfx._release` (the timer
## callback of a one-shot sound) appeared during play: something frees a sound player (the flush fades it out and frees it after 0.5 s)
## before the timer fires, and a typed `player: Node` parameter cannot take a freed object, so the callback never ran and the event's
## voice counter never went back down (after max_voices such sounds the event would stay silent).
## Every sound event, three ways: left alone (control), freed at once, faded out with `Sfx.fade_out` (what the flush does).
## Then, after the longest sound has ended, no event may still hold a voice and every event can be played again.
const T := preload("res://tests/t.gd")
const Sfx := preload("res://scripts/sfx.gd")


func _init() -> void:
	var anchor := Node3D.new()
	root.add_child(anchor)
	await process_frame
	var longest := 0.0
	var played: Array[Dictionary] = [] # {event, how, player}
	for event: String in Sfx.events():
		for f: String in Sfx.events()[event]["files"]:
			longest = maxf(longest, (load(Sfx.DIR + f) as AudioStream).get_length())
	# One round per way, so the same event is never asked for a second voice while its first is still playing.
	for how: String in ["control", "freed", "faded"]:
		played.clear()
		for event: String in Sfx.events():
			var p: Node = Sfx.play_at(anchor, event, Vector3.ZERO)
			T.check(p != null, "%s (%s): a voice was available" % [event, how])
			played.append({"event": event, "player": p})
		await process_frame
		for entry in played:
			var p = entry["player"]
			if p == null:
				continue
			if how == "freed":
				p.queue_free()
			elif how == "faded":
				Sfx.fade_out(p, 0.1)
		# Longest sound, at the lowest pitch the table can give (about x0.7 of the speed), plus the 0.3 s margin, plus slack.
		await T.wait(self, longest / 0.7 + 1.5)
		var stuck: Array[String] = []
		for event: String in Sfx.events():
			if int(Sfx._voices.get(event, 0)) != 0:
				stuck.append("%s=%d" % [event, int(Sfx._voices.get(event, 0))])
		T.check(stuck.is_empty(), "%s: after the sounds ended no event still holds a voice (stuck: %s)" % [how, ", ".join(stuck)])
	# Every event plays again (no voice was lost for good).
	for event: String in Sfx.events():
		var p: Node = Sfx.play_at(anchor, event, Vector3.ZERO)
		T.check(p != null, "%s: can be played again after all three rounds" % event)
	T.finish(self)
