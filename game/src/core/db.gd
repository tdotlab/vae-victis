class_name DB
extends RefCounted
## Read-only access to the game's data files under res://data/.
## Everything is loaded lazily and cached.

static var _cache: Dictionary = {}


static func load_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var full := path if path.begins_with("res://") else "res://data/" + path
	if not FileAccess.file_exists(full):
		push_error("DB: missing data file " + full)
		return null
	var text := FileAccess.get_file_as_string(full)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("DB: %s line %d: %s" % [full, json.get_error_line(), json.get_error_message()])
		return null
	_cache[path] = json.data
	return json.data


static func clear_cache() -> void:
	_cache.clear()


static func rules() -> Dictionary:
	return load_json("rules.json")


static func _index(file: String, key: String) -> Dictionary:
	var ck := file + "#" + key
	if _cache.has(ck):
		return _cache[ck]
	var out := {}
	var data = load_json(file)
	var list: Array = []
	if data is Dictionary:
		list = data.get(key, [])
	elif data is Array:
		list = data
	for e in list:
		out[e["id"]] = e
	_cache[ck] = out
	return out


static func skill_defs() -> Array:
	return rules()["skills"]


static func trait_def(id: String) -> Dictionary:
	return _index("rules.json", "traits").get(id, {})


static func perk_def(id: String) -> Dictionary:
	return _index("rules.json", "perks").get(id, {})


static func item(id: String) -> Dictionary:
	return items().get(id, {})


## An item's name for the middle of a sentence: "Roman order" stays capitalized
## past the first letter, "Bread" becomes "bread".
static func item_name_lc(id: String) -> String:
	return lc_first(str(item(id).get("name", id)))


static func lc_first(s: String) -> String:
	var first := s.get_slice(" ", 0)
	if first in story().get("proper_words", []):
		return s
	return s.left(1).to_lower() + s.substr(1)


static func items() -> Dictionary:
	return _index("items.json", "items")


static func terrain() -> Dictionary:
	return load_json("terrain.json")


static func npc_template(id: String) -> Dictionary:
	return _index("npcs.json", "npcs").get(id, {})


static func quest(id: String) -> Dictionary:
	return _index("quests.json", "quests").get(id, {})


static func quests() -> Dictionary:
	return _index("quests.json", "quests")


static func map_def(id: String) -> Dictionary:
	var d = load_json("maps/%s.json" % id)
	return d if d is Dictionary else {}


static func story() -> Dictionary:
	var d = load_json("story.json")
	return d if d is Dictionary else {}


static func text_file(path: String) -> String:
	var full := "res://data/" + path
	if not FileAccess.file_exists(full):
		push_error("DB: missing text file " + full)
		return ""
	return FileAccess.get_file_as_string(full)


static func world() -> Dictionary:
	var d = load_json("world.json")
	return d if d is Dictionary else {}


static func calendar() -> Array:
	var d = load_json("calendar.json")
	return d.get("events", []) if d is Dictionary else []
