extends TestCase


func _actor(name_: String, attrs: Dictionary, tags: Array, equip: Array = []) -> Actor:
	var a := Actor.new()
	a.sheet = CharacterSheet.create(name_, attrs, tags)
	for e in equip:
		a.sheet.inventory.add(e, 1)
		a.sheet.equip(e)
	a.sheet.hp = a.sheet.max_hp()
	return a


func test_hit_chance_bounds_and_range() -> void:
	var a := _actor("A", {"AGI": 8, "STR": 7}, ["blades"], ["gladius"])
	var d := _actor("D", {}, [])
	var w := a.sheet.weapon_def()
	var c := CombatRules.hit_chance(a, d, w, 1)
	check(c >= 5 and c <= 95)
	eq(CombatRules.hit_chance(a, d, w, 2), 0, "melee can't reach two hexes")
	check(CombatRules.hit_chance(a, d, w, 1, "eyes") < c, "aimed shots are harder")


func test_ranged_falls_off_with_distance() -> void:
	var a := _actor("A", {"PER": 6}, ["missiles"], ["sling"])
	a.sheet.inventory.add("sling_stone", 10)
	var d := _actor("D", {}, [])
	var w := a.sheet.weapon_def()
	check(CombatRules.hit_chance(a, d, w, 3) > CombatRules.hit_chance(a, d, w, 9))
	check(CombatRules.has_ammo(a, w))


func test_damage_respects_armor() -> void:
	var a := _actor("A", {"STR": 5}, ["blades"], ["dagger"])
	var d := _actor("D", {}, [], ["chief_mail"])
	var dice := Dice.new()
	dice.reseed(3)
	var w := a.sheet.weapon_def()
	var total_armored := 0
	var total_bare := 0
	var bare := _actor("B", {}, [])
	for i in range(50):
		total_armored += CombatRules.roll_damage(a, d, w, "torso", false, dice)["damage"]
		total_bare += CombatRules.roll_damage(a, bare, w, "torso", false, dice)["damage"]
	check(total_armored < total_bare)


func test_shield_covers_front_only() -> void:
	var d := _actor("D", {}, [], ["gallic_shield"])
	d.cell = Vector2i(0, 0)
	d.facing = 0  # facing east
	check(CombatRules.shield_covers(d, Hex.neighbor(d.cell, 0)))
	check(CombatRules.shield_covers(d, Hex.neighbor(d.cell, 1)))
	check(not CombatRules.shield_covers(d, Hex.neighbor(d.cell, 3)), "not from behind")
	d.shield_fouled = true
	check(not CombatRules.shield_covers(d, Hex.neighbor(d.cell, 0)), "fouled shield is useless")


func test_turn_order_by_sequence() -> void:
	var slow := _actor("S", {"PER": 2}, [])
	var fast := _actor("F", {"PER": 9}, [])
	var o := CombatRules.turn_order([slow, fast])
	eq(o[0], fast)


func test_wolves_break_sooner_than_men() -> void:
	# Same wounds and morale; the wolf's template "nerve" makes it run.
	var dice := Dice.new()
	dice.reseed(11)
	var wolf_runs := 0
	var man_runs := 0
	for i in range(300):
		var wolf := Actor.from_template("wolf")
		var man := Actor.from_template("brigand")
		for a in [wolf, man]:
			a.sheet.hp = a.sheet.max_hp() / 3
		if not CombatRules.morale_holds(wolf, 10, dice):
			wolf_runs += 1
		if not CombatRules.morale_holds(man, 10, dice):
			man_runs += 1
	check(wolf_runs > 100, "a hurt wolf usually runs")
	check(wolf_runs > man_runs * 2, "wolves run far sooner than brigands")


func test_trade_prices() -> void:
	var p := CharacterSheet.create("P", {"PRE": 5}, ["barter"])
	var t := CharacterSheet.create("T", {"PRE": 5}, [])
	check(Trade.buy_factor(p, t) >= 1.0)
	check(Trade.sell_factor(p, t) < 1.0)
	var mine := Inventory.new()
	mine.add("salt", 2)
	var theirs := Inventory.new()
	theirs.add("bronze_torque", 1)
	p.silver = 0
	eq(Trade.settle(mine, theirs, p, t), null, "can't afford")
	p.silver = 500
	var paid = Trade.settle(mine, theirs, p, t)
	check(paid is int and paid > 0)
