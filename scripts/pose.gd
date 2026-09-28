extends RefCounted
## Bone-posing helpers shared by Bob and Jijio (same skeleton and bone names, see the glb notes).
## Sitting, washing, the toilet sequence and locomotion are all baked clips now (FACTORY_TODO batches 1-2); only the
## shorts pull-up (no baked "pants up" clip exists) and the face/finger helpers below are still code-driven.

## How far each shorts bone travels down at slide = 1, from bob_godot_notes.md.
const SHORTS_TRAVEL := {
	"DEF-shorts_waist": 0.384,
	"DEF-shorts_L_0": 0.380, "DEF-shorts_R_0": 0.380,
	"DEF-shorts_L_1": 0.348, "DEF-shorts_R_1": 0.348,
	"DEF-shorts_L_2": 0.314, "DEF-shorts_R_2": 0.314,
	"DEF-shorts_L_3": 0.280, "DEF-shorts_R_3": 0.280,
	"DEF-shorts_hem_L": 0.264, "DEF-shorts_hem_R": 0.264,
}


static func skeleton_of(model: Node) -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0]


## idle/walk/run, FACTORY_TODO batch 1 (wired 2026-09-23). `speed` is the character's actual horizontal speed (m/s); `mid`
## is the speed that switches walk to run. `walk_authored`/`run_authored` are the pace the clips were made at (1.0 / 3.1 m/s,
## shared by Bob and Jijio): playback speed is scaled to the real speed so the feet don't slide. The loop flag on these three
## clips does not survive the glTF export, so it is set here rather than trusted from the file.
static func locomotion(ap: AnimationPlayer, speed: float, mid: float, walk_authored: float = 1.0, run_authored: float = 3.1) -> void:
	if ap == null:
		return
	for n in ["idle", "walk", "run"]:
		ensure_loop(ap, n)
	var clip := "idle"
	var authored := 1.0
	if speed > mid:
		clip = "run"
		authored = run_authored
	elif speed > 0.15:
		clip = "walk"
		authored = walk_authored
	if not ap.is_playing() or ap.current_animation != clip:
		ap.play(clip, 0.15)
	ap.speed_scale = 1.0 if clip == "idle" else speed / authored


## Stage 6b E: the factory `talk` clip (both rigs, 3 s loop) turns head and chest about 22 deg to the character's LEFT (the model's +X;
## tests/probe_talk_clip.gd: head 21.6, chest 25.0). A talker's body turns this far to the right of its partner so the head looks at them.
const TALK_TURN := 0.38 ## rad (22 deg)


## Loop the `talk` clip (cross-fade 0.25 s from whatever played, as the notes suggest).
static func talk(ap: AnimationPlayer) -> void:
	if ap == null or not ap.has_animation("talk"):
		return
	ensure_loop(ap, "talk")
	if not ap.is_playing() or ap.current_animation != "talk":
		ap.play("talk", 0.25)
	ap.speed_scale = 1.0


## The model yaw (front +Z) for a talker at `from` facing a partner at `to`: TALK_TURN to the right of the partner.
static func talk_yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) - TALK_TURN


## Stops any locomotion clip so procedural posing (the shorts pull-up, the only one left) has the skeleton to itself.
static func stop_locomotion(ap: AnimationPlayer) -> void:
	if ap != null and ap.is_playing():
		ap.stop()


## The glb's own loop flag does not survive export (FACTORY_TODO batches 1-2): call this once before the first
## `ap.play(name)` for any clip authored to loop (idle/walk/run/sit/wash).
static func ensure_loop(ap: AnimationPlayer, name: String) -> void:
	var a := ap.get_animation(name)
	if a.loop_mode != Animation.LOOP_LINEAR:
		a.loop_mode = Animation.LOOP_LINEAR


## Slide Bob's shorts down (slide 0 = worn, 1 = at the ankles), as described in bob_godot_notes.md.
## The offsets are applied in each bone's parent frame, so they follow the legs when Bob sits.
static func set_shorts_slide(sk: Skeleton3D, frame: Node3D, model: Node, slide: float) -> void:
	var down := (sk.global_basis.inverse() * (frame.global_basis * Vector3.DOWN)).normalized()
	for bone_name: String in SHORTS_TRAVEL:
		var i := sk.find_bone(bone_name)
		if i < 0:
			continue
		var parent := sk.get_bone_parent(i)
		var parent_basis := sk.get_bone_global_pose(parent).basis
		var travel: float = SHORTS_TRAVEL[bone_name]
		var offset: Vector3 = parent_basis.inverse() * (down * travel * slide)
		sk.set_bone_pose_position(i, sk.get_bone_rest(i).origin + offset)
	set_blend(model, "sk_shorts_bunch_ankle", slide)


## Collapse (or restore) the head by scaling its bone, so a camera at the eyes doesn't sit inside it.
## Hair, eyes and teeth are rigid to the head bone, so they vanish with it.
static func hide_head(sk: Skeleton3D, hidden: bool) -> void:
	var i := sk.find_bone("DEF-spine.006")
	if i >= 0:
		sk.set_bone_pose_scale(i, Vector3.ONE * (0.001 if hidden else 1.0))


## Drive one face/corrective shape key on every mesh that has it.
static func set_blend(root: Node, key: String, value: float) -> void:
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var idx := mi.find_blend_shape_by_name(key)
		if idx >= 0:
			mi.set_blend_shape_value(idx, value)
