extends SceneTree
## PROBE (not run by run.sh): every stall door's interaction point and its occupant's position, both rows, to derive where the
## door plane is and which way the corridor lies (Level 4: the cutters stand in front of the open stall).
const T := preload("res://tests/t.gd")


func _init() -> void:
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	for i in 20:
		var door: Node3D = lvl.stalls.doors[i]
		var occ: Node3D = lvl.population.occupants[i]
		print("stall %d: door point %s  door node %s  occupant %s" % [i, door.point, door.global_position, occ.global_position])
	print("door_for(1,5) == doors[4]: ", lvl.stalls.door_for(1, 5) == lvl.stalls.doors[4], "   door_for(2,5) == doors[14]: ", lvl.stalls.door_for(2, 5) == lvl.stalls.doors[14])
	lvl.queue_free()
	await process_frame
	quit()
