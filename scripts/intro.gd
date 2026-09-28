extends Node
## The start-of-level dialogue (owner 2026-09-25: "for all levels I want dialogue at the start where Bob as usual tries to cut the queue,
## so the player understands the context of the game and has enough time to act"). The level clock is PAUSED while it plays and starts
## with a big "GO!"; Enter skips the whole intro (retries). LevelDefs "intro" names the scene played here (every level has one since 6b).

const Sfx := preload("res://scripts/sfx.gd")

static var enabled := true ## tests switch this off (t.gd), so unrelated tests start with the clock running; `-- intro` keeps it on

signal finished

const GHOST_REPLIES := ["Just let me squeeze in, I'm bursting!", "Whoa, is that a spider on your back? Let me get it...", "Hey, isn't that your friend at the front?"]
const GHOST_REBUTTALS := ["Bursting? Everybody in here is bursting.", "Nice try. There's nothing on my back. There never is.", "I have no friends. I've been in this queue a very... long... time."]
const GHOST_COLOR := Color(0.7, 0.95, 1.0, 0.45) ## pale, see-through; the emission makes it read in the green-lit room (skill 3c)
const GHOST_GLOW := Color(0.35, 0.85, 1.0)
const FLOAT_UP := 0.3 ## m: the ghost rises off the floor when it shows itself
const GO_SECONDS := 1.2
const INTRO_SHOULDER := 0.5 ## m: the camera pivot slides right during the talk so the speaker is not behind Bob's head
## Level 3's fart scene (SPEC Round 2 Stage 2, owner 2026-09-25; Bob's lines are Claude's default, owner 2026-09-27 "yes to all"):
## the ghost farts, a brown cloud fills the waiting room, the queue complains, Bob mocks the smell, walks up to the farter and accuses it.
const BOB_LINES := ["EWWW! What is THAT smell?! Did something crawl in here and DIE?", "YOU! It was you, wasn't it? You smell like a sewer that's been dead for a hundred years!"]
const CROWD_SHOUTS := ["UGH!", "WHO DID THAT?!"]
## Saturated and unshaded: a pale or dark haze vanishes in this green-lit white-tile room (skill 3c). Puffs fade near the camera.
const CLOUD_COLOR := Color(0.4, 0.22, 0.04, 0.72) ## screenshots: (0.5, 0.3, 0.05, 0.55) read orange-amber, (0.3, 0.17, 0.04, 0.6) faint murky patches
const CLOUD_ROOM := AABB(Vector3(-4.9, 0.4, -1.75), Vector3(4.3, 1.9, 3.5)) ## where the puffs' centres end up: the waiting room
const CLOUD_GRID := Vector3i(5, 2, 4) ## one puff per cell (x, y, z), jittered: the whole room is covered, not a random clump
const CLOUD_SPREAD_SECONDS := 2.4
## The farter (who is the ghost) stands in the front line, 2.2 m from Bob, so he can walk up to it (queue[4], the Jijio the old intro
## used, is only 1.1 m away across the snake). The queue makes way for him as usual.
const FARTER := 1
const CONFRONT_DISTANCE := 1.2 ## m: Bob stops this far from the farter
const CONFRONT_MAX_SECONDS := 3.5
## s: the fart (fart_06, 2 s) plays alone, then the queue reacts, then Bob speaks. Overlapping them (shouts at 0.5 s, Bob at 1.4 s) hit
## 0 dB in the recorded mix (tests/probe_soundscape.gd).
const FART_ALONE := 2.0
const BOB_AFTER_SHOUTS := 1.6 ## s after FART_ALONE: at 0.9 Bob's shouted "EWWW!" landed on "WHO DID THAT?!" and hit -0.1 dB (2 of 3 runs)

var skipped := false
var playing := false
var ghost: Node3D ## Level 3: the Jijio ahead of Bob, who turns out to be a ghost (tests read it)
var cloud: Node3D ## Level 3: the fart cloud (tests read it); freed once it has faded after GO

var _level: Node3D
var _mats: Array[StandardMaterial3D] = []
var _light_energy := {}
var _go: Label


## Play the intro `id` for `level`, then show GO!. Returns when the clock may start.
func run(level: Node3D, id: String) -> void:
	_level = level
	playing = true
	match id:
		"ghost":
			await _fart_scene()
			await _ghost_intro()
		"flood":
			await _flood_intro()
		"cut_in":
			await _cut_in_intro()
	_restore_lights()
	level.player.frozen = false
	level.player.auto_move = Vector3.ZERO
	_clear_cloud(0.6 if skipped else 3.0)
	playing = false
	finished.emit()
	_show_go()


func _input(event: InputEvent) -> void:
	if not playing or skipped or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		skipped = true
		get_viewport().set_input_as_handled()
		_level.dialogue.force_close()


# --- Level 2: the flood (SPEC Round 2 Stage 3, owner "yes" 2026-09-27; the lines are Claude's, accepted with the plan) ---------------

const FLOOD_BOB := ["Excuse me! Coming through! Tiny bladder, very important!", "It's my birthday! Birthday Bob goes first!", "Oh no. I'm gonna need a plunger."]
const FLOOD_QUEUE := ["Mm-hm. Back of the line, sweetie.", "Happy birthday. The line's still that way."]
const FLOOD_SCREAM := "OH NO. NO NO NO! I CLOGGED IT!! IT'S COMING OUT!!"
const FLOOD_CROWD := ["EWWW!", "RUN!"]
const FLOOD_BLAST_ALONE := 1.8 ## s: the blast plays alone before the scream


## Bob tries to talk his way past the two Jijios ahead; both blank him. Then a blast from the clogged stall (flood_story.gd), the
## clogger screams, the queue shouts, Bob sighs. The stall bursts open at GO (flood_story.start()).
func _flood_intro() -> void:
	var d = _level.dialogue
	var player: CharacterBody3D = _level.player
	var queue: Array = _level.population.queue
	var story: Node3D = _level.flood_story
	player.frozen = true
	var shoulder_before: float = player.shoulder
	player.shoulder = INTRO_SHOULDER
	var ahead: Node3D = queue[4] # 1.1 m ahead of Bob
	player.turn_toward(ahead.global_position)
	# one call per line, with the constants written out: tools/make_voices.py finds the lines by reading these calls
	if not skipped:
		await d.say(player, FLOOD_BOB[0], false, "Bob")
	if not skipped:
		await d.say(ahead, FLOOD_QUEUE[0])
	if not skipped:
		await d.say(player, FLOOD_BOB[1], false, "Bob")
	if not skipped:
		await d.say(queue[1], FLOOD_QUEUE[1])
	d.hide_box()
	if not skipped:
		story.blast()
		await get_tree().create_timer(FLOOD_BLAST_ALONE, false).timeout
	if not skipped:
		await d.say(story.clogger, FLOOD_SCREAM)
		d.hide_box()
	if not skipped:
		for k in FLOOD_CROWD.size():
			d.bubble(queue[[2, 6][k] % queue.size()], FLOOD_CROWD[k], 1.6)
		await get_tree().create_timer(1.2, false).timeout
	if not skipped:
		await d.say(player, FLOOD_BOB[2], false, "Bob")
	d.hide_box()
	player.shoulder = shoulder_before


# --- Levels 1, 4 and 5: Bob asks to cut in (SPEC Stage 6b D; the lines are Claude's, owner "Ok" 2026-09-28) ------------------------

const CUT_IN_LEVELS := [1, 4, 5]
const CUT_IN_BOB := ["I really need to go! Can I go first? Please?", "I really need to go! Can I just slip in ahead of you?", "I really need to go! Pretty please?"]
const CUT_IN_JIJIO := ["Everybody needs to go, sweetie. And good luck finding toilet paper in there.", "No cutting! Some real line-cutters come through here, you know.", "Shh. Can't you hear that music? Some of us are trying to vibe."]


## Bob asks the Jijio just ahead of him to let him go first; the answer is no (and a hint at the level). Then GO.
func _cut_in_intro() -> void:
	var d = _level.dialogue
	var player: CharacterBody3D = _level.player
	var ahead: Node3D = _level.population.queue[4] # 1.1 m ahead of Bob
	var k := CUT_IN_LEVELS.find(_level.level_number)
	player.frozen = true
	var shoulder_before: float = player.shoulder
	player.shoulder = INTRO_SHOULDER
	player.turn_toward(ahead.global_position)
	if not skipped:
		await d.say(player, CUT_IN_BOB[k], false, "Bob")
	if not skipped:
		await d.say(ahead, CUT_IN_JIJIO[k])
	d.hide_box()
	player.shoulder = shoulder_before


# --- Level 3: the ghost -------------------------------------------------------------------------------------------------

## Bob tries to squeeze past the Jijio ahead of him; every excuse fails; it turns round: a GHOST, who starts the hide and seek and
## vanishes. It leaves the queue for good (8 queue seekers instead of 9).
func _ghost_intro() -> void:
	var d = _level.dialogue
	var player: Node3D = _level.player
	ghost = _level.population.queue[FARTER]
	if skipped:
		_remove_ghost()
		return
	var shoulder_before: float = player.shoulder
	player.shoulder = INTRO_SHOULDER # Bob's head hid the ghost (first screenshot): look past his shoulder
	d.begin(ghost, player)
	var pick: int = await d.choose(ghost, "Hm? Oh, it's YOU again. Back of the line, pal.", GHOST_REPLIES)
	if not skipped:
		Sfx.play_ui(_level, "ui_wrong")
		await d.say(ghost, GHOST_REBUTTALS[pick])
	if not skipped:
		await d.say(ghost, "You want MY place? Do you know how long I've been waiting for this toilet?")
	if not skipped:
		reveal()
		await d.say(ghost, "A HUNDRED YEARS.", false, "GHOST")
	if not skipped:
		await d.say(ghost, "Let's play a game, Bob. Everyone in here counts to twenty... and you HIDE.", false, "GHOST")
	if not skipped:
		await d.say(ghost, "If they find you... you're MINE. Hee hee hee...", false, "GHOST")
	d.end(ghost, player)
	if skipped:
		_remove_ghost()
		player.shoulder = shoulder_before
		return
	player.busy = true
	await _vanish()
	player.busy = false
	player.shoulder = shoulder_before


## The ghost (still looking like a Jijio) farts; the cloud spreads; two in the queue complain; Bob mocks the smell, walks up and accuses it.
func _fart_scene() -> void:
	var d = _level.dialogue
	var player: CharacterBody3D = _level.player
	var queue: Array = _level.population.queue
	ghost = queue[FARTER]
	player.frozen = true
	Sfx.play_at(_level, "fart_loud", ghost.global_position + Vector3.UP * 0.5)
	_make_cloud(ghost.global_position + Vector3.UP * 0.6)
	for k in CROWD_SHOUTS.size():
		var npc: Node3D = queue[[2, 6][k] % queue.size()]
		get_tree().create_timer(FART_ALONE + 0.5 * k, false).timeout.connect(func() -> void:
			if playing and is_instance_valid(npc):
				d.bubble(npc, CROWD_SHOUTS[k], 1.6))
	await get_tree().create_timer(FART_ALONE + BOB_AFTER_SHOUTS, false).timeout
	if skipped:
		return
	player.turn_toward(ghost.global_position)
	await d.say(player, BOB_LINES[0], false, "Bob")
	if skipped:
		return
	d.hide_box()
	var walked := 0.0
	while not skipped and walked < CONFRONT_MAX_SECONDS:
		var to: Vector3 = ghost.global_position - player.global_position
		to.y = 0.0
		if to.length() <= CONFRONT_DISTANCE:
			break
		player.auto_move = to.normalized()
		await get_tree().physics_frame
		walked += get_physics_process_delta_time()
	player.auto_move = Vector3.ZERO
	if skipped:
		return
	await get_tree().create_timer(0.3, false).timeout
	player.turn_toward(ghost.global_position)
	await d.say(player, BOB_LINES[1], false, "Bob")


## About 40 soft brown puffs burst out of the farter and spread over the waiting room.
func _make_cloud(from: Vector3) -> void:
	cloud = Node3D.new()
	cloud.name = "FartCloud"
	_level.add_child(cloud)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cell := CLOUD_ROOM.size / Vector3(CLOUD_GRID)
	for ix in CLOUD_GRID.x:
		for iy in CLOUD_GRID.y:
			for iz in CLOUD_GRID.z:
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				mat.billboard_keep_scale = true
				mat.albedo_texture = tex
				mat.albedo_color = Color(CLOUD_COLOR, CLOUD_COLOR.a * rng.randf_range(0.7, 1.0))
				mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA # a puff at the camera would turn the screen solid brown
				mat.distance_fade_min_distance = 0.5
				mat.distance_fade_max_distance = 2.0
				var quad := QuadMesh.new()
				quad.size = Vector2.ONE
				var puff := MeshInstance3D.new()
				puff.mesh = quad
				puff.material_override = mat
				puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				cloud.add_child(puff)
				puff.global_position = from
				puff.scale = Vector3.ONE * 0.2
				var target := CLOUD_ROOM.position + cell * (Vector3(ix, iy, iz) + Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)))
				var delay := rng.randf_range(0.0, 0.5)
				var t := CLOUD_SPREAD_SECONDS * rng.randf_range(0.6, 1.0)
				var tw := puff.create_tween().set_parallel(true)
				tw.tween_property(puff, "global_position", target, t).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				# every third puff small and thick, so it reads as billowing puffs, not an even haze (screenshot)
				var small := (ix + iy + iz) % 3 == 0
				if small:
					mat.albedo_color.a = minf(CLOUD_COLOR.a * 1.4, 0.9)
				tw.tween_property(puff, "scale", Vector3.ONE * (rng.randf_range(0.7, 1.0) if small else rng.randf_range(1.4, 2.2)), t).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Where the cloud reaches (world space, each puff counted with its size).
func cloud_bounds() -> AABB:
	var box := AABB()
	var first := true
	for puff: MeshInstance3D in cloud.get_children() if is_instance_valid(cloud) else []:
		var half := puff.scale * 0.5
		var b := AABB(puff.global_position - half, half * 2.0)
		box = b if first else box.merge(b)
		first = false
	return box


func _clear_cloud(seconds: float) -> void:
	if not is_instance_valid(cloud):
		return
	var tw := cloud.create_tween().set_parallel(true)
	for puff: MeshInstance3D in cloud.get_children():
		tw.tween_property(puff.material_override, "albedo_color:a", 0.0, seconds)
		tw.tween_property(puff, "global_position:y", puff.global_position.y + 0.4, seconds)
	await tw.finished
	if is_instance_valid(cloud):
		cloud.queue_free()


## The Jijio shows what it is: pale, see-through, glowing, floating; the lights flicker.
func reveal() -> void:
	if ghost == null or not _mats.is_empty():
		return
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count() if m.mesh else 0:
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = GHOST_COLOR
			mat.emission_enabled = true
			mat.emission = GHOST_GLOW
			mat.emission_energy_multiplier = 1.2
			m.set_surface_override_material(s, mat)
			_mats.append(mat)
	ghost.set_physics_process(false) # it floats: no gravity, no queue logic
	var tw := create_tween()
	tw.tween_property(ghost, "global_position:y", ghost.global_position.y + FLOAT_UP, 0.8).set_trans(Tween.TRANS_SINE)
	Sfx.play_at(_level, "scare", ghost.global_position + Vector3.UP)
	_flicker()


func is_ghostly() -> bool:
	return not _mats.is_empty()


func _flicker() -> void:
	var lights := _level.find_children("*", "Light3D", true, false)
	for node in lights:
		var l := node as Light3D
		if not _light_energy.has(l):
			_light_energy[l] = l.light_energy
	for k in 6:
		for l: Light3D in _light_energy:
			if is_instance_valid(l):
				l.light_energy = _light_energy[l] * (0.12 if k % 2 == 0 else 1.0)
		await get_tree().create_timer(0.09 if k % 2 == 0 else 0.14).timeout
	_restore_lights()


func _restore_lights() -> void:
	for l: Light3D in _light_energy:
		if is_instance_valid(l):
			l.light_energy = _light_energy[l]


## Fades out while rising, then leaves the level.
func _vanish() -> void:
	var tw := create_tween().set_parallel(true)
	for mat in _mats:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.9)
	tw.tween_property(ghost, "global_position:y", ghost.global_position.y + 0.6, 0.9)
	await tw.finished
	_remove_ghost()


func _remove_ghost() -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	_level.population.queue.erase(ghost)
	ghost.visible = false
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	ghost.set_physics_process(false)
	ghost.set_process(false)
	if ghost.is_in_group("interactable"):
		ghost.clear_interaction()


func _show_go() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_go = Label.new()
	_go.text = "GO!"
	_go.set_anchors_preset(Control.PRESET_FULL_RECT)
	_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_go.add_theme_font_size_override("font_size", 120)
	_go.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_go.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_go.add_theme_constant_override("outline_size", 18)
	_go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_go)
	var tw := create_tween()
	tw.tween_interval(GO_SECONDS * 0.6)
	tw.tween_property(_go, "modulate:a", 0.0, GO_SECONDS * 0.4)
	tw.tween_callback(layer.queue_free)
