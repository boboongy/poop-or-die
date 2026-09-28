extends SceneTree
## Level 2 "The flood": EVERY instance of the tasks, with real key presses (skill 3.4). `-- row1` = stalls 0-9, `-- row2` = stalls 10-19.
## For each clogged stall: the red plunger floats outside it (E picks it up), HOLD E at the toilet unclogs it (shallow water for even
## stalls, deep 1.6 m water for odd ones: then Bob dives, the camera goes under and both come back up), E at each of its 4 running taps
## turns it off (the 4 sinks rotate so every sink 1-10 is used in both depths), then E at the drain empties the room, 4 leftover puddles
## appear (one outside that stall) and the mop waits by the drain. Every frame: Bob never below the floor, never under water unless diving.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const FloodStory := preload("res://scripts/flood_story.gd")

var _lowest := 0.0
var _under_seen := false
var _under_frames := 0
var _bad_frames := 0
var _bad_note := ""
var _dive_frames := 0 ## frames deep in a dive (the clip check ran)


func _sample(lvl: Node) -> void:
	var p: CharacterBody3D = lvl.player
	var w: Node3D = lvl.water
	_lowest = minf(_lowest, p.global_position.y)
	if w.is_camera_under() and w.depth - get_root().get_camera_3d().global_position.y > 0.2:
		_under_seen = true # really under, not grazing the surface (the first windowed look showed the dive camera AT the surface)
		_under_frames += 1
	# the camera may only be under water during a dive
	var cam := get_root().get_camera_3d()
	if cam != null and not p.diving and cam.global_position.y < w.depth - 0.02 and w.depth > 0.5:
		_bad_frames += 1
		_bad_note = "camera %.2f under the surface %.2f (Bob y %.2f busy %s arm %.2f pitch %.2f, frame %d)" % [cam.global_position.y, w.depth,
			p.global_position.y, p.busy, (p.get_node("CameraPivot/SpringArm3D") as SpringArm3D).spring_length, p.get_node("CameraPivot").rotation.x, Engine.get_physics_frames()]
	if p.global_position.y < -0.05:
		_bad_frames += 1
		_bad_note = "Bob at y %.2f, below the floor" % p.global_position.y
	# deep in a dive: the factory clips duck_dive -> swim_under, his body above the floor (not through it)
	if p.diving and p.global_position.y < w.surface_y() - p.FLOAT_DEPTH - 0.4:
		_dive_frames += 1
		var clip := T.clip_of(p.model())
		var lowest := minf(T.bone_at(p.model(), "DEF-hand.R").y, T.bone_at(p.model(), "DEF-spine").y)
		var ok_clips: Array = ["swim"] if p._surfacing else ["duck_dive", "swim_under"] # coming up: the 0.4 s cross-fade back to swim
		if not clip in ok_clips or lowest < -0.05:
			_bad_frames += 1
			_bad_note = "diving: clip %s, lowest of hand/hips %.2f" % [clip, lowest]


func _wait_sampling(lvl: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		_sample(lvl)
		t += 1.0 / 60.0


func _place(lvl: Node, at: Vector3, face: Vector3) -> void:
	var p: CharacterBody3D = lvl.player
	var y := 0.05
	if lvl.water.depth > p.FLOAT_DEPTH:
		y = lvl.water.depth - p.FLOAT_DEPTH
	p.global_position = Vector3(at.x, y, at.z)
	p.face_direction(face)
	await _wait_sampling(lvl, 0.3)


func _one(stall: int) -> void:
	var i := stall % 10
	var sinks: Array[int] = [i + 1, (i + 3) % 10 + 1, (i + 5) % 10 + 1, (i + 7) % 10 + 1]
	sinks.sort()
	FloodStory.force_stall = stall
	FloodStory.force_sinks = sinks
	var deep := stall % 2 == 1
	var lvl := T.level(self)
	await T.wait(self, 0.3)
	lvl._time_left = 100000.0
	var story: Node3D = lvl.flood_story
	var w: Node3D = lvl.water
	var p: CharacterBody3D = lvl.player
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var mm = lvl.get_node("MissionManager")
	var tag := "stall %d (row %d, %s)" % [stall % 10 + 1, 1 if stall < 10 else 2, "deep" if deep else "shallow"]
	_lowest = 0.0
	_under_seen = false
	_under_frames = 0
	_bad_frames = 0
	_dive_frames = 0
	# the taps: switched on now instead of waiting for the rampage (test_flood_water checks the rampage does it)
	for k in sinks:
		if not story.taps_on.has(k):
			story._tap_on(k)
	if deep:
		w.depth = w.MAX_DEPTH # a jump the game never makes (it rises 2.7 cm/s): put Bob at the surface too, or he rises for 0.5 s under it
		p.global_position.y = w.depth - p.FLOAT_DEPTH
	await _wait_sampling(lvl, 1.0)
	var door: Vector3 = story._door_floor
	var out: Vector3 = story._out
	# 1. the plunger
	await _place(lvl, door + out * 1.4, -out)
	var said_plunger := prompt.text
	await T.key(self, KEY_E)
	await _wait_sampling(lvl, 1.8)
	T.check(said_plunger == "E  pick up the plunger" and story.has_plunger and p.carrying != null and p.carrying.name == "Plunger",
		"%s: the plunger is picked up ('%s')" % [tag, said_plunger])
	# 2. plunge: in the doorway, facing the toilet, hold E
	await _place(lvl, door - out * 0.25, -out)
	var said_toilet := prompt.text
	if stall == 0 or stall == 10:
		print("INFO  %s: Bob in the doorway is %.2f m from the toilet spot" % [tag, Vector2(p.global_position.x - story._toilet_spot.point.x, p.global_position.z - story._toilet_spot.point.z).length()])
	await T.key_down(self, KEY_E)
	await _wait_sampling(lvl, story.PLUNGE_SECONDS + (story.DIVE_DOWN if deep else 0.0) + 0.4)
	await T.key_up(self, KEY_E)
	await _wait_sampling(lvl, 0.8)
	T.check(said_toilet == "E (hold)  plunge the toilet" and not story.clogged and not w.is_running("toilet") and p.carrying == null and not p.busy and not p.diving,
		"%s: holding E unclogs the toilet ('%s', clogged %s, busy %s)" % [tag, said_toilet, story.clogged, p.busy])
	if deep:
		T.check(_lowest < 0.3 and _under_seen and _under_frames >= 60, "%s: Bob dived (lowest y %.2f) and the camera was at least 0.2 m under for %d frames (>= 60)" % [tag, _lowest, _under_frames])
		T.check(p.global_position.y > w.depth - p.FLOAT_DEPTH - 0.1, "%s: and he came back up to the surface (y %.2f)" % [tag, p.global_position.y])
	T.check(mm.is_done("plunge"), "%s: 'unclog the toilet' done" % tag)
	# 3. the taps
	for k in sinks:
		var x: float = story._tap_point(k).x
		await _place(lvl, Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
		var said_tap := prompt.text
		await T.key(self, KEY_E)
		await _wait_sampling(lvl, story.TAP_SECONDS + (story.DIVE_DOWN + story.DIVE_UP if deep else 0.0) + 0.4)
		T.check(said_tap == "E  turn off the tap" and not story.taps_on.has(k) and not w.is_running("sink%d" % k) and not lvl.get_node("Sinks")._streams[k - 1].visible,
			"%s: sink %d's tap is turned off ('%s')" % [tag, k, said_tap])
	T.check(w.running_count() == 0 and mm.is_done("taps"), "%s: nothing runs any more, 'turn off the taps' done" % tag)
	# 4. the plug
	await _place(lvl, story.DRAIN_POS + Vector3(0.7, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
	var said_plug := prompt.text
	await T.key(self, KEY_E)
	await _wait_sampling(lvl, 0.6 + (story.DIVE_DOWN + story.DIVE_UP if deep else 0.0) + 0.3)
	T.check(said_plug == "E  pull the plug" and story.plug_out and w.draining, "%s: the plug comes out ('%s')" % [tag, said_plug])
	await _wait_sampling(lvl, w.DRAIN_SECONDS + 1.0)
	T.check(story.is_drained and w.depth == 0.0 and mm.is_done("plug"), "%s: the room drained, 'pull the plug' done" % tag)
	await _wait_sampling(lvl, 1.0)
	T.check(p.is_on_floor() and absf(p.global_position.y) < 0.1, "%s: Bob stands on the floor again (y %.2f)" % [tag, p.global_position.y])
	# 5. what is left
	var wet_ok := true
	for f in story.residue:
		if f.wet_cells() < 8:
			wet_ok = false
	T.check(story.residue.size() == 4 and wet_ok, "%s: 4 leftover puddles, each wet (%s)" % [tag, lvl.puddle_text()])
	var first: Node3D = story.residue[0]
	T.check(Vector2(first.source.x - door.x, first.source.z - door.z).length() < 1.2 and first.wetness_at(door + out * 0.9) > 0.9,
		"%s: one lies just outside the stall" % tag)
	var prop: Node3D = mm.mission("find_mop")._prop
	T.check(prop != null and prop.global_position.distance_to(story.MOP_POS) < 0.2, "%s: the mop waits by the drain" % tag)
	T.check(_bad_frames == 0, "%s: every frame Bob stayed above the floor and the camera above water outside dives (%d bad: %s)" % [tag, _bad_frames, _bad_note])
	if deep:
		T.check(_dive_frames >= 60, "%s: the dive clips were checked on %d frames deep in the dives (>= 60)" % [tag, _dive_frames])
	lvl.queue_free()
	await T.wait(self, 0.2)


func _init() -> void:
	seed(11)
	Progress.level = T.FLOOD_LEVEL
	var args := OS.get_cmdline_user_args()
	var first := 10 if args.has("row2") else 0
	for s in range(first, first + 10):
		if args.has("only=%d" % s) or not Array(args).any(func(a: String) -> bool: return a.begins_with("only=")):
			await _one(s)
	FloodStory.force_stall = -1
	FloodStory.force_sinks = []
	T.finish(self)
