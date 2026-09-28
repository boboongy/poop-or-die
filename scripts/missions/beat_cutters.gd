extends "res://scripts/missions/mission.gd"
## Level 4, the one mission: three queue cutters block the stall that opened at the start (cutters.gd); argue with each
## (E) and win the fights. Done when all three are down (`all_down`); the level then lets Bob use that stall.


func _init() -> void:
	id = "cutters"
	title = "Stop the queue cutters"


func activate() -> void:
	var cm = level.cutters
	cm.all_down.connect(finish)
	cm.fight_started.connect(func(_n: String) -> void: _update())
	cm.fight_ended.connect(_update)
	cm.arrived.connect(_update)
	super.activate()
	_update()


func _update() -> void:
	if state != State.ACTIVE:
		return
	var cm = level.cutters
	var stall: int = level.ctx.get("open_stall", 0)
	var where := "stall %d (row %d)" % [stall % 10 + 1, 1 if stall < 10 else 2]
	if cm.cutters.is_empty():
		hint = "%s is free... but someone is coming" % where
	else:
		title = "Stop the queue cutters (%d left)" % (3 - cm.fights_won)
		hint = "they block %s: press E on one to argue" % where
	changed.emit()
