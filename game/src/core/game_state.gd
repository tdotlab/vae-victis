class_name GameState
extends RefCounted
## Everything that makes up a saved game. Pure data.

const SAVE_VERSION := 1
## In-game clock starts at dawn of day 1.
const START_MINUTES := 7 * 60

var player: CharacterSheet
var companions: Array = []     # Array of Actor state dicts traveling with the player
var flags: Dictionary = {}     # story flags, name -> int
var quests: Dictionary = {}    # quest id -> {"stage": String, "status": "active"|"done"|"failed"}
var quest_log: Array = []      # [{"day": int, "quest": id, "text": String}]
var minutes := START_MINUTES
var honor := 0
var renown := 0
var standing: Dictionary = {}  # faction -> int
var map_id := ""
var entry := "start"           # mark name to place the player on map entry
var map_states: Dictionary = {}  # map id -> {"actors": {uid: state}, "containers": {...}, "taken": [...]}
var world_pos := Vector2i.ZERO
var known_locations: Array = []
var titles: Array = []
var messages: Array = []       # recent log lines, for the HUD
var dice := Dice.new()


func day() -> int:
	return minutes / 1440 + 1


func hour() -> int:
	return (minutes / 60) % 24


func advance(mins: int) -> void:
	minutes += maxi(0, mins)


func flag(name_: String) -> int:
	return int(flags.get(name_, 0))


func set_flag(name_: String, v: int = 1) -> void:
	flags[name_] = v


func quest_status(qid: String) -> String:
	return quests.get(qid, {}).get("status", "")


func quest_stage(qid: String) -> String:
	return quests.get(qid, {}).get("stage", "")


func set_quest(qid: String, stage: String, status: String = "active") -> void:
	quests[qid] = {"stage": stage, "status": status}


func add_standing(faction: String, amount: int) -> void:
	standing[faction] = int(standing.get(faction, 0)) + amount


func get_standing(faction: String) -> int:
	return int(standing.get(faction, 0))


func season() -> String:
	var d := day()
	if d <= 45:
		return "winter"
	if d <= 135:
		return "spring"
	if d <= 230:
		return "summer"
	return "autumn"


func date_text() -> String:
	return "Day %d, %s, %02d:%02d" % [day(), season(), hour(), minutes % 60]


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player": player.to_dict(),
		"companions": companions,
		"flags": flags, "quests": quests, "quest_log": quest_log,
		"minutes": minutes, "honor": honor, "renown": renown,
		"standing": standing, "map_id": map_id, "entry": entry,
		"map_states": map_states,
		"world_pos": [world_pos.x, world_pos.y],
		"known_locations": known_locations, "titles": titles,
		"dice_state": str(dice.get_state()),
	}


static func from_dict(d: Dictionary) -> GameState:
	var g := GameState.new()
	g.player = CharacterSheet.from_dict(d["player"])
	g.companions = d.get("companions", [])
	g.flags = d.get("flags", {})
	for k in g.flags:
		g.flags[k] = int(g.flags[k])
	g.quests = d.get("quests", {})
	g.quest_log = d.get("quest_log", [])
	g.minutes = int(d.get("minutes", START_MINUTES))
	g.honor = int(d.get("honor", 0))
	g.renown = int(d.get("renown", 0))
	g.standing = d.get("standing", {})
	g.map_id = d.get("map_id", "")
	g.entry = d.get("entry", "start")
	g.map_states = d.get("map_states", {})
	var wp: Array = d.get("world_pos", [0, 0])
	g.world_pos = Vector2i(int(wp[0]), int(wp[1]))
	g.known_locations = d.get("known_locations", [])
	g.titles = d.get("titles", [])
	if d.has("dice_state"):
		g.dice.set_state(int(d["dice_state"]))
	return g
