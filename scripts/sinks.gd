extends Node3D
## Water for all 10 sinks: a running stream from the faucet plus a little splash.
## The faucet spout and basin positions were measured from the sink meshes (spout tip 0.92 m high,
## 0.2 m in front of the wall side of the basin).

const SINK_X_FIRST := 1.5
const SINK_X_STEP := 0.95
const SINK_COUNT := 10
const SPOUT := Vector3(0.0, 0.92, 0.80) ## relative to the sink's centre x
const BASIN_BOTTOM_Y := 0.72
const STAND_Z := 0.38 ## where someone stands to use the sink (the basin front is at z 0.6)

const Sfx := preload("res://scripts/sfx.gd")

var _streams: Array[Node3D] = []
var _loops := {} ## sink number -> the looping tap sound while it runs


func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float flow = fract(UV.y * 5.0 - TIME * 3.5);
	float streak = smoothstep(0.0, 0.4, flow) * (1.0 - smoothstep(0.6, 1.0, flow));
	ALBEDO = vec3(0.75, 0.92, 1.0);
	ALPHA = mix(0.45, 0.9, streak);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for k in range(1, SINK_COUNT + 1):
		var x := SINK_X_FIRST + SINK_X_STEP * (k - 1)
		var stream := Node3D.new()
		stream.name = "Stream%02d" % k
		stream.position = Vector3(x, 0.0, 0.0)
		stream.visible = false
		add_child(stream)

		var drop := absf(SPOUT.y - BASIN_BOTTOM_Y)
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.010
		cyl.bottom_radius = 0.016
		cyl.height = drop
		cyl.radial_segments = 8
		mesh.mesh = cyl
		mesh.material_override = mat
		mesh.position = Vector3(0.0, SPOUT.y - drop / 2.0, SPOUT.z)
		stream.add_child(mesh)

		var splash := CPUParticles3D.new()
		splash.position = Vector3(0.0, BASIN_BOTTOM_Y + 0.01, SPOUT.z)
		splash.amount = 14
		splash.lifetime = 0.4
		splash.direction = Vector3.UP
		splash.spread = 55.0
		splash.initial_velocity_min = 0.25
		splash.initial_velocity_max = 0.5
		splash.gravity = Vector3(0.0, -2.0, 0.0)
		var drop_mesh := SphereMesh.new()
		drop_mesh.radius = 0.007
		drop_mesh.height = 0.014
		splash.mesh = drop_mesh
		splash.material_override = mat
		stream.add_child(splash)
		_streams.append(stream)


## Turn sink `k` (1-10) on or off.
func set_running(k: int, running: bool) -> void:
	_streams[k - 1].visible = running
	if running and not _loops.has(k):
		_loops[k] = Sfx.loop_at(_streams[k - 1], "tap")
	elif not running and _loops.has(k):
		Sfx.stop_loop(_loops[k])
		_loops.erase(k)


## Where someone stands to wash at sink `k`, facing +Z (the wall).
func stand_spot(k: int) -> Vector3:
	return Vector3(SINK_X_FIRST + SINK_X_STEP * (k - 1), 0.0, STAND_Z)
