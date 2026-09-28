extends "res://scripts/missions/mission.gd"
## Level 2 "The flood": with the toilet unclogged and every tap off, pull the plug in the waiting room floor; done when the water is gone.


func _init() -> void:
	id = "plug"
	title = "Pull the plug in the waiting room floor"
	requires = ["plunge", "taps"]


func activate() -> void:
	var story: Node3D = level.flood_story
	hint = "the brass ring in the floor behind where you started. E"
	story.plug_pulled.connect(func() -> void:
		title = "Draining..."
		hint = ""
		changed.emit())
	story.drained.connect(func() -> void:
		title = "Pull the plug: the water is gone"
		finish())
	super.activate()
