class_name CombatRunner
extends Node
## Runs turn-based combat on a LocalMap: turn order, action points, player
## orders, enemy and companion AI, and the animation hand-offs. The math lives
## in CombatRules.

signal _player_done

var map: LocalMap
var active := false
var current: Actor
var order: Array = []
var round_no := 0
var acting := false                # an attack or move is animating
var _cached_hover := Vector2i(-9999, -9999)
var _cached_path: Array[Vector2i] = []


func dice() -> Dice:
	return Game.state.dice


# --- Starting and ending --------------------------------------------------------

func start_combat(initiator: Actor, target: Actor = null) -> void:
	if active:
		return
	active = true
	round_no = 0
	map.path_preview.clear()
	var participants: Array = []
	for a in map.actors:
		if not a.is_active():
			continue
		if a.is_player or a.is_companion:
			participants.append(a)
		elif a.hostile and _aware(a):
			participants.append(a)
	if target and not participants.has(target):
		participants.append(target)
	# Their friends hear the fight and come, even without seeing you.
	for a in map.actors:
		if a.is_active() and a.hostile and not participants.has(a) and _hears_friends(a, participants):
			participants.append(a)
	for a in participants:
		_join(a)
	order = CombatRules.turn_order(participants)
	# Whoever started the fight gets the first turn.
	order.erase(initiator)
	order.push_front(initiator)
	Game.say("Combat!", "bad")
	Game.hint("hint_fight")
	map.hud.refresh()
	_run.call_deferred()


func _aware(a: Actor) -> bool:
	for o in map.actors:
		if (o.is_player or o.is_companion) and o.is_active():
			if map.can_see(a, o) or Hex.distance(a.cell, o.cell) <= 3:
				return true
	return false


## True if a hostile who hasn't noticed the player has a same-faction friend
## already fighting within earshot.
func _hears_friends(a: Actor, fighters: Array) -> bool:
	for o in fighters:
		if o != a and o.hostile and o.is_active() and o.faction == a.faction and Hex.distance(a.cell, o.cell) <= 10:
			return true
	return false


func _join(a: Actor) -> void:
	a.in_combat = true
	a.bonus_defense = 0
	a.morale = 100
	if not order.has(a) and active and order.size() > 0:
		order.append(a)


func _end_combat() -> void:
	active = false
	current = null
	for a in map.actors:
		a.in_combat = false
		a.bonus_defense = 0
		a.shield_fouled = false
		a.knocked_down = false
		a.ap = 0
		if a.unconscious and not a.dead:
			a.unconscious = false
		if a.has_meta("broken"):
			a.remove_meta("broken")
	_note_wiped_factions()
	Game.say("The fighting is over.")
	map.busy = false
	map.hud.refresh()
	map.save_map_state()


## Sets wiped_<faction> when every member of a faction on this map is dead,
## so quests can notice a clean kill without the player carrying proof.
func _note_wiped_factions() -> void:
	var seen := {}
	for a in map.actors:
		if a.faction == "neutral" or a.is_player or a.is_companion:
			continue
		seen[a.faction] = bool(seen.get(a.faction, true)) and a.dead
	for f in seen:
		if seen[f]:
			Game.state.set_flag("wiped_" + f)


func can_end_combat() -> bool:
	for a in order:
		if a.hostile and a.is_active() and Hex.distance(a.cell, map.player.cell) <= 10 and map.has_line_of_sight_between(a, map.player):
			return false
	return true


func request_end() -> void:
	if not active or current != map.player or acting:
		return
	if can_end_combat():
		_end_combat()
		_player_done.emit()
	else:
		Game.say("There are still enemies close by.", "bad")


func _fight_over() -> bool:
	if not map.player.is_active():
		return true
	for a in order:
		if a.hostile and a.is_active() and not a.has_meta("broken"):
			return false
	return true


# --- The turn loop -----------------------------------------------------------

func _run() -> void:
	while active:
		round_no += 1
		_recruit_newly_aware()
		for a in order.duplicate():
			if not active:
				return
			if a.dead or a.fled:
				continue
			if a.unconscious:
				if round_no >= int(a.get_meta("wake_round", 0)):
					a.unconscious = false
					Game.say("%s comes to." % a.display_name())
				continue
			current = a
			a.ap = a.sheet.max_ap()
			a.bonus_defense = 0
			if a.knocked_down:
				a.knocked_down = false
				a.ap = maxi(0, a.ap - 2)
			map.hud.refresh()
			if a.is_player:
				await _player_done
				if not active:
					return
			else:
				await get_tree().create_timer(0.2).timeout
				await _ai_turn(a)
			# Unused action points make you harder to hit until your next turn.
			a.bonus_defense = a.ap * 2
			if not map.player.is_active():
				_player_died()
				return
			if _fight_over():
				_end_combat()
				return
		order = order.filter(func(x: Actor): return not x.fled)


func _recruit_newly_aware() -> void:
	for a in map.actors:
		if a.hostile and a.is_active() and not order.has(a) and (_aware(a) or _hears_friends(a, order)):
			_join(a)
			order.append(a)


func player_end_turn() -> void:
	if active and current == map.player and not acting:
		_player_done.emit()


func _player_died() -> void:
	active = false
	Game.say("You die.", "bad")
	await get_tree().create_timer(1.5).timeout
	Game.goto("death", {"text": DB.text_file("text/death.txt")})


# --- Player orders -------------------------------------------------------------

func on_click(c: Vector2i, button: int) -> void:
	if current != map.player or acting:
		return
	var target := map.actor_at(c)
	if target and target != map.player and not target.is_companion:
		if button == MOUSE_BUTTON_RIGHT:
			map.hud.open_aim(target)
		else:
			player_attack(target, "torso")
		return
	if button == MOUSE_BUTTON_RIGHT:
		map.examine(c)
		return
	if not map.is_walkable_free(c):
		return
	var path := Pathfinder.find_path(map.map, map.player.cell, c, map.occupied(map.player))
	if path.is_empty():
		return
	acting = true
	for step in path:
		var cost := CombatRules.move_ap(map.map, step, map.player)
		if cost > map.player.ap or map.actor_at(step) != null:
			break
		map.player.ap -= cost
		await map.step_actor(map.player, step, map.COMBAT_STEP_TIME)
		map.hud.refresh()
	acting = false
	_cached_hover = Vector2i(-9999, -9999)
	if map.exit_at(map.player.cell).size() > 0 and can_end_combat():
		Game.say("You slip away from the fight.")
		_end_combat()
		_player_done.emit()
		map.take_exit(map.exit_at(map.player.cell))


func player_attack(target: Actor, aim: String) -> void:
	if acting or current != map.player:
		return
	var w := map.player.sheet.weapon_def()
	var reason := attack_blocker(map.player, target, w, aim)
	if reason != "":
		Game.say(reason)
		return
	acting = true
	await attack(map.player, target, w, aim)
	acting = false
	map.hud.refresh()
	if not active:
		return
	if _fight_over():
		_end_combat()
		_player_done.emit()


## Why this attack can't happen right now, or "" if it can.
func attack_blocker(att: Actor, target: Actor, w: Dictionary, aim: String) -> String:
	var dist := Hex.distance(att.cell, target.cell)
	if CombatRules.attack_ap(w, aim != "torso") > att.ap:
		return "Not enough action points."
	if dist > CombatRules.weapon_range(w):
		return "Out of range."
	if not CombatRules.has_ammo(att, w):
		return "You have nothing to shoot."
	if CombatRules.is_ranged(w) and not map.map.has_line_of_sight(att.cell, target.cell):
		return "You don't have a clear shot."
	return ""


func cover_between(att: Actor, def: Actor) -> int:
	var l := Hex.line(att.cell, def.cell)
	if l.size() < 3:
		return 0
	var before: Vector2i = l[l.size() - 2]
	var c := int(map.map.terrain_at(before).get("cover", 0))
	if map.actor_at(before) != null:
		c += 15
	return c


func chance_for(att: Actor, def: Actor, w: Dictionary, aim: String) -> int:
	var dist := Hex.distance(att.cell, def.cell)
	var cov := cover_between(att, def) if CombatRules.is_ranged(w) else 0
	return CombatRules.hit_chance(att, def, w, dist, aim, cov)


# --- Resolving an attack -------------------------------------------------------

func attack(att: Actor, def: Actor, w: Dictionary, aim: String = "torso") -> void:
	att.ap -= CombatRules.attack_ap(w, aim != "torso")
	map.face(att, def.cell)
	var chance := chance_for(att, def, w, aim)
	var thrown: bool = w.get("thrown", false)
	if w.has("ammo"):
		att.sheet.inventory.remove(w["ammo"], 1)
	if thrown:
		_consume_thrown(att, w)
	if att.is_player and not def.hostile and not def.is_companion:
		provoke(def)
	if CombatRules.is_ranged(w):
		await map.shoot(att.cell, def.cell)
	else:
		await map.lunge(att, def.cell)
	var who := att.display_name()
	var whom := def.display_name()
	var part: String = CombatRules.AIM_NAMES.get(aim, "body")
	var roll := dice().d100()
	if roll > chance:
		map.float_text(def.cell, "miss", Color(0.85, 0.85, 0.8))
		if roll > 100 - CombatRules.fumble_chance(att):
			Game.say("%s stumbles and loses the moment." % who, "bad" if att.is_player else "info")
			att.ap = 0
		else:
			Game.say("%s misses %s." % [who, whom])
		return
	var crit := dice().chance(CombatRules.crit_chance(att, aim))
	if not crit and CombatRules.shield_covers(def, att.cell) and dice().chance(def.shield_block()):
		map.float_text(def.cell, "blocked", Color(0.8, 0.75, 0.55))
		Game.say("%s takes %s's blow on the shield." % [whom, who])
		var sb := int(w.get("shield_breaker", 0))
		if sb > 0 and dice().chance(sb):
			def.shield_fouled = true
			Game.say("The %s sticks fast in %s's shield. It's dead weight now." % [DB.lc_first(str(w.get("name", "weapon"))), whom], "good" if att.is_player else "bad")
		if thrown:
			def.sheet.inventory.add(w["id"], 1)
		return
	var r := CombatRules.roll_damage(att, def, w, aim, crit, dice())
	var d: int = r["damage"]
	def.sheet.hp -= d
	if thrown:
		def.sheet.inventory.add(w["id"], 1)
	map.float_text(def.cell, str(d) if d > 0 else "0", Color(1, 0.4, 0.3) if not crit else Color(1, 0.85, 0.3))
	var line := "%s hits %s%s for %d damage." % [who, whom, (" in the " + part) if aim != "torso" else "", d]
	if crit:
		line = "A critical hit! " + line
	Game.say(line, "bad" if def.is_player else ("good" if att.is_player else "info"))
	if def.sheet.hp <= 0 and DB.npc_template(def.template).get("essential", false):
		# History needs some people alive. They go down hard and stay down.
		def.sheet.hp = 1
		def.unconscious = true
		def.set_meta("wake_round", round_no + 1000)
		Game.say("%s goes down and doesn't get up." % whom)
		return
	if def.sheet.hp <= 0:
		_kill(def, att)
		return
	_apply_effect(def, r["effect"])
	if not def.is_player and not def.has_meta("broken"):
		if not CombatRules.morale_holds(def, d * 2, dice()):
			def.set_meta("broken", true)
			Game.say("%s breaks and runs!" % whom, "good" if def.hostile else "bad")


func _consume_thrown(att: Actor, w: Dictionary) -> void:
	var id: String = w["id"]
	if att.sheet.equipped("weapon") == id:
		att.sheet.equipment["weapon"] = ""
		if att.sheet.inventory.count(id) > 0:
			att.sheet.equip(id)
	else:
		att.sheet.inventory.remove(id, 1)


func _apply_effect(def: Actor, effect: String) -> void:
	var whom := def.display_name()
	match effect:
		"knockdown":
			def.knocked_down = true
			Game.say("%s is knocked down." % whom)
		"leg":
			def.crippled["leg"] = true
			Game.say("%s's leg is crippled." % whom)
		"arm":
			def.crippled["arms"] = true
			Game.say("%s's arm is crippled." % whom)
		"disarm":
			var wid := def.sheet.equipped("weapon")
			if wid != "":
				def.sheet.unequip("weapon")
				Game.say("%s drops their weapon." % whom)
		"eyes":
			def.crippled["eyes"] = true
			Game.say("%s is blinded." % whom)
		"knockout":
			def.unconscious = true
			def.set_meta("wake_round", round_no + 3)
			Game.say("%s is knocked senseless." % whom)


func _kill(def: Actor, killer: Actor) -> void:
	def.sheet.hp = 0
	def.dead = true
	def.in_combat = false
	Game.say("%s is dead." % def.display_name(), "bad" if def.is_player or def.is_companion else "info")
	if def.is_player:
		return
	if killer.is_player or killer.is_companion:
		var xp := int(DB.npc_template(def.template).get("xp", 25 + 15 * def.sheet.level))
		Game.give_xp(xp, "Killed " + def.display_name())
	if def.has_meta("kill_flag") or DB.npc_template(def.template).has("kill_flag"):
		Game.state.set_flag(DB.npc_template(def.template).get("kill_flag", def.get_meta("kill_flag", "")))
	var shock := 10 + (25 if def.leader else 0)
	var head_taker := killer.is_player and killer.sheet.has_flag("head_taker")
	for o in order:
		if o == def or not o.is_active() or o.is_player or o.has_meta("broken"):
			continue
		var s := 0
		if o.faction == def.faction:
			s += shock
		if head_taker and o.hostile and map.can_see(o, killer):
			s += 15
		if s > 0 and not CombatRules.morale_holds(o, s, dice()):
			o.set_meta("broken", true)
			Game.say("%s loses heart and runs!" % o.display_name(), "good" if o.hostile else "bad")


## A neutral the player attacked turns hostile, and so do their friends.
func provoke(def: Actor) -> void:
	def.hostile = true
	Game.state.add_standing(def.faction, -10)
	_add(def)
	for o in map.actors:
		if o != def and o.is_active() and not o.is_player and not o.is_companion and o.faction == def.faction:
			if map.can_see(o, map.player) or Hex.distance(o.cell, def.cell) <= 6:
				o.hostile = true
				_add(o)


func _add(a: Actor) -> void:
	if not order.has(a):
		_join(a)
		order.append(a)


# --- AI -------------------------------------------------------------------------

func _enemies_of(a: Actor) -> Array:
	var out: Array = []
	for o in order:
		if not o.is_active() or o == a:
			continue
		if a.hostile != o.hostile and (o.is_player or o.is_companion or o.hostile or a.hostile):
			out.append(o)
	return out


func _ai_turn(a: Actor) -> void:
	if a.has_meta("broken"):
		await _flee(a)
		return
	var guard := 0
	while a.ap > 0 and active and guard < 20:
		guard += 1
		var foes := _enemies_of(a)
		if foes.is_empty():
			return
		foes.sort_custom(func(x, y): return Hex.distance(a.cell, x.cell) < Hex.distance(a.cell, y.cell))
		var t: Actor = foes[0]
		var dist := Hex.distance(a.cell, t.cell)
		# Throw a javelin first if one is carried and the target is not yet in reach.
		var w := a.sheet.weapon_def()
		var throw_w := _throwable(a)
		if not throw_w.is_empty() and dist >= 2 and dist <= CombatRules.weapon_range(throw_w) \
				and map.map.has_line_of_sight(a.cell, t.cell) and CombatRules.attack_ap(throw_w, false) <= a.ap:
			await attack(a, t, throw_w)
			if not map.player.is_active():
				return
			continue
		if attack_blocker(a, t, w, "torso") == "":
			await attack(a, t, w)
			if not map.player.is_active():
				return
			continue
		if dist <= CombatRules.weapon_range(w) and CombatRules.attack_ap(w, false) > a.ap:
			return  # in reach but out of breath; keep the AP as defense
		# Close in.
		var path := Pathfinder.find_path(map.map, a.cell, t.cell, map.occupied(a), 200, true)
		if path.is_empty():
			return
		var moved := false
		for step in path:
			var cost := CombatRules.move_ap(map.map, step, a)
			if cost > a.ap or map.actor_at(step) != null:
				break
			a.ap -= cost
			await map.step_actor(a, step, map.COMBAT_STEP_TIME)
			moved = true
			if Hex.distance(a.cell, t.cell) <= CombatRules.weapon_range(w) and attack_blocker(a, t, w, "torso") == "":
				break
		if not moved:
			return


func _throwable(a: Actor) -> Dictionary:
	for id in a.sheet.inventory.ids():
		var d := DB.item(id)
		if d.get("thrown", false):
			return d
	var w := a.sheet.weapon_def()
	if w.get("thrown", false):
		return w
	return {}


func _flee(a: Actor) -> void:
	var foes := _enemies_of(a)
	while a.ap > 0:
		if map.map_edge(a.cell):
			a.fled = true
			a.in_combat = false
			Game.say("%s flees the field." % a.display_name())
			return
		var best := a.cell
		var best_score := -999.0
		var occ := map.occupied(a)
		for n in Hex.neighbors(a.cell):
			if not map.map.is_walkable(n) or occ.has(n):
				continue
			var s := 0.0
			for f in foes:
				s += minf(12.0, Hex.distance(n, f.cell))
			if map.map_edge(n):
				s += 3.0
			if s > best_score:
				best_score = s
				best = n
		if best == a.cell:
			return
		var cost := CombatRules.move_ap(map.map, best, a)
		if cost > a.ap:
			return
		a.ap -= cost
		await map.step_actor(a, best, map.COMBAT_STEP_TIME)


# --- Overlay --------------------------------------------------------------------

func draw_overlay(ci: CanvasItem) -> void:
	if current != map.player or acting:
		return
	var h := map.hover
	var target := map.actor_at(h)
	var font := UITheme.BODY_FONT
	if target and target != map.player and not target.is_companion:
		var w := map.player.sheet.weapon_def()
		var txt := "%d%%" % chance_for(map.player, target, w, "torso")
		if attack_blocker(map.player, target, w, "torso") != "":
			txt = "--"
		var p := Hex.to_pixel(h, Paint.HEX) + Vector2(-30, 14)
		ci.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60, 15, 4, Color.BLACK)
		ci.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color(1, 0.9, 0.6))
		return
	if h != _cached_hover:
		_cached_hover = h
		_cached_path = []
		if map.is_walkable_free(h):
			_cached_path = Pathfinder.find_path(map.map, map.player.cell, h, map.occupied(map.player), 60)
	var ap := map.player.ap
	var spent := 0
	for step in _cached_path:
		spent += CombatRules.move_ap(map.map, step, map.player)
		var ok := spent <= ap
		ci.draw_circle(Hex.to_pixel(step, Paint.HEX), 3.0, Color(0.5, 0.9, 0.4, 0.8) if ok else Color(0.9, 0.3, 0.2, 0.7))
	if not _cached_path.is_empty():
		var p := Hex.to_pixel(_cached_path[-1], Paint.HEX) + Vector2(-30, 16)
		var txt := "%d AP" % spent
		ci.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60, 14, 4, Color.BLACK)
		ci.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(0.9, 0.95, 0.8) if spent <= ap else Color(1, 0.5, 0.4))
