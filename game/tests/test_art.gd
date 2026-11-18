extends TestCase
## Figure layers: which sprite layers make up a person, and that the packed
## art has every layer any NPC asks for.


func _gear() -> Dictionary:
	return Art.manifest().get("figure", {}).get("gear", {})


func test_women_get_the_dress_and_a_braid_by_default() -> void:
	var a := Actor.from_template("refugee_woman")
	var l := Art.figure_layers(a, _gear(), false)
	eq(l[0], "body_f", "a woman's body")
	check("hair_braid" in l, "braided by default")
	check(not "moustache" in l and not "beard" in l, "no moustache")


func test_romans_are_bare_legged_and_short_haired() -> void:
	var a := Actor.from_template("roman_forager")
	var l := Art.figure_layers(a, _gear(), false)
	eq(l[0], "body_roman")
	check("hair_short" in l, "short hair")
	check("gladius" in l and "scutum" in l and "helmet" in l, "gladius, scutum, Montefortino: %s" % [l])


func test_nobody_wears_a_torc_or_moustache_unless_their_look_says_so() -> void:
	var a := Actor.from_template("refugee")
	for l in Art.figure_layers(a, _gear(), false):
		check(not String(l).begins_with("torc") and l != "moustache", "plain refugee: %s" % l)
	var v := Art.figure_layers(Actor.from_template("vellaunos"), _gear(), false)
	check("torc_gold" in v and "moustache" in v, "the chief of elders has both")


func test_the_fallen_keep_head_and_torc_but_drop_their_gear() -> void:
	var l := Art.figure_layers(Actor.from_template("haldo"), _gear(), true)
	eq(l, ["body", "hair_knot", "beard"])


func test_swept_hair_goes_under_a_helmet() -> void:
	var l := Art.figure_layers(Actor.from_template("moccos"), _gear(), false)
	check("helmet_iron" in l and "hair_long" in l and not "hair_swept" in l, "%s" % [l])


func test_every_npc_layer_has_a_sprite() -> void:
	var f: Dictionary = Art.manifest().get("figure", {})
	if f.is_empty():
		return  # no art packed; the game falls back to placeholders
	for t in DB.load_json("npcs.json")["npcs"]:
		if t.get("look", {}).get("beast", false):
			continue
		var a := Actor.from_template(t["id"])
		for down in [false, true]:
			for l in Art.figure_layers(a, f["gear"], down):
				check(f["layers"].has(l), "%s: layer %s is packed" % [t["id"], l])
