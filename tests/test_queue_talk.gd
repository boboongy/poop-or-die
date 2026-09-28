extends SceneTree
## Stage 6c D (owner "yes to all" 2026-09-28, SPEC "Stage 6c D details"): E on ANY of the 9 queue Jijios from up to 1.5 m opens a talk
## (one of that Jijio's own lines, then the level's walker hint) with the first-person pan onto it; W leaves at once. No prompt while a
## scene owns the queue. Cases:
## (1) every queue Jijio, Bob 1.4 m away facing it (the edge of the 1.5 m reach, past Bob's own 1.3 m; closer for the Jijios in the
##     middle of the snake, whose neighbours are nearer at 1.4 m from any side), in Levels 1, 3 (dry), 4 and 5:
##     E opens the talk, the camera turns to it, the first line is one of ITS lines, W closes it. queue[4] in Levels 1 and 5 belongs to
##     the mission talk (it keeps its own lines): only its prompt is checked.
## (2) no queue prompt while a scene owns the queue: the start dialogue, hide-and-seek, the flood, a fight, the dance battle, the timeout.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Pose := preload("res://scripts/pose.gd")
const QueueTalk := preload("res://scripts/queue_talk.gd")

const DECIDED_REACH := 1.5
const TEST_DISTANCE := 1.4


func _aim_error(p: Node, npc: Node3D) -> float:
	var cam: Camera3D = p.get_node("CameraPivot/SpringArm3D/Camera3D")
	var sk := Pose.skeleton_of(npc)
	var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("DEF-spine.006")).origin
	return (-cam.global_basis.z).angle_to(head - cam.global_position)


## Put Bob `dist` from `npc`, facing it, at a spot clear of the other queue Jijios where the prompt picks `npc`. Returns false
## if no direction works (16 tried).
func _stand_by(lvl: Node, npc: Node3D, dist: float) -> bool:
	var p: CharacterBody3D = lvl.player
	for k in 16:
		var a := TAU * k / 16.0
		var spot: Vector3 = npc.global_position + Vector3(sin(a), 0.0, cos(a)) * dist
		spot.y = p.global_position.y
		if spot.x < -4.7 or spot.x > -0.3 or absf(spot.z) > 1.6: # inside the waiting room walls
			continue
		var clear := true
		for other: Node3D in lvl.population.queue:
			if other != npc and Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length() < 0.6:
				clear = false
		if not clear:
			continue
		p.global_position = spot
		p.velocity = Vector3.ZERO
		var to: Vector3 = npc.global_position - spot
		p.set_facing(atan2(-to.x, -to.z))
		await T.wait(self, 0.1)
		if p._focus == npc:
			return true
	return false


func _mine(npc: Node3D) -> bool:
	var o: Object = npc.interaction_owner()
	return o != null and o.get_script() == QueueTalk


func _queue_prompts(lvl: Node) -> int:
	var n := 0
	for npc: Node3D in lvl.population.queue:
		if _mine(npc):
			n += 1
	return n


func _talk_all(level: int) -> void:
	Progress.level = level
	T.dry = level == T.FLOOD_LEVEL
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player
	var d = lvl.dialogue
	var talks := 0
	var at_edge := 0
	var queue: Array = lvl.population.queue.duplicate()
	T.check(queue.size() == 9, "L%d: 9 Jijios in the queue (%d)" % [level, queue.size()])
	for i in queue.size():
		var npc: Node3D = queue[i]
		# In the middle of the snake the neighbours stand 0.8 / 1.1 m away: at 1.4 m a neighbour is always nearer and rightly takes the
		# prompt, so step closer until this Jijio is the nearest one Bob faces.
		var placed := false
		for want in [TEST_DISTANCE, 1.2, 1.0, 0.8, 0.6]:
			placed = await _stand_by(lvl, npc, want)
			if placed:
				if want == TEST_DISTANCE:
					at_edge += 1
				break
		var dist := Vector2(npc.global_position.x - p.global_position.x, npc.global_position.z - p.global_position.z).length()
		if not placed:
			T.check(false, "L%d queue[%d]: no spot 0.6-1.4 m away gives its E prompt (prompt '%s', owner %s, state %d)" % [level, i, npc.prompt(), npc.interaction_owner(), npc.state])
			continue
		if not _mine(npc): # the mission Jijio: its own talk keeps its own lines
			T.check(npc.prompt() != "", "L%d queue[%d] (mission talk): prompt from %.2f m" % [level, i, dist])
			continue
		await T.key(self, KEY_E)
		await T.wait(self, 0.7)
		var text: String = d._text.text
		var own: bool = QueueTalk.LINES[i].has(text)
		var aim := _aim_error(p, npc)
		T.check(d.is_open() and own and aim < 0.15, "L%d queue[%d] from %.2f m: talk open %s, its own line %s ('%s'), camera %.3f rad off" % [level, i, dist, d.is_open(), own, text.left(40), aim])
		await T.key(self, KEY_W)
		await T.wait(self, 0.8)
		T.check(not d.is_open() and not p.busy, "L%d queue[%d]: W leaves the talk at once" % [level, i])
		talks += 1
	print("L%d: %d queue talks opened" % [level, talks])
	T.check(at_edge >= 4, "L%d: %d of the 9 reached from %.1f m (past Bob's own 1.3 m; the others are boxed in by neighbours)" % [level, at_edge, TEST_DISTANCE])
	lvl.queue_free()
	T.dry = false
	await T.wait(self, 0.2)


## (2) The scenes that own the queue: no prompt of this talk on any queue Jijio.
func _blocked() -> void:
	# the start dialogue (the flag the level sets while it plays)
	Progress.level = 1
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	T.check(_queue_prompts(lvl) >= 8, "L1 control: %d queue prompts in normal play" % _queue_prompts(lvl))
	lvl.intro_playing = true
	await T.wait(self, 0.1)
	T.check(_queue_prompts(lvl) == 0, "L1 start dialogue: %d queue prompts" % _queue_prompts(lvl))
	lvl.intro_playing = false
	await T.wait(self, 0.1)
	T.check(_queue_prompts(lvl) >= 8, "L1 after the start dialogue: the prompts are back (%d)" % _queue_prompts(lvl))
	# the timeout: the real clock runs out, the queue rushes Bob
	lvl._time_left = 0.05
	await T.wait(self, 0.5)
	T.check(_queue_prompts(lvl) == 0, "L1 timeout kick-out: %d queue prompts" % _queue_prompts(lvl))
	lvl.queue_free()
	await T.wait(self, 0.2)
	# hide-and-seek: counting, then the search
	Progress.level = T.HIDE_LEVEL
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	T.check(_queue_prompts(lvl) == 0, "hide level, counting (phase %d): %d queue prompts" % [lvl.hide_seek.phase, _queue_prompts(lvl)])
	lvl.queue_free()
	await T.wait(self, 0.2)
	# the flood: the real story starts at once
	Progress.level = T.FLOOD_LEVEL
	lvl = T.level(self)
	await T.wait(self, 3.0)
	lvl._time_left = 100000.0
	T.check(lvl.flood_story.is_started and _queue_prompts(lvl) == 0, "flood level, rampage started %s: %d queue prompts" % [lvl.flood_story.is_started, _queue_prompts(lvl)])
	lvl.queue_free()
	await T.wait(self, 0.2)
	# a fight (Level 4) and the dance battle (Level 5): the flags their directors set
	Progress.level = 4
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	T.check(_queue_prompts(lvl) >= 9, "L4 control: %d queue prompts" % _queue_prompts(lvl))
	lvl.cutters.fight = Node.new()
	await T.wait(self, 0.1)
	T.check(_queue_prompts(lvl) == 0, "L4 during a fight: %d queue prompts" % _queue_prompts(lvl))
	lvl.cutters.fight.free()
	lvl.cutters.fight = null
	lvl.queue_free()
	await T.wait(self, 0.2)
	Progress.level = 5
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	T.check(_queue_prompts(lvl) >= 8, "L5 control: %d queue prompts" % _queue_prompts(lvl))
	lvl.dance.challenged = true
	await T.wait(self, 0.1)
	T.check(_queue_prompts(lvl) == 0, "L5 dance battle: %d queue prompts" % _queue_prompts(lvl))
	lvl.queue_free()
	await T.wait(self, 0.2)


func _init() -> void:
	seed(1)
	T.check(is_equal_approx(QueueTalk.REACH, DECIDED_REACH), "the queue reach is the DECIDED 1.5 m (%.2f)" % QueueTalk.REACH)
	T.check(QueueTalk.LINES.size() == 9, "9 rows of lines (%d)" % QueueTalk.LINES.size())
	for row: Array in QueueTalk.LINES:
		T.check(row.size() == 3, "3 lines per queue Jijio (%d)" % row.size())
	for level in [1, T.FLOOD_LEVEL, 4, 5]:
		await _talk_all(level)
	await _blocked()
	T.finish(self)
