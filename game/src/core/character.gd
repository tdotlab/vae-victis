class_name CharacterSheet
extends RefCounted
## A character's permanent stats: attributes, skills, traits, perks, level,
## inventory and equipment. Used for the player, companions and NPCs.
## Pure data plus the rules that derive numbers from it.

const ATTR_IDS := ["STR", "END", "AGI", "PER", "WIT", "PRE", "FOR"]
const SLOTS := ["weapon", "shield", "armor", "helmet"]

var name := "Nameless"
var sex := "m"
var attrs: Dictionary = {}
var tags: Array = []
var skill_invested: Dictionary = {}  # skill id -> points of increase bought
var traits: Array = []
var perks: Array = []
var level := 1
var xp := 0
var unspent_skill_points := 0
var perks_owed := 0
var hp := 0
var silver := 0
var inventory := Inventory.new()
var equipment: Dictionary = {"weapon": "", "shield": "", "armor": "", "helmet": ""}
## Flat skill modifiers from story effects (e.g. a druid's teaching).
var skill_bonus: Dictionary = {}


func _init() -> void:
	var start: int = DB.rules()["attribute_start"]
	for a in ATTR_IDS:
		attrs[a] = start


static func create(p_name: String, p_attrs: Dictionary, p_tags: Array, p_traits: Array = []) -> CharacterSheet:
	var c := CharacterSheet.new()
	c.name = p_name
	for a in p_attrs:
		c.attrs[a] = int(p_attrs[a])
	c.tags = p_tags.duplicate()
	c.traits = p_traits.duplicate()
	c.hp = c.max_hp()
	return c


## Points left to spend during character creation (0 when valid).
static func creation_points_left(p_attrs: Dictionary) -> int:
	var r := DB.rules()
	var total: int = r["attribute_start"] * ATTR_IDS.size() + r["attribute_bonus_points"]
	var spent := 0
	for a in ATTR_IDS:
		spent += int(p_attrs.get(a, r["attribute_start"]))
	return total - spent


static func creation_errors(p_name: String, p_attrs: Dictionary, p_tags: Array, p_traits: Array) -> Array[String]:
	var r := DB.rules()
	var errs: Array[String] = []
	if p_name.strip_edges() == "":
		errs.append("Your character needs a name.")
	var left := creation_points_left(p_attrs)
	if left > 0:
		errs.append("You have %d attribute points left to spend." % left)
	elif left < 0:
		errs.append("You have spent %d attribute points too many." % -left)
	for a in ATTR_IDS:
		var v := int(p_attrs.get(a, 0))
		if v < r["attribute_min"] or v > r["attribute_max"]:
			errs.append("Attributes must be between %d and %d." % [r["attribute_min"], r["attribute_max"]])
			break
	if p_tags.size() != r["tag_count"]:
		errs.append("Tag exactly %d skills." % r["tag_count"])
	if p_traits.size() > r["max_traits"]:
		errs.append("At most %d traits." % r["max_traits"])
	return errs


func has_flag(flag: String) -> bool:
	for t in traits:
		if flag in DB.trait_def(t).get("flags", []):
			return true
	for p in perks:
		if flag in DB.perk_def(p).get("flags", []):
			return true
	return false


func _mods() -> Array:
	var out := []
	for t in traits:
		out.append(DB.trait_def(t).get("mods", {}))
	for p in perks:
		out.append(DB.perk_def(p).get("mods", {}))
	return out


func attr(id: String) -> int:
	var v: int = attrs.get(id, 5)
	for m in _mods():
		v += int(m.get("attributes", {}).get(id, 0))
	return clampi(v, 1, 10)


func _vars() -> Dictionary:
	var v := {}
	for a in ATTR_IDS:
		v[a] = attr(a)
	v["LVL"] = level
	return v


func skill_def(id: String) -> Dictionary:
	for s in DB.skill_defs():
		if s["id"] == id:
			return s
	return {}


func is_tagged(id: String) -> bool:
	return id in tags


func skill_base(id: String) -> int:
	var d := skill_def(id)
	if d.is_empty():
		push_error("Unknown skill " + id)
		return 0
	var v := Formula.eval_int(d["base"], _vars())
	if is_tagged(id):
		v += int(DB.rules()["tag_bonus"])
	return v


func skill(id: String) -> int:
	var v := skill_base(id)
	var inv: int = skill_invested.get(id, 0)
	v += inv * (2 if is_tagged(id) else 1)
	for m in _mods():
		v += int(m.get("skills", {}).get(id, 0))
	v += int(skill_bonus.get(id, 0))
	return clampi(v, 0, int(DB.rules()["skill_cap"]))


## Skill points needed to raise a skill by one step at its current value.
func skill_raise_cost(id: String) -> int:
	var v := skill(id)
	if v < 101:
		return 1
	if v < 126:
		return 2
	if v < 151:
		return 3
	if v < 176:
		return 4
	return 5


func can_raise_skill(id: String) -> bool:
	return skill(id) < int(DB.rules()["skill_cap"]) and unspent_skill_points >= skill_raise_cost(id)


func raise_skill(id: String) -> bool:
	if not can_raise_skill(id):
		return false
	unspent_skill_points -= skill_raise_cost(id)
	skill_invested[id] = int(skill_invested.get(id, 0)) + 1
	return true


func derived(key: String) -> int:
	var formula: String = DB.rules()["derived"].get(key, "0")
	var v := Formula.eval_int(formula, _vars())
	for m in _mods():
		v += int(m.get("derived", {}).get(key, 0))
	return v


func max_hp() -> int:
	var v := derived("max_hp") + (level - 1) * derived("hp_per_level")
	for m in _mods():
		v += int(m.get("derived_per_level", {}).get("max_hp", 0)) * level
	return v


func max_ap() -> int:
	return maxi(1, derived("ap"))


static func xp_for_level(n: int) -> int:
	return 1000 * n * (n - 1) / 2


## Adds experience. Returns the number of levels gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_for_level(level + 1):
		var old_max := max_hp()
		level += 1
		gained += 1
		unspent_skill_points += derived("skill_points")
		hp += max_hp() - old_max
		if level % int(DB.rules()["perk_every"]) == 0:
			perks_owed += 1
	return gained


func available_perks() -> Array:
	var out := []
	for p in DB.rules()["perks"]:
		if p["id"] in perks:
			continue
		if level >= int(p.get("level", 1)):
			out.append(p)
	return out


func take_perk(id: String) -> bool:
	if perks_owed <= 0 or id in perks:
		return false
	var d := DB.perk_def(id)
	if d.is_empty() or level < int(d.get("level", 1)):
		return false
	var old_max := max_hp()
	perks.append(id)
	perks_owed -= 1
	hp += max_hp() - old_max
	return true


# --- Equipment -------------------------------------------------------------

func equipped(slot: String) -> String:
	return equipment.get(slot, "")


func weapon_def() -> Dictionary:
	var w := equipped("weapon")
	if w == "":
		return DB.item("fists")
	return DB.item(w)


func slot_for(item_id: String) -> String:
	var t: String = DB.item(item_id).get("type", "")
	match t:
		"weapon":
			return "weapon"
		"shield":
			return "shield"
		"armor":
			return "armor"
		"helmet":
			return "helmet"
	return ""


func can_equip(item_id: String) -> bool:
	var slot := slot_for(item_id)
	if slot == "":
		return false
	if slot == "shield":
		var w := DB.item(equipped("weapon"))
		if w.get("two_handed", false):
			return false
	return true


## Moves an item from the inventory into its slot, swapping out whatever was there.
func equip(item_id: String) -> bool:
	if not can_equip(item_id) or inventory.count(item_id) <= 0:
		return false
	var slot := slot_for(item_id)
	unequip(slot)
	if slot == "weapon" and DB.item(item_id).get("two_handed", false):
		unequip("shield")
	inventory.remove(item_id, 1)
	equipment[slot] = item_id
	return true


func unequip(slot: String) -> void:
	var cur := equipped(slot)
	if cur != "":
		inventory.add(cur, 1)
		equipment[slot] = ""


func armor_values() -> Dictionary:
	## Damage threshold (flat) and resistance (percent) from worn gear.
	var dt := 0
	var dr := 0
	var defense := 0
	for slot in ["armor", "helmet"]:
		var it := DB.item(equipped(slot))
		dt += int(it.get("dt", 0))
		dr += int(it.get("dr", 0))
		defense += int(it.get("defense", 0))
	return {"dt": dt, "dr": mini(dr, 80), "defense": defense}


func carry_weight() -> float:
	var w := inventory.total_weight()
	for slot in SLOTS:
		w += float(DB.item(equipped(slot)).get("weight", 0))
	return w


func is_overloaded() -> bool:
	return carry_weight() > derived("carry")


# --- Saving ----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"name": name, "sex": sex, "attrs": attrs, "tags": tags,
		"skill_invested": skill_invested, "traits": traits, "perks": perks,
		"level": level, "xp": xp, "unspent_skill_points": unspent_skill_points,
		"perks_owed": perks_owed, "hp": hp, "silver": silver,
		"inventory": inventory.to_array(), "equipment": equipment,
		"skill_bonus": skill_bonus,
	}


static func from_dict(d: Dictionary) -> CharacterSheet:
	var c := CharacterSheet.new()
	c.name = d.get("name", "Nameless")
	c.sex = d.get("sex", "m")
	for a in d.get("attrs", {}):
		c.attrs[a] = int(d["attrs"][a])
	c.tags = d.get("tags", []).duplicate()
	for k in d.get("skill_invested", {}):
		c.skill_invested[k] = int(d["skill_invested"][k])
	c.traits = d.get("traits", []).duplicate()
	c.perks = d.get("perks", []).duplicate()
	c.level = int(d.get("level", 1))
	c.xp = int(d.get("xp", 0))
	c.unspent_skill_points = int(d.get("unspent_skill_points", 0))
	c.perks_owed = int(d.get("perks_owed", 0))
	c.hp = int(d.get("hp", 1))
	c.silver = int(d.get("silver", 0))
	c.inventory = Inventory.from_array(d.get("inventory", []))
	for s in SLOTS:
		c.equipment[s] = d.get("equipment", {}).get(s, "")
	for k in d.get("skill_bonus", {}):
		c.skill_bonus[k] = int(d["skill_bonus"][k])
	return c
