extends SceneTree
## Stage 6c (B), owner 2026-09-28 screenshot: Jijios of the kick-out crowd stuck in the walls (the flood level).
## In EVERY level (1-5), walkers on: 20 s of normal play, then the timeout kick-out from three spots, 8 s each. On EVERY physics
## frame, every visible Jijio's head and chest bones are checked against the solid level geometry (layer 1, characters excluded):
## none may stay in it STUCK_FRAMES frames in a row (shorter touches are counted and printed).
## Then the flood level with the water forced deep (1.2 m): 15 s of swimming, and the kick-out from the three spots.
## Prints per case: frames, bone samples, stuck and touching Jijio-frames, the first few with the collider's name.
## Run: timeout 470 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_jijio_walls.gd [-- levels=3]
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const NPC := preload("res://scripts/npc_jijio.gd")

const SPOTS := {"spawn": Vector3(-3.7, 0.05, 0.4), "corridor B": Vector3(3.0, 0.05, -5.2), "far east": Vector3(11.0, 0.05, -2.5)}
const BONES := ["DEF-spine.006", "DEF-spine.003"] # head, chest
const RADIUS := 0.08
## 0.1 s: shorter touches are counted, not failed: the guard in npc_jijio.gd pushes a Jijio out on its next step, but a stall door
## swinging open at the kick-out (a tween, it pushes nobody) can pass through a Jijio running past for 3-4 frames (2 of 72 cases).
const STUCK_FRAMES := 6
var total_touches := 0

var lvl: Node
var watching := false
var frames := 0
var samples := 0
var touches := 0 ## Jijio-frames with the head or chest in the level (a door leaf swinging through, a turn into a wall: fixed next step)
var stuck := 0 ## Jijio-frames that were the STUCK_FRAMES-th or later in a row: what the owner sees as "stuck in a wall"
var _streak := {}
var examples: Array[String] = []
var by_state := {}
var _prev := {} ## each Jijio's state and position on the frame before (what it was doing before it met the wall)
var _npcs: Array[CharacterBody3D] = []
var _refresh := 0
var _sphere := SphereShape3D.new()


func _on_frame() -> void:
	if not watching or lvl == null or not is_instance_valid(lvl):
		return
	frames += 1
	_refresh -= 1
	if _refresh <= 0:
		_refresh = 30
		_npcs.clear()
		for n in lvl.find_children("*", "CharacterBody3D", true, false):
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("npc_jijio.gd"):
				_npcs.append(n)
	var p: CharacterBody3D = lvl.player
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var skip: Array[RID] = [p.get_rid()]
	for n in _npcs:
		if is_instance_valid(n):
			skip.append(n.get_rid())
	for n in _npcs:
		if not is_instance_valid(n) or not n.is_visible_in_tree() or (n.state == NPC.State.SIT and not n.floating):
			continue # a seated occupant's body is inside the toilet's collision box by design
		var in_wall := false
		for bone: String in BONES:
			var at := T.bone_at(n._model, bone)
			samples += 1
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = _sphere
			q.transform = Transform3D(Basis(), at)
			q.collision_mask = 1
			q.exclude = skip
			var hits := space.intersect_shape(q, 1)
			if hits.is_empty() or in_wall:
				continue
			in_wall = true
			touches += 1
			var streak: int = _streak.get(n, 0) + 1
			if streak >= STUCK_FRAMES:
				stuck += 1
				var key := "state %d%s" % [n.state, " floating" if n.floating else ""]
				by_state[key] = by_state.get(key, 0) + 1
				if examples.size() < 6:
					var c: Object = hits[0].collider
					var off := Vector2(at.x - n.global_position.x, at.z - n.global_position.z).length()
					examples.append("%s %s %s (was %s) %.2f m off the capsule centre, at %s in %s" % [n.name, bone, key, _prev.get(n, "?"), off, at, c.get_parent().name + "/" + c.name if c is Node else str(c)])
		_streak[n] = _streak.get(n, 0) + 1 if in_wall else 0
	for n in _npcs:
		if is_instance_valid(n):
			_prev[n] = "state %d at %s" % [n.state, n.global_position.snappedf(0.01)]


func _levels() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("levels="):
			return int(a.substr(7))
	return 5


func _reset() -> void:
	frames = 0
	samples = 0
	touches = 0
	stuck = 0
	_streak.clear()
	examples.clear()
	by_state.clear()
	_refresh = 0


func _report(tag: String) -> void:
	T.check(frames > 100 and samples > 0 and stuck == 0, "%s: no Jijio in a wall for %d+ frames in a row (%d frames, %d bone samples; %d stuck Jijio-frames %s; %d Jijio-frames touching in all) %s" % [tag, STUCK_FRAMES, frames, samples, stuck, by_state, touches, "; ".join(examples)])
	total_touches += touches


func _init() -> void:
	_sphere.radius = RADIUS
	physics_frame.connect(_on_frame)
	for level in range(1, _levels() + 1):
		# Normal play: the walkers, the queue, the level's own story (the flood rises, the seekers, the cutters).
		Progress.level = level
		lvl = T.level(self, true)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		_reset()
		watching = true
		await T.wait(self, 20.0)
		watching = false
		_report("level %d normal play" % level)
		lvl.queue_free()
		await T.wait(self, 0.1)
		# The kick-out from three spots.
		for label: String in SPOTS:
			Progress.level = level
			lvl = T.level(self, true)
			await T.wait(self, 0.8)
			lvl.player.global_position = SPOTS[label]
			await T.wait(self, 0.2)
			_reset()
			watching = true
			lvl._time_left = 0.05
			await T.wait(self, 8.0)
			watching = false
			_report("level %d kick-out, Bob at %s" % [level, label])
			lvl.queue_free()
			await T.wait(self, 0.1)
	# The flood level in DEEP water (the owner's screenshot): everyone swims, then the kick-out swims to Bob.
	for label: String in ["swimming"] + SPOTS.keys():
		Progress.level = T.FLOOD_LEVEL
		lvl = T.level(self, true)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		lvl.water.depth = 1.2
		await T.wait(self, 1.0)
		_reset()
		watching = true
		if label == "swimming":
			await T.wait(self, 15.0)
		else:
			lvl.player.global_position = SPOTS[label] + Vector3.UP * 1.0
			lvl._time_left = 0.05
			await T.wait(self, 8.0)
		watching = false
		_report("flood level, deep water, %s" % (label if label == "swimming" else "kick-out, Bob at " + label))
		lvl.queue_free()
		await T.wait(self, 0.1)
	Progress.level = 1
	print("INFO  Jijio-frames touching the level over all cases (incl. stuck ones): %d" % total_touches)
	T.finish(self)
