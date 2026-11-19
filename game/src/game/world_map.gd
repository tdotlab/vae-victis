class_name WorldMap
extends Node2D
## The travel map of Gaul. Click a place to walk there; the days pass as you
## go, the country reveals itself around you, and the road has its own ideas
## (random encounters). Arriving on a known location enters it.
## Rules live in WorldData; this file draws and drives them.

const CELL := 26.0
const STEP_TIME := 0.16          # seconds of animation per cell
const PANEL_W := 270.0
const BAR_H := 152.0

var world: WorldData
var hud: HUD
var modal_open := false
var _cam: Camera2D
var _pos: Vector2i
var _marker := Vector2.ZERO
var _path: Array = []
var _dest_loc := ""              # location to enter on arrival
var _step_t := 0.0
var _seen := {}
var _hover := Vector2i(-1, -1)
var _rest_heal_carry := 0.0
var _panel_box: VBoxContainer
var _here: Label
var _enter_btn: Button
var _places: VBoxContainer
var _tip: Label
var _font: Font


func _ready() -> void:
	var gs := Game.state
	gs.map_id = ""
	world = WorldData.load_world()
	_font = ThemeDB.fallback_font
	_pos = gs.world_pos
	if not world.in_bounds(_pos):
		var home := world.location(DB.story().get("home_location", "brigodunon"))
		_pos = world.location_cell(home) if not home.is_empty() else Vector2i(0, 0)
		gs.world_pos = _pos
	for i in gs.world_seen:
		_seen[int(i)] = true
	_marker = _center(_pos)
	if gs.world_seen.is_empty():
		_reveal(_pos, int(DB.story().get("home_reveal", 3)))
	_reveal(_pos)
	for l in gs.known_locations:
		var loc := world.location(l)
		if not loc.is_empty():
			_reveal(world.location_cell(loc), 0)
	_cam = Camera2D.new()
	_cam.offset = Vector2(PANEL_W / 2.0, BAR_H / 2.0)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 5.0
	_cam.position = _marker
	add_child(_cam)
	_cam.reset_smoothing()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = HUD.new()
	hud.world = self
	ui.add_child(hud)
	_build_panel(hud)
	_tip = UITheme.label("", 14)
	_tip.add_theme_color_override("font_outline_color", Color.BLACK)
	_tip.add_theme_constant_override("outline_size", 4)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_tip)
	_refresh_panel()
	Game.say("You are on the road. Click a place to travel there.")
	_discover()
	await get_tree().process_frame
	_show_news()


# --- Geometry ----------------------------------------------------------------

func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5) * CELL


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _idx(c: Vector2i) -> int:
	return c.y * world.width + c.x


func _is_seen(c: Vector2i) -> bool:
	return _seen.has(_idx(c))


func _reveal(c: Vector2i, radius: int = -1) -> void:
	var r := int(world.def.get("reveal_radius", 1)) if radius < 0 else radius
	# Hills and mountains show you farther.
	if radius < 0 and world.terrain_id(c) in ["hills", "mountains"]:
		r += 1
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var n := Vector2i(x, y)
			if world.in_bounds(n) and not _seen.has(_idx(n)):
				_seen[_idx(n)] = true
				Game.state.world_seen.append(_idx(n))
	queue_redraw()


func _known(l: Dictionary) -> bool:
	return l["id"] in Game.state.known_locations


func _survival() -> int:
	return Game.state.player.skill("survival")


# --- Side panel ----------------------------------------------------------------

func _build_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_W
	panel.offset_bottom = -BAR_H
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 6)
	panel.add_child(_panel_box)
	_panel_box.add_child(UITheme.label(world.def.get("title", "Gaul"), 22, UITheme.BRONZE))
	_here = UITheme.label("", 14)
	_here.autowrap_mode = TextServer.AUTOWRAP_WORD
	_here.custom_minimum_size.x = PANEL_W - 20
	_panel_box.add_child(_here)
	_enter_btn = UITheme.button("", _enter_here)
	_panel_box.add_child(_enter_btn)
	_panel_box.add_child(HSeparator.new())
	_panel_box.add_child(UITheme.label("Places you know", 16, UITheme.BRONZE))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_box.add_child(scroll)
	_places = VBoxContainer.new()
	_places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_places)


func _refresh_panel() -> void:
	var gs := Game.state
	var loc := world.location_at(_pos)
	var t := world.terrain(_pos)
	var lines: Array = []
	if not loc.is_empty() and _known(loc):
		lines.append(loc["name"])
		lines.append(loc.get("desc", ""))
	else:
		lines.append(t.get("name", ""))
	lines.append(gs.date_text())
	_here.text = "\n".join(lines)
	_enter_btn.visible = not loc.is_empty() and _known(loc)
	if _enter_btn.visible:
		_enter_btn.text = "Enter %s (E)" % loc["name"]
	for c in _places.get_children():
		c.queue_free()
	for l in world.locations:
		if not _known(l):
			continue
		var lid: String = l["id"]
		var lc := world.location_cell(l)
		var label: String = l["name"]
		if lc == _pos:
			label += "  (here)"
		else:
			var path := world.find_path(_pos, lc, gs.season(), _survival())
			if path.is_empty():
				label += "  (no way)"
			else:
				label += "  (%s)" % _duration_text(world.path_hours(_pos, path, gs.season(), _survival()))
		var b := UITheme.button(label, func(): _travel_to_location(lid))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size.x = PANEL_W - 24
		_places.add_child(b)
	hud.refresh()


static func _duration_text(hours: float) -> String:
	var h := int(round(hours))
	if h < 24:
		return "%d hours" % maxi(1, h)
	var d := h / 24
	var rest := h % 24
	if rest == 0:
		return "%d day%s" % [d, "" if d == 1 else "s"]
	return "%d day%s %d h" % [d, "" if d == 1 else "s", rest]


# --- Travel ------------------------------------------------------------------

func _travel_to_location(lid: String) -> void:
	if modal_open:
		return
	var l := world.location(lid)
	var lc := world.location_cell(l)
	if lc == _pos:
		_enter(l)
		return
	_set_destination(lc)
	_dest_loc = lid if not _path.is_empty() else ""


func _set_destination(c: Vector2i) -> void:
	_dest_loc = ""
	if c == _pos:
		_path = []
		return
	if not world.passable(c):
		Game.say("You can't cross there. Look for a ford.")
		return
	var p := world.find_path(_pos, c, Game.state.season(), _survival())
	if p.is_empty():
		Game.say("You can't find a way there.")
		return
	_path = p
	_step_t = 0.0
	queue_redraw()


func stop() -> void:
	_path = []
	_dest_loc = ""
	queue_redraw()


func _process(delta: float) -> void:
	_update_hover()
	queue_redraw()
	if _path.is_empty() or modal_open:
		return
	_step_t += delta
	var next: Vector2i = _path[0]
	_marker = _center(_pos).lerp(_center(next), clampf(_step_t / STEP_TIME, 0.0, 1.0))
	_cam.position = _marker
	queue_redraw()
	if _step_t < STEP_TIME:
		return
	_step_t = 0.0
	_path.pop_front()
	_arrive_cell(next)


func _arrive_cell(c: Vector2i) -> void:
	var gs := Game.state
	var hours := world.hours_for(c, gs.season(), _survival())
	if c.x != _pos.x and c.y != _pos.y:
		hours *= 1.4
	_pos = c
	gs.world_pos = c
	_marker = _center(c)
	_pass_time(int(round(hours * 60.0)), 3.0)
	_reveal(c)
	_discover()
	_refresh_panel()
	if _show_news():
		return
	if _path.is_empty() and _dest_loc != "":
		var lid := _dest_loc
		_dest_loc = ""
		_enter(world.location(lid))
		return
	_roll_encounter(c)


## Advances the clock and heals: one heal-rate's worth per `hours_per_heal`.
func _pass_time(mins: int, hours_per_heal: float) -> void:
	var gs := Game.state
	gs.advance(mins)
	var p := gs.player
	_rest_heal_carry += mins / 60.0 / hours_per_heal * p.derived("heal_rate")
	var whole := int(_rest_heal_carry)
	if whole > 0:
		_rest_heal_carry -= whole
		p.hp = mini(p.max_hp(), p.hp + whole)


func _discover() -> void:
	var gs := Game.state
	for l in world.discover_near(_pos, 1, gs.known_locations):
		gs.known_locations.append(l["id"])
		_reveal(world.location_cell(l), 0)
		Game.say("You find %s." % l["name"], "good")
	_refresh_panel()


func _show_news() -> bool:
	var news := Game.check_calendar()
	if news.is_empty():
		return false
	stop()
	for ev in news:
		_popup(ev.get("title", ""), ev.get("text", ""), [["Go on", func(): pass]])
	return true


# --- Encounters ----------------------------------------------------------------

func _roll_encounter(c: Vector2i) -> void:
	var gs := Game.state
	var night := gs.hour() < 6 or gs.hour() >= 20
	if not gs.dice.chance(world.encounter_chance(c, night)):
		return
	var e := world.pick_encounter(c, gs.day(), gs.dice)
	if e.is_empty():
		return
	var dest: Vector2i = _path.back() if not _path.is_empty() else c
	var dest_loc := _dest_loc
	stop()
	var spot := clampi(_survival() + 10, 5, 95)
	var text: String = e.get("text", "")
	if gs.dice.chance(spot):
		_popup(world.def.get("encounter_title", "On the road"), text + "\n\n" + world.def.get("spotted_text", "You see them before they see you."), [
			["Approach", func(): _start_encounter(e, c)],
			["Go around", func():
				Game.say(world.def.get("avoided_text", "You give them a wide berth."))
				_set_destination(dest)
				_dest_loc = dest_loc],
		])
	else:
		_popup(world.def.get("encounter_title", "On the road"), text, [["Go on", func(): _start_encounter(e, c)]])


func _start_encounter(e: Dictionary, c: Vector2i) -> void:
	var gs := Game.state
	var map_id: String = e.get("map", world.terrain(c).get("encounter_map", "enc_open"))
	gs.encounter = {"id": e["id"], "actors": e.get("actors", []), "text": e.get("text", "")}
	gs.map_states.erase(map_id)
	gs.map_id = map_id
	gs.entry = "start"
	Game.goto("map", {})


# --- Locations ----------------------------------------------------------------

func _enter_here() -> void:
	var l := world.location_at(_pos)
	if not l.is_empty() and _known(l):
		_enter(l)


func _enter(l: Dictionary) -> void:
	if l.is_empty():
		return
	stop()
	if not l.has("map"):
		_popup(l["name"], "%s\n\n%s" % [l.get("desc", ""), l.get("closed_text", "")], [["Back", func(): pass]])
		return
	var gs := Game.state
	if l.has("open_flag") and gs.flag(l["open_flag"]) == 0:
		_popup(l["name"], "%s\n\n%s" % [l.get("desc", ""), l.get("shut_text", "")], [["Back", func(): pass]])
		return
	var where := WorldData.map_entry(l, gs.flags)
	gs.map_id = where["map"]
	gs.entry = where["entry"]
	Game.goto("map", {})


# --- Resting and saving ----------------------------------------------------------

## Camps until healed, at most a day.
func rest() -> void:
	if modal_open:
		return
	stop()
	var p := Game.state.player
	if p.hp >= p.max_hp():
		_pass_time(8 * 60, 1.0)
		Game.say("You rest for eight hours.")
	else:
		var hours := 0
		while p.hp < p.max_hp() and hours < 24:
			_pass_time(60, 1.0)
			hours += 1
		Game.say("You make camp and rest for %d hours." % hours, "good")
	_refresh_panel()
	_show_news()


func quick_save() -> void:
	Game.state.world_pos = _pos
	if Game.save_game("quick"):
		Game.say("Game saved.", "good")


func _popup(title: String, text: String, buttons: Array) -> void:
	var r := UITheme.modal(hud, title, Vector2(560, 0))
	var root: Control = r[0]
	var vb: VBoxContainer = r[1]
	root.set_meta("no_escape", true)
	var l := UITheme.label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 520
	vb.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	for b in buttons:
		var cb: Callable = b[1]
		row.add_child(UITheme.button(b[0], func():
			hud.close_modal(root)
			cb.call(), 160))
	hud.push_modal(root)


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if modal_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var c := _cell_at(get_global_mouse_position())
			if not world.in_bounds(c):
				return
			var l := world.location_at(c)
			if not l.is_empty() and _known(l) and _is_seen(c):
				_travel_to_location(l["id"])
			else:
				_set_destination(c)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			stop()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_I:
				hud.open_inventory()
			KEY_C:
				hud.open_character()
			KEY_J:
				hud.open_journal()
			KEY_R:
				rest()
			KEY_E:
				_enter_here()
			KEY_SPACE:
				stop()
			KEY_HOME:
				_cam.position = _marker
			KEY_F5:
				quick_save()
			KEY_F9:
				if Game.has_save("quick"):
					Game.goto("load", {"slot": "quick"})


func _update_hover() -> void:
	if modal_open:
		_tip.text = ""
		return
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport_rect().size
	if mp.x > vs.x - PANEL_W or mp.y > vs.y - BAR_H:
		_tip.text = ""
		return
	var c := _cell_at(get_global_mouse_position())
	if c == _hover:
		_tip.position = mp + Vector2(16, 12)
		return
	_hover = c
	queue_redraw()
	if not world.in_bounds(c):
		_tip.text = ""
		return
	if not _is_seen(c):
		_tip.text = "Unknown country"
	else:
		var l := world.location_at(c)
		var name_: String = l["name"] if not l.is_empty() and _known(l) else world.terrain(c).get("name", "")
		_tip.text = name_
		if c != _pos and world.passable(c):
			var gs := Game.state
			var p := world.find_path(_pos, c, gs.season(), _survival())
			if not p.is_empty():
				_tip.text += "\n" + _duration_text(world.path_hours(_pos, p, gs.season(), _survival()))
	_tip.position = mp + Vector2(16, 12)


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var season := Game.state.season()
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(world.width * CELL + 4000, world.height * CELL + 4000)), Color("#0f1113"))
	for y in range(world.height):
		for x in range(world.width):
			var c := Vector2i(x, y)
			var r := Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			if not _is_seen(c):
				var h := Paint._hash(c)
				draw_rect(r, Color("#16191c").lightened(h * 0.04))
				continue
			_draw_cell(c, r, season)
	# Faint grid over the known country.
	var grid := Color(0, 0, 0, 0.12)
	for x in range(world.width + 1):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, world.height * CELL), grid)
	for y in range(world.height + 1):
		draw_line(Vector2(0, y * CELL), Vector2(world.width * CELL, y * CELL), grid)
	# Route
	if not _path.is_empty():
		var prev := _marker
		for c in _path:
			var p := _center(c)
			draw_dashed_line(prev, p, Color("#e8d8a0", 0.8), 2.0, 5.0)
			prev = p
		var end := _center(_path.back())
		draw_line(end + Vector2(-5, -5), end + Vector2(5, 5), Color("#e8d8a0"), 2.0)
		draw_line(end + Vector2(-5, 5), end + Vector2(5, -5), Color("#e8d8a0"), 2.0)
	# Locations
	for l in world.locations:
		if not _known(l):
			continue
		var lc := world.location_cell(l)
		var p := _center(lc)
		var rad := 6.0 + 3.0 * int(l.get("size", 1))
		draw_circle(p, rad, Color("#c8a050", 0.22))
		draw_arc(p, rad, 0, TAU, 32, Color("#e0b860"), 2.0)
		var name_: String = l["name"]
		var w := _font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tp := p + Vector2(-w / 2.0, rad + 14)
		draw_string_outline(_font, tp, name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
		draw_string(_font, tp, name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f0dca0"))
	# Hover
	if world.in_bounds(_hover):
		draw_rect(Rect2(Vector2(_hover) * CELL, Vector2(CELL, CELL)), Color(1, 1, 1, 0.35), false, 1.5)
	# You
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	draw_circle(_marker, 7.0, Color(0, 0, 0, 0.7))
	draw_circle(_marker, 5.0, Color("#f0c040"))
	draw_arc(_marker, 9.0 + pulse * 2.0, 0, TAU, 24, Color("#f0c040", 0.6), 1.5)


func _draw_cell(c: Vector2i, r: Rect2, season: String) -> void:
	var tid := world.terrain_id(c)
	var t := world.terrain(c)
	var h := Paint._hash(c)
	var base := Color(t.get("color", "#6b6a3a"))
	if season == "winter" and tid in ["plain", "hills", "forest"]:
		base = base.lerp(Color("#9a9a90"), 0.18)
	base = base.lightened((h - 0.5) * 0.08)
	draw_rect(r, base)
	var o := r.position
	var s := CELL
	match tid:
		"forest":
			var dark := base.darkened(0.35)
			for i in range(3):
				var px := o.x + s * (0.25 + 0.25 * i) + (Paint._hash(c + Vector2i(i, 7)) - 0.5) * 4.0
				var py := o.y + s * (0.45 + 0.2 * (i % 2))
				draw_colored_polygon(PackedVector2Array([Vector2(px, py - 7), Vector2(px - 5, py + 4), Vector2(px + 5, py + 4)]), dark)
		"hills":
			var line := base.darkened(0.3)
			draw_arc(o + Vector2(s * 0.35, s * 0.7), s * 0.22, PI, TAU, 10, line, 1.5)
			draw_arc(o + Vector2(s * 0.68, s * 0.55), s * 0.18, PI, TAU, 10, line, 1.5)
		"mountains":
			var peak := PackedVector2Array([o + Vector2(s * 0.15, s * 0.85), o + Vector2(s * 0.5, s * 0.18), o + Vector2(s * 0.85, s * 0.85)])
			draw_colored_polygon(peak, base.darkened(0.25))
			var cap_col := Color("#e8e8e0") if season in ["winter", "spring"] else Color("#b0aca0")
			draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.38, s * 0.42), o + Vector2(s * 0.5, s * 0.18), o + Vector2(s * 0.62, s * 0.42)]), cap_col)
		"marsh":
			var w := base.lightened(0.2)
			for i in range(3):
				var y := o.y + s * (0.3 + 0.2 * i)
				draw_line(Vector2(o.x + s * 0.2, y), Vector2(o.x + s * 0.55, y), w, 1.0)
		"river":
			var wave := base.lightened(0.25)
			draw_line(o + Vector2(s * 0.15, s * 0.45), o + Vector2(s * 0.45, s * 0.55), wave, 1.5)
			draw_line(o + Vector2(s * 0.5, s * 0.5), o + Vector2(s * 0.85, s * 0.42), wave, 1.5)
		"ford":
			var stone := Color("#b8b0a0")
			for i in range(4):
				draw_circle(o + Vector2(s * (0.2 + 0.2 * i), s * (0.5 + 0.08 * ((i % 2) * 2 - 1))), 2.2, stone)
