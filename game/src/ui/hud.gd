class_name HUD
extends Control
## The interface over a local map: the bottom bar and the windows opened from
## it. The bar is a hammered iron plate under a bronze strip (art/ui.py):
## the message log in a recessed well, health, the action-point studs over
## the weapon slot, the shield boss that ends a turn, and the buttons.

const BAR_H := 162.0     # the opaque part of the bar; the texture adds 6 px of shadow above
const TEX_H := 168.0

var map: LocalMap        # set on a local map
var world: Node          # set on the world map (WorldMap); exactly one of the two
var _log: RichTextLabel
var _hp: Label
var _hp_max: Label
var _date: Label
var _studs: HBoxContainer
var _weapon_btn: Button
var _weapon_name: Label
var _weapon_info: Label
var _hover: Label
var _end_turn: TextureButton
var _end_turn_label: Label
var _end_combat: Button
var _sneak_btn: Button
var _modals: Array = []   # open windows, top last
var _stud_on: Texture2D = preload("res://assets/ui/stud_on.png")
var _stud_off: Texture2D = preload("res://assets/ui/stud_off.png")
var _boss_ready: Texture2D = preload("res://assets/ui/boss_ready.png")
var _boss_idle: Texture2D = preload("res://assets/ui/boss_idle.png")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	_build_bar()
	_hover = UITheme.label("", 14, UITheme.TEXT)
	_hover.position = Vector2(12, 8)
	_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover.add_theme_constant_override("outline_size", 4)
	add_child(_hover)
	Game.message.connect(_on_message)
	Game.stats_changed.connect(refresh)
	for m in Game.state.messages.slice(-8):
		_append(m, "info")
	refresh()


func _build_bar() -> void:
	var plate := NinePatchRect.new()
	plate.texture = preload("res://assets/ui/bar.png")
	plate.patch_margin_left = 48
	plate.patch_margin_right = 48
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_top = -TEX_H
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	# Swallow clicks on the opaque part only, not the shadow above it.
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	catcher.offset_top = -BAR_H
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(catcher)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hb.offset_top = -BAR_H + 30
	hb.offset_bottom = -10
	hb.offset_left = 32
	hb.offset_right = -32
	hb.add_theme_constant_override("separation", 12)
	add_child(hb)

	# The log, in a dark well.
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UITheme.tex_box("well", 12, 10))
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(well)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(440, 0)
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	well.add_child(_log)

	# Health, with the date under it.
	var hcol := VBoxContainer.new()
	hcol.custom_minimum_size.x = 112
	hcol.add_theme_constant_override("separation", 4)
	hb.add_child(hcol)
	var hwell := PanelContainer.new()
	hwell.add_theme_stylebox_override("panel", UITheme.tex_box("well", 12, 6))
	hwell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(hwell)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", -2)
	hwell.add_child(hv)
	hv.add_child(UITheme.caps("Health", 11))
	_hp = UITheme.title_label("", 30, UITheme.TEXT)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_hp)
	_hp_max = UITheme.label("", 12, UITheme.DIM)
	_hp_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(_hp_max)
	_date = UITheme.label("", 13, UITheme.DIM)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_date.add_theme_constant_override("shadow_offset_y", 1)
	hcol.add_child(_date)

	# Action studs over the weapon slot.
	var wcol := VBoxContainer.new()
	wcol.custom_minimum_size.x = 214
	wcol.add_theme_constant_override("separation", 5)
	hb.add_child(wcol)
	_studs = HBoxContainer.new()
	_studs.alignment = BoxContainer.ALIGNMENT_CENTER
	_studs.add_theme_constant_override("separation", 2)
	_studs.custom_minimum_size.y = 18
	_studs.tooltip_text = "Action points. Lit in a fight while they last."
	_studs.mouse_filter = Control.MOUSE_FILTER_STOP
	wcol.add_child(_studs)
	_weapon_btn = Button.new()
	_weapon_btn.focus_mode = Control.FOCUS_NONE
	_weapon_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_btn.tooltip_text = "Your weapon. Click to switch to another one you carry."
	_weapon_btn.add_theme_stylebox_override("normal", UITheme.tex_box("well", 12, 8))
	_weapon_btn.add_theme_stylebox_override("hover", UITheme.tex_box("well_hover", 12, 8))
	_weapon_btn.add_theme_stylebox_override("pressed", UITheme.tex_box("well_hover", 12, 8))
	_weapon_btn.pressed.connect(_cycle_weapon)
	wcol.add_child(_weapon_btn)
	var wv := VBoxContainer.new()
	wv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wv.add_theme_constant_override("separation", 2)
	_weapon_btn.add_child(wv)
	var wcap := UITheme.caps("Weapon", 11)
	wcap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wv.add_child(wcap)
	_weapon_name = UITheme.label("", 17, UITheme.TEXT)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wv.add_child(_weapon_name)
	_weapon_info = UITheme.label("", 13, UITheme.WARN)
	_weapon_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wv.add_child(_weapon_info)

	# The shield boss ends a turn; End fight under it.
	var bcol := VBoxContainer.new()
	bcol.custom_minimum_size.x = 92
	bcol.add_theme_constant_override("separation", 0)
	hb.add_child(bcol)
	_end_turn = TextureButton.new()
	_end_turn.texture_normal = _boss_idle
	_end_turn.texture_hover = preload("res://assets/ui/boss_hover.png")
	_end_turn.texture_pressed = preload("res://assets/ui/boss_pressed.png")
	_end_turn.texture_disabled = _boss_idle
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_turn.tooltip_text = "End your turn (Space)."
	if map:
		_end_turn.pressed.connect(func(): map.combat.player_end_turn())
	bcol.add_child(_end_turn)
	_end_turn_label = UITheme.caps("End turn", 10)
	_end_turn_label.position = Vector2(0, 36)
	_end_turn_label.size = Vector2(88, 16)
	_end_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_turn.add_child(_end_turn_label)
	_end_combat = _tb("End fight", "End the fight when no enemy is left in sight (Enter).", func():
		if map:
			map.combat.request_end())
	_end_combat.custom_minimum_size = Vector2(92, 26)
	bcol.add_child(_end_combat)
	# Turns and action points mean nothing on the road.
	bcol.visible = map != null
	_studs.visible = map != null

	# The buttons.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(grid)
	grid.add_child(_tb("Gear", "Your gear and what you carry (I).", open_inventory))
	grid.add_child(_tb("Self", "Your character (C).", open_character))
	grid.add_child(_tb("Journal", "Quests and notes (J).", open_journal))
	if map == null:
		grid.add_child(_tb("Rest", "Rest a while (R).", func(): world.rest()))
		grid.add_child(_tb("Menu", "Save, load, help, quit (Esc).", open_menu))
		return
	grid.add_child(_tb("Travel", "The map of Gaul (M).", func(): map.try_world_map()))
	_sneak_btn = _tb("Sneak", "Move quietly (S).", func(): map.toggle_sneak())
	grid.add_child(_sneak_btn)
	grid.add_child(_tb("Menu", "Save, load, help, quit (Esc).", open_menu))


func _tb(text: String, tip: String, cb: Callable) -> Button:
	var b := UITheme.button(text.to_upper(), cb, 96)
	b.custom_minimum_size.y = 32
	b.tooltip_text = tip
	b.add_theme_font_override("font", UITheme.caps_font())
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", UITheme.TEXT.darkened(0.08))
	b.add_theme_color_override("font_hover_color", UITheme.BRONZE)
	return b


func _on_message(text: String, kind: String) -> void:
	_append(text, kind)


func _append(text: String, kind: String) -> void:
	var col := UITheme.TEXT
	match kind:
		"good":
			col = UITheme.GOOD
		"bad":
			col = UITheme.BAD
		"story":
			col = Color("#e8c890")
		"warn":
			col = UITheme.WARN
		"hint":
			col = UITheme.BRONZE
	_log.append_text("[color=#%s]%s[/color]\n" % [col.to_html(false), text.replace("[", "[lb]")])


func refresh() -> void:
	if map == null and world == null:
		return
	if map and map.player == null:
		return
	var p := Game.state.player
	_hp.text = str(p.hp)
	_hp.add_theme_color_override("font_color", UITheme.TEXT if p.hp * 2 > p.max_hp() else UITheme.BAD)
	_hp_max.text = "of %d" % p.max_hp()
	var fighting := in_fight()
	var mine := fighting and map.combat.current == map.player
	var lit: int = map.player.ap if mine else 0
	var n := p.max_ap()
	while _studs.get_child_count() < n:
		var t := TextureRect.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_studs.add_child(t)
	for i in _studs.get_child_count():
		var t: TextureRect = _studs.get_child(i)
		t.visible = i < n
		t.texture = _stud_on if i < lit else _stud_off
	_date.text = Game.state.date_text()
	var w := p.weapon_def()
	var info := "%d AP" % int(w.get("ap", 3))
	if w.has("ammo"):
		info += "   %d %s" % [p.inventory.count(w["ammo"]), DB.item_name_lc(w["ammo"])]
	elif w.get("thrown", false):
		info += "   %d left" % (p.inventory.count(w["id"]) + 1)
	_weapon_name.text = w.get("name", "Fists")
	_weapon_info.text = info
	_end_turn.disabled = not mine
	_end_turn.texture_normal = _boss_ready if mine else _boss_idle
	_end_turn_label.add_theme_color_override("font_color", UITheme.BRONZE if mine else UITheme.DIM.darkened(0.3))
	_end_combat.disabled = not fighting
	if map:
		_sneak_btn.disabled = fighting
		var sneaking: bool = map.player.get_meta("sneaking", false)
		if sneaking:
			_sneak_btn.add_theme_stylebox_override("normal", UITheme.button_box("btn_on"))
			_sneak_btn.add_theme_color_override("font_color", UITheme.BRONZE)
		else:
			_sneak_btn.remove_theme_stylebox_override("normal")
			_sneak_btn.add_theme_color_override("font_color", UITheme.TEXT.darkened(0.08))


func in_fight() -> bool:
	return map != null and map.combat.active


func _set_modal_open(v: bool) -> void:
	if map:
		map.modal_open = v
		map.path_preview.clear()
	elif world:
		world.modal_open = v


func update_hover(c: Vector2i) -> void:
	var t := ""
	var a := map.actor_at(c, true)
	if a and not a.is_player:
		t = a.display_name()
		if a.dead:
			t += " (dead)"
		elif a.hostile:
			t += " (hostile)"
	elif map.container_at(c) != "":
		t = map.containers[map.container_at(c)]["def"].get("name", "")
	elif not map.exit_at(c).is_empty():
		t = map.exit_at(c).get("label", "Leave this place")
	_hover.text = t
	_hover.position = get_viewport().get_mouse_position() + Vector2(16, 12)


func _cycle_weapon() -> void:
	var p := Game.state.player
	var options: Array = [""]
	for id in p.inventory.ids():
		if DB.item(id).get("type", "") == "weapon":
			options.append(id)
	if options.size() <= 1 and p.equipped("weapon") == "":
		return
	if in_fight():
		if map.combat.current != map.player or map.player.ap < 1:
			return
		map.player.ap -= 1
	var cur := p.equipped("weapon")
	var idx := options.find(cur)
	var next: String = options[(idx + 1) % options.size()] if idx >= 0 else options[0]
	if next == "" or next == cur:
		p.unequip("weapon")
		if options.size() > 1 and cur == "":
			p.equip(options[1])
	else:
		p.equip(next)
	refresh()


# --- Windows --------------------------------------------------------------------

func push_modal(root: Control) -> void:
	_modals.append(root)
	_set_modal_open(true)
	_hover.text = ""


func close_modal(root: Control) -> void:
	_modals.erase(root)
	root.queue_free()
	_set_modal_open(not _modals.is_empty())
	refresh()


func close_top() -> bool:
	if _modals.is_empty():
		return false
	var top: Control = _modals[-1]
	if top.has_meta("no_escape"):
		return true
	if top.has_method("request_close"):
		top.request_close()
	else:
		close_modal(top)
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not close_top():
				open_menu()
			get_viewport().set_input_as_handled()
		elif not _modals.is_empty():
			var top: Control = _modals[-1]
			if top.has_method("on_key"):
				top.on_key(event)
				get_viewport().set_input_as_handled()


func open_dialogue(dlg_id: String, speaker: Actor) -> void:
	var w := DialoguePanel.new()
	w.hud = self
	w.speaker = speaker
	w.dlg_id = dlg_id
	add_child(w)
	push_modal(w)


func open_aim(target: Actor) -> void:
	var w := map.player.sheet.weapon_def()
	var r := UITheme.modal(self, "Aim at %s" % target.display_name(), Vector2(320, 0))
	var root: Control = r[0]
	var vb: VBoxContainer = r[1]
	for part in ["torso", "head", "eyes", "arms", "legs", "groin"]:
		var ch := map.combat.chance_for(map.player, target, w, part)
		var cost := CombatRules.attack_ap(w, part != "torso")
		var label := "%s   %d%%   %d AP" % [String(CombatRules.AIM_NAMES[part]).capitalize(), ch, cost]
		var b := UITheme.button(label, func():
			close_modal(root)
			map.combat.player_attack(target, part))
		b.disabled = map.combat.attack_blocker(map.player, target, w, part) != ""
		vb.add_child(b)
	vb.add_child(UITheme.button("Never mind", func(): close_modal(root)))
	push_modal(root)


func open_loot(title: String, cstate: Dictionary, body: Actor) -> void:
	var w := LootPanel.new()
	w.hud = self
	w.title = title
	w.cstate = cstate
	w.body = body
	add_child(w)
	push_modal(w)


func open_barter(trader: Actor) -> void:
	var w := BarterPanel.new()
	w.hud = self
	w.trader = trader
	add_child(w)
	push_modal(w)


func open_inventory() -> void:
	if _is_open(InventoryPanel):
		return
	var w := InventoryPanel.new()
	w.hud = self
	add_child(w)
	push_modal(w)


func open_character() -> void:
	if _is_open(CharacterPanel):
		return
	var w := CharacterPanel.new()
	w.sheet = Game.state.player
	w.on_close = func(): close_modal(w)
	add_child(w)
	push_modal(w)


func open_journal() -> void:
	if _is_open(JournalPanel):
		return
	var w := JournalPanel.new()
	w.on_close = func(): close_modal(w)
	add_child(w)
	push_modal(w)


func open_menu() -> void:
	var r := UITheme.modal(self, "Vae Victis", Vector2(300, 0))
	var root: Control = r[0]
	var vb: VBoxContainer = r[1]
	vb.add_child(UITheme.button("Resume", func(): close_modal(root)))
	var save_b := UITheme.button("Save (F5)", func():
		close_modal(root)
		if map:
			map.quick_save()
		else:
			world.quick_save())
	save_b.disabled = in_fight()
	vb.add_child(save_b)
	var load_b := UITheme.button("Load (F9)", func(): Game.goto("load", {"slot": "quick"}))
	load_b.disabled = not Game.has_save("quick")
	vb.add_child(load_b)
	vb.add_child(UITheme.button("Help", func():
		close_modal(root)
		open_help()))
	vb.add_child(UITheme.button("Quit to title", func(): Game.goto("title", {})))
	push_modal(root)


func open_help() -> void:
	var r := UITheme.modal(self, "How to play", Vector2(620, 0))
	var root: Control = r[0]
	var vb: VBoxContainer = r[1]
	var t := UITheme.label(DB.text_file("text/help.txt"), 14)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size.x = 580
	vb.add_child(t)
	vb.add_child(UITheme.button("Close", func(): close_modal(root)))
	push_modal(root)


func _is_open(cls) -> bool:
	for m in _modals:
		if is_instance_of(m, cls):
			return true
	return false
