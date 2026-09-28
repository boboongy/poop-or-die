extends Node
## Add as a child of a walker (Bob, a Jijio): plays a footstep every `stride` metres the parent really moves on the floor.
## Nothing plays while the parent is standing, sitting, in the air, or moved by a code-driven sequence (`busy`).

const Sfx := preload("res://scripts/sfx.gd")

@export var stride := 0.85
@export var min_speed := 0.5 ## m/s: slower drifting (a queue Jijio settling back) makes no steps
const SWIM_STRIDE := 1.2 ## m per swimming stroke (Bob swims at 2.2 m/s: about two strokes a second)
const RUN_SPEED := 4.0 ## m/s: faster = the running squeak (player.gd ANIM_WALK_RUN_MID: the run clip plays above this too)

var _last := Vector3.ZERO
var _phase := -1.0 ## the parent's swim clip phase last frame (-1 = not swimming)
var _distance := 0.0
var _parent: Node3D


func _ready() -> void:
	_parent = get_parent() as Node3D
	_last = _parent.global_position
	# Out of step with each other: a crowd that starts running in the same frame (Level 2's rampage at GO) put 8 steps on one frame,
	# 0 dB in the recorded mix. From the instance id, not the RNG (a new random draw shifts every seeded test's sequence).
	_distance = float(get_instance_id() % 997) / 997.0 * stride


func _physics_process(delta: float) -> void:
	var here := _parent.global_position
	var moved := Vector2(here.x - _last.x, here.z - _last.z).length()
	_last = here
	if moved > 1.0 or delta <= 0.0: # a teleport, not a walk
		return
	if "busy" in _parent and _parent.busy:
		return
	if _parent.has_method("is_sitting") and _parent.is_sitting():
		return
	# Level 2's flood: a stroke splash every SWIM_STRIDE while swimming (Bob only: the floating crowd would be a wall of splashes),
	# a wading splash instead of a step in shallow water.
	var w = _parent.get("water")
	var depth: float = w.depth_at(here) if w != null else 0.0
	if _parent.get("swimming") == true:
		# Stage 6: synced to the `swim` clip (a splash each time it passes the stroke phase); by distance if the parent has no clip phase
		if _parent.has_method("swim_phase"):
			var phase: float = _parent.swim_phase()
			var at: float = _parent.SWIM_SPLASH_PHASE
			if phase >= 0.0 and _phase >= 0.0 and fposmod(at - _phase, 1.0) < fposmod(phase - _phase, 1.0) and moved / delta >= min_speed:
				Sfx.play_at(_parent, "swim", here + Vector3.UP * 0.6)
			_phase = phase
		elif moved / delta >= min_speed:
			_distance += moved
			if _distance >= SWIM_STRIDE:
				_distance -= SWIM_STRIDE
				Sfx.play_at(_parent, "swim", here + Vector3.UP * 0.6)
		return
	_phase = -1.0
	if _parent is CharacterBody3D and not _parent.is_on_floor():
		return
	if moved / delta < min_speed:
		return
	_distance += moved
	if _distance >= stride:
		_distance -= stride
		Sfx.play_at(_parent, "wade" if depth > 0.05 else ("run_step" if moved / delta >= RUN_SPEED else "step"), here)
