extends Node3D
## A generic "press E here" spot. Set `prompt_text`, `point` and `enabled`, listen for `used`.

signal used(player: Node3D)

var prompt_text := ""
var point := Vector3.ZERO
var enabled := true
var enabled_fn := Callable() ## optional extra condition, checked every time the prompt is asked for
var priority := 1.0 ## wins over the plain stall door standing next to it


func _ready() -> void:
	add_to_group("interactable")


func prompt() -> String:
	if not enabled or (enabled_fn.is_valid() and not enabled_fn.call()):
		return ""
	return prompt_text


func interaction_point() -> Vector3:
	return point


func interact(player: Node3D) -> void:
	used.emit(player)
