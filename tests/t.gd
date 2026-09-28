extends RefCounted
## Tiny test helper. Each test is a script `extends SceneTree` run with:
##   godot --headless --path . --script tests/<name>.gd
## and ends with T.finish(self). Exit code is 1 if any check failed.

## Which level number holds which game (owner, Stage 6b: Levels 2 and 3 swapped). Tests use these, never a bare 2 or 3.
const HIDE_LEVEL := 2
const FLOOD_LEVEL := 3

static var passed := 0
static var failed := 0
static var dry := false ## true (or `-- dry`): the flood level loads without starting the flood (tests of the puddle and mop mechanics, see puddle())
static var intro := false ## true: the level plays its start dialogue (intro.gd), the clock waits for it


static func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS  ", message)
	else:
		failed += 1
		print("FAIL  ", message)


static func finish(tree: SceneTree) -> void:
	print("RESULT  %d passed, %d failed" % [passed, failed])
	tree.quit(1 if failed > 0 else 0)


## Wait `seconds` of physics time.
static func wait(tree: SceneTree, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await tree.physics_frame


## Poll `predicate` (a Callable returning bool) every 0.1 s until it is true or `timeout` seconds pass, whichever
## first (a hung `while` with no cap is the thing that made day-3 tests hang on a script error).
static func wait_for(tree: SceneTree, predicate: Callable, timeout: float) -> void:
	var waited := 0.0
	while not predicate.call() and waited < timeout:
		await wait(tree, 0.1)
		waited += 0.1


## Press and release a key (goes through the real input path).
static func key(tree: SceneTree, code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await tree.physics_frame


## Press a key and keep it down (release it with key_up).
static func key_down(tree: SceneTree, code: int) -> void:
	_key_event(code, true)
	await tree.physics_frame


static func key_up(tree: SceneTree, code: int) -> void:
	_key_event(code, false)
	await tree.physics_frame


static func _key_event(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## One real right-click (goes through the real input path, like the player's mouse).
static func right_click(tree: SceneTree) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.pressed = pressed
		ev.position = tree.root.get_visible_rect().size / 2.0
		Input.parse_input_event(ev)
		await tree.physics_frame


## One real left-click (Level 4: punch).
static func left_click(tree: SceneTree) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = tree.root.get_visible_rect().size / 2.0
		Input.parse_input_event(ev)
		await tree.physics_frame


## Press and hold the left mouse button (Level 4 water fight: spray; release with left_up).
static func left_down(tree: SceneTree) -> void:
	_button_event(tree, MOUSE_BUTTON_LEFT, true)
	await tree.physics_frame


static func left_up(tree: SceneTree) -> void:
	_button_event(tree, MOUSE_BUTTON_LEFT, false)
	await tree.physics_frame


static func _button_event(tree: SceneTree, button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = tree.root.get_visible_rect().size / 2.0
	Input.parse_input_event(ev)


## Press and hold the right mouse button (release with right_up).
static func right_down(tree: SceneTree) -> void:
	_right_event(tree, true)
	await tree.physics_frame


static func right_up(tree: SceneTree) -> void:
	_right_event(tree, false)
	await tree.physics_frame


static func _right_event(tree: SceneTree, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = pressed
	ev.position = tree.root.get_visible_rect().size / 2.0
	Input.parse_input_event(ev)


## Stand Bob at `from`, turn him toward `target` (a floor point) and tilt the camera until the screen-centre crosshair meets the
## floor within 0.15 m of `target`. Returns how far off the best pitch was (metres); a big number means no pitch can aim there.
static func aim_at(tree: SceneTree, p: CharacterBody3D, mop: Node, from: Vector3, target: Vector3) -> float:
	p.global_position = from
	var dir := target - from
	dir.y = 0.0
	p.face_direction(dir.normalized())
	var yaw := atan2(-dir.x, -dir.z)
	var best := INF
	var best_pitch := -0.5
	var pitch := -0.4
	while pitch > -1.15:
		p.set_camera(yaw, pitch)
		await tree.physics_frame
		await tree.process_frame
		mop.call("_aim")
		if mop.target_valid:
			var err := Vector2(mop.target.x - target.x, mop.target.z - target.z).length()
			if err < best:
				best = err
				best_pitch = pitch
			if err < 0.1:
				break
			if mop.target.distance_to(from) < target.distance_to(from) - 0.3:
				break # the crosshair has passed the target on its way down
		pitch -= 0.01
	if best >= 0.1:
		p.set_camera(yaw, best_pitch)
		await tree.physics_frame
		await tree.process_frame
		mop.call("_aim")
	return best


## Load the level. The walking Jijios are OFF by default so an unrelated test cannot be disturbed by one wandering
## into its path; pass `with_walkers` (or run with `-- walkers` after the script name) to test with them.
## `-- flood` loads the flood level (FLOOD_LEVEL) instead of Level 1, for tests that are the same in every level.
static func level(tree: SceneTree, with_walkers := false) -> Node:
	const Walkers := preload("res://scripts/walkers.gd")
	const Progress := preload("res://scripts/progress.gd")
	const Flood := preload("res://scripts/flood.gd")
	Walkers.enabled = with_walkers or OS.get_cmdline_user_args().has("walkers")
	# The start dialogue pauses the clock until it is clicked through: off unless a test asks for it (`intro = true` or `-- intro`).
	const Intro := preload("res://scripts/intro.gd")
	Intro.enabled = intro or OS.get_cmdline_user_args().has("intro")
	# Level 2 "The flood": the story starts at once (no intro in tests) unless the test wants a dry level for the puddle mechanics.
	const FloodStory := preload("res://scripts/flood_story.gd")
	FloodStory.auto_start = not (dry or OS.get_cmdline_user_args().has("dry"))
	if OS.get_cmdline_user_args().has("flood"):
		Progress.level = FLOOD_LEVEL
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	tree.get_root().add_child(lvl)
	return lvl


## World position of a bone of a character model (Bob's `player.model()` or a Jijio's `_model`), e.g. "DEF-spine.006" = the head.
static func bone_at(model: Node3D, bone: String) -> Vector3:
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


## The clip a character model is playing ("" when stopped).
static func clip_of(model: Node3D) -> String:
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	return String(ap.current_animation) if ap != null and ap.is_playing() else ""


## A puddle for the tests of the puddle, mop and slip mechanics in a DRY Level 2 (`dry = true`): the game's puddles are now the flood's
## leftovers (flood.gd start_residue), these tests start one with start(stall) / start_sink(k) / start_residue(pos) themselves.
## Call after the first wait (the level's @onready members are null before).
static func puddle(lvl: Node) -> Node3D:
	const Flood := preload("res://scripts/flood.gd")
	var f: Node3D = Flood.new()
	f.name = "TestPuddle"
	lvl.add_child(f)
	f.setup(lvl)
	lvl.floods.append(f)
	lvl.flood = f
	return f
