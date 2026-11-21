class_name Scenarios
extends RefCounted
## Ready-made game situations for development and screenshot checks.
## Not reachable from the game's menus.


static func test_hero() -> CharacterSheet:
	var s := CharacterSheet.create("Tester", {"STR": 6, "END": 6, "AGI": 7, "PER": 6, "WIT": 6, "PRE": 6, "FOR": 3},
		["blades", "speech", "missiles"], [])
	for id in ["gallic_sword", "gallic_shield", "leather_jerkin"]:
		s.inventory.add(id, 1)
		s.equip(id)
	s.inventory.add("javelin", 3)
	s.inventory.add("herbs", 2)
	s.silver = 30
	s.hp = s.max_hp()
	return s


static func start(name: String) -> void:
	match name:
		"title":
			Game.goto("title", {})
		"create":
			Game.goto("create", {})
		"sandbox", "fight", "talk", "loot", "inventory", "character", "barter":
			Game.new_game(test_hero())
			Game.state.map_id = "sandbox"
			Game.goto("map", {})
		"world":
			Game.new_game(test_hero())
			Game.state.set_quest("hostages", "find_tally")
			for l in DB.story().get("known_locations", []):
				Game.state.known_locations.append(l)
			var ws: Array = DB.story().get("world_start", [0, 0])
			Game.state.world_pos = Vector2i(int(ws[0]), int(ws[1]))
			Game.goto("world", {})
		"newgame":
			Game.new_game(test_hero())
			Game.start_story()
		_:
			# Any map id: drop the test hero there.
			Game.new_game(test_hero())
			Game.state.map_id = name
			Game.goto("map", {})


## Scripted actions for screenshot runs: walk:x:y, fight, talk:<uid>,
## open:<panel>, wait:<frames>, attack:<uid>, endturn, key:<choice number>,
## encounter:<id> (world map), press:<button text prefix>, flag:<name>[:v], quest:<id>:<stage>, give:<item>[:n], silver:<n>, opinion:<uid>:<n>, ally:<uid>, roof:<host faction>, known:<location>, save:<slot>, reload.
static func act(main: Node, a: String) -> void:
	var parts := a.split(":")
	var tree := main.get_tree()
	var screen: Node = main.current_screen()
	var map := screen as LocalMap
	match parts[0]:
		"wait":
			for i in range(int(parts[1])):
				await tree.process_frame
		"walk":
			if map:
				var c := Hex.offset_to_axial(int(parts[1]), int(parts[2]))
				var path := Pathfinder.find_path(map.map, map.player.cell, c, map.occupied(map.player))
				await map._walk_player(path)
		"fight":
			if map:
				map.combat.start_combat(map.player)
				await tree.process_frame
		"attack":
			if map:
				var t := map.find_actor(parts[1])
				await map.combat.player_attack(t, parts[2] if parts.size() > 2 else "torso")
		"endturn":
			if map:
				map.combat.player_end_turn()
				for i in range(90):
					await tree.process_frame
		"talk":
			if map:
				var t2 := map.find_actor(parts[1])
				map.open_dialogue(t2.dialogue, t2)
				await tree.process_frame
		"travel":
			var wm := screen as WorldMap
			if wm:
				if parts.size() > 2:
					wm._set_destination(Vector2i(int(parts[1]), int(parts[2])))
				else:
					wm._travel_to_location(parts[1])
				for i in range(600):
					await tree.process_frame
					if wm._path.is_empty() or wm.modal_open or main.current_screen() != wm:
						break
		"key":
			var ev := InputEventKey.new()
			ev.keycode = KEY_1 + int(parts[1]) - 1
			ev.pressed = true
			Input.parse_input_event(ev)
			await tree.process_frame
			await tree.process_frame
		"open":
			if map:
				match parts[1]:
					"inventory":
						map.hud.open_inventory()
					"character":
						map.hud.open_character()
					"journal":
						map.hud.open_journal()
					"chest":
						map.open_container(parts[2] if parts.size() > 2 else "chest")
					"barter":
						map.hud.open_barter(map.find_actor(parts[2]))
					"save", "load":
						map.hud.open_saves(parts[1])
				await tree.process_frame
		"save":
			if map:
				map.quick_save(parts[1])
		"flag":
			Game.state.set_flag(parts[1], int(parts[2]) if parts.size() > 2 else 1)
		"quest":
			Game.state.set_quest(parts[1], parts[2])
		"give":
			Game.state.player.inventory.add(parts[1], int(parts[2]) if parts.size() > 2 else 1)
		"silver":
			Game.state.player.silver += int(parts[1])
		"roof":
			# Declares the whole map a host's roof, as a map's "hospitality" would.
			if map:
				map.map.def = map.map.def.duplicate()
				map.map.def["hospitality"] = [{"host": parts[1]}]
		"ally":
			if map:
				var al := map.find_actor(parts[1])
				al.ally = true
				al.hostile = false
		"opinion":
			Companions.change(Game.state, parts[1], int(parts[2]))
			if map:
				map.check_quiet()
				await tree.process_frame
		"known":
			Game.state.known_locations.append(parts[1])
			if screen is WorldMap:
				screen.queue_redraw()
		"hover":
			if map:
				map.hover = Hex.offset_to_axial(int(parts[1]), int(parts[2]))
		"press":
			var btn := _find_button(main, ":".join(parts.slice(1)))
			if btn:
				btn.pressed.emit()
			for i in range(5):
				await tree.process_frame
		"encounter":
			var wm := screen as WorldMap
			if wm:
				wm.offer_encounter_by_id(parts[1])
				for i in range(5):
					await tree.process_frame
		"reload":
			# Re-enter the current map, so actors gated on flags set above respawn.
			Game.goto("map", {})
			for i in range(10):
				await tree.process_frame
		"time":
			Game.state.advance(int(parts[1]) * 60)
		"click":
			if map:
				var c2 := Hex.offset_to_axial(int(parts[1]), int(parts[2]))
				map.combat.on_click(c2, MOUSE_BUTTON_LEFT)
				for i in range(60):
					await tree.process_frame


static func _find_button(n: Node, prefix: String) -> Button:
	if n is Button and (n as Button).text.begins_with(prefix) and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_button(c, prefix)
		if b:
			return b
	return null
