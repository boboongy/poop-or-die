extends SceneTree
## Level 4 fight HUD (scripts/fight_hud.gd via scripts/fight.gd), real level, real input: ROUND n / FIGHT! intro that locks
## the controls, named health bars that follow hp (with a lagging damage trail), the super meter + SUPER READY, the N HIT
## COMBO counter, FINISH HIM!, TOILETALITY!, K.O., the level's own HUD hidden during the fight and back after it.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Fight := preload("res://scripts/fight.gd")
const Fighter := preload("res://scripts/fighter.gd")

const CENTER := Vector3(11.5, 0.0, -2.5)
const AXIS := Vector3(0.0, 0.0, -1.0)

var lvl: Node
var p: CharacterBody3D


func _fight(finishable: bool, ai: bool, intro: bool, round_number: int = 1) -> Node:
	var npc: Node3D = lvl.population.spawn_walker(CENTER + AXIS * 2.0, 0.0)
	lvl.population.walkers.erase(npc)
	var f: Node = Fight.new()
	lvl.add_child(f)
	f.ai_enabled = ai
	if not intro:
		f.intro_seconds = 0.0
	f.hide_nodes = [lvl.get_node("HUD/MissionLabel")]
	f.start(p, npc, CENTER, AXIS, "CUTTER", 30.0, finishable, 1, 1, round_number)
	await process_frame
	return f


func _clear(f: Node) -> void:
	var npc: Node = f.foe_body
	f.abort()
	f.queue_free()
	npc.queue_free()
	await T.wait(self, 0.1)


func _init() -> void:
	seed(1)
	Progress.level = 1
	lvl = T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	p = lvl.player
	var mission: CanvasItem = lvl.get_node("HUD/MissionLabel")

	# 1. intro: ROUND 2 then FIGHT!, controls locked until it ends; names on the bars; the level's mission text hidden
	var f: Node = await _fight(false, false, true, 2)
	var hud: Node = f.hud
	T.check(hud != null and hud.big.visible and hud.big.text == "ROUND 2", "intro shows 'ROUND 2' (got '%s')" % hud.big.text)
	T.check(hud.left_name.text == "BOB" and hud.right_name.text == "CUTTER", "bars are named BOB / CUTTER")
	T.check(not mission.visible, "the level's mission text is hidden during the fight")
	await T.key(self, KEY_SPACE)
	await T.wait(self, 0.1)
	T.check(f.bob.state == Fighter.State.IDLE, "J during the intro does nothing")
	await T.wait_for(self, func() -> bool: return hud.big.text == "FIGHT!", 2.0)
	T.check(hud.big.text == "FIGHT!", "then 'FIGHT!'")
	await T.wait_for(self, func() -> bool: return f.fighting(), 2.0)
	T.check(f.fighting(), "the fight starts after the intro")

	# 2. health bars follow hp; the damage trail lags behind, then catches up
	f.foe.max_hp = 1000.0
	f.foe.hp = 1000.0
	f.foe.pos = f.bob.pos + 0.7
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.foe.hp < 1000.0, 1.5)
	await T.wait(self, 0.05)
	var ratio: float = f.foe.hp / f.foe.max_hp
	T.check(absf(hud.right_fill.anchor_left - (1.0 - ratio)) < 0.002, "the cutter's bar shows hp %.3f (anchor %.3f)" % [ratio, 1.0 - hud.right_fill.anchor_left])
	T.check(hud.right_trail.anchor_left < hud.right_fill.anchor_left - 0.001, "the damage trail is still longer than the bar just after the hit")
	await T.wait(self, 1.5)
	T.check(absf(hud.right_trail.anchor_left - hud.right_fill.anchor_left) < 0.002, "the trail catches up")
	f.bob.hp = 60.0
	await T.wait(self, 0.05)
	T.check(absf(hud.left_fill.anchor_right - 0.6) < 0.002, "Bob's bar shows 60%% (anchor %.3f)" % hud.left_fill.anchor_right)
	f.bob.hp = 100.0
	await T.wait(self, 0.8)

	# 3. combo counter: the combo's 6 hits show '6 HITS'; a lone punch shows no counter
	await T.key(self, KEY_SPACE)
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.bob.combo >= 6, 3.0)
	await T.wait(self, 0.05)
	T.check(hud.combo_label.visible and hud.combo_label.text.begins_with("6 HITS"), "combo shows '6 HITS' (got '%s', visible %s)" % [hud.combo_label.text, hud.combo_label.visible])
	await T.wait(self, 2.5)
	T.check(not hud.combo_label.visible, "the combo counter fades away")
	await T.key(self, KEY_SPACE)
	await T.wait(self, 1.2)
	T.check(not hud.combo_label.visible, "a lone punch shows no combo counter")

	# 4. super meter bar and SUPER READY
	f.bob.meter = 40.0
	await T.wait(self, 0.05)
	T.check(absf(hud.meter_fill.anchor_right - 0.4) < 0.002 and not hud.super_ready.visible, "meter bar at 40%%, no SUPER READY")
	f.bob.meter = Fighter.METER_MAX
	await T.wait(self, 0.05)
	T.check(hud.super_ready.visible, "full meter shows SUPER READY")
	# where it is ON SCREEN (a screenshot found the meter's frame stuck at the top-left while the anchors above looked right)
	await process_frame
	var vh: float = hud.meter_fill.get_viewport_rect().size.y
	var mr: Rect2 = hud.meter_fill.get_global_rect()
	T.check(mr.position.y > vh * 0.8 and mr.size.x > 100.0 and mr.size.y > 5.0, "the full meter bar is drawn at the bottom of the screen (%s, screen h %.0f)" % [mr, vh])
	var lr: Rect2 = hud.left_fill.get_global_rect()
	T.check(lr.position.y < vh * 0.2 and lr.size.x > 100.0, "Bob's health bar is drawn at the top (%s)" % lr)
	await _clear(f)
	T.check(mission.visible, "abort brings the level's mission text back")

	# 5. FINISH HIM!, then TOILETALITY!, then the HUD goes and the level HUD comes back
	f = await _fight(true, false, false)
	hud = f.hud
	f.foe.pos = f.bob.pos + 0.7
	f.foe.hp = 1.0
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.foe.is_dizzy(), 2.0)
	await T.wait(self, 0.05)
	T.check(hud.big.visible and hud.big.text == "FINISH HIM!", "dizzy cutter: 'FINISH HIM!' (got '%s')" % hud.big.text)
	await T.wait(self, 0.5)
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.foe.is_ko(), 4.0)
	await T.wait(self, 0.05)
	T.check(hud.big.text == "TOILETALITY!", "finished: 'TOILETALITY!' (got '%s')" % hud.big.text)
	var hud_ref: WeakRef = weakref(hud) # a lambda capturing the HUD itself errors once it is freed
	await T.wait_for(self, func() -> bool: return hud_ref.get_ref() == null, 5.0)
	T.check(hud_ref.get_ref() == null, "the fight HUD is removed after the fight")
	T.check(mission.visible, "the level's mission text is back after the fight")
	await _clear(f)

	# 6. plain KO (not finishable): 'K.O.'
	f = await _fight(false, false, false)
	hud = f.hud
	f.foe.pos = f.bob.pos + 0.7
	f.foe.hp = 1.0
	await T.key(self, KEY_SPACE)
	await T.wait_for(self, func() -> bool: return f.foe.is_ko(), 2.0)
	await T.wait(self, 0.05)
	T.check(hud.big.text == "K.O.", "plain KO: 'K.O.' (got '%s')" % hud.big.text)
	await T.wait_for(self, func() -> bool: return not f.running, 4.0)
	await _clear(f)

	# 7. Bob KO'd by the AI: 'K.O.' too
	f = await _fight(false, true, false)
	hud = f.hud
	f.bob.hp = 1.0
	await T.wait_for(self, func() -> bool: return f.bob.is_ko(), 12.0)
	await T.wait(self, 0.05)
	T.check(f.bob.is_ko() and hud.big.text == "K.O.", "Bob KO'd: 'K.O.' (got '%s')" % hud.big.text)
	await T.wait_for(self, func() -> bool: return not f.running, 4.0)
	await _clear(f)

	lvl.queue_free()
	await process_frame
	T.finish(self)
