extends "res://scripts/missions/mission.gd"
## Level 2 "The flood": unclog the toilet the crazy Jijio blocked (flood_story.gd). Pick up the red plunger floating outside the stall,
## then hold E at the toilet. Any order with the taps.


func _init() -> void:
	id = "plunge"
	title = "Unclog the toilet"


func setup(level_node: Node3D) -> void:
	super.setup(level_node)
	title = "Unclog the toilet in %s" % level.flood_story.stall_text()


func activate() -> void:
	hint = "grab the red plunger floating outside it, then HOLD E at the toilet"
	level.flood_story.unclogged.connect(finish)
	super.activate()
