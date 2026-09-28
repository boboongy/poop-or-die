extends Node3D
## Level 1's mission prop: the factory tissue roll (tissue-props.glb `SM_TissueRoll`, owner B1 2026-09-27), shown SCALE x its real size.
## It keeps the old stand-in box's warm orange glow (solid orange + emission) and slowly turns and bobs: a plain pale prop was invisible on
## the white, glossy, green-lit floor (owner could not find it, 2026-09-21). Only the mesh child moves, so this node stays where the
## mission put it.

const TissueProps := preload("res://assets/environments/tissue-props/tissue-props.glb")
const ITEM_ID := "tissue_box" ## the missions' id (unchanged)
const GLOW := Color(1.0, 0.45, 0.05)
const SCALE := 2.2 ## 0.24 m across, about the old 0.26 m glowing box (at 1.5x the windowed shots lost it behind Bob, 2026-09-27)
const HOVER := 0.13 ## m: the roll's centre over this node (0.12 m radius at SCALE)

signal grabbed ## the player finished picking it up

var item_id := ITEM_ID

var _mesh: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("interactable")
	var props: Node3D = TissueProps.instantiate()
	var roll: MeshInstance3D = props.find_child("SM_TissueRoll", true, false)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = roll.mesh # the roll's shape; painted orange below
	props.free()
	_mesh.scale = Vector3.ONE * SCALE
	# Solid orange, lit a little from inside: a white roll under a see-through glow blew out to a white blob in the bright sink area
	# (windowed shots 2026-09-27); the green ceiling light cannot wash this out.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.6, 0.25)
	glow.roughness = 0.7
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 1.0 # test_tissue_spots: at least 1.0 (the owner's 2026-09-21 "can't find it" report)
	_mesh.material_override = glow
	set_meta("carry_name", "tissue roll")
	add_child(_mesh)


func _process(delta: float) -> void:
	_time += delta
	_mesh.position.y = HOVER + 0.04 * sin(_time * 2.0) # hovers a little above the floor
	_mesh.rotation.y = _time * 0.8


func prompt() -> String:
	return "E  pick up the tissue"


func interaction_point() -> Vector3:
	return global_position


func interact(player: Node3D) -> void:
	remove_from_group("interactable")
	set_process(false) # the pickup tweens the whole box into Bob's hands: the mesh stops turning
	_mesh.position = Vector3.ZERO
	_mesh.rotation = Vector3.ZERO
	await player.grab(self)
	grabbed.emit()
