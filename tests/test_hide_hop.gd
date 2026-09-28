extends SceneTree
## Level 3 "Hide and seek", part 1: the setup and the hop, in ALL 20 stalls (level loaded 20 times, once per forced empty stall, so each
## stall is tested both as the EMPTY one and as an OCCUPIED one).
##  - Level 3 is 90 s, has the mission "hide", exactly ONE empty stall (random over 3000 draws: all 20 possible), 19 sitting Jijios.
##  - No text the player reads mentions the seat, the lap, feet or the gap (the puzzle is not told).
##  - Empty stall: inside with the door closed the prompt is "E  climb" (not with the door open); E hops Bob onto the seat (feet above
##    the peek height, so nobody peeking under the door sees them), E again climbs down. On the floor his feet ARE seen.
##  - Occupied stall: the prompt is "E  talk" (no climb); a wrong reply repeats the talk and does not shush; the right reply ("shush")
##    shushes the Jijio, then "E  climb" puts Bob on top of the Jijio (FACTORY_TODO #13: near the head, not the lap -- no clear
##    gap exists at lap height for a second full-size body; owner approved the render); E again climbs down.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")

const BANNED := ["seat", "lap", "feet", "foot", "toilet", "gap", "under the door", "climb"]


func _init() -> void:
	seed(5)
	Progress.level = T.HIDE_LEVEL
	# The random choice reaches every stall.
	var seen := {}
	for n in 3000:
		seen[HideSeek.pick_empty()] = true
	T.check(seen.size() == 20, "the empty stall can be any of the 20 (%d different in 3000 draws)" % seen.size())
	T.check(LevelDefs.has_level(T.HIDE_LEVEL) and LevelDefs.get_level(T.HIDE_LEVEL)["time"] == 90.0, "hide and seek exists and is 90 s (owner 2026-09-25)")

	for i in 20:
		HideSeek.force_empty = i
		var lvl := T.level(self)
		await T.wait(self, 0.8)
		await _one_load(lvl, i)
		lvl.queue_free()
		await process_frame
		await physics_frame
	HideSeek.force_empty = -1
	T.finish(self)


func _one_load(lvl: Node, empty: int) -> void:
	var hs = lvl.hide_seek
	var p: CharacterBody3D = lvl.player
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var doors: Array = lvl.stalls.doors
	var tag := "empty=%d" % empty
	if empty == 0:
		T.check(lvl.level_number == T.HIDE_LEVEL, "the hide-and-seek level loaded")
		T.check(absf(lvl._time_left - 90.0) < 1.5, "timer about 90 s (%.1f)" % lvl._time_left)
		T.check(lvl.get_node("MissionManager").mission("hide") != null, "mission 'hide' exists")
		var text: String = lvl.get_node("HUD/MissionLabel").text.to_lower() + " " + String(LevelDefs.get_level(T.HIDE_LEVEL).get("walker_hint", "")).to_lower()
		var bad: Array[String] = []
		for w: String in BANNED:
			if text.contains(w):
				bad.append(w)
		T.check(bad.is_empty(), "the mission text and hint do not give the puzzle away (banned words found: %s) '%s'" % [str(bad), text])
	T.check(hs.empty_stall == empty, "%s: the forced stall is the empty one" % tag)
	var sitting := 0
	for npc in lvl.population.occupants:
		if npc.is_sitting():
			sitting += 1
	T.check(sitting == 19 and not lvl.population.occupants[empty].is_sitting(), "%s: 19 Jijios sit, the empty stall has nobody (%d)" % [tag, sitting])

	# --- the empty stall: climb up and down
	await _enter(lvl, empty)
	T.check(hs.feet_visible(empty), "%s: Bob on the floor of the closed empty stall: his feet show under the door" % tag)
	T.check(p.get_camera_pitch() < -0.9, "%s: as soon as Bob is inside a stall the camera tilts steeply down (a stall is too cramped for the normal view; pitch %.2f)" % [tag, p.get_camera_pitch()])
	var floor_cam: float = p.get_node("CameraPivot/SpringArm3D/Camera3D").global_position.distance_to(p.global_position + Vector3(0, 0.6, 0))
	T.check(floor_cam > 1.2, "%s: and the camera is not squashed against his back (%.2f m from him)" % [tag, floor_cam])
	T.check(prompt.text == "E  climb", "%s: inside the closed empty stall the prompt is 'E  climb' ('%s')" % [tag, prompt.text])
	doors[empty].set_open(true, 0.01)
	await T.wait(self, 0.4)
	T.check(not prompt.text.contains("climb"), "%s: with the door open there is no climb prompt ('%s')" % [tag, prompt.text])
	doors[empty].set_open(false, 0.01)
	await T.wait(self, 0.4)
	await T.key(self, KEY_E)
	await T.wait(self, 0.8)
	T.check(hs.hidden_in == empty, "%s: E hops Bob up (hidden_in %d)" % [tag, hs.hidden_in])
	T.check(p.get_camera_pitch() < -0.9, "%s: hiding tilts the camera steeply down (the stall is too cramped for the normal view: pitch %.2f)" % [tag, p.get_camera_pitch()])
	var cam_dist: float = p.get_node("CameraPivot/SpringArm3D/Camera3D").global_position.distance_to(p.global_position + Vector3(0, 0.6, 0))
	T.check(cam_dist > 1.2, "%s: and the camera is not squashed against Bob (%.2f m from him)" % [tag, cam_dist])
	T.check(p.global_position.y > 0.45, "%s: Bob stands on the seat (y %.2f)" % [tag, p.global_position.y])
	T.check(not hs.feet_visible(empty), "%s: on the seat his feet are above the peek height, nothing shows under the door" % tag)
	T.check(prompt.text == "E  climb down", "%s: prompt on the seat ('%s')" % [tag, prompt.text])
	doors[empty].set_open(true, 0.01)
	T.check(hs.feet_visible(empty), "%s: if the door is open he is seen even on the seat" % tag)
	doors[empty].set_open(false, 0.01)
	await T.key(self, KEY_E)
	await T.wait(self, 0.8)
	T.check(hs.hidden_in == -1 and not p.hiding and p.global_position.y < 0.05, "%s: E climbs down (y %.2f)" % [tag, p.global_position.y])
	T.check(not p.get_node("CollisionShape3D").disabled, "%s: Bob's body collision is back" % tag)
	T.check(hs.stall_of(p.global_position) == empty, "%s: he is still inside the stall after climbing down" % tag)
	T.check(p.get_camera_pitch() < -0.9, "%s: still inside the stall: the camera stays tilted (%.2f)" % [tag, p.get_camera_pitch()])
	var outward := Vector3(0.0, 0.0, 1.0) if empty < 10 else Vector3(0.0, 0.0, -1.0)
	p.global_position = Vector3(doors[empty].point.x, 0.05, doors[empty].point.z) + outward * 0.8
	await T.wait(self, 0.4)
	T.check(hs.stall_of(p.global_position) == -1 and p.get_camera_pitch() > -0.4, "%s: walking out into the corridor puts the camera pitch back (%.2f)" % [tag, p.get_camera_pitch()])

	# --- an occupied stall: the talk first, then the lap
	var occ := (empty + 1) % 20
	await _enter(lvl, occ)
	T.check(prompt.text == "E  talk", "%s: occupied stall %d: the prompt is 'E  talk', no climb yet ('%s')" % [tag, occ, prompt.text])
	await T.key(self, KEY_E) # start
	await T.wait(self, 0.2)
	T.check(p.busy, "%s: the talk freezes Bob" % tag)
	await T.key(self, KEY_E) # line 1
	await T.wait(self, 0.1)
	await T.key(self, KEY_2) # the wrong reply
	await T.wait(self, 0.1)
	await T.key(self, KEY_E) # their answer
	await T.wait(self, 0.3)
	T.check(not p.busy and not hs.shushed.has(occ), "%s: a wrong reply repeats: not shushed, Bob free again" % tag)
	T.check(prompt.text == "E  talk", "%s: the talk can be tried again ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait(self, 0.2)
	await T.key(self, KEY_E)
	await T.wait(self, 0.1)
	await T.key(self, KEY_1) # "shhh"
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)
	await T.wait(self, 0.3)
	T.check(hs.shushed.has(occ) and not p.busy, "%s: the right reply shushes the Jijio" % tag)
	T.check(prompt.text == "E  climb", "%s: now the climb prompt appears ('%s')" % [tag, prompt.text])
	await T.key(self, KEY_E)
	await T.wait(self, 0.8)
	T.check(hs.hidden_in == occ and p.global_position.y > 0.55, "%s: Bob stands on the occupied Jijio (y %.2f)" % [tag, p.global_position.y])
	T.check(not hs.feet_visible(occ), "%s: on top of the Jijio his feet are hidden" % tag)
	T.check(lvl.population.occupants[occ].is_sitting(), "%s: the Jijio still sits" % tag)
	var occupant: Node3D = lvl.population.occupants[occ]
	var expected: Vector3 = occupant.global_position + Basis(Vector3.UP, occupant.get_yaw()) * HideSeek.LAP_OFFSET
	T.check(p.global_position.distance_to(expected) < 0.02, "%s: Bob's position matches the occupant + the yaw-rotated offset (FACTORY_TODO #13; off by %.3f m)" % [tag, p.global_position.distance_to(expected)])
	await T.key(self, KEY_E)
	await T.wait(self, 0.8)
	T.check(hs.hidden_in == -1 and p.global_position.y < 0.05, "%s: climbed down from the lap" % tag)


## Bob inside stall `i`, 0.6 m past the door, facing the toilet, door closed.
func _enter(lvl: Node, i: int) -> void:
	var door: Node3D = lvl.stalls.doors[i]
	var inward := Vector3(0.0, 0.0, -1.0) if i < 10 else Vector3(0.0, 0.0, 1.0)
	door.set_open(false, 0.01)
	lvl.player.global_position = Vector3(door.point.x, 0.05, door.point.z) + inward * 0.6
	lvl.player.face_direction(inward)
	await T.wait(self, 0.5)
