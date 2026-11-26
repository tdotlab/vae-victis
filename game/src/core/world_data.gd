class_name WorldData
extends RefCounted
## The travel map of Gaul: a square grid of terrain cells, the locations on
## it, travel times, encounter tables and the historical calendar. Pure
## rules, no rendering. Loaded from data/world.json and data/calendar.json.
##
## world.json shape:
##   "legend":    char -> terrain id (see "terrain")
##   "terrain":   id -> {name, hours, color, pass, encounter}
##                hours = hours to cross one cell on foot in good weather;
##                pass false = can't be entered (deep rivers)
##   "seasons":   season -> {terrain id or "*": multiplier}
##   "rows":      strings, one char per cell
##   "locations": [{id, name, cell [x, y], map, entry, desc, size, closed_text,
##                  open_flag, shut_text, map_by_flag [{flag, map, entry}],
##                  closed_by_flag [{flag, text}]}]
##                map_by_flag: the first entry whose flag is set replaces the
##                map and/or the entry mark (a place that changes on the clock)
##   "encounters":[{id, weight, terrain [...], days [from, to], map, actors [...], text}]

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var def: Dictionary = {}
var width := 0
var height := 0
var cells: PackedStringArray = []   # terrain id per cell, row-major
var locations: Array = []


static func from_def(d: Dictionary) -> WorldData:
	var w := WorldData.new()
	w.def = d
	var rows: Array = d.get("rows", [])
	var legend: Dictionary = d.get("legend", {})
	w.height = rows.size()
	for r in rows:
		w.width = maxi(w.width, String(r).length())
	w.cells.resize(w.width * w.height)
	for y in range(w.height):
		var line: String = rows[y]
		for x in range(w.width):
			var ch := line[x] if x < line.length() else "."
			var t: String = legend.get(ch, "")
			if t == "":
				push_error("World map: unknown char '%s' at %d,%d" % [ch, x, y])
				t = String(legend.values()[0])
			w.cells[y * w.width + x] = t
	w.locations = d.get("locations", [])
	return w


static func load_world() -> WorldData:
	return from_def(DB.world())


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func terrain_id(c: Vector2i) -> String:
	if not in_bounds(c):
		return ""
	return cells[c.y * width + c.x]


func terrain(c: Vector2i) -> Dictionary:
	return def.get("terrain", {}).get(terrain_id(c), {})


func passable(c: Vector2i) -> bool:
	return in_bounds(c) and terrain(c).get("pass", true)


## Hours to cross cell c on foot, given the season and the traveler's
## Survival skill (0-100+). Good woodcraft saves up to a third of the time.
func hours_for(c: Vector2i, season: String, survival: int) -> float:
	var base := float(terrain(c).get("hours", 4))
	var mults: Dictionary = def.get("seasons", {}).get(season, {})
	var m := float(mults.get(terrain_id(c), mults.get("*", 1.0)))
	var skill_factor := clampf(1.1 - survival / 300.0, 0.67, 1.1)
	return base * m * skill_factor


## No slipping diagonally between two blocked cells (keeps rivers watertight).
func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not passable(b):
		return false
	var d := b - a
	if d.x != 0 and d.y != 0:
		if not passable(Vector2i(a.x + d.x, a.y)) or not passable(Vector2i(a.x, a.y + d.y)):
			return false
	return true


## Cheapest route in hours from a to b (excluding a). Empty if unreachable.
func find_path(a: Vector2i, b: Vector2i, season: String, survival: int) -> Array:
	if a == b or not passable(b):
		return []
	var open := {a: 0.0}
	var came := {}
	var cost := {a: 0.0}
	var closed := {}
	while not open.is_empty():
		var cur: Vector2i = open.keys()[0]
		var best := INF
		for k in open:
			var f: float = open[k]
			if f < best:
				best = f
				cur = k
		if cur == b:
			var path: Array = []
			var n := b
			while n != a:
				path.push_front(n)
				n = came[n]
			return path
		open.erase(cur)
		closed[cur] = true
		for dvec in DIRS:
			var nb: Vector2i = cur + dvec
			if closed.has(nb) or not can_step(cur, nb):
				continue
			var step := hours_for(nb, season, survival)
			if dvec.x != 0 and dvec.y != 0:
				step *= 1.4
			var g: float = cost[cur] + step
			if g < float(cost.get(nb, INF)):
				cost[nb] = g
				came[nb] = cur
				# Heuristic: straight-line distance at the cheapest terrain.
				open[nb] = g + Vector2(nb - b).length() * 3.0
	return []


func path_hours(from: Vector2i, path: Array, season: String, survival: int) -> float:
	var h := 0.0
	var prev := from
	for c in path:
		var step := hours_for(c, season, survival)
		if c.x != prev.x and c.y != prev.y:
			step *= 1.4
		h += step
		prev = c
	return h


func location(id: String) -> Dictionary:
	for l in locations:
		if l["id"] == id:
			return l
	return {}


func location_cell(l: Dictionary) -> Vector2i:
	return Vector2i(int(l["cell"][0]), int(l["cell"][1]))


## The map and entry mark a location opens on, given the game's flags.
static func map_entry(l: Dictionary, flags: Dictionary) -> Dictionary:
	var out := {"map": l.get("map", ""), "entry": l.get("entry", "start")}
	for v in l.get("map_by_flag", []):
		if int(flags.get(String(v["flag"]), 0)) != 0:
			out["map"] = v.get("map", out["map"])
			out["entry"] = v.get("entry", out["entry"])
			break
	return out


## The world cell of the location a local map belongs to (any of its faces),
## or (-1, -1) for maps that belong to none (road encounters, the sandbox).
func cell_for_map(map_id: String) -> Vector2i:
	for l in locations:
		if l.get("map", "") == map_id:
			return location_cell(l)
		for v in l.get("map_by_flag", []):
			if v.get("map", "") == map_id:
				return location_cell(l)
	return Vector2i(-1, -1)


func location_at(c: Vector2i) -> Dictionary:
	for l in locations:
		if location_cell(l) == c:
			return l
	return {}


## Locations within `radius` cells of c that the player doesn't know yet.
func discover_near(c: Vector2i, radius: int, known: Array) -> Array:
	var found: Array = []
	for l in locations:
		if l["id"] in known or l.get("hidden", false):
			continue
		var lc := location_cell(l)
		if maxi(absi(lc.x - c.x), absi(lc.y - c.y)) <= radius:
			found.append(l)
	return found


## Per-cell chance (0-100) of running into something while crossing c.
func encounter_chance(c: Vector2i, night: bool) -> int:
	var base := int(terrain(c).get("encounter", 6))
	if night:
		base += 3
	if not location_at(c).is_empty():
		return 0
	return base


## A scripted encounter that is due: one marked "forced" whose "if"
## conditions hold and that hasn't happened yet (fired is recorded as the flag
## enc_<id>). It finds the player on the next stretch of road, wherever they
## are, as the runner from home does. {} if none is due.
static func forced_encounter(encounters: Array, gs: GameState) -> Dictionary:
	for e in encounters:
		if not e.get("forced", false) or gs.flag("enc_" + String(e["id"])) != 0:
			continue
		var days: Array = e.get("days", [0, 9999])
		if gs.day() < int(days[0]) or gs.day() > int(days[1]):
			continue
		if Dialogue.all_true(gs, e.get("if", [])):
			return e
	return {}


## Picks an encounter that fits the terrain and the day, or {} if none does.
## Forced (scripted) encounters never come up at random.
func pick_encounter(c: Vector2i, day: int, dice: Dice) -> Dictionary:
	var t := terrain_id(c)
	var pool: Array = []
	var total := 0
	for e in def.get("encounters", []):
		if e.get("forced", false):
			continue
		var terr: Array = e.get("terrain", [])
		if not terr.is_empty() and not t in terr:
			continue
		var days: Array = e.get("days", [0, 9999])
		if day < int(days[0]) or day > int(days[1]):
			continue
		pool.append(e)
		total += int(e.get("weight", 10))
	if total <= 0:
		return {}
	var r := dice.range_i(1, total)
	for e in pool:
		r -= int(e.get("weight", 10))
		if r <= 0:
			return e
	return pool[-1]


## Calendar events (from data/calendar.json) that are due by `day` and not
## yet fired. Firing is recorded in flags as "cal_<id>".
static func due_events(events: Array, day: int, flags: Dictionary) -> Array:
	var out: Array = []
	for e in events:
		if int(e.get("day", 0)) <= day and int(flags.get("cal_" + String(e["id"]), 0)) == 0:
			out.append(e)
	return out
