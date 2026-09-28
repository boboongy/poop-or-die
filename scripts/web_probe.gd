extends Node
## Web build diagnosis (added by liminal_lighting.gd, web only): every 3 s prints the FPS and where the frame time goes to the
## browser console when the page address has any switch (index.html?probe), e.g. index.html?chars=0&anim=0:
##   chars=0 hide every character, anim=0 freeze every Jijio's AnimationPlayer, phys=0 stop physics.

var _next := 0 ## wall-clock msec of the next report
var _query := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the opening dialogue pauses the tree
	var q: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(q) == TYPE_STRING:
		for pair in (q as String).trim_prefix("?").split("&", false):
			var kv := pair.split("=")
			_query[kv[0]] = kv[1] if kv.size() > 1 else "1"
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if _query.get("phys") == "0":
		Engine.physics_ticks_per_second = 1
	if not _query.is_empty():
		print("web_probe switches: ", _query)


func _process(_delta: float) -> void:
	if _query.is_empty(): # players: nothing unless the address asks for it (index.html?probe)
		set_process(false)
		return
	var now := Time.get_ticks_msec()
	if _query.get("chars") == "0" or _query.get("anim") == "0":
		for s in get_tree().get_nodes_in_group("jijio"):
			if _query.get("anim") == "0":
				var ap: AnimationPlayer = s.anim()
				if ap != null and ap.is_playing():
					ap.pause()
			if _query.get("chars") == "0":
				(s as Node3D).visible = false
	if now < _next:
		return
	_next = now + 3000
	var rid := get_viewport().get_viewport_rid()
	print("web_probe frame %d  fps %d  process %.1f ms  physics %.1f ms  render cpu %.1f ms  gpu %.1f ms  draw calls %d" % [
		Engine.get_process_frames(), Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
