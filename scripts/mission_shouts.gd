extends Node
## Stage 6c G (DECIDED 2026-09-28): when a new mission line appears in the top-left list, the nearest Jijio Bob can see SHOUTS it as a
## voiced bubble; repeated every REPEAT seconds while the mission is not done. All 5 levels, every mission (lines by Claude, the owner
## may reject them). "Can see": in front of Bob's camera with no wall between; nobody in sight = the nearest Jijio (heard, not seen).
## No shout while a talk box, the start dialogue, a fight or the toilet sequence owns the screen: it waits for them.

const MissionBase := preload("res://scripts/missions/mission.gd")
const REPEAT := 20.0 ## s between two shouts of the same unfinished mission (DECIDED)
const MIN_CAM_DIST := 2.5 ## m: a shouter nearer the camera than this is skipped (its bubble was huge and cut off)
const GAP := 3.0 ## s at least between any two shouts (two missions appearing together do not talk over each other)
const SHOUTS := {
	"ask": "ASK WHO NEEDS HELP!",
	"find": "FIND SOME TISSUE!",
	"deliver": "GIVE THEM THE TISSUE!",
	"find_mop": "FIND THE MOP!",
	"mop": "MOP UP THE WATER!",
	"plunge": "PLUNGE THE TOILET!",
	"plug": "PULL THE PLUG!",
	"taps": "TURN OFF THE SINKS!",
	"hide": "HIDE!",
	"cutters": "STOP THE CUTTERS!",
	"finesse": "TALK YOUR WAY IN!",
	"find_dancer": "FIND ANOTHER WAY IN!",
	"battle": "WIN THE DANCE BATTLE!",
}

var shouted: Array[String] = [] ## "<mission id>@<level time>" for every shout (tests read it)
var _level: Node3D
var _manager: Node
var _next := {} ## mission node -> level time of its next shout
var _clock := 0.0
var _last := -100.0


func setup(level: Node3D, manager: Node) -> void:
	_level = level
	_manager = manager


func _physics_process(delta: float) -> void:
	if _level == null or _level._game_over or _level._all_done:
		return
	_clock += delta
	for m in _manager.missions:
		if m.state != MissionBase.State.ACTIVE:
			_next.erase(m)
			continue
		if not _next.has(m):
			_next[m] = _clock # a new line in the list: shout it as soon as the screen is free
		if _clock >= _next[m] and _clock - _last >= GAP and _free():
			_shout(m)
			_next[m] = _clock + REPEAT


## Nothing else owns the screen or the voice right now.
func _free() -> bool:
	var p = _level.player
	if _level.intro_playing or not _level._running or p.busy or p.posing: # busy = a talk box is open (dialogue.begin)
		return false
	if _level.cutters != null and _level.cutters.fight != null:
		return false
	return true


func _shout(m: Node) -> void:
	if not SHOUTS.has(m.id):
		return
	var npc := shouter()
	if npc == null:
		return
	var line: String = SHOUTS[m.id]
	_last = _clock
	shouted.append("%s@%.1f" % [m.id, _clock])
	_level.dialogue.bubble(npc, line)


## The nearest Jijio Bob can see (in front of the camera, nothing solid between), else the nearest Jijio at all.
func shouter() -> Node3D:
	var cam := _level.get_viewport().get_camera_3d()
	var bob: Vector3 = _level.player.global_position
	var seen: Node3D = null
	var seen_d := INF
	var any: Node3D = null
	var any_d := INF
	var space := _level.get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("jijio"):
		if not (n is Node3D) or not n.is_visible_in_tree():
			continue
		var d := bob.distance_to(n.global_position)
		if d < any_d:
			any_d = d
			any = n
		if d >= seen_d or cam == null:
			continue
		var head: Vector3 = n.global_position + Vector3.UP * 1.3
		var bubble_at: Vector3 = n.global_position + Vector3.UP * 2.1 # the bubble (dialogue.BUBBLE_HEIGHT 2.05)
		# right next to the camera its bubble filled the top of the screen, cut off (player-eye pass 2026-09-28): 2.5 m at least, and
		# the bubble itself on screen
		if cam.global_position.distance_to(head) < MIN_CAM_DIST or not cam.is_position_in_frustum(head) or not cam.is_position_in_frustum(bubble_at):
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, head, 1)
		if space.intersect_ray(q).is_empty():
			seen_d = d
			seen = n
	return seen if seen != null else any
