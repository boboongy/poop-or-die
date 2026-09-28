extends Node
## NPC talk. Two kinds:
##  - bubble(): a floating text bubble over an NPC (shows through walls), fades by itself.
##  - say() / choose(): a conversation box at the bottom of the screen. Bob is frozen while it is open.
##    Advance with E / Space, answer with the number keys. Wrong answers just repeat (retry only, no time cost).

const Sfx := preload("res://scripts/sfx.gd")
const Pose := preload("res://scripts/pose.gd")

signal _answered(index: int)

const BUBBLE_HEIGHT := 2.05
## A bubble stays at least this long, whatever the caller asks (owner 2026-09-25: "could not fully digest the dialogue since too fast";
## Level 5's lines were up for 1.2-1.6 s). Reading time = READ_BASE + READ_PER_WORD per word.
const READ_BASE := 1.2
const READ_PER_WORD := 0.3
const LEAVE_KEYS: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE] ## leave a walker's small talk

## Spoken voices (SPEC "Round 2" Stage 2): every line has a file audio/voices/<cast>/<first 10 hex of the text's md5>.ogg, made offline
## by tools/make_voices.py with Piper TTS (the same cast map is in that tool). A line without a file prints VOICE MISSING (run.sh
## fails that test): after changing or adding a line, run `python tools/make_voices.py`.
const VOICE_DIR := "res://audio/voices/"
const CAST_OF_WHO := {"Bob": "bob", "GHOST": "ghost", "SHUFFLE QUEEN": "queen", "PUSHY": "pushy", "SNEAKY": "sneaky", "BOSSY": "bossy"}
const JIJIO_CASTS := ["jijio_a", "jijio_b", "jijio_c"] ## any other speaker: a generic Jijio, one voice per NPC
## Voice files are at -16 LUFS (shouts -13). Recorded mix (probe_soundscape): bubbles at +2 then -3 dB still clipped on the battle beat
## and the Level 3 fart (crowd shouts pile up, three at once); -6 keeps them under.
const VOICE_DB := -3.0
const BUBBLE_VOICE_DB := -6.0 ## 3D: fades with distance
const BUBBLE_VOICE_RANGE := 22.0
const BUBBLE_VOICES_MAX := 2 ## the dance crowd shouts four at once; 3 voices on the battle beat clipped the mix (probe_level5_sound)
static var spoken: Array[String] = [] ## "cast|text", newest last (tests)
static var missing: Array[String] = []
var bubble_voice_db := BUBBLE_VOICE_DB ## Level 5's battle lowers it (dance.gd beat_as_music): without the shouts the battle mix peaks at -3 dB
var voice_playing := "" ## the talk box's voice file while it speaks, "" when quiet (tests; the dummy audio driver has no playback state)
var _voice: AudioStreamPlayer
var _voice_line := 0 ## counts lines, so a voice waiting for Bob's reply knows it was skipped
var _bob_until := 0.0 ## game time (s) when Bob's spoken reply ends: the NPC's next line waits for it
var _clock := 0.0
var _bubble_voices := 0
var _skipped := false ## force_close() is answering: Bob says nothing

var _layer: CanvasLayer
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _choices: Label
var _waiting := false
var _choice_count := 0
var _skippable := false ## the line showing can be left with W, A, S, D or Esc (small talk only, never a question)
var cancelled := false ## the last conversation was left with a movement key or Esc: the speaker skips the rest


func _ready() -> void:
	_build_ui()
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = VOICE_DB
	add_child(_voice)


func _physics_process(delta: float) -> void:
	_clock += delta


## The voice cast of a speaker: named characters by the name shown, a generic Jijio by its node (so it keeps one voice).
static func cast_for(npc: Node, who: String) -> String:
	if CAST_OF_WHO.has(who):
		return CAST_OF_WHO[who]
	if npc == null:
		return JIJIO_CASTS[0]
	return JIJIO_CASTS[absi(String(npc.name).hash()) % JIJIO_CASTS.size()]


static func voice_path(cast: String, text: String) -> String:
	return VOICE_DIR + cast + "/" + text.md5_text().substr(0, 10) + ".ogg"


## The voice of a line, or null (and a VOICE MISSING line in the log) when it was never made.
static func voice_stream(cast: String, text: String) -> AudioStream:
	spoken.append(cast + "|" + text)
	if spoken.size() > 400:
		spoken = spoken.slice(200)
	var path := voice_path(cast, text)
	if not ResourceLoader.exists(path):
		var id := cast + " | " + text
		if not missing.has(id):
			missing.append(id)
			print("VOICE MISSING: ", id, "  (run: python tools/make_voices.py)")
		return null
	return load(path)


## The talk box's voice for the line just shown. After Bob's spoken reply it waits until he has finished; a line closed meanwhile never speaks.
func _speak(npc: Node, who: String, text: String) -> void:
	var stream := voice_stream(cast_for(npc, who), text)
	_voice_line += 1
	var line := _voice_line
	if _clock < _bob_until:
		await get_tree().create_timer(_bob_until - _clock, false, true).timeout
		if line != _voice_line:
			return
	_play_voice(stream)


func _play_voice(stream: AudioStream) -> void:
	_voice.stop()
	voice_playing = ""
	if stream == null:
		return
	_voice.stream = stream
	_voice.play()
	voice_playing = stream.resource_path
	var line := _voice_line
	await get_tree().create_timer(stream.get_length(), false, true).timeout
	if line == _voice_line and voice_playing == stream.resource_path:
		voice_playing = ""


func _stop_voice() -> void:
	_voice_line += 1
	_bob_until = 0.0
	_voice.stop()
	voice_playing = ""


## A floating bubble above `npc`. Visible through walls so a stall occupant can call out from inside. `who` picks the voice (named characters).
func bubble(npc: Node3D, text: String, seconds := 3.5, height := BUBBLE_HEIGHT, who := "Jijio") -> void:
	var voice_len := _bubble_voice(npc, who, text)
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.004
	label.font_size = 40
	label.outline_size = 14
	label.outline_modulate = Color(0.0, 0.08, 0.0, 1.0)
	label.modulate = Color(1.0, 1.0, 0.85, 1.0)
	label.width = 620.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0.0, height, 0.0)
	npc.add_child(label)
	var tween := create_tween()
	tween.tween_interval(maxf(maxf(seconds, READ_BASE + READ_PER_WORD * text.split(" ", false).size()), voice_len + 0.2))
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


## A line spoken from `npc` with no bubble (Bob's "SUPER SOAKER!" in first person, where a bubble over him is out of sight).
func shout_voice(npc: Node3D, text: String, who := "Jijio") -> void:
	_bubble_voice(npc, who, text)


## A bubble's voice comes from the NPC (3D). Returns its length (0 when none plays).
func _bubble_voice(npc: Node3D, who: String, text: String) -> float:
	var stream := voice_stream(cast_for(npc, who), text)
	if stream == null or _bubble_voices >= BUBBLE_VOICES_MAX:
		return 0.0
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = BUBBLE_VOICE_DB if CAST_OF_WHO.has(who) else bubble_voice_db # a named character is never pushed under the music
	player.max_distance = BUBBLE_VOICE_RANGE
	player.unit_size = 5.0
	player.max_db = Sfx.MAX_3D_DB
	player.position = Vector3(0.0, 0.8, 0.0)
	npc.add_child(player)
	player.play()
	_bubble_voices += 1
	var length := stream.get_length()
	get_tree().create_timer(length + 0.2).timeout.connect(_bubble_voice_done.bind(player))
	return length


## `player` untyped: the NPC (and its player) may be gone already (skill 7: freed objects and timer callbacks).
func _bubble_voice_done(player) -> void:
	_bubble_voices = maxi(_bubble_voices - 1, 0)
	if is_instance_valid(player):
		player.queue_free()


## Start a conversation: freezes Bob, turns both toward each other. Stage 6b E (owner): both play the `talk` clip (the body turns
## Pose.TALK_TURN right of the partner, the clip turns the head back) and the camera pans into Bob's first person on the Jijio's face.
func begin(npc: Node3D, player: Node3D) -> void:
	cancelled = false
	Sfx.play_ui(self, "ui_open")
	player.busy = true
	if player.has_method("start_talk_view"):
		player.start_talk_view(npc)
	else:
		player.turn_toward(npc.global_position)
	if "talking" in npc:
		npc.talking = true
		npc.set_meta("yaw_before_talk", npc.get_yaw())
		if npc.state != npc.State.SIT: # a seated occupant keeps sitting straight
			npc.face_yaw(Pose.talk_yaw(npc.global_position, player.global_position))


func end(npc: Node3D, player: Node3D) -> void:
	Sfx.play_ui(self, "ui_close")
	_panel.visible = false
	_waiting = false
	if "talking" in npc:
		npc.talking = false
		if npc.has_meta("yaw_before_talk"):
			npc.face_yaw(npc.get_meta("yaw_before_talk"))
	if player.has_method("end_talk_view"):
		player.end_talk_view()
	player.busy = false


## One line of speech; waits for E / Space. With `skippable` (a walker's small talk) W, A, S, D or Esc also leave the conversation at
## once (owner, 2026-09-21: the frozen talk box felt like being blocked): `cancelled` is then true and the caller says nothing more.
func say(_npc: Node3D, text: String, skippable := false, who := "Jijio") -> void:
	_skippable = skippable
	_show(who, text, [])
	_speak(_npc, who, text)
	await _answered
	_skippable = false


## A question with numbered replies. Returns the chosen index (0-based). Bob then SAYS the reply (owner 2026-09-27); the next line's
## text shows at once but its voice waits for him (no extra key press).
func choose(_npc: Node3D, text: String, replies: Array, who := "Jijio") -> int:
	_show(who, text, replies)
	_speak(_npc, who, text)
	var index: int = await _answered
	if not _skipped and index < replies.size():
		var stream := voice_stream("bob", str(replies[index]))
		_play_voice(stream)
		if stream != null:
			_bob_until = _clock + stream.get_length()
	return index


## Hide the talk box between lines of a cutscene (Bob walks), without ending a conversation.
## The talk box is showing (Bob's groans wait: ambience.gd).
func is_open() -> bool:
	return _panel != null and _panel.visible


func hide_box() -> void:
	_panel.visible = false


## Skip (a level intro's Enter): the line or question showing returns at once (a question with reply 0); the caller checks its own flag.
func force_close() -> void:
	_stop_voice()
	if _waiting:
		_waiting = false
		_skipped = true
		_answered.emit(0)
		_skipped = false


func _show(who: String, text: String, replies: Array) -> void:
	_speaker.text = who
	_text.text = text
	_choice_count = replies.size()
	if replies.is_empty():
		_choices.text = "[E] continue"
	else:
		var lines: Array[String] = []
		for i in replies.size():
			lines.append("[%d]  %s" % [i + 1, replies[i]])
		_choices.text = "\n".join(lines)
	_panel.visible = true
	_waiting = true


func _input(event: InputEvent) -> void:
	if not _waiting or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := -1
	if _choice_count == 0:
		if event.keycode in [KEY_E, KEY_SPACE]: # not Enter: it skips a level's intro (intro.gd)
			index = 0
		elif _skippable and (event.keycode in LEAVE_KEYS or event.physical_keycode in LEAVE_KEYS):
			cancelled = true
			index = 0
	elif event.keycode >= KEY_1 and event.keycode < KEY_1 + _choice_count:
		index = event.keycode - KEY_1
	if index >= 0:
		get_viewport().set_input_as_handled()
		Sfx.play_ui(self, "ui_choose")
		_stop_voice()
		_waiting = false
		_answered.emit(index)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -430.0
	_panel.offset_right = 430.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = -60.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.06, 0.02, 0.86)
	style.border_color = Color(0.45, 1.0, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	box.add_child(_speaker)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 26)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(800, 0)
	box.add_child(_text)
	_choices = Label.new()
	_choices.add_theme_font_size_override("font_size", 24)
	_choices.add_theme_color_override("font_color", Color(1.0, 1.0, 0.75))
	box.add_child(_choices)
