extends Node3D
## Stand-in for the factory's mop and bucket (FACTORY_TODO.md batch 4): a bucket with a mop standing in it, made of
## plain shapes. E picks up the mop (first-person grab); the bucket stays where it is.

signal grabbed(mop: Node3D) ## the pickup finished; `mop` is the mop node, now held by Bob

var mop: Node3D


func _ready() -> void:
	add_to_group("interactable")
	var bucket := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.14
	cyl.height = 0.3
	bucket.mesh = cyl
	bucket.material_override = _color(Color(0.15, 0.35, 0.85))
	bucket.position = Vector3(0.0, 0.15, 0.0)
	add_child(bucket)
	mop = make_mop()
	mop.position = Vector3(0.0, 0.05, 0.0)
	mop.rotation.z = 0.28 # leaning out of the bucket
	add_child(mop)


## The mop alone: its origin is the mop head on the floor, the handle rises along +Y.
static func make_mop() -> Node3D:
	var m := Node3D.new()
	m.name = "Mop"
	m.set_meta("carry_name", "mop")
	var handle := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.015
	stick.bottom_radius = 0.015
	stick.height = 1.2
	handle.mesh = stick
	handle.material_override = _color(Color(0.55, 0.4, 0.2))
	handle.position = Vector3(0.0, 0.6, 0.0)
	m.add_child(handle)
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.07, 0.12)
	head.mesh = box
	head.material_override = _color(Color(0.85, 0.85, 0.8))
	head.position = Vector3(0.0, 0.035, 0.0)
	m.add_child(head)
	return m


static func _color(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	return mat


func prompt() -> String:
	return "E  pick up the mop"


func interaction_point() -> Vector3:
	return global_position


func interact(player: Node3D) -> void:
	remove_from_group("interactable")
	await player.grab(mop)
	grabbed.emit(mop)
