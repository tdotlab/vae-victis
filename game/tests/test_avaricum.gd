extends TestCase
## Avaricum's quest routes, walked through the real dialogue files: the
## Aeduan's list (main line), the countermine, Nertomara's children, the
## sentry on the ruins, the girl in the granary, and the pen.

class FixedDice extends Dice:
	var result := true
	func chance(_percent: float) -> bool:
		return result


var gs: GameState
var dlg: Dictionary
var page: Dictionary
var actions: Array = []


func _new_game(d := 100) -> void:
	gs = GameState.new()
	gs.player = CharacterSheet.create("Ambiorix", {}, ["speech", "blades", "sneak"])
	gs.dice = FixedDice.new()
	_day(d, 10)
	actions = []


func _day(d: int, h: int) -> void:
	gs.minutes = (d - 1) * 1440 + h * 60


func _siege() -> void:
	gs.set_flag("scorched_earth", 1)
	gs.set_flag("avaricum_siege", 1)
	_day(115, 10)


func _fallen() -> void:
	_siege()
	gs.set_flag("avaricum_fallen", 1)
	_day(140, 10)


func _talk(id: String) -> void:
	dlg = Dialogue.load_dialogue(id)
	check(not dlg.is_empty(), "dialogue %s loads" % id)
	page = Dialogue.enter(gs, dlg, dlg["entry"])
	actions += page["actions"]


func _has(sub: String) -> bool:
	for ch in page["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			return true
	return false


func _pick(sub: String, win := true) -> void:
	(gs.dice as FixedDice).result = win
	for ch in page["choices"]:
		if str(ch["text"]).find(sub) >= 0:
			page = Dialogue.choose(gs, dlg, page["node"], ch["index"])
			actions += page["actions"]
			return
	var texts: Array = page["choices"].map(func(c): return c["text"])
	fail("no choice containing '%s' at %s; have %s" % [sub, page["node"], texts])
	page = {"node": "END", "choices": [], "end": true, "actions": [], "text": ""}


func _acted(prefix: String) -> bool:
	for a in actions:
		if str(a).begins_with(prefix):
			return true
	return false


func _night() -> void:
	gs.minutes = gs.minutes - gs.minutes % 1440 + 22 * 60


func _letter_read() -> bool:
	return gs.flag("letter_read") == 1 and gs.known_locations.has("noviodunum")


# --- The world entry ----------------------------------------------------------

func test_avaricum_entry_follows_the_calendar() -> void:
	var loc: Dictionary = {}
	for l in DB.world()["locations"]:
		if l["id"] == "avaricum":
			loc = l
	check(not loc.is_empty(), "avaricum is on the world map")
	var e := WorldData.map_entry(loc, {})
	eq(e["map"], "avaricum")
	eq(e["entry"], "world")
	e = WorldData.map_entry(loc, {"scorched_earth": 1, "avaricum_siege": 1})
	eq(e["map"], "avaricum")
	eq(e["entry"], "marsh")
	e = WorldData.map_entry(loc, {"avaricum_siege": 1, "avaricum_fallen": 1})
	eq(e["map"], "avaricum_ruins")
	eq(e["entry"], "world")


func test_the_calendar_has_the_siege() -> void:
	var days := {}
	for ev in DB.load_json("calendar.json")["events"]:
		days[ev["id"]] = int(ev["day"])
	check(days["scorched_earth"] < days["avaricum_siege"], "siege after the burning")
	check(days["avaricum_siege"] < days["terrace_fire"], "terrace fire during the siege")
	check(days["breakout_stopped"] < days["avaricum_fallen"], "breakout before the fall")
	eq(DB.map_def("avaricum")["deadline"]["day"], days["avaricum_fallen"])


# --- The Empty Line (main) ----------------------------------------------------

func test_rumor_then_unmask_by_lore_then_buy_and_read() -> void:
	_new_game()
	_talk("ava_market")
	_pick("gossip")
	eq(gs.quest_stage("factor"), "rumor")
	gs.player.skill_bonus["lore"] = 100
	_talk("ava_epomeduos")
	_pick("buy it from them")
	eq(gs.quest_stage("factor"), "found")
	check(gs.known_locations.has("noviodunum"), "he gives away Noviodunum")
	gs.player.silver = 200
	_pick("What do you want")
	_pick("Pay him")
	eq(gs.quest_status("factor"), "done")
	eq(gs.quest_stage("factor"), "done_bought")
	eq(gs.player.silver, 50)
	check(gs.player.inventory.count("aeduan_letter") == 1, "has the letter")
	gs.player.attrs["WIT"] = 8
	_talk("item_letter")
	_pick("puzzle out")
	check(_letter_read(), "letter read")
	_talk("ava_epomeduos")
	eq(page["node"], "paid")


func test_unmask_with_the_tablets_and_turn_him() -> void:
	_new_game()
	gs.set_flag("tablets_read", 1)
	gs.player.attrs["PRE"] = 8
	_talk("ava_epomeduos")
	_pick("Dannotalos sends his regards")
	eq(gs.quest_stage("factor"), "found")
	_pick("as your partner")
	eq(gs.quest_stage("factor"), "done_turned")
	eq(gs.flag("factor_turned"), 1)
	check(gs.player.inventory.count("aeduan_letter") == 1, "has the letter")


func test_steal_the_list_and_expose_him() -> void:
	_new_game()
	gs.player.inventory.add("factor_list", 1)
	_talk("item_factor_list")
	eq(gs.quest_stage("factor"), "rumor")
	_talk("ava_epomeduos")
	_pick("The one with the prices")
	eq(gs.quest_stage("factor"), "found")
	_pick("Not now")
	_talk("ava_senodonnos")
	_pick("tablet of names")
	eq(gs.quest_stage("factor"), "done_exposed")
	eq(gs.flag("factor_gone"), 1)
	eq(gs.player.inventory.count("factor_list"), 0)
	eq(gs.player.inventory.count("aeduan_letter"), 1)
	eq(gs.get_standing("bituriges"), 15)
	_pick("Can you read this")
	check(_letter_read(), "Senodonnos reads the letter")


func test_expose_by_speech_closes_in_the_siege() -> void:
	_new_game()
	gs.set_quest("factor", "found")
	gs.player.skill_bonus["speech"] = 100
	_talk("ava_senodonnos")
	check(_has("slave market"), "speech exposure offered before the siege")
	_siege()
	_talk("ava_senodonnos")
	check(not _has("slave market"), "no exposure once he has gone")
	_pick("The Aeduan grain buyer")
	check(str(page["text"]).find("south gate") >= 0, "he left before the Romans came")


func test_kill_him_and_read_the_letter() -> void:
	_new_game()
	gs.set_flag("factor_unmasked", 1)
	gs.set_quest("factor", "found")
	_talk("ava_epomeduos")
	_pick("About your list")
	_pick("explain your list to the gods")
	check(_acted("fight"), "a fight starts")
	eq(String(DB.npc_template("epomeduos")["kill_flag"]), "factor_gone")
	gs.set_flag("factor_gone", 1)  # what the kill does
	gs.set_quest("factor", "rumor")
	gs.player.inventory.add("aeduan_letter", 1)
	gs.player.skill_bonus["lore"] = 100
	_talk("item_letter")
	_pick("You know the letters")
	eq(gs.quest_stage("factor"), "done_killed")


func test_haggle_for_the_letter_in_the_ruins() -> void:
	_new_game()
	_fallen()
	_talk("ava_epomeduos")
	eq(gs.quest_stage("factor"), "found")
	gs.player.skill_bonus["barter"] = 100
	gs.player.silver = 100
	_pick("What do you want")
	_pick("Ninety")
	eq(gs.quest_stage("factor"), "done_bought")
	eq(gs.player.silver, 10)


# --- Under the Terrace --------------------------------------------------------

func _mine() -> void:
	_new_game()
	_siege()
	_talk("ava_andecamulos")
	eq(gs.quest_stage("countermine"), "start")


func _rewarded() -> void:
	eq(gs.quest_status("countermine"), "done")
	eq(gs.player.inventory.count("biturigan_sword"), 1)
	eq(gs.flag("miner_friend"), 1)


func test_countermine_by_digging() -> void:
	_mine()
	gs.player.attrs["STR"] = 7
	_talk("ava_andecamulos")
	var t := gs.minutes
	_pick("Give me a shovel")
	eq(gs.quest_stage("countermine"), "done_dug")
	check(gs.minutes - t >= 600, "digging takes the night")
	_rewarded()


func test_countermine_by_listening_and_by_pitch() -> void:
	_mine()
	gs.player.attrs["PER"] = 8
	_talk("ava_andecamulos")
	_pick("listen at the face")
	eq(gs.quest_stage("countermine"), "done_heard")
	_rewarded()
	_mine()
	gs.player.inventory.add("pitch", 3)
	_talk("ava_andecamulos")
	_pick("Three pots of pitch")
	eq(gs.quest_stage("countermine"), "done_pitch")
	eq(gs.player.inventory.count("pitch"), 0)
	_rewarded()


func test_countermine_sortie_fails_then_succeeds() -> void:
	_mine()
	check(not _has("Over the wall"), "no sortie by day")
	_night()
	_talk("ava_andecamulos")
	_pick("Over the wall")
	var t := gs.minutes
	_pick("Go with them", false)
	check(gs.minutes - t >= 1440, "a failed sortie costs a day")
	eq(gs.quest_status("countermine"), "active")
	_night()
	_talk("ava_andecamulos")
	_pick("Over the wall")
	_pick("Go with them", true)
	eq(gs.quest_stage("countermine"), "done_fired")
	_rewarded()


# --- The Most Beautiful City --------------------------------------------------

func test_nertomara_waits_for_the_burning() -> void:
	_new_game(100)
	_talk("ava_nertomara")
	eq(gs.quest_status("nertomara"), "")
	gs.set_flag("scorched_earth", 1)
	_day(106, 10)
	_talk("ava_nertomara")
	eq(gs.quest_stage("nertomara"), "start")
	gs.player.skill_bonus["speech"] = 100
	_pick("while the road is open")
	eq(gs.quest_stage("nertomara"), "done_early")
	eq(gs.player.inventory.count("gold_torque"), 1)
	check(gs.titles.size() == 1, "a title")


func test_nertomara_early_route_closes_in_the_siege() -> void:
	_new_game()
	_siege()
	gs.player.skill_bonus["speech"] = 100
	_talk("ava_nertomara")
	check(not _has("while the road is open"), "no early route once the siege starts")
	_pick("How do I get them out")


func test_nertomara_by_boat_fails_and_closes() -> void:
	_new_game()
	_siege()
	_talk("ava_nertomara")
	gs.player.silver = 50
	_talk("ava_vindos")
	_pick("two children through the marsh")
	_pick("Pay him")
	eq(gs.quest_stage("nertomara"), "boat_paid")
	_talk("ava_vindos")
	eq(page["node"], "paid_day")
	_night()
	_talk("ava_vindos")
	_pick("keep low", false)
	eq(gs.flag("boat_lost"), 1)
	eq(gs.quest_status("nertomara"), "active")
	_talk("ava_vindos")
	check(not _has("two children"), "the boat route is closed")


func test_nertomara_by_boat_succeeds() -> void:
	_new_game()
	_siege()
	_talk("ava_nertomara")
	gs.player.silver = 50
	_talk("ava_vindos")
	_pick("two children through the marsh")
	_pick("Pay him")
	_night()
	_talk("ava_vindos")
	_pick("keep low", true)
	eq(gs.quest_stage("nertomara"), "done_boat")
	_talk("ava_nertomara")
	eq(page["node"], "thanks")
	eq(gs.player.inventory.count("gold_torque"), 1)


func test_nertomara_through_the_drift_and_with_the_runners() -> void:
	_new_game()
	_siege()
	_talk("ava_nertomara")
	gs.set_flag("miner_friend", 1)
	gs.set_quest("countermine", "done_dug", "done")
	_talk("ava_andecamulos")
	_pick("under the north wall")
	eq(gs.quest_stage("nertomara"), "done_adit")
	_new_game()
	_siege()
	_talk("ava_nertomara")
	gs.renown = 12
	_talk("ava_picked")
	_pick("You know who I am")
	eq(gs.quest_stage("nertomara"), "done_runners")


func test_the_fall_fails_what_is_unfinished() -> void:
	_new_game()
	_siege()
	_talk("ava_nertomara")
	_talk("ava_andecamulos")
	_talk("ava_fall")
	eq(gs.quest_status("nertomara"), "failed")
	eq(gs.quest_status("countermine"), "failed")
	eq(gs.flag("fall_survived"), 1)
	_pick("Go on")
	check(_acted("travel world"), "the fall puts you on the road")


func test_the_empty_house_fails_nertomara() -> void:
	_new_game()
	_siege()
	_talk("ava_nertomara")
	_fallen()
	_talk("ava_nert_house")
	eq(gs.quest_status("nertomara"), "failed")
	gs.set_quest("nertomara", "done_boat", "done")
	_talk("ava_nert_house")
	eq(page["node"], "saved")
	eq(gs.quest_status("nertomara"), "done")


# --- The ruins ----------------------------------------------------------------

func test_sentry_routes() -> void:
	_new_game()
	_fallen()
	gs.set_quest("countermine", "start")
	gs.player.skill_bonus["latin"] = 100
	_talk("ava_sentry")
	eq(gs.quest_status("countermine"), "failed")
	_pick("Sutler")
	eq(gs.flag("ruins_passed"), 1)
	_talk("ava_sentry")
	eq(page["node"], "passed")

	_new_game()
	_fallen()
	gs.player.inventory.add("aeduan_letter", 1)
	_talk("ava_sentry")
	_pick("horse seal")
	eq(gs.flag("ruins_passed"), 1)

	_new_game()
	_fallen()
	gs.player.silver = 25
	_talk("ava_sentry")
	_pick("twenty silver")
	eq(gs.flag("ruins_passed"), 1)
	eq(gs.player.silver, 5)

	_new_game()
	_fallen()
	_talk("ava_sentry")
	_pick("go back")
	check(_acted("travel world"), "turning back leaves")
	eq(gs.flag("ruins_passed"), 0)

	_new_game()
	_fallen()
	_talk("ava_sentry")
	_pick("through you")
	check(_acted("fight_all rome_camp"), "fighting the sentry fights the camp")


func test_survivor_sneak_fails_then_latin_gets_her_out() -> void:
	_new_game()
	_fallen()
	_talk("ava_survivor")
	eq(gs.quest_stage("survivor"), "start")
	check(not _has("do exactly what I do"), "no sneaking by day")
	_night()
	_talk("ava_survivor")
	_pick("do exactly what I do", false)
	eq(gs.flag("survivor_seen"), 1)
	_talk("ava_survivor")
	check(not _has("do exactly what I do"), "she won't try that again")
	gs.player.skill_bonus["latin"] = 100
	_talk("ava_survivor")
	_pick("you're mine")
	eq(gs.quest_stage("survivor"), "done_latin")
	eq(gs.flag("survivor_out"), 1)


func test_survivor_other_routes() -> void:
	_new_game()
	_fallen()
	_talk("ava_survivor")
	_night()
	_talk("ava_survivor")
	_pick("do exactly what I do", true)
	eq(gs.quest_stage("survivor"), "done_sneak")

	_new_game()
	_fallen()
	_talk("ava_survivor")
	gs.player.silver = 30
	_talk("ava_legionary")
	_pick("last granary")
	eq(gs.quest_stage("survivor"), "done_paid")
	check(_acted("leave_all survivor"), "she goes")

	_new_game()
	_fallen()
	_talk("ava_survivor")
	gs.set_flag("factor_turned", 1)
	gs.set_quest("factor", "done_turned", "done")
	_talk("ava_epomeduos")
	_pick("Vouch for her")
	eq(gs.quest_stage("survivor"), "done_vouched")

	_new_game()
	_fallen()
	_talk("ava_survivor")
	_pick("nobody's stopping us")
	eq(gs.quest_stage("survivor"), "done_fought")
	check(_acted("fight_all rome_camp"), "the camp fights")


func test_hermeros_sells_the_pen_and_reads() -> void:
	_new_game()
	_fallen()
	gs.player.silver = 260
	_talk("ava_hermeros")
	_pick("What do you want for them")
	_pick("Pay him")
	eq(gs.flag("pen_freed"), 1)
	check(_acted("leave_all captives"), "the captives go")
	eq(gs.player.silver, 10)
	gs.player.inventory.add("aeduan_letter", 1)
	gs.set_quest("factor", "found")
	_talk("ava_hermeros")
	_pick("Can you read this")
	_pick("Pay him")
	check(_letter_read(), "Hermeros reads the letter")
	eq(gs.quest_stage("factor"), "done_stolen")
