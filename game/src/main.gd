extends Node
## Root of the game: swaps screens when Game asks for one.
##
## Test harness (user args after "--"):
##   --scenario=<name>   skip the title and start a ready-made situation
##                       (sandbox, fight, talk, world, create, title, brigodunon...)
##   --shot=<file.png>   save a screenshot after --frames frames, then quit
##   --frames=<n>        frames to wait before the screenshot (default 30)
##   --act=<list>        comma-separated scripted actions run before the shot
##   --style=<id>        art style for this run (see data/art_styles.json)

var _screen: Node
var _shot := ""
var _frames := 30
var _acts: Array = []


func _ready() -> void:
	get_window().title = "Vae Victis"
	Game.screen_requested.connect(_on_screen)
	var scenario := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--act="):
			_acts = Array(a.substr(6).split(","))
		elif a.begins_with("--style="):
			Art.set_style(a.substr(8), false)
	if scenario != "":
		# Harness runs save somewhere of their own, not over the player's games.
		Game.save_dir = "user://harness_saves"
		Scenarios.start(scenario)
	else:
		_on_screen("title", {})
	if _shot != "":
		_harness.call_deferred()


func _on_screen(screen: String, args: Dictionary) -> void:
	if _screen:
		_screen.queue_free()
		_screen = null
	match screen:
		"title":
			_screen = TitleScreen.new()
		"create":
			_screen = CreationScreen.new()
		"map":
			_screen = LocalMap.new()
		"world":
			_screen = WorldMap.new()
		"text":
			var t := TextScreen.new()
			t.args = args
			_screen = t
		"death":
			var t2 := TextScreen.new()
			t2.args = {"title": "Vae victis", "text": args.get("text", ""), "next": "title", "button": "Return to the title"}
			_screen = t2
		"load":
			if Game.load_game(args.get("slot", "quick")):
				_on_screen("map" if Game.state.map_id != "" else "world", {})
				Game.say("Game loaded.", "good")
			else:
				_on_screen("title", {})
			return
		_:
			push_error("Unknown screen " + screen)
			_screen = TitleScreen.new()
	add_child(_screen)


func _harness() -> void:
	for i in range(10):
		await get_tree().process_frame
	for act in _acts:
		await Scenarios.act(self, act)
	for i in range(_frames):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot)
	print("Saved screenshot ", _shot)
	get_tree().quit()


func current_screen() -> Node:
	return _screen
