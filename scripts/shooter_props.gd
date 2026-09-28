extends RefCounted
## Stage 4 "WATER WAR" (SPEC "Stage 4 plan APPROVED 2026-09-27"): the code-built props. The first-person toy gun (yellow body, blue
## tank; no hands, FACTORY_TODO R6), the water blobs, the toilet-paper cover stacks (slice 4).
## Everything is self-lit: the room is green-lit white tile and plain colours vanish in it (skill player-eye).

const YELLOW := Color(1.0, 0.82, 0.1)
const BLUE := Color(0.2, 0.65, 1.0)
const SPLASH_BLUE := Color(0.05, 0.4, 1.0) ## deeper than the blobs: it reads on the pale green tile
const BROWN := Color(0.42, 0.22, 0.04) ## the crew's poop-water
const BROWN_GUN := Color(0.3, 0.16, 0.05)


## An enemy's toy gun (held in the model's right hand; the barrel along -Z, "Muzzle" at its tip). Self-lit so it reads.
static func make_gun(color: Color) -> Node3D:
	var g := Node3D.new()
	g.name = "EnemyGun"
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.13, 0.3)
	_lit(g, box, Vector3.ZERO, Vector3.ZERO, color)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.025
	barrel.bottom_radius = 0.025
	barrel.height = 0.18
	_lit(g, barrel, Vector3(0.0, 0.02, -0.23), Vector3(PI / 2.0, 0.0, 0.0), color.darkened(0.3))
	var tank := SphereMesh.new()
	tank.radius = 0.075
	tank.height = 0.15
	_lit(g, tank, Vector3(0.0, 0.11, 0.04), Vector3.ZERO, BROWN.lightened(0.15))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.02, -0.34)
	g.add_child(muzzle)
	return g


static func _lit(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
const BLOB_RADIUS := 0.06 ## 0.045 was hard to see at 40 m/s (first screenshot)


## The first-person gun, a child of the camera. Its parts skip the depth test and are drawn in a fixed order (grip, barrel, body,
## tank), so the gun is never cut by a wall Bob stands against (his capsule keeps the camera 0.25 m from a wall; the barrel reaches
## 0.6 m). The muzzle is the returned node's child "Muzzle" (-Z).
static func make_fp_gun() -> Node3D:
	var g := Node3D.new()
	g.name = "FPGun"
	var grip := BoxMesh.new()
	grip.size = Vector3(0.05, 0.12, 0.05)
	_part(g, grip, Vector3(0.0, -0.1, 0.07), Vector3(-0.3, 0.0, 0.0), YELLOW.darkened(0.35), 0)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.022
	barrel.bottom_radius = 0.026
	barrel.height = 0.16
	_part(g, barrel, Vector3(0.0, 0.015, -0.2), Vector3(PI / 2.0, 0.0, 0.0), YELLOW.darkened(0.25), 1)
	var body := BoxMesh.new()
	body.size = Vector3(0.085, 0.11, 0.26)
	_part(g, body, Vector3.ZERO, Vector3.ZERO, YELLOW, 2)
	var tank := SphereMesh.new()
	tank.radius = 0.065
	tank.height = 0.13
	_part(g, tank, Vector3(0.0, 0.1, 0.03), Vector3.ZERO, BLUE, 3)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.015, -0.29)
	g.add_child(muzzle)
	return g


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color, order: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.45
	mat.no_depth_test = true
	mat.render_priority = order
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Where a blob lands: a one-shot burst of droplets thrown out along `normal` (it frees itself).
static func make_splash(color: Color = BLUE) -> CPUParticles3D:
	var s := CPUParticles3D.new()
	s.name = "Splash"
	s.emitting = false # a new CPUParticles3D emits at once: the caller places it, then calls restart()
	s.one_shot = true
	s.explosiveness = 0.95
	s.amount = 18
	s.lifetime = 0.45
	s.local_coords = false
	s.direction = Vector3(0.0, 0.0, 1.0) # the caller turns +Z to the surface normal
	s.spread = 70.0
	s.initial_velocity_min = 1.2
	s.initial_velocity_max = 2.8
	s.gravity = Vector3(0.0, -9.0, 0.0)
	s.scale_amount_min = 0.5
	s.scale_amount_max = 1.1
	var drop := SphereMesh.new()
	drop.radius = 0.04 # 0.025 pale drops vanished on the pale tile (frame-by-frame screenshot)
	drop.height = 0.08
	drop.radial_segments = 6
	drop.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SPLASH_BLUE if color == BLUE else color
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.8 if color == BLUE else 0.4
	drop.material = mat
	s.mesh = drop
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.finished.connect(s.queue_free)
	return s


## A floating damage number: always faces the camera, drawn over everything, the same size on screen at any distance.
static func make_number(text: String, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = "DamageNumber"
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0022 # 0.0009 was a speck at 6 m (screenshot)
	l.font_size = 40
	l.outline_size = 12
	l.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	l.render_priority = 10
	l.outline_render_priority = 9
	return l


## One water blob: a bright self-lit drop, stretched a little along its flight (-Z).
static func make_blob(color: Color = BLUE) -> MeshInstance3D:
	var drop := SphereMesh.new()
	drop.radius = BLOB_RADIUS
	drop.height = BLOB_RADIUS * 2.0
	drop.radial_segments = 8
	drop.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0 if color == BLUE else 0.6 # brown glowing hard turns orange
	drop.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Blob"
	mi.mesh = drop
	mi.scale = Vector3(0.9, 0.9, 2.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const HOSE_MUZZLE := 0.035 ## the stream's radius at the gun...
const HOSE_WIDE := 0.2 ## ... and where it lands (the 0.5 m hit width, a little under it)


## The SUPER-SOAKER stream: a see-through blue cone with a brighter core, 1 m long along -Z from its origin (shooter.gd scales z to
## the stream's length and wobbles x/y).
static func make_hose() -> Node3D:
	var h := Node3D.new()
	h.name = "Hose"
	for layer: Array in [[HOSE_MUZZLE, HOSE_WIDE, 0.45, 1.2], [HOSE_MUZZLE * 0.6, HOSE_WIDE * 0.45, 0.8, 2.2]]:
		var cone := CylinderMesh.new()
		cone.top_radius = layer[1] # +Y end: the far end once turned to -Z
		cone.bottom_radius = layer[0] # at the gun
		cone.height = 1.0
		cone.radial_segments = 14
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(BLUE.r, BLUE.g, BLUE.b, layer[2])
		mat.emission_enabled = true
		mat.emission = BLUE
		mat.emission_energy_multiplier = layer[3]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cone.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.rotation = Vector3(-PI / 2.0, 0.0, 0.0) # +Y -> -Z
		mi.position = Vector3(0.0, 0.0, -0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(mi)
	return h


const ROLL := 0.2 ## a toilet roll's width and height (m)
const STACK_WHITE := Color(0.96, 0.96, 0.93)
const BAND_BLUE := Color(0.1, 0.45, 1.0)


## A cover stack of toilet rolls `size` (x, height, z), standing on the floor at its origin: solid (layer 1, a box the size of the
## stack), white rolls in a grid (one MultiMesh), a glowing blue band round the middle (SPEC Stage 4 plan (2)).
static func make_stack(size: Vector3) -> StaticBody3D:
	var s := StaticBody3D.new()
	s.name = "PaperStack"
	s.collision_layer = 1
	s.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y / 2.0, 0.0)
	s.add_child(shape)
	var nx := maxi(roundi(size.x / ROLL), 1)
	var ny := maxi(roundi(size.y / ROLL), 1)
	var nz := maxi(roundi(size.z / ROLL), 1)
	var roll := CylinderMesh.new()
	roll.top_radius = size.x / nx * 0.49
	roll.bottom_radius = roll.top_radius
	roll.height = size.y / ny * 0.97
	roll.radial_segments = 12
	roll.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STACK_WHITE
	mat.emission_enabled = true
	mat.emission = STACK_WHITE
	mat.emission_energy_multiplier = 0.25
	roll.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = roll
	mm.instance_count = nx * ny * nz
	var sz := (size.z / nz) / (size.x / nx) # squash the roll to its cell when the grid is not square
	var k := 0
	for iy in ny:
		for ix in nx:
			for iz in nz:
				var at := Vector3(-size.x / 2.0 + size.x / nx * (ix + 0.5), size.y / ny * (iy + 0.5), -size.z / 2.0 + size.z / nz * (iz + 0.5))
				mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, sz)), at))
				k += 1
	var rolls := MultiMeshInstance3D.new()
	rolls.name = "Rolls"
	rolls.multimesh = mm
	s.add_child(rolls)
	var band := BoxMesh.new()
	band.size = Vector3(size.x + 0.02, 0.1, size.z + 0.02)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = BAND_BLUE
	bmat.emission_enabled = true
	bmat.emission = BAND_BLUE
	bmat.emission_energy_multiplier = 1.2
	band.material = bmat
	var b := MeshInstance3D.new()
	b.name = "Band"
	b.mesh = band
	b.position = Vector3(0.0, size.y * 0.55, 0.0)
	s.add_child(b)
	return s
