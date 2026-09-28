extends "res://scripts/missions/mission.gd"
## Level 2, mission 1: a mop and bucket stand in one of three places (random each run, never inside the puddle).
## Picking the mop up (E) gives Bob the mop tool (hold Q, right-click).

const MopProp := preload("res://scripts/mop_prop.gd")

## Same three places as the tissue box in Level 1: near the sinks at the east end, the back corridor, the waiting room corner.
const SPOTS: Array[Vector3] = [Vector3(11.3, 0.05, 0.4), Vector3(3.0, 0.05, -5.3), Vector3(-4.7, 0.05, 1.7)]
const MIN_DISTANCE_FROM_PUDDLE := 1.6

var _prop: Node3D


func _init() -> void:
	id = "find_mop"
	title = "Find the mop and bucket"


func activate() -> void:
	hint = "the flood is spreading from %s! The mop is somewhere: near the sinks, the back corridor or the waiting room" % level.puddle_text()
	var options: Array[Vector3] = []
	for s in SPOTS:
		var clear := true
		for f in level.floods: # never lying inside any puddle
			if Vector2(s.x - f.source.x, s.z - f.source.z).length() < MIN_DISTANCE_FROM_PUDDLE:
				clear = false
		if clear:
			options.append(s)
	if options.is_empty():
		options.append(SPOTS[2]) # the waiting room corner is always dry
	_prop = MopProp.new()
	level.add_child(_prop)
	_prop.global_position = options[randi() % options.size()]
	_prop.grabbed.connect(_on_grabbed)
	super.activate()


func _on_grabbed(mop: Node3D) -> void:
	level.player.take_carried() # the mop is not "carried" like the tissue: the mop tool owns it
	level.mop.give(mop)
	finish()
