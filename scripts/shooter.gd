extends Node
## Stage 4 "WATER WAR" (SPEC "Stage 4 plan APPROVED 2026-09-27"; numbers PROPOSAL until played): Level 4's round 3 as an Overwatch-style
## first-person shooter. Slice 1: Bob in first person (camera at his eyes, body hidden), the code-built toy gun lower right, automatic
## fire along the crosshair (8 shots/s, blue blobs at 40 m/s, 0.01 rad scatter, 15 m reach, 12 body / 24 head), recoil and the gun's
## kick, the 60-shot tank with a dry click and "EMPTY", crew that take damage and go down. Added to the level as a child.
## The blobs fly from the camera along the crosshair (that path is what hits); each is DRAWN from the muzzle and slides onto that path
## over its first CONVERGE metres, as shooters do, so a shot always lands where the crosshair was.
## Slice 3: the crew's AI (shooter_enemy.gd) and their brown blobs, Bob's hitbox (his collision capsule), HP with regen, the brown
## splats on the screen, the red edge when low, K.O. at 0; Space jumps 0.5 m.
## Slice 4: the arena (4 toilet-paper stacks, an invisible wall across corridor A that only Bob bumps into, every stall door shut,
## the walkers hidden; all undone by abort()), BOSSY walking in once 2 crew are down, and the tank refilling at any of the 10 sinks.
## Slice 5: the SUPER-SOAKER hose: gun damage fills the meter to 300, Q = 5 s of stream (60 dmg/s, 10 m, 0.5 m wide, stops at the first
## enemy or the level, pushes 3 m/s), no tank, the gun silent, Bob at 70 % speed.
## Slice 6 (SPEC "slice 6 details DECIDED"): Level 4's round 3 (cutters.gd calls begin_war()): Bob at START facing east, a fade in and
## INTRO_SECONDS of "ROUND 3" / "WATER WAR!" with everyone locked; BOSSY down = "SOAKED!" + WIN_SECONDS of slow motion, then ended("BOB");
## Bob at 0 = "K.O." for KO_SECONDS, then ended("CREW"); the barks (at most one every BARK_GAP s) and Bob's "SUPER SOAKER!" voice.

signal hit(enemy, head: bool, amount: float, killed: bool, at: Vector3) ## a blob hit an enemy (the HUD's markers, numbers, feed)
signal ended(winner: String, finished: bool) ## like fight.gd: "BOB" or the side that soaked him

const Player := preload("res://scripts/player.gd")
const Props := preload("res://scripts/shooter_props.gd")
const Enemy := preload("res://scripts/shooter_enemy.gd")
const Hud := preload("res://scripts/shooter_hud.gd")
const Cutters := preload("res://scripts/cutters.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Sinks := preload("res://scripts/sinks.gd")

const BOB_HP := 150.0
const TANK := 60
const RATE := 8.0 ## shots per second while the trigger is held
const BLOB_SPEED := 40.0
const SCATTER := 0.01 ## rad: the most a shot strays from the crosshair
const REACH := 15.0
const BODY_DAMAGE := 12.0
const HEAD_DAMAGE := 24.0
const CREW_HP := 100.0
const RECOIL_KICK := 0.012 ## rad up per shot
const RECOIL_RECOVER := 0.2 ## rad/s back down, only as far as the recoil took it up
const GUN_KICK := 0.03 ## m back per shot
const GUN_RETURN := 0.3 ## m/s: the gun slides back to rest
const DRY_CLICK_EVERY := 0.4 ## s between dry clicks while the trigger is held on empty
const CONVERGE := 2.0 ## m: a blob is drawn from the muzzle and meets the crosshair path this far out
const GUN_REST := Vector3(0.24, -0.22, -0.55) ## in camera space: lower right (at 0.42 m it filled a quarter of the screen, first screenshot)
const GUN_TURN := Vector3(0.03, 0.05, 0.0)
const GUN_SCALE := 0.8
const CREW_BROWN := Color(0.45, 0.26, 0.1)
const NUMBER_RISE := 0.5 ## m a damage number floats up...
const NUMBER_SECONDS := 0.6 ## ... over this long, fading in its second half
const REGEN := 10.0 ## HP/s...
const REGEN_DELAY := 4.0 ## ... once Bob has not been hit for this long
const LOW_HP := 40.0 ## the red screen edge below this
const JUMP_HEIGHT := 0.5
const ENEMY_REACH := 20.0
const BOB_RADIUS := 0.25 ## his collision capsule (probe_shooter.gd): r 0.25, 1.3 m tall
const BOB_LOW := 0.25
const BOB_HIGH := 1.05
const BOB_CHEST := 0.7 ## where the enemies aim
## The arena (probe_shooter.gd): corridor A z -1.0..1.0, the east end x 10.65..12.65 z -6.1..1.0, corridor B z -6.1..-4.1; the stall
## block's corners at (10.65, -1.0) and (10.65, -4.1). The enemies walk the corridor middles, in this order (the "U"):
const U_PATH: Array[Vector3] = [Vector3(1.2, 0.0, 0.0), Vector3(11.65, 0.0, 0.0), Vector3(11.65, 0.0, -5.1), Vector3(0.6, 0.0, -5.1)]
## Cover points in U order: HIDE behind cover (from someone coming along the U from corridor A), PEEK = stepped out into the open.
## The toilet-paper stacks they hide behind are built in slice 4 (STACKS); the corners are the stall block's. PROPOSAL positions.
const COVERS := [
	{"name": "A stack", "hide": Vector3(6.75, 0.0, -0.6), "peek": Vector3(6.75, 0.0, 0.3)},
	{"name": "A corner", "hide": Vector3(11.6, 0.0, -2.0), "peek": Vector3(11.35, 0.0, -0.45)},
	{"name": "E stack 1", "hide": Vector3(12.4, 0.0, -3.05), "peek": Vector3(11.45, 0.0, -3.05)},
	{"name": "E stack 2", "hide": Vector3(12.4, 0.0, -4.75), "peek": Vector3(11.45, 0.0, -4.75)},
	{"name": "B corner", "hide": Vector3(9.9, 0.0, -4.55), "peek": Vector3(10.95, 0.0, -5.1)},
	{"name": "B stack", "hide": Vector3(5.25, 0.0, -4.45), "peek": Vector3(5.25, 0.0, -5.4)},
]
## Where the squad starts (SPEC: CREW 1 corridor A, CREW 2 east end, CREW 3 corridor B).
const SQUAD := [["CREW 1", 1], ["CREW 2", 2], ["CREW 3", 4]]
## The arena's floor as boxes [x0, x1, z0, z1] (tests: nobody stands outside them).
const ARENA_BOXES := [[1.2, 12.65, -1.0, 1.0], [10.65, 12.65, -6.1, 1.0], [0.0, 12.65, -6.1, -4.1]]
## The toilet-paper stacks [x0, x1, z0, z1], STACK_HEIGHT high, one per "stack" cover point (COVERS 0, 2, 3, 5), each on the side of
## its hide spot that faces Bob coming along the U; the 0.6 m side across the corridor (A: 1.0 m free to the sink fronts at z 0.6).
const STACKS := [[5.6, 6.4, -1.0, -0.4], [12.05, 12.65, -2.75, -1.95], [12.05, 12.65, -4.45, -3.65], [5.55, 6.35, -4.7, -4.1]]
const STACK_HEIGHT := 1.0
const WALL_X := 1.2 ## the invisible wall across corridor A (its east face)
const WALL_LAYER := 1 << 9 ## physics layer 10: only Bob's mask gets it, so blobs and sight lines pass (owner C1)
## BOSSY (SPEC (3)): walks in from the east-end corner Bob cannot see once BOSS_AFTER crew are down.
const BOSS_NAME := "BOSSY"
const BOSS_HP := 200.0
const BOSS_BURST := 5
const BOSS_DAMAGE := 8.0
const BOSS_BLOB_SPEED := 22.0
const BOSS_AFTER := 2
const BOSS_CORNERS: Array[Vector3] = [Vector3(12.2, 0.0, 0.5), Vector3(12.2, 0.0, -5.6)]
## The tank refills from empty to full in REFILL_SECONDS while Bob is within REFILL_RANGE (flat) of any sink's tap (owner A1).
const REFILL_RANGE := 1.0
const REFILL_SECONDS := 1.5

const ULT_FULL := 300.0 ## gun damage dealt that fills the meter (the hose's own damage never counts)
const HOSE_SECONDS := 5.0
const HOSE_DPS := 60.0
const HOSE_REACH := 10.0
const HOSE_RADIUS := 0.25 ## the stream is about 0.5 m wide where it hits
const HOSE_PUSH := 3.0 ## m/s: the target slides away from Bob
const HOSE_SPEED := 0.7 ## Bob's speed while hosing
const HOSE_NUMBER_EVERY := 0.25 ## s: one damage number (15) instead of one per frame
const HOSE_SPLASH_EVERY := 0.1
const HOSE_SHAKE := 0.006 ## m: the gun jitters while the hose runs
const SHOUT_SECONDS := 1.2

const START := Vector3(2.0, 0.0, 0.3) ## Bob starts at the west end of corridor A...
const START_YAW := -PI / 2.0 ## ... his camera facing east (+X)
const INTRO_SECONDS := 2.0 ## "ROUND 3", then "WATER WAR!" for the second half; nobody moves or fires, the level clock runs
const FADE_SECONDS := 0.6 ## from black, under the intro
const WIN_SLOWMO := 0.3
const WIN_SECONDS := 1.0 ## real seconds of slow motion after "SOAKED!"
const KO_SECONDS := 1.0 ## "K.O." holds this long (normal speed) before the level's fail screen (owner D)
const BARK_GAP := 6.0 ## s: one bark at a time, from anyone (owner B)
const BARK_SECONDS := 1.5
const BARKS := {"seen": "THERE HE IS!", "burst": "EAT BROWN!", "hit": "MY SHIRT!", "cover": "COVER ME!"}

var bob ## the player (player.gd)
var cam: Camera3D
var gun: Node3D
var hud ## shooter_hud.gd
var running := false
var bob_hp := BOB_HP
var tank := TANK
var shots_fired := 0 ## tests count these
var dry_clicks := 0
var wall_hits := 0 ## blobs stopped by the level (walls, floor, doors, props) or a bystander
var enemies: Array = [] ## shooter_enemy.gd
var blobs: Array = [] ## {"pos", "dir", "travel", "offset", "node"}
var hits: Array = [] ## {"enemy", "head", "damage", "kill", "at"}, oldest first (tests read it)
var numbers: Array = [] ## the damage numbers in the air (Label3D; meta "age", "from")
var splashes := 0 ## splash bursts made (one per blob that landed)
var hide_nodes: Array = [] ## the level's HUD items to hide, shown again after
var bystanders: Array[Node3D] = [] ## other NPCs out of the arena for the war, like the walkers (cutters.gd: the open stall's Jijio at a sink)
var ai_enabled := true ## tests park the enemies
var enemy_blobs: Array = [] ## {"pos", "dir", "travel", "speed", "damage", "from", "node"}
var enemy_shots: Array = [] ## {"enemy", "clear"}: every enemy shot and whether Bob was in plain view (tests)
var bob_hits: Array = [] ## {"from", "at", "damage"}: every brown blob that hit Bob (tests)
var over := false ## Bob is soaked (K.O.): nothing moves any more
var since_hit := 1000.0 ## s since Bob was last hit
var stacks: Array = [] ## the cover stacks (StaticBody3D)
var wall: StaticBody3D
var boss = null ## shooter_enemy.gd, once BOSSY has walked in
var boss_corner := Vector3.ZERO
var refills := 0 ## refills started (tests)
var refilling := false
var ult := 0.0 ## the meter, 0..ULT_FULL
var hosing := false
var hose_left := 0.0 ## s
var hose_uses := 0 ## tests
var hose_numbers := 0 ## damage numbers the hose made (tests)
var hose_node: Node3D ## the drawn stream
var hose_sound: Node ## the looping hose sound
var hose_end := Vector3.ZERO ## where the stream stops this frame
var intro_left := 0.0 ## s of the locked intro left
var clock := 0.0 ## s since start() (barks)
var barks: Array = [] ## {"who", "kind", "t"} (tests)
var _next_bark := 0.0
var _slowmo := false

var _hidden: Array = []
var _rng := RandomNumberGenerator.new()
var _cool := 0.0
var _dry_left := 0.0
var _was_held := false
var _recoil := 0.0
var _kick := 0.0
var _squad := false ## spawn_squad() ran: BOSSY follows the crew
var _fill := 0.0
var _doors: Array = [] ## [door, was open]
var _walkers: Array = [] ## [walker, visible, process_mode, layer]
var _bob_mask := 0
var _interactables: Array = [] ## everything that offered an E prompt before the fight (back in the group after)
var _speeds := Vector2.ZERO ## Bob's walk and sprint speed before the hose
var _hose_pour := {} ## enemy -> hose damage not yet shown as a number
var _hose_tick := 0.0
var _hose_splash := 0.0


func start(player) -> void:
	_rng.seed = randi() # never randomize(): seeded tests stay repeatable (references/testing.md)
	_register_actions()
	bob = player
	cam = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.shoulder = 0.0
	player.set_view(Player.View.FIRST_HIDDEN, 0.3)
	player.set_camera(player.get_camera_yaw(), 0.0)
	player.jump_speed = sqrt(2.0 * 9.8 * JUMP_HEIGHT)
	gun = Props.make_fp_gun()
	cam.add_child(gun)
	gun.position = GUN_REST
	gun.rotation = GUN_TURN
	gun.scale = Vector3.ONE * GUN_SCALE
	_hidden = []
	for n in hide_nodes:
		if is_instance_valid(n):
			_hidden.append([n, n.visible])
			n.visible = false
	hud = Hud.new()
	add_child(hud)
	_build_arena()
	running = true
	hud.update(bob_hp, BOB_HP, tank, TANK, 0.0)
	_update_foes()


## Level 4's round 3 (cutters.gd): Bob at START facing east, the squad at their cover points, a fade from black and the locked intro.
func begin_war(player) -> void:
	player.global_position = Vector3(START.x, player.global_position.y, START.z)
	player.velocity = Vector3.ZERO
	player.face_direction(Vector3.RIGHT)
	start(player)
	player.set_camera(START_YAW, 0.0)
	spawn_squad()
	intro_left = INTRO_SECONDS
	player.frozen = true
	hud.fade_in(FADE_SECONDS)
	hud.announce("ROUND 3", Color.WHITE)


## The stacks, the wall, the doors shut, the walkers away (abort() undoes all of it).
func _build_arena() -> void:
	for r: Array in STACKS:
		var s := Props.make_stack(Vector3(r[1] - r[0], STACK_HEIGHT, r[3] - r[2]))
		add_child(s)
		s.global_position = Vector3((r[0] + r[1]) / 2.0, 0.0, (r[2] + r[3]) / 2.0)
		stacks.append(s)
	wall = StaticBody3D.new()
	wall.name = "ArenaWall"
	wall.collision_layer = WALL_LAYER
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 3.0, 2.4)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(WALL_X - 0.1, 1.5, 0.0)
	_bob_mask = bob.collision_mask
	bob.collision_mask |= WALL_LAYER
	var level := get_parent()
	_doors = []
	for d: Node3D in level.stalls.doors:
		_doors.append([d, d.is_open])
		d.set_open(false, 0.2)
	# no E prompts during the fight: a hidden walker still offered "E talk" and a shut door "E open door" (first arena screenshot)
	_interactables = get_tree().get_nodes_in_group("interactable")
	for n in _interactables:
		n.remove_from_group("interactable")
	_walkers = []
	for w: Node3D in level.population.walkers + bystanders:
		if is_instance_valid(w):
			_walkers.append([w, w.visible, w.process_mode, w.collision_layer])
			w.visible = false
			w.process_mode = Node.PROCESS_MODE_DISABLED
			w.collision_layer = 0


func _clear_arena() -> void:
	for s in stacks:
		if is_instance_valid(s):
			s.queue_free()
	stacks = []
	if is_instance_valid(wall):
		wall.queue_free()
	if is_instance_valid(bob) and _bob_mask != 0:
		bob.collision_mask = _bob_mask
	_bob_mask = 0
	for pair: Array in _doors:
		if is_instance_valid(pair[0]):
			pair[0].set_open(pair[1], 0.2)
	_doors = []
	for w: Array in _walkers:
		if is_instance_valid(w[0]):
			w[0].visible = w[1]
			w[0].process_mode = w[2]
			w[0].collision_layer = w[3]
	_walkers = []
	for n in _interactables:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.add_to_group("interactable")
	_interactables = []


## A crew Jijio in a brown shirt at `pos`, facing `yaw` (the model's front is +Z: -PI/2 faces west).
func spawn_crew(crew_name: String, pos: Vector3, yaw: float):
	var population = get_parent().population
	var npc: Node3D = population.spawn_walker(pos, yaw)
	population.walkers.erase(npc) # nobody else steers them
	npc.name = crew_name.replace(" ", "_")
	npc.state = npc.State.FIGHT
	npc.velocity = Vector3.ZERO
	npc.face_yaw(yaw)
	Cutters._tint(npc, CREW_BROWN)
	return add_enemy(npc, crew_name, CREW_HP)


## The three crew at their start cover points, AI on.
func spawn_squad() -> Array:
	var out: Array = []
	for s: Array in SQUAD:
		var e = spawn_crew(s[0], COVERS[s[1]]["hide"], PI / 2.0)
		e.start_ai(self, s[1], _rng)
		out.append(e)
	_squad = true
	_update_foes()
	return out


## BOSSY: orange, BOSS_HP, her own bursts; she appears at the east-end corner Bob cannot see (both hidden or both seen: the farther)
## and walks to the free cover point nearest that corner along the U, then runs the usual loop.
func spawn_boss():
	var best := BOSS_CORNERS[0]
	var best_score := -INF
	for c: Vector3 in BOSS_CORNERS:
		var score := c.distance_to(bob.global_position) + (0.0 if clear_line(c + Vector3.UP * 1.1, bob_head()) else 100.0)
		if score > best_score:
			best_score = score
			best = c
	boss_corner = best
	var population = get_parent().population
	var npc: Node3D = population.spawn_walker(best, 0.0)
	population.walkers.erase(npc)
	npc.name = BOSS_NAME
	npc.state = npc.State.FIGHT
	npc.velocity = Vector3.ZERO
	Cutters._tint(npc, Cutters.DEFS[2]["color"])
	boss = add_enemy(npc, BOSS_NAME, BOSS_HP)
	boss.burst = BOSS_BURST
	boss.shot_damage = BOSS_DAMAGE
	boss.blob_speed = BOSS_BLOB_SPEED
	var s0 := u_param(best)
	var pick := -1
	for i in COVERS.size():
		if cover_taken(i, boss):
			continue
		if pick < 0 or absf(cover_s(i) - s0) < absf(cover_s(pick) - s0):
			pick = i
	boss.enter(self, maxi(pick, 0), _rng)
	_update_foes()
	return boss


func _update_foes() -> void:
	if not is_instance_valid(hud):
		return
	var crew := 0
	for e in enemies:
		if e != boss and not e.down:
			crew += 1
	hud.set_foes(crew, boss != null and not boss.down)


func crew_down() -> int:
	var n := 0
	for e in enemies:
		if e != boss and e.down:
			n += 1
	return n


func add_enemy(npc: Node3D, enemy_name: String, hit_points: float):
	if npc.is_in_group("interactable"):
		npc.remove_from_group("interactable")
	var e = Enemy.new(npc, enemy_name, hit_points)
	enemies.append(e)
	return e


## Stop at once (the level's timeout or a reset, and after the end): Bob in third person again, the props and the HUD gone.
func abort() -> void:
	end_hose()
	running = false
	intro_left = 0.0
	if _slowmo:
		Engine.time_scale = 1.0
		_slowmo = false
	if is_instance_valid(bob):
		bob.set_view(Player.View.THIRD, 0.3)
		bob.frozen = false
		bob.jump_speed = 0.0
	for b: Dictionary in blobs + enemy_blobs:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	blobs.clear()
	enemy_blobs.clear()
	for n in numbers:
		if is_instance_valid(n):
			n.queue_free()
	numbers.clear()
	if is_instance_valid(gun):
		gun.queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	for pair: Array in _hidden:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	_hidden = []
	_clear_arena()


func _physics_process(delta: float) -> void:
	if not running:
		return
	_float_numbers(delta)
	clock += delta
	if over:
		return
	if intro_left > 0.0:
		_intro(delta)
		return
	_recover(delta) # before firing: the frame of a shot shows its whole kick
	_refill(delta)
	if Input.is_action_just_pressed("ult"):
		start_hose()
	_trigger(delta)
	_fly(delta)
	if ai_enabled:
		for e in enemies:
			e.tick(delta)
	if hosing:
		_hose(delta) # after the AI's own steps: the push wins this frame
	_fly_enemy(delta)
	since_hit += delta
	if since_hit >= REGEN_DELAY:
		bob_hp = minf(bob_hp + REGEN * delta, BOB_HP)
	gun.position = GUN_REST + Vector3(0.0, 0.0, _kick)
	if hosing:
		gun.position += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * HOSE_SHAKE
	hud.update(bob_hp, BOB_HP, tank, TANK, delta)
	hud.set_ult(ult / ULT_FULL, hosing, hose_left / HOSE_SECONDS, delta)
	hud.low_hp(bob_hp < LOW_HP)


## True while Bob and the crew can act (after the intro, before the end), like fight.gd.
func fighting() -> bool:
	return running and intro_left <= 0.0 and not over


## The locked intro: "ROUND 3", "WATER WAR!" for its second half, then Bob is free and the crew start.
func _intro(delta: float) -> void:
	var before := intro_left
	intro_left = maxf(intro_left - delta, 0.0)
	if before > INTRO_SECONDS / 2.0 and intro_left <= INTRO_SECONDS / 2.0:
		hud.announce("WATER WAR!", Hud.ULT_READY)
	if intro_left <= 0.0:
		hud.hide_announce()
		bob.frozen = false
	hud.update(bob_hp, BOB_HP, tank, TANK, delta)
	hud.set_ult(ult / ULT_FULL, false, 0.0, delta)


func _recover(delta: float) -> void:
	_kick = maxf(_kick - GUN_RETURN * delta, 0.0)
	if _recoil <= 0.0:
		return
	var back := minf(_recoil, RECOIL_RECOVER * delta)
	_recoil -= back
	bob.set_camera(bob.get_camera_yaw(), bob.get_camera_pitch() - back)


## Flat distance from `p` to the nearest sink's tap.
static func sink_distance(p: Vector3) -> float:
	var best := INF
	for k in Sinks.SINK_COUNT:
		var tap := Vector2(Sinks.SINK_X_FIRST + Sinks.SINK_X_STEP * k, Sinks.SPOUT.z)
		best = minf(best, tap.distance_to(Vector2(p.x, p.z)))
	return best


## At a sink: the tank fills (TANK in REFILL_SECONDS), the gurgle plays once per refill.
func _refill(delta: float) -> void:
	if tank >= TANK or sink_distance(bob.global_position) > REFILL_RANGE:
		refilling = false
		_fill = 0.0
		return
	if not refilling:
		refilling = true
		refills += 1
		Sfx.play_ui(self, "refill")
	_fill += TANK / REFILL_SECONDS * delta
	var whole := floori(_fill + 0.0001)
	if whole > 0:
		tank = mini(tank + whole, TANK)
		_fill -= whole


func _trigger(delta: float) -> void:
	var held: bool = Input.is_action_pressed("shoot") and not bob.frozen and not hosing
	if not held:
		_cool = maxf(_cool - delta, 0.0)
		_was_held = false
		return
	if not _was_held:
		_dry_left = 0.0 # a new press on empty clicks at once
	_was_held = true
	_cool -= delta
	while _cool <= 0.0 and tank > 0:
		_shoot()
		_cool += 1.0 / RATE
	if tank <= 0:
		_cool = maxf(_cool, 0.0)
		_dry_left -= delta
		if _dry_left <= 0.0:
			_dry_left = DRY_CLICK_EVERY
			dry_clicks += 1
			Sfx.play_ui(self, "dry_click")


func _shoot() -> void:
	tank -= 1
	shots_fired += 1
	var basis := cam.global_basis
	var forward := -basis.z
	var angle := _rng.randf() * TAU
	var off := tan(SCATTER * sqrt(_rng.randf()))
	var dir := (forward + (basis.x * cos(angle) + basis.y * sin(angle)) * off).normalized()
	var node := Props.make_blob()
	add_child(node)
	var origin := cam.global_position
	var muzzle: Vector3 = (gun.get_node("Muzzle") as Node3D).global_position
	blobs.append({"pos": origin, "dir": dir, "travel": 0.0, "offset": muzzle - origin, "node": node})
	_place_blob(blobs[blobs.size() - 1])
	_recoil += RECOIL_KICK
	bob.set_camera(bob.get_camera_yaw(), bob.get_camera_pitch() + RECOIL_KICK)
	_kick = GUN_KICK
	Sfx.play_ui(self, "gun_shot")


## Move every blob one step: the first thing on its way (a wall or an enemy's hitbox) stops it.
func _fly(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = bob.get_world_3d().direct_space_state
	# the level (layer 1) and any bystander Jijio (layer 2, walkers) stop a blob; the enemies are tested by their hitboxes instead
	var skip: Array[RID] = [bob.get_rid()]
	for e in enemies:
		skip.append(e.body.get_rid())
	var keep: Array = []
	for b: Dictionary in blobs:
		var step := minf(BLOB_SPEED * delta, REACH - float(b["travel"]))
		var a: Vector3 = b["pos"]
		var to: Vector3 = a + (b["dir"] as Vector3) * step
		var q := PhysicsRayQueryParameters3D.create(a, to, 1 | 2, skip)
		var ray := space.intersect_ray(q)
		var wall_t: float = step + 1.0 if ray.is_empty() else a.distance_to(ray["position"])
		var best = null
		var best_hit := {}
		for e in enemies:
			var h: Dictionary = e.hit_along(a, to)
			if not h.is_empty() and float(h["t"]) < wall_t and (best_hit.is_empty() or float(h["t"]) < float(best_hit["t"])):
				best = e
				best_hit = h
		if best != null:
			var at: Vector3 = a + (b["dir"] as Vector3) * float(best_hit["t"])
			_on_hit(best, bool(best_hit["head"]), at)
			_splash(at, -(b["dir"] as Vector3))
			b["node"].queue_free()
			continue
		if not ray.is_empty():
			wall_hits += 1
			_splash(ray["position"], ray["normal"])
			b["node"].queue_free()
			continue
		b["pos"] = to
		b["travel"] = float(b["travel"]) + step
		if float(b["travel"]) >= REACH - 0.0001:
			b["node"].queue_free()
			continue
		_place_blob(b)
		keep.append(b)
	blobs = keep


func _place_blob(b: Dictionary) -> void:
	var node: Node3D = b["node"]
	var slide := maxf(1.0 - float(b["travel"]) / CONVERGE, 0.0)
	var at: Vector3 = (b["pos"] as Vector3) + (b["offset"] as Vector3) * slide
	node.global_position = at
	node.look_at(at + (b["dir"] as Vector3), Vector3.UP if absf((b["dir"] as Vector3).y) < 0.99 else Vector3.RIGHT)


func _on_hit(e, head: bool, at: Vector3) -> void:
	var amount := HEAD_DAMAGE if head else BODY_DAMAGE
	var before: float = e.hp
	var killed: bool = e.damage(amount)
	ult = minf(ult + (before - e.hp), ULT_FULL) # what the shot really dealt (a kill shot counts only the HP it took)
	hits.append({"enemy": e.name, "head": head, "damage": amount, "kill": killed, "at": at})
	hud.show_marker(head, killed)
	_number(at, amount, head)
	if killed:
		_on_kill(e, head)
	else:
		Sfx.play_ui(self, "hit_ding" if head else "hit_tick")
		bark(e, "hit")
	hit.emit(e, head, amount, killed, at)


func _on_kill(e, head: bool) -> void:
	Sfx.play_ui(self, "kill_chime") # the chime alone: a ding or tick on the same frame only muddies it
	hud.add_feed("BOB", e.name, head)
	if _squad and boss == null and crew_down() >= BOSS_AFTER:
		spawn_boss()
	_update_foes()
	if e == boss:
		_win()


## BOSSY down: "SOAKED!", everything stops, WIN_SECONDS (real time) of slow motion, then ended("BOB").
func _win() -> void:
	end_hose()
	over = true
	bob.frozen = true
	for x in enemies:
		x.body.velocity = Vector3.ZERO
	hud.announce("SOAKED!", Hud.BOB_BLUE)
	Engine.time_scale = WIN_SLOWMO
	_slowmo = true
	_finish_after(WIN_SECONDS, "BOB")


func _finish_after(seconds: float, winner: String) -> void:
	get_tree().create_timer(seconds, true, false, true).timeout.connect(_finish.bind(winner))


func _finish(winner: String) -> void:
	if not running: # aborted meanwhile (the level's timeout)
		return
	if _slowmo:
		Engine.time_scale = 1.0
		_slowmo = false
	ended.emit(winner, false)


## A bark: a bubble over the enemy with its voice, at most one every BARK_GAP s from anyone (owner B). `kind`: a BARKS key.
func bark(e, kind: String) -> void:
	if not running or over or intro_left > 0.0 or e.down or clock < _next_bark:
		return
	_next_bark = clock + BARK_GAP
	barks.append({"who": e.name, "kind": kind, "t": clock})
	var dialogue = get_parent().get("dialogue")
	if dialogue:
		dialogue.bubble(e.body, BARKS[kind], BARK_SECONDS, 2.05, "BOSSY" if e == boss else "Jijio")


# --- the SUPER-SOAKER hose (slice 5; SPEC "slice 5 details DECIDED") -------------------------------------------------

## Q with a full meter: 5 s of stream, the meter back to 0, Bob slower, the shout. False when it cannot start.
func start_hose() -> bool:
	if hosing or over or bob.frozen or ult < ULT_FULL - 0.001:
		return false
	hosing = true
	hose_uses += 1
	hose_left = HOSE_SECONDS
	ult = 0.0
	_hose_pour = {}
	_hose_tick = 0.0
	_hose_splash = 0.0
	_speeds = Vector2(bob.walk_speed, bob.sprint_speed)
	bob.walk_speed *= HOSE_SPEED
	bob.sprint_speed *= HOSE_SPEED
	hose_node = Props.make_hose()
	add_child(hose_node)
	hose_sound = Sfx.loop_ui(self, "hose")
	hud.shout("SUPER SOAKER!", SHOUT_SECONDS)
	var dialogue = get_parent().get("dialogue")
	if dialogue:
		dialogue.shout_voice(bob, "SUPER SOAKER!", "Bob") # voice only: a bubble over Bob is out of sight in first person
	return true


## The hose's end (its time ran out, a K.O., abort()): Bob's speed back, the stream and its sound gone.
func end_hose() -> void:
	if not hosing:
		return
	hosing = false
	hose_left = 0.0
	if is_instance_valid(bob):
		bob.walk_speed = _speeds.x
		bob.sprint_speed = _speeds.y
	if is_instance_valid(hose_node):
		hose_node.queue_free()
	hose_node = null
	if is_instance_valid(hose_sound):
		Sfx.stop_loop(hose_sound)
	hose_sound = null
	_flush_pour()


## One frame of stream along the crosshair: it stops at the level, a stack or the first enemy; that enemy takes HOSE_DPS and slides away.
func _hose(delta: float) -> void:
	hose_left -= delta
	var origin := cam.global_position
	var dir := -cam.global_basis.z
	var to := origin + dir * HOSE_REACH
	var skip: Array[RID] = [bob.get_rid()]
	for e in enemies:
		skip.append(e.body.get_rid())
	var space: PhysicsDirectSpaceState3D = bob.get_world_3d().direct_space_state
	var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, to, 1 | 2, skip))
	var end_t: float = HOSE_REACH if ray.is_empty() else origin.distance_to(ray["position"])
	var target = null
	for e in enemies:
		var h: Dictionary = e.hit_along(origin, to, HOSE_RADIUS)
		if not h.is_empty() and float(h["t"]) < end_t:
			end_t = float(h["t"])
			target = e
	hose_end = origin + dir * end_t
	_hose_splash -= delta
	if (target != null or not ray.is_empty()) and _hose_splash <= 0.0:
		_hose_splash = HOSE_SPLASH_EVERY
		_splash(hose_end, -dir if target != null else (ray["normal"] as Vector3), false)
	if target != null:
		var before: float = target.hp
		var killed: bool = target.damage(HOSE_DPS * delta)
		_hose_pour[target] = float(_hose_pour.get(target, 0.0)) + before - target.hp
		hud.show_marker(false, killed)
		if killed:
			_on_kill(target, false)
			if not hosing: # that was BOSSY: the win ended the hose (and freed the stream)
				return
		else:
			var flat := Vector3(dir.x, 0.0, dir.z)
			if flat.length() > 0.01:
				target.push(flat.normalized() * HOSE_PUSH)
	_hose_tick += delta
	if _hose_tick >= HOSE_NUMBER_EVERY - 0.0001:
		_hose_tick -= HOSE_NUMBER_EVERY
		_flush_pour()
	_place_hose()
	if hose_left <= 0.0:
		end_hose()


## The hose damage poured since the last number, one number per enemy.
func _flush_pour() -> void:
	for e in _hose_pour:
		var amount: float = _hose_pour[e]
		if amount >= 0.5 and is_instance_valid(e.body):
			_number(e.body.global_position + Vector3.UP * 1.0, amount, false)
			hose_numbers += 1
	_hose_pour = {}


## The drawn stream: from the muzzle to where it stops, a little wobble each frame.
func _place_hose() -> void:
	if not is_instance_valid(hose_node):
		return
	var from: Vector3 = (gun.get_node("Muzzle") as Node3D).global_position
	var length := from.distance_to(hose_end)
	if length < 0.05:
		hose_node.visible = false
		return
	hose_node.visible = true
	hose_node.global_position = from
	var up := Vector3.UP if absf((hose_end - from).normalized().y) < 0.99 else Vector3.RIGHT
	hose_node.look_at(hose_end, up)
	var w := _rng.randf_range(0.85, 1.15)
	hose_node.scale = Vector3(w, 2.0 - w, length)


func _splash(at: Vector3, normal: Vector3, sound := true) -> void:
	splashes += 1
	var s := Props.make_splash()
	add_child(s)
	s.global_position = at + normal * 0.03
	if absf(normal.dot(Vector3.UP)) < 0.99:
		s.look_at(at - normal, Vector3.UP) # +Z (the burst's direction) along the normal
	else:
		s.rotation = Vector3(-PI / 2.0 if normal.y > 0.0 else PI / 2.0, 0.0, 0.0)
	s.restart()
	if sound: # the hose's own loop covers its splashes
		Sfx.play_at(self, "blob_splash", at)


func _number(at: Vector3, amount: float, head: bool) -> void:
	var l := Props.make_number("%d" % roundi(amount), Hud.NUMBER_HEAD if head else Hud.NUMBER_BODY)
	add_child(l)
	# right of the hit marker (under it the marker hid it, screenshot), with a little jitter so a burst does not stack its numbers;
	# the offset grows with distance, so it is about the same on screen
	var dist := cam.global_position.distance_to(at)
	var from := at + cam.global_basis.x * dist * _rng.randf_range(0.07, 0.12) + Vector3.UP * dist * 0.02
	l.global_position = from
	l.set_meta("age", 0.0)
	l.set_meta("from", from)
	numbers.append(l)


func _float_numbers(delta: float) -> void:
	var keep: Array = []
	for l: Label3D in numbers:
		var age: float = float(l.get_meta("age")) + delta
		if age >= NUMBER_SECONDS:
			l.queue_free()
			continue
		l.set_meta("age", age)
		var k := age / NUMBER_SECONDS
		l.global_position = (l.get_meta("from") as Vector3) + Vector3.UP * NUMBER_RISE * k
		l.modulate.a = clampf(2.0 - 2.0 * k, 0.0, 1.0)
		l.outline_modulate.a = 0.85 * l.modulate.a
		keep.append(l)
	numbers = keep


# --- the enemies' side ------------------------------------------------------------------------------------------------

func bob_head() -> Vector3:
	return cam.global_position


func bob_chest() -> Vector3:
	return bob.global_position + Vector3.UP * BOB_CHEST


## No level geometry between a and b (Bob and the enemies do not count).
func clear_line(a: Vector3, b: Vector3, _from_enemy = null) -> bool:
	var skip: Array[RID] = [bob.get_rid()]
	for e in enemies:
		skip.append(e.body.get_rid())
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, skip)
	return bob.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A brown blob from an enemy's muzzle.
func enemy_fire(e, from: Vector3, dir: Vector3) -> void:
	var node := Props.make_blob(Props.BROWN)
	add_child(node)
	var b := {"pos": from, "dir": dir, "travel": 0.0, "speed": e.blob_speed, "damage": e.shot_damage, "from": from, "node": node}
	enemy_blobs.append(b)
	node.global_position = from
	node.look_at(from + dir, Vector3.UP)
	enemy_shots.append({"enemy": e.name, "clear": clear_line(from, bob_head())})
	Sfx.play_at(self, "enemy_shot", from)


## Move the brown blobs: a wall stops one (a brown splash), Bob's capsule takes one (a splat on his screen).
func _fly_enemy(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = bob.get_world_3d().direct_space_state
	var skip: Array[RID] = [bob.get_rid()]
	for e in enemies:
		skip.append(e.body.get_rid())
	var keep: Array = []
	var low: Vector3 = bob.global_position + Vector3.UP * BOB_LOW
	var high: Vector3 = bob.global_position + Vector3.UP * BOB_HIGH
	for b: Dictionary in enemy_blobs:
		var step := minf(float(b["speed"]) * delta, ENEMY_REACH - float(b["travel"]))
		var a: Vector3 = b["pos"]
		var to: Vector3 = a + (b["dir"] as Vector3) * step
		var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, to, 1, skip))
		var wall_t: float = step + 1.0 if ray.is_empty() else a.distance_to(ray["position"])
		var bob_t: float = Enemy._capsule(a, to, low, high, BOB_RADIUS)
		if bob_t >= 0.0 and bob_t < wall_t:
			_bob_hit(b, a + (b["dir"] as Vector3) * bob_t)
			b["node"].queue_free()
			continue
		if not ray.is_empty():
			var s := Props.make_splash(Props.BROWN)
			add_child(s)
			s.global_position = (ray["position"] as Vector3) + (ray["normal"] as Vector3) * 0.03
			if absf((ray["normal"] as Vector3).dot(Vector3.UP)) < 0.99:
				s.look_at(ray["position"] - ray["normal"], Vector3.UP)
			s.restart()
			Sfx.play_at(self, "blob_splash", ray["position"])
			b["node"].queue_free()
			continue
		b["pos"] = to
		b["travel"] = float(b["travel"]) + step
		if float(b["travel"]) >= ENEMY_REACH - 0.0001:
			b["node"].queue_free()
			continue
		(b["node"] as Node3D).global_position = to
		keep.append(b)
	enemy_blobs = keep


func _bob_hit(b: Dictionary, at: Vector3) -> void:
	bob_hp = maxf(bob_hp - float(b["damage"]), 0.0)
	since_hit = 0.0
	bob_hits.append({"from": b["from"], "at": at, "damage": b["damage"]})
	hud.splat(_rng)
	Sfx.play_ui(self, "bob_splat")
	if bob_hp <= 0.0:
		_soaked()


## Bob at 0: K.O. Nothing moves or fires any more; the level decides what follows (slice 6: the fail screen).
func _soaked() -> void:
	end_hose()
	over = true
	bob.frozen = true
	for e in enemies:
		e.body.velocity = Vector3.ZERO
	hud.announce("K.O.", Hud.MARKER_HEAD)
	_finish_after(KO_SECONDS, "CREW")


## Where a point is along the U (metres from its start), by the nearest segment.
func u_param(p: Vector3) -> float:
	return float(_project_u(p)["s"])


func _project_u(p: Vector3) -> Dictionary:
	var best := {"s": 0.0, "at": U_PATH[0], "seg": 0}
	var best_d := INF
	var s0 := 0.0
	for i in U_PATH.size() - 1:
		var a: Vector3 = U_PATH[i]
		var b: Vector3 = U_PATH[i + 1]
		var ab := b - a
		var t := clampf(Vector3(p.x - a.x, 0.0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var at := a + ab * t
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = {"s": s0 + ab.length() * t, "at": at, "seg": i}
		s0 += ab.length()
	return best


func cover_s(i: int) -> float:
	return u_param(COVERS[i]["peek"])


func cover_taken(i: int, me) -> bool:
	for e in enemies:
		if e != me and not e.down and e.cover == i:
			return true
	return false


## A walk from `from` to cover `i`: onto the U, along it (its corners), out to the peek spot, back to the hide spot.
func path_between(from: Vector3, i: int) -> Array[Vector3]:
	var a := _project_u(from)
	var b := _project_u(COVERS[i]["peek"])
	var out: Array[Vector3] = [a["at"]]
	var sa: int = a["seg"]
	var sb: int = b["seg"]
	if sb > sa:
		for k in range(sa + 1, sb + 1):
			out.append(U_PATH[k])
	elif sb < sa:
		for k in range(sa, sb, -1):
			out.append(U_PATH[k])
	out.append(b["at"])
	out.append(COVERS[i]["peek"])
	out.append(COVERS[i]["hide"])
	return out


## Actions in code (project.godot is editor-owned); input actions so touch can be added later (SPEC Stage 5).
static func _register_actions() -> void:
	if not InputMap.has_action("ult"):
		InputMap.add_action("ult")
		var q := InputEventKey.new()
		q.physical_keycode = KEY_Q # also the mop's key, but the mop is not in Level 4
		InputMap.action_add_event("ult", q)
	if InputMap.has_action("shoot"):
		return
	InputMap.add_action("shoot")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", ev)
