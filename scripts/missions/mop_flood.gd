extends "res://scripts/missions/mission.gd"
## Level 2, mission 2: dry EVERY puddle (owner, 2026-09-21: four puddles, from clogged toilets and overflowing sinks). Done once all of
## them have stopped growing and are fully mopped. The checklist counts the puddles still left.


func _init() -> void:
	id = "mop"
	title = "Mop up the flood"
	requires = ["find_mop"]


func activate() -> void:
	hint = "the water is at %s. Hold Q, face the water, right-click to mop (hold it to keep mopping). Don't run on the wet floor!" % level.puddle_text()
	for f in level.floods:
		f.cleaned.connect(_update)
	super.activate()
	_update()


func _update() -> void:
	var left: int = level.puddles_left()
	title = "Mop up the flood (%d puddle%s left)" % [left, "" if left == 1 else "s"]
	changed.emit()
	if left == 0:
		finish()
