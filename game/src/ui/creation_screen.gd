class_name CreationScreen
extends Control
## Character creation: name, attributes, three tagged skills, up to two traits.

var _name: LineEdit
var _sex := "m"
var _attrs: Dictionary = {}
var _tags: Array = []
var _traits: Array = []
var _cols: HBoxContainer
var _info: Label
var _begin: Button
var _errors: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var r := DB.rules()
	for a in CharacterSheet.ATTR_IDS:
		_attrs[a] = int(r["attribute_start"])
	var pre: Dictionary = DB.story().get("default_hero", {})
	if not pre.is_empty():
		for a in pre.get("attrs", {}):
			_attrs[a] = int(pre["attrs"][a])
		_tags = pre.get("tags", []).duplicate()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)
	top.add_child(UITheme.label("Who are you?", 26, UITheme.BRONZE))
	_name = LineEdit.new()
	_name.placeholder_text = "Your name"
	_name.text = pre.get("name", "")
	_name.custom_minimum_size.x = 260
	_name.text_changed.connect(func(_t): _refresh())
	top.add_child(_name)
	var sexb := UITheme.button("Man", func(): pass, 100)
	sexb.pressed.connect(func():
		_sex = "f" if _sex == "m" else "m"
		sexb.text = "Woman" if _sex == "f" else "Man")
	top.add_child(sexb)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 30)
	_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_cols)
	_info = UITheme.label(DB.story().get("creation_hint", "Point at anything to read about it."), 15, UITheme.TEXT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(1200, 60)
	vb.add_child(_info)
	var bottom := HBoxContainer.new()
	vb.add_child(bottom)
	bottom.add_child(UITheme.button("Back", func(): Game.goto("title", {}), 140))
	_errors = UITheme.label("", 14, UITheme.BAD)
	_errors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_errors.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_errors)
	_begin = UITheme.button("Begin", _start, 200)
	bottom.add_child(_begin)
	_refresh()


func _hint(c: Control, text: String) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_entered.connect(func(): _info.text = text)


func _preview() -> CharacterSheet:
	return CharacterSheet.create(_name.text, _attrs, _tags, _traits)


func _refresh() -> void:
	for c in _cols.get_children():
		c.queue_free()
	var r := DB.rules()
	var s := _preview()
	# Attributes
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size.x = 330
	_cols.add_child(c1)
	var left := CharacterSheet.creation_points_left(_attrs)
	c1.add_child(UITheme.label("Attributes   (%d points left)" % left, 17, UITheme.BRONZE if left == 0 else UITheme.WARN))
	for a in r["attributes"]:
		var id: String = a["id"]
		var row := HBoxContainer.new()
		var l := UITheme.label(a["name"], 16)
		l.custom_minimum_size.x = 140
		_hint(l, "%s: %s" % [a["name"], a["desc"]])
		row.add_child(l)
		var minus := UITheme.button("-", func():
			_attrs[id] = int(_attrs[id]) - 1
			_refresh())
		minus.custom_minimum_size = Vector2(30, 26)
		minus.disabled = int(_attrs[id]) <= int(r["attribute_min"])
		row.add_child(minus)
		var v := UITheme.label("%2d" % s.attr(id), 18, UITheme.TEXT)
		v.custom_minimum_size.x = 36
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(v)
		var plus := UITheme.button("+", func():
			_attrs[id] = int(_attrs[id]) + 1
			_refresh())
		plus.custom_minimum_size = Vector2(30, 26)
		plus.disabled = left <= 0 or int(_attrs[id]) >= int(r["attribute_max"])
		row.add_child(plus)
		c1.add_child(row)
	c1.add_child(HSeparator.new())
	var av := s.armor_values()
	for pair in [["Health", str(s.max_hp())], ["Action points", str(s.max_ap())], ["Defense", str(s.derived("defense") + int(av["defense"]))],
			["Melee bonus", "+%d" % s.derived("melee_bonus")], ["Carry", str(s.derived("carry"))], ["Sequence", str(s.derived("sequence"))],
			["Critical", "%d%%" % s.derived("crit")], ["Skill points per level", str(s.derived("skill_points"))]]:
		c1.add_child(UITheme.label("%s: %s" % pair, 14, UITheme.DIM))
	# Skills
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size.x = 400
	_cols.add_child(c2)
	var tagn := int(r["tag_count"])
	c2.add_child(UITheme.label("Skills   (tag %d: %d chosen)" % [tagn, _tags.size()], 17, UITheme.BRONZE if _tags.size() == tagn else UITheme.WARN))
	for sk in DB.skill_defs():
		var id: String = sk["id"]
		var tagged := id in _tags
		var b := UITheme.button("%s %s   %d%%" % ["[x]" if tagged else "[  ]", sk["name"], s.skill(id)], func():
			if id in _tags:
				_tags.erase(id)
			elif _tags.size() < tagn:
				_tags.append(id)
			_refresh())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(360, 24)
		b.add_theme_font_size_override("font_size", 14)
		if tagged:
			b.add_theme_color_override("font_color", UITheme.WARN)
		b.mouse_entered.connect(func(): _info.text = "%s (%s): %s  Tagged skills start %d higher and rise twice as fast." % [sk["name"], sk.get("group", ""), sk["desc"], int(r["tag_bonus"])])
		c2.add_child(b)
	# Traits
	var c3 := VBoxContainer.new()
	c3.custom_minimum_size.x = 380
	_cols.add_child(c3)
	var maxt := int(r["max_traits"])
	c3.add_child(UITheme.label("Traits   (up to %d)" % maxt, 17, UITheme.BRONZE))
	for t in r["traits"]:
		var id: String = t["id"]
		var on := id in _traits
		var b := UITheme.button("%s %s" % ["[x]" if on else "[  ]", t["name"]], func():
			if id in _traits:
				_traits.erase(id)
			elif _traits.size() < maxt:
				_traits.append(id)
			_refresh())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(340, 26)
		if on:
			b.add_theme_color_override("font_color", UITheme.WARN)
		b.mouse_entered.connect(func(): _info.text = "%s: %s" % [t["name"], t["desc"]])
		c3.add_child(b)
	var errs := CharacterSheet.creation_errors(_name.text, _attrs, _tags, _traits)
	_errors.text = errs[0] if not errs.is_empty() else ""
	_begin.disabled = not errs.is_empty()


func _start() -> void:
	var s := _preview()
	s.sex = _sex
	var st := DB.story()
	for id in st.get("start_equip", []):
		s.inventory.add(id, 1)
		s.equip(id)
	s.hp = s.max_hp()
	Game.new_game(s)
	Game.start_story()
