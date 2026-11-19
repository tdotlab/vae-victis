class_name Atmos
extends CanvasLayer
## Weather and fire over a local map: smoke rising from hearths (out through
## the roof when the hearth is indoors), rain where the map says it rains,
## and the light of fires, which matters most at night. Drawn on its own
## layer above the map and below the style's post pass, so the night tint
## doesn't swallow the firelight. Nothing here touches game rules.
##
## A map opts in with "weather": "rain", optionally only while a story flag
## is set ("weather_flag"): Avaricum rains from the siege on, Caesar's cold,
## constant rain (BG VII.24). "fires": false puts out a map's hearths.

const WIND := Vector2(0.55, 0.0)  # smoke drift, screen px per px risen
const SMOKE_PERIOD := 7.0
const PUFFS := 7

var sources: Array = []  # {fire: Vector2, smoke: Vector2, roof: Dictionary, seed: float}
var rain := 0.0
var tint := Color.WHITE
var player_cell := Vector2i(-9999, -9999)
var _t := 0.0
var _light: Node2D
var _air: Node2D
var _glow: Texture2D


class _Pass extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


func setup(map: MapData, roofs: Array) -> void:
	layer = 1
	follow_viewport_enabled = true
	_light = _Pass.new()
	_light.fn = _draw_light
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	add_child(_light)
	_air = _Pass.new()
	_air.fn = _draw_air
	add_child(_air)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt
	rain = 1.0 if rains(map.def, Game.state.flags) else 0.0
	if not map.def.get("fires", true):
		return
	var tdefs := DB.terrain()
	for c in map.cells:
		if not tdefs.get(map.cells[c], {}).get("glow", false):
			continue
		var p := Hex.to_pixel(c, Paint.HEX)
		var roof := {}
		for r in roofs:
			if r["cells"].has(c):
				roof = r
				break
		var smoke := p - Vector2(0, 10)
		if not roof.is_empty():
			smoke = Geometry2D.get_closest_point_to_segment(p - Vector2(0, 40), roof["ridge"][0], roof["ridge"][1])
		sources.append({"fire": p, "smoke": smoke, "roof": roof, "seed": fmod(float(c.x) * 0.37 + float(c.y) * 0.61, 1.0)})


## Whether it rains on a map with this def, given the story flags.
static func rains(def: Dictionary, flags: Dictionary) -> bool:
	if str(def.get("weather", "")) != "rain":
		return false
	var f := str(def.get("weather_flag", ""))
	return f == "" or int(flags.get(f, 0)) != 0


func tick(delta: float, night_color: Color, cell: Vector2i) -> void:
	_t += delta
	tint = night_color
	player_cell = cell
	_light.queue_redraw()
	_air.queue_redraw()


## 0 by day, 1 at full night, from the map's night tint.
func _night() -> float:
	var lum := tint.r * 0.3 + tint.g * 0.5 + tint.b * 0.2
	return clampf((1.0 - lum) / 0.5, 0.0, 1.0)


func _draw_light(ci: CanvasItem) -> void:
	var n := _night()
	var base := 0.12 + 0.6 * n
	for s in sources:
		# An indoor fire lights its house only while the roof is off, i.e.
		# while the player is inside.
		if not s["roof"].is_empty() and not s["roof"]["cells"].has(player_cell):
			continue
		var k: float = s["seed"] * 40.0
		var flick := 0.86 + 0.08 * sin(_t * 7.1 + k) + 0.06 * sin(_t * 12.7 + k * 1.7)
		var r := (70.0 + 30.0 * n) * (0.97 + 0.03 * sin(_t * 5.3 + k))
		var col := Color(1.0, 0.55, 0.2) * (base * flick)
		col.a = 1.0
		var p: Vector2 = s["fire"] - Vector2(0, 6)
		ci.draw_set_transform(p, 0, Vector2(1, 0.62))
		ci.draw_texture_rect(_glow, Rect2(Vector2(-r, -r), Vector2(r, r) * 2), false, col)
		ci.draw_texture_rect(_glow, Rect2(Vector2(-r, -r) * 0.35, Vector2(r, r) * 0.7), false, col * 0.6)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_air(ci: CanvasItem) -> void:
	var smoke := Color(0.62, 0.6, 0.57) * tint
	for s in sources:
		var seed: float = s["seed"]
		var origin: Vector2 = s["smoke"]
		for i in range(PUFFS):
			var k := fmod(_t / SMOKE_PERIOD + float(i) / PUFFS + seed, 1.0)
			var rise := k * 95.0
			var pos := origin + Vector2(WIND.x * rise + sin(k * 6.0 + seed * 20.0) * 4.0, -rise)
			var c := smoke
			c.a = 0.75 * (1.0 - k) * minf(1.0, k * 8.0)
			var r := 6.0 + 18.0 * k
			ci.draw_texture_rect(_glow, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2), false, c)
	if rain <= 0.0:
		return
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var vis := Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
	ci.draw_rect(vis, Color(0.32, 0.36, 0.42, 0.13 * rain))
	var drop := Color(0.78, 0.82, 0.9, 0.32) * Color(tint.r, tint.g, tint.b, 1.0)
	var n := int(320 * rain)
	for i in range(n):
		var hx := fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var hy := fmod(sin(float(i) * 78.233) * 12543.123, 1.0)
		hx = absf(hx)
		hy = absf(hy)
		var speed := 0.9 + 0.3 * hx
		var y := fmod(hy + _t * speed, 1.0)
		var p := vis.position + Vector2(fmod(hx + y * 0.06, 1.0) * vis.size.x, y * vis.size.y)
		ci.draw_line(p, p + Vector2(-3.0, 13.0), drop, 1.0)
