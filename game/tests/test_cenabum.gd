extends TestCase
## Cenabum walked through the real dialogue files: the bridge (argued early
## or late, the ford, the boats) and the widow (judged, bribed out, caught,
## argued, bought, given up), with the Act I ending slides they feed.

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


## The widow's things, handed over on any route that frees her or gives her up.
func _has_her_things() -> void:
	eq(gs.player.inventory.count("commissary_seal"), 1, "seal")
	eq(gs.player.inventory.count("grain_ledger"), 1, "ledger")


func _open_bridge() -> void:
	_talk("cen_senuacos")
	_pick("When Caesar comes back")
	eq(gs.quest_stage("bridge"), "start")


func test_the_ford_argued_early_waits_for_the_news() -> void:
	_new_game()
	gs.player.skill_bonus["lore"] = 100
	_open_bridge()
	check(not _has("Caesar's at Vellaunodunum"), "no news yet")
	_pick("Where did they cross before there was one")
	eq(gs.flag("cen_ford_found"), 1)
	_pick("The old ford below the island")
	eq(gs.quest_stage("bridge"), "agreed")
	eq(gs.flag("cenabum_saved"), 0, "not yet: the calendar does that")
	check(not _acted("leave_all"), "nobody leaves yet")


func test_the_news_lets_a_weaker_argument_land_and_the_town_goes() -> void:
	_new_game()
	gs.player.skill_bonus["speech"] = 40 - gs.player.skill("speech")
	gs.set_flag("caesar_near_cenabum")
	_open_bridge()
	check(not _has("One bridge, one night"), "speech 50 argument hidden at 40")
	_pick("Caesar's at Vellaunodunum")
	eq(gs.quest_stage("bridge"), "done_saved")
	eq(gs.quest_status("bridge"), "done")
	eq(gs.flag("cenabum_saved"), 1)
	check(_acted("leave_all cenabum"), "the town walks out")
	check(_ending_text().find("found the gates open and the streets empty") >= 0, "saved slide")


func test_boats_and_the_ford_from_the_boatman() -> void:
	_new_game()
	gs.player.silver = 60
	gs.player.skill_bonus["barter"] = 100
	_open_bridge()
	_talk("cen_onnacos")
	_pick("Is there anywhere to cross")
	_pick("Ten silver")
	eq(gs.flag("cen_ford_found"), 1)
	_pick("How many could your boats")
	_pick("Fifty.")
	eq(gs.flag("cen_boats"), 1)
	eq(gs.player.silver, 0)
	_talk("cen_senuacos")
	_pick("About the bridge")
	check(_has("Onnacos's boats are yours"), "boats argument")
	_pick("Onnacos's boats are yours")
	eq(gs.quest_stage("bridge"), "agreed")


func test_the_bridge_seen_with_a_good_eye() -> void:
	_new_game()
	gs.player.skill_bonus["survival"] = 100
	_talk("cen_bridge")
	eq(gs.flag("cen_bridge_seen"), 1)
	_pick("Look downstream")
	eq(gs.flag("cen_ford_found"), 1)


func test_the_bridge_fails_when_caesar_comes() -> void:
	_new_game()
	_open_bridge()
	gs.set_quest("bridge", "done_failed", "failed")
	check(_ending_text().find("hardly anyone escaped") >= 0, "failed slide")


func test_the_elder_judges_the_widow() -> void:
	_new_game()
	gs.player.skill_bonus["lore"] = 100
	_talk("cen_senuacos")
	_pick("There's a pen behind Atepomaros's house")
	eq(gs.quest_stage("widow"), "start")
	_pick("The blood of the tribe is the druids' to judge")
	eq(gs.quest_stage("widow"), "done_judged")
	eq(gs.flag("lit_free"), 1)
	_talk("cen_litumara")
	eq(page["node"], "free")
	_has_her_things()
	eq(gs.flag("lit_gone"), 1)
	check(_acted("leave_all cen_widow"), "she goes")
	eq(gs.quest_stage("widow"), "done_judged", "judgment stands")
	check(_ending_text().find("judged Litumara a woman of the Carnutes") >= 0, "judged slide")


func test_the_elder_refuses_a_failed_plea_once() -> void:
	_new_game()
	_talk("cen_senuacos")
	_pick("There's a pen behind Atepomaros's house")
	_pick("Better he finds them alive", false)
	eq(gs.flag("sen_refused"), 1)
	check(not _has("a woman in a pen"), "no second plea")


func test_bribed_cousin_and_a_night_walk() -> void:
	_new_game()
	gs.player.silver = 20
	_talk("cen_litumara")
	_pick("I'm from the south")
	check(not _has("The cousin's looking the other way"), "not before the bribe")
	_talk("cen_kinsman")
	_pick("Here's twenty")
	eq(gs.flag("kin_bribed"), 1)
	_talk("cen_litumara")
	check(not _has("The cousin's looking the other way"), "not by day")
	_night()
	_talk("cen_litumara")
	_pick("The cousin's looking the other way")
	eq(gs.quest_stage("widow"), "done_saved")
	_has_her_things()
	check(_ending_text().find("got out of Cenabum ahead of the legions") >= 0, "saved slide")


func test_caught_at_the_hurdles_then_the_fight() -> void:
	_new_game()
	_night()
	_talk("cen_litumara")
	_pick("Who are you?")
	_pick("Out through the back hurdles", false)
	eq(page["node"], "caught")
	_pick("Let her go and run")
	eq(gs.flag("lit_caught"), 1)
	_talk("cen_litumara")
	eq(page["node"], "watched")
	_talk("cen_atepomaros")
	_pick("Let her go, or I'll make you")
	_pick("Fight.")
	check(_acted("fight_all atepomaros"), "the fight starts")
	gs.set_flag("ate_dead")
	_talk("cen_litumara")
	eq(page["node"], "free")
	eq(gs.quest_stage("widow"), "done_saved")
	_has_her_things()


func test_latin_tells_atepomaros_the_boy_is_worth_nothing() -> void:
	_new_game()
	gs.player.skill_bonus["latin"] = 100
	_talk("cen_atepomaros")
	check(not _has("That boy's no citizen"), "needs the brother's story first")
	_pick("Why are you holding her?")
	_pick("That boy's no citizen")
	eq(gs.flag("lit_free"), 1)
	_talk("cen_litumara")
	eq(gs.quest_stage("widow"), "done_saved")
	_has_her_things()
	_talk("cen_atepomaros")
	eq(page["node"], "after")


func test_paying_his_brother_s_price() -> void:
	_new_game()
	gs.player.silver = 120
	_talk("cen_atepomaros")
	_pick("In silver")
	_pick("Count it out")
	eq(gs.player.silver, 0)
	eq(gs.quest_stage("widow"), "done_bought")
	_talk("cen_litumara")
	_has_her_things()
	eq(gs.quest_stage("widow"), "done_bought")
	check(_ending_text().find("went to the coast to buy his brother back") >= 0, "bought slide")


func test_giving_her_up() -> void:
	_new_game()
	gs.honor = 20
	_talk("cen_atepomaros")
	_pick("I only want what her husband carried")
	_pick("A seal and a book of accounts")
	eq(gs.quest_stage("widow"), "done_given")
	eq(gs.honor, 10)
	_has_her_things()
	check(_acted("leave_all cen_widow"), "they take her away")
	_talk("cen_atepomaros")
	eq(page["node"], "after_given")
	check(_ending_text().find("The account was considered settled") >= 0, "given slide")


func test_the_elder_points_to_the_druids() -> void:
	_new_game()
	_talk("cen_senuacos")
	_pick("Where do the druids meet?")
	check("carnute_forest" in gs.known_locations, "forest known")


func test_the_ashes_remember_who_got_out() -> void:
	_new_game()
	gs.set_flag("cenabum_burned")
	gs.set_flag("cenabum_saved")
	_talk("cen_senuacos_after")
	eq(gs.player.inventory.count("gold_torque"), 1)
	check("carnute_forest" in gs.known_locations, "forest known")
	_talk("cen_senuacos_after")
	eq(page["node"], "again")
	eq(gs.player.inventory.count("gold_torque"), 1, "rewarded once")
	_talk("cen_ash")
	eq(page["node"], "saved")
	_talk("cen_cunissos")
	eq(page["node"], "ash")
