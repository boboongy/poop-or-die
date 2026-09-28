extends "res://scripts/missions/mission.gd"
## Level 1, mission 1: the person in front of Bob in the queue tells him someone in a stall has run out of
## tissue. Choosing "Not my problem" just repeats the talk (retry only, no time lost).

var _npc: Node3D


func _init() -> void:
	id = "ask"
	title = "Ask the queue who needs help"


func activate() -> void:
	hint = "talk to the Jijio right in front of you (E)"
	_npc = level.population.queue[4] # the queue spot straight ahead of Bob's spawn
	_npc.set_interaction("E  talk", _talk)
	super.activate()
	if level.intro_playing: # Stage 6b D: after the start dialogue (the same Jijio speaks in it), not over it
		await level.intro_done
	level.dialogue.bubble(_npc, "Psst! You look as desperate as I feel...", 5.0)


func _talk(player: Node3D) -> void:
	var d = level.dialogue
	d.begin(_npc, player)
	if not level.ctx.has("needy"):
		level.ctx["needy"] = level.population.pick_free_stall()
	var index: int = level.ctx["needy"]
	var number := index % 10 + 1
	var row_name := "first row (along the corridor you walk in from)" if index < 10 else "back row (the corridor behind the stalls)"
	await d.say(_npc, "Ugh, that knocking again... The person in the %s, stall number %d from the entrance, has run out of tissue!" % [row_name, number])
	var pick: int = await d.choose(_npc, "Are you going to help them?", ["Yes, I'll find some tissue.", "Not my problem."])
	if pick == 1:
		Sfx.play_ui(level, "ui_wrong")
		await d.say(_npc, "Then stop wasting my time. Come back when you change your mind.")
		d.end(_npc, player)
		return # stays active: retry, no time lost
	await d.say(_npc, "Thank you! There should be tissue lying around. Try near the sinks, the back corridor or this waiting room.")
	d.end(_npc, player)
	_npc.clear_interaction()
	finish()
