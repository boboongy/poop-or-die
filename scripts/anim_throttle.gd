extends Node
## Web build only (Compatibility renderer, added by liminal_lighting.gd): every Jijio further than NEAR metres from the camera
## is animated on every EVERY-th frame (staggered, with the time it missed), the near ones every frame. Posing ~33 skinned
## characters every frame was the web build's biggest cost: tests/probe_compat_fps.gd, Level 3, 3 runs each, 24 -> 32 FPS.

const NEAR := 5.0
const EVERY := 3

var _owed := {} ## AnimationPlayer -> seconds of animation not yet advanced
var _tick := 0


func _process(delta: float) -> void:
	_tick += 1
	var cam := get_viewport().get_camera_3d()
	var i := 0
	for npc in get_tree().get_nodes_in_group("jijio"):
		var ap: AnimationPlayer = npc.anim()
		if ap == null or not is_instance_valid(ap):
			continue
		i += 1
		if ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var owed: float = _owed.get(ap, 0.0) + delta
		var near := cam == null or cam.global_position.distance_to((npc as Node3D).global_position) < NEAR
		if near or (i + _tick) % EVERY == 0:
			ap.advance(owed)
			owed = 0.0
		_owed[ap] = owed
	if _tick % 300 == 0: # forget freed Jijios
		for ap in _owed.keys():
			if not is_instance_valid(ap):
				_owed.erase(ap)
