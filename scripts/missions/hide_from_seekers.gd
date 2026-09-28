extends "res://scripts/missions/mission.gd"
## Level 3, the one mission: hide until the seekers have looked in every stall (hide_seek.gd). The hint only counts the seconds down; it
## never says WHERE or HOW to hide (the owner wants the player to work that out).


func _init() -> void:
	id = "hide"
	title = "Hide from the seekers"


func activate() -> void:
	var hs = level.hide_seek
	hs.tick.connect(_update)
	hs.search_over.connect(finish)
	super.activate()
	_update()


func _update() -> void:
	if state != State.ACTIVE:
		return
	var hs = level.hide_seek
	if hs.phase == hs.Phase.HIDING:
		hint = "they start looking in %d s" % int(ceil(hs.hide_left()))
	else:
		hint = "they are looking..."
	changed.emit()
