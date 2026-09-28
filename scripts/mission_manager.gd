extends Node
## Loads a level's missions from LevelDefs, activates them as their requirements are done, and keeps
## the HUD checklist text. Emits `all_done` once every mission is done.

signal all_done
signal changed

const LevelDefs := preload("res://scripts/level_defs.gd")
const MissionBase := preload("res://scripts/missions/mission.gd")

var missions: Array = []
var _all_done_sent := false


func load_level(number: int, level_node: Node3D) -> void:
	for script_path: String in LevelDefs.get_level(number)["missions"]:
		var created: Node = load(script_path).new()
		add_child(created)
		missions.append(created)
		created.changed.connect(func() -> void: changed.emit())
		created.completed.connect(_refresh)
	for m in missions:
		m.setup(level_node)
	_refresh()


func mission(id: String) -> Node:
	for m in missions:
		if m.id == id:
			return m
	return null


func is_done(id: String) -> bool:
	var m := mission(id)
	return m != null and m.state == MissionBase.State.DONE


func _refresh() -> void:
	for m in missions:
		if m.state != MissionBase.State.LOCKED:
			continue
		var unlocked := true
		for req: String in m.requires:
			if not is_done(req):
				unlocked = false
		if unlocked:
			m.activate()
	changed.emit()
	if not _all_done_sent and missions.all(func(m: Node) -> bool: return m.state == MissionBase.State.DONE):
		_all_done_sent = true
		all_done.emit()


## "[x] done", "[ ] active  -  hint", locked missions greyed with "-".
func checklist_text() -> String:
	var lines: Array[String] = []
	for m in missions:
		match m.state:
			MissionBase.State.DONE:
				lines.append("[x] " + m.title)
			MissionBase.State.ACTIVE:
				lines.append("[ ] " + m.title + ("   ->  " + m.hint if m.hint != "" else ""))
			_:
				lines.append("[-] " + m.title)
	return "\n".join(lines)
