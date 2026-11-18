class_name MapData
extends RefCounted
## A local map: a hex grid of terrain plus named marks placed in the ASCII
## layout. Built from a map file in data/maps/. Pure data, no rendering.
##
## Map file shape (JSON):
##   "legend": char -> terrain id, or {"terrain": id, "mark": name}
##   "rows":   strings; each character is one hex in odd-r offset layout
## Marks let the file pin NPCs, containers and exits to places on the drawing.

var id := ""
var name := ""
var width := 0
var height := 0
var cells: Dictionary = {}  # Vector2i (axial) -> terrain id
var marks: Dictionary = {}  # mark name -> Array[Vector2i]
var def: Dictionary = {}


static func from_def(d: Dictionary) -> MapData:
	var m := MapData.new()
	m.def = d
	m.id = d.get("id", "")
	m.name = d.get("name", m.id)
	var legend: Dictionary = d.get("legend", {})
	var default_terrain: String = d.get("default", "grass")
	var rows: Array = d.get("rows", [])
	m.height = rows.size()
	for row in range(rows.size()):
		var line: String = rows[row]
		m.width = maxi(m.width, line.length())
		for col in range(line.length()):
			var ch := line[col]
			if ch == " ":
				continue  # outside the map
			var entry = legend.get(ch, default_terrain)
			var c := Hex.offset_to_axial(col, row)
			if entry is Dictionary:
				m.cells[c] = entry.get("terrain", default_terrain)
				var mark: String = entry.get("mark", "")
				if mark != "":
					if not m.marks.has(mark):
						m.marks[mark] = []
					m.marks[mark].append(c)
			else:
				m.cells[c] = str(entry)
	# Unknown terrain is a data bug; fail loudly but keep going.
	var tdefs := DB.terrain()
	for c in m.cells:
		if not tdefs.has(m.cells[c]):
			push_error("Map %s: unknown terrain '%s'" % [m.id, m.cells[c]])
			m.cells[c] = default_terrain
	return m


static func load_map(map_id: String) -> MapData:
	return from_def(DB.map_def(map_id))


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


func terrain_at(c: Vector2i) -> Dictionary:
	return DB.terrain().get(cells.get(c, ""), {})


func is_walkable(c: Vector2i) -> bool:
	return cells.has(c) and terrain_at(c).get("walk", false)


func move_cost(c: Vector2i) -> int:
	return int(terrain_at(c).get("cost", 1))


func blocks_sight(c: Vector2i) -> bool:
	if not cells.has(c):
		return true
	return not terrain_at(c).get("sight", true)


## True if nothing on the straight line between a and b blocks sight.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var l := Hex.line(a, b)
	for i in range(1, l.size() - 1):
		if blocks_sight(l[i]):
			return false
	return true


func mark(name_: String) -> Vector2i:
	var arr: Array = marks.get(name_, [])
	if arr.is_empty():
		push_error("Map %s: no mark '%s'" % [id, name_])
		return Vector2i(-9999, -9999)
	return arr[0]


func mark_cells(name_: String) -> Array:
	return marks.get(name_, [])


func has_mark(name_: String) -> bool:
	return marks.has(name_)


## Nearest walkable, unblocked cell to c (c itself if fine).
func nearest_free(c: Vector2i, blocked: Dictionary) -> Vector2i:
	for r in range(0, 8):
		for n in Hex.ring(c, r):
			if is_walkable(n) and not blocked.has(n):
				return n
	return c


func bounds_px(size: float) -> Rect2:
	var r := Rect2()
	var first := true
	for c in cells:
		var p := Hex.to_pixel(c, size)
		if first:
			r = Rect2(p, Vector2.ZERO)
			first = false
		else:
			r = r.expand(p)
	return r.grow(size * 2.0)
