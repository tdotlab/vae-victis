extends TestCase

const SRC := """
=== start
[flag met] -> again
Well met, {name}.
~ set met
* [speech 200] Impossible talk -> END
* [speech 10] Easy talk -> talked ~ xp 20; set talked
* [roll speech 95] Gamble -> win | lose
* Bye -> END

=== again
Back again?

So soon.
* Bye -> END

=== talked
~ quest hostages find_tally
~ give salt 2; silver 15
Done.
* Leave -> END ~ fight

=== win
You win.
=== lose
You lose.
"""


func _gs() -> GameState:
	var gs := GameState.new()
	gs.player = CharacterSheet.create("Ambiorix", {"PRE": 6}, ["speech", "blades", "sneak"])
	gs.dice.reseed(7)
	return gs


func test_parse_and_enter() -> void:
	var d := Dialogue.parse(SRC)
	eq(d["entry"], "start")
	var gs := _gs()
	var page := Dialogue.enter(gs, d, "start")
	eq(page["text"], "Well met, Ambiorix.")
	eq(gs.flag("met"), 1)
	# The impossible speech check is hidden; three choices remain.
	eq(page["choices"].size(), 3)
	eq(page["choices"][0]["label"], "[Speech] ")


func test_conditional_jump_and_paragraphs() -> void:
	var d := Dialogue.parse(SRC)
	var gs := _gs()
	gs.set_flag("met")
	var page := Dialogue.enter(gs, d, "start")
	eq(page["node"], "again")
	eq(page["text"], "Back again?\n\nSo soon.")


func test_choice_effects() -> void:
	var d := Dialogue.parse(SRC)
	var gs := _gs()
	var page := Dialogue.enter(gs, d, "start")
	var ch: Dictionary = page["choices"][0]
	var next := Dialogue.choose(gs, d, page["node"], ch["index"])
	eq(next["node"], "talked")
	eq(next["xp"], 20)
	eq(gs.flag("talked"), 1)
	eq(gs.quest_stage("hostages"), "find_tally")
	eq(gs.player.inventory.count("salt"), 2)
	eq(gs.player.silver, 15)
	var last := Dialogue.choose(gs, d, "talked", next["choices"][0]["index"])
	check(last["end"])
	eq(last["actions"], ["fight"])


func test_roll_choice() -> void:
	var d := Dialogue.parse(SRC)
	var gs := _gs()
	var page := Dialogue.enter(gs, d, "start")
	var ch: Dictionary = page["choices"][1]
	check(ch.has("chance"))
	var next := Dialogue.choose(gs, d, page["node"], ch["index"])
	check(next["node"] == "win" or next["node"] == "lose")


func test_conditions() -> void:
	var gs := _gs()
	gs.honor = 30
	gs.player.silver = 10
	check(Dialogue.check(gs, "honor >= 25"))
	check(not Dialogue.check(gs, "honor >= 40"))
	check(Dialogue.check(gs, "silver 10"))
	check(not Dialogue.check(gs, "silver 11"))
	check(Dialogue.check(gs, "!flag nothing"))
	gs.set_flag("x", 3)
	check(Dialogue.check(gs, "flag x>=2"))
	check(Dialogue.check(gs, "PRE 6"))
	check(not Dialogue.check(gs, "PRE 7"))
	check(Dialogue.check(gs, "quest hostages none"))


func test_real_dialogues_parse() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".dlg"):
			continue
		var d := Dialogue.parse(FileAccess.get_file_as_string("res://data/dialogue/" + f), f)
		check(d["entry"] != "", f + " has an entry node")
		for nid in d["nodes"]:
			for op in d["nodes"][nid]:
				for key in ["to", "fail"]:
					if op.has(key) and op[key] != "END":
						check(d["nodes"].has(op[key]), "%s: node %s points to missing %s" % [f, nid, op[key]])
