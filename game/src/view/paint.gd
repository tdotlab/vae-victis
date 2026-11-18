class_name Paint
extends RefCounted
## Placeholder art, drawn procedurally: ground hexes, raised walls, trees,
## and simple figures. Replaced by rendered sprites in the art milestone.

const HEX := 28.0


static func _hash(c: Vector2i) -> float:
	var h := (c.x * 73856093) ^ (c.y * 19349663)
	return float(posmod(h, 1000)) / 1000.0


static func floor_hex(ci: CanvasItem, c: Vector2i, tdef: Dictionary) -> void:
	var p := Hex.to_pixel(c, HEX)
	var col := Color(tdef.get("color", "#555555"))
	var n := _hash(c)
	col = col.lightened((n - 0.5) * 0.10)
	var pts := Hex.corners(p, HEX + 0.6)
	ci.draw_colored_polygon(pts, col)
	if tdef.get("indoor", false):
		# Plank seams for wooden floors, nothing for earth.
		if tdef.get("name", "") == "Plank floor":
			ci.draw_line(p + Vector2(-HEX * 0.7, -2), p + Vector2(HEX * 0.7, -2), col.darkened(0.25), 1.0)
	elif tdef.get("cover", false):
		for i in range(3):
			var o := Vector2((i - 1) * 9.0, -2.0 + (i % 2) * 4.0)
			ci.draw_circle(p + o, 5.0, col.darkened(0.15))
	elif tdef.get("name", "") == "Deep water" or tdef.get("name", "") == "Shallow water":
		var w := sin(n * 6.28) * 4.0
		ci.draw_line(p + Vector2(-8 + w, -2), p + Vector2(4 + w, -2), col.lightened(0.18), 1.0)
	elif tdef.get("name", "") == "Bones":
		ci.draw_line(p + Vector2(-6, -1), p + Vector2(6, 2), Color("#d8d0b8"), 2.0)
		ci.draw_circle(p + Vector2(-3, -4), 2.5, Color("#d8d0b8"))


static func grid_hex(ci: CanvasItem, c: Vector2i, color: Color, width: float = 1.0) -> void:
	var pts := Hex.corners(Hex.to_pixel(c, HEX), HEX)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width)


static func fill_hex(ci: CanvasItem, c: Vector2i, color: Color) -> void:
	ci.draw_colored_polygon(Hex.corners(Hex.to_pixel(c, HEX), HEX), color)


## Raised block (wall, rock, furniture) standing on cell c.
static func block(ci: CanvasItem, c: Vector2i, tdef: Dictionary, fade: float = 1.0) -> void:
	var h := float(tdef.get("height", 20))
	var p := Hex.to_pixel(c, HEX)
	var base := Hex.corners(p, HEX)
	var top := PackedVector2Array()
	for v in base:
		top.append(v - Vector2(0, h))
	var col := Color(tdef.get("color", "#777777"))
	col = col.lightened((_hash(c) - 0.5) * 0.08)
	var a := fade
	# Visible side faces: edges 0-1, 1-2, 2-3, 3-4 (right through left, front).
	var shades := [0.30, 0.22, 0.12, 0.05]
	for i in range(4):
		var j := i + 1
		var quad := PackedVector2Array([base[i], base[j], top[j], top[i]])
		var sc := col.darkened(shades[i])
		sc.a = a
		ci.draw_colored_polygon(quad, sc)
	var tc := col.lightened(0.08)
	tc.a = a
	ci.draw_colored_polygon(top, tc)
	if tdef.get("glow", false):
		ci.draw_circle(p - Vector2(0, h + 2), 6.0, Color(1.0, 0.55, 0.15, 0.85))
		ci.draw_circle(p - Vector2(0, h + 4), 3.0, Color(1.0, 0.85, 0.4, 0.95))


static func tree(ci: CanvasItem, c: Vector2i, tdef: Dictionary, fade: float = 1.0) -> void:
	var p := Hex.to_pixel(c, HEX)
	var h := float(tdef.get("height", 46))
	var col := Color(tdef.get("color", "#2f3d1c"))
	var a := fade
	ci.draw_set_transform(p, 0, Vector2(1, 0.5))
	ci.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.25 * a))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_rect(Rect2(p + Vector2(-3, -h * 0.45), Vector2(6, h * 0.45)), Color(0.28, 0.2, 0.12, a))
	var n := _hash(c)
	if tdef.get("name", "") == "Pine":
		for i in range(3):
			var y := -h * (0.35 + i * 0.22)
			var w := 17.0 - i * 4.5
			var tri := PackedVector2Array([p + Vector2(-w, y + 10), p + Vector2(w, y + 10), p + Vector2(0, y - 14)])
			var cc := col.lightened(0.05 * i + n * 0.06)
			cc.a = a
			ci.draw_colored_polygon(tri, cc)
	else:
		var cc := col.lightened(n * 0.08)
		cc.a = a
		ci.draw_circle(p + Vector2(-7, -h * 0.62), 12.0, cc.darkened(0.1))
		ci.draw_circle(p + Vector2(7, -h * 0.66), 12.0, cc)
		ci.draw_circle(p + Vector2(0, -h * 0.85), 13.0, cc.lightened(0.07))


static func figure(ci: CanvasItem, pos: Vector2, a: Actor, walk_phase: float, ring: Color = Color(0, 0, 0, 0)) -> void:
	var look := a.look
	var tunic := Color(look.get("tunic", _faction_color(a.faction)))
	var skin := Color(look.get("skin", "#d6a77a"))
	var hair := Color(look.get("hair", "#4a3020"))
	var trousers := Color(look.get("trousers", "#4b4136"))
	ci.draw_set_transform(pos, 0, Vector2(1, 0.45))
	if ring.a > 0:
		ci.draw_arc(Vector2.ZERO, 15.0, 0, TAU, 28, ring, 2.5)
	ci.draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if a.dead or a.unconscious:
		# Lying on the ground.
		var body := PackedVector2Array([pos + Vector2(-16, -2), pos + Vector2(10, -5), pos + Vector2(12, 2), pos + Vector2(-14, 4)])
		ci.draw_colored_polygon(body, tunic.darkened(0.3))
		ci.draw_circle(pos + Vector2(15, -2), 5.0, skin.darkened(0.3))
		if a.dead:
			ci.draw_circle(pos + Vector2(4, 5), 5.0, Color(0.4, 0.05, 0.03, 0.7))
		return
	var right := a.facing in [0, 1, 5]
	var sx := 1.0 if right else -1.0
	var swing := sin(walk_phase) * 4.0
	var bob := absf(sin(walk_phase)) * 1.5
	var p := pos - Vector2(0, bob)
	if a.knocked_down:
		p += Vector2(0, 8)
	# Legs
	ci.draw_line(p + Vector2(-3, -14), p + Vector2(-3 - swing, 0), trousers, 3.5)
	ci.draw_line(p + Vector2(3, -14), p + Vector2(3 + swing, 0), trousers, 3.5)
	# Tunic body
	var body := PackedVector2Array([p + Vector2(-7, -15), p + Vector2(7, -15), p + Vector2(6, -32), p + Vector2(-6, -32)])
	ci.draw_colored_polygon(body, tunic)
	if look.has("cloak"):
		var cloak := Color(look["cloak"])
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * sx, -32), p + Vector2(-9 * sx, -14), p + Vector2(-2 * sx, -16), p + Vector2(0, -32)]), cloak)
	ci.draw_line(p + Vector2(-7, -16), p + Vector2(7, -16), tunic.darkened(0.35), 2.0)
	# Arms and weapon
	var w := a.sheet.weapon_def()
	var hand := p + Vector2(8 * sx, -20 + swing * 0.3)
	ci.draw_line(p + Vector2(5 * sx, -30), hand, skin, 3.0)
	ci.draw_line(p + Vector2(-5 * sx, -30), p + Vector2(-8 * sx, -20 - swing * 0.3), skin, 3.0)
	match w.get("skill", ""):
		"spears":
			ci.draw_line(hand + Vector2(-2 * sx, 14), hand + Vector2(4 * sx, -30), Color("#8a6a40"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([hand + Vector2(4 * sx, -30), hand + Vector2(2 * sx, -38), hand + Vector2(6 * sx, -38)]), Color("#c8c8c0"))
		"blades":
			ci.draw_line(hand, hand + Vector2(10 * sx, -14), Color("#c8c8c0"), 2.5)
			ci.draw_line(hand + Vector2(-2 * sx, 2), hand + Vector2(3 * sx, -2), Color("#6a4a2a"), 3.0)
		"missiles":
			if w.get("ammo", "") == "arrow":
				ci.draw_arc(hand, 12.0, -1.2 if right else PI - 1.2, 1.2 if right else PI + 1.2, 10, Color("#7a5a30"), 2.0)
			elif w.get("thrown", false):
				ci.draw_line(hand + Vector2(-2 * sx, 6), hand + Vector2(3 * sx, -22), Color("#8a6a40"), 1.5)
		"brawling":
			if w.get("id", "") != "fists":
				ci.draw_line(hand, hand + Vector2(6 * sx, -12), Color("#6a4a2a"), 4.0)
	# Head
	ci.draw_circle(p + Vector2(0, -38), 6.0, skin)
	ci.draw_arc(p + Vector2(0, -39), 6.0, PI * 1.05, TAU * 0.98, 10, hair, 3.0)
	if a.sheet.equipped("helmet") != "":
		ci.draw_arc(p + Vector2(0, -39), 6.5, PI, TAU, 10, Color("#b08d4a"), 3.5)
	# Shield on the off-hand side
	var s := a.sheet.equipped("shield")
	if s != "":
		var sc := Color(look.get("shield", "#7a4a28"))
		if a.shield_fouled:
			sc = sc.darkened(0.4)
		var c := p + Vector2(-9 * sx, -22)
		var big := s != "small_shield"
		ci.draw_set_transform(c, 0, Vector2(0.55, 1.0) if big else Vector2(0.8, 0.8))
		ci.draw_circle(Vector2.ZERO, 11.0 if big else 8.0, sc)
		ci.draw_arc(Vector2.ZERO, 11.0 if big else 8.0, 0, TAU, 18, sc.darkened(0.4), 2.0)
		ci.draw_circle(Vector2.ZERO, 2.5, Color("#9a9a90"))
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if a.shield_fouled:
			ci.draw_line(c + Vector2(-2, 0), c + Vector2(14 * -sx, -14), Color("#8a6a40"), 2.0)


static func _faction_color(f: String) -> String:
	match f:
		"player":
			return "#3f6f8a"
		"brigodunon", "villager", "cadurci":
			return "#7a6a3a"
		"bandit":
			return "#5a3a3a"
		"roman":
			return "#9a2a22"
		"german":
			return "#4a5a3a"
		"beast":
			return "#5a5048"
	return "#6a6a5a"


## Wolves and boars: the same placeholder idea, on four legs.
static func beast(ci: CanvasItem, pos: Vector2, a: Actor, walk_phase: float, ring: Color = Color(0, 0, 0, 0)) -> void:
	var col := Color(a.look.get("tunic", "#6a6058"))
	ci.draw_set_transform(pos, 0, Vector2(1, 0.45))
	if ring.a > 0:
		ci.draw_arc(Vector2.ZERO, 16.0, 0, TAU, 28, ring, 2.5)
	ci.draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if a.dead:
		ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-14, -2), pos + Vector2(12, -6), pos + Vector2(14, 2), pos + Vector2(-12, 4)]), col.darkened(0.3))
		ci.draw_circle(pos + Vector2(4, 5), 5.0, Color(0.4, 0.05, 0.03, 0.7))
		return
	var sx := 1.0 if a.facing in [0, 1, 5] else -1.0
	var swing := sin(walk_phase) * 3.0
	var p := pos
	for lx in [-8.0, -4.0, 5.0, 9.0]:
		var s := swing if lx < 0 else -swing
		ci.draw_line(p + Vector2(lx * sx, -10), p + Vector2((lx + s) * sx, 0), col.darkened(0.3), 3.0)
	ci.draw_set_transform(p + Vector2(0, -14), 0, Vector2(1.0, 0.55))
	ci.draw_circle(Vector2.ZERO, 13.0, col)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_circle(p + Vector2(13 * sx, -18), 6.0, col.lightened(0.05))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(16 * sx, -20), p + Vector2(24 * sx, -16), p + Vector2(16 * sx, -14)]), col.darkened(0.1))
	ci.draw_circle(p + Vector2(15 * sx, -20), 1.5, Color(0.9, 0.7, 0.2))
