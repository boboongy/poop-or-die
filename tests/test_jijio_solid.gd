extends SceneTree
## Stage 6c A (owner playtest 2026-09-28, DECIDED): Jijios are always solid, Bob NEVER walks through them; one that blocks him is
## pushed / steps aside so he never gets stuck. The worst case on purpose: walkers that stand still and never make way themselves
## (spawned by hand, the walker manager does not drive them): one in the middle of a corridor, then two side by side across it, in both
## 1.6 m corridors, Bob walking each way. Checked EVERY physics frame: Bob's capsule never overlaps a Jijio's (0.25 + 0.2 m, 0.05 m
## tolerance), he gets to the far end, and the pushed Jijios stay inside the corridor (not in a wall).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")

const MIN_GAP := 0.40 ## m between the two capsule axes: 0.25 (Bob) + 0.2 (Jijio) - 0.05 tolerance
const MAX_SECONDS := 12.0 ## the whole 9 m walk at 2-3 m/s takes about 4 s; pushing may slow him, never stop him

var _p: CharacterBody3D
var _blockers: Array[Node3D] = []
var _closest := INF
var _overlap_frames := 0


func _on_frame() -> void:
	if _p == null:
		return
	for w: Node3D in _blockers:
		if not is_instance_valid(w):
			continue
		var d := Vector2(w.global_position.x - _p.global_position.x, w.global_position.z - _p.global_position.z).length()
		_closest = minf(_closest, d)
		if d < MIN_GAP:
			if _overlap_frames == 0:
				print("INFO  first overlap: Bob's mask %d (3 = Jijios solid), Jijio layer %d" % [_p.collision_mask, w.collision_layer])
			_overlap_frames += 1


## How deep the Jijio's own capsule sits in the level (layer 1), horizontally, in metres.
func _wall_depth(w: CollisionObject3D) -> float:
	var cs := w.get_node("CollisionShape3D") as CollisionShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = 1
	q.exclude = [w.get_rid(), _p.get_rid()]
	var pts := w.get_world_3d().direct_space_state.collide_shape(q, 8)
	var deepest := 0.0
	for i in range(0, pts.size(), 2):
		var d: Vector3 = pts[i + 1] - pts[i]
		d.y = 0.0
		deepest = maxf(deepest, d.length())
	return deepest


func _init() -> void:
	seed(1)
	Progress.level = T.FLOOD_LEVEL
	T.dry = true # the corridors without the flood
	var cases := [
		# [name, corridor z band, blocker z list, east]
		["A one, east", Vector2(-0.55, 0.65), [0.05], true],
		["A two, east", Vector2(-0.55, 0.65), [-0.3, 0.4], true],
		["A two, west", Vector2(-0.55, 0.65), [-0.3, 0.4], false],
		["B one, west", Vector2(-5.95, -4.55), [-5.25], false],
		["B two, east", Vector2(-5.95, -4.55), [-5.7, -4.8], true],
		["B two, west", Vector2(-5.95, -4.55), [-5.7, -4.8], false],
	]
	physics_frame.connect(_on_frame)
	for c: Array in cases:
		var lvl := T.level(self)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		var band: Vector2 = c[1]
		var mid := (band.x + band.y) / 2.0
		var east: bool = c[3]
		_p = lvl.player
		_p.global_position = Vector3(1.6 if east else 10.8, 0.05, mid)
		_p.set_facing(-PI / 2.0 if east else PI / 2.0)
		_blockers.clear()
		for z: float in c[2]:
			var w: Node3D = lvl.population.spawn_walker(Vector3(6.0, 0.05, z), PI / 2.0 if east else -PI / 2.0)
			_blockers.append(w)
		await T.wait(self, 0.4)
		_closest = INF
		_overlap_frames = 0
		Input.action_press("move_forward")
		var t := 0.0
		var to_x := 10.5 if east else 1.6
		while t < MAX_SECONDS and ((east and _p.global_position.x < to_x) or (not east and _p.global_position.x > to_x)):
			await T.wait(self, 0.1)
			t += 0.1
		Input.action_release("move_forward")
		var reached := (east and _p.global_position.x >= to_x) or (not east and _p.global_position.x <= to_x)
		T.check(_closest < 0.8, "%s: the walk really met the Jijio(s) (closest %.2f m)" % [c[0], _closest])
		T.check(_overlap_frames == 0, "%s: Bob never overlaps a Jijio (closest %.2f m, need >= %.2f; %d frames inside)" % [c[0], _closest, MIN_GAP, _overlap_frames])
		T.check(reached, "%s: Bob got past in %.1f s (limit %.0f s), at x %.2f" % [c[0], t, MAX_SECONDS, _p.global_position.x])
		for w: Node3D in _blockers:
			var depth := _wall_depth(w)
			T.check(depth < 0.03, "%s: the pushed Jijio is not inside a wall (at %.2f, %.2f; %.3f m deep)" % [c[0], w.global_position.x, w.global_position.z, depth])
		_p = null
		lvl.queue_free()
		await T.wait(self, 0.3)
	T.finish(self)
