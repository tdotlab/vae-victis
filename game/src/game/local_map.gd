class_name LocalMap
extends Node2D
## A playable local map: renders the map and its actors, takes mouse input,
## walks the player around, and hands off to combat, dialogue, looting and
## exits. Built entirely in code from the current GameState.

signal clicked_cell(cell: Vector2i, button: int)

const STEP_TIME := 0.13
const COMBAT_STEP_TIME := 0.16

var map: MapData
var actors: Array = []
var player: Actor
var display_pos: Dictionary = {}   # Actor -> Vector2
var walk_phase: Dictionary = {}    # Actor -> float
var hover := Vector2i(-9999, -9999)
var path_preview: Array[Vector2i] = []
var combat: CombatRunner
var hud: HUD
var ui_layer: CanvasLayer
var modal_open := false
var busy := false                  # an action is animating; ignore new orders
var floaters: Array = []           # [pos, text, color, age]
var projectiles: Array = []        # [from, to, t, color]
var containers: Dictionary = {}    # mark -> {"def":..., "state":...}
var exits: Array = []
var _move_token := 0
var _wander_timer := 0.0
var _camera: Camera2D
var _cam_offset := Vector2.ZERO
var _floor: _Layer
var _things: _Layer
var _over: _Layer
var _night: CanvasModulate
var _fired_triggers: Dictionary = {}
var _leaving := false


class _Layer extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


func _ready() -> void:
	var gs := Game.state
	map = MapData.load_map(gs.map_id)
	_night = CanvasModulate.new()
	add_child(_night)
	_floor = _Layer.new()
	_floor.fn = _draw_floor
	add_child(_floor)
	_over = _Layer.new()
	_over.fn = _draw_overlay
	add_child(_over)
	_things = _Layer.new()
	_things.fn = _draw_things
	add_child(_things)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = HUD.new()
	hud.map = self
	ui_layer.add_child(hud)
	combat = CombatRunner.new()
	combat.map = self
	add_child(combat)
	_spawn_actors()
	_setup_containers_and_exits()
	_update_night()
	hud.refresh()
	var cam_target := display_pos[player] as Vector2
	_camera.position = cam_target
	_camera.reset_smoothing()
	var first_visit: bool = not gs.map_states.has(map.id) or not gs.map_states[map.id].get("visited", false)
	_remember_visit()
	if first_visit and map.def.has("arrive_text"):
		Game.say(map.def["arrive_text"], "story")
	else:
		Game.say("You are in %s." % map.name)
	_fired_triggers = gs.map_states.get(map.id, {}).get("triggers", {}).duplicate()
	if first_visit and map.def.has("arrive_dialogue"):
		await get_tree().process_frame
		open_dialogue(map.def["arrive_dialogue"], null)


func _remember_visit() -> void:
	var gs := Game.state
	if not gs.map_states.has(map.id):
		gs.map_states[map.id] = {}
	gs.map_states[map.id]["visited"] = true


# --- Setup -------------------------------------------------------------------

func _spawn_actors() -> void:
	var gs := Game.state
	var saved: Dictionary = gs.map_states.get(map.id, {}).get("actors", {})
	# Player
	player = Actor.new()
	player.uid = "player"
	player.sheet = gs.player
	player.is_player = true
	player.faction = "player"
	player.look = {"tunic": "#3f6f8a", "cloak": "#5a4a30", "hair": "#6a4a2a" if gs.player.sex == "m" else "#8a5a2a"}
	var entry := gs.entry if map.has_mark(gs.entry) else "start"
	player.cell = map.mark(entry)
	actors.append(player)
	# Map NPCs
	for e in map.def.get("actors", []):
		var uid: String = e.get("uid", e["template"])
		if e.has("if_flag") and gs.flag(e["if_flag"]) == 0:
			continue
		if e.has("unless_flag") and gs.flag(e["unless_flag"]) != 0:
			continue
		var a := Actor.from_template(e["template"], uid)
		if e.has("mark"):
			a.cell = map.mark(e["mark"])
		if e.has("dialogue"):
			a.dialogue = e["dialogue"]
		if e.has("ai"):
			a.ai = e["ai"]
		a.home = a.cell
		if saved.has(uid):
			a.apply_state(saved[uid])
		actors.append(a)
	# Companions travel with the player.
	for cd in gs.companions:
		var c := Actor.from_template(cd["template"], cd["uid"])
		c.apply_state(cd)
		c.is_companion = true
		c.ai = "follow"
		actors.append(c)
	var taken := {}
	for a in actors:
		if a.dead or a.fled:
			continue
		if taken.has(a.cell) or not map.is_walkable(a.cell):
			a.cell = map.nearest_free(a.cell if map.has_cell(a.cell) else player.cell, taken)
		taken[a.cell] = true
	for a in actors:
		display_pos[a] = Hex.to_pixel(a.cell, Paint.HEX)
		walk_phase[a] = 0.0


func _setup_containers_and_exits() -> void:
	var ms: Dictionary = Game.state.map_states.get(map.id, {})
	var saved: Dictionary = ms.get("containers", {})
	for c in map.def.get("containers", []):
		var mark: String = c["mark"]
		var st: Dictionary
		if saved.has(mark):
			st = saved[mark]
		else:
			st = {"items": c.get("items", []).duplicate(true), "silver": int(c.get("silver", 0)), "unlocked": not c.has("lock")}
		containers[mark] = {"def": c, "state": st}
	exits = map.def.get("exits", [])


## Writes actor and container state back into the GameState.
func save_map_state() -> void:
	var gs := Game.state
	if not gs.map_states.has(map.id):
		gs.map_states[map.id] = {}
	var ms: Dictionary = gs.map_states[map.id]
	var a_states := {}
	var comps := []
	for a in actors:
		if a.is_player:
			continue
		if a.is_companion:
			comps.append(a.state_dict())
		else:
			a_states[a.uid] = a.state_dict()
	ms["actors"] = a_states
	var c_states := {}
	for m in containers:
		c_states[m] = containers[m]["state"]
	ms["containers"] = c_states
	ms["triggers"] = _fired_triggers
	gs.companions = comps


# --- Queries -------------------------------------------------------------------

func actor_at(c: Vector2i, include_dead: bool = false) -> Actor:
	for a in actors:
		if a.cell == c and (a.is_active() or (include_dead and (a.dead or a.unconscious))):
			if a.fled:
				continue
			return a
	return null


func occupied(except: Actor = null) -> Dictionary:
	var d := {}
	for a in actors:
		if a != except and a.is_active():
			d[a.cell] = true
	return d


func container_at(c: Vector2i) -> String:
	for m in containers:
		if map.mark_cells(m).has(c):
			return m
	return ""


func exit_at(c: Vector2i) -> Dictionary:
	for e in exits:
		if map.mark_cells(e["mark"]).has(c):
			return e
	return {}


func is_walkable_free(c: Vector2i) -> bool:
	return map.is_walkable(c) and actor_at(c) == null


func has_line_of_sight_between(a: Actor, b: Actor) -> bool:
	return map.has_line_of_sight(a.cell, b.cell)


## True if the cell is at the edge of the map (a way off it).
func map_edge(c: Vector2i) -> bool:
	for n in Hex.neighbors(c):
		if not map.has_cell(n):
			return true
	return false


func can_see(a: Actor, b: Actor) -> bool:
	var d := Hex.distance(a.cell, b.cell)
	var sight := a.sheet.derived("sight") + 4
	if Game.state.hour() >= 21 or Game.state.hour() < 6:
		sight -= 4
	if d > sight:
		return false
	if not map.has_line_of_sight(a.cell, b.cell):
		return false
	# Sneaking player: hostile must beat the Sneak skill if far enough away.
	if b.is_player and b.get_meta("sneaking", false) and d > 1:
		var sneak := b.sheet.skill("sneak")
		var notice := 30 + a.sheet.attr("PER") * 5 - d * 4
		return notice > sneak
	return true


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if modal_open or _leaving:
		return
	if event is InputEventMouseMotion:
		var c := Hex.from_pixel(get_global_mouse_position(), Paint.HEX)
		if c != hover:
			hover = c
			_update_preview()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.6, 0.6), Vector2(2.2, 2.2))
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom = (_camera.zoom / 1.1).clamp(Vector2(0.6, 0.6), Vector2(2.2, 2.2))
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var c := Hex.from_pixel(get_global_mouse_position(), Paint.HEX)
				clicked_cell.emit(c, event.button_index)
				if combat.active:
					combat.on_click(c, event.button_index)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					_explore_click(c)
				else:
					examine(c)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if combat.active:
					combat.player_end_turn()
			KEY_ENTER, KEY_KP_ENTER:
				if combat.active:
					combat.request_end()
			KEY_A:
				if not combat.active and not busy:
					combat.start_combat(player)
			KEY_S:
				if not combat.active:
					toggle_sneak()
			KEY_C:
				hud.open_character()
			KEY_I:
				hud.open_inventory()
			KEY_J:
				hud.open_journal()
			KEY_M:
				if not combat.active:
					try_world_map()
			KEY_F5:
				quick_save()
			KEY_F9:
				Game.goto("load", {"slot": "quick"})
			KEY_HOME:
				_cam_offset = Vector2.ZERO


func _update_preview() -> void:
	path_preview.clear()
	if busy:
		return
	if map.is_walkable(hover) and actor_at(hover) == null:
		path_preview = Pathfinder.find_path(map, player.cell, hover, occupied(player))
	hud.update_hover(hover)


func _explore_click(c: Vector2i) -> void:
	if busy and not player.has_meta("walking"):
		return
	var target := actor_at(c)
	if target and target != player:
		_approach_and(target.cell, func(): _interact_actor(target))
		return
	var cont := container_at(c)
	if cont != "":
		_approach_and(c, func(): open_container(cont))
		return
	if not map.is_walkable(c):
		var dead := actor_at(c, true)
		if dead == null:
			return
	var body := actor_at(c, true)
	if body and body != player and (body.dead or body.unconscious):
		_approach_and(c, func(): open_body(body))
		return
	if not map.is_walkable(c):
		return
	var path := Pathfinder.find_path(map, player.cell, c, occupied(player))
	if path.is_empty():
		return
	_walk_player(path, func(): _arrived(c))


func _approach_and(target: Vector2i, then: Callable) -> void:
	if Hex.distance(player.cell, target) <= 1:
		then.call()
		return
	var path := Pathfinder.find_path(map, player.cell, target, occupied(player), 400, true)
	if path.is_empty():
		Game.say("You can't reach that.")
		return
	_walk_player(path, then)


func _walk_player(path: Array[Vector2i], then: Callable = Callable()) -> void:
	_move_token += 1
	var token := _move_token
	player.set_meta("walking", true)
	busy = true
	for c in path:
		if token != _move_token:
			return
		if actor_at(c) != null:
			break
		await step_actor(player, c, STEP_TIME)
		_after_player_step()
		if combat.active or _leaving:
			break
	if token != _move_token:
		return
	player.remove_meta("walking")
	busy = false
	_update_preview()
	if not combat.active and not _leaving and then.is_valid():
		then.call()


func _after_player_step() -> void:
	Game.state.advance(0)
	_check_triggers(player.cell)
	_check_detection()


func _arrived(c: Vector2i) -> void:
	var e := exit_at(c)
	if not e.is_empty():
		take_exit(e)


func _interact_actor(a: Actor) -> void:
	face(player, a.cell)
	if a.hostile:
		combat.start_combat(player, a)
		return
	if a.dialogue != "":
		open_dialogue(a.dialogue, a)
	else:
		Game.say("%s: %s" % [a.display_name(), a.desc if a.desc != "" else "They have nothing to say to you."])


func examine(c: Vector2i) -> void:
	var a := actor_at(c, true)
	if a:
		if a.is_player:
			Game.say("You are %s." % a.health_word())
		else:
			var txt := "You see %s." % a.display_name()
			if a.desc != "":
				txt += " " + a.desc
			txt += " They look %s." % a.health_word()
			Game.say(txt)
		return
	for n in map.def.get("notes", []):
		if map.mark_cells(n["mark"]).has(c):
			Game.say(n["text"])
			return
	var cont := container_at(c)
	if cont != "":
		Game.say("You see %s." % containers[cont]["def"].get("name", "a container").to_lower())
		return
	var t := map.terrain_at(c)
	if not t.is_empty():
		Game.say("You see: %s." % t.get("name", "nothing"))


func toggle_sneak() -> void:
	var on: bool = not player.get_meta("sneaking", false)
	player.set_meta("sneaking", on)
	Game.say("You move quietly now (Sneak %d%%)." % player.sheet.skill("sneak") if on else "You stop sneaking.")
	hud.refresh()


# --- Animation helpers --------------------------------------------------------

func face(a: Actor, target: Vector2i) -> void:
	if target != a.cell:
		a.facing = Hex.direction_to(a.cell, target)


func step_actor(a: Actor, c: Vector2i, dur: float) -> void:
	face(a, c)
	var from: Vector2 = display_pos[a]
	var to := Hex.to_pixel(c, Paint.HEX)
	a.cell = c
	var t := 0.0
	while t < dur:
		var dt := get_process_delta_time()
		t += dt
		var k := minf(1.0, t / dur)
		display_pos[a] = from.lerp(to, k)
		walk_phase[a] = float(walk_phase[a]) + dt * 14.0
		await get_tree().process_frame
	display_pos[a] = to
	walk_phase[a] = 0.0


func lunge(a: Actor, target: Vector2i) -> void:
	face(a, target)
	var base := Hex.to_pixel(a.cell, Paint.HEX)
	var dir := (Hex.to_pixel(target, Paint.HEX) - base).normalized() * 9.0
	for k in [0.4, 0.8, 1.0, 0.6, 0.3, 0.0]:
		display_pos[a] = base + dir * k
		await get_tree().process_frame
	display_pos[a] = base


func shoot(from: Vector2i, to: Vector2i, color: Color = Color("#d8d0b0")) -> void:
	var p := [Hex.to_pixel(from, Paint.HEX) - Vector2(0, 24), Hex.to_pixel(to, Paint.HEX) - Vector2(0, 22), 0.0, color]
	projectiles.append(p)
	var dist: float = (p[1] - p[0]).length()
	var dur := clampf(dist / 700.0, 0.12, 0.45)
	var t := 0.0
	while t < dur:
		t += get_process_delta_time()
		p[2] = minf(1.0, t / dur)
		await get_tree().process_frame
	projectiles.erase(p)


func float_text(c: Vector2i, text: String, color: Color) -> void:
	floaters.append([Hex.to_pixel(c, Paint.HEX) - Vector2(0, 50), text, color, 0.0])


# --- Exploration ticking ------------------------------------------------------

func _process(delta: float) -> void:
	_update_camera(delta)
	for f in floaters:
		f[3] += delta
	floaters = floaters.filter(func(f): return f[3] < 1.4)
	_things.queue_redraw()
	_over.queue_redraw()
	if combat.active or modal_open or _leaving:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = 1.2
		_npc_idle_moves()
		_check_detection()
		_update_night()


func _update_camera(delta: float) -> void:
	var pan := Vector2.ZERO
	if not modal_open:
		if Input.is_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			pan.x += 1
		if Input.is_key_pressed(KEY_UP):
			pan.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			pan.y += 1
	_cam_offset += pan * 600.0 * delta / _camera.zoom.x
	var focus: Vector2 = display_pos[player]
	if combat.active and combat.current and combat.current != player:
		focus = display_pos[combat.current]
	_camera.position = focus + _cam_offset
	if player.has_meta("walking"):
		_cam_offset = _cam_offset.lerp(Vector2.ZERO, minf(1.0, delta * 3.0))


func _npc_idle_moves() -> void:
	var occ := occupied()
	for a in actors:
		if not a.is_active() or a.is_player:
			continue
		if a.ai == "follow":
			var d := Hex.distance(a.cell, player.cell)
			if d > 2 and not a.has_meta("walking"):
				var path := Pathfinder.find_path(map, a.cell, player.cell, occupied(a), 200, true)
				if path.size() > 1:
					path.resize(path.size() - 1)
				if not path.is_empty():
					_walk_npc(a, path)
		elif a.ai == "wander" and Game.state.dice.chance(30):
			var options: Array = []
			for n in Hex.neighbors(a.cell):
				if map.is_walkable(n) and not occ.has(n) and Hex.distance(n, a.home) <= 3:
					options.append(n)
			if not options.is_empty():
				var n: Vector2i = Game.state.dice.pick(options)
				occ[n] = true
				step_actor(a, n, 0.35)


func _walk_npc(a: Actor, path: Array[Vector2i]) -> void:
	a.set_meta("walking", true)
	for c in path:
		if combat.active or actor_at(c) != null:
			break
		await step_actor(a, c, STEP_TIME)
	a.remove_meta("walking")


func _check_detection() -> void:
	if combat.active:
		return
	for a in actors:
		if a.hostile and a.is_active() and can_see(a, player):
			Game.say("%s has spotted you!" % a.display_name(), "bad")
			_move_token += 1
			player.remove_meta("walking")
			busy = false
			combat.start_combat(a)
			return


func _check_triggers(c: Vector2i) -> void:
	for t in map.def.get("triggers", []):
		var key: String = t.get("id", t["mark"])
		if t.get("once", true) and _fired_triggers.has(key):
			continue
		if not map.mark_cells(t["mark"]).has(c):
			continue
		if t.has("if_flag") and Game.state.flag(t["if_flag"]) == 0:
			continue
		if t.has("unless_flag") and Game.state.flag(t["unless_flag"]) != 0:
			continue
		_fired_triggers[key] = 1
		if t.has("say"):
			Game.say(t["say"], "story")
		if t.has("set_flag"):
			Game.state.set_flag(t["set_flag"])
		if t.has("dialogue"):
			_move_token += 1
			player.remove_meta("walking")
			busy = false
			open_dialogue(t["dialogue"], null)


func _update_night() -> void:
	var h := Game.state.hour() + (Game.state.minutes % 60) / 60.0
	var col := Color(1, 1, 1)
	if map.def.get("indoor", false) or map.def.get("cave", false):
		col = Color(0.85, 0.8, 0.75) if map.def.get("cave", false) else Color(1, 0.95, 0.9)
	elif h < 5.0 or h >= 21.0:
		col = Color(0.42, 0.45, 0.62)
	elif h < 7.0:
		col = Color(0.42, 0.45, 0.62).lerp(Color(1, 0.92, 0.85), (h - 5.0) / 2.0)
	elif h >= 18.0:
		col = Color(1, 0.9, 0.8).lerp(Color(0.42, 0.45, 0.62), (h - 18.0) / 3.0)
	if Game.state.season() == "winter" and not map.def.get("cave", false):
		col *= Color(0.95, 0.97, 1.03)
	_night.color = col


# --- Hand-offs to other systems ------------------------------------------------

func open_dialogue(dlg_id: String, speaker: Actor) -> void:
	hud.open_dialogue(dlg_id, speaker)


func open_container(mark: String) -> void:
	var c: Dictionary = containers[mark]
	var st: Dictionary = c["state"]
	if not st.get("unlocked", true):
		var lock := int(c["def"].get("lock", 0))
		var skill := player.sheet.skill("locks") + _tool_bonus("locks")
		var chance := clampi(skill - lock + 50, 5, 95)
		Game.state.advance(5)
		if Game.state.dice.chance(chance):
			st["unlocked"] = true
			Game.say("You work the lock open.", "good")
			Game.give_xp(25 + lock / 2, "Opened a lock")
		else:
			Game.say("The lock holds. (Locks %d%%)" % skill, "bad")
			return
	if c["def"].has("owner"):
		_owner_check(c["def"]["owner"])
	hud.open_loot(c["def"].get("name", "Container"), st, null)


func open_body(a: Actor) -> void:
	hud.open_loot(a.display_name(), {}, a)


func _owner_check(owner_uid: String) -> void:
	for a in actors:
		if a.uid == owner_uid and a.is_active() and can_see(a, player) and not player.get_meta("sneaking", false):
			Game.say("%s sees you going through their things." % a.display_name(), "bad")
			Game.state.add_standing(a.faction, -5)


func _tool_bonus(skill: String) -> int:
	var b := 0
	for id in player.sheet.inventory.ids():
		b = maxi(b, int(DB.item(id).get("skill_bonus", {}).get(skill, 0)))
	return b


func take_exit(e: Dictionary) -> void:
	if _leaving:
		return
	var to: String = e.get("to", "world")
	if e.has("require_flag") and Game.state.flag(e["require_flag"]) == 0:
		Game.say(e.get("blocked_text", "You can't leave that way yet."))
		return
	leave_to(to, e.get("entry", "start"))


func try_world_map() -> void:
	if map.def.get("no_world_exit", false):
		Game.say("You can't leave from here.")
		return
	for e in exits:
		if e.get("to", "") == "world" and Hex.distance(player.cell, map.mark(e["mark"])) <= 3:
			take_exit(e)
			return
	Game.say("Walk to the edge of the area to travel on.")


func leave_to(to: String, entry: String = "start") -> void:
	_leaving = true
	save_map_state()
	if to == "world":
		Game.goto("world", {})
	elif to.begins_with("map:"):
		Game.state.map_id = to.substr(4)
		Game.state.entry = entry
		Game.goto("map", {})


func quick_save() -> void:
	if combat.active:
		Game.say("You can't save during a fight.")
		return
	save_map_state()
	if Game.save_game("quick"):
		Game.say("Game saved.", "good")


## Called by dialogue and combat when an NPC's state changes in a way the map
## should show (hostility, removal, joining the party).
func refresh_actor(a: Actor) -> void:
	display_pos[a] = Hex.to_pixel(a.cell, Paint.HEX)


func find_actor(uid: String) -> Actor:
	for a in actors:
		if a.uid == uid:
			return a
	return null


func spawn_actor(template: String, uid: String, cell: Vector2i) -> Actor:
	var a := Actor.from_template(template, uid)
	a.cell = map.nearest_free(cell, occupied())
	a.home = a.cell
	actors.append(a)
	display_pos[a] = Hex.to_pixel(a.cell, Paint.HEX)
	walk_phase[a] = 0.0
	return a


# --- Drawing ----------------------------------------------------------------

func _draw_floor(ci: CanvasItem) -> void:
	var tdefs := DB.terrain()
	for c in map.cells:
		var t: Dictionary = tdefs[map.cells[c]]
		if not t.has("height") or t.get("walk", false):
			Paint.floor_hex(ci, c, t)
		else:
			# Under blocks, draw the neighboring ground color so edges look right.
			Paint.floor_hex(ci, c, tdefs.get(map.def.get("default", "grass"), t) if t.get("tree", false) else {"color": Color(t["color"]).darkened(0.35).to_html()})
	for e in exits:
		for c in map.mark_cells(e["mark"]):
			Paint.fill_hex(ci, c, Color(0.45, 0.75, 0.35, 0.22))
			Paint.grid_hex(ci, c, Color(0.55, 0.85, 0.4, 0.5))


func _draw_overlay(ci: CanvasItem) -> void:
	if combat.active:
		for c in map.cells:
			if map.is_walkable(c):
				Paint.grid_hex(ci, c, Color(0, 0, 0, 0.12))
		combat.draw_overlay(ci)
	elif not path_preview.is_empty() and not busy:
		for c in path_preview:
			ci.draw_circle(Hex.to_pixel(c, Paint.HEX), 2.5, Color(0.9, 0.8, 0.5, 0.6))
	if map.has_cell(hover) and not modal_open:
		var col := Color(0.95, 0.85, 0.5, 0.8)
		var a := actor_at(hover)
		if a and a.hostile:
			col = Color(0.95, 0.35, 0.25, 0.9)
		elif a and not a.is_player:
			col = Color(0.5, 0.85, 0.95, 0.9)
		elif not map.is_walkable(hover):
			col = Color(0.6, 0.6, 0.6, 0.5)
		Paint.grid_hex(ci, hover, col, 2.0)


func _draw_things(ci: CanvasItem) -> void:
	var tdefs := DB.terrain()
	var items: Array = []  # [sort_y, kind, payload]
	for c in map.cells:
		var t: Dictionary = tdefs[map.cells[c]]
		if t.has("height") and not t.get("walk", false):
			items.append([Hex.to_pixel(c, Paint.HEX).y, 0, c])
	for a in actors:
		if a.fled:
			continue
		var y: float = display_pos[a].y + (0.1 if a.is_active() else -0.5)
		items.append([y, 1, a])
	items.sort_custom(func(x, y): return x[0] < y[0])
	var pp: Vector2 = display_pos[player]
	for it in items:
		if it[1] == 0:
			var c: Vector2i = it[2]
			var t: Dictionary = tdefs[map.cells[c]]
			var p := Hex.to_pixel(c, Paint.HEX)
			# Fade blocks that stand in front of the player and would hide them.
			var fade := p.y > pp.y and p.y - pp.y < 60 and absf(p.x - pp.x) < 40 and float(t.get("height", 0)) > 20
			if t.get("tree", false):
				Paint.tree(ci, c, t, fade)
			else:
				Paint.block(ci, c, t, fade)
		else:
			var a: Actor = it[2]
			var ring := Color(0, 0, 0, 0)
			if a.is_player:
				ring = Color(0.9, 0.75, 0.3, 0.9)
			elif combat.active and a.is_active() and a.in_combat:
				ring = Color(0.9, 0.3, 0.2, 0.9) if a.hostile else Color(0.4, 0.8, 0.4, 0.8)
				if a == combat.current:
					ring = Color(1, 1, 1, 0.95)
			if a.look.get("beast", false):
				Paint.beast(ci, display_pos[a], a, walk_phase[a], ring)
			else:
				Paint.figure(ci, display_pos[a], a, walk_phase[a], ring)
	for p in projectiles:
		var from: Vector2 = p[0]
		var to: Vector2 = p[1]
		var k: float = p[2]
		var pos := from.lerp(to, k) - Vector2(0, sin(k * PI) * 18.0)
		var dir := (to - from).normalized()
		ci.draw_line(pos - dir * 9.0, pos + dir * 3.0, p[3], 2.0)
	var font := ThemeDB.fallback_font
	for f in floaters:
		var pos: Vector2 = f[0] - Vector2(0, f[3] * 30.0)
		var col: Color = f[2]
		col.a = clampf(1.6 - f[3], 0.0, 1.0)
		ci.draw_string_outline(font, pos + Vector2(-30, 0), f[1], HORIZONTAL_ALIGNMENT_CENTER, 60, 16, 4, Color(0, 0, 0, col.a))
		ci.draw_string(font, pos + Vector2(-30, 0), f[1], HORIZONTAL_ALIGNMENT_CENTER, 60, 16, col)
