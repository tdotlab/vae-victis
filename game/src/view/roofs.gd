class_name Roofs
extends RefCounted
## Thatched hip roofs, built from each house's own outline.
##
## A house is a ring of wall cells (wall_wood, wall_stone, door) around cells
## the outside can't reach. Its roof is a hip roof over the wall line's
## bounding box, ridge along the long side, so every house gets a roof with no
## art work (all houses so far are rectangles; an odd plan gets its box). Each
## roof is one mesh, lit from the same sun as the sprites, and is depth-sorted
## as a single item at the house's southmost wall row.

const WALLS := {"wall_wood": true, "wall_stone": true, "door": true}
const EAVE := 24.0   # screen px: the eaves hang a little below the wall tops
const OVER := 16.0   # px the eaves reach past the wall line
const PITCH := 42.0  # degrees
const ZS := 0.785    # screen px per world px of height (cos of the camera's elevation)
const UV_SCALE := 1.0 / 128.0
# Toward the sun in (x, flat y, up); the sprites' sun shines from the
# southwest, high up.
const LIGHT := Vector3(-0.55, 0.6, 1.05)


## Returns [{cells, sort_y, rect, mesh}] for every roofed house on the map.
static func build(map: MapData) -> Array:
	var outside := {}
	var stack: Array[Vector2i] = []
	for c in map.cells:
		if WALLS.has(map.cells[c]):
			continue
		for n in Hex.neighbors(c):
			if not map.cells.has(n):
				outside[c] = true
				stack.append(c)
				break
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for n in Hex.neighbors(c):
			if map.cells.has(n) and not outside.has(n) and not WALLS.has(map.cells[n]):
				outside[n] = true
				stack.append(n)
	var seen := {}
	var out: Array = []
	for c in map.cells:
		if outside.has(c) or seen.has(c):
			continue
		var cells := {}
		var walls := {}
		var interior := 0
		var q: Array[Vector2i] = [c]
		seen[c] = true
		while not q.is_empty():
			var k: Vector2i = q.pop_back()
			cells[k] = true
			if WALLS.has(map.cells[k]):
				walls[k] = true
			else:
				interior += 1
			for n in Hex.neighbors(k):
				if map.cells.has(n) and not outside.has(n) and not seen.has(n):
					seen[n] = true
					q.append(n)
		if interior > 0:
			out.append(_house(cells, walls))
	return out


static func _house(cells: Dictionary, walls: Dictionary) -> Dictionary:
	# The eaves: the wall line's bounding box, pushed out by the overhang.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var sort_y := -INF
	for c in walls:
		var p := Hex.to_flat(c) * Paint.HEX
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		sort_y = maxf(sort_y, p.y * Hex.SQUASH)
	lo -= Vector2(OVER, OVER)
	hi += Vector2(OVER, OVER)
	var mid := (lo + hi) / 2.0
	var along_x := hi.x - lo.x >= hi.y - lo.y
	var hw := (hi.y - lo.y if along_x else hi.x - lo.x) / 2.0
	var top := hw * tan(deg_to_rad(PITCH))  # world px above the eaves
	var r0 := Vector2(lo.x + hw, mid.y) if along_x else Vector2(mid.x, lo.y + hw)
	var r1 := Vector2(hi.x - hw, mid.y) if along_x else Vector2(mid.x, hi.y - hw)
	var nw := Vector2(lo.x, lo.y)
	var ne := Vector2(hi.x, lo.y)
	var sw := Vector2(lo.x, hi.y)
	var se := Vector2(hi.x, hi.y)
	# Faces as [eave points..., ridge points...], back to front.
	var faces: Array = []
	if along_x:
		faces = [[nw, ne, r1, r0], [ne, se, r1], [sw, nw, r0], [se, sw, r0, r1]]
	else:
		faces = [[nw, ne, r0], [ne, se, r1, r0], [sw, nw, r0, r1], [se, sw, r1]]
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var light := LIGHT.normalized()
	for f in faces:
		var e0: Vector2 = f[0]
		var e1: Vector2 = f[1]
		var edge := (e1 - e0).normalized()
		var up := Vector2(-edge.y, edge.x)  # toward the ridge
		if up.dot(mid - e0) < 0:
			up = -up
		var nrm := Vector3(-up.x, -up.y, 1.0 / tan(deg_to_rad(PITCH))).normalized()
		var lit := 0.4 + 0.9 * maxf(nrm.dot(light), 0.0)
		var col := Color(lit, lit * 0.97, lit * 0.9)
		var pts: Array[Vector3] = []
		for p in f:
			var z := 0.0 if (p == e0 or p == e1) else top
			pts.append(Vector3(p.x, p.y, z))
		var tri_idx: Array = [[0, 1, 2]] if pts.size() == 3 else [[0, 1, 2], [0, 2, 3]]
		for t in tri_idx:
			for i in t:
				var q: Vector3 = pts[i]
				verts.append(_screen(q))
				cols.append(col)
				var pl := Vector2(q.x, q.y)
				uvs.append(Vector2(pl.dot(edge), -pl.dot(up) / cos(deg_to_rad(PITCH))) * UV_SCALE)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var eaves := PackedVector2Array()
	for p in [sw, se, ne]:
		eaves.append(_screen(Vector3(p.x, p.y, 0)))
	var ridge := PackedVector2Array([_screen(Vector3(r0.x, r0.y, top)), _screen(Vector3(r1.x, r1.y, top))])
	var rect := Rect2(eaves[0], Vector2.ZERO).expand(eaves[1]).expand(eaves[2]).expand(_screen(Vector3(nw.x, nw.y, 0)))
	rect = rect.expand(ridge[0]).expand(ridge[1])
	return {"cells": cells, "sort_y": sort_y + 0.2, "rect": rect, "mesh": mesh,
		"eaves": eaves, "ridge": ridge}


static func _screen(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y * Hex.SQUASH - EAVE - p.z * ZS)


## Draws a roof; fully hidden while the player is inside, see-through while the
## player stands behind it.
static func draw(ci: CanvasItem, roof: Dictionary, player_cell: Vector2i, player_pos: Vector2) -> void:
	if roof["cells"].has(player_cell):
		return
	var tex := Art.ground_texture("thatch")
	var mod := Color.WHITE
	var r: Rect2 = roof["rect"]
	if player_pos.y < roof["sort_y"] and r.grow(-6).has_point(player_pos - Vector2(0, 20)):
		mod.a = 0.35
	ci.draw_mesh(roof["mesh"], tex, Transform2D.IDENTITY, mod)
	ci.draw_polyline(roof["eaves"], Color(0.12, 0.09, 0.06, 0.55 * mod.a), 2.0)
	ci.draw_polyline(roof["ridge"], Color(0.85, 0.75, 0.55, 0.35 * mod.a), 2.0)
