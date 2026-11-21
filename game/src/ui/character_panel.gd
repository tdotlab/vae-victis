class_name CharacterPanel
extends Control
## The character sheet: attributes, derived numbers, skills (spend points
## here after leveling), traits, perks, honor and renown.

var sheet: CharacterSheet
var on_close: Callable
var _body: HBoxContainer
var _info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	var r := UITheme.modal(self, "", Vector2(1000, 0))
	var vb: VBoxContainer = r[1]
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	vb.add_child(_body)
	_info = UITheme.label("", 14, UITheme.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(960, 44)
	vb.add_child(_info)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UITheme.button("Close", func(): on_close.call(), 120))
	_refresh()


func _hint(c: Control, text: String) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_entered.connect(func(): _info.text = text)


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var s := sheet
	var gs := Game.state
	# Column 1: who you are.
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size.x = 260
	_body.add_child(c1)
	c1.add_child(UITheme.title_label(s.name, 24))
	c1.add_child(UITheme.label("Level %d   (%d / %d xp)" % [s.level, s.xp, CharacterSheet.xp_for_level(s.level + 1)], 14))
	c1.add_child(UITheme.label("Honor: %s" % Game.honor_word(), 14))
	c1.add_child(UITheme.label("Renown: %s" % Game.renown_word(), 14))
	c1.add_child(HSeparator.new())
	for a in DB.rules()["attributes"]:
		var l := UITheme.label("%-12s %2d" % [a["name"], s.attr(a["id"])], 16)
		_hint(l, "%s: %s" % [a["name"], a["desc"]])
		c1.add_child(l)
	c1.add_child(HSeparator.new())
	var av := s.armor_values()
	for pair in [["Health", "%d / %d" % [s.hp, s.max_hp()]], ["Action points", str(s.max_ap())],
			["Defense", str(s.derived("defense") + int(av["defense"]))], ["Armor", "%d / %d%%" % [av["dt"], av["dr"]]],
			["Melee bonus", "+%d" % s.derived("melee_bonus")], ["Sequence", str(s.derived("sequence"))],
			["Critical", "%d%%" % s.derived("crit")], ["Carry", "%s / %d" % [str(snappedf(s.carry_weight(), 0.1)), s.derived("carry")]]]:
		c1.add_child(UITheme.label("%-14s %s" % pair, 14, UITheme.TEXT))
	# Column 2: skills.
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size.x = 380
	_body.add_child(c2)
	var head := "Skills"
	if s.unspent_skill_points > 0:
		head += "   (%d points to spend)" % s.unspent_skill_points
	c2.add_child(UITheme.label(head, 16, UITheme.BRONZE))
	for sk in DB.skill_defs():
		var row := HBoxContainer.new()
		var tagged := s.is_tagged(sk["id"])
		var l := UITheme.label("%s%s" % [sk["name"], " *" if tagged else ""], 14, UITheme.WARN if tagged else UITheme.TEXT)
		l.custom_minimum_size.x = 200
		_hint(l, "%s: %s%s" % [sk["name"], sk["desc"], "  Tagged: raises twice as fast." if tagged else ""])
		row.add_child(l)
		var v := UITheme.label("%d%%" % s.skill(sk["id"]), 14)
		v.custom_minimum_size.x = 60
		row.add_child(v)
		if s.unspent_skill_points > 0:
			var id: String = sk["id"]
			var b := UITheme.button("+", func():
				s.raise_skill(id)
				_refresh())
			b.disabled = not s.can_raise_skill(id)
			b.custom_minimum_size = Vector2(28, 22)
			row.add_child(b)
		c2.add_child(row)
	# Column 3: traits and perks.
	var c3 := VBoxContainer.new()
	c3.custom_minimum_size.x = 300
	_body.add_child(c3)
	c3.add_child(UITheme.label("Traits", 16, UITheme.BRONZE))
	for t in s.traits:
		var d := DB.trait_def(t)
		var l := UITheme.label(d.get("name", t), 14)
		_hint(l, d.get("desc", ""))
		c3.add_child(l)
	if s.traits.is_empty():
		c3.add_child(UITheme.label("(none)", 14, UITheme.DIM))
	c3.add_child(UITheme.label("Perks", 16, UITheme.BRONZE))
	for p in s.perks:
		var d := DB.perk_def(p)
		var l := UITheme.label(d.get("name", p), 14)
		_hint(l, d.get("desc", ""))
		c3.add_child(l)
	if s.perks.is_empty():
		c3.add_child(UITheme.label("(none)", 14, UITheme.DIM))
	if s.perks_owed > 0:
		c3.add_child(UITheme.label("Choose a perk:", 15, UITheme.GOOD))
		for p in s.available_perks():
			var id: String = p["id"]
			var b := UITheme.button(p["name"], func():
				s.take_perk(id)
				Game.stats_changed.emit()
				_refresh())
			b.tooltip_text = p["desc"]
			b.mouse_entered.connect(func(): _info.text = "%s: %s" % [p["name"], p["desc"]])
			c3.add_child(b)
	if not gs.titles.is_empty():
		c3.add_child(UITheme.label("Known as", 16, UITheme.BRONZE))
		for t in gs.titles:
			c3.add_child(UITheme.label(t, 14))
	if not gs.companions.is_empty():
		c3.add_child(UITheme.label(Companions.text("heading", "With you (%d of %d)") % [Companions.count(gs), Companions.cap(gs)], 16, UITheme.BRONZE))
		for cd in gs.companions:
			var who: String = cd.get("sheet", {}).get("name", cd.get("uid", ""))
			var l := UITheme.label("%s %s" % [who, Companions.opinion_word(gs, cd.get("uid", ""))], 14)
			_hint(l, Companions.text("hint", "Presence decides how many will follow you. What you do decides whether they stay."))
			c3.add_child(l)
