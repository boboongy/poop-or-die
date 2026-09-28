extends "res://scripts/missions/mission.gd"
## Level 5, mission 1 (owner's story: "Bob talks to Jijio trying to finesse"): the Jijio right in front of Bob in the queue. Every
## excuse fails, but the talk ends with a hint about music by the stalls, which is where SHUFFLE QUEEN dances (dance.gd).

const REPLIES := ["It's an emergency!", "I'm a VIP. Let me through.", "Whoa, look over there!"]
const REBUTTALS := ["Everyone in this queue is an emergency, pal.", "A VIP? In a toilet queue? Ha!", "Nice try. I'm not turning around."]

var _npc: Node3D


func _init() -> void:
	id = "finesse"
	title = "Talk your way to the front"


func activate() -> void:
	hint = "try the Jijio right in front of you (E)"
	_npc = level.population.queue[4] # the queue spot straight ahead of Bob's spawn (same Jijio as Level 1)
	_npc.set_interaction("E  talk", _talk)
	super.activate()
	if level.intro_playing: # Stage 6b D: after the start dialogue (the same Jijio speaks in it), not over it
		await level.intro_done
	level.dialogue.bubble(_npc, "Don't even THINK about cutting in.", 5.0)


func _talk(player: Node3D) -> void:
	var d = level.dialogue
	d.begin(_npc, player)
	var pick: int = await d.choose(_npc, "What do you want? I'm not letting anybody in front of me.", REPLIES)
	Sfx.play_ui(level, "ui_wrong")
	await d.say(_npc, REBUTTALS[pick])
	await d.say(_npc, "Go bother someone else... Hey, do you hear music? Somebody's having a party back there by the stalls.")
	d.end(_npc, player)
	_npc.clear_interaction()
	finish()
