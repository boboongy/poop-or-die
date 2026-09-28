extends Node3D
## A hinged stall door. The pivot sits on the hinge; the mesh and its collision box are children.

const Sfx := preload("res://scripts/sfx.gd")

signal toggled(is_open: bool)

var open_angle := 0.0
var point := Vector3.ZERO ## where the interact prompt is measured from
var is_open := false

var _tween: Tween


func _ready() -> void:
	add_to_group("interactable")


func prompt() -> String:
	return "E  close door" if is_open else "E  open door"


func interaction_point() -> Vector3:
	return point


func interact(_player: Node3D) -> void:
	set_open(not is_open)


func set_open(open: bool, seconds := 0.35) -> void:
	if open == is_open:
		return
	is_open = open
	if is_inside_tree():
		Sfx.play_at(self, "door_open" if open else "door_close", global_position + Vector3(0.0, 1.0, 0.0))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", open_angle if open else 0.0, seconds)
	toggled.emit(open)
