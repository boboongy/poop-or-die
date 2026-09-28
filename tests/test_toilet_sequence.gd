extends SceneTree
## From the reward stall (row 1 stall 5) to the win screen: the Jijio walks out and washes at the sink (baked
## `stand_up`/`wash` clips), Bob uses the toilet (FACTORY_TODO batch 2: pants_down, sit_down, sit, tissue_grab,
## wipe, press_flush, stand_up -- all baked clips now, `toilet_session.gd`). The timer must stop when Bob sits
## down; grabbing tissue and flushing are each their own E prompt (wiping itself is no longer hold-to-wipe:
## the clip's own 3.2 s timing carries it, see the owner's 2026-09-23 answer).
const T := preload("res://tests/t.gd")


func _init() -> void:
	seed(3)
	var lvl := T.level(self)
	await T.wait(self, 0.5)
	var p = lvl.get_node("Player")
	var pop: Node3D = lvl.get_node("Population")
	var sess = lvl.get_node("ToiletSession")
	var sinks = lvl.get_node("Sinks")
	var prompt: Label = lvl.get_node("HUD/PromptLabel")
	var status: Label = lvl.get_node("HUD/StatusLabel")
	sess.poop_seconds = 0.5
	var ap: AnimationPlayer = p.anim()

	var idx: int = pop.pick_free_stall()
	await pop.reward_release(idx)
	var npc = pop.occupants[idx]
	sess.setup(idx)
	T.check(lvl.stalls.doors[idx].is_open, "reward stall door is open")
	var ticks := 0
	while npc.state != 6 and ticks < 60 * 30: # 6 = WASH
		await T.wait(self, 0.1)
		ticks += 6
	var sink := idx % 10 + 1
	T.check(npc.state == 6, "the freed Jijio reached the sink and is washing (%.1f s)" % (ticks / 60.0))
	T.check(npc.anim().current_animation == "wash", "the freed Jijio plays the baked 'wash' clip")
	T.check(sinks._streams[sink - 1].visible, "tap water is running at sink %d" % sink)

	var f := Vector3(0, 0, 1) if idx < 10 else Vector3(0, 0, -1)
	p.global_position = sess._stand_spot() + f * 0.9
	p.face_direction(-f)
	await T.wait(self, 0.4)
	T.check(prompt.text == "E  use toilet", "use-toilet prompt ('%s')" % prompt.text)
	var running_before: bool = lvl._running
	await T.key(self, KEY_E)

	# --- pants_down -> sit_down -> sit (the timer stops here)
	var waited0 := 0.0
	while ap.current_animation != "pants_down" and waited0 < 3.0:
		await T.wait(self, 0.05)
		waited0 += 0.05
	T.check(ap.current_animation == "pants_down", "pants_down plays after the use-toilet prompt")
	T.check(p.busy and p.posing, "Bob is busy and the AnimationPlayer is his while the sequence runs")
	T.check(prompt.text == "", "no ambient interactable (e.g. the stall door behind Bob) can steal focus mid-clip ('%s')" % prompt.text)
	await T.wait_for(self, func() -> bool: return status.text.begins_with("Pooping"), 5.0)
	T.check(running_before and not lvl._running, "the timer stopped when Bob sat down")
	T.check(ap.current_animation == "sit", "sitting to poop plays 'sit' (got '%s')" % ap.current_animation)
	T.check(prompt.text == "", "still no ambient interactable while seated and pooping ('%s')" % prompt.text)

	# --- grab tissue prompt -> tissue_grab -> wipe (auto, no more hold-to-wipe)
	await T.wait_for(self, func() -> bool: return prompt.text == "E  grab tissue", 5.0)
	T.check(prompt.text == "E  grab tissue", "grab-tissue prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return ap.current_animation == "tissue_grab", 3.0)
	T.check(ap.current_animation == "tissue_grab", "tissue_grab plays after the grab-tissue prompt")
	await T.wait_for(self, func() -> bool: return ap.current_animation == "wipe", 5.0)
	T.check(status.text == "Wiping...", "wipe status text ('%s')" % status.text)

	# --- flush prompt -> press_flush -> the bowl-swirl cutscene -> win screen
	await T.wait_for(self, func() -> bool: return prompt.text == "E  flush", 5.0)
	T.check(prompt.text == "E  flush", "flush prompt ('%s')" % prompt.text)
	await T.key(self, KEY_E)
	await T.wait_for(self, func() -> bool: return ap.current_animation == "press_flush", 3.0)
	T.check(ap.current_animation == "press_flush", "press_flush plays after the flush prompt")

	var waited := 0.0
	while not lvl._result.visible and waited < 25.0:
		await T.wait(self, 0.2)
		waited += 0.2
	T.check(lvl._result.visible and lvl._result.text.begins_with("LEVEL %d COMPLETE" % lvl.level_number), "win screen after the flush ('%s')" % lvl._result.text.replace("\n", " | "))

	# --- stand_up plays afterward (a courtesy tail, does not gate the win) and Bob is handed back
	waited = 0.0
	while p.busy and waited < 5.0:
		await T.wait(self, 0.1)
		waited += 0.1
	T.check(not p.busy and not p.posing, "Bob is handed back after standing up")
	T.finish(self)
