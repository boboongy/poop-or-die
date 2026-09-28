extends Node3D
## Bowl water and the flush. The bowl water is a lit, translucent surface (ripples, a vortex dip, foam
## and a drain hole); a band of streaks on the bowl wall shows water washing around and down.
## Both are created the first time a toilet is used. The seat lid is hidden while a toilet is in use.
## The flush sound plays with the flush and fades out as it ends.
## The surface height and vortex are done in the vertex shader, so the swirl is real geometry.

const SURFACE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float level_offset = 0.0;  // how far the water has risen (+) or drained (-), in metres
uniform float vortex = 0.0;        // 0 = calm, 1 = full whirlpool
uniform float swirl_speed = 0.4;
uniform float ripple = 0.3;
uniform float hole = 0.0;          // radius of the drain hole in the middle (0..1)
uniform float fade = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float ripples(vec2 p, float t) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	return (sin(r * 18.0 - t * 5.0) + sin(ang * 4.0 + r * 7.0 + t * 3.0)) * 0.5 * 0.004 * ripple;
}

void vertex() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float dip = vortex * pow(clamp(1.0 - r, 0.0, 1.0), 2.0) * 0.14;
	VERTEX.y += level_offset - dip + ripples(p, TIME);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < hole) { discard; }
	float e = 0.02;
	float hx = ripples(p + vec2(e, 0.0), TIME) - ripples(p - vec2(e, 0.0), TIME);
	float hz = ripples(p + vec2(0.0, e), TIME) - ripples(p - vec2(0.0, e), TIME);
	vec2 dir = normalize(p + vec2(0.0001));
	float slope = vortex * 2.0 * clamp(1.0 - r, 0.0, 1.0) * 0.14;
	vec3 n = normalize(vec3(-hx * 10.0 - dir.x * slope * 3.0, 1.0, -hz * 10.0 - dir.y * slope * 3.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float ang = atan(p.y, p.x);
	float spiral = sin(ang * 3.0 + (1.0 - r) * 14.0 * vortex + r * 4.0 - TIME * swirl_speed * 6.0);
	float lines = smoothstep(0.7, 1.0, spiral) * (0.25 + 0.75 * vortex);
	float foam = clamp(lines + noise(p * 14.0 + TIME * 0.8) * 0.4 * vortex + smoothstep(0.8, 1.0, r) * 0.2 * ripple, 0.0, 1.0);
	vec3 col = mix(vec3(0.16, 0.5, 0.72), vec3(0.88, 0.97, 1.0), foam);
	ALBEDO = col;
	EMISSION = col * 0.18;
	ALPHA = clamp(mix(0.72, 0.98, foam), 0.0, 1.0) * fade;
	ROUGHNESS = mix(0.05, 0.5, foam);
	SPECULAR = 0.9;
}
"""

const WALL_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float flow = 0.0; // 0 = dry wall, 1 = water washing round and down
uniform float speed = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// UV.x goes round the bowl, UV.y from the rim (0) downward (1): streaks spiral down the wall.
	float around = UV.x * 9.0 + UV.y * 2.2 - TIME * speed;
	float cell = floor(around);
	float s = fract(around);
	float width = 0.35 + 0.5 * hash(vec2(cell, 3.0));
	float streak = smoothstep(0.0, 0.12, s) * (1.0 - smoothstep(width * 0.6, width, s));
	float sheet = 0.3 + 0.7 * streak;
	ALBEDO = mix(vec3(0.5, 0.82, 1.0), vec3(1.0), streak);
	ALPHA = flow * sheet * (1.0 - UV.y * 0.55) * 0.85;
}
"""

const Sfx := preload("res://scripts/sfx.gd")

## A pre-rendered flush (Blender fluid simulation, rendered from the flush camera) played full screen.
## While the file is missing, the flat shader water below is used as a stand-in.
## Spec: FACTORY_TODO.md item 11. Ogg Theora (.ogv), 16:9.
@export var video_path := "res://video/flush.ogv"
@export var video_timeout := 8.0 ## seconds; the clip is 5.5 s
@export var water_height := 0.38
@export var water_forward := 0.06 ## shift toward the front of the bowl (the lid centre is a bit behind the bowl centre)
@export var radius_x := 0.16
@export var radius_z := 0.19

var _toilets := {} ## "row_k" -> {surface: ShaderMaterial, wall: ShaderMaterial, nodes: Node3D}

@onready var _toilet: Node3D = $"../NavRegion/Toilet"


func _lid(row: int, k: int) -> MeshInstance3D:
	return _toilet.find_child("SM_Toilet_R%d_%02d_Lid" % [row, k], true, false) as MeshInstance3D


func set_lid_visible(row: int, k: int, shown: bool) -> void:
	_lid(row, k).visible = shown


func bowl_center(row: int, k: int) -> Vector3:
	var lid := _lid(row, k)
	var box := lid.global_transform * lid.get_aabb()
	var c := box.get_center()
	var front := 1.0 if row == 1 else -1.0 # row 1 toilets face +Z, row 2 face -Z
	return Vector3(c.x, water_height, c.z + front * water_forward)


## Show the bowl water (with the lid up).
func prepare(row: int, k: int) -> void:
	set_lid_visible(row, k, false)
	if not ResourceLoader.exists(video_path):
		_toilet_fx(row, k) # stand-in water; with the rendered flush video there is no game-side water


func _toilet_fx(row: int, k: int) -> Dictionary:
	var key := "%d_%d" % [row, k]
	if _toilets.has(key):
		return _toilets[key]
	var holder := Node3D.new()
	holder.position = bowl_center(row, k)
	add_child(holder)

	var surface_shader := Shader.new()
	surface_shader.code = SURFACE_SHADER
	var surface := ShaderMaterial.new()
	surface.shader = surface_shader
	var surface_mesh := MeshInstance3D.new()
	surface_mesh.mesh = _disc_mesh(radius_x, radius_z, 28, 48)
	surface_mesh.material_override = surface
	holder.add_child(surface_mesh)

	var wall_shader := Shader.new()
	wall_shader.code = WALL_SHADER
	var wall := ShaderMaterial.new()
	wall.shader = wall_shader
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius_x * 1.05
	cyl.bottom_radius = radius_x * 0.8
	cyl.height = 0.1
	cyl.radial_segments = 48
	cyl.cap_top = false
	cyl.cap_bottom = false
	band.mesh = cyl
	band.material_override = wall
	band.position = Vector3(0.0, 0.04, 0.0)
	band.scale = Vector3(1.0, 1.0, radius_z / radius_x)
	holder.add_child(band)

	# A dark drain under the water, only visible once the whirlpool opens a hole in the middle.
	var drain := MeshInstance3D.new()
	var drain_mesh := CylinderMesh.new()
	drain_mesh.top_radius = 0.05
	drain_mesh.bottom_radius = 0.05
	drain_mesh.height = 0.004
	drain.mesh = drain_mesh
	var drain_mat := StandardMaterial3D.new()
	drain_mat.albedo_color = Color(0.02, 0.06, 0.06)
	drain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drain.material_override = drain_mat
	drain.position = Vector3(0.0, -0.07, 0.0)
	drain.transparency = 1.0
	holder.add_child(drain)

	var defaults := {"level_offset": 0.0, "vortex": 0.0, "swirl_speed": 0.4, "ripple": 0.3, "hole": 0.0, "fade": 1.0}
	for param: String in defaults:
		surface.set_shader_parameter(param, defaults[param])
	wall.set_shader_parameter("flow", 0.0)
	var entry := {"surface": surface, "wall": wall, "drain": drain}
	_toilets[key] = entry
	return entry


## A flat polar-grid disc (an ellipse), fine enough for the vortex to bend in the vertex shader.
## UV maps the disc to 0..1 so the shaders can work in centred coordinates.
func _disc_mesh(rx: float, rz: float, rings: int, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings):
		for seg in range(segments):
			var quad: Array[Vector2] = []
			for corner in [[ring, seg], [ring + 1, seg], [ring + 1, seg + 1], [ring, seg + 1]]:
				var r: float = float(corner[0]) / rings
				var a: float = TAU * float(corner[1]) / segments
				quad.append(Vector2(r * cos(a), r * sin(a)))
			for idx in [0, 1, 2, 0, 2, 3]:
				var p := quad[idx]
				st.set_normal(Vector3.UP)
				st.set_uv(p * 0.5 + Vector2(0.5, 0.5))
				st.add_vertex(Vector3(p.x * rx, 0.0, p.y * rz))
	return st.commit()


## Flush (about 5.5 s): the rim wash starts, the water rises a little, whirls and drains through a
## hole in the middle, gurgles, then the bowl refills and calms down.
func flush(row: int, k: int) -> void:
	var sound := Sfx.play_ui(self, "flush")
	if ResourceLoader.exists(video_path):
		await _play_flush_video()
		Sfx.fade_out(sound, 0.5)
		return
	var fx := _toilet_fx(row, k)
	var surface: ShaderMaterial = fx["surface"]
	var wall: ShaderMaterial = fx["wall"]
	var drain: MeshInstance3D = fx["drain"]
	var tween := create_tween()
	# 1. water washes round the rim, the surface gets restless and rises a little
	tween.set_parallel(true)
	tween.tween_property(wall, "shader_parameter/flow", 1.0, 0.6)
	tween.tween_property(surface, "shader_parameter/ripple", 2.5, 0.8)
	tween.tween_property(surface, "shader_parameter/level_offset", 0.025, 0.8)
	tween.tween_property(surface, "shader_parameter/swirl_speed", 1.2, 0.8)
	tween.chain().set_parallel(true)
	# 2. whirlpool forms and the bowl drains
	tween.tween_property(surface, "shader_parameter/vortex", 1.0, 1.2)
	tween.tween_property(surface, "shader_parameter/swirl_speed", 3.0, 1.4)
	tween.tween_property(surface, "shader_parameter/level_offset", -0.085, 1.6)
	tween.tween_property(surface, "shader_parameter/hole", 0.26, 1.6)
	tween.tween_property(drain, "transparency", 0.0, 1.2)
	tween.chain().set_parallel(true)
	# 3. gurgle: the rim wash ends and the last of the water spirals away
	tween.tween_property(wall, "shader_parameter/flow", 0.0, 0.7)
	tween.tween_property(surface, "shader_parameter/swirl_speed", 1.5, 0.7)
	tween.tween_property(surface, "shader_parameter/level_offset", -0.11, 0.7)
	tween.chain().set_parallel(true)
	# 4. refill and calm down
	tween.tween_property(surface, "shader_parameter/vortex", 0.0, 0.9)
	tween.tween_property(surface, "shader_parameter/hole", 0.0, 0.5)
	tween.tween_property(drain, "transparency", 1.0, 0.6)
	tween.tween_property(surface, "shader_parameter/level_offset", 0.0, 1.6)
	tween.tween_property(surface, "shader_parameter/ripple", 0.3, 1.6)
	tween.tween_property(surface, "shader_parameter/swirl_speed", 0.4, 1.6)
	await tween.finished
	Sfx.fade_out(sound, 0.5)


## Full-screen cutscene: the rendered flush dissolves in over the game (no black in between, so the
## screen stays green), plays, and dissolves back out to the live game.
func _play_flush_video() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var player := VideoStreamPlayer.new()
	player.stream = load(video_path)
	player.expand = true
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.modulate.a = 0.0
	layer.add_child(player)
	player.play()

	var fade_in := create_tween()
	fade_in.tween_property(player, "modulate:a", 1.0, 0.35)
	await fade_in.finished
	get_viewport().disable_3d = true # the video covers the screen: don't spend GPU drawing the scene behind it
	var done := [false] # an array, because a lambda cannot reassign a captured variable
	player.finished.connect(func() -> void: done[0] = true)
	var waited := 0.0
	while not done[0] and waited < video_timeout: # never let a video that fails to play freeze the game
		await get_tree().process_frame
		waited += get_process_delta_time()
	get_viewport().disable_3d = false
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_out := create_tween()
	fade_out.tween_property(player, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	layer.queue_free()
