extends TestCase


func test_distance() -> void:
	eq(Hex.distance(Vector2i(0, 0), Vector2i(0, 0)), 0)
	eq(Hex.distance(Vector2i(0, 0), Vector2i(3, 0)), 3)
	eq(Hex.distance(Vector2i(0, 0), Vector2i(2, -1)), 2)
	eq(Hex.distance(Vector2i(-2, 3), Vector2i(1, -1)), 4)


func test_neighbors_are_distance_one() -> void:
	var c := Vector2i(4, -2)
	var ns := Hex.neighbors(c)
	eq(ns.size(), 6)
	for n in ns:
		eq(Hex.distance(c, n), 1)


func test_offset_round_trip() -> void:
	for row in range(-3, 8):
		for col in range(-3, 8):
			var ax := Hex.offset_to_axial(col, row)
			eq(Hex.axial_to_offset(ax), Vector2i(col, row), "round trip")


func test_pixel_round_trip() -> void:
	for q in range(-5, 6):
		for r in range(-5, 6):
			var c := Vector2i(q, r)
			eq(Hex.from_pixel(Hex.to_pixel(c, 32.0), 32.0), c, "pixel round trip")


func test_line_endpoints_and_length() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(4, -2)
	var l := Hex.line(a, b)
	eq(l.size(), Hex.distance(a, b) + 1)
	eq(l[0], a)
	eq(l[l.size() - 1], b)
	for i in range(1, l.size()):
		eq(Hex.distance(l[i - 1], l[i]), 1, "line is contiguous")


func test_ring_and_spiral_sizes() -> void:
	eq(Hex.ring(Vector2i.ZERO, 0).size(), 1)
	eq(Hex.ring(Vector2i.ZERO, 2).size(), 12)
	eq(Hex.spiral(Vector2i.ZERO, 2).size(), 19)
	for c in Hex.ring(Vector2i(1, 1), 3):
		eq(Hex.distance(Vector2i(1, 1), c), 3)


func test_direction_to_matches_neighbors() -> void:
	for d in range(6):
		eq(Hex.direction_to(Vector2i.ZERO, Hex.DIRECTIONS[d]), d, "dir %d" % d)


func test_dice_is_deterministic() -> void:
	var a := Dice.new(42)
	var b := Dice.new(42)
	for i in range(50):
		eq(a.d100(), b.d100())
	var c := Dice.new(7)
	for i in range(200):
		var v := c.range_i(3, 6)
		check(v >= 3 and v <= 6, "range")
