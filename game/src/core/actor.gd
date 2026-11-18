class_name Actor
extends RefCounted
## A character standing on a local map: the player, a companion, a villager,
## an enemy. Holds a CharacterSheet plus everything that only matters while
## on a map (position, facing, combat state).

var uid := ""
var template := ""
var sheet: CharacterSheet
var cell := Vector2i.ZERO
var facing := 0
var faction := "neutral"
var hostile := false
var is_player := false
var is_companion := false
var dialogue := ""
var desc := ""
var ai := "idle"          # idle, wander, guard, follow
var home := Vector2i.ZERO
var look: Dictionary = {}  # tunic, skin, hair colors etc. for placeholder drawing
var dead := false
var fled := false
var unconscious := false

# Combat state
var ap := 0
var bonus_defense := 0
var shield_fouled := false
var knocked_down := false
var crippled: Dictionary = {}  # "arm_l", "arm_r", "leg_l", "leg_r", "eyes"
var morale := 100
var leader := false
var in_combat := false


func is_active() -> bool:
	return not dead and not fled and not unconscious


func display_name() -> String:
	return sheet.name


func max_hp() -> int:
	return sheet.max_hp()


func hp() -> int:
	return sheet.hp


func health_word() -> String:
	if dead:
		return "dead"
	var f := float(sheet.hp) / maxf(1.0, float(sheet.max_hp()))
	if f >= 0.95:
		return "unhurt"
	if f >= 0.7:
		return "lightly wounded"
	if f >= 0.4:
		return "wounded"
	if f >= 0.15:
		return "badly wounded"
	return "near death"


func shield_block() -> int:
	var s := sheet.equipped("shield")
	if s == "" or shield_fouled:
		return 0
	return int(DB.item(s).get("block", 0)) + sheet.skill("shield") / 5


func defense() -> int:
	var d: int = sheet.derived("defense") + int(sheet.armor_values()["defense"]) + bonus_defense
	var s := sheet.equipped("shield")
	if s != "" and not shield_fouled:
		d += int(DB.item(s).get("defense", 0))
	if knocked_down:
		d -= 10
	return d


## Build an actor from an NPC template in data/npcs.json.
static func from_template(tid: String, uid_: String = "") -> Actor:
	var t := DB.npc_template(tid)
	var a := Actor.new()
	if t.is_empty():
		push_error("Unknown NPC template " + tid)
		t = {"name": tid}
	a.template = tid
	a.uid = uid_ if uid_ != "" else tid
	var attrs: Dictionary = t.get("attrs", {})
	a.sheet = CharacterSheet.create(t.get("name", tid), attrs, t.get("tags", []), t.get("traits", []))
	a.sheet.sex = t.get("sex", "m")
	var lvl := int(t.get("level", 1))
	if lvl > 1:
		a.sheet.add_xp(CharacterSheet.xp_for_level(lvl))
	for sk in t.get("skills", {}):
		a.sheet.skill_bonus[sk] = int(t["skills"][sk])
	for e in t.get("items", []):
		if e is Array:
			a.sheet.inventory.add(e[0], int(e[1]))
		else:
			a.sheet.inventory.add(str(e), 1)
	for e in t.get("equip", []):
		a.sheet.inventory.add(e, 1)
		a.sheet.equip(e)
	a.sheet.silver = int(t.get("silver", 0))
	a.sheet.hp = a.sheet.max_hp()
	if t.has("hp"):
		a.sheet.hp = int(t["hp"])
	a.faction = t.get("faction", "neutral")
	a.hostile = t.get("hostile", false)
	a.dialogue = t.get("dialogue", "")
	a.desc = t.get("desc", "")
	a.ai = t.get("ai", "idle")
	a.look = t.get("look", {})
	a.leader = t.get("leader", false)
	return a


func state_dict() -> Dictionary:
	## The part of an actor that persists when you leave and return to a map.
	return {
		"uid": uid, "template": template, "cell": [cell.x, cell.y], "facing": facing,
		"hostile": hostile, "dead": dead, "fled": fled, "unconscious": unconscious,
		"sheet": sheet.to_dict(), "faction": faction, "dialogue": dialogue,
		"ai": ai, "home": [home.x, home.y], "is_companion": is_companion,
	}


func apply_state(d: Dictionary) -> void:
	cell = Vector2i(int(d["cell"][0]), int(d["cell"][1]))
	facing = int(d.get("facing", 0))
	hostile = d.get("hostile", hostile)
	dead = d.get("dead", false)
	fled = d.get("fled", false)
	unconscious = d.get("unconscious", false)
	sheet = CharacterSheet.from_dict(d["sheet"])
	faction = d.get("faction", faction)
	dialogue = d.get("dialogue", dialogue)
	ai = d.get("ai", ai)
	home = Vector2i(int(d["home"][0]), int(d["home"][1])) if d.has("home") else cell
	is_companion = d.get("is_companion", false)
