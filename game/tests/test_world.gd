extends TestCase
## The travel map: data integrity, travel rules, encounters and the calendar.


func _w() -> WorldData:
	return WorldData.load_world()


func test_world_loads_with_full_rows() -> void:
	var w := _w()
	check(w.width > 10 and w.height > 10, "world has a size")
	for r in DB.world()["rows"]:
		eq(String(r).length(), w.width, "every row is the full width")


func test_locations_are_on_passable_cells_and_open_ones_have_maps() -> void:
	var w := _w()
	for l in w.locations:
		var c := w.location_cell(l)
		check(w.passable(c), "%s is on passable ground" % l["id"])
		if l.has("map"):
			check(not DB.map_def(l["map"]).is_empty(), "%s has map %s" % [l["id"], l["map"]])
		else:
			check(l.has("closed_text"), "%s has closed_text" % l["id"])


func test_encounters_reference_real_things() -> void:
	var w := _w()
	var terr: Dictionary = DB.world()["terrain"]
	for e in DB.world()["encounters"]:
		for a in e["actors"]:
			check(not DB.npc_template(a).is_empty(), "%s: npc %s exists" % [e["id"], a])
		for t in e.get("terrain", []):
			check(terr.has(t), "%s: terrain %s exists" % [e["id"], t])
	for t in terr:
		if terr[t].get("pass", true):
			check(not DB.map_def(terr[t]["encounter_map"]).is_empty(), "%s has an encounter map" % t)


func test_rivers_only_cross_at_fords() -> void:
	var w := _w()
	var home := w.location_cell(w.location("brigodunon"))
	var south := Vector2i(home.x, w.height - 1)
	var path := w.find_path(home, south, "summer", 0)
	check(not path.is_empty(), "the south bank is reachable")
	var crossed_ford := false
	for c in path:
		check(w.terrain_id(c) != "river", "never steps into a river")
		if w.terrain_id(c) == "ford":
			crossed_ford = true
	check(crossed_ford, "crossing the Oltis uses a ford")


func test_no_diagonal_slip_between_river_cells() -> void:
	var w := WorldData.from_def({
		"legend": {".": "plain", "~": "river"},
		"terrain": {"plain": {"hours": 4}, "river": {"pass": false}},
		"rows": ["..~", ".~.", "~.."]})
	check(not w.can_step(Vector2i(1, 0), Vector2i(2, 1)) or w.passable(Vector2i(2, 0)) or w.passable(Vector2i(1, 1)), "corner rule")
	check(w.find_path(Vector2i(0, 0), Vector2i(2, 2), "summer", 0).is_empty(), "a diagonal river line is watertight")


func test_terrain_season_and_skill_change_travel_time() -> void:
	var w := _w()
	var hills := Vector2i(-1, -1)
	for y in range(w.height):
		for x in range(w.width):
			if w.terrain_id(Vector2i(x, y)) == "mountains":
				hills = Vector2i(x, y)
	check(w.in_bounds(hills), "found a mountain cell")
	check(w.hours_for(hills, "winter", 20) > w.hours_for(hills, "summer", 20), "mountains are slower in winter")
	check(w.hours_for(hills, "summer", 90) < w.hours_for(hills, "summer", 10), "survival speeds travel")


func test_encounters_respect_terrain_and_day() -> void:
	var w := WorldData.from_def({
		"legend": {".": "plain", "f": "forest"},
		"terrain": {"plain": {"hours": 4}, "forest": {"hours": 6}},
		"rows": [".f"],
		"encounters": [
			{"id": "wolves", "terrain": ["forest"], "days": [0, 10], "actors": []},
			{"id": "romans", "terrain": [], "days": [26, 999], "actors": []}]})
	var d := Dice.new(7)
	for i in range(20):
		eq(w.pick_encounter(Vector2i(1, 0), 5, d).get("id", ""), "wolves", "only wolves in the woods early")
		eq(w.pick_encounter(Vector2i(0, 0), 5, d).get("id", ""), "", "nothing fits open country early")
		eq(w.pick_encounter(Vector2i(0, 0), 30, d).get("id", ""), "romans", "romans later")


func test_calendar_fires_once() -> void:
	var events := [{"id": "a", "day": 5}, {"id": "b", "day": 25}]
	var flags := {}
	eq(WorldData.due_events(events, 4, flags).size(), 0, "nothing before day 5")
	var due := WorldData.due_events(events, 30, flags)
	eq(due.size(), 2, "both due by day 30")
	flags["cal_a"] = 1
	eq(WorldData.due_events(events, 30, flags).size(), 1, "fired events don't repeat")


func test_real_calendar_is_ordered_and_valid() -> void:
	var last := 0
	for e in DB.calendar():
		check(e.has("id") and e.has("day"), "event has id and day")
		check(int(e["day"]) >= last, "events in day order")
		last = int(e["day"])
		if not e.get("silent", false):
			check(e.has("text") and e.has("title"), "%s has title and text" % e["id"])


func test_calendar_follows_caesar_not_a_240_day_year() -> void:
	var day := {}
	for e in DB.calendar():
		day[e["id"]] = int(e["day"])
	check(day["cevennes"] >= 44, "Caesar must reach Narbo before the Cevennes (about day 44)")
	check(day["avaricum_fallen"] > day["scorched_earth"] + 25, "the Avaricum ramp alone took 25 days")
	check(day["gergovia_victory"] > day["avaricum_fallen"] + 40, "Gergovia is weeks after Avaricum")
	check(day["noviodunum"] >= day["gergovia_victory"], "the Aedui turn after Gergovia")


func test_seasons_follow_the_calendar() -> void:
	var gs := GameState.new()
	var want := {1: "winter", 70: "winter", 71: "spring", 160: "spring", 161: "summer", 255: "summer", 256: "autumn"}
	for d in want:
		gs.minutes = (d - 1) * 1440 + 8 * 60
		eq(gs.season(), want[d], "season on day %d" % d)


func test_discovery() -> void:
	var w := _w()
	var c := w.location_cell(w.location("grotto"))
	var found := w.discover_near(c + Vector2i(1, 0), 1, ["brigodunon"])
	var ids: Array = []
	for l in found:
		ids.append(l["id"])
	check("grotto" in ids, "walking next to the Grotto finds it")
