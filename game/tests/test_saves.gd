extends TestCase
## Save slots: every slot round-trips the game, carries a summary for the
## windows, the newest save is the one Continue picks, and a load doesn't
## get overwritten by the autosave of the screen it opens.

const DIR := "user://test_saves"

var g: Node


func _setup() -> void:
	g = load("res://src/game/game.gd").new()
	g.save_dir = DIR
	for slot in g.save_slots():
		g.delete_save(slot)
	g.state = GameState.new()
	g.state.player = CharacterSheet.create("Ambiorix", {}, ["speech", "blades", "sneak"])
	g.state.minutes = 84 * 1440 + 10 * 60
	g.place = "Cenabum"


func _teardown() -> void:
	for slot in g.save_slots():
		g.delete_save(slot)
	g.free()


func test_a_slot_round_trips_with_its_summary() -> void:
	_setup()
	g.state.set_flag("lit_free")
	check(g.save_game("slot3"), "saved")
	var info: Dictionary = g.save_info("slot3")
	eq(info.get("name"), "Ambiorix")
	eq(int(info.get("day")), 85)
	eq(info.get("place"), "Cenabum")
	check(int(info.get("saved_at", 0)) > 0, "timestamped")
	g.state = null
	check(g.load_game("slot3"), "loaded")
	eq(g.state.flag("lit_free"), 1)
	eq(g.state.player.name, "Ambiorix")
	var text := SaveSlotsPanel.describe(info)
	check(text.find("Ambiorix, level 1") >= 0, "who: " + text)
	check(text.find("Cenabum") >= 0, "where: " + text)
	_teardown()


func test_empty_and_damaged_slots() -> void:
	_setup()
	eq(g.save_info("slot1"), {})
	eq(g.newest_save(), "", "nothing to continue")
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + "/slot2.json", FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(g.save_info("slot2").get("damaged", false), "damaged")
	eq(g.newest_save(), "", "a damaged save isn't continued")
	check(not g.load_game("slot2"), "won't load")
	_teardown()


func test_newest_save_wins() -> void:
	_setup()
	g.save_game("slot1")
	g.save_game("quick")
	# Same second; push the times apart by hand.
	_stamp("slot1", 1000)
	_stamp("quick", 2000)
	eq(g.newest_save(), "quick")
	_stamp("slot1", 3000)
	eq(g.newest_save(), "slot1")
	_teardown()


func test_a_load_skips_the_next_autosave() -> void:
	_setup()
	g.save_game("slot1")
	g.load_game("slot1")
	g.autosave()
	check(not g.has_save("auto"), "the screen a load opens doesn't autosave")
	g.autosave()
	check(g.has_save("auto"), "the next arrival does")
	_teardown()


func test_old_saves_without_a_summary() -> void:
	_setup()
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + "/quick.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(g.state.to_dict()))
	f.close()
	var info: Dictionary = g.save_info("quick")
	eq(info.get("name"), "Ambiorix")
	eq(int(info.get("day")), 85)
	check(g.load_game("quick"), "still loads")
	_teardown()


func test_slot_names() -> void:
	eq(SaveSlotsPanel.slot_name("slot4"), "Slot 4")
	eq(SaveSlotsPanel.slot_name("quick"), "Quicksave")
	eq(SaveSlotsPanel.slot_name("auto"), "Autosave")
	check(not Array(g_slots(false)).has("auto"), "you can't save to the autosave")


func g_slots(with_auto: bool) -> Array:
	return load("res://src/game/game.gd").save_slots(with_auto)


func _stamp(slot: String, t: int) -> void:
	var path := DIR + "/" + slot + ".json"
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d["meta"]["saved_at"] = t
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
