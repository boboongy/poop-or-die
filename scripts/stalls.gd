extends Node3D
## Godot-side stand-in for stall collision. The toilet glb only has collision proxies on stall 1
## (see FACTORY_TODO.md item 1), so this builds a box per stall part from the meshes, and turns
## every stall door into a hinged, interactable door with its own collision.
## Sits under NavRegion, after Toilet, so the boxes are part of the baked navmesh.

const DoorScript := preload("res://scripts/stall_door.gd")

## Mesh-name prefixes that get a solid box. Lids are skipped (the body box covers them).
const SOLID_PREFIXES := ["SM_StallPartition", "SM_StallFrontPanel", "SM_StallPilaster", "SM_Sink_", "SM_TrashBin"]

@export var open_degrees := 100.0

var doors: Array[Node3D] = []

@onready var _toilet: Node3D = $"../Toilet"


func _ready() -> void:
	# The glb's one stall-1 door proxy cannot swing, so remove it: doors get their own collision.
	for body in _toilet.find_children("SM_StallDoor*", "StaticBody3D", true, false):
		body.get_parent().remove_child(body)
		body.free()
	for mi in _toilet.find_children("SM_*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if _is_solid(n):
			_add_box(mi)


## Call after the navmesh is baked: closed doors must not cut the stalls off from the navmesh.
func setup_doors() -> void:
	for mi in _toilet.find_children("SM_StallDoor_R*", "MeshInstance3D", true, false):
		doors.append(_make_door(mi as MeshInstance3D))
	doors.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))


func door_for(row: int, index: int) -> Node3D:
	return doors[(row - 1) * 10 + (index - 1)]


func _is_solid(mesh_name: String) -> bool:
	if mesh_name.begins_with("SM_Toilet_R") and mesh_name.ends_with("_Body"):
		return true
	for p in SOLID_PREFIXES:
		if mesh_name.begins_with(p):
			return true
	return false


func _add_box(mi: MeshInstance3D) -> void:
	var box := mi.global_transform * mi.get_aabb()
	var body := StaticBody3D.new()
	body.name = "Box_" + mi.name
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	body.add_child(shape)
	add_child(body)
	body.global_position = box.get_center()


## The door mesh's origin is its hinge (left edge). Wrap it in an unscaled pivot with a collision box.
func _make_door(mi: MeshInstance3D) -> Node3D:
	var box := mi.global_transform * mi.get_aabb()
	var hinge := mi.global_position
	var row_two := String(mi.name).contains("_R2_")
	var pivot := Node3D.new()
	pivot.name = "Door_" + mi.name
	pivot.set_script(DoorScript)
	add_child(pivot)
	pivot.global_position = hinge
	mi.reparent(pivot, true)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	body.add_child(shape)
	pivot.add_child(body)
	body.global_position = box.get_center()

	# Doors swing outward into the corridor: toward +Z for row 1, toward -Z for row 2.
	pivot.open_angle = deg_to_rad(open_degrees if row_two else -open_degrees)
	pivot.point = box.get_center()
	return pivot
