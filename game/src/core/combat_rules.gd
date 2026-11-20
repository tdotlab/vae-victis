class_name CombatRules
extends RefCounted
## Pure combat math: hit chances, damage, criticals, shields, morale.
## No scenes, no animation; the CombatRunner calls these and shows the result.

const AIM_PENALTY := {"torso": 0, "head": 40, "eyes": 60, "arms": 30, "legs": 20, "groin": 30}
const AIM_CRIT_BONUS := {"torso": 0, "head": 15, "eyes": 25, "arms": 5, "legs": 5, "groin": 10}
const AIM_NAMES := {"torso": "body", "head": "head", "eyes": "eyes", "arms": "arm", "legs": "leg", "groin": "groin"}
const RANGED_PENALTY_PER_HEX := 4


static func is_ranged(w: Dictionary) -> bool:
	return w.get("skill", "") == "missiles"


static func attack_ap(w: Dictionary, aimed: bool) -> int:
	return int(w.get("ap", 3)) + (1 if aimed else 0)


static func weapon_range(w: Dictionary) -> int:
	return int(w.get("range", 1))


## Can this attacker use this weapon right now (ammo, thrown weapon in hand)?
static func has_ammo(a: Actor, w: Dictionary) -> bool:
	if w.has("ammo"):
		return a.sheet.inventory.count(w["ammo"]) > 0
	return true


## Percent chance to hit, 0 if impossible (out of range).
static func hit_chance(att: Actor, def: Actor, w: Dictionary, dist: int, aim: String = "torso", cover: int = 0) -> int:
	if dist > weapon_range(w):
		return 0
	var c := att.sheet.skill(w.get("skill", "brawling")) + int(w.get("acc", 0))
	c -= def.defense()
	c -= int(AIM_PENALTY.get(aim, 0))
	if is_ranged(w):
		# Perception extends the comfortable range.
		var easy := maxi(1, att.sheet.attr("PER") - 2)
		c -= maxi(0, dist - easy) * RANGED_PENALTY_PER_HEX
		c -= cover
	if att.crippled.has("eyes"):
		c -= 25
	if att.crippled.has("arm_r") or att.crippled.has("arms"):
		c -= 15
	if def.knocked_down and not is_ranged(w):
		c += 15
	return clampi(c, 5, 95)


static func crit_chance(att: Actor, aim: String = "torso") -> int:
	var c := att.sheet.derived("crit") + int(AIM_CRIT_BONUS.get(aim, 0))
	if att.sheet.has_flag("gods_touched"):
		c *= 3
	return clampi(c, 0, 95)


## Chance that a miss is a fumble (dropped weapon, lost footing).
static func fumble_chance(att: Actor) -> int:
	var c := maxi(0, 6 - att.sheet.attr("FOR"))
	if att.sheet.has_flag("gods_touched"):
		c *= 3
	return c


## True if the defender faces the attacker closely enough to use a shield.
## Shields cover the facing direction and the two beside it.
static func shield_covers(def: Actor, att_cell: Vector2i) -> bool:
	if def.sheet.equipped("shield") == "" or def.shield_fouled or def.knocked_down:
		return false
	if att_cell == def.cell:
		return false
	var d := Hex.direction_to(def.cell, att_cell)
	var diff := absi(d - def.facing) % 6
	diff = mini(diff, 6 - diff)
	return diff <= 1


## Rolls damage after armor. Returns {"damage", "crit", "effect"}.
static func roll_damage(att: Actor, def: Actor, w: Dictionary, aim: String, crit: bool, dice: Dice) -> Dictionary:
	var dmg: Array = w.get("dmg", [1, 2])
	var base := dice.range_i(int(dmg[0]), int(dmg[1]))
	if not is_ranged(w) or w.get("thrown", false):
		base += att.sheet.derived("melee_bonus")
	var armor := def.sheet.armor_values()
	var dt := int(armor["dt"])
	var dr := int(armor["dr"])
	if aim == "eyes" or aim == "head" and def.sheet.equipped("helmet") == "":
		dt = dt / 2
	var effect := ""
	if crit:
		base = int(base * (2.0 if aim in ["head", "eyes"] else 1.5))
		dt = dt / 2
		effect = _crit_effect(aim, dice)
	var d := maxi(0, base - dt)
	d = int(round(d * (100 - dr) / 100.0))
	if crit:
		d = maxi(d, 1)
	return {"damage": d, "crit": crit, "effect": effect}


static func _crit_effect(aim: String, dice: Dice) -> String:
	match aim:
		"legs":
			return "leg" if dice.chance(60) else "knockdown"
		"arms":
			return "arm" if dice.chance(60) else "disarm"
		"eyes":
			return "eyes" if dice.chance(50) else "knockdown"
		"head":
			return "knockout" if dice.chance(30) else "knockdown"
		"groin":
			return "knockdown"
	return "knockdown" if dice.chance(25) else ""


## AP spent moving into a cell.
static func move_ap(map: MapData, c: Vector2i, a: Actor) -> int:
	var cost := map.move_cost(c)
	if a.crippled.has("leg") or a.crippled.has("leg_l") or a.crippled.has("leg_r"):
		cost += 1
	return cost


## Morale test: true if the actor holds. Morale drops with wounds and fallen friends.
static func morale_holds(a: Actor, shock: int, dice: Dice) -> bool:
	a.morale -= shock
	var hp_frac := float(a.sheet.hp) / maxf(1.0, float(a.sheet.max_hp()))
	if hp_frac > 0.5 and a.morale > 40:
		return true
	var nerve := a.morale + a.sheet.attr("END") * 3 + a.sheet.attr("PRE") * 2
	# Animals and the like carry a template "nerve" modifier: a wolf has no
	# stake in your purse and runs once it's hurt.
	nerve += int(DB.npc_template(a.template).get("nerve", 0))
	return dice.chance(clampi(nerve, 5, 95))


## Order of turns: Sequence (2*PER) high first, player wins ties.
static func turn_order(actors: Array) -> Array:
	var arr := actors.duplicate()
	arr.sort_custom(func(x: Actor, y: Actor):
		var sx := x.sheet.derived("sequence")
		var sy := y.sheet.derived("sequence")
		if sx != sy:
			return sx > sy
		return x.is_player and not y.is_player)
	return arr
