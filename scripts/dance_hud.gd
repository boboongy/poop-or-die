extends CanvasLayer
## Level 5: the dance battle's screen. Big announcements ("DANCE BATTLE!", "ROUND 2", "YOUR TURN!"), a banner line at the bottom, and
## (with `battle` set) the rhythm lanes on the left: four arrows (left, down, up, right) rising from the bottom to the line near the top,
## hers in pink during her turn, PERFECT / GOOD / MISS under the line, the combo, and the scoreboard at the top right.

const Battle := preload("res://scripts/dance_battle.gd")

const LANE_COLORS := [Color(1.0, 0.25, 0.8), Color(0.2, 0.9, 1.0), Color(0.55, 1.0, 0.3), Color(1.0, 0.6, 0.1)]
const LANE_TURN := [-PI / 2.0, PI, 0.0, PI / 2.0] ## the up-pointing arrow turned for left, down, up, right
const LANE_W := 78.0
const LANES_X := 36.0
const LINE_Y := 118.0
const ARROW := 30.0
const QUEEN_TINT := Color(1.0, 0.35, 0.75, 0.55)
const JUDGE_COLORS := {"PERFECT": Color(1.0, 0.85, 0.15), "GREAT": Color(0.3, 0.9, 1.0), "GOOD": Color(0.4, 1.0, 0.5),
	"EARLY": Color(1.0, 0.55, 0.15), "LATE": Color(1.0, 0.55, 0.15), "MISS": Color(1.0, 0.25, 0.25)}
## Stage 7 E1: the combo from 2 hits, bigger and a new colour as it grows; confetti at these combos (the crowd cheers, dance.gd)
const COMBO_FROM := 2
const COMBO_COLORS := [Color(1.0, 1.0, 1.0), Color(0.3, 0.9, 1.0), Color(0.55, 1.0, 0.3), Color(1.0, 0.85, 0.15), Color(1.0, 0.45, 0.1), Color(1.0, 0.25, 0.8)]
const CONFETTI_AT := [5, 10]
const HIT_RESULTS := ["PERFECT", "GREAT", "GOOD"]

var confetti_bursts := 0 ## tests
var combo_shown := "" ## the combo text on screen (tests)

var announced := "" ## the last announcement's text (tests)
var battle ## dance_battle.gd, or null outside the battle

var _big: Label
var _banner: Label
var _lanes: Control
var _judge: Label
var _combo: Label
var _score: Label
var _flash := [0.0, 0.0, 0.0, 0.0] ## per lane: seconds of receptor glow left


func _ready() -> void:
	layer = 6
	_lanes = Control.new()
	_lanes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lanes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lanes.draw.connect(_draw_lanes)
	add_child(_lanes)
	_judge = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_judge.position = Vector2(LANES_X, LINE_Y + 50.0)
	_judge.size = Vector2(LANE_W * 4.0, 60.0)
	_combo = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_combo.position = Vector2(LANES_X, LINE_Y + 110.0)
	_combo.size = Vector2(LANE_W * 4.0, 60.0)
	_combo.pivot_offset = _combo.size / 2.0
	# explicit anchors + offsets: a preset plus `position` left the scoreboard off screen and the big text in the top-left corner
	_score = _label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_score, Vector4(1.0, 0.0, 1.0, 0.0), Vector4(-470.0, 14.0, -20.0, 140.0))
	_banner = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_banner, Vector4(0.0, 1.0, 1.0, 1.0), Vector4(0.0, -70.0, 0.0, -20.0))
	_big = _label(96, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_big, Vector4(0.0, 0.0, 1.0, 1.0), Vector4.ZERO)
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.visible = false


## anchors = (left, top, right, bottom) as fractions of the screen; offsets in pixels from them.
static func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


## The right edge of the lanes panel in pixels (crowd shouts stay right of it).
static func lanes_right() -> float:
	return LANES_X + LANE_W * 4.0 + 8.0


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", maxi(8, int(font_size / 4.0)))
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## A big word in the middle of the screen that pops in and fades after `seconds`.
func announce(text: String, color: Color, seconds := 1.2) -> void:
	announced = text
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.visible = true
	_big.modulate.a = 1.0
	_big.pivot_offset = _big.size / 2.0
	_big.scale = Vector2.ONE * 1.6
	var tw := create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(_big, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: _big.visible = false)


## The line at the bottom of the screen ("" hides it).
func banner(text: String) -> void:
	_banner.text = text


func on_judged(lane: int, result: String) -> void:
	_judge.text = result
	_judge.add_theme_color_override("font_color", JUDGE_COLORS.get(result, Color.WHITE))
	_judge.modulate.a = 1.0
	create_tween().tween_property(_judge, "modulate:a", 0.0, 0.5).set_delay(0.15)
	if result in HIT_RESULTS:
		_flash[lane] = 0.15
	var b = battle
	var n: int = b.combo if b != null and is_instance_valid(b) else 0
	if n >= COMBO_FROM and result in HIT_RESULTS:
		_show_combo(n)
	elif not result in HIT_RESULTS:
		_combo.text = ""
		combo_shown = ""


## "NX COMBO!": pops up bigger (a bounce) on every hit, grows with the combo and changes colour every 3.
func _show_combo(n: int) -> void:
	combo_shown = "%dX COMBO!" % n
	_combo.text = combo_shown
	_combo.add_theme_color_override("font_color", COMBO_COLORS[mini((n - COMBO_FROM) / 3, COMBO_COLORS.size() - 1)])
	var size := minf(1.0 + (n - COMBO_FROM) * 0.06, 1.8)
	_combo.scale = Vector2.ONE * size * 1.35
	create_tween().tween_property(_combo, "scale", Vector2.ONE * size, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if n in CONFETTI_AT:
		confetti(n)


## A confetti burst over the lanes (CPUParticles2D: it works in the web build's renderer too).
func confetti(n: int) -> void:
	confetti_bursts += 1
	var p := CPUParticles2D.new()
	p.position = Vector2(LANES_X + LANE_W * 2.0, LINE_Y + 120.0)
	p.amount = 60 if n < 10 else 120
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.6
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 520.0
	p.gravity = Vector2(0.0, 700.0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([LANE_COLORS[0], LANE_COLORS[1], LANE_COLORS[2], LANE_COLORS[3], Color(1.0, 0.85, 0.15)])
	p.color_initial_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _process(delta: float) -> void:
	for k in 4:
		_flash[k] = maxf(_flash[k] - delta, 0.0)
	var b = battle
	if b == null or not is_instance_valid(b):
		_lanes.visible = false
		_score.text = ""
		_combo.text = ""
		return
	_lanes.visible = true
	if b.combo < COMBO_FROM and combo_shown != "": # a MISS that passed by broke it
		_combo.text = ""
		combo_shown = ""
	_score.text = "ROUND %d of 3\nBOB  %d%%   %s\nSHUFFLE QUEEN  %d%%   %s" % [b.round_number,
			roundi(b.accuracy() * 100.0), _pips(b.rounds_bob), roundi(b.queen_accuracy() * 100.0), _pips(b.rounds_queen)]
	_lanes.queue_redraw()


func _pips(n: int) -> String:
	return "[" + "X".repeat(n) + "-".repeat(2 - n) + "]"


func _draw_lanes() -> void:
	var b = battle
	if b == null or not is_instance_valid(b):
		return
	var bottom := _lanes.size.y
	_lanes.draw_rect(Rect2(LANES_X - 8.0, 0.0, LANE_W * 4.0 + 16.0, bottom), Color(0.0, 0.0, 0.05, 0.45))
	var t: float = b.now()
	for lane in 4:
		var x := LANES_X + LANE_W * (lane + 0.5)
		var glow: float = _flash[lane] / 0.15
		if glow > 0.0: # a hit flashes the whole lane in its colour
			var lc: Color = LANE_COLORS[lane]
			_lanes.draw_rect(Rect2(LANES_X + LANE_W * lane, 0.0, LANE_W, bottom), Color(lc.r, lc.g, lc.b, 0.35 * glow))
		_arrow(Vector2(x, LINE_Y), lane, Color(1, 1, 1, 0.35 + 0.65 * glow), false)
	var travel := bottom - LINE_Y
	if b.phase == "queen" or b.phase == "intro":
		for q: Dictionary in b.queen_notes:
			var dt: float = float(q["t"]) - t
			if not q["done"] and dt <= Battle.APPROACH:
				_arrow(Vector2(LANES_X + LANE_W * (int(q["lane"]) + 0.5), LINE_Y + dt / Battle.APPROACH * travel), q["lane"], QUEEN_TINT, true)
	for note: Dictionary in b.notes:
		var dt: float = float(note["t"]) - t
		if dt > Battle.APPROACH:
			continue
		var y := LINE_Y + dt / Battle.APPROACH * travel
		if note["hit"] in HIT_RESULTS or y < -ARROW:
			continue
		var c: Color = LANE_COLORS[note["lane"]]
		if note["hit"] == "MISS":
			c = Color(0.5, 0.5, 0.5, 0.5)
		_arrow(Vector2(LANES_X + LANE_W * (int(note["lane"]) + 0.5), y), note["lane"], c, true)


## An arrow centred at `at`, pointing the lane's way: filled (a note) or outlined (the target on the line).
func _arrow(at: Vector2, lane: int, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array([Vector2(0, -1), Vector2(0.95, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.95), Vector2(-0.4, 0.95),
			Vector2(-0.4, 0.0), Vector2(-0.95, 0.0)])
	var turn: float = LANE_TURN[lane]
	for i in pts.size():
		pts[i] = at + pts[i].rotated(turn) * ARROW
	if filled:
		_lanes.draw_colored_polygon(pts, color)
		var outline := pts.duplicate()
		outline.append(pts[0])
		_lanes.draw_polyline(outline, Color(0.05, 0.0, 0.08, color.a), 3.0)
	else:
		var outline := pts.duplicate()
		outline.append(pts[0])
		_lanes.draw_polyline(outline, color, 4.0)
