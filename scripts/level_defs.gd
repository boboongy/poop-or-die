extends RefCounted
## The levels as data: name, timer, and the list of missions (all required; a mission can wait for
## others through its `requires`). To add a level, add an entry here and write its mission scripts.

const M := "res://scripts/missions/"

const LEVELS := {
	1: {
		"name": "Find the tissue",
		"time": 75.0,
		"intro": "cut_in", # intro.gd (Stage 6b D): Bob asks the Jijio ahead to let him go first; the clock waits for it
		"missions": [M + "ask_who_needs_tissue.gd", M + "find_tissue.gd", M + "deliver_tissue.gd"],
		"walker_hint": "Desperate too? The Jijio right in front of you in the queue knows who needs help. Have a word with them.",
	},
	2: {
		"name": "Hide and seek",
		"time": 90.0, # Level 2 since Stage 6b (owner, twice: swap Levels 2 and 3); owner 2026-09-25 (was 75): "make the timer longer, very hard to win"; counting 12 -> 20 s (hide_seek.gd)
		"intro": "ghost", # intro.gd: Bob tries to cut in, the Jijio ahead is a GHOST who starts the game; the clock waits for it
		"hide_seek": true, # see hide_seek.gd: one empty stall, every queue Jijio and walker seeks, the 20 stall occupants stay put
		"missions": [M + "hide_from_seekers.gd"],
		"walker_hint": "Shh! It's hide and seek. When the counting stops, everybody comes looking. Find somewhere to hide.",
	},
	3: {
		"name": "The flood",
		"time": 150.0, # Level 3 since Stage 6b (owner: swap Levels 2 and 3); SPEC Round 2 Stage 3 (owner 2026-09-25/27): the rising flood replaced the four puddles ("Wet floor", 120 s)
		"rising": true, # flood_water.gd + flood_story.gd: a clogged toilet and 4 taps fill the toilet to 1.6 m; plunge, taps off, plug, mop
		"intro": "flood", # intro.gd: Bob tries to cut in, everyone ignores him, the blast and the scream; the clock waits for it
		"missions": [M + "plunge_toilet.gd", M + "taps_off.gd", M + "pull_plug.gd", M + "flood_find_mop.gd", M + "mop_flood.gd"],
		"walker_hint": "The toilet's clogged and they've turned every tap on! Plunge it, shut the taps, then pull the plug in the waiting room floor.",
	},
	4: {
		"name": "Cutting the queue",
		"time": 150.0, # SPEC Stage 4 (was 90, before that 65): round 3 is now WATER WAR, the shooter; keeps running through the fights
		"cutters": true, # see cutters.gd: one stall opens at the start, three cutters block it, argue + fight each (the 3rd = WATER WAR)
		"intro": "cut_in", # intro.gd (Stage 6b D); the cutters arrive ARRIVE_AT s after GO
		"missions": [M + "beat_cutters.gd"],
		"walker_hint": "See those three pushing in? They think they own the place. Somebody should have a word with them.",
	},
	5: {
		"name": "Dance battle",
		"time": 75.0, # owner "yes to all" 2026-09-24 (J): searching for the dancer takes time; tune by playtest
		"dance": true, # see dance.gd: SHUFFLE QUEEN dances outside a random stall; the stall opens only when Bob wins the battle
		"intro": "cut_in", # intro.gd (Stage 6b D): a short opener before the finesse talk (owner B: that talk stays)
		"missions": [M + "finesse_queue.gd", M + "find_dancer.gd", M + "win_dance_battle.gd"],
		"walker_hint": "Nobody lets anyone cut in here. Unless you've got MOVES...",
	},
}


static func has_level(number: int) -> bool:
	return LEVELS.has(number)


static func get_level(number: int) -> Dictionary:
	return LEVELS[number]
