extends CanvasLayer
## Stage 4 "WATER WAR" HUD (SPEC "Stage 4 plan" (6)): a dot + 4-line crosshair, HP bottom left, the tank "42 / 60" + a bar bottom right,
## "EMPTY: refill at a sink" when the tank is dry; the hit marker (an X round the crosshair, 0.15 s: white body, red head, bigger on a
## kill); the kill feed top right ("BOB <drop> CREW 2 [HEADSHOT]", the newest 4, each 4 s). The damage numbers live in the world
## (shooter.gd). Slice 3: the brown splats on Bob, the red edge. Slice 5: the ult ring bottom centre (%, "Q" when full, the hose's time
## left) and the "SUPER SOAKER!" shout high up.

const WHITE := Color(1.0, 1.0, 1.0, 0.9)
const TANK_BLUE := Color(0.25, 0.7, 1.0)
const HP_GREEN := Color(0.35, 0.95, 0.4)
const EDGE := 32.0
const MARKER_SECONDS := 0.15
const MARKER_BODY := Color(1.0, 1.0, 1.0)
const MARKER_HEAD := Color(1.0, 0.18, 0.12)
const MARKER_KILL_SCALE := 1.5
const NUMBER_BODY := Color(1.0, 1.0, 1.0)
const NUMBER_HEAD := Color(1.0, 0.85, 0.1)
const FEED_SECONDS := 4.0
const FEED_MAX := 4
const BOB_BLUE := Color(0.4, 0.8, 1.0)
const FOE_ORANGE := Color(1.0, 0.6, 0.25)

const SPLAT_SECONDS := 1.5
const SPLAT_MAX := 8
const SPLAT_BROWN := Color(0.33, 0.19, 0.05, 0.92)
const ULT_R := 44.0 ## the ult ring's radius (px)
const ULT_CHARGING := Color(0.85, 0.9, 1.0)
const ULT_READY := Color(1.0, 0.82, 0.1) ## the gun's yellow

var crosshair: Control
var marker: Control
var feed: VBoxContainer
var splats: Control ## the brown splats on the screen (children)
var splats_made := 0
var edge: TextureRect ## the red screen edge when Bob is low
var big: Label
var fade: ColorRect ## the black cut into round 3 (fade_in)
var _marker_left := 0.0
var hp_label: Label
var hp_fill: ColorRect
var tank_label: Label
var tank_fill: ColorRect
var empty_label: Label
var foes_label: Label ## "CREW 3 · BOSSY", top centre
var ult_ring: Control ## bottom centre: the meter, then the hose's time left
var ult_label: Label ## "42%", or "Q" when full
var _ult_frac := 0.0
var _ult_time := 0.0
var shout_label: Label ## "SUPER SOAKER!": high up, off the crosshair (centred, it hid the target in the first screenshots)
var _shout_left := 0.0

var _empty_time := 0.0


func _init() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# under everything else: the red edge, then the splats (the crosshair and numbers stay readable on top)
	edge = TextureRect.new()
	var grad := Gradient.new()
	grad.set_offset(0, 0.8) # clear to 80 % of the way to the sides (at 55 % it tinted the whole screen, screenshot)
	grad.set_color(0, Color(0.9, 0.0, 0.0, 0.0))
	grad.set_offset(1, 1.15)
	grad.set_color(1, Color(0.95, 0.0, 0.0, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	edge.texture = tex
	edge.stretch_mode = TextureRect.STRETCH_SCALE
	edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.visible = false
	root.add_child(edge)
	splats = Control.new()
	splats.set_anchors_preset(Control.PRESET_FULL_RECT)
	splats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(splats)
	crosshair = _Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	marker = _Marker.new()
	marker.set_anchors_preset(Control.PRESET_CENTER)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.visible = false
	root.add_child(marker)
	feed = VBoxContainer.new()
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	feed.add_theme_constant_override("separation", 4)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	_place(feed, 1.0, 0.0, -EDGE - 420.0, EDGE + 40.0, 420.0, 200.0)
	# HP, bottom left
	hp_label = _label(root, 34, Color.WHITE)
	_place(hp_label, 0.0, 1.0, EDGE, -110.0, 260.0, 44.0)
	hp_fill = _bar(root, 0.0, 1.0, EDGE, -62.0, 260.0, 16.0, HP_GREEN)
	# the tank, bottom right
	tank_label = _label(root, 34, TANK_BLUE.lightened(0.3))
	tank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(tank_label, 1.0, 1.0, -EDGE - 260.0, -110.0, 260.0, 44.0)
	tank_fill = _bar(root, 1.0, 1.0, -EDGE - 260.0, -62.0, 260.0, 16.0, TANK_BLUE)
	empty_label = _label(root, 30, Color(1.0, 0.45, 0.2))
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.text = "EMPTY: refill at a sink"
	_place(empty_label, 0.5, 0.5, -300.0, 70.0, 600.0, 40.0)
	empty_label.visible = false
	big = _label(root, 96, Color.WHITE)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_constant_override("outline_size", 16)
	_place(big, 0.5, 0.5, -500.0, -170.0, 1000.0, 120.0)
	big.visible = false
	# who is left, top centre: "CREW 3 · BOSSY" (BOSSY appears once she walks in)
	foes_label = _label(root, 30, FOE_ORANGE)
	foes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(foes_label, 0.5, 0.0, -300.0, 64.0, 600.0, 40.0) # under the level timer (TimerLabel, y 0-60)
	# the ult ring, bottom centre
	ult_ring = _UltRing.new()
	ult_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ult_ring)
	_place(ult_ring, 0.5, 1.0, -ULT_R - 8.0, -EDGE - 2.0 * ULT_R - 16.0, 2.0 * ULT_R + 16.0, 2.0 * ULT_R + 16.0)
	ult_label = _label(ult_ring, 26, Color.WHITE)
	ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ult_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ult_label.text = "0%"
	shout_label = _label(root, 60, TANK_BLUE.lightened(0.3))
	shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout_label.add_theme_constant_override("outline_size", 12)
	_place(shout_label, 0.5, 0.0, -500.0, 110.0, 1000.0, 80.0) # under the foes line
	shout_label.visible = false


## A short shout high on the screen for `seconds`.
func shout(text: String, seconds: float) -> void:
	shout_label.text = text
	shout_label.visible = true
	_shout_left = seconds


## The ult ring: `frac` of the meter (0..1); while hosing it shows the time left instead, in the hose's colour.
func set_ult(frac: float, hosing: bool, hose_frac: float, delta: float) -> void:
	_ult_frac = clampf(frac, 0.0, 1.0)
	var ring := ult_ring as _UltRing
	if hosing:
		ring.fill = clampf(hose_frac, 0.0, 1.0)
		ring.color = TANK_BLUE.lightened(0.3)
		ring.pulse = 0.0
		ult_label.text = ""
	else:
		ring.fill = _ult_frac
		ring.color = ULT_READY if ult_ready() else ULT_CHARGING
		if ult_ready():
			_ult_time += delta
			ring.pulse = 0.5 + 0.5 * sin(_ult_time * 7.0)
			ult_label.text = "Q"
			ult_label.add_theme_font_size_override("font_size", 40)
		else:
			_ult_time = 0.0
			ring.pulse = 0.0
			ult_label.text = "%d%%" % ult_percent()
			ult_label.add_theme_font_size_override("font_size", 26)
	ring.queue_redraw()


func ult_percent() -> int:
	return floori(_ult_frac * 100.0 + 0.0001)


func ult_ready() -> bool:
	return _ult_frac >= 1.0 - 0.00001


func set_foes(crew_left: int, boss_in: bool) -> void:
	var parts: Array[String] = []
	if crew_left > 0:
		parts.append("CREW %d" % crew_left)
	if boss_in:
		parts.append("BOSSY")
	foes_label.text = " · ".join(parts)


func update(hp: float, hp_max: float, tank: int, tank_max: int, delta: float) -> void:
	hp_label.text = "%d" % ceili(hp)
	(hp_fill.get_meta("fill") as ColorRect).anchor_right = clampf(hp / hp_max, 0.0, 1.0)
	tank_label.text = "%d / %d" % [tank, tank_max]
	(tank_fill.get_meta("fill") as ColorRect).anchor_right = clampf(float(tank) / tank_max, 0.0, 1.0)
	empty_label.visible = tank <= 0
	if empty_label.visible:
		_empty_time += delta
		empty_label.modulate.a = 0.65 + 0.35 * sin(_empty_time * 8.0)
	else:
		_empty_time = 0.0


## The hit marker: white on the body, red on the head, MARKER_KILL_SCALE bigger on a kill.
func show_marker(head: bool, kill: bool) -> void:
	marker.modulate = MARKER_HEAD if head else MARKER_BODY
	marker.scale = Vector2.ONE * (MARKER_KILL_SCALE if kill else 1.0)
	marker.visible = true
	_marker_left = MARKER_SECONDS


## A kill feed line: "BOB <drop> CREW 2 [HEADSHOT]". The text is also the entry's meta "text" (tests read it).
func add_feed(killer: String, victim: String, head: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := "%s 💦 %s" % [killer, victim]
	row.add_child(_feed_label(killer, BOB_BLUE))
	var drop := _Drop.new()
	drop.custom_minimum_size = Vector2(22.0, 28.0)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(drop)
	row.add_child(_feed_label(victim, FOE_ORANGE))
	if head:
		text += " [HEADSHOT]"
		row.add_child(_feed_label("[HEADSHOT]", MARKER_HEAD))
	row.set_meta("text", text)
	row.set_meta("age", 0.0)
	feed.add_child(row)
	while feed.get_child_count() > FEED_MAX:
		var old := feed.get_child(0)
		feed.remove_child(old)
		old.queue_free()


## A brown splat at a random screen spot, 15-30 % of the screen's height across; it fades over SPLAT_SECONDS; the newest SPLAT_MAX stay.
func splat(rng: RandomNumberGenerator) -> void:
	var view := splats.get_viewport_rect().size
	var s := _Splat.new()
	s.radius = view.y * rng.randf_range(0.075, 0.15)
	s.shape_seed = rng.randi()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = Vector2(rng.randf_range(0.1, 0.9) * view.x, rng.randf_range(0.12, 0.88) * view.y)
	s.set_meta("age", 0.0)
	splats.add_child(s)
	splats_made += 1
	while splats.get_child_count() > SPLAT_MAX:
		var old := splats.get_child(0)
		splats.remove_child(old)
		old.queue_free()


func low_hp(on: bool) -> void:
	edge.visible = on


func announce(text: String, color: Color) -> void:
	big.text = text
	big.add_theme_color_override("font_color", color)
	big.visible = true


func hide_announce() -> void:
	big.visible = false


## Black over everything, fading out over `seconds` (the cut into round 3).
func fade_in(seconds: float) -> void:
	if fade == null:
		fade = ColorRect.new()
		fade.color = Color.BLACK
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fade)
	fade.modulate.a = 1.0
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, seconds)
	tw.tween_callback(fade.hide)


func _process(delta: float) -> void:
	if _shout_left > 0.0:
		_shout_left -= delta
		if _shout_left <= 0.0:
			shout_label.visible = false
	for s in splats.get_children():
		var age: float = float(s.get_meta("age")) + delta
		s.set_meta("age", age)
		s.modulate.a = clampf((SPLAT_SECONDS - age) / (SPLAT_SECONDS * 0.7), 0.0, 1.0) # holds, then fades
		if age >= SPLAT_SECONDS:
			splats.remove_child(s)
			s.queue_free()
	if edge.visible:
		edge.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
	if _marker_left > 0.0:
		_marker_left -= delta
		if _marker_left <= 0.0:
			marker.visible = false
	for row in feed.get_children():
		var age: float = float(row.get_meta("age")) + delta
		row.set_meta("age", age)
		row.modulate.a = clampf((FEED_SECONDS - age) / 0.4, 0.0, 1.0) # fades out over its last 0.4 s
		if age >= FEED_SECONDS:
			feed.remove_child(row)
			row.queue_free()


static func _feed_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


## A bar: a dark frame with a coloured fill (the frame's meta "fill"); the fill's anchor_right is the ratio.
static func _bar(parent: Control, ax: float, ay: float, x: float, y: float, w: float, h: float, color: Color) -> ColorRect:
	var frame := ColorRect.new()
	frame.color = Color(0.0, 0.0, 0.0, 0.55)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_place(frame, ax, ay, x, y, w, h)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = 1.0
	fill.offset_left = 2.0
	fill.offset_top = 2.0
	fill.offset_bottom = -2.0
	frame.add_child(fill)
	frame.set_meta("fill", fill)
	return frame


## The crosshair: a dot and four short lines with a gap, outlined so it reads on white tile.
class _Crosshair extends Control:
	const GAP := 7.0
	const LENGTH := 9.0

	func _draw() -> void:
		for pass_i in 2:
			var col := Color(0.0, 0.0, 0.0, 0.6) if pass_i == 0 else Color.WHITE
			var w := 4.0 if pass_i == 0 else 2.0
			draw_circle(Vector2.ZERO, 2.5 if pass_i == 0 else 1.6, col)
			for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(d * GAP, d * (GAP + LENGTH), col, w)


## The ult ring: a dark disc, a thin track, the filled arc clockwise from the top; a glow ring when `pulse` > 0 (ready).
class _UltRing extends Control:
	var fill := 0.0
	var color := Color.WHITE
	var pulse := 0.0

	func _draw() -> void:
		var c := size / 2.0
		var r := ULT_R
		draw_circle(c, r + 6.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.18), 7.0, true)
		if fill > 0.001:
			draw_arc(c, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * fill, maxi(int(64 * fill), 2), color, 7.0, true)
		if pulse > 0.0:
			draw_arc(c, r + 5.0, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.35 + 0.5 * pulse), 3.0 + 3.0 * pulse, true)


## The hit marker: four diagonal strokes round the crosshair, drawn white (the node's modulate colours it) with a dark outline.
class _Marker extends Control:
	const INNER := 10.0
	const OUTER := 22.0

	func _draw() -> void:
		for pass_i in 2:
			var col := Color(0.0, 0.0, 0.0, 0.7) if pass_i == 0 else Color.WHITE
			var w := 6.0 if pass_i == 0 else 3.0
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var n := d.normalized()
				draw_line(n * INNER, n * OUTER, col, w)


## A brown splat drawn round its position: a lumpy blob, a few drips running down, some flecks. Its shape comes from `shape_seed`.
class _Splat extends Control:
	var radius := 60.0
	var shape_seed := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = shape_seed
		var col := SPLAT_BROWN
		var pts := PackedVector2Array()
		var n := 18
		for i in n:
			var a := TAU * i / n
			pts.append(Vector2(cos(a), sin(a)) * radius * rng.randf_range(0.7, 1.15))
		draw_colored_polygon(pts, col)
		for i in rng.randi_range(2, 4): # drips
			var x := rng.randf_range(-0.6, 0.6) * radius
			var w := rng.randf_range(0.08, 0.16) * radius
			var l := rng.randf_range(0.6, 1.4) * radius
			draw_rect(Rect2(x - w / 2.0, 0.0, w, radius * 0.6 + l), col)
			draw_circle(Vector2(x, radius * 0.6 + l), w * 0.75, col)
		for i in rng.randi_range(4, 8): # flecks
			var a := rng.randf() * TAU
			draw_circle(Vector2(cos(a), sin(a)) * radius * rng.randf_range(1.2, 1.7), radius * rng.randf_range(0.05, 0.14), col)
		draw_circle(Vector2(-0.25, -0.3) * radius, radius * 0.18, Color(0.55, 0.36, 0.14, 0.5)) # a wet highlight


## The kill feed's water drop (the default font has no emoji): a blue drop, point up.
class _Drop extends Control:
	func _draw() -> void:
		var c := size / 2.0 + Vector2(0.0, 4.0)
		var r := minf(size.x, size.y) * 0.32
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			pts.append(c + Vector2(cos(a) * r, sin(a) * r)) # the round bottom
		pts.append(c + Vector2(0.0, -r * 2.2)) # the point
		draw_colored_polygon(pts, Color(0.25, 0.7, 1.0))
		pts.append(pts[0])
		draw_polyline(pts, Color.BLACK, 1.5)
