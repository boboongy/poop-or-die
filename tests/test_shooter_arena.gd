extends SceneTree
## Stage 4 "WATER WAR" slice 4 (SPEC "Stage 4 plan" (2), (3), (4)): the arena and BOSSY's phase, in the real level with walkers.
## Stacks: all 4 solid where STACKS says, 1.0 m high, at least 0.9 m free beside each, never touched by any cover-to-cover walk (all 30,
## a 0.25 m body), and from Bob's approach they hide the chest at their hide spot while the head shows. The invisible wall at x 1.2
## stops Bob but not blobs or sight; corridor B's west end is closed too. Every stall door shut during the fight and back after; the
## walkers hidden and back after; no enemy offers "E talk". Refill at ALL 10 sinks: empty to full in 1.5 s +- 1 frame at 0.95 m, the
## refill sound, EMPTY gone; none 1.5 m out. BOSSY for all 3 "which 2 crew go down" orders: never after 1, at once after 2, her numbers,
## orange, the hidden corner, she walks to cover and stays in the arena; never twice, never without the squad.
## Run: timeout 400 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_shooter_arena.gd
const T := preload("res://tests/t.gd")
const Shooter := preload("res://scripts/shooter.gd")
const Enemy := preload("res://scripts/shooter_enemy.gd")
const Sinks := preload("res://scripts/sinks.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Sfx := preload("res://scripts/sfx.gd")

const BODY_R := 0.25 ## a Jijio's collision radius (npc_jijio.tscn)
const OPEN_SIDE: Array[Vector3] = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)] ## each stack's free side
const STACK_COVER := [0, 2, 3, 5]

var lvl: Node
var sh: Node
var p: CharacterBody3D
var watching := false
var frames := 0
var outside := 0
var talkers := 0
var first_bad := ""


func _on_frame() -> void:
	if not watching or sh == null or not is_instance_valid(sh):
		return
	frames += 1
	sh.bob_hp = Shooter.BOB_HP # nobody is K.O.'d here: this test is about the arena
	if p._focus != null or not get_nodes_in_group("interactable").is_empty():
		talkers += 1
	for e in sh.enemies:
		if e.down:
			continue
		var at: Vector3 = e.body.global_position
		var inside := false
		for b: Array in Shooter.ARENA_BOXES:
			if at.x >= b[0] + 0.15 and at.x <= b[1] - 0.15 and at.z >= b[2] + 0.15 and at.z <= b[3] - 0.15:
				inside = true
		if not inside:
			outside += 1
			if first_bad == "":
				first_bad = "%s at %s" % [e.name, at]


func _ray(from: Vector3, to: Vector3, mask := 1) -> Dictionary:
	return p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, [p.get_rid()]))


## Flat distance from p to the rectangle [x0, x1, z0, z1].
static func _rect_dist(p2: Vector2, r: Array) -> float:
	var dx := maxf(maxf(r[0] - p2.x, 0.0), p2.x - r[1])
	var dz := maxf(maxf(r[2] - p2.y, 0.0), p2.y - r[3])
	return Vector2(dx, dz).length()


## The point `s` metres along the U.
static func _u_point(s: float) -> Vector3:
	var left := s
	for i in Shooter.U_PATH.size() - 1:
		var a: Vector3 = Shooter.U_PATH[i]
		var b: Vector3 = Shooter.U_PATH[i + 1]
		if left <= a.distance_to(b):
			return a + (b - a).normalized() * maxf(left, 0.0)
		left -= a.distance_to(b)
	return Shooter.U_PATH[Shooter.U_PATH.size() - 1]


func _stand(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	await T.wait(self, 0.1)


func _new_shooter() -> void:
	sh = Shooter.new()
	lvl.add_child(sh)
	sh.hide_nodes = [lvl.get_node("HUD/MissionLabel"), lvl.get_node("HUD/StatusLabel")]
	sh.start(p)


func _drop_shooter() -> void:
	watching = false
	sh.abort()
	for e in sh.enemies:
		if is_instance_valid(e.body):
			e.body.queue_free()
	sh.queue_free()
	await T.wait(self, 0.3)


func _init() -> void:
	seed(1)
	physics_frame.connect(_on_frame)
	lvl = T.level(self, true)
	await T.wait(self, 1.0)
	lvl._time_left = 100000.0
	p = lvl.player
	await _stand(Vector3(2.0, 0.0, -0.5))
	# two doors open before the fight (as in Level 4: the open stall)
	lvl.stalls.door_for(1, 3).set_open(true, 0.01)
	lvl.stalls.door_for(2, 7).set_open(true, 0.01)
	await T.wait(self, 0.3)
	var walkers: Array = lvl.population.walkers.duplicate()
	T.check(walkers.size() >= 2, "the level has walkers to hide (%d)" % walkers.size())
	var prompts_before: int = get_nodes_in_group("interactable").size()

	_new_shooter()
	await T.wait(self, 0.5)
	# E prompts: none during the fight. A walker right beside Bob (as in the first screenshot) and a shut door in front of him.
	await _stand(Vector3(3.0, 0.0, -0.3))
	walkers[0].global_position = Vector3(3.6, 0.0, -0.3)
	p.set_camera(-PI / 2.0, 0.0) # facing east, at the walker
	await T.wait(self, 0.2)
	var focus_walker = p._focus
	var door: Node3D = lvl.stalls.door_for(1, 4)
	await _stand(Vector3(door.point.x, 0.0, -0.2))
	p.set_camera(0.0, 0.0) # facing -Z, at the door
	await T.wait(self, 0.2)
	var focus_door = p._focus
	await T.key(self, KEY_E)
	await T.wait(self, 0.5)
	T.check(focus_walker == null and focus_door == null and not door.is_open,
			"no E prompt next to a hidden walker or a shut door, E opens nothing (%s, %s, door open %s)" % [focus_walker, focus_door, door.is_open])

	# --- doors and walkers ---
	var shut := 0
	for d: Node3D in lvl.stalls.doors:
		if not d.is_open and absf(d.rotation.y) < 0.01:
			shut += 1
	T.check(lvl.stalls.doors.size() == 20 and shut == 20, "every stall door shut during the fight (%d of %d)" % [shut, lvl.stalls.doors.size()])
	var hidden := 0
	for w: Node3D in walkers:
		if not w.visible and w.collision_layer == 0 and w.process_mode == Node.PROCESS_MODE_DISABLED:
			hidden += 1
	T.check(hidden == walkers.size(), "every walker hidden, not solid, stopped (%d of %d)" % [hidden, walkers.size()])
	var queue_seen := 0
	for q: Node3D in lvl.population.queue:
		if q.visible:
			queue_seen += 1
	T.check(queue_seen == lvl.population.queue.size() and queue_seen > 0, "the queue stays (%d visible)" % queue_seen)

	# --- the stacks ---
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	T.check(sh.stacks.size() == 4, "4 toilet-paper stacks (%d)" % sh.stacks.size())
	for i in Shooter.STACKS.size():
		var r: Array = Shooter.STACKS[i]
		var c := Vector3((r[0] + r[1]) / 2.0, 0.5, (r[2] + r[3]) / 2.0)
		var q := PhysicsPointQueryParameters3D.new()
		q.position = c
		q.collision_mask = 1
		var inside := false
		for h: Dictionary in space.intersect_point(q):
			if h["collider"] == sh.stacks[i]:
				inside = true
		# its top: a ray down from above lands at 1.0 m on it
		var top := _ray(Vector3(c.x, 2.0, c.z), Vector3(c.x, -0.5, c.z))
		var top_ok: bool = not top.is_empty() and top["collider"] == sh.stacks[i] and absf(float(top["position"].y) - 1.0) < 0.02
		var dims := Vector2(r[1] - r[0], r[3] - r[2])
		var size_ok := (is_equal_approx(dims.x, 0.8) and is_equal_approx(dims.y, 0.6)) or (is_equal_approx(dims.x, 0.6) and is_equal_approx(dims.y, 0.8))
		# free beside it: from its open face across the corridor to the level, at knee and chest height
		var side: Vector3 = OPEN_SIDE[i]
		var face := c + side * (absf(side.x) * dims.x / 2.0 + absf(side.z) * dims.y / 2.0 + 0.01)
		var free := 10.0
		for y: float in [0.3, 0.8]:
			var from := Vector3(face.x, y, face.z)
			var hit := _ray(from, from + side * 3.0)
			free = minf(free, 3.0 if hit.is_empty() else from.distance_to(hit["position"]))
		T.check(inside and top_ok and size_ok and free >= 0.9,
				"stack %d (%s): solid %s, 1.0 m high %s, 0.8 x 0.6 %s, %.2f m free beside it (>= 0.9)" % [i, Shooter.COVERS[STACK_COVER[i]]["name"], inside, top_ok, size_ok, free])
	# every walk between cover points keeps a body clear of every stack (all 30 ordered pairs, sampled every 5 cm)
	var walks := 0
	var touched: Array = []
	for a in Shooter.COVERS.size():
		for b in Shooter.COVERS.size():
			if a == b:
				continue
			walks += 1
			var path: Array[Vector3] = [Shooter.COVERS[a]["hide"]]
			path.append_array(sh.path_between(Shooter.COVERS[a]["hide"], b))
			var worst := 10.0
			for k in path.size() - 1:
				var n := maxi(ceili(path[k].distance_to(path[k + 1]) / 0.05), 1)
				for j in n + 1:
					var at: Vector3 = path[k].lerp(path[k + 1], float(j) / n)
					for r: Array in Shooter.STACKS:
						worst = minf(worst, _rect_dist(Vector2(at.x, at.z), r))
			if worst < BODY_R:
				touched.append("%d->%d %.2f" % [a, b, worst])
	T.check(walks == 30 and touched.is_empty(), "no stack in the way of any of %d cover-to-cover walks (touching: %s)" % [walks, touched])
	# cover: from Bob's approach along the U (1.5 m and 3 m before the cover), chest at the hide spot hidden, head showing
	var views := 0
	var bad_cover: Array = []
	for i in STACK_COVER.size():
		var cv: Dictionary = Shooter.COVERS[STACK_COVER[i]]
		var s: float = sh.cover_s(STACK_COVER[i])
		for back: float in [1.5, 3.0]:
			await _stand(_u_point(s - back))
			var eye: Vector3 = sh.bob_head()
			var chest_seen: bool = sh.clear_line(eye, cv["hide"] + Vector3.UP * 0.7)
			var head_seen: bool = sh.clear_line(eye, cv["hide"] + Vector3.UP * 1.1)
			views += 1
			if chest_seen or not head_seen:
				bad_cover.append("%s from %.1f m back (%s): chest seen %s, head seen %s" % [cv["name"], back, p.global_position, chest_seen, head_seen])
	T.check(views == 8 and bad_cover.is_empty(), "the stacks hide the chest and show the head from %d approach points (%s)" % [views, bad_cover])

	# --- the invisible wall: Bob stops at x 1.2, blobs and sight pass ---
	await _stand(Vector3(2.2, 0.0, 0.0))
	p.set_camera(PI / 2.0, 0.0) # facing west (-X)
	await T.key_down(self, KEY_W)
	await T.wait(self, 2.0)
	await T.key_up(self, KEY_W)
	var stop_x: float = p.global_position.x
	T.check(stop_x >= Shooter.WALL_X + 0.2 and stop_x < 1.6, "walking west in corridor A Bob stops at the wall (x %.2f, the wall at %.1f)" % [stop_x, Shooter.WALL_X])
	await _stand(Vector3(1.5, 0.0, -5.1))
	await T.key_down(self, KEY_W)
	await T.wait(self, 2.0)
	await T.key_up(self, KEY_W)
	T.check(p.global_position.x > -0.1, "corridor B's west end is closed too (x %.2f)" % p.global_position.x)
	T.check(sh.clear_line(Vector3(1.6, 1.0, 0.0), Vector3(0.6, 1.0, 0.0)), "the wall does not block sight")
	await _stand(Vector3(1.6, 0.0, 0.0))
	p.set_camera(PI / 2.0, 0.0)
	var walled: int = sh.wall_hits
	var min_x := 10.0
	await T.left_down(self)
	for f in 3:
		await physics_frame
	await T.left_up(self)
	for f in 20:
		for b: Dictionary in sh.blobs:
			min_x = minf(min_x, (b["pos"] as Vector3).x)
		await physics_frame
	T.check(min_x < Shooter.WALL_X - 0.3, "blobs fly through the wall (the westmost at x %.2f; %d wall hits)" % [min_x, sh.wall_hits - walled])

	# --- refill at every sink ---
	await _stand(Vector3(2.0, 0.0, -0.5))
	await T.wait(self, 1.6) # the wall part's 3 shots were refilled at sink 1: let that gurgle end (the sound plays one at a time)
	var fills: Array = []
	var no_fill: Array = []
	var sounds_before := Sfx.count("refill")
	var refills0: int = sh.refills
	for k in Sinks.SINK_COUNT:
		var x := Sinks.SINK_X_FIRST + Sinks.SINK_X_STEP * k
		await _stand(Vector3(x, 0.0, Sinks.SPOUT.z - 0.95))
		sh.tank = 0
		var n := 0
		while sh.tank < Shooter.TANK and n < 200:
			await physics_frame
			n += 1
		fills.append(n)
		await T.wait(self, 0.1)
		if sh.hud.empty_label.visible:
			fills[fills.size() - 1] = -1
		# 1.5 m out (the far side of corridor A; behind stack A for sinks 5 and 6: those are measured from the stack's side)
		var far := Vector3(x, 0.0, Sinks.SPOUT.z - 1.5)
		if far.x > 5.6 - BODY_R and far.x < 6.4 + BODY_R:
			far = Vector3(5.6 - BODY_R - 0.02 if x < 6.0 else 6.4 + BODY_R + 0.02, 0.0, -0.7)
		await _stand(far)
		sh.tank = 0
		var d := Shooter.sink_distance(p.global_position)
		await T.wait(self, 1.0)
		if sh.tank != 0 or d < 1.0:
			no_fill.append("sink %d at %s (%.2f m): tank %d" % [k + 1, p.global_position, d, sh.tank])
	var fast_ok := fills.all(func(f: int) -> bool: return f >= 89 and f <= 91)
	T.check(fast_ok, "every sink fills an empty tank in 1.5 s +- 1 frame at 0.95 m, EMPTY gone (frames per sink %s; -1 = EMPTY stayed)" % [fills])
	T.check(sh.refills - refills0 == 10 and Sfx.count("refill") - sounds_before == 10, "one refill and one gurgle per sink (%d refills, %d sounds)" % [sh.refills - refills0, Sfx.count("refill") - sounds_before])
	T.check(no_fill.is_empty(), "no refill 1.5 m out at any of the 10 sinks (%s)" % [no_fill])

	# --- BOSSY: the three orders ---
	await _drop_shooter()
	var orders := [[0, 1, Vector3(2.0, 0.0, -0.5)], [0, 2, Vector3(11.3, 0.0, 0.3)], [1, 2, Vector3(11.0, 0.0, -5.3)]]
	var corners := {}
	for o: Array in orders:
		await _stand(o[2])
		_new_shooter()
		var squad: Array = sh.spawn_squad()
		watching = true
		T.check(sh.hud.foes_label.text == "CREW 3", "order %s: the HUD says CREW 3 (%s)" % [o, sh.hud.foes_label.text])
		await T.wait(self, 0.5)
		squad[o[0]].hp = 1.0
		sh._on_hit(squad[o[0]], false, squad[o[0]].body.global_position)
		await T.wait(self, 1.0)
		T.check(sh.boss == null, "order %s: no BOSSY after one crew down" % [o])
		var eye: Vector3 = sh.bob_head()
		squad[o[1]].hp = 1.0
		sh._on_hit(squad[o[1]], false, squad[o[1]].body.global_position)
		var bz = sh.boss
		T.check(bz != null and bz.name == "BOSSY" and bz.hp == 200.0 and bz.burst == 5 and bz.shot_damage == 8.0 and bz.blob_speed == 22.0,
				"order %s: BOSSY at once after the second, 200 HP, bursts of 5, 8 dmg, 22 m/s" % [o])
		if bz == null:
			await _drop_shooter()
			continue
		T.check(Cutters.is_tinted(bz.body, Cutters.DEFS[2]["color"]), "order %s: she is orange" % [o])
		var hidden_corners: Array = Shooter.BOSS_CORNERS.filter(func(c: Vector3) -> bool: return not sh.clear_line(c + Vector3.UP * 1.1, eye))
		var corner: Vector3 = sh.boss_corner
		corners[corner] = true
		T.check(hidden_corners.is_empty() or hidden_corners.has(corner), "order %s: she appears at a corner Bob cannot see (%s; hidden %s)" % [o, corner, hidden_corners])
		await T.wait(self, 0.1)
		T.check(sh.hud.foes_label.text == "CREW 1 · BOSSY", "order %s: the HUD says '%s'" % [o, sh.hud.foes_label.text])
		var reached := false
		for t in 20:
			await T.wait(self, 0.5)
			var c: Dictionary = Shooter.COVERS[bz.cover]
			var at: Vector3 = bz.body.global_position
			if bz.ai != Enemy.Ai.MOVE and (Vector2(at.x - c["hide"].x, at.z - c["hide"].z).length() < 0.3 or Vector2(at.x - c["peek"].x, at.z - c["peek"].z).length() < 0.3):
				reached = true
				break
		T.check(reached, "order %s: she walks to cover %d (%s) (at %s)" % [o, bz.cover, Shooter.COVERS[bz.cover]["name"], bz.body.global_position])
		var last: int = 3 - o[0] - o[1]
		squad[last].hp = 1.0
		sh._on_hit(squad[last], false, squad[last].body.global_position)
		var bosses: int = sh.enemies.filter(func(e) -> bool: return e.name == "BOSSY").size()
		T.check(bosses == 1, "order %s: the third crew down brings no second BOSSY (%d)" % [o, bosses])
		await _drop_shooter()
	T.check(corners.size() == 2, "both corners used across the orders (%s)" % [corners.keys()])
	# crew spawned one by one (no squad) never bring BOSSY
	_new_shooter()
	var solo: Array = [sh.spawn_crew("CREW 1", Vector3(9.0, 0.0, 0.3), -PI / 2.0), sh.spawn_crew("CREW 2", Vector3(11.5, 0.0, -3.0), 0.0)]
	for e in solo:
		e.hp = 1.0
		sh._on_hit(e, false, e.body.global_position)
	T.check(sh.boss == null, "no BOSSY without the squad")
	T.check(frames > 400 and outside == 0, "every enemy inside the arena on every frame (%d frames, %d outside %s)" % [frames, outside, first_bad])
	T.check(talkers == 0, "no E prompt on any watched frame (%d frames with one)" % talkers)

	# --- after the fight: doors and walkers back ---
	await _drop_shooter()
	await T.wait(self, 0.5)
	var open_again: bool = lvl.stalls.door_for(1, 3).is_open and lvl.stalls.door_for(2, 7).is_open
	var others_shut := 0
	for d: Node3D in lvl.stalls.doors:
		if not d.is_open:
			others_shut += 1
	T.check(open_again and others_shut == 18, "after: the 2 open doors open again, 18 shut (%s, %d)" % [open_again, others_shut])
	var back := 0
	for w: Node3D in walkers:
		if is_instance_valid(w) and w.visible and w.collision_layer == 2 and w.process_mode == Node.PROCESS_MODE_INHERIT:
			back += 1
	T.check(back == walkers.size(), "after: every walker back (%d of %d)" % [back, walkers.size()])
	T.check(p.collision_mask & Shooter.WALL_LAYER == 0, "after: Bob no longer bumps into the arena wall")
	T.check(get_nodes_in_group("interactable").size() == prompts_before, "after: every E prompt back (%d of %d)" % [get_nodes_in_group("interactable").size(), prompts_before])
	lvl.queue_free()
	await process_frame
	T.finish(self)
