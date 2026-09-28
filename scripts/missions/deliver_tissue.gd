extends "res://scripts/missions/mission.gd"
## Level 1, mission 3: pass the tissue under the door of the stall that asked. Not carrying the tissue shows
## nothing at the door; the normal "open door" prompt still works.

const SimpleInteractable := preload("res://scripts/simple_interactable.gd")

var _spot: Node3D


func _init() -> void:
	id = "deliver"
	title = "Pass the tissue to the person in the stall"
	requires = ["find"]


func activate() -> void:
	var index: int = level.ctx["needy"]
	title = "Pass the tissue to stall %d (%s row)" % [index % 10 + 1, "first" if index < 10 else "back"]
	hint = "walk up to that stall's door while carrying it"
	var door: Node3D = level.stalls.doors[index]
	_spot = SimpleInteractable.new()
	_spot.prompt_text = "E  pass the tissue under the door"
	_spot.point = door.interaction_point()
	_spot.enabled_fn = func() -> bool:
		return level.player.carrying != null and level.player.carrying.item_id == "tissue_box"
	_spot.used.connect(_deliver)
	level.add_child(_spot)
	super.activate()


func _deliver(player: Node3D) -> void:
	var index: int = level.ctx["needy"]
	var npc: Node3D = level.population.occupants[index]
	var item: Node3D = player.take_carried()
	if item == null:
		return
	item.reparent(npc.get_node("Model"), true)
	item.position = Vector3(0.0, 0.7, 0.4)
	item.rotation = Vector3.ZERO
	level.ctx["knocking"] = false
	_spot.enabled = false
	npc.set_expression("sk_expr_happy", 1.0)
	level.dialogue.bubble(npc, "Oh thank goodness!! You are a lifesaver!", 4.0)
	finish()
