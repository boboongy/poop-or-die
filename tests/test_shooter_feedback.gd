extends SceneTree
## Stage 4 "WATER WAR" slice 2 (SPEC "Stage 4 plan" (6), (9)): the hit feedback, real level, real mouse button. Checks: the hit marker (white
## body, red head, bigger on a kill, gone after 0.15 s), the damage number (12 white / 24 yellow, floats up about 0.5 m, gone after 0.6 s),
## the kill feed (killer, victim, [HEADSHOT], at most 4 entries, each gone after 4 s), a splash where every blob lands, and a sound for
## each event: shot, tick, ding, chime, splash, dry click.
## Run: timeout 180 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_shooter_feedback.gd
const T := preload("res://tests/t.gd")
const Shooter := preload("res://scripts/shooter.gd")
const Hud := preload("res://scripts/shooter_hud.gd")
const Sfx := preload("res://scripts/sfx.gd")

var sh: Node
var p: CharacterBody3D


func _aim(at: Vector3) -> void:
	var cam := p.get_viewport().get_camera_3d()
	var d := at - cam.global_position
	p.set_camera(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


## One shot at `at`; returns what the frames after the hit looked like: {"hit", "marker_color", "marker_scale", "number", "rise",
## "marker_gone_at", "number_gone_at"} (times in seconds after the hit; -1 = never within 1.5 s).
func _one_shot(at: Vector3, watch := true) -> Dictionary:
	_aim(at)
	var n: int = sh.hits.size()
	await T.left_down(self)
	await T.left_up(self)
	var r := {"hit": {}, "marker_color": Color.BLACK, "marker_scale": 0.0, "number": null, "rise": 0.0, "marker_gone_at": -1.0, "number_gone_at": -1.0}
	var waited := 0
	while sh.hits.size() == n and waited < 60:
		await physics_frame
		waited += 1
	if sh.hits.size() == n:
		return r
	r["hit"] = sh.hits[n]
	if not watch:
		return r
	await process_frame # the HUD draws in _process
	r["marker_color"] = sh.hud.marker.modulate
	r["marker_scale"] = sh.hud.marker.scale.x
	var lbl: Label3D = null if sh.numbers.is_empty() else sh.numbers[sh.numbers.size() - 1]
	r["number"] = lbl
	var y0: float = lbl.global_position.y if lbl else 0.0
	var number_text := lbl.text if lbl else ""
	var number_color := lbl.modulate if lbl else Color.BLACK
	r["number_text"] = number_text
	r["number_color"] = number_color
	for f in 90:
		await physics_frame
		var t := (f + 1) / 60.0
		if r["marker_gone_at"] < 0.0 and not sh.hud.marker.visible:
			r["marker_gone_at"] = t
		if is_instance_valid(lbl):
			r["rise"] = maxf(float(r["rise"]), lbl.global_position.y - y0)
		elif r["number_gone_at"] < 0.0:
			r["number_gone_at"] = t
	return r


func _feed_texts() -> Array:
	var out: Array = []
	for e in sh.hud.feed.get_children():
		if not e.is_queued_for_deletion():
			out.append(String(e.get_meta("text")))
	return out


func _init() -> void:
	seed(1)
	var lvl := T.level(self)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	p = lvl.player
	p.global_position = Vector3(2.0, 0.0, -0.5) # 1.37 m from the nearest tap: out of refill range (slice 4)
	p.face_direction(Vector3.RIGHT)
	await T.wait(self, 0.2)
	sh = Shooter.new()
	lvl.add_child(sh)
	sh.start(p)
	var crew = sh.spawn_crew("CREW 1", Vector3(8.0, 0.0, 0.3), -PI / 2.0)
	await T.wait(self, 0.5)

	# --- a body hit ---
	Sfx.played.clear()
	var r := await _one_shot(crew.body.global_position + Vector3.UP * 0.5)
	T.check(not r["hit"].is_empty() and not r["hit"]["head"], "a single shot at the chest hits the body")
	T.check((r["marker_color"] as Color).is_equal_approx(Hud.MARKER_BODY) and is_equal_approx(float(r["marker_scale"]), 1.0), "body: a white hit marker, normal size (%s x%.2f)" % [r["marker_color"], r["marker_scale"]])
	T.check(float(r["marker_gone_at"]) > 0.1 and float(r["marker_gone_at"]) <= 0.2, "the marker is gone %.2f s after the hit (0.15)" % r["marker_gone_at"])
	T.check(r["number_text"] == "12" and (r["number_color"] as Color).is_equal_approx(Hud.NUMBER_BODY), "a white 12 pops up (%s)" % r["number_text"])
	T.check(float(r["rise"]) > 0.35 and float(r["rise"]) < 0.6, "the number floats up %.2f m (0.5)" % r["rise"])
	T.check(float(r["number_gone_at"]) > 0.5 and float(r["number_gone_at"]) <= 0.75, "the number is gone %.2f s after the hit (0.6)" % r["number_gone_at"])
	T.check(Sfx.count("gun_shot") == 1 and Sfx.count("hit_tick") == 1 and Sfx.count("hit_ding") == 0, "sounds: 1 shot, 1 tick, no ding (%s)" % [Sfx.played])
	T.check(Sfx.count("blob_splash") == 1 and sh.splashes >= 1, "the blob splashes where it lands (sound %d, splashes %d)" % [Sfx.count("blob_splash"), sh.splashes])

	# --- a head hit ---
	Sfx.played.clear()
	r = await _one_shot(crew.head_center())
	T.check(not r["hit"].is_empty() and r["hit"]["head"], "a single shot at the head is a headshot")
	T.check((r["marker_color"] as Color).is_equal_approx(Hud.MARKER_HEAD), "head: a red hit marker (%s)" % r["marker_color"])
	T.check(r["number_text"] == "24" and (r["number_color"] as Color).is_equal_approx(Hud.NUMBER_HEAD), "a yellow 24 pops up (%s)" % r["number_text"])
	T.check(Sfx.count("hit_ding") == 1 and Sfx.count("hit_tick") == 0, "sounds: a ding, no tick (%s)" % [Sfx.played])
	T.check(_feed_texts().is_empty(), "no kill, no feed entry")

	# --- the kill (a headshot) ---
	crew.hp = 10.0
	Sfx.played.clear()
	r = await _one_shot(crew.head_center())
	T.check(crew.down and r["hit"].get("kill", false), "the last shot is the kill")
	T.check(float(r["marker_scale"]) >= 1.4 and (r["marker_color"] as Color).is_equal_approx(Hud.MARKER_HEAD), "kill: a BIGGER red marker (x%.2f)" % r["marker_scale"])
	T.check(Sfx.count("kill_chime") == 1, "a kill chime (%s)" % [Sfx.played])
	var feed := _feed_texts()
	T.check(feed.size() == 1 and String(feed[0]).begins_with("BOB") and String(feed[0]).contains("CREW 1") and String(feed[0]).contains("[HEADSHOT]"),
			"the kill feed: %s" % [feed])

	# --- a body-shot kill has no [HEADSHOT]; 5 kills keep only the newest 4; each leaves after 4 s ---
	var victims: Array = []
	for i in 5:
		var c = sh.spawn_crew("CREW %d" % (i + 2), Vector3(8.0, 0.0, 0.3), -PI / 2.0)
		victims.append(c)
	for c in victims: # all on one spot: the ones still up but not next are switched off for the shot
		c.hp = 5.0
		var e_down: Array = sh.enemies.filter(func(e) -> bool: return e != c and not e.down)
		for e in e_down:
			e.down = true # only this one takes the shot
		await _one_shot(c.body.global_position + Vector3.UP * 0.5, false) # quick: 5 kills well inside the 4 s an entry stays
		for e in e_down:
			e.down = false
	feed = _feed_texts()
	T.check(feed.size() == 4, "after 5 more kills the feed holds 4 (%d)" % feed.size())
	T.check(String(feed[feed.size() - 1]).contains("CREW 6") and not String(feed[0]).contains("CREW 1") and not String(feed[feed.size() - 1]).contains("HEADSHOT"),
			"newest last, the oldest dropped, a body kill has no [HEADSHOT]: %s" % [feed])
	await T.wait(self, Hud.FEED_SECONDS + 0.3)
	T.check(_feed_texts().is_empty(), "every entry is gone %.0f s after it came" % Hud.FEED_SECONDS)

	# --- a burst: every shot has its sound; every blob that lands splashes ---
	Sfx.played.clear()
	var s0: int = sh.shots_fired
	var w0: int = sh.wall_hits
	var sp0: int = sh.splashes
	_aim(Vector3(12.6, 1.8, 0.3))
	await T.left_down(self)
	await T.wait(self, 2.0)
	await T.left_up(self)
	await T.wait(self, 0.6)
	var fired: int = sh.shots_fired - s0
	T.check(fired >= 16 and Sfx.count("gun_shot") == fired, "2 s of fire: %d shots, %d shot sounds" % [fired, Sfx.count("gun_shot")])
	T.check(sh.wall_hits - w0 == fired and sh.splashes - sp0 == fired, "every one of the %d blobs splashed on the wall (%d)" % [fired, sh.splashes - sp0])
	T.check(Sfx.count("blob_splash") >= 4, "splash sounds (at most 4 at once): %d" % Sfx.count("blob_splash"))

	# --- the dry click has its sound ---
	sh.tank = 0
	Sfx.played.clear()
	await T.left_down(self)
	await T.wait(self, 0.2)
	await T.left_up(self)
	T.check(Sfx.count("dry_click") == 1 and Sfx.count("gun_shot") == 0, "empty: one dry-click sound, no shot sound (%s)" % [Sfx.played])

	sh.abort()
	await T.wait(self, 0.2)
	T.check(sh.numbers.is_empty(), "abort clears the damage numbers")
	lvl.queue_free()
	await process_frame
	T.finish(self)
