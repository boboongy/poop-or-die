extends Node
## Level 4: ONE Street Fighter style fight between Bob and a Jijio (SPEC "Level 4"). Takes both bodies over, puts them on a
## straight fight line seen from a fixed side camera, reads Bob's buttons, runs the AI, plays the real baked clips
## (fighter.gd MOVES) and adds the feel: hit-stop, an impact flash, camera shake, a slow-motion KO and FINISH HIM.
## Placeholder poses (no clip exists yet, FACTORY_TODO Level 4 row): block = a held frame of the combo's guard, jump = the
## body lifted in an arc, hit = a lean back, dizzy = a sway, KO = falling onto the back.
## Controls, WASD + SPACE ONLY (owner 2026-09-28, SPEC D1 SUPERSEDED line): A/D walk, hold away = block, S crouch, W jump; Space =
## punch (again quickly = combo), toward + Space = kick, S + Space = low sweep, Space in the air = jump kick; motion specials typed
## within MOTION_WINDOW ("forward" = toward the foe): S D Space flurry, D S D Space uppercut, S A Space spin kick, S D S D Space super
## (full meter; empty = the uppercut). Any attack on a dizzy foe = the finisher. The water fight keeps the mouse (it is a shooter).

signal ended(winner: String, finished: bool) ## after the KO slow motion; winner is "BOB" or the foe's name
signal hit_landed(event: Dictionary) ## every contact that connected (fighter.gd event + "victim"), for the HUD

const Fighter := preload("res://scripts/fighter.gd")
const Pose := preload("res://scripts/pose.gd")
const FightHud := preload("res://scripts/fight_hud.gd")
const Sfx := preload("res://scripts/sfx.gd")

const FIGHT_CALL := 0.6 ## "FIGHT!" shows this long before the intro ends (after "ROUND n")
const RED := Color(1.0, 0.15, 0.1)

const START_GAP := 2.0
const LINE_HALF := 2.8 ## the fight line's ends (m from the centre): the "stage edge"
## Side camera: 2.0 m out with a 60 degree lens frames about 4 m of the line. Further out it stood behind the east wall
## and a quarter of the frame showed the black void under the room's edge (first screenshot pass).
const CAM_DIST := 2.0
const CAM_HEIGHT := 1.1
const CAM_LOOK_HEIGHT := 0.75
const CAM_FOV := 60.0
const HITSTOP := 0.08 ## both fighters freeze on a clean hit (SPEC "N")
const SHAKE := 0.04
const SHAKE_SECONDS := 0.15
const KO_SLOWMO := 0.3
const KO_SLOWMO_SECONDS := 1.0 ## real seconds
const FINISHER_SLOWMO := 0.4
const JUMP_HEIGHT := 0.5
const BUFFER := 0.15 ## a button pressed this long before the fighter is free still counts
const MOTION_WINDOW := 0.6 ## s: a special's whole motion + button must be typed within this (owner default "0.5 s per motion", +0.1 for key travel)
## Motion specials, most specific first (numpad notation: 2 = down, 6 = forward toward the foe, 4 = back), all ending in Space
## (Stage 7 keys, owner 2026-09-28). [motion, button, action, name]
const SPECIALS := [
	["2626", "attack", "super", "SUPER!"],
	["626", "attack", "uppercut", "UPPERCUT!"],
	["26", "attack", "flurry", "FLURRY!"],
	["24", "attack", "spin", "SPIN KICK!"],
]
## Fight stance and guard, cut from the attack clips at runtime (probed with tests/probe_fight_clips.gd): punch_combo
## frames 6-8 = both fists up at the chin (hands y 0.88-0.92 m, 0.21-0.24 m in front), feet staggered: the stance bounces
## between them. punch frame 8 = lead fist out, rear fist at the face: the block (placeholder until a `block` clip exists).
const STANCE := ["punch_combo", [6, 8, 6], [0.0, 0.35, 0.7]]
const GUARD := ["punch", [8, 8], [0.0, 0.5]]
## Crouch (placeholder until a `crouch` clip exists, FACTORY_TODO R7): the flying double kick's coil, frame 8.
const CROUCH := ["kick_double", [8, 8], [0.0, 0.5]]
const KO_TILT := -1.35 ## on the back (same as a slipped Jijio)
const WALK_AUTHORED := 1.0 ## m/s the walk clip was made at
## AI per difficulty 1..3 (owner 2026-09-25 "too easy": was block 0.15/0.3/0.45, attack 0.45/0.55/0.65, jab or kick only).
## block: chance to guard when Bob starts a move in range; attack: chance to attack on a think tick; punish: chance to hit
## back at once when Bob's move ends in range (a whiffed or blocked attack); combo: chance an attack is the jab chain;
## special: chance (in range) of a spin kick / uppercut; anti_air: chance to uppercut a jump in range. PROPOSAL numbers.
const AI_BLOCK := [0.4, 0.55, 0.7]
const AI_ATTACK := [0.6, 0.75, 0.85]
const AI_PUNISH := [0.35, 0.7, 0.85]
const AI_COMBO := [0.25, 0.45, 0.6]
const AI_SPECIAL := [0.0, 0.25, 0.35]
const AI_ANTI_AIR := [0.2, 0.6, 0.8]

var bob: Fighter
var foe: Fighter
var bob_body ## the player (untyped: its script members busy/posing/anim() are used)
var foe_body ## the Jijio (npc_jijio.gd)
var camera: Camera3D
var running := false
var ai_enabled := true
var ai_level := 1
var hitstop_left := 0.0
var hitstop_count := 0
var _foe_hits := 0 ## clean hits on the foe (every other one gets an OOF)
var hud ## fight_hud.gd (untyped: its own methods are called), freed by itself after the fight
var intro_seconds := 1.6 ## ROUND n, then FIGHT!: nobody can act until it ends (set 0 before start() to skip)
var hide_nodes: Array = [] ## the level's HUD items to hide during the fight (mission list, prompts), shown again after

var _intro_left := 0.0
var _hidden: Array = [] ## [node, was_visible]
var _dizzy_called := false

var _center := Vector3.ZERO
var _axis := Vector3.FORWARD
var _floor := {} ## body -> its floor y at the start
var _shown := {} ## body -> the pose key being shown
var _want_speed := {} ## body -> the AnimationPlayer speed the pose wants (0 during hit-stop)
var _prev_pos := {} ## fighter -> pos last frame (walking detection)
var _prev_camera: Camera3D
var _old_callback := {} ## body -> its AnimationPlayer's callback mode before the fight
var _shake_left := 0.0
var _buffer_action := ""
var _buffer_left := 0.0
var _motion: Array = [] ## Bob's recent direction presses: [token "2"/"4"/"6", time]
var _clock := 0.0 ## real seconds since the fight started (for the motion window)
var _ending := false
var _finisher_slow := false
var _rng := RandomNumberGenerator.new()
var _ai_think := 0.5
var _ai_walk_dir := 0.0
var _ai_walk_left := 0.0
var _ai_block_left := 0.0
var _ai_stunned := false ## the cutter was in hit stun on the last AI tick
var _ai_bob_moving := false ## Bob was in a move on the last AI tick (to punish the moment it ends)


## `axis`: the world direction the fight line runs in; the camera is placed so that `axis` points to screen-right,
## Bob starts on the left. `level` 1..3 sets the AI.
func start(player, npc, center: Vector3, axis: Vector3, foe_name: String, foe_hp: float,
		finishable: bool, level: int, rng_seed: int = 1, round_number: int = 1) -> void:
	_register_actions()
	_rng.seed = rng_seed
	bob_body = player
	foe_body = npc
	_center = center
	_axis = Vector3(axis.x, 0.0, axis.z).normalized()
	ai_level = clampi(level, 1, 3)
	bob = Fighter.new("BOB", 100.0)
	foe = Fighter.new(foe_name, foe_hp)
	foe.finishable = finishable
	bob.pos = -START_GAP / 2.0
	foe.pos = START_GAP / 2.0
	bob.face(foe)
	foe.face(bob)
	_prev_pos = {bob: bob.pos, foe: foe.pos}
	_floor = {player: player.global_position.y, npc: npc.global_position.y}
	player.busy = true
	player.posing = true
	player.posing_focus = null
	player.velocity = Vector3.ZERO
	npc.state = npc.State.FIGHT
	npc.velocity = Vector3.ZERO
	# clips advance on the physics tick with the fight logic, so a hit freezes on its contact frame even at low FPS
	# (a 10 FPS window showed the kick's backswing at contact when the clips ran on the render frame)
	_old_callback = {}
	for body in [player, npc]:
		var ap: AnimationPlayer = body.anim()
		_old_callback[body] = ap.callback_mode_process
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		_ensure_pose_clips(ap)
	_prev_camera = player.get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	add_child(camera)
	camera.near = _near_clip()
	camera.make_current()
	_hidden = []
	for n in hide_nodes:
		if is_instance_valid(n):
			_hidden.append([n, n.visible])
			n.visible = false
	hud = FightHud.new()
	add_child(hud)
	hud.setup(bob.name, foe.name)
	_intro_left = intro_seconds
	if _intro_left > 0.0:
		hud.announce("ROUND %d" % round_number, Color.WHITE)
	running = true
	_update_poses()
	_place(0.0)
	hud.update(bob, foe, 0.0)


## True while the fighters can act (after the intro, before the KO).
func fighting() -> bool:
	return running and _intro_left <= 0.0 and not _ending


## Stop at once (tests, level reset): Bob free again, normal time.
func abort() -> void:
	running = false
	Engine.time_scale = 1.0
	_release_player()
	_restore_hidden()
	if is_instance_valid(hud):
		hud.queue_free()


func _restore_hidden() -> void:
	for pair: Array in _hidden:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	_hidden = []


func _physics_process(delta: float) -> void:
	if not running:
		return
	_clock += delta / maxf(Engine.time_scale, 0.01) # unscaled: the motion window is the player's typing speed, slow motion or not
	_shake_left = maxf(_shake_left - delta, 0.0)
	if is_instance_valid(hud):
		hud.update(bob, foe, delta)
	if _intro_left > 0.0:
		var before := _intro_left
		_intro_left = maxf(_intro_left - delta, 0.0)
		if before > FIGHT_CALL and _intro_left <= FIGHT_CALL:
			hud.announce("FIGHT!", Color(1.0, 0.8, 0.1), 0.5)
		_update_poses()
		_apply_speeds()
		_place(delta)
		_prev_pos = {bob: bob.pos, foe: foe.pos}
		return
	if hitstop_left > 0.0:
		hitstop_left = maxf(hitstop_left - delta, 0.0)
		_apply_speeds()
		_place(delta)
		return
	if not _ending:
		_bob_controls(delta)
		if ai_enabled:
			_ai(delta)
	var events: Array = bob.step(delta, foe)
	events.append_array(foe.step(delta, bob))
	bob.pos = clampf(bob.pos, -LINE_HALF, LINE_HALF)
	foe.pos = clampf(foe.pos, -LINE_HALF, LINE_HALF)
	for e: Dictionary in events:
		_on_hit(e)
	# FINISH HIM: the finisher plays in slow motion
	var want_slow := bob.move == "finisher" and not _ending
	if want_slow != _finisher_slow:
		_finisher_slow = want_slow
		Engine.time_scale = FINISHER_SLOWMO if want_slow else 1.0
	_update_poses()
	_apply_speeds()
	_place(delta)
	_prev_pos = {bob: bob.pos, foe: foe.pos}
	if foe.is_dizzy() and not _dizzy_called:
		_dizzy_called = true
		hud.announce("FINISH HIM!", RED, 0.0, true)
	if not _ending and (bob.is_ko() or foe.is_ko()):
		_end()


# --- Bob's buttons -------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not fighting() or event.is_echo():
		return
	# direction presses feed the motion history (relative to the foe: forward = toward them)
	var toward_right := foe.pos >= bob.pos
	if event.is_action_pressed("move_back"):
		_motion.append(["2", _clock])
	elif event.is_action_pressed("move_right"):
		_motion.append(["6" if toward_right else "4", _clock])
	elif event.is_action_pressed("move_left"):
		_motion.append(["4" if toward_right else "6", _clock])
	# Stage 7 keys (owner 2026-09-28: "just WASD and Space"): W jumps, Space attacks; what Space does depends on the motion typed and
	# the direction held (see _resolve)
	for pair: Array in [["fight_attack", "attack"], ["move_forward", "jump"]]:
		if event.is_action_pressed(pair[0]):
			var action := _resolve(pair[1])
			if not _try(action):
				_buffer_action = action
				_buffer_left = BUFFER
			get_viewport().set_input_as_handled()
			return


## A button, plus the motion typed just before it = the action (a special, or the plain button). A special used clears the history.
## The super needs a full meter: without one, the same keys fall through to the next special that matches (the uppercut).
## Space ("attack"): a special motion first, then in the air = jump kick, S held = low sweep, toward the foe held = kick, else punch.
func _resolve(button: String) -> String:
	if button != "attack":
		return button
	while not _motion.is_empty() and _clock - _motion[0][1] > MOTION_WINDOW:
		_motion.pop_front()
	var typed := ""
	for m: Array in _motion:
		typed += m[0]
	for sp: Array in SPECIALS:
		if not typed.ends_with(sp[0]):
			continue
		if sp[2] == "super" and bob.meter < Fighter.METER_MAX:
			continue
		_motion.clear()
		return sp[2]
	if bob.is_airborne():
		return "jump_kick"
	if Input.is_action_pressed("move_back"):
		return "sweep"
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.1 and signf(dir) == signf(foe.pos - bob.pos):
		return "kick"
	return "punch"


## The on-screen name of a special action ("" for a plain button).
static func special_name(action: String) -> String:
	for sp: Array in SPECIALS:
		if sp[2] == action:
			return sp[3]
	return ""


func _bob_controls(delta: float) -> void:
	if _buffer_left > 0.0:
		_buffer_left -= delta
		if _try(_buffer_action):
			_buffer_left = 0.0
	var dir := Input.get_axis("move_left", "move_right")
	# Street Fighter (owner 2026-09-25): holding AWAY from the foe walks back and guards (the only block since 2026-09-28: L/Shift
	# removed); S held crouches (punches pass over).
	var back_held := absf(dir) > 0.1 and signf(dir) == -bob.facing
	bob.set_block(back_held)
	bob.set_crouch(Input.is_action_pressed("move_back"))
	if absf(dir) > 0.1:
		bob.walk(dir, delta, foe)


func _try(action: String) -> bool:
	if foe.is_dizzy() and action != "jump":
		return bob.start_move("finisher")
	var ok := false
	match action:
		"punch":
			ok = bob.chain_punch() or bob.start_move("punch")
		"kick":
			ok = bob.start_move("kick")
		"sweep":
			ok = bob.start_move("sweep")
		"jump_kick":
			ok = bob.jump_kick()
		"flurry":
			ok = bob.start_move("combo")
		"uppercut":
			ok = bob.start_move("uppercut")
		"spin":
			ok = bob.start_move("spin")
		"super":
			ok = bob.start_move("super")
		"jump":
			ok = bob.jump()
	if ok and special_name(action) != "" and is_instance_valid(hud):
		hud.show_special(special_name(action))
	return ok


# --- AI --------------------------------------------------------------------------------------------------------------

func _ai(delta: float) -> void:
	var lv := ai_level - 1
	var bob_was_moving := _ai_bob_moving
	_ai_bob_moving = bob.state == Fighter.State.MOVE
	var dist := absf(bob.pos - foe.pos)
	var toward := signf(bob.pos - foe.pos)
	# The guard decisions are made even while the cutter is still stunned: rolled only when free, a key-masher's jabs
	# (each one starting inside the last one's hit stun) were never guarded, and a masher won 10 of 10.
	if bob.state == Fighter.State.MOVE and bob.t <= delta * 1.5 and dist < 1.6 and _rng.randf() < AI_BLOCK[lv]:
		_ai_block_left = 0.5
	var was_stunned := _ai_stunned
	_ai_stunned = foe.state == Fighter.State.HIT
	if was_stunned and not _ai_stunned and _rng.randf() < AI_BLOCK[lv]:
		_ai_block_left = maxf(_ai_block_left, 0.4) # wakes up guarding
	if not foe.can_act():
		return
	# Bob jumps in close: maybe knock him out of the air
	if bob.is_airborne() and bob.t <= delta * 1.5 and dist < 1.2 and _rng.randf() < AI_ANTI_AIR[lv]:
		foe.set_block(false)
		foe.start_move("uppercut")
		return
	# Bob's attack just ended in range (whiffed or blocked): punish it at once
	if bob_was_moving and bob.can_act() and dist < 1.3 and _rng.randf() < AI_PUNISH[lv]:
		_ai_block_left = 0.0
		foe.set_block(false)
		_ai_attack(dist)
		return
	if _ai_block_left > 0.0:
		_ai_block_left -= delta
		foe.set_block(true)
		return
	foe.set_block(false)
	if _ai_walk_left > 0.0:
		_ai_walk_left -= delta
		foe.walk(_ai_walk_dir, delta, bob)
	_ai_think -= delta
	if _ai_think > 0.0:
		return
	_ai_think = _rng.randf_range(0.2, 0.5) / (0.7 + 0.3 * ai_level)
	if dist > 0.85 and not (dist < 1.4 and _rng.randf() < AI_SPECIAL[lv]):
		_ai_walk_dir = toward
		_ai_walk_left = 0.35
		return
	var r := _rng.randf()
	if r < AI_ATTACK[lv]:
		_ai_attack(dist)
	elif r < 0.9:
		_ai_walk_dir = -toward
		_ai_walk_left = 0.2


## The cutter's attack for this distance: a spin kick from further out, the kick at a crouching Bob (punches pass over),
## otherwise the jab, the jab chain or (close) the uppercut.
func _ai_attack(dist: float) -> void:
	var lv := ai_level - 1
	if dist > 0.9 or bob.crouching:
		foe.start_move("spin" if dist > 1.25 or _rng.randf() < AI_SPECIAL[lv] else "kick")
	elif dist < 0.8 and _rng.randf() < AI_SPECIAL[lv]:
		foe.start_move("uppercut")
	else:
		foe.start_move("combo" if _rng.randf() < AI_COMBO[lv] else "punch")


# --- hits, KO --------------------------------------------------------------------------------------------------------

func _on_hit(e: Dictionary) -> void:
	var victim_body: Node3D = foe_body if e["by"] == bob.name else bob_body
	e["victim"] = foe.name if e["by"] == bob.name else bob.name
	if not bool(e["blocked"]):
		hitstop_left = HITSTOP
		hitstop_count += 1
		_shake_left = SHAKE_SECONDS
	_flash(victim_body, victim_body == foe_body, bool(e["blocked"]))
	var sound := "block_hit" if bool(e["blocked"]) else ("punch_hit" if e["move"] in ["punch", "combo"] else "heavy_hit")
	Sfx.play_at(self, sound, victim_body.global_position + Vector3.UP * 1.0)
	# Stage 6 E: a voice on the clean hits: the cutter on every other one (in its own cast), Bob on each
	if not bool(e["blocked"]):
		if victim_body == foe_body:
			_foe_hits += 1
			if _foe_hits % 2 == 1:
				Sfx.play_at(self, _cast_event("oof_"), victim_body.global_position + Vector3.UP * 1.3)
		else:
			Sfx.play_at(self, "bob_ouch", victim_body.global_position + Vector3.UP * 1.1)
	hud.on_hit(e["by"] == bob.name, int(e["combo"]), bool(e["blocked"]))
	hit_landed.emit(e)


## The foe's own voice event ("oof_pushy", "ko_bossy"), or the generic Jijio one ("oof"; a KO without its own groan: "oof").
func _cast_event(prefix: String) -> String:
	var own := prefix + foe.name.to_lower()
	return own if Sfx.EVENTS.has(own) else "oof"


func _flash(victim: Node3D, victim_is_foe: bool, blocked: bool) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.85, 1.0) if blocked else Color(1.0, 0.95, 0.45)
	sphere.material = mat
	mesh.mesh = sphere
	add_child(mesh)
	var toward_attacker := -_axis if victim_is_foe else _axis
	mesh.global_position = victim.global_position + Vector3.UP * 0.85 + toward_attacker * 0.2
	var tw := mesh.create_tween().set_parallel()
	tw.tween_property(mesh, "scale", Vector3.ONE * (1.6 if blocked else 2.6), 0.15).from(Vector3.ONE * 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.chain().tween_callback(mesh.queue_free)


func _end() -> void:
	_ending = true
	_finisher_slow = false
	Engine.time_scale = KO_SLOWMO
	var loser := foe if foe.is_ko() else bob
	Sfx.play_at(self, "ko", (_body_of(loser) as Node3D).global_position + Vector3.UP * 0.8)
	# Stage 6 E: a long cartoon groan in the loser's own voice
	Sfx.play_at(self, _cast_event("ko_") if loser == foe else "bob_ouch", (_body_of(loser) as Node3D).global_position + Vector3.UP * 1.2)
	hud.announce("TOILETALITY!" if foe.finished else "K.O.", RED)
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.wait_time = KO_SLOWMO_SECONDS
	add_child(timer)
	timer.timeout.connect(_finish_end)
	timer.start()


func _finish_end() -> void:
	Engine.time_scale = 1.0
	var bob_won := foe.is_ko()
	for f: Fighter in [bob, foe]:
		if f.is_ko():
			_model_of(_body_of(f)).rotation.x = KO_TILT
	_restore_clocks()
	if bob_won:
		_release_player()
	_restore_hidden()
	hud.finish(1.0)
	running = false
	ended.emit("BOB" if bob_won else foe.name, foe.finished if bob_won else false)


func _restore_clocks() -> void:
	for body in _old_callback:
		if is_instance_valid(body):
			(body.anim() as AnimationPlayer).callback_mode_process = _old_callback[body]
	_old_callback = {}


## Adds the "fight" animation library (stance, guard) to one AnimationPlayer, cut from its own attack clips.
static func _ensure_pose_clips(ap: AnimationPlayer) -> void:
	if ap.has_animation("fight/stance"):
		return
	var lib := AnimationLibrary.new()
	lib.add_animation("stance", _slice(ap.get_animation(STANCE[0]), STANCE[1], STANCE[2]))
	lib.add_animation("guard", _slice(ap.get_animation(GUARD[0]), GUARD[1], GUARD[2]))
	lib.add_animation("crouch", _slice(ap.get_animation(CROUCH[0]), CROUCH[1], CROUCH[2]))
	ap.add_animation_library("fight", lib)


## A looping clip whose key k is `src` sampled at frame frames[k], placed at times[k] seconds.
static func _slice(src: Animation, frames: Array, times: Array) -> Animation:
	var a := Animation.new()
	a.length = float(times[times.size() - 1])
	a.loop_mode = Animation.LOOP_LINEAR
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		var nt := a.add_track(type)
		a.track_set_path(nt, src.track_get_path(t))
		for k in frames.size():
			var at: float = times[k]
			var ft: float = float(frames[k]) / Fighter.FPS
			match type:
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(nt, at, src.position_track_interpolate(t, ft))
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(nt, at, src.rotation_track_interpolate(t, ft))
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(nt, at, src.scale_track_interpolate(t, ft))
				Animation.TYPE_BLEND_SHAPE:
					a.blend_shape_track_insert_key(nt, at, src.blend_shape_track_interpolate(t, ft))
				Animation.TYPE_VALUE:
					a.track_insert_key(nt, at, src.value_track_interpolate(t, ft))
	return a


func _release_player() -> void:
	_restore_clocks()
	if not is_instance_valid(bob_body):
		return
	bob_body.busy = false
	bob_body.posing = false
	var m := _model_of(bob_body)
	if not bob.is_ko():
		m.rotation.x = 0.0
		m.rotation.z = 0.0
	if is_instance_valid(_prev_camera):
		_prev_camera.make_current()


# --- bodies, clips, camera -------------------------------------------------------------------------------------------

func _body_of(f: Fighter):
	return bob_body if f == bob else foe_body


func _model_of(body: Node3D) -> Node3D:
	return body.get_node("Model")


func _pose_key(f: Fighter) -> String:
	match f.state:
		Fighter.State.KO:
			return "ko"
		Fighter.State.DIZZY:
			return "dizzy"
		Fighter.State.HIT:
			return "hit"
		Fighter.State.JUMP:
			return "jumpkick" if f.air_kick else "jump"
		Fighter.State.MOVE:
			return "move:" + f.move
	if f.crouching:
		return "crouch"
	if f.blocking:
		return "block"
	var moved: float = f.pos - float(_prev_pos.get(f, f.pos))
	if absf(moved) > 0.0001:
		return "walk_f" if signf(moved) == f.facing else "walk_b"
	return "idle"


func _update_poses() -> void:
	for f: Fighter in [bob, foe]:
		var body = _body_of(f)
		var key := _pose_key(f)
		if _shown.get(body, "") == key:
			continue
		_shown[body] = key
		var ap: AnimationPlayer = body.anim()
		var speed := 1.0
		if key.begins_with("move:"):
			var m: Dictionary = Fighter.MOVES[f.move]
			ap.play(m["clip"], 0.05)
			speed = m["speed"]
		elif key.begins_with("walk"):
			Pose.ensure_loop(ap, "walk")
			ap.play("walk", 0.1)
			speed = (1.0 if key == "walk_f" else -1.0) * Fighter.WALK_SPEED / WALK_AUTHORED
		elif key == "jumpkick": # the kick's extension (from frame 10) in the air
			ap.play("kick", 0.05)
			ap.seek(10.0 / Fighter.FPS, true)
			speed = 1.6
		elif key == "block":
			ap.play("fight/guard", 0.06)
		elif key == "crouch":
			ap.play("fight/crouch", 0.06)
		elif key == "dizzy" or key == "ko":
			Pose.ensure_loop(ap, "idle") # arms down: dazed / lying
			ap.play("idle", 0.15)
			speed = 0.5 if key == "dizzy" else 1.0
		else: # idle, jump, hit: the stance (jump and hit are placeholders, see the header)
			ap.play("fight/stance", 0.1)
		_want_speed[body] = speed


func _apply_speeds() -> void:
	for body in [bob_body, foe_body]:
		var ap: AnimationPlayer = body.anim()
		ap.speed_scale = 0.0 if hitstop_left > 0.0 else float(_want_speed.get(body, 1.0))


func _place(delta: float) -> void:
	for f: Fighter in [bob, foe]:
		var body: Node3D = _body_of(f)
		var y: float = _floor[body]
		if f.is_airborne():
			y += JUMP_HEIGHT * sin(PI * clampf(f.t / Fighter.JUMP_SECONDS, 0.0, 1.0))
		body.global_position = Vector3(_center.x, y, _center.z) + _axis * f.pos
		var dir := _axis * f.facing
		var m := _model_of(body)
		var tilt := 0.0
		var sway := 0.0
		if f.is_ko():
			tilt = move_toward(m.rotation.x, KO_TILT, delta * 5.0)
		elif f.state == Fighter.State.HIT:
			tilt = -0.3 * (1.0 - clampf(f.t / Fighter.HIT_STUN, 0.0, 1.0))
		elif f.is_dizzy():
			sway = 0.18 * sin(f.t * 5.0)
		elif f.blocking:
			tilt = -0.1 # braced, leaning away from the hit
		m.rotation = Vector3(tilt, atan2(dir.x, dir.z), sway)
	# the camera tracks the middle of the two, from the side, with a little shake on clean hits
	var mid := Vector3(_center.x, _center.y, _center.z) + _axis * clampf((bob.pos + foe.pos) / 2.0, -LINE_HALF + 1.0, LINE_HALF - 1.0)
	var fwd := Vector3.UP.cross(_axis)
	camera.global_position = mid - fwd * CAM_DIST + Vector3.UP * CAM_HEIGHT
	camera.look_at(mid + Vector3.UP * CAM_LOOK_HEIGHT, Vector3.UP)
	var s := SHAKE * (_shake_left / SHAKE_SECONDS)
	camera.h_offset = _rng.randf_range(-s, s)
	camera.v_offset = _rng.randf_range(-s, s)


## The camera stands outside the room behind a wall: clip everything nearer than the wall's inside face.
func _near_clip() -> float:
	var fwd := Vector3.UP.cross(_axis)
	var from := _center + Vector3.UP * CAM_HEIGHT
	var q := PhysicsRayQueryParameters3D.create(from, from - fwd * CAM_DIST, 1)
	var hit: Dictionary = bob_body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 0.05
	return CAM_DIST - from.distance_to(hit["position"]) + 0.3


func _register_actions() -> void:
	# keyboard only: WASD + Space (W jumps: move_forward, read in _unhandled_input)
	var keys := {"fight_attack": [KEY_SPACE]}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_add_event(action, ev)
