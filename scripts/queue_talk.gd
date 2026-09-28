extends Node
## Stage 6c D (owner "yes to all" 2026-09-28, SPEC "Stage 6c D details"): E on any Jijio standing in the waiting-room queue (all 5 levels)
## opens a small talk: one of that Jijio's own 3 lines, then the level's walker hint, with the same first-person pan as the walkers
## (dialogue.begin). Reach 1.5 m for the queue only; a stall door still wins (walkers' TALK_PRIORITY); W/A/S/D or Esc leave at once.
## No talk while a scene owns the queue (the start dialogue, hide-and-seek, the flood, a fight, the dance battle, the timeout rush).
## A prompt another script put on a queue Jijio (the queue[4] mission talks) always wins: this node only touches prompts it set itself.

const Walkers := preload("res://scripts/walkers.gd")
const LevelDefs := preload("res://scripts/level_defs.gd")
const HideSeek := preload("res://scripts/hide_seek.gd")

const REACH := 1.5 ## m (DECIDED, Stage 6c D (C)); Bob's own 1.3 m stays for everything else
## One row per queue spot, front of the line first (population.QUEUE_SPOTS order). Claude's lines, the owner may reject any.
const LINES := [
	["I'm NEXT. Don't even think about it.", "I can hear the flush. It's so close. So beautiful.", "I've been at the front for an hour. The door never opens."],
	["Stop breathing on my neck. Oh, it's you. Still stop.", "I brought a book. I've finished the book.", "My tummy is making noises only whales understand."],
	["Do NOT make me laugh right now. It's dangerous.", "I counted the tiles. Four thousand and twelve.", "If I sneeze, we're all in trouble."],
	["This queue has a queue. I'm in the second queue.", "I'm doing my breathing. In... out... in... hold... HOLD...", "Whoever had the beans for lunch, I know it was you."],
	["Squeeze tight. That's my only advice.", "I'm fine. Totally fine. Why are my legs shaking? No reason.", "The Jijio in front of me hasn't moved since Tuesday."],
	["I dreamt about a toilet last night. It was free.", "Don't look at me. I'm concentrating very hard.", "Every time that door creaks, my heart does a little dance."],
	["I'm not squirming. This is my dance.", "Ten more minutes and I'm using the sink.", "My knees are crossed so tight they've merged."],
	["Is it me, or is this line going backwards?", "I've made friends with everyone in this queue. Except him. He knows what he did.", "I should have gone before I left the house."],
	["Back of the line, pal. Oh, you're already behind me. Good.", "At this rate I'll retire before I get in.", "Tell me a joke. No, wait. Don't. I can't laugh right now."],
]

var _level: Node3D
var _hint := ""
var _index := {} ## npc -> its queue spot at the start (the ghost leaving the queue does not shift anyone's lines)


func setup(level: Node3D) -> void:
	_level = level
	_hint = LevelDefs.get_level(level.level_number).get("walker_hint", "")
	var queue: Array = level.population.queue
	for i in queue.size():
		_index[queue[i]] = i
		queue[i].talk_reach = REACH


func _process(_delta: float) -> void:
	for npc: Node3D in _index:
		if not is_instance_valid(npc):
			continue
		var mine: bool = npc.interaction_owner() == self
		var ok := _allowed(npc)
		if ok and not mine and npc.interaction_owner() == null:
			npc.set_interaction("E  talk", _talk.bind(npc))
			npc.priority = Walkers.TALK_PRIORITY
		elif mine and not ok:
			npc.clear_interaction()
			npc.priority = 0.0
		elif not mine and npc.priority == Walkers.TALK_PRIORITY and npc.interaction_owner() != null:
			npc.priority = 0.0 # a mission took the prompt over: it keeps the normal priority


## Standing in the queue and no scene owns it.
func _allowed(npc: Node3D) -> bool:
	if not _level.population.queue.has(npc) or npc.state != npc.State.QUEUED or npc.floating or not npc.visible:
		return false
	if _level.intro_playing:
		return false
	if _level.hide_seek != null and _level.hide_seek.phase in [HideSeek.Phase.HIDING, HideSeek.Phase.SEEKING]:
		return false
	if _level.flood_story != null and _level.flood_story.is_started and not _level.flood_story.is_drained:
		return false
	if _level.cutters != null and _level.cutters.fight != null:
		return false
	if _level.dance != null and _level.dance.challenged:
		return false
	return true


func _talk(player: Node3D, npc: Node3D) -> void:
	if not _allowed(npc):
		return
	var d = _level.dialogue
	d.begin(npc, player)
	var lines: Array = LINES[_index[npc]]
	await d.say(npc, lines[randi() % lines.size()], true) # small talk: W/A/S/D or Esc leave it at once
	if _hint != "" and not d.cancelled:
		await d.say(npc, _hint, true)
	d.end(npc, player)
