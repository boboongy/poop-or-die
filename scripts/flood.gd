extends Node3D
## One puddle on the floor. In the game (Level 2 "The flood", 2026-09-27) the puddles are what the drained flood leaves behind:
## start_residue(), full at once, not growing (flood_story.gd). The older growing puddles from a clogged toilet (start(index)) or an
## overflowing sink (start_sink(k)), the "Wet floor" level of 2026-09-21, are only used by the tests of the puddle/mop/slip mechanics now.
## A puddle is a small grid of 0.25 m cells around its source (a stall doorway, or the floor in front of a sink); each cell holds a
## wetness 0..1. Cells fill in from the source outwards over GROW_SECONDS until it is about 2.5 m across (RADIUS 1.25 m), then it
## stops. Only mopping dries it: a stroke lowers every cell within STROKE_RADIUS by 1/STROKES, so STROKES strokes on one spot clear it.
## A flat quad with puddle.gdshader draws it; wet_at() is what makes Bob and the Jijios slip.
## The puddle only exists in the corridors and the open east end (is_floor), on the corridor side of its source, never inside or
## under the stalls or the sinks.

const Sfx := preload("res://scripts/sfx.gd")
const SinksScript := preload("res://scripts/sinks.gd")

signal stopped_growing
signal cleaned ## it has stopped growing and the last patch was mopped

const CELL := 0.25
const GRID := 12
const EXTENT := CELL * GRID ## 3.0 m square around the doorway
const RADIUS := 1.25 ## the farthest cell centre from the doorway: about 2.5 m across
const GROW_SECONDS := 20.0
const FILL_SPEED := 0.8 ## wetness per second while a newly reached cell fills
const WET_LIMIT := 0.3 ## wetter than this and you slip
const STROKE_RADIUS := 0.75 ## owner 2026-09-21: mopping took too long, so a bigger patch (was 0.55) ...
const STROKES := 4 ## ... and fewer strokes on one spot to dry it (was 6)
const HEIGHT := 0.012 ## the quad floats just above the floor
const SHADER := preload("res://scripts/puddle.gdshader")
## The toilet is green-lit and white: a dark or grey puddle was only a smudge (owner, 2026-09-21: "I don't see any puddles").
const WATER_DEEP := Color(0.03, 0.22, 0.60)
const WATER_THIN := Color(0.15, 0.50, 0.85)
const WATER_GLOW := 0.6

## Floor rectangles measured from the toilet glb (x, z, width, depth; 2026-09-21): everything inside the shell except the
## waiting room (x < 0) and the solid block of stalls (the chase block at the west end, both rows, the centre wall and the end
## wall: x -0.15..10.65, z -4.1..-1.0). The corridors are z -1.0..0.95 (front) and z -6.1..-4.1 (back), joined by the open east end.
const BOUNDS := Rect2(0.0, -6.1, 12.65, 7.05)
const STALL_BLOCK := Rect2(-0.15, -4.1, 10.8, 3.1)

const COMPLAINTS: Array[String] = [
	"*bang bang*  The toilet's overflowing!! Somebody do something!",
	"It won't stop! There's water everywhere!",
	"*knock knock*  Get a mop! Please!",
]

var level: Node3D
var kind := "toilet" ## "toilet" (a clogged stall) or "sink" (an overflowing basin)
var stall_index := -1 ## toilets: 0-9 first row, 10-19 back row
var sink_number := 0 ## sinks: 1-10
var source := Vector3.ZERO ## the doorway of the clogged stall, or the floor at the front of the sink; on the floor
var dir := 1.0 ## which way the corridor lies from the source along z (+1 first row toilets, -1 back row toilets and sinks)
var active := false
var growing := false
var elapsed := 0.0
var wet := PackedFloat32Array()

var _reach := PackedFloat32Array() ## second at which each cell gets wet (-1: never, not a floor cell)
var _reached := PackedByteArray()
var _filling := PackedByteArray()
var _origin := Vector2.ZERO
var _image: Image
var _texture: ImageTexture
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _sign: Node3D
var _loop: AudioStreamPlayer3D
var _cleaned_sent := false
var _complaining := false
var _sink_on := false ## this puddle's sink tap is running


static func is_floor(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return BOUNDS.has_point(p) and not STALL_BLOCK.has_point(p)


func setup(level_node: Node3D) -> void:
	level = level_node
	_image = Image.create(GRID, GRID, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("wet_map", _texture)
	_material.set_shader_parameter("extent", EXTENT)
	_material.set_shader_parameter("deep_color", WATER_DEEP) # blue and self-lit on purpose: see puddle.gdshader
	_material.set_shader_parameter("thin_color", WATER_THIN)
	_material.set_shader_parameter("glow", WATER_GLOW)
	_material.set_shader_parameter("bounds", Vector4(BOUNDS.position.x, BOUNDS.position.y, BOUNDS.size.x, BOUNDS.size.y))
	_material.set_shader_parameter("block", Vector4(STALL_BLOCK.position.x, STALL_BLOCK.position.y, STALL_BLOCK.size.x, STALL_BLOCK.size.y))
	var plane := PlaneMesh.new()
	plane.size = Vector2(EXTENT, EXTENT)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Puddle"
	_mesh.mesh = plane
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visible = false
	add_child(_mesh)


## Where puddles can come from, measured from the toilet glb (2026-09-21; test_puddles checks them against the real doors and sinks).
const DOOR_X_FIRST := 1.4 ## stall doorway centre, stall 1; the next stalls are DOOR_X_STEP further east
const DOOR_X_STEP := 0.95
const DOOR_Z := [-1.02, -4.08] ## door line of the first row and of the back row
const SINK_Z := 0.6 ## front of the sink basins, where the water runs onto the floor
const MIN_SOURCE_GAP := 2.6 ## two puddles' sources are at least this far apart (a puddle is 2.5 m across), so they never overlap


## The world position (on the floor) where a puddle of this kind and number starts. toilet: 0-19, sink: 1-10.
static func source_of(source_kind: String, number: int) -> Vector3:
	if source_kind == "sink":
		return Vector3(SinksScript.SINK_X_FIRST + SinksScript.SINK_X_STEP * (number - 1), 0.0, SINK_Z)
	return Vector3(DOOR_X_FIRST + DOOR_X_STEP * (number % 10), 0.0, DOOR_Z[0 if number < 10 else 1])


## Clog stall `index` (0-19: 0-9 first row, 10-19 back row) and start this puddle. Can be called again to re-point it.
func start(index: int) -> void:
	_release()
	kind = "toilet"
	stall_index = index
	sink_number = 0
	dir = 1.0 if index < 10 else -1.0
	source = source_of("toilet", index)
	level.population.blocked_stalls.append(index)
	_begin()
	if not _complaining:
		_complain_loop()


## Overflow sink `number` (1-10): the tap runs, the water spills over the basin onto the corridor floor and this puddle starts.
## The tap stays on until the puddle has stopped growing, and no walker washes there meanwhile.
func start_sink(number: int) -> void:
	_release()
	kind = "sink"
	stall_index = -1
	sink_number = number
	dir = -1.0
	source = source_of("sink", number)
	var walkers := level.get_node_or_null("Walkers")
	if walkers != null:
		walkers.block_sink(number)
	level.get_node("Sinks").set_running(number, true)
	_sink_on = true
	_begin()


## Level 2 "The flood": what the drained water leaves behind (SPEC Round 2 Stage 3). A puddle RESIDUE_RADIUS across at `pos`, fully wet
## at once and not growing: no sign, no sound, no complaints. It may lie in the waiting room too (by the drain). `name_text` is its hint.
const RESIDUE_RADIUS := 1.0
## Glossy wet sheen with a faint murk that still reads on green-lit white tile (skill 3c): a grey-green tint, a little self-light and a
## white glint that drifts over it. PROPOSAL, tuned by screenshot.
## Windowed screenshots 2026-09-27 (tests/probe_residue_look.gd, three looks side by side from Bob's camera): a pale grey-green vanished on
## the pale tile; this dark murk with a strong glint read best at 3-5 m.
const RESIDUE_DEEP := Color(0.22, 0.26, 0.16)
const RESIDUE_THIN := Color(0.36, 0.40, 0.26)
const RESIDUE_GLOW := 0.25
const RESIDUE_SPARKLE := 1.2
const WAITING_ROOM := Rect2(-5.15, -2.0, 4.85, 4.0)
var residue_name := ""


func start_residue(pos: Vector3, name_text: String) -> void:
	_release()
	kind = "residue"
	residue_name = name_text
	source = Vector3(pos.x, 0.0, pos.z)
	_origin = Vector2(source.x, source.z) - Vector2(EXTENT, EXTENT) / 2.0
	wet = PackedFloat32Array()
	wet.resize(GRID * GRID)
	_reach = PackedFloat32Array()
	_reach.resize(GRID * GRID)
	_reached = PackedByteArray()
	_reached.resize(GRID * GRID)
	_filling = PackedByteArray()
	_filling.resize(GRID * GRID)
	for j in GRID:
		for i in GRID:
			var c := cell_center(i, j)
			var k := j * GRID + i
			var floor_cell := is_floor(c.x, c.z) or WAITING_ROOM.has_point(Vector2(c.x, c.z))
			var inside := Vector2(c.x - source.x, c.z - source.z).length() <= RESIDUE_RADIUS
			_reach[k] = 0.0 if floor_cell and inside else -1.0
			wet[k] = 1.0 if floor_cell and inside else 0.0
			_reached[k] = 1 if floor_cell and inside else 0
	elapsed = 0.0
	active = true
	growing = false
	_cleaned_sent = false
	_material.set_shader_parameter("bounds", Vector4(-5.3, -6.1, 18.0, 8.1))
	_material.set_shader_parameter("deep_color", RESIDUE_DEEP)
	_material.set_shader_parameter("thin_color", RESIDUE_THIN)
	_material.set_shader_parameter("glow", RESIDUE_GLOW)
	_material.set_shader_parameter("sparkle_color", Color(1.0, 1.0, 0.95))
	_material.set_shader_parameter("sparkle_amount", RESIDUE_SPARKLE)
	_mesh.global_position = Vector3(source.x, HEIGHT, source.z)
	_material.set_shader_parameter("origin", _origin)
	_mesh.visible = true
	_upload()


## A short name for hints: "stall 3 (first row)" or "sink 6".
func label() -> String:
	if kind == "residue":
		return residue_name
	if kind == "sink":
		return "sink %d" % sink_number
	return "stall %d (%s row)" % [stall_index % 10 + 1, "first" if stall_index < 10 else "back"]


## Switch this puddle off completely (tests use it to isolate one puddle).
func clear() -> void:
	_release()
	active = false
	growing = false
	if _mesh != null:
		_mesh.visible = false


## Undo what the last start() did: the sign, the running-water sound, the blocked stall or the running sink.
func _release() -> void:
	_stop_loop()
	if _sign != null:
		_sign.queue_free()
		_sign = null
	if kind == "toilet" and stall_index >= 0:
		level.population.blocked_stalls.erase(stall_index)
	_sink_off()
	stall_index = -1
	sink_number = 0


func _sink_off() -> void:
	if kind != "sink" or not _sink_on:
		return
	_sink_on = false
	level.get_node("Sinks").set_running(sink_number, false)
	var walkers := level.get_node_or_null("Walkers")
	if walkers != null:
		walkers.unblock_sink(sink_number)


## The part of start() and start_sink() that is the same: the cells, the sound, the sign.
func _begin() -> void:
	_origin = Vector2(source.x, source.z) - Vector2(EXTENT, EXTENT) / 2.0
	wet = PackedFloat32Array()
	wet.resize(GRID * GRID)
	_reach = PackedFloat32Array()
	_reach.resize(GRID * GRID)
	_reached = PackedByteArray()
	_reached.resize(GRID * GRID)
	_filling = PackedByteArray()
	_filling.resize(GRID * GRID)
	for j in GRID:
		for i in GRID:
			var c := cell_center(i, j)
			var d := Vector2(c.x - source.x, c.z - source.z).length()
			var k := j * GRID + i
			_reach[k] = -1.0
			if d <= RADIUS and is_floor(c.x, c.z) and (c.z - source.z) * dir >= 0.0: # only on the corridor side of the source
				_reach[k] = maxf(0.0, d - 0.2) / (RADIUS - 0.2) * GROW_SECONDS
	elapsed = 0.0
	active = true
	growing = true
	_cleaned_sent = false
	_mesh.global_position = Vector3(source.x, HEIGHT, source.z)
	_material.set_shader_parameter("origin", _origin)
	_mesh.visible = true
	_loop = Sfx.loop_at(_source_marker(), "flood")
	_make_sign()
	advance(0.0)


## World position (on the floor) of the centre of cell (i, j).
func cell_center(i: int, j: int) -> Vector3:
	return Vector3(_origin.x + (i + 0.5) * CELL, 0.0, _origin.y + (j + 0.5) * CELL)


func _process(delta: float) -> void:
	if active:
		advance(delta)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	# Anyone WALKING onto wet floor slips (running crowds and people standing still do not).
	var walking: Array = level.population.walkers.duplicate()
	for npc: Node3D in level.population.occupants:
		if npc.is_walking():
			walking.append(npc)
	for npc: Node3D in walking:
		if npc.is_walking() and wet_at(npc.global_position):
			npc.slip(Vector3(npc.velocity.x, 0.0, npc.velocity.z))


## Move the flood forward `seconds` (the game calls this every frame; tests use big steps).
func advance(seconds: float) -> void:
	if not active:
		return
	elapsed += seconds
	if growing:
		for k in wet.size():
			if _reach[k] >= 0.0 and _reached[k] == 0 and elapsed >= _reach[k]:
				_reached[k] = 1
				_filling[k] = 1
		if elapsed >= GROW_SECONDS:
			growing = false
			_fade_loop()
			_sink_off() # an overflowing sink stops overflowing when its puddle has stopped growing (the tap goes off)
			stopped_growing.emit()
	for k in wet.size():
		if _filling[k] == 1:
			wet[k] = minf(1.0, wet[k] + FILL_SPEED * seconds)
			if wet[k] >= 1.0:
				_filling[k] = 0
	_upload()
	_check_clean()


## One mop stroke at `point`: every wet cell within STROKE_RADIUS gets 1/6 drier. Returns how many cells it touched.
func mop(point: Vector3) -> int:
	var touched := 0
	for j in GRID:
		for i in GRID:
			var k := j * GRID + i
			if wet[k] <= 0.0:
				continue
			var c := cell_center(i, j)
			if Vector2(c.x - point.x, c.z - point.z).length() > STROKE_RADIUS:
				continue
			_filling[k] = 0
			wet[k] = wet[k] - 1.0 / STROKES
			if wet[k] < 0.01:
				wet[k] = 0.0
			touched += 1
	if touched > 0:
		_upload()
		_check_clean()
	return touched


## How wet the floor is under `p` (0 outside the puddle).
func wetness_at(p: Vector3) -> float:
	if not active:
		return 0.0
	var i := floori((p.x - _origin.x) / CELL)
	var j := floori((p.z - _origin.y) / CELL)
	if i < 0 or j < 0 or i >= GRID or j >= GRID:
		return 0.0
	return wet[j * GRID + i]


func wet_at(p: Vector3) -> bool:
	return wetness_at(p) > WET_LIMIT


## Number of cells that are wet at all.
func wet_cells() -> int:
	var n := 0
	for w in wet:
		if w > 0.0:
			n += 1
	return n


## Number of cells the puddle will cover at its full size (or has covered).
func planned_cells() -> int:
	var n := 0
	for r in _reach:
		if r >= 0.0:
			n += 1
	return n


func is_clean() -> bool:
	return active and not growing and wet_cells() == 0


## Widest distance between two wet cell centres (metres): about 2.5 when the puddle has its full size and the corridor allows.
func wet_span() -> float:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for j in GRID:
		for i in GRID:
			if wet[j * GRID + i] > 0.0:
				var c := cell_center(i, j)
				lo = lo.min(Vector2(c.x, c.z))
				hi = hi.max(Vector2(c.x, c.z))
	return maxf(hi.x - lo.x, hi.y - lo.y) if lo.x != INF else 0.0


func _check_clean() -> void:
	if is_clean() and not _cleaned_sent:
		_cleaned_sent = true
		cleaned.emit()


func _upload() -> void:
	for j in GRID:
		for i in GRID:
			_image.set_pixel(i, j, Color(wet[j * GRID + i], 0.0, 0.0))
	_texture.update(_image)


func _source_marker() -> Node3D:
	var marker := get_node_or_null("Source") as Node3D
	if marker == null:
		marker = Node3D.new()
		marker.name = "Source"
		add_child(marker)
	marker.global_position = source + Vector3(0.0, 0.3, 0.0)
	return marker


func _stop_loop() -> void:
	Sfx.stop_loop(_loop)
	_loop = null


func _fade_loop() -> void:
	Sfx.fade_out(_loop, 1.5)
	_loop = null


## A "wet floor" sign at the edge of the puddle, on the side toward the middle of the corridor. Decoration only:
## no collision and nobody reacts to it (owner, 2026-09-21). Stand-in shape until the factory delivers the prop.
func _make_sign() -> void:
	_sign = Node3D.new()
	_sign.name = "WetFloorSign"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.05)
	mat.roughness = 0.5
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.6, 0.02)
		panel.mesh = box
		panel.material_override = mat
		panel.position = Vector3(0.0, 0.3, 0.08 * side)
		panel.rotation.x = 0.22 * side
		_sign.add_child(panel)
	add_child(_sign)
	var along := 1.0 if source.x < 6.0 else -1.0
	var toward := 0.55 * dir ## a little way into the corridor, out of the doorway line
	_sign.global_position = Vector3(source.x + along * 1.7, 0.0, source.z + toward)
	_sign.rotation.y = PI / 2.0


## The person on the clogged toilet keeps knocking and shouting while there is water on the floor.
func _complain_loop() -> void:
	_complaining = true
	var turn := 0
	await get_tree().create_timer(1.5 + randf() * 3.0).timeout # not while the level is still being built; each toilet starts at its own time
	while is_inside_tree() and active and kind == "toilet" and not is_clean():
		var npc: Node3D = level.population.occupants[stall_index]
		if npc.is_sitting():
			Sfx.knock(npc, npc.global_position + Vector3(0.0, 1.0, 0.0))
			level.dialogue.bubble(npc, COMPLAINTS[turn % COMPLAINTS.size()], 3.0)
		turn += 1
		await get_tree().create_timer(6.0).timeout
	_complaining = false
