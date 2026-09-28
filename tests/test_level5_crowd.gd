extends SceneTree
## Level 5 step 3 (SPEC "Level 5", owner "1" 2026-09-24): after SHUFFLE QUEEN's challenge ALL the Jijios (queue + walkers) rush toward
## Bob and her, shouting; then a fade and everyone stands in a ring in the WAITING ROOM (the only open floor), Bob and her in the middle,
## the crowd grooving / pumping fists / hopping, seen from the battle camera in the doorway. Walkers ON (they join the crowd). One stall
## in each row. Written before the crowd code existed.
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Dance := preload("res://scripts/dance.gd")

const ROOM_X := Vector2(-5.15, -0.3) ## measured walls (tests/probe_level5_space.gd)
const ROOM_Z := Vector2(-2.0, 2.0)


func _init() -> void:
	seed(11)
	Progress.level = 5
	for stall in [6, 13]:
		Dance.force_stall = stall
		var lvl := T.level(self, true)
		await T.wait(self, 0.8)
		lvl._time_left = 100000.0
		await _to_challenge(lvl)
		await _check_circle(lvl, stall)
		lvl.queue_free()
		await process_frame
		await physics_frame
	Dance.force_stall = -1
	T.finish(self)


## The finesse talk, then walk up to her and take her challenge (the real talk path, as in test_level5_setup).
func _to_challenge(lvl: Node) -> void:
	var p: CharacterBody3D = lvl.player
	var d: Node = lvl.dance
	lvl.population.queue[4].interact(p)
	await T.wait(self, 0.2)
	for k in [KEY_1, KEY_E, KEY_E]:
		await T.key(self, k)
		await T.wait(self, 0.1)
	var at: Vector3 = d.queen.global_position + d.out * 0.9
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.face_direction(-d.out)
	await T.wait(self, 0.2)
	d.queen.interact(p)
	await T.wait(self, 0.2)
	await T.key(self, KEY_3)
	await T.wait(self, 0.1)
	await T.key(self, KEY_E)


func _check_circle(lvl: Node, stall: int) -> void:
	var d: Node = lvl.dance
	var p: CharacterBody3D = lvl.player
	var row := "stall %d row %d" % [stall % 10 + 1, 1 if stall < 10 else 2]
	var expected: int = lvl.population.queue.size() + lvl.population.walkers.size()
	# the rush: they come at Bob and shout before the fade
	var rushing := 0
	var shouts_before: int = d.shouts
	await T.wait(self, 1.0)
	for npc: Node3D in d.crowd:
		if npc.is_walking():
			rushing += 1
	T.check(d.crowd.size() == expected and expected >= 11, "%s: the crowd is every queue Jijio + every walker (%d of %d)" % [row, d.crowd.size(), expected])
	T.check(rushing >= expected - 2, "%s: they rush toward Bob and her (%d of %d moving 1 s after the challenge)" % [row, rushing, expected])
	T.check(p.busy, "%s: Bob stays put during the rush" % row)
	await T.wait_for(self, func() -> bool: return d.circle_ready, 6.0)
	T.check(d.circle_ready, "%s: the circle stands within 6 s of the challenge" % row)
	T.check(d.shouts - shouts_before >= 3, "%s: the crowd shouted %d times" % [row, d.shouts - shouts_before])
	await T.wait(self, 0.3)
	var c: Vector3 = Dance.ROOM_CENTER
	var bad := 0
	var closest := INF
	var styles := {}
	for i in d.crowd.size():
		var a: Node3D = d.crowd[i]
		var pos := a.global_position
		var inside := pos.x > ROOM_X.x + 0.25 and pos.x < ROOM_X.y - 0.25 and pos.z > ROOM_Z.x + 0.25 and pos.z < ROOM_Z.y - 0.25
		var to_c := Vector2(c.x - pos.x, c.z - pos.z)
		var facing := absf(angle_difference(a.get_yaw(), atan2(to_c.x, to_c.y))) < 0.6
		var clear := pos.distance_to(p.global_position) > 0.9 and pos.distance_to(d.queen.global_position) > 0.9
		var anim_ok: bool = a.anim().is_playing() and String(a.anim().current_animation).begins_with("dance/")
		if not (inside and facing and clear and anim_ok and a.state == a.State.DANCE):
			bad += 1
			print("  %s: crowd %d at %s inside %s facing %s clear %s anim '%s' state %d" % [row, i, pos, inside, facing, clear, a.anim().current_animation, a.state])
		styles[d.style_of(a)] = true
		for j in range(i + 1, d.crowd.size()):
			closest = minf(closest, pos.distance_to(d.crowd[j].global_position))
	T.check(bad == 0, "%s: all %d in the room, facing the middle, 0.9 m clear of the dancers, dancing (%d wrong)" % [row, d.crowd.size(), bad])
	T.check(closest >= 0.45, "%s: nobody stands inside anybody (closest pair %.2f m)" % [row, closest])
	T.check(styles.size() >= 2, "%s: the crowd moves in %d different ways" % [row, styles.size()])
	var bob_ok: bool = p.global_position.distance_to(Dance.BOB_SPOT) < 0.1 and p.posing
	var q_ok: bool = d.queen.global_position.distance_to(Dance.QUEEN_SPOT) < 0.1 and d.queen.anim().current_animation == "dance/groove"
	T.check(bob_ok and q_ok, "%s: Bob and SHUFFLE QUEEN stand in the middle (Bob %s, her %s)" % [row, p.global_position, d.queen.global_position])
	var cam: Camera3D = get_root().get_camera_3d()
	T.check(cam == d.camera, "%s: the battle camera is on" % row)
	# nothing between the camera and either dancer's chest: every body layer counts (the crowd is on layers 1 and 2)
	var space: PhysicsDirectSpaceState3D = lvl.get_world_3d().direct_space_state
	for target: Node3D in [p, d.queen]:
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, target.global_position + Vector3.UP * 0.8, 0xFFFFFFFF)
		var hit := space.intersect_ray(q)
		var blocker: String = "nothing" if hit.is_empty() else String(hit["collider"].name)
		T.check(hit.is_empty() or hit["collider"] == target, "%s: the camera sees %s's chest (first hit: %s)" % [row, target.name, blocker])
	T.check(d.beat_player.playing and d.boombox.global_position.distance_to(c) < 2.2, "%s: the boombox came along and still plays" % row)
	var mission_label: Label = lvl.get_node("HUD/MissionLabel")
	var timer_label: Label = lvl.get_node("HUD/TimerLabel")
	T.check(not mission_label.visible and timer_label.visible, "%s: the checklist hides, the timer stays on screen" % row)
	await _check_disco(lvl, row)


## Step 4: disco lights. The room's own lights and the exposure drop, coloured spots sweep, two white spots are on the dancers,
## "DANCE BATTLE!" shows; abort() (the level timeout) puts every light, the exposure, the camera and Bob back.
func _check_disco(lvl: Node, row: String) -> void:
	var d: Node = lvl.dance
	var p: CharacterBody3D = lvl.player
	var env: Environment = lvl.get_node("WorldEnvironment").environment
	T.check(env.tonemap_exposure < 0.7, "%s: the exposure drops for the disco (%.2f)" % [row, env.tonemap_exposure])
	var dim_bad := 0
	var room := 0
	for node in lvl.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		if d.is_disco_light(l):
			continue
		room += 1
		if l.light_energy > d.room_energy(l) * 0.31:
			dim_bad += 1
	T.check(room >= 10 and dim_bad == 0, "%s: all %d room lights dimmed to 30%% or less (%d not)" % [row, room, dim_bad])
	var colours: Array = d.disco_spots
	var dirs: Array = []
	for s: SpotLight3D in colours:
		dirs.append(-s.global_basis.z)
	await T.wait(self, 1.0)
	var moved := 0
	for k in colours.size():
		var s: SpotLight3D = colours[k]
		if s.light_energy > 1.0 and (dirs[k] as Vector3).angle_to(-s.global_basis.z) > 0.1:
			moved += 1
	T.check(colours.size() >= 4 and moved == colours.size(), "%s: %d coloured spots, %d of them sweeping" % [row, colours.size(), moved])
	var aimed := 0
	for pair: Array in [[d.bob_spot_light, p], [d.queen_spot_light, d.queen]]:
		var s: SpotLight3D = pair[0]
		var chest: Vector3 = (pair[1] as Node3D).global_position + Vector3.UP * 0.8
		var axis := -s.global_basis.z
		var to := chest - s.global_position
		var off := (to - axis * to.dot(axis)).length() # how far the beam's centre line passes from the chest
		if s.light_color.s < 0.15 and s.light_energy > 1.0 and off < 0.3:
			aimed += 1
	T.check(aimed == 2, "%s: two white spots on the dancers (%d)" % [row, aimed])
	T.check(d.hud != null and d.hud.announced.contains("DANCE BATTLE"), "%s: 'DANCE BATTLE!' on screen" % row)
	# owner 2026-09-25 "during the battle I didn't hear anything": the beat is battle MUSIC now (no distance fall-off or muffling;
	# the windowed recording in tests/probe_level5_sound.gd measures the loudness, headless has no audio)
	var bp: AudioStreamPlayer3D = d.beat_player
	T.check(bp.playing and bp.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED and bp.attenuation_filter_db == 0.0 and bp.volume_db == Dance.BATTLE_BEAT_DB,
			"%s: during the battle the beat plays as music (model %d, filter %.0f dB, %.0f dB)" % [row, bp.attenuation_model, bp.attenuation_filter_db, bp.volume_db])
	# the level timeout path
	var before_exp: float = d.room_exposure()
	d.abort()
	await T.wait(self, 0.6)
	var restored := 0
	for node in lvl.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		if not d.is_disco_light(l) and absf(l.light_energy - d.room_energy(l)) < 0.01:
			restored += 1
	var lit_disco := 0
	for s: SpotLight3D in colours + [d.bob_spot_light, d.queen_spot_light]:
		if is_instance_valid(s) and s.visible and s.light_energy > 0.01:
			lit_disco += 1
	T.check(restored == room and lit_disco == 0 and absf(env.tonemap_exposure - before_exp) < 0.01,
			"%s: abort() restores all %d room lights (%d) and the exposure, disco off (%d still lit)" % [row, room, restored, lit_disco])
	T.check(not p.posing and not p.busy and get_root().get_camera_3d() != d.camera, "%s: abort() frees Bob and gives his camera back" % row)
	T.check(bp.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and bp.attenuation_filter_db == Dance.BEAT_FILTER_DB,
			"%s: after the battle the beat is her 3D boombox again" % row)
