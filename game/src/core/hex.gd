class_name Hex
extends RefCounted
## Hex grid math. Cells use axial coordinates (q, r) stored in Vector2i,
## pointy-top layout. Map files use "odd-r" offset coordinates (col, row),
## which read naturally as ASCII rows; convert at the edges.
## Reference: Red Blob Games, "Hexagonal Grids".

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

## Vertical squash applied when projecting to the screen, for the isometric look.
const SQUASH := 0.62


static func neighbor(c: Vector2i, dir: int) -> Vector2i:
	return c + DIRECTIONS[posmod(dir, 6)]


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRECTIONS:
		out.append(c + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## Direction index (0..5) from a toward b, by nearest angle.
static func direction_to(a: Vector2i, b: Vector2i) -> int:
	if a == b:
		return 0
	var pa := to_flat(a)
	var pb := to_flat(b)
	var ang := atan2(-(pb.y - pa.y), pb.x - pa.x)  # screen y points down
	var idx := int(round(ang / (PI / 3.0)))
	return posmod(idx, 6)


static func offset_to_axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)


static func axial_to_offset(c: Vector2i) -> Vector2i:
	return Vector2i(c.x + (c.y - (c.y & 1)) / 2, c.y)


## Unsquashed pixel center for a hex of circumradius 1.
static func to_flat(c: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (c.x + c.y / 2.0), 1.5 * c.y)


## Screen position of a cell center for a hex of the given size.
static func to_pixel(c: Vector2i, size: float) -> Vector2:
	var f := to_flat(c) * size
	return Vector2(f.x, f.y * SQUASH)


static func from_pixel(p: Vector2, size: float) -> Vector2i:
	var x := p.x / size
	var y := p.y / SQUASH / size
	var q := (sqrt(3.0) / 3.0 * x - 1.0 / 3.0 * y)
	var r := (2.0 / 3.0 * y)
	return cube_round(q, r)


static func cube_round(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


## Cells on the straight line from a to b, both ends included.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n := distance(a, b)
	var out: Array[Vector2i] = []
	if n == 0:
		out.append(a)
		return out
	# Nudge to avoid ties landing exactly on cell edges.
	var aq := a.x + 1e-6
	var ar := a.y + 1e-6
	var bq := b.x + 1e-6
	var br := b.y + 1e-6
	for i in range(n + 1):
		var t := float(i) / n
		out.append(cube_round(lerpf(aq, bq, t), lerpf(ar, br, t)))
	return out


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius == 0:
		out.append(center)
		return out
	var c := center + DIRECTIONS[4] * radius
	for side in range(6):
		for _i in range(radius):
			out.append(c)
			c = c + DIRECTIONS[side]
	return out


static func spiral(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(radius + 1):
		out.append_array(ring(center, r))
	return out


## Corner points of a hex, squashed, around a screen-space center.
static func corners(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(size * cos(ang), size * sin(ang) * SQUASH))
	return pts
