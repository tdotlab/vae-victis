extends SceneTree
## Combat arena: a headless balance check. Pits fresh player builds against
## every random encounter in data/world.json, thousands of times, and prints
## win rates. Usage (from the repo root):
##   tools/arena.sh                      every encounter, default builds
##   tools/arena.sh --runs=2000          more runs per cell (default 500)
##   tools/arena.sh --only=wolves        encounters whose id contains this
##   tools/arena.sh --turns              also print mean turns and hp left
##   tools/arena.sh --quest              the scripted quest fights instead,
##                                       at the levels a player meets them
##   tools/arena.sh --group=a,b,b --level=2   any group of templates
##   tools/arena.sh --allies=theron,aed_spear  friendly fighters beside the player
##                                       (also a quest fight's "allies")
##
## All the math comes from CombatRules, so tuning data/rules.json, items or
## NPCs shows up here at once. The turn loop is a stripped copy of
## CombatRunner's on an empty open field: no walls, no mud, no stealth, no
## flight for the player. If CombatRunner's rules change, mirror them here.
## Not a test (no test_ prefix), so the suite doesn't run it.

const START_DIST := 5      # hexes between the player and the nearest enemy
const MAX_ROUNDS := 60

# Fresh characters: 5 in everything plus 5 points, three tagged skills, and
# the story's starting gear (a dagger and nothing else) unless "gear" says more.
const BUILDS := {
	"fighter": {
		"attrs": {"STR": 7, "END": 7, "AGI": 6, "PER": 5, "WIT": 4, "PRE": 4, "FOR": 7},
		"tags": ["blades", "brawling", "survival"],
	},
	"balanced": {
		"attrs": {"STR": 6, "END": 6, "AGI": 6, "PER": 5, "WIT": 5, "PRE": 5, "FOR": 7},
		"tags": ["blades", "speech", "survival"],
	},
	"talker": {
		"attrs": {"STR": 4, "END": 5, "AGI": 6, "PER": 6, "WIT": 7, "PRE": 8, "FOR": 4},
		"tags": ["speech", "barter", "lore"],
	},
}
const GEARS := {
	"dagger": ["dagger"],
	"sword+shield": ["gallic_sword", "gallic_shield", "leather_jerkin"],
}

# The fights quests start (fight_all in dialogue), with every member of the
# faction on the map, and the levels a player usually has by then (Act I
# hands out roughly 3000-4000 xp: level 2 by mid-act, 3 near the end).
const QUEST_FIGHTS := {
	"ford riders": {"foes": ["haldo", "rider", "rider", "rider_archer", "rider"], "levels": [1, 2]},
	"grotto": {"foes": ["dubnacos", "grotto_bandit", "grotto_bandit", "grotto_slinger"], "levels": [1, 2]},
	"grotto wolves": {"foes": ["wolf", "wolf", "wolf"], "levels": [1, 2]},
	"atepomaros": {"foes": ["atepomaros", "cen_kinsman", "cen_kinsman"], "levels": [2, 3]},
	"depot watch": {"foes": ["nov_watch", "nov_watch", "nov_guard"], "levels": [2, 3]},
	"ava sentry": {"foes": ["legionary"], "levels": [2, 3]},
	"ava garrison": {"foes": ["legionary", "legionary", "legionary", "legionary", "legionary", "legionary", "legionary"], "levels": [2, 3]},
	"epomeduos": {"foes": ["epomeduos"], "levels": [2]},
}
# Where each build puts its skill points as it levels, and the perk it takes.
const GROWTH := {
	"fighter": {"skills": ["blades", "shield"], "perk": "toughened"},
	"balanced": {"skills": ["blades", "speech"], "perk": "quick_hands"},
	"talker": {"skills": ["speech", "barter"], "perk": "silver_tongue"},
}

var _dice := Dice.new()
var _level := 1
## Templates that fight on the player's side (--allies, or a quest fight's "allies").
var _allies: Array = []


func _initialize() -> void:
	var runs := 500
	var only := ""
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--turns":
			verbose = true
	var quest := OS.get_cmdline_user_args().has("--quest")
	var group := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--group="):
			group = a.substr(8)
		elif a.begins_with("--level="):
			_level = int(a.substr(8))
		elif a.begins_with("--allies="):
			_allies = Array(a.substr(9).split(",", false))
	if quest or group != "":
		_quest_table(runs, only, verbose, group)
		quit()
		return
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var encounters: Array = world.get("encounters", [])
	_dice.reseed(12345)
	var gear_names: Array = GEARS.keys()
	var head := "%-16s %-4s %-10s" % ["encounter", "wt", "foes"]
	for g in gear_names:
		for b in BUILDS:
			head += " %-13s" % (g.substr(0, 6) + "/" + b.substr(0, 5))
	print(head)
	for e in encounters:
		var id: String = e["id"]
		if only != "" and not id.contains(only):
			continue
		if not _has_hostile(e["actors"]):
			continue
		var line := "%-16s %-4s %-10s" % [id, str(e.get("weight", "")), _foes_label(e["actors"])]
		var extra := ""
		for g in gear_names:
			for b in BUILDS:
				var r := _run_cell(e["actors"], b, GEARS[g], runs)
				line += " %-13s" % ("%3d%%" % roundi(100.0 * r["wins"] / runs))
				if verbose:
					extra += "    %s/%s: %.1f turns, %.0f%% hp left when won\n" % [g, b, r["turns"], 100.0 * r["hp_left"]]
		print(line)
		if verbose:
			print(extra.trim_suffix("\n"))
	print("(win rate over %d runs per cell; foes start %d hexes away on open ground)" % [runs, START_DIST])
	quit()


## Quest fights (or one --group), one row per fight and level.
func _quest_table(runs: int, only: String, verbose: bool, group: String) -> void:
	_dice.reseed(12345)
	var fights := QUEST_FIGHTS
	if group != "":
		fights = {group: {"foes": Array(group.split(",")), "levels": [_level]}}
	var head := "%-15s %-3s" % ["fight", "lvl"]
	for g in GEARS:
		for b in BUILDS:
			head += " %-13s" % (g.substr(0, 6) + "/" + b.substr(0, 5))
	print(head)
	for id in fights:
		if only != "" and not id.contains(only):
			continue
		var allies_arg := _allies
		if fights[id].has("allies") and _allies.is_empty():
			_allies = fights[id]["allies"]
		for lvl in fights[id]["levels"]:
			_level = lvl
			var line := "%-15s %-3d" % [id, lvl]
			var extra := ""
			for g in GEARS:
				for b in BUILDS:
					var r := _run_cell(fights[id]["foes"], b, GEARS[g], runs, true)
					line += " %-13s" % ("%3d%%" % roundi(100.0 * r["wins"] / runs))
					if verbose:
						extra += "    %s/%s: %.1f turns, %.0f%% hp left when won
" % [g, b, r["turns"], 100.0 * r["hp_left"]]
			print(line)
			if verbose:
				print(extra.trim_suffix("
"))
		_allies = allies_arg
	print("(win rate over %d runs per cell; every foe hostile, %d hexes away on open ground)" % [runs, START_DIST])


func _has_hostile(actors: Array) -> bool:
	for t in actors:
		if DB.npc_template(t).get("hostile", false):
			return true
	return false


func _foes_label(actors: Array) -> String:
	var counts := {}
	for t in actors:
		counts[t] = int(counts.get(t, 0)) + 1
	var parts: Array[String] = []
	for t in counts:
		parts.append("%dx%s" % [counts[t], str(t).substr(0, 7)])
	return " ".join(parts)


func _run_cell(foe_templates: Array, build: String, gear: Array, runs: int, all_hostile := false) -> Dictionary:
	var wins := 0
	var turns := 0
	var hp_left := 0.0
	for i in range(runs):
		var r := _fight(foe_templates, build, gear, all_hostile)
		if r["won"]:
			wins += 1
			turns += r["rounds"]
			hp_left += r["hp_frac"]
	return {
		"wins": wins,
		"turns": float(turns) / maxf(1.0, wins),
		"hp_left": hp_left / maxf(1.0, wins),
	}


# --- One fight -----------------------------------------------------------------

func _fight(foe_templates: Array, build_id: String, gear: Array, all_hostile := false) -> Dictionary:
	var build: Dictionary = BUILDS[build_id]
	var player := Actor.new()
	player.is_player = true
	player.sheet = CharacterSheet.create("Hero", build["attrs"], build["tags"])
	_grow(player.sheet, build_id)
	for id in gear:
		player.sheet.inventory.add(id, 1)
		player.sheet.equip(id)
	player.sheet.hp = player.sheet.max_hp()
	player.cell = Vector2i(0, 0)
	var foes: Array = []
	var spot := 0
	for t in foe_templates:
		var f := Actor.from_template(t)
		if all_hostile:
			f.hostile = true
		if not f.hostile:
			continue  # peaceful travellers don't join the fight
		f.cell = _spawn_cell(player.cell, spot)
		spot += 1
		foes.append(f)
	var order: Array = [player]
	order.append_array(foes)
	# Allies start beside the player and play by the same simple plan.
	var side := 0
	for t in _allies:
		var al := Actor.from_template(t)
		al.hostile = false
		al.ally = true
		al.cell = Hex.neighbor(player.cell, (side * 2) % 6)
		side += 1
		order.append(al)
	order = CombatRules.turn_order(order)
	order.erase(player)
	order.push_front(player)  # the player starts the fight, as in the game
	var round_no := 0
	while round_no < MAX_ROUNDS:
		round_no += 1
		for a in order:
			if not a.is_active() or a.has_meta("broken"):
				if a.unconscious and round_no >= int(a.get_meta("wake_round", 0)):
					a.unconscious = false
				continue
			a.ap = a.sheet.max_ap()
			a.bonus_defense = 0
			if a.knocked_down:
				a.knocked_down = false
				a.ap = maxi(0, a.ap - 2)
			_turn(a, order, round_no)
			a.bonus_defense = a.ap * 2
			if not player.is_active():
				return {"won": false, "rounds": round_no, "hp_frac": 0.0}
			if _over(order):
				return {"won": true, "rounds": round_no,
					"hp_frac": float(player.sheet.hp) / player.sheet.max_hp()}
	return {"won": false, "rounds": round_no, "hp_frac": 0.0}


## Levels the sheet up to _level the way that build would spend it.
func _grow(sheet: CharacterSheet, build_id: String) -> void:
	if _level <= 1:
		return
	sheet.add_xp(CharacterSheet.xp_for_level(_level))
	var g: Dictionary = GROWTH[build_id]
	var guard := 0
	while sheet.unspent_skill_points > 0 and guard < 400:
		guard += 1
		var raised := false
		for sk in g["skills"]:
			if sheet.raise_skill(sk):
				raised = true
		if not raised:
			break
	if sheet.perks_owed > 0:
		sheet.take_perk(g["perk"])


func _over(order: Array) -> bool:
	for a in order:
		if a.hostile and a.is_active() and not a.has_meta("broken"):
			return false
	return true


## Foes start on a ring START_DIST hexes out, spread around.
func _spawn_cell(center: Vector2i, i: int) -> Vector2i:
	var c := center
	for k in range(START_DIST):
		c = Hex.neighbor(c, (i * 2 + 1) % 6 if k == 0 else (i * 2 + 1 + (k % 2)) % 6)
	return c


func _occupied(order: Array, except: Actor) -> Dictionary:
	var occ := {}
	for o in order:
		if o != except and not o.dead and not o.fled:
			occ[o.cell] = true
	return occ


func _nearest_foe(a: Actor, order: Array) -> Actor:
	var best: Actor = null
	var bd := 9999
	for o in order:
		if o == a or not o.is_active() or o.has_meta("broken") or o.hostile == a.hostile:
			continue
		var d := Hex.distance(a.cell, o.cell)
		if d < bd:
			bd = d
			best = o
	return best


## The same simple plan for both sides: close in, hit until the points run out.
## Unspent points stay as defense.
func _turn(a: Actor, order: Array, round_no: int) -> void:
	var guard := 0
	while a.ap > 0 and guard < 30:
		guard += 1
		var t := _nearest_foe(a, order)
		if t == null:
			return
		var w := a.sheet.weapon_def()
		var dist := Hex.distance(a.cell, t.cell)
		if dist <= CombatRules.weapon_range(w):
			if CombatRules.attack_ap(w, false) > a.ap:
				return
			_attack(a, t, w, order, round_no)
			if not t.is_active() and _over(order):
				return
			if not a.is_active():
				return
			continue
		var occ := _occupied(order, a)
		var best := a.cell
		var bd := dist
		for n in Hex.neighbors(a.cell):
			if occ.has(n):
				continue
			var d := Hex.distance(n, t.cell)
			if d < bd:
				bd = d
				best = n
		if best == a.cell or a.ap < 1:
			return
		a.ap -= 1
		a.facing = Hex.direction_to(a.cell, best)
		a.cell = best


func _attack(att: Actor, def: Actor, w: Dictionary, order: Array, round_no: int) -> void:
	att.ap -= CombatRules.attack_ap(w, false)
	att.facing = Hex.direction_to(att.cell, def.cell)
	var dist := Hex.distance(att.cell, def.cell)
	var chance := CombatRules.hit_chance(att, def, w, dist)
	var roll := _dice.d100()
	if roll > chance:
		if roll > 100 - CombatRules.fumble_chance(att):
			att.ap = 0
		return
	var crit := _dice.chance(CombatRules.crit_chance(att))
	if not crit and CombatRules.shield_covers(def, att.cell) and _dice.chance(def.shield_block()):
		return
	var r := CombatRules.roll_damage(att, def, w, "torso", crit, _dice)
	var d: int = r["damage"]
	def.sheet.hp -= d
	if def.sheet.hp <= 0:
		def.sheet.hp = 0
		def.dead = true
		if not def.is_player:
			_kill_shock(def, order)
		return
	_effect(def, r["effect"], round_no)
	if not def.is_player and not def.has_meta("broken"):
		if not CombatRules.morale_holds(def, d * 2, _dice):
			def.set_meta("broken", true)


func _kill_shock(dead: Actor, order: Array) -> void:
	for o in order:
		if o == dead or not o.is_active() or o.is_player or o.has_meta("broken"):
			continue
		var shock := int(DB.rules().get("kill_shock", 10)) + (int(DB.rules().get("leader_shock", 50)) if dead.leader else 0)
		if o.faction == dead.faction and not CombatRules.morale_holds(o, shock, _dice):
			o.set_meta("broken", true)


func _effect(def: Actor, effect: String, round_no: int) -> void:
	match effect:
		"knockdown":
			def.knocked_down = true
		"leg":
			def.crippled["leg"] = true
		"arm":
			def.crippled["arms"] = true
		"disarm":
			def.sheet.unequip("weapon")
		"eyes":
			def.crippled["eyes"] = true
		"knockout":
			def.unconscious = true
			def.set_meta("wake_round", round_no + 3)
