extends Node
## Global game services (autoload "Game"): the current GameState, the message
## log, saving and loading, and requests to change screens. Screens listen to
## the signals; main.gd does the actual scene switching.

signal message(text: String, kind: String)
signal screen_requested(screen: String, args: Dictionary)
signal stats_changed

const SAVE_DIR := "user://saves"

var state: GameState


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
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if f == null:
		say("Could not save the game.", "bad")
		return false
	f.store_string(JSON.stringify(state.to_dict(), "\t"))
	f.close()
	return true


func has_save(slot: String = "quick") -> bool:
	return FileAccess.file_exists("%s/%s.json" % [SAVE_DIR, slot])


func load_game(slot: String = "quick") -> bool:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		say("That save is damaged.", "bad")
		return false
	state = GameState.from_dict(d)
	return true


# --- The historical clock ---------------------------------------------------

## Fires calendar events that are due: sets their flags and returns the ones
## with news to show. Screens decide how to show them.
func check_calendar() -> Array:
	if state == null:
		return []
	var shown: Array = []
	for e in WorldData.due_events(DB.calendar(), state.day(), state.flags):
		state.set_flag("cal_" + String(e["id"]))
		var fl: Dictionary = e.get("flags", {})
		for f in fl:
			state.set_flag(f, int(fl[f]))
		if not e.get("silent", false):
			shown.append(e)
	return shown
