class_name Art
extends RefCounted
## Rendered art: sprite sheets and ground textures built by art/sprites.py
## (Blender) and art/pack.py, listed in assets/art/art.json. Also the art
## style switch (F2 on a map). Anything without a sprite falls back to the
## code-drawn placeholders in Paint, which are also a style of their own.

const DIR := "res://assets/art/"
const TILE := 256.0  # screen pixels covered by one ground texture tile

static var style := -1
static var _man: Dictionary = {}
static var _loaded := false
static var _tex: Dictionary = {}


static func styles() -> Array:
	return DB.load_json("art_styles.json").get("styles", [])


static func style_def() -> Dictionary:
	_init_style()
	return styles()[style]


static func _init_style() -> void:
	if style >= 0:
		return
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	set_style(cfg.get_value("art", "style", "rendered"), false)


## Picks a style by id; unknown ids fall back to the first.
static func set_style(id: String, save := true) -> void:
	style = 0
	for i in range(styles().size()):
		if styles()[i]["id"] == id:
			style = i
	if save:
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		cfg.set_value("art", "style", id)
		cfg.save("user://settings.cfg")


static func cycle() -> String:
	_init_style()
	set_style(styles()[(style + 1) % styles().size()]["id"])
	return DB.load_json("art_styles.json").get("message", "%s") % style_def()["name"]


static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var d = DB.load_json(DIR + "art.json") if FileAccess.file_exists(DIR + "art.json") else null
		_man = d if d is Dictionary else {}
	return _man


## True when sprites should be drawn instead of the placeholders.
static func on() -> bool:
	return style_def().get("sprites", false) and not manifest().is_empty()


static func _texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load(DIR + file) if ResourceLoader.exists(DIR + file) else null
	return _tex[file]


# --- Ground -------------------------------------------------------------------

static func ground_id(terrain: String) -> String:
	return manifest().get("alias", {}).get(terrain, terrain)


static func ground_texture(terrain: String) -> Texture2D:
	var g: Dictionary = manifest().get("ground", {})
	var id := ground_id(terrain)
	return _texture(g[id]) if g.has(id) else null


static func blend_rank(terrain: String) -> int:
	return int(manifest().get("blend", {}).get(ground_id(terrain), -1))


## The ground under a wall, tree or prop; "" means the map's default ground.
static func ground_under(terrain: String) -> String:
	for group in ["walls", "props"]:
		var e: Dictionary = manifest().get(group, {}).get(terrain, {})
		if not e.is_empty():
			var u = e.get("under")
			return u if u is String else ""
	return ""


static func _uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for p in pts:
		uv.append(p / TILE)
	return uv


static func draw_ground(ci: CanvasItem, c: Vector2i, tex: Texture2D) -> void:
	var pts := Hex.corners(Hex.to_pixel(c, Paint.HEX), Paint.HEX + 0.5)
	ci.draw_colored_polygon(pts, Color.WHITE, _uvs(pts), tex)


## A soft fringe of this hex's ground over the neighbor across edge i.
static func draw_fringe(ci: CanvasItem, c: Vector2i, edge: int, tex: Texture2D) -> void:
	var p := Hex.to_pixel(c, Paint.HEX)
	var inner := Hex.corners(p, Paint.HEX)
	var outer := Hex.corners(p, Paint.HEX * 1.42)
	var j := (edge + 1) % 6
	var pts := PackedVector2Array([inner[edge], inner[j], outer[j], outer[edge]])
	var w := Color(1, 1, 1, 1)
	var t := Color(1, 1, 1, 0)
	ci.draw_polygon(pts, PackedColorArray([w, w, t, t]), _uvs(pts), tex)


# --- Things standing on the map --------------------------------------------------

static func _frame(ci: CanvasItem, e: Dictionary, sheet: String, idx: int, pos: Vector2, mod := Color.WHITE) -> void:
	var tex := _texture(sheet)
	if tex == null:
		return
	var s: float = manifest().get("scale", 0.5)
	var cell := Vector2(e["cell"][0], e["cell"][1])
	var anchor := Vector2(e["anchor"][0], e["anchor"][1])
	var cols := int(e.get("cols", 1))
	var src := Rect2(Vector2(idx % cols, idx / cols) * cell, cell)
	ci.draw_texture_rect_region(tex, Rect2(pos - anchor * s, cell * s), src, mod)


static func has_wall(terrain: String) -> bool:
	return manifest().get("walls", {}).has(terrain)


static func has_thing(terrain: String) -> bool:
	return manifest().get("trees", {}).has(terrain) or manifest().get("props", {}).has(terrain)


## Draws a wall hex joined to its neighbors. Bit d of the frame is set when
## the neighbor in Hex.DIRECTIONS[d] continues the wall.
static func draw_wall(ci: CanvasItem, map: MapData, c: Vector2i, terrain: String, fade: float) -> void:
	var e: Dictionary = manifest()["walls"][terrain]
	var mask := 0
	for d in range(6):
		if str(map.cells.get(Hex.neighbor(c, d), "")) in e.get("connect", []):
			mask |= 1 << d
	_frame(ci, e, e["sheet"], mask, Hex.to_pixel(c, Paint.HEX), Color(1, 1, 1, fade))


static func draw_thing(ci: CanvasItem, c: Vector2i, terrain: String, fade: float) -> void:
	var m := manifest()
	var mod := Color(1, 1, 1, fade)
	var p := Hex.to_pixel(c, Paint.HEX)
	if m["trees"].has(terrain):
		var e: Dictionary = m["trees"][terrain]
		_frame(ci, e, e["sheet"], int(Paint._hash(c) * 997) % int(e["frames"]), p, mod)
	elif m["props"].has(terrain):
		var e2: Dictionary = m["props"][terrain]
		_frame(ci, e2, e2["sheet"], int(e2["frame"]), p, mod)


## A person: the body recolored from their look, then what they wear and
## carry, each a layer of its own. Beasts with a sprite (by NPC template)
## draw the same way without the gear. Returns false when there is no sprite,
## so the caller can fall back to Paint.
static func draw_figure(ci: CanvasItem, pos: Vector2, a: Actor, walk_phase: float, ring: Color) -> bool:
	var f: Dictionary = manifest().get("figure", {})
	if a.look.get("beast", false):
		f = manifest().get("beasts", {}).get(a.template, {})
	if f.is_empty():
		return false
	if ring.a > 0:
		ci.draw_set_transform(pos, 0, Vector2(1, 0.45))
		ci.draw_arc(Vector2.ZERO, 17.0, 0, TAU, 28, ring, 2.5)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var down := a.dead or a.unconscious or a.knocked_down
	var idx := 18
	if not down:
		var s := sin(walk_phase)
		idx = a.facing * 3 + (1 if s > 0.35 else (2 if s < -0.35 else 0))
	var look := a.look
	var tints := {
		"tunic": Color(look.get("tunic", Paint._faction_color(a.faction))),
		"trousers": Color(look.get("trousers", "#4b4136")),
		"hair": Color(look.get("hair", "#4a3020")),
		"cloak": Color(look.get("cloak", "#5a4a3a")),
		"shield": Color(look.get("shield", "#7a4a28")),
	}
	var layers := ["body"]
	if not down and not look.get("beast", false):
		var gear: Dictionary = f.get("gear", {})
		for slot in ["armor", "cloak", "helmet", "shield", "weapon"]:
			var layer := ""
			if slot == "cloak":
				layer = "cloak" if look.has("cloak") else ""
			else:
				layer = gear.get(a.sheet.equipped(slot), "")
			if layer != "":
				layers.append(layer)
	for name in layers:
		var l: Dictionary = f["layers"].get(name, {})
		if l.is_empty():
			continue
		_frame(ci, f, l["sheet"], idx, pos)
		for key in l.get("tints", {}):
			var t: Color = tints[key]
			if key == "shield" and a.shield_fouled:
				t = t.darkened(0.4)
			_frame(ci, f, l["tints"][key], idx, pos, Color(t.r * 2.0, t.g * 2.0, t.b * 2.0, 1.0))
	if a.dead:
		ci.draw_circle(pos + Vector2(4, 4), 6.0, Color(0.4, 0.05, 0.03, 0.7))
	return true


# --- Pixel styles ------------------------------------------------------------------

## A full-screen pass between the map and the HUD that turns the map into
## chunky pixels (and optionally a fixed palette), for the pixel styles.
static func make_post_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/view/pixelate.gdshader")
	rect.material = mat
	layer.add_child(rect)
	update_post_layer(layer, Vector2.ZERO)
	return layer


static func update_post_layer(layer: CanvasLayer, origin_px: Vector2) -> void:
	var d := style_def()
	var rect := layer.get_child(0) as ColorRect
	var px := float(d.get("pixel", 0))
	layer.visible = px > 0
	if px <= 0:
		return
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("px", px)
	mat.set_shader_parameter("origin", origin_px)
	var pal: Array = d.get("palette", [])
	var cols := PackedVector3Array()
	for h in pal:
		var c := Color(h)
		cols.append(Vector3(c.r, c.g, c.b))
	while cols.size() < 32:
		cols.append(Vector3.ZERO)
	mat.set_shader_parameter("palette", cols)
	mat.set_shader_parameter("palette_size", pal.size())
	mat.set_shader_parameter("dither", float(d.get("dither", 0.0)))
