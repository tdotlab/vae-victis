extends TestCase


func _map() -> MapData:
	return MapData.from_def({
		"id": "t",
		"legend": {".": "grass", "#": "wall_stone", "~": "water", "m": "mud", "@": {"terrain": "grass", "mark": "start"}, "X": {"terrain": "grass", "mark": "goal"}},
		"rows": [
			"@.....#....",
			"......#....",
			"......#..X.",
			"...........",
			"~~~~~~.....",
		],
	})


func test_marks() -> void:
	var m := _map()
	eq(m.mark("start"), Hex.offset_to_axial(0, 0))
	eq(m.mark("goal"), Hex.offset_to_axial(9, 2))
	check(m.is_walkable(m.mark("start")))
	check(not m.is_walkable(Hex.offset_to_axial(6, 0)))
	check(not m.is_walkable(Hex.offset_to_axial(0, 4)))


func test_path_goes_around_wall() -> void:
	var m := _map()
	var p := Pathfinder.find_path(m, m.mark("start"), m.mark("goal"))
	check(p.size() > 0, "path found")
	eq(p[p.size() - 1], m.mark("goal"))
	for c in p:
		check(m.is_walkable(c), "path cell walkable")
	# The wall forces a detour longer than the straight distance.
	check(p.size() > Hex.distance(m.mark("start"), m.mark("goal")))


func test_path_respects_blocked_and_adjacent() -> void:
	var m := _map()
	var goal := m.mark("goal")
	var p := Pathfinder.find_path(m, m.mark("start"), goal, {goal: true})
	eq(p.size(), 0, "blocked goal unreachable")
	var p2 := Pathfinder.find_path(m, m.mark("start"), goal, {goal: true}, 400, true)
	check(p2.size() > 0)
	eq(Hex.distance(p2[p2.size() - 1], goal), 1)


func test_line_of_sight() -> void:
	var m := _map()
	var a := Hex.offset_to_axial(4, 1)
	var b := Hex.offset_to_axial(8, 1)
	check(not m.has_line_of_sight(a, b), "wall blocks")
	check(m.has_line_of_sight(Hex.offset_to_axial(0, 3), Hex.offset_to_axial(9, 3)), "open row")


func test_real_maps_load() -> void:
	var dir := DirAccess.open("res://data/maps")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var m := MapData.load_map(f.get_basename())
		check(m.cells.size() > 0, f + " has cells")
		check(m.has_mark("start"), f + " has a start mark")
