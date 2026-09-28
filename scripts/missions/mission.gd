extends Node
## Base class of every mission. A mission is created when the level loads (`setup`), becomes ACTIVE when
## all missions it `requires` are done (`activate`), and calls `finish()` when the player has done it.
## Failing never costs time: a mission simply stays active until it is done (retry only).

const Sfx := preload("res://scripts/sfx.gd")

signal completed
signal changed ## title / hint / state changed: the HUD list refreshes

enum State { LOCKED, ACTIVE, DONE }

var id := ""
var title := ""
var hint := "" ## shown next to the title while the mission is active
var requires: Array[String] = []
var state := State.LOCKED
var level: Node3D


## Called once at level start, for every mission. Look things up here; do not start anything yet.
func setup(level_node: Node3D) -> void:
	level = level_node


## Called when the mission becomes active. Override to place props, make NPCs interactable, etc.
func activate() -> void:
	state = State.ACTIVE
	changed.emit()


func finish() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	hint = ""
	if level:
		Sfx.play_ui(level, "ui_done")
	completed.emit()
	changed.emit()
