extends SceneTree
## PROBE (not run by run.sh): every clip Bob's and a Jijio's AnimationPlayer has after the import, with its length and frame count at
## 30 fps. Used to check a factory republish (2026-09-25: 10 dance clips on both) before wiring anything.
const T := preload("res://tests/t.gd")


func _list(who: String, ap: AnimationPlayer) -> void:
	var names := ap.get_animation_list()
	print("INFO %s: %d clips" % [who, names.size()])
	for n in names:
		var a := ap.get_animation(n)
		print("INFO   %s  %.3f s  %d f  loop %d" % [n, a.length, roundi(a.length * 30.0), a.loop_mode])


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	_list("Bob", lvl.player.anim())
	var npc: Node3D = lvl.population.queue[0]
	_list("Jijio", npc.find_children("*", "AnimationPlayer", true, false)[0])
	lvl.queue_free()
	await process_frame
	quit()
