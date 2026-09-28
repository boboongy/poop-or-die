extends "res://scripts/missions/mission.gd"
## Level 5, mission 2: find SHUFFLE QUEEN (dance.gd) dancing outside the stall that is about to open, and talk to her. The hint
## never names the stall (owner: Bob "happens to see" her); the boombox's beat gets louder as he gets closer.


func _init() -> void:
	id = "find_dancer"
	title = "Find another way in"
	requires.assign(["finesse"])


func activate() -> void:
	hint = "look around the stalls (follow the music)"
	level.dance.challenged_bob.connect(finish, CONNECT_ONE_SHOT)
	level.dance.enable_talk()
	super.activate()
