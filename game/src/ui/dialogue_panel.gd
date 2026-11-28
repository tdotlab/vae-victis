class_name DialoguePanel
extends Control
## A conversation window: what the speaker says, and numbered replies.
## Walks a Dialogue script and hands actions (fight, trade, join...) back
## to the map.

var hud: HUD
var speaker: Actor
var dlg_id := ""
var _dlg: Dictionary
var _page: Dictionary
var _text: RichTextLabel
var _choices: VBoxContainer
var _pending_actions: Array = []
var _finished := false
const TEXT_MIN_H := 120.0
const TEXT_MAX_H := 330.0


## The speaker, full length at three times map size (the sprites are
## rendered at twice it), turned three-quarters toward the reader.
class _Portrait extends Control:
	var actor: Actor
	const W := 150.0
	const H := 230.0

	func _ready() -> void:
		custom_minimum_size = Vector2(W, H)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		clip_contents = true

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0e1012"))
		var foot := Vector2(W * 0.5 - 4.0, H - 16.0)
		for i in range(6):
			var k := 1.0 - i / 6.0
			draw_set_transform(foot, 0, Vector2(1, 0.32))
			draw_circle(Vector2.ZERO, 40.0 + i * 9.0, Color(0.16, 0.18, 0.2, 0.18 * k))
		draw_set_transform(foot, 0, Vector2(3, 3))
		Art.draw_figure(self, Vector2.ZERO, actor, 0.0, Color(0, 0, 0, 0), 5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.EDGE, false, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	set_meta("no_escape", true)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(panel)
	UITheme.keep_above_bar(center, panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	if speaker and Art.on():
		var por := _Portrait.new()
		por.actor = speaker
		row.add_child(por)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vb)
	_dlg = Dialogue.load_dialogue(dlg_id)
	var who: String = speaker.display_name() if speaker else _dlg.get("speaker", "")
	var title := UITheme.title_label(who, 22)
	vb.add_child(title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(760, TEXT_MIN_H)
	_text.scroll_following = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 16)
	vb.add_child(_text)
	var sep := HSeparator.new()
	vb.add_child(sep)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 3)
	vb.add_child(_choices)
	if speaker:
		hud.map.face(speaker, hud.map.player.cell)
	_show(Dialogue.enter(Game.state, _dlg, _dlg["entry"], _ctx()))


func _ctx() -> Dictionary:
	var c := {}
	if speaker:
		c["speaker_hurt"] = speaker.sheet.hp < speaker.sheet.max_hp()
	return c


func _show(page: Dictionary) -> void:
	_page = page
	for m in page["messages"]:
		Game.say(m[0], m[1])
	if int(page["xp"]) > 0:
		Game.give_xp(int(page["xp"]))
	if page.get("rolled", "") == "failure":
		Game.say("That didn't work.", "bad")
	_pending_actions.append_array(page["actions"])
	# Trading happens mid-conversation; everything else waits for the end.
	for a in page["actions"]:
		if a == "barter" and speaker:
			hud.open_barter(speaker)
	_text.text = ""
	_text.append_text(page["text"].replace("[", "[lb]"))
	_fit_text.call_deferred()
	for c in _choices.get_children():
		c.queue_free()
	if page["end"]:
		# A choice that leads straight to END has nothing left to read.
		if str(page["text"]).strip_edges() == "":
			_finish.call_deferred()
			return
		var b := _choice_button("1. [Done]", func(): _finish())
		_choices.add_child(b)
		return
	var n := 0
	for ch in page["choices"]:
		n += 1
		var label := "%d. %s%s" % [n, ch["label"], ch["text"]]
		if ch.has("chance"):
			label += "  (%d%%)" % ch["chance"]
		var idx: int = ch["index"]
		_choices.add_child(_choice_button(label, func(): _pick(idx)))


## Grows the text box to fit a long speech, up to a cap; past that it scrolls.
func _fit_text() -> void:
	_text.custom_minimum_size.y = clampf(_text.get_content_height() + 8, TEXT_MIN_H, TEXT_MAX_H)


func _choice_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.custom_minimum_size.x = 760
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("#e2c77a"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	return b


func _pick(op_index: int) -> void:
	_show(Dialogue.choose(Game.state, _dlg, _page["node"], op_index, _ctx()))


func on_key(event: InputEventKey) -> void:
	var k := event.keycode - KEY_1
	if k >= 0 and k < 9:
		if _page["end"]:
			_finish()
		elif k < _page["choices"].size():
			_pick(_page["choices"][k]["index"])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	hud.close_modal(self)
	var m := hud.map
	for a in _pending_actions:
		var parts: PackedStringArray = a.split(" ")
		match parts[0]:
			"fight":
				if speaker:
					speaker.hostile = true
					m.combat.provoke(speaker)
					m.combat.start_combat(speaker)
			"duel":
				var champ: Actor = m.find_actor(parts[1]) if parts.size() > 1 else speaker
				if champ and champ.is_active():
					m.save_map_state()
					hud.refresh()
					m.combat.start_duel(champ, parts[2] if parts.size() > 2 else "")
					return
			"join":
				if speaker and not Companions.has_room(Game.state, speaker.template):
					Game.say(Companions.text("full", "You can't lead more than %d people.") % Companions.cap(Game.state), "bad")
				elif speaker:
					speaker.is_companion = true
					speaker.ally = false
					speaker.hostile = false
					speaker.ai = "follow"
					speaker.faction = "player"
					Game.say("%s joins you." % speaker.display_name(), "good")
					m.save_map_state()
			"part":
				if speaker and speaker.is_companion:
					Game.say(Companions.text("stays", "%s stays here.") % speaker.display_name())
					m.part_companion(speaker)
			"ally":
				if speaker:
					speaker.ally = true
					speaker.hostile = false
			"ally_all":
				for a2 in m.actors:
					if a2.faction == parts[1] and not a2.dead and not a2.is_companion:
						a2.ally = true
						a2.hostile = false
				m.save_map_state()
			"leave":
				if speaker:
					speaker.fled = true
					speaker.ai = "idle"
					Game.say("%s leaves." % speaker.display_name())
					m.save_map_state()
			"travel":
				var dest := parts[1] if parts.size() > 1 else "world"
				var entry := parts[2] if parts.size() > 2 else "start"
				m.leave_to("world" if dest == "world" else "map:" + dest, entry)
				return
			"rest":
				var gs := Game.state
				var to_morning := ((24 + 7 - gs.hour()) % 24) * 60
				gs.advance(maxi(60, to_morning))
				gs.player.hp = gs.player.max_hp()
				Game.say("You sleep, and wake rested.", "good")
			"heal_all":
				Game.state.player.hp = Game.state.player.max_hp()
				Game.say("Your wounds are tended.", "good")
			"leave_all":
				for a2 in m.actors:
					if a2.faction == parts[1] and not a2.dead and not a2.is_companion:
						a2.fled = true
						a2.ai = "idle"
				m.save_map_state()
			"fight_all":
				var first: Actor = null
				for a2 in m.actors:
					if a2.faction == parts[1] and a2.is_active():
						a2.hostile = true
						if first == null:
							first = a2
				if first:
					m.combat.provoke(first)
					m.combat.start_combat(first)
			"ending":
				m.save_map_state()
				if parts[1].ends_with(".json"):
					var ed: Dictionary = DB.load_json(parts[1])
					Game.goto("text", {"pages": Endings.pages(Game.state, parts[1]), "next": "map",
						"button": ed.get("button", DB.story().get("ending_button", "Go on"))})
				else:
					Game.goto("text", {"title": DB.story().get("ending_title", ""), "text": DB.text_file(parts[1]), "next": "map", "button": DB.story().get("ending_button", "Go on")})
				return
	m.save_map_state()
	hud.refresh()
	m.check_quiet.call_deferred()
