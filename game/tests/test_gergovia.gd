extends TestCase
## Gergovia's quest routes, walked through the real dialogue files: the Vettius
## tablets, the king's levy, the pit, and Theron.

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
	gs.set_flag("gergovia_taken", 1)
	gs.minutes = 8 * 1440 + 10 * 60  # day 9, mid-morning
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


func _night() -> void:
	gs.minutes = gs.minutes - gs.minutes % 1440 + 22 * 60


## Paconius unmasked through the potter's hint.
func _unmasked() -> void:
	_new_game()
	_talk("ger_recruiter")
	eq(gs.quest_stage("vettius"), "rumor")
	_talk("ger_potter")
	_pick("strangers")
	eq(gs.flag("potter_hint"), 1)
	_talk("ger_paconius")
	_pick("never went out with them")
	eq(gs.quest_stage("vettius"), "found")


func _read_with_item_and_latin() -> void:
	gs.player.skill_bonus["latin"] = 100
	_talk("item_tablets")
	_pick("Read it")
	eq(gs.quest_status("vettius"), "done")
	eq(gs.quest_stage("vettius"), "read")
	check("noviodunum" in gs.known_locations, "Noviodunum is on the map")


# --- The Vettius tablets ---------------------------------------------------------

func test_clerk_escape_by_sneaking_then_failing_is_closed() -> void:
	_unmasked()
	_pick("get you out of Gergovia")
	_pick("potter's back fence", false)
	eq(gs.flag("clerk_spooked"), 1)
	check(not _has("get you out of Gergovia"), "the escape can't be retried after a scare")
	_new_game()
	_unmasked()
	_pick("get you out of Gergovia")
	_pick("potter's back fence", true)
	eq(gs.player.inventory.count("vettius_tablets"), 1)
	eq(gs.flag("clerk_saved"), 1)
	eq(gs.flag("clerk_gone"), 1)
	eq(gs.quest_stage("vettius"), "tablets")
	_pick("Good luck")
	check(_acted("leave"), "Paconius leaves")
	_read_with_item_and_latin()


func test_clerk_escape_by_bribe_and_by_speech() -> void:
	_unmasked()
	gs.player.silver = 40
	_pick("get you out of Gergovia")
	_pick("drinks well tonight")
	eq(gs.player.silver, 0)
	eq(gs.flag("clerk_saved"), 1)
	_new_game()
	_unmasked()
	gs.player.skill_bonus["speech"] = 100
	_pick("get you out of Gergovia")
	_pick("You're my servant")
	eq(gs.flag("clerk_saved"), 1)


func test_unmask_by_latin_and_buy_then_he_reads() -> void:
	_new_game()
	gs.player.skill_bonus["latin"] = 100
	gs.player.silver = 80
	_talk("ger_paconius")
	_pick("Salve")
	eq(gs.flag("clerk_unmasked"), 1)
	_pick("I'll buy them")
	_pick("Pay him")
	eq(gs.player.silver, 0)
	eq(gs.player.inventory.count("vettius_tablets"), 1)
	_pick("Read these to me")
	eq(gs.quest_status("vettius"), "done")


func test_theron_confesses_then_threat() -> void:
	_new_game()
	gs.player.skill_bonus["speech"] = 100
	_talk("ger_theron")
	eq(gs.quest_stage("vettius"), "rumor")
	_pick("Your bookkeeper")
	_pick("I can count")
	eq(gs.flag("theron_confessed"), 1)
	eq(gs.quest_stage("vettius"), "found")
	_talk("ger_paconius")
	_pick("Theron told me")
	_pick("or I tell the king's men")
	_pick("until I finish this sentence", false)
	eq(gs.player.inventory.count("vettius_tablets"), 0)
	_pick("or I tell the king's men")
	_pick("until I finish this sentence", true)
	eq(gs.player.inventory.count("vettius_tablets"), 1)
	# Theron reads them, for a price or a word.
	_talk("ger_theron")
	_pick("Can you read these?")
	_pick("read them out loud for free")
	eq(gs.quest_status("vettius"), "done")


func test_betraying_the_clerk_costs_theron() -> void:
	_unmasked()
	_talk("ger_ollognatos")
	_pick("Roman hiding in the lower town")
	eq(gs.flag("clerk_betrayed"), 1)
	eq(gs.flag("tablets_given"), 1)
	eq(gs.player.inventory.count("vettius_tablets"), 1)
	check(gs.get_standing("arverni") > 0, "the king's men are pleased")
	check(gs.honor < 0, "honor suffers")
	_talk("ger_theron")
	check(not _has("getting you out"), "Theron won't deal")
	check(not _has("You look like a man"), "Theron won't deal")


func test_lugurix_reads_the_tablets_and_moves_the_main_quest() -> void:
	_new_game()
	gs.set_quest("hostages", "read_tally", "active")
	gs.player.inventory.add("vettius_tablets", 1)
	gs.player.silver = 40
	_talk("vind_trader")
	_pick("Roman wax tablets")
	_pick("Pay him")
	eq(gs.quest_stage("hostages"), "north")
	eq(gs.quest_status("vettius"), "done")
	_talk("brig_vellaunos")
	_pick("Roman merchant's accounts")
	eq(gs.flag("vell_tablets"), 1)


func test_the_king_hears_the_tablets() -> void:
	_new_game()
	gs.set_flag("tablets_read", 1)
	_talk("ger_vercingetorix")
	_pick("I have the accounts")
	eq(gs.flag("verc_tablets"), 1)
	check(not _has("I have the accounts"), "only once")


# --- The king's levy -------------------------------------------------------------

func _levy(choice: String) -> void:
	_new_game()
	_talk("ger_ollognatos")
	eq(gs.quest_status("levy"), "active")
	_pick("About Brigodunon's levy")
	_pick(choice)
	eq(gs.quest_status("levy"), "done")


func test_levy_routes() -> void:
	_levy("You have my word")
	eq(gs.quest_stage("levy"), "done_pledged")
	_talk("brig_vellaunos")
	_pick("Gergovia wants hostages")
	check(page["text"].find("Two children") >= 0, "Vellaunos reacts to the pledge")

	_new_game()
	gs.honor = 10
	_talk("ger_ollognatos")
	_pick("About Brigodunon's levy")
	_pick("My oath to the king")
	eq(gs.quest_stage("levy"), "done_self")

	_new_game()
	gs.player.skill_bonus["lore"] = 100
	_talk("ger_ollognatos")
	_pick("About Brigodunon's levy")
	_pick("through Lucterius")
	eq(gs.quest_stage("levy"), "done_lucterius")

	_new_game()
	gs.player.silver = 100
	_talk("ger_ollognatos")
	_pick("About Brigodunon's levy")
	_pick("silver for spearheads")
	eq(gs.player.silver, 0)
	eq(gs.quest_stage("levy"), "done_iron")

	_levy("Brigodunon gives nothing")
	eq(gs.quest_stage("levy"), "done_refused")
	check(gs.get_standing("arverni") < 0, "the king's men remember")


func test_levy_sold_to_vindomagos_and_sulicena_knows() -> void:
	_levy("Vindomagos is richer")
	eq(gs.flag("levy_vindomagos"), 1)
	gs.set_flag("sul_met", 1)
	_talk("vind_sulicena")
	eq(gs.flag("sul_levy"), 1)
	check(page["text"].find("I wonder who") >= 0, "Sulicena knows")
	check(gs.get_standing("vindomagos") < 0, "Vindomagos remembers")


# --- The pit ----------------------------------------------------------------------

func _pit() -> void:
	_new_game()
	_talk("ger_ategnatos")
	_pick("What happened to his friends")
	eq(gs.quest_status("pit"), "active")


func test_pit_plea_by_speech_is_rewarded() -> void:
	_pit()
	gs.player.skill_bonus["speech"] = 100
	_talk("ger_vercingetorix")
	_pick("spare him")
	_pick("front rank teaches them")
	eq(gs.quest_stage("pit"), "done_spared")
	eq(gs.flag("pit_closed"), 1)
	var silver := gs.player.silver
	_talk("ger_ategnatos")
	eq(gs.player.silver, silver + 120)
	eq(gs.quest_stage("vettius"), "rumor")
	_talk("ger_ategnatos")
	eq(gs.player.silver, silver + 120)


func test_pit_plain_plea_costs_ears() -> void:
	_pit()
	_talk("ger_vercingetorix")
	_pick("spare him")
	_pick("Show mercy")
	eq(gs.quest_stage("pit"), "done_ears")
	_talk("ger_vercingetorix")
	check(not _has("spare him"), "one plea only")


func test_pit_bribe_and_night_rescue() -> void:
	_pit()
	gs.player.silver = 60
	_talk("ger_pit_guard")
	_pick("Sixty silver")
	eq(gs.quest_stage("pit"), "guard_paid")
	_talk("ger_eppillos")
	check(_has("Not in daylight"), "not by day")
	check(not _has("Here's the rope"), "not by day")
	_night()
	_talk("ger_eppillos")
	_pick("Here's the rope")
	eq(gs.quest_stage("pit"), "done_freed")
	_pick("Go")
	check(_acted("leave"), "Eppillos runs")
	_talk("ger_ategnatos")
	eq(gs.player.inventory.count("gold_torque"), 1)


func test_pit_sneak_fails_then_closed() -> void:
	_pit()
	_night()
	_talk("ger_eppillos")
	_pick("getting you out", false)
	eq(gs.flag("pit_alarm"), 1)
	_talk("ger_eppillos")
	check(not _has("getting you out"), "the watch is doubled")
	_talk("ger_pit_guard")
	check(not _has("Sixty silver"), "the guard won't take silver now")


func test_pit_betrayed_to_ollognatos() -> void:
	_pit()
	_talk("ger_ollognatos")
	_pick("Ategnatos means to get his son out")
	eq(gs.quest_stage("pit"), "done_betrayed")
	eq(gs.flag("ategnatos_taken"), 1)


func test_pit_fails_when_the_king_marches() -> void:
	_pit()
	gs.set_flag("verc_north", 1)
	_talk("ger_stakes")
	eq(gs.quest_status("pit"), "failed")
	_pit()
	gs.set_flag("verc_north", 1)
	_talk("ger_ategnatos")
	eq(gs.quest_status("pit"), "failed")


# --- Theron ------------------------------------------------------------------------

func test_theron_joins_after_the_clerk_is_saved() -> void:
	_unmasked()
	gs.player.silver = 40
	_pick("get you out of Gergovia")
	_pick("drinks well tonight")
	_talk("ger_theron")
	_pick("rather be somewhere else")
	eq(gs.quest_status("theron"), "active")
	_pick("About getting you out")
	_pick("Pack what you can carry")
	eq(gs.player.silver, 50)
	_pick("Let's go")
	eq(gs.quest_status("theron"), "done")
	eq(gs.flag("theron_joined"), 1)
	check(_acted("join"), "Theron joins")


func test_theron_joins_as_a_paid_escort() -> void:
	_new_game()
	_talk("ger_theron")
	_pick("rather be somewhere else")
	_pick("About getting you out")
	_pick("Twenty-five silver")
	eq(gs.player.silver, 25)
	_pick("Let's go")
	eq(gs.quest_status("theron"), "done")
