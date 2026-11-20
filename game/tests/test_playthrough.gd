extends TestCase
## Walks the demo's quest routes through the real dialogue files, choosing
## options by their text, the way a player would. Rolls are forced by
## swapping in dice that always pass or always fail.

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
	actions = []


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


## New game up to holding Vellaunos's commission and the vates' grotto quest.
func _commissioned() -> void:
	_new_game()
	_talk("brig_wake")
	eq(gs.quest_stage("hostages"), "summoned")
	_pick("Then I'd better go")
	_talk("brig_vellaunos")
	_pick("Why me?")
	_pick("I'll find it")
	eq(gs.quest_stage("hostages"), "find_tally")
	eq(gs.player.inventory.count("elders_ring"), 1)
	eq(gs.player.silver, 25)
	_talk("brig_vates")
	_pick("I'll get it back")
	eq(gs.quest_status("grotto"), "active")
	check("grotto" in gs.known_locations, "grotto is on the map")


## Commissioned, plus the tally bought from Dubnacos and shown to Vellaunos.
func _tally_read_needed() -> void:
	_commissioned()
	gs.player.silver = 60
	_talk("grotto_dubnacos")
	_pick("What do you want for it?")
	_pick("Pay him sixty silver")
	eq(gs.player.inventory.count("hostage_tally"), 1)
	eq(gs.quest_status("grotto"), "done")
	_talk("brig_vellaunos")
	_pick("I have the tally")
	eq(gs.quest_stage("hostages"), "read_tally")
	_pick("Vindomagos, then")


func test_main_line_to_the_report() -> void:
	_tally_read_needed()
	_talk("vind_sulicena")
	_pick("Can you read Roman marks?")
	eq(gs.quest_stage("hostages"), "ask_riders")
	_pick("Thank you")
	_pick("Vellaunos sends his greetings")
	eq(gs.quest_status("ford"), "active")
	eq(gs.player.inventory.count("grain_writ"), 1)
	gs.player.skill_bonus["speech"] = 100
	_talk("ford_haldo")
	_pick("Can you read Roman marks?")
	_pick("It's three children")
	eq(gs.quest_stage("hostages"), "north")
	check("noviodunum" in gs.known_locations, "noviodunum is known")
	_talk("brig_vellaunos")
	_pick("I know where the tally was cut")
	eq(gs.quest_stage("hostages"), "reported")
	check(not _acted("ending "), "the report no longer ends the game")
	_pick("I'll be back before the spring")
	_talk("brig_vellaunos")
	check(not _has("Call the assembly"), "no assembly before Noviodunum")


func test_reading_the_tally_yourself() -> void:
	_tally_read_needed()
	actions = []
	_talk("brig_vellaunos")
	_pick("Goodbye")
	gs.player.skill_bonus["latin"] = 100
	gs.set_quest("hostages", "read_tally")
	_talk("vind_sulicena")
	_pick("Can you read Roman marks?")
	_pick("I know some Latin")
	eq(gs.quest_stage("hostages"), "north")


func test_grotto_pardon_route() -> void:
	_commissioned()
	_talk("grotto_dubnacos")
	_pick("What do you want for it?")
	eq(gs.quest_stage("grotto"), "pardon_asked")
	_pick("I'll be back")
	gs.player.skill_bonus["speech"] = 100
	_talk("brig_vellaunos")
	_pick("He wants to come home")
	_pick("Brigodunon is about to need")
	eq(gs.flag("pardon_granted"), 1)
	_talk("grotto_dubnacos")
	_pick("Vellaunos says you can come home")
	eq(gs.player.inventory.count("hostage_tally"), 1)
	eq(gs.flag("dubnacos_pardoned"), 1)
	check(_acted("leave_all grotto"), "the bandits leave")


func test_grotto_lie_route_both_ways() -> void:
	_commissioned()
	_talk("grotto_dubnacos")
	_pick("What do you want for it?")
	_pick("Show him the elder's ring", false)
	eq(gs.flag("dub_lie_failed"), 1)
	check(not _has("Show him the elder's ring"), "the lie can't be retried")
	_commissioned()
	_talk("grotto_dubnacos")
	_pick("What do you want for it?")
	_pick("Show him the elder's ring", true)
	eq(gs.quest_stage("grotto"), "done_lied")
	check(gs.honor < 0, "lying costs honor")


func test_grotto_idol_and_fight_routes() -> void:
	_commissioned()
	gs.player.inventory.add("grotto_idol")
	_talk("grotto_dubnacos")
	_pick("Hold up the idol")
	eq(gs.quest_stage("grotto"), "done_scared")
	_commissioned()
	_talk("grotto_dubnacos")
	_pick("Give me the tally or I'll take it")
	_pick("So be it")
	check(_acted("fight_all grotto"), "the grotto fights")


func test_vates_closes_grotto_if_tally_stolen() -> void:
	_commissioned()
	gs.player.inventory.add("hostage_tally")
	_talk("brig_vates")
	_pick("I have the tally back")
	eq(gs.quest_status("grotto"), "done")


func _at_the_ford() -> void:
	_commissioned()
	_talk("vind_sulicena")
	_pick("Vellaunos sends his greetings")
	_pick("I'll see to it")


func _ford_closed_by_sulicena(flag_: String) -> void:
	eq(gs.flag("ford_settled"), 1)
	_talk("vind_sulicena")
	_pick("The ford is open")
	eq(gs.quest_status("ford"), "done")
	check(page["text"] != "", "Sulicena comments on " + flag_)


func test_ford_toll() -> void:
	_at_the_ford()
	gs.player.silver = 40
	_talk("ford_haldo")
	_pick("Brigodunon's grain")
	_pick("Pay him forty silver")
	eq(gs.player.silver, 0)
	_pick("Nothing. Goodbye")
	_talk("ford_barrier")
	_ford_closed_by_sulicena("ford_toll_paid")


func test_ford_lie() -> void:
	_at_the_ford()
	_talk("ford_haldo")
	_pick("the Arverni are coming", false)
	eq(gs.flag("ford_lie_failed"), 1)
	check(not _has("the Arverni are coming"), "the lie can't be retried")
	_pick("Nothing. Goodbye")
	_at_the_ford()
	_talk("ford_haldo")
	_pick("the Arverni are coming", true)
	check(_acted("leave_all riders"), "the riders leave")
	_ford_closed_by_sulicena("ford_lied")


func test_ford_forged_recall() -> void:
	_at_the_ford()
	gs.player.skill_bonus["latin"] = 100
	_talk("vind_sulicena")
	_pick("What if Rome called them home?")
	_pick("That's Rome's business")
	eq(gs.player.inventory.count("roman_order"), 1)
	_pick("Goodbye")
	_talk("ford_haldo")
	_pick("A message came for you")
	_pick("A courier came through")
	eq(gs.player.inventory.count("roman_order"), 0)
	_ford_closed_by_sulicena("riders_recalled")


func test_ford_recruit_and_threat() -> void:
	_at_the_ford()
	gs.player.silver = 60
	gs.renown = 10
	_talk("ford_haldo")
	_pick("Ride for Brigodunon instead")
	_pick("Sixty silver now")
	eq(gs.flag("riders_hired"), 1)
	_ford_closed_by_sulicena("riders_hired")
	_at_the_ford()
	_talk("ford_haldo")
	_pick("Get off this ford")
	_pick("Look at me", false)
	check(_acted("fight_all riders"), "a failed threat starts the fight")
	_at_the_ford()
	_talk("ford_haldo")
	_pick("Get off this ford")
	_pick("Look at me", true)
	_ford_closed_by_sulicena("threat")


func test_ford_horses() -> void:
	_at_the_ford()
	gs.minutes = (gs.minutes / 1440) * 1440 + 9 * 60
	_talk("ford_horses")
	_pick("wait for dark")
	check(gs.hour() >= 20 or gs.hour() < 6, "it is night after waiting")
	_pick("Cut the picket rope", true)
	eq(gs.flag("horses_gone"), 1)
	_talk("ford_haldo")
	eq(page["node"], "on_foot")
	gs.player.skill_bonus["speech"] = 100
	_pick("On foot, in winter")
	_ford_closed_by_sulicena("horses_gone")


## Getting caught at the horse line is never a straight drop into a fight
## with the whole band: run, talk, pay, or stare Haldo down.
func test_ford_horses_caught() -> void:
	for way in [["Drop into the reeds", true, ""], ["I came looking for Haldo", true, ""],
			["Drop into the reeds", false, "Hold out twenty silver"],
			["Drop into the reeds", false, "say nothing at all"]]:
		_at_the_ford()
		gs.player.silver = 20
		gs.minutes = (gs.minutes / 1440) * 1440 + 23 * 60
		_talk("ford_horses")
		_pick("Cut the picket rope", false)
		eq(page["node"], "caught")
		_pick(way[0], way[1])
		if way[2] != "":
			eq(page["node"], "cornered")
			_pick(way[2], true)
		check(not _acted("fight_all riders"), "%s: no fight" % way[0])
		eq(gs.flag("horses_watched"), 1)
		eq(gs.flag("horses_gone"), 0)
		_talk("ford_horses")
		eq(page["node"], "watched", "the horse line is guarded now")
	_at_the_ford()
	gs.minutes = (gs.minutes / 1440) * 1440 + 23 * 60
	_talk("ford_horses")
	_pick("Cut the picket rope", false)
	_pick("Fight.")
	check(_acted("fight_all riders"), "or fight")


func test_ford_barrier_fight_and_after() -> void:
	_at_the_ford()
	_talk("ford_barrier")
	_pick("Push past him")
	check(not _acted("fight_all riders"), "the band stands up first")
	_pick("Push past him anyway")
	check(_acted("fight_all riders"), "pushing starts the fight")
	_talk("ford_barrier")
	eq(gs.flag("ford_open"), 1)
	gs.player.inventory.add("rider_tablet")
	_talk("vind_sulicena")
	_pick("The riders at the ford are dead")
	eq(gs.quest_status("ford"), "done")
