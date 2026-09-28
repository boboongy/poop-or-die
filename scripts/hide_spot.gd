extends Node3D
## A "press E" spot whose prompt text is worked out every time the player asks for it (Level 3: climb, climb down, talk). Empty text =
## not available right now. `priority` makes it win over the plain stall door next to it.

var prompt_fn := Callable()
var use_fn := Callable()
var point := Vector3.ZERO
var priority := 2.0


func _ready() -> void:
	add_to_group("interactable")


func prompt() -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else ""


func interaction_point() -> Vector3:
	return point


func interact(player: Node3D) -> void:
	if use_fn.is_valid():
		use_fn.call(player)
