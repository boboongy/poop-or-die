extends "res://scripts/missions/mission.gd"
## Level 1, mission 2: a tissue box appears in one of three places (random each run). Meanwhile the person in
## the stall keeps knocking, so Bob can find which stall it is.

const TissueBox := preload("res://scripts/tissue_box.gd")

## Possible places (world positions on the floor): near the sinks at the east end, the back corridor, the waiting room corner.
const SPOTS: Array[Vector3] = [Vector3(11.3, 0.07, 0.4), Vector3(3.0, 0.07, -5.3), Vector3(-4.7, 0.07, 1.7)]

var _box: Node3D


func _init() -> void:
	id = "find"
	title = "Find some tissue"
	requires = ["ask"]


func activate() -> void:
	hint = "it is lying on the floor somewhere: near the sinks, the back corridor or the waiting room"
	_box = Node3D.new()
	_box.set_script(TissueBox)
	level.add_child(_box)
	_box.global_position = SPOTS[randi() % SPOTS.size()]
	_box.grabbed.connect(finish)
	level.ctx["knocking"] = true
	_knock_loop()
	super.activate()


## The person in the stall calls out now and then, so the right stall can be found by ear and by eye.
func _knock_loop() -> void:
	var lines := ["*knock knock*  Hello?? Anyone got tissue?!", "Please! I'm stuck in here!", "*bang bang*  Tissue!! Anybody!?"]
	var turn := 0
	while level.ctx.get("knocking", false) and is_inside_tree():
		var npc: Node3D = level.population.occupants[level.ctx["needy"]]
		if npc.is_sitting():
			Sfx.knock(npc, npc.global_position + Vector3(0.0, 1.0, 0.0)) # heard through the walls: find the stall by ear
			level.dialogue.bubble(npc, lines[turn % lines.size()], 3.0)
		turn += 1
		await get_tree().create_timer(6.0).timeout
