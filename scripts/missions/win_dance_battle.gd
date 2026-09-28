extends "res://scripts/missions/mission.gd"
## Level 5, mission 3: win the dance battle against SHUFFLE QUEEN (dance.gd `battle_won`). Only then does her stall open (the level's
## reward flow on ctx "reward_stall").


func _init() -> void:
	id = "battle"
	title = "Win the dance battle"
	requires.assign(["find_dancer"])


func activate() -> void:
	hint = "beat SHUFFLE QUEEN: best of 3 rounds"
	level.dance.battle_won.connect(finish, CONNECT_ONE_SHOT)
	super.activate()
