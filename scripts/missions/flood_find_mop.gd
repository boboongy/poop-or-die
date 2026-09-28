extends "res://scripts/missions/mission.gd"
## Level 2 "The flood": when the water is gone, the mop and bucket stand by the drain (flood_story.gd MOP_POS). E picks the mop up
## (the mop tool: hold Q, right-click), then mop_flood.gd counts the leftover puddles.

const MopProp := preload("res://scripts/mop_prop.gd")

var _prop: Node3D


func _init() -> void:
	id = "find_mop"
	title = "Grab the mop by the drain"
	requires = ["plug"]


func activate() -> void:
	hint = "the water left puddles behind"
	_prop = MopProp.new()
	level.add_child(_prop)
	_prop.global_position = level.flood_story.MOP_POS + Vector3(0.0, 0.05, 0.0)
	_prop.grabbed.connect(_on_grabbed)
	super.activate()


func _on_grabbed(mop: Node3D) -> void:
	level.player.take_carried() # the mop is not "carried" like the tissue: the mop tool owns it
	level.mop.give(mop)
	finish()
