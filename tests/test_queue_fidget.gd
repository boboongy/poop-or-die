extends SceneTree
## Stage 6c E (DECIDED 2026-09-28): the queue is never static. Each of the 9 queue Jijios switches clip every 4-8 s (random, out of
## sync): `talk` toward a neighbour 50 %, `squirm` 30 %, `twerk` 20 %, no plain idle; it stops at once when it steps aside for Bob.
## Levels 1 and 5 (the queue stands in both at the start), 40 s each, sampled every 0.25 s.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const FIDGETS := ["talk", "squirm", "twerk"]


func _init() -> void:
	seed(5)
	T.check(is_equal_approx(preload("res://scripts/npc_jijio.gd").FIDGET_MIN, 4.0) and is_equal_approx(preload("res://scripts/npc_jijio.gd").FIDGET_MAX, 8.0), "switch every 4-8 s (DECIDED numbers)")
	for level_no in [1, 5]:
		await _level(level_no)
	T.finish(self)


func _level(level_no: int) -> void:
	Progress.level = level_no
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	p.global_position = Vector3(10.0, 0.05, 0.0) # out of the waiting room: nobody makes way
	var queue: Array = lvl.population.queue.filter(func(n: Node3D) -> bool: return n.state == n.State.QUEUED)
	T.check(queue.size() >= 8, "L%d: the queue stands (%d queued)" % [level_no, queue.size()])
	await T.wait(self, 8.5) # every Jijio's first switch comes within 8 s
	var changes := {}
	var last := {}
	var counts := {"talk": 0, "squirm": 0, "twerk": 0, "idle": 0, "other": 0}
	var in_sync := 0
	var samples := 0
	var talk_bad := 0
	for i in 160: # 40 s
		await T.wait(self, 0.25)
		samples += 1
		var seen := {}
		for npc: Node3D in queue:
			var clip := T.clip_of(npc.get_node("Model"))
			seen[clip] = true
			if clip in FIDGETS:
				counts[clip] += 1
			elif clip == "idle":
				counts["idle"] += 1
			else:
				counts["other"] += 1
			if last.has(npc) and last[npc] != clip:
				changes[npc] = int(changes.get(npc, 0)) + 1
			last[npc] = clip
			if clip == "talk" and npc._queue_neighbour() == null:
				talk_bad += 1
		if seen.size() == 1:
			in_sync += 1
	var total: int = counts["talk"] + counts["squirm"] + counts["twerk"] + counts["idle"] + counts["other"]
	print("L%d clip samples %s over %d Jijio-samples; all the same clip in %d of %d samples" % [level_no, str(counts), total, in_sync, samples])
	T.check(counts["idle"] + counts["other"] < total * 0.05, "L%d: no plain idle while standing in the queue (%d of %d samples)" % [level_no, counts["idle"] + counts["other"], total])
	var few: Array[String] = []
	for npc: Node3D in queue:
		if int(changes.get(npc, 0)) < 2:
			few.append("%s %d" % [npc.name, int(changes.get(npc, 0))])
	T.check(few.is_empty(), "L%d: every queue Jijio changes clip in 40 s (fewer than 2 changes: %s)" % [level_no, str(few)])
	var talk_share := float(counts["talk"]) / maxf(total, 1)
	T.check(talk_share > 0.25 and talk_share < 0.75 and counts["squirm"] > 0 and counts["twerk"] > 0, "L%d: all three clips show, talk about half (%.0f %%)" % [level_no, talk_share * 100.0])
	T.check(float(counts["twerk"]) < float(counts["squirm"]) * 1.5, "L%d: twerk (20 %%) rarer than squirm (30 %%): %d vs %d" % [level_no, counts["twerk"], counts["squirm"]])
	T.check(in_sync < samples * 0.1, "L%d: the line is out of sync (all one clip in %d of %d samples)" % [level_no, in_sync, samples])
	T.check(talk_bad == 0, "L%d: a talker always has a queued neighbour within 1.3 m (%d bad)" % [level_no, talk_bad])

	# Bob walks at the queue: every Jijio that makes way drops its clip at once (checked every frame for 4 s)
	var ahead: Node3D = queue[queue.size() / 2]
	p.global_position = ahead.global_position + Vector3(0.0, 0.05, 2.2)
	p.set_facing(0.0)
	var met := 0
	var bad := 0
	T.key_down(self, KEY_W)
	for f in 120:
		await physics_frame
		for npc: Node3D in queue:
			if npc._hold > 0.0 and Vector2(npc.velocity.x, npc.velocity.z).length() > 0.05:
				met += 1
				if npc.fidget_clip != "":
					bad += 1
	T.key_up(self, KEY_W)
	T.check(met > 0, "L%d: Bob's walk made queue Jijios step aside (%d Jijio-frames)" % [level_no, met])
	T.check(bad == 0, "L%d: a Jijio stepping aside plays no queue clip (%d of %d frames did)" % [level_no, bad, met])
	lvl.queue_free()
	await process_frame
