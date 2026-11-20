extends TestCase
## Noviodunum and the end of Act I, walked through the real dialogue files:
## the ways in, the ways out (mercy, price, forged order, night escape,
## leaving them), the homecoming, the assembly and its ending slides.

class FixedDice extends Dice:
	var result := true
	func chance(_percent: float) -> bool:
		return result


var gs: GameState
var dlg: Dictionary
var page: Dictionary
var actions: Array = []


func _new_game() -> void:
	gs = GameState.new()
	gs.player = CharacterSheet.create("Ambiorix", {}, ["speech", "blades", "sneak"])
	gs.dice = FixedDice.new()
	gs.minutes = 80 * 1440 + 10 * 60
	gs.set_quest("hostages", "reported")
	gs.known_locations.append("noviodunum")
	gs.player.inventory.add("hostage_tally")
	actions = []


func _night() -> void:
	gs.minutes = gs.minutes - gs.minutes % 1440 + 22 * 60


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


func _ending_text() -> String:
	var out := ""
	for p in Endings.pages(gs, "endings/act1.json"):
		out += p["title"] + ": " + p["text"] + "\n"
	return out


## Through the gate on the truth, and the tally shown to Orbius.
func _inside() -> void:
	_new_game()
	gs.player.skill_bonus["speech"] = 100
	_talk("nov_gate")
	_pick("My sister is in there. I've walked")
	eq(gs.flag("depot_pass"), 1)
	_talk("nov_orbius")
	_pick("Show him the tally")
	eq(gs.quest_stage("hostages"), "inside")


## Home, then the assembly, choosing `sub`.
func _assembly(sub: String, win := true) -> void:
	_talk("brig_vellaunos")
	check(_has("Call the assembly"), "the assembly can be called")
	_pick("Call the assembly")
	_pick(sub, win)
	eq(gs.flag("act1_done"), 1)
	eq(gs.quest_status("hostages"), "done")
	check(_acted("ending endings/act1.json"), "the Act I ending plays")


func test_mercy_frees_all_three_and_the_town_rises() -> void:
	_inside()
	_talk("nov_ateula")
	_pick("Your father wants you home")
	_pick("He's going to stand up in the assembly")
	eq(gs.flag("ateula_ready"), 1)
	_talk("nov_orbius")
	_pick("Let them go")
	_pick("Write them dead")
	for f in ["orbius_mercy", "epo_out", "iccios_out", "ateula_out"]:
		eq(gs.flag(f), 1, f)
	eq(gs.quest_stage("hostages"), "freed")
	check(_acted("travel noviodunum town"), "back out to the town")
	_assembly("Say nothing")
	eq(gs.flag("brig_rising"), 1)
	var t := _ending_text()
	check(t.find("All three came home") >= 0, "all-three slide")
	check(t.find("three children of the Cadurci died of fever") >= 0, "mercy slide")
	check(t.find("Brigodunon rose.") >= 0, "rising slide")
	check(t.find("Then came Alesia") >= 0, "Act II teaser")


func test_buying_only_the_sister_leaves_the_roll() -> void:
	_inside()
	gs.player.silver = 100
	_talk("nov_orbius")
	_pick("What would it cost")
	_pick("One hundred. For my sister.")
	eq(gs.flag("epo_out"), 1)
	eq(gs.flag("iccios_out"), 0)
	eq(gs.quest_stage("hostages"), "freed_some")
	eq(gs.player.inventory.count("hostage_roll"), 1)
	_assembly("Hold up Ateula's roll")
	eq(gs.flag("brig_rising"), 1)
	check(_ending_text().find("made money on the fever") >= 0, "bought slide")


func test_forged_order_through_the_watch() -> void:
	_inside()
	gs.player.inventory.add("orbius_seal")
	_talk("nov_ateula")
	_pick("Can you get them out on paper?")
	_pick("I have the quartermaster's seal")
	eq(gs.player.inventory.count("release_order"), 1)
	_talk("nov_watch")
	_pick("Give him the sealed order")
	for f in ["release_forged", "epo_out", "iccios_out", "ateula_stays"]:
		eq(gs.flag(f), 1, f)
	eq(gs.quest_stage("hostages"), "freed_some")
	gs.honor = 30
	_assembly("I gave my word to bring them back")
	eq(gs.flag("brig_faith"), 1)
	var t := _ending_text()
	check(t.find("Ateula stayed behind") >= 0, "Ateula stays slide")
	check(t.find("seal was wrong") >= 0, "forged order slide")


func test_night_escape_spotted_then_out() -> void:
	_inside()
	_talk("nov_eponina")
	_pick("Mother sent me")
	check(not _has("Tonight. We go now."), "no escape by day")
	_night()
	_talk("nov_eponina")
	_pick("Tonight. We go now.")
	_pick("Go now. Down to the river", false)
	eq(page["node"], "spotted")
	_pick("Run for the gap alone")
	eq(gs.flag("epo_out"), 0)
	_talk("nov_eponina")
	_pick("Tonight. We go now.")
	_pick("Go now. Down to the river")
	eq(gs.flag("epo_out"), 1)
	eq(gs.flag("iccios_out"), 0)
	eq(gs.quest_stage("hostages"), "freed_some")
	# Iccios can still follow on a later night.
	_talk("nov_iccios")
	_pick("We're getting out of here")
	_pick("If you stay, you're nails")
	_pick("The others are out")
	eq(gs.flag("iccios_out"), 1)
	eq(gs.quest_stage("hostages"), "freed_some", "Ateula is still inside")
	_talk("brig_vellaunos")
	_pick("Call the assembly")
	check(not _has("Nobody in this hall"), "the split argument needs Presence")
	_pick("Say nothing")
	eq(gs.flag("brig_rising"), 1)


func test_night_escape_with_the_horses_and_a_split() -> void:
	_inside()
	gs.player.silver = 30
	gs.player.attrs["PRE"] = 6
	_talk("nov_neitin")
	_pick("If the horses got loose")
	_pick("Thirty silver")
	eq(gs.flag("horses_loose"), 1)
	_talk("nov_eponina")
	_pick("I've come to take you home")
	_night()
	_talk("nov_eponina")
	_pick("Tonight. We go now.")
	_pick("while the watch is chasing horses")
	eq(gs.flag("epo_out"), 1)
	_assembly("Nobody in this hall can make anyone")
	eq(gs.flag("brig_split"), 1)
	var t := _ending_text()
	check(t.find("Neitin") >= 0, "Neitin slide")
	check(t.find("Brigodunon split.") >= 0, "split slide")


func test_leaving_them_then_keeping_faith_by_argument() -> void:
	_inside()
	_talk("nov_eponina")
	_pick("Hold her.")
	_pick("I can't get you out. Not now.")
	_pick("I don't know.")
	_pick("I'm leaving you here.")
	eq(gs.flag("hostages_left"), 1)
	eq(gs.quest_stage("hostages"), "left")
	_talk("brig_matugenta")
	check(page["node"] == "left", "mother hears it")
	_assembly("Rome has six legions")
	eq(gs.flag("brig_faith"), 1)
	check(_ending_text().find("You left them in Noviodunum") >= 0, "left slide")


func test_losing_the_argument_still_ends_the_act() -> void:
	_inside()
	_talk("nov_eponina")
	_pick("Hold her.")
	_pick("I can't get you out. Not now.")
	_pick("I don't know.")
	_pick("I'm leaving you here.")
	_assembly("War is a thing you start", false)
	eq(gs.flag("brig_rising"), 1)


func test_assembly_without_you() -> void:
	_new_game()
	gs.set_flag("assembly_met")
	_talk("brig_vellaunos")
	eq(gs.flag("act1_done"), 1)
	eq(gs.quest_stage("hostages"), "done_late")
	check(_acted("ending endings/act1.json"), "the Act I ending plays")
	var t := _ending_text()
	check(t.find("rose without hearing from you") >= 0, "late slide")
	check(t.find("Nobody from Brigodunon reached Noviodunum") >= 0, "nobody reached them")
	_talk("brig_vellaunos")
	eq(page["node"], "post")


func test_the_river_way_in() -> void:
	_new_game()
	_talk("nov_river")
	eq(page["node"], "day", "no way in by day")
	_night()
	_talk("nov_river")
	_pick("Wait for the lamp to pass", false)
	check(_acted("travel noviodunum reeds"), "seen, back to the reeds")
	eq(gs.flag("depot_pass"), 0)
	gs.player.skill_bonus["survival"] = 100
	_night()
	_talk("nov_river")
	_pick("count the watchman's steps")
	eq(gs.flag("depot_pass"), 1)
	eq(gs.flag("depot_sneaked"), 1)


func test_the_alarm_can_be_outrun() -> void:
	_inside()
	gs.set_flag("escape_alarm")
	_talk("nov_watch")
	eq(page["node"], "alarm")
	_pick("Run for the gap")
	check(not _acted("fight_all depot_watch"), "no fight")
	check(_acted("travel noviodunum reeds"), "out into the reeds")
