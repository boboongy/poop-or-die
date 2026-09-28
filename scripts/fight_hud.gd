extends CanvasLayer
## Level 4 fight HUD, Street Fighter style (SPEC "Level 4"): two named health bars either side of the level timer (they
## drain toward the outer edges, with a lagging damage trail), Bob's super meter under his bar with SUPER READY, the big
## announcer text (ROUND n, FIGHT!, FINISH HIM!, K.O., TOILETALITY!), an N HITS COMBO counter on the attacker's side and a
## controls line at the bottom. Built in code; fight.gd creates it, feeds it every frame and frees it after the fight.

const Fighter := preload("res://scripts/fighter.gd")

const BAR_TOP := 64.0
const BAR_HEIGHT := 26.0
const TIMER_GAP := 110.0 ## half the space left for the level timer between the bars
const EDGE := 40.0
const TRAIL_DELAY := 0.4 ## the red damage trail waits, then slides down to the bar
const TRAIL_SPEED := 0.8 ## bar widths per second
const COMBO_SECONDS := 1.5
const YELLOW := Color(1.0, 0.85, 0.1)
const TRAIL := Color(0.9, 0.1, 0.05)
const METER := Color(0.2, 0.6, 1.0)
const GOLD := Color(1.0, 0.75, 0.0)

var left_name: Label
var right_name: Label
var left_fill: ColorRect
var right_fill: ColorRect
var left_trail: ColorRect
var right_trail: ColorRect
var meter_fill: ColorRect
var super_ready: Label
var big: Label
var combo_label: Label
var controls: Label
var special_label: Label ## "FLURRY!" etc. when Bob starts a special
var crosshair: Label ## water fight only
var hurt: ColorRect ## water fight only: a blue wash while BOSSY's stream is on Bob

var _meter_parts: Array = [] ## the super meter's frame and labels (hidden in the water fight)

var _trail_wait := [0.0, 0.0]
var _combo_left := 0.0
var _big_tween: Tween
var _special_tween: Tween
var _time := 0.0


func _init() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# health bars: left = Bob (anchored on the left edge), right = the cutter (anchored on the right edge)
	var lb := _bar_frame(root, 0.0, 0.5, EDGE, -TIMER_GAP, BAR_TOP, BAR_HEIGHT)
	left_trail = _rect(lb, TRAIL)
	left_fill = _rect(lb, YELLOW)
	var rb := _bar_frame(root, 0.5, 1.0, TIMER_GAP, -EDGE, BAR_TOP, BAR_HEIGHT)
	right_trail = _rect(rb, TRAIL)
	right_fill = _rect(rb, YELLOW)
	left_name = _label(root, 26, Color.WHITE)
	left_name.position = Vector2(EDGE, BAR_TOP + BAR_HEIGHT + 2.0)
	right_name = _label(root, 26, Color.WHITE)
	right_name.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_name.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_name.offset_right = -EDGE
	right_name.offset_top = BAR_TOP + BAR_HEIGHT + 2.0
	# super meter: bottom left, like Street Fighter
	var mb := _bar_frame(root, 0.0, 0.3, EDGE, 0.0, -70.0, 14.0, 1.0)
	meter_fill = _rect(mb, METER)
	var meter_name := _label(root, 18, METER.lightened(0.4))
	meter_name.text = "SUPER"
	meter_name.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	meter_name.offset_left = EDGE
	meter_name.offset_top = -98.0
	super_ready = _label(root, 22, GOLD)
	super_ready.text = "SUPER READY  [S D S D SPACE]"
	super_ready.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	super_ready.offset_left = EDGE + 80.0
	super_ready.offset_top = -100.0
	super_ready.visible = false
	_meter_parts = [mb.get_parent(), meter_name, super_ready]
	# water fight: a blue wash when Bob is hit, and the crosshair (behind the announcer text)
	hurt = ColorRect.new()
	hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt.color = Color(0.05, 0.3, 1.0, 0.0) # deep blue: a pale one vanished in the pale green room (screenshot)
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt.visible = false
	root.add_child(hurt)
	crosshair = _label(root, 34, Color.WHITE, 6)
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	crosshair.visible = false
	# announcer text, centre screen
	big = _label(root, 110, Color.WHITE, 16)
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.pivot_offset = Vector2(640.0, 360.0)
	big.visible = false
	# combo counter, on the attacker's side
	combo_label = _label(root, 46, Color(1.0, 0.55, 0.1), 10)
	combo_label.anchor_top = 0.3
	combo_label.anchor_bottom = 0.3
	combo_label.visible = false
	controls = _label(root, 18, Color(1, 1, 1, 0.85))
	# keyboard only (owner 2026-09-25); "forward" = toward the foe, Bob starts on the left so it reads as D
	controls.text = "A/D move   hold back = block   S crouch   W jump   SPACE punch (tap fast = combo)   D+SPACE kick   S+SPACE sweep   SPACE in the air = jump kick\nS D SPACE  FLURRY     D S D SPACE  UPPERCUT     S A SPACE  SPIN KICK     S D S D SPACE  SUPER (full meter)"
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT) # bottom right: centred, it ran into the SUPER meter (screenshot)
	controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.offset_left = -EDGE
	controls.offset_right = -EDGE
	controls.offset_top = -12.0
	controls.offset_bottom = -12.0
	# a special's name, just under Bob's health bar
	special_label = _label(root, 40, GOLD, 10)
	special_label.position = Vector2(EDGE, BAR_TOP + BAR_HEIGHT + 40.0)
	special_label.visible = false


func setup(bob_name: String, foe_name: String) -> void:
	left_name.text = bob_name
	right_name.text = foe_name


## Called by fight.gd every physics frame.
func update(bob: Fighter, foe: Fighter, delta: float) -> void:
	_time += delta
	var lr := clampf(bob.hp / bob.max_hp, 0.0, 1.0)
	var rr := clampf(foe.hp / foe.max_hp, 0.0, 1.0)
	left_fill.anchor_right = lr
	right_fill.anchor_left = 1.0 - rr
	# trails: jump up at once if healed, wait then slide down after damage
	var lt := _trail(0, left_trail.anchor_right, lr, delta)
	left_trail.anchor_right = lt
	right_trail.anchor_left = 1.0 - _trail(1, 1.0 - right_trail.anchor_left, rr, delta)
	for r: ColorRect in [left_fill, left_trail, right_fill, right_trail]:
		r.offset_left = 0.0
		r.offset_right = 0.0
	var m := clampf(bob.meter / Fighter.METER_MAX, 0.0, 1.0)
	meter_fill.anchor_right = m
	meter_fill.offset_right = 0.0
	var full := m >= 1.0
	super_ready.visible = full
	meter_fill.color = GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 12.0)) if full else METER
	if _combo_left > 0.0:
		_combo_left -= delta
		combo_label.modulate.a = clampf(_combo_left / 0.4, 0.0, 1.0)
		if _combo_left <= 0.0:
			combo_label.visible = false


## BOSSY's water fight: the right bar becomes BOSSY's blue WET meter (fills from the outer edge), no super meter, own controls line.
func water_mode(foe_name: String) -> void:
	right_name.text = foe_name + "   WET"
	right_fill.color = METER
	right_trail.visible = false
	for n: Control in _meter_parts:
		n.visible = false
	controls.text = "WASD move   Mouse aim   E pick up the gun   Hold left click spray   Shift run"


## Called by water_fight.gd every physics frame. `aiming`: Bob holds the gun (crosshair on); `hit`: he is in BOSSY's stream.
func update_water(bob_ratio: float, wet: float, aiming: bool, hit: bool, delta: float) -> void:
	_time += delta
	var lr := clampf(bob_ratio, 0.0, 1.0)
	left_fill.anchor_right = lr
	left_trail.anchor_right = _trail(0, left_trail.anchor_right, lr, delta)
	right_fill.anchor_left = 1.0 - clampf(wet, 0.0, 1.0)
	for r: ColorRect in [left_fill, left_trail, right_fill]:
		r.offset_left = 0.0
		r.offset_right = 0.0
	crosshair.visible = aiming and big.visible == false
	hurt.visible = hit
	hurt.color.a = 0.28 + 0.08 * sin(_time * 20.0) if hit else 0.0


func _trail(i: int, shown: float, target: float, delta: float) -> float:
	if target >= shown:
		_trail_wait[i] = TRAIL_DELAY
		return target
	if _trail_wait[i] > 0.0:
		_trail_wait[i] -= delta
		return shown
	return maxf(target, shown - TRAIL_SPEED * delta)


## A landed hit: restart the trail delay on the victim's bar, and show the attacker's combo count from 2 hits up.
func on_hit(by_bob: bool, combo: int, blocked: bool) -> void:
	_trail_wait[1 if by_bob else 0] = TRAIL_DELAY
	if blocked or combo < 2:
		return
	combo_label.text = "%d HITS\nCOMBO!" % combo
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if by_bob else HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.anchor_left = 0.0 if by_bob else 1.0
	combo_label.anchor_right = combo_label.anchor_left
	combo_label.grow_horizontal = Control.GROW_DIRECTION_END if by_bob else Control.GROW_DIRECTION_BEGIN
	combo_label.offset_left = EDGE if by_bob else -EDGE
	combo_label.offset_right = combo_label.offset_left
	combo_label.visible = true
	combo_label.modulate.a = 1.0
	_combo_left = COMBO_SECONDS


## A special's name under Bob's bar, for about a second.
func show_special(text: String) -> void:
	special_label.text = text
	special_label.visible = true
	special_label.modulate.a = 1.0
	if _special_tween:
		_special_tween.kill()
	_special_tween = create_tween()
	_special_tween.tween_interval(0.8)
	_special_tween.tween_property(special_label, "modulate:a", 0.0, 0.3)
	_special_tween.tween_callback(func() -> void: special_label.visible = false)


## Big centre text with a pop-in. `hold` 0 = stays until the next announce/clear_big.
func announce(text: String, color: Color, hold: float = 0.0, pulse: bool = false) -> void:
	big.text = text
	big.add_theme_color_override("font_color", color)
	big.visible = true
	big.modulate.a = 1.0
	big.pivot_offset = big.size / 2.0
	if _big_tween:
		_big_tween.kill()
	_big_tween = create_tween()
	_big_tween.tween_property(big, "scale", Vector2.ONE, 0.18).from(Vector2.ONE * 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if pulse:
		_big_tween.tween_property(big, "scale", Vector2.ONE * 1.08, 0.25)
		_big_tween.tween_property(big, "scale", Vector2.ONE, 0.25)
		_big_tween.set_loops()
	elif hold > 0.0:
		_big_tween.tween_interval(hold)
		_big_tween.tween_property(big, "modulate:a", 0.0, 0.25)
		_big_tween.tween_callback(func() -> void: big.visible = false)


func clear_big() -> void:
	if _big_tween:
		_big_tween.kill()
	big.visible = false


## After the fight: the bars go at once, the last announcement fades, then the HUD frees itself.
func finish(fade_seconds: float) -> void:
	for c in get_child(0).get_children():
		if c != big:
			c.visible = false
	if _big_tween:
		_big_tween.kill()
	var tw := create_tween()
	tw.tween_property(big, "modulate:a", 0.0, fade_seconds)
	tw.tween_callback(queue_free)


## A dark framed bar; returns the INNER area (put the fills in it). `a_top` 0 = `top` from the screen top, 1 = from the bottom.
func _bar_frame(parent: Control, a_left: float, a_right: float, off_left: float, off_right: float, top: float, height: float,
		a_top: float = 0.0) -> Control:
	var frame := ColorRect.new()
	frame.color = Color(0.0, 0.0, 0.0, 0.75)
	frame.anchor_left = a_left
	frame.anchor_right = a_right
	frame.anchor_bottom = a_top
	frame.anchor_top = a_top
	frame.offset_left = off_left - 3.0
	frame.offset_right = off_right + 3.0
	frame.offset_top = top - 3.0
	frame.offset_bottom = top + height + 3.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 3.0
	inner.offset_right = -3.0
	inner.offset_top = 3.0
	inner.offset_bottom = -3.0
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)
	return inner


func _rect(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(parent: Control, size: int, color: Color, outline: int = 6) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
