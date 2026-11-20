extends Node
## Global game services (autoload "Game"): the current GameState, the message
## log, saving and loading, and requests to change screens. Screens listen to
## the signals; main.gd does the actual scene switching.

signal message(text: String, kind: String)
signal screen_requested(screen: String, args: Dictionary)
signal stats_changed

const SAVE_DIR := "user://saves"
## Slots, in the order the save and load windows list them. "auto" is written
## by the game on the way into a place; "quick" by F5; the rest by hand.
const MANUAL_SLOTS := 6

var state: GameState
## Where the player is, for save summaries. Screens set it when they open.
var place := ""
## Lets tests point saving somewhere harmless.
var save_dir := SAVE_DIR
## Set by a load so the screen it opens doesn't autosave over the autosave.
var skip_autosave := false


func new_game(sheet: CharacterSheet) -> void:
	state = GameState.new()
	state.player = sheet
	sheet.hp = sheet.max_hp()


## Sets up a fresh story after character creation and shows the intro.
func start_story() -> void:
	var st := DB.story()
	state.map_id = st.get("start_map", "sandbox")
	state.entry = st.get("start_entry", "start")
	state.minutes = (int(st.get("start_day", 1)) - 1) * 1440 + GameState.START_MINUTES
	for loc in st.get("known_locations", []):
		state.known_locations.append(loc)
	if st.has("world_start"):
		state.world_pos = Vector2i(int(st["world_start"][0]), int(st["world_start"][1]))
	for it in st.get("start_items", []):
		state.player.inventory.add(it[0], int(it[1]))
	for id in st.get("start_equip", []):
		state.player.equip(id)
	state.player.silver += int(st.get("start_silver", 0))
	if st.has("intro"):
		goto("text", {"title": st.get("intro_title", ""), "text": DB.text_file(st["intro"]), "next": "map", "button": "Begin"})
	else:
		goto("map", {})


func has_game() -> bool:
	return state != null


func say(text: String, kind: String = "info") -> void:
	if state:
		state.messages.append(text)
		if state.messages.size() > 200:
			state.messages = state.messages.slice(-200)
	message.emit(text, kind)


## Shows a how-to-play line from data/text/<id>.txt once per game.
func hint(id: String) -> void:
	if state == null or state.flag(id) != 0:
		return
	state.set_flag(id)
	say(DB.text_file("text/%s.txt" % id).strip_edges(), "hint")


func goto(screen: String, args: Dictionary = {}) -> void:
	screen_requested.emit(screen, args)


func give_xp(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var levels := state.player.add_xp(amount)
	if reason != "":
		say("%s: %d experience." % [reason, amount], "good")
	else:
		say("You gain %d experience." % amount, "good")
	if levels > 0:
		say("You are now level %d. You have skill points to spend." % state.player.level, "good")
		if state.player.perks_owed > 0:
			say("You may choose a new perk on the character screen.", "good")
	stats_changed.emit()


func change_honor(amount: int) -> void:
	state.honor += amount
	if amount > 0:
		say("Your honor grows.", "good")
	elif amount < 0:
		say("Your honor suffers.", "bad")
	stats_changed.emit()


func change_renown(amount: int) -> void:
	var a := amount
	if a > 0 and state.player.has_flag("bards_friend"):
		a = int(ceil(a * 1.5))
	state.renown += a
	stats_changed.emit()


func honor_word() -> String:
	var h := state.honor
	if h >= 60:
		return "Oath-true"
	if h >= 25:
		return "Honorable"
	if h > -25:
		return "Unremarkable"
	if h > -60:
		return "Faithless"
	return "Accursed"


func renown_word() -> String:
	var r := state.renown
	if r >= 80:
		return "Sung of across Gaul"
	if r >= 40:
		return "Known in many halls"
	if r >= 15:
		return "Talked about"
	return "Unknown"


# --- Saving ---------------------------------------------------------------

func save_game(slot: String = "quick") -> bool:
	if state == null:
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		say("Could not save the game.", "bad")
		return false
	var d := state.to_dict()
	d["meta"] = {
		"name": state.player.name, "level": state.player.level,
		"day": state.day(), "date": state.date_text(), "place": place,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	f.store_string(JSON.stringify(d, "	"))
	f.close()
	return true


## Saves to the autosave slot on the way into a place. Screens call it when
## they open; it does nothing right after a load, or with the player dead.
func autosave() -> void:
	if skip_autosave:
		skip_autosave = false
		return
	if state != null and state.player != null and state.player.hp > 0:
		save_game("auto")


func has_save(slot: String = "quick") -> bool:
	return FileAccess.file_exists(_save_path(slot))


func load_game(slot: String = "quick") -> bool:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var d = _read(path)
	if not d is Dictionary:
		say("That save is damaged.", "bad")
		return false
	state = GameState.from_dict(d)
	skip_autosave = true
	return true


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_save_path(slot))


static func save_slots(with_auto := true) -> Array:
	var out: Array = ["auto", "quick"] if with_auto else ["quick"]
	for i in range(1, MANUAL_SLOTS + 1):
		out.append("slot%d" % i)
	return out


## What a slot holds, for the save and load windows: name, level, day, date,
## place and saved_at (unix seconds). Empty if the slot is empty;
## {"damaged": true} if it can't be read. Old saves without a summary get
## one worked out from the state.
func save_info(slot: String) -> Dictionary:
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var d = _read(path)
	if not d is Dictionary or not d.has("player"):
		return {"slot": slot, "damaged": true, "saved_at": 0}
	var m: Dictionary = d.get("meta", {}).duplicate()
	if m.is_empty():
		var mins := int(d.get("minutes", 0))
		m = {"name": d["player"].get("name", ""), "level": int(d["player"].get("level", 1)),
			"day": mins / 1440 + 1, "date": "", "place": "",
			"saved_at": FileAccess.get_modified_time(path)}
	m["slot"] = slot
	return m


## The most recently written slot, or "" if there are no saves.
func newest_save() -> String:
	var best := ""
	var best_t := -1
	for slot in save_slots():
		var info := save_info(slot)
		if info.is_empty() or info.get("damaged", false):
			continue
		if int(info.get("saved_at", 0)) > best_t:
			best_t = int(info.get("saved_at", 0))
			best = slot
	return best


## A save file's contents, or null if it isn't JSON (quietly: a damaged save
## is shown as damaged, not raised as an engine error).
static func _read(path: String) -> Variant:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data


func _save_path(slot: String) -> String:
	return "%s/%s.json" % [save_dir, slot]


# --- The historical clock ---------------------------------------------------

## Fires calendar events that are due: sets their flags and returns the ones
## with news to show. Screens decide how to show them.
func check_calendar() -> Array:
	if state == null:
		return []
	var shown: Array = []
	for e in WorldData.due_events(DB.calendar(), state.day(), state.flags):
		state.set_flag("cal_" + String(e["id"]))
		# An event can be overtaken by the player ("unless_flag"): it passes
		# without news or effects.
		if e.has("unless_flag") and state.flag(String(e["unless_flag"])) != 0:
			continue
		# Or it only happens if things stand a certain way ("if", dialogue
		# conditions), and can move quests along ("fx", dialogue effects).
		if not Dialogue.all_true(state, e.get("if", [])):
			continue
		var fl: Dictionary = e.get("flags", {})
		for f in fl:
			state.set_flag(f, int(fl[f]))
		Dialogue.apply(state, e.get("fx", []))
		if not e.get("silent", false):
			shown.append(e)
	return shown
