extends TestCase


func _default() -> CharacterSheet:
	var attrs := {"STR": 6, "END": 6, "AGI": 6, "PER": 6, "WIT": 6, "PRE": 5, "FOR": 5}
	return CharacterSheet.create("Test", attrs, ["blades", "speech", "sneak"])


func test_creation_points() -> void:
	var a := {"STR": 5, "END": 5, "AGI": 5, "PER": 5, "WIT": 5, "PRE": 5, "FOR": 5}
	eq(CharacterSheet.creation_points_left(a), 5)
	a["STR"] = 10
	eq(CharacterSheet.creation_points_left(a), 0)
	eq(CharacterSheet.creation_errors("X", a, ["blades", "spears", "lore"], []).size(), 0)
	check(CharacterSheet.creation_errors("", a, ["blades"], []).size() >= 2)


func test_skill_formulas_and_tags() -> void:
	var c := _default()
	# blades: 10 + 2*(6+6) = 34, tagged +20
	eq(c.skill("blades"), 54)
	# spears: 10 + 2*(6+6) = 34, untagged
	eq(c.skill("spears"), 34)
	# latin: 2*WIT = 12
	eq(c.skill("latin"), 12)


func test_derived() -> void:
	var c := _default()
	eq(c.max_hp(), 15 + 6 + 12)
	eq(c.max_ap(), 8)
	eq(c.derived("sequence"), 12)
	eq(c.derived("melee_bonus"), 1)
	eq(c.hp, c.max_hp())


func test_traits_modify() -> void:
	var a := {"STR": 6, "END": 6, "AGI": 6, "PER": 6, "WIT": 6, "PRE": 5, "FOR": 5}
	var c := CharacterSheet.create("T", a, ["blades", "speech", "sneak"], ["once_sold", "saddle_born"])
	eq(c.skill("latin"), 27)
	eq(c.max_ap(), 7)
	check(c.has_flag("branded"))
	check(not c.has_flag("proud"))


func test_leveling() -> void:
	var c := _default()
	eq(CharacterSheet.xp_for_level(2), 1000)
	eq(CharacterSheet.xp_for_level(3), 3000)
	var hp_before := c.max_hp()
	eq(c.add_xp(999), 0)
	eq(c.add_xp(2001), 2)
	eq(c.level, 3)
	eq(c.unspent_skill_points, 2 * (5 + 12))
	eq(c.perks_owed, 1)
	eq(c.max_hp(), hp_before + 2 * 6)
	check(c.take_perk("toughened"))
	eq(c.max_hp(), hp_before + 2 * 6 + 3 * 4)


func test_raise_skill_tagged_doubles() -> void:
	var c := _default()
	c.unspent_skill_points = 10
	var before := c.skill("blades")
	check(c.raise_skill("blades"))
	eq(c.skill("blades"), before + 2)
	var sp := c.skill("spears")
	check(c.raise_skill("spears"))
	eq(c.skill("spears"), sp + 1)
	eq(c.unspent_skill_points, 8)


func test_equipment_and_inventory() -> void:
	var c := _default()
	c.inventory.add("gallic_sword")
	c.inventory.add("gallic_shield")
	c.inventory.add("war_spear")
	check(c.equip("gallic_sword"))
	check(c.equip("gallic_shield"))
	eq(c.equipped("weapon"), "gallic_sword")
	eq(c.inventory.count("gallic_sword"), 0)
	# Two-handed spear knocks the shield off.
	check(c.equip("war_spear"))
	eq(c.equipped("shield"), "")
	eq(c.inventory.count("gallic_shield"), 1)
	eq(c.inventory.count("gallic_sword"), 1)
	check(not c.can_equip("gallic_shield"))


func test_save_round_trip() -> void:
	var c := _default()
	c.inventory.add("herbs", 3)
	c.silver = 42
	c.add_xp(1500)
	var d := c.to_dict()
	var c2 := CharacterSheet.from_dict(JSON.parse_string(JSON.stringify(d)))
	eq(c2.skill("blades"), c.skill("blades"))
	eq(c2.inventory.count("herbs"), 3)
	eq(c2.silver, 42)
	eq(c2.level, 2)
	eq(c2.max_hp(), c.max_hp())
