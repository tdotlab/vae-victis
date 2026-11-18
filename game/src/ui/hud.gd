class_name HUD
extends Control
## The interface over a local map: the bottom bar (message log, health,
## action points, weapon, buttons) and the windows opened from it.

var map: LocalMap
var _log: RichTextLabel
var _hp: Label
var _ap: Label
var _date: Label
var _weapon_btn: Button
var _hover: Label
var _end_turn: Button
var _end_combat: Button
var _sneak_btn: Button
var _modals: Array = []   # open windows, top last


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
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -152
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	bar.add_child(hb)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(520, 130)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 14)
	var log_bg := StyleBoxFlat.new()
	log_bg.bg_color = Color("#140f0a")
	log_bg.set_content_margin_all(6)
	_log.add_theme_stylebox_override("normal", log_bg)
	hb.add_child(_log)
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 170
	hb.add_child(stats)
	_hp = UITheme.label("", 18, UITheme.GOOD)
	stats.add_child(_hp)
	_ap = UITheme.label("", 16, UITheme.WARN)
	stats.add_child(_ap)
	_date = UITheme.label("", 13, UITheme.DIM)
	_date.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats.add_child(_date)
	_weapon_btn = UITheme.button("", _cycle_weapon, 170)
	_weapon_btn.custom_minimum_size.y = 34
	_weapon_btn.tooltip_text = "Your weapon. Click to switch to another one you carry."
	stats.add_child(_weapon_btn)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	hb.add_child(grid)
	grid.add_child(_tb("Gear (I)", open_inventory))
	grid.add_child(_tb("Self (C)", open_character))
	grid.add_child(_tb("Journal (J)", open_journal))
	grid.add_child(_tb("Travel (M)", func(): map.try_world_map()))
	_sneak_btn = _tb("Sneak (S)", func(): map.toggle_sneak())
	grid.add_child(_sneak_btn)
	grid.add_child(_tb("Menu (Esc)", open_menu))
	_end_turn = _tb("End turn (Space)", func(): map.combat.player_end_turn())
	grid.add_child(_end_turn)
	_end_combat = _tb("End fight (Enter)", func(): map.combat.request_end())
	grid.add_child(_end_combat)


func _tb(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb, 140)
	b.custom_minimum_size.y = 28
	b.add_theme_font_size_override("font_size", 13)
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
	_log.append_text("[color=#%s]%s[/color]\n" % [col.to_html(false), text.replace("[", "[lb]")])


func refresh() -> void:
	if map == null or map.player == null:
		return
	var p := map.player.sheet
	_hp.text = "Health %d / %d" % [p.hp, p.max_hp()]
	_hp.add_theme_color_override("font_color", UITheme.GOOD if p.hp * 2 > p.max_hp() else UITheme.BAD)
	var in_fight := map.combat.active
	if in_fight:
		var a := map.player.ap if map.combat.current == map.player else 0
		_ap.text = "Action %s" % ("●".repeat(a) + "○".repeat(maxi(0, p.max_ap() - a)))
	else:
		_ap.text = "Sneaking" if map.player.get_meta("sneaking", false) else ""
	_date.text = Game.state.date_text()
	var w := p.weapon_def()
	var ammo := ""
	if w.has("ammo"):
		ammo = " (%d)" % p.inventory.count(w["ammo"])
	elif w.get("thrown", false):
		ammo = " (%d)" % (p.inventory.count(w["id"]) + 1)
	_weapon_btn.text = "%s%s  %d AP" % [w.get("name", "Fists"), ammo, int(w.get("ap", 3))]
	_end_turn.disabled = not in_fight
	_end_combat.disabled = not in_fight
	_sneak_btn.disabled = in_fight


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
	var p := map.player.sheet
	var options: Array = [""]
	for id in p.inventory.ids():
		if DB.item(id).get("type", "") == "weapon":
			options.append(id)
	if options.size() <= 1 and p.equipped("weapon") == "":
		return
	if map.combat.active:
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
	map.modal_open = true
	map.path_preview.clear()
	_hover.text = ""


func close_modal(root: Control) -> void:
	_modals.erase(root)
	root.queue_free()
	map.modal_open = not _modals.is_empty()
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
	w.sheet = map.player.sheet
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
		map.quick_save())
	save_b.disabled = map.combat.active
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
