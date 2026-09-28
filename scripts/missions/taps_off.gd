extends "res://scripts/missions/mission.gd"
## Level 2 "The flood": the rampaging Jijios turned on 4 taps; E at each one turns it off (flood_story.gd). Any order with the plunging.


func _init() -> void:
	id = "taps"
	title = "Turn off the running taps"


func activate() -> void:
	var story: Node3D = level.flood_story
	story.tap_on.connect(func(_k: int) -> void: _update())
	story.tap_closed.connect(func(_k: int) -> void: _update())
	super.activate()
	_update()


func _update() -> void:
	var story: Node3D = level.flood_story
	var left: int = story.taps_left()
	title = "Turn off the running taps (%d left)" % left
	hint = "E at each tap: sinks %s" % story.sinks_text(false) if left > 0 else ""
	changed.emit()
	if left == 0:
		finish()
