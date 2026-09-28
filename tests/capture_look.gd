extends SceneTree
## THE LOOK'S BEFORE/AFTER SHOTS (docs/ww2-look-plan.md, phase 0): the Cockpit,
## the strategic map, a message, a dialog, a finder and the in-game menu of a
## fresh game, each the whole screen. Needs a window (NOT --headless), like
## tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_look.gd -- `
##       --out=C:/tmp/look/ww2_1440 --pack=ww2 --record=user://capture-look.jsonl [--faction=allies]
##
## writes <out>_cockpit.png, _map.png, _message.png, _dialog.png, _finder.png
## and _menu.png. --record= is REQUIRED: without it the game's session log
## would overwrite the player's user://last-session.jsonl.
##
## No art set is read (Artwork.UserArtRoot / IgnoreProjectFolder, as the
## plain-look tests do; movies likewise), so a pack shows its own look - the
## Star Wars pack's plain look is the regression set.

const Art := preload("res://src/ui/artwork.gd")
const MoviesLib := preload("res://src/ui/movies.gd")


func _init() -> void:
	await process_frame
	if _arg("--record=", "").is_empty():
		push_error("[capture_look] pass --record=user://<file>.jsonl so the player's session log is untouched")
		quit(2)
		return
	var out := _arg("--out=", "user://look").trim_suffix(".png")
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-capture-look-none"
	MoviesLib.UserRoot = "user://test-capture-look-none"
	MoviesLib.LaunchPlayed = true
	FactionRegistry.EnsureLoaded()
	if not FactionRegistry.IsLoaded():
		push_error("[capture_look] no pack loaded - pass --pack=<id>")
		quit(3)
		return
	var ok := true

	# THE COCKPIT.
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	for _i in 6:
		await process_frame
	ok = _shot(out, "cockpit") and ok
	menu.queue_free()
	await process_frame
	await process_frame

	# A FRESH GAME.
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.HQOnlyVictory = false
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	ok = _shot(out, "map") and ok

	# A MESSAGE: four categories, one naming a world and one a character.
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	# A commander, not a head of state, reports.
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and not c.IsMajor)
	if who == null:
		who = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us)
	var today: int = StrategicTickManager.Today
	EventBus.Tell(us, GameMessage.new("Supply convoy arrived", "Raw materials delivered to the depot.", Enums.MessageCategory.Resources, today))
	EventBus.Tell(us, GameMessage.new("Fleet awaiting orders", "The fleet has arrived and awaits orders.", Enums.MessageCategory.Fleets, today, home))
	EventBus.Tell(us, GameMessage.new("%s reports" % who.Name, "The mission team has reached its destination and begun work.", Enums.MessageCategory.Missions, today, home, who))
	EventBus.Tell(us, GameMessage.new("Battle at %s" % home.Name, "Enemy forces have engaged our fleet in orbit. Losses are being assessed.", Enums.MessageCategory.Conflict, today, home))
	ui.OnMessageIndexClicked("All")
	for _i in 5:
		await process_frame
	ok = _shot(out, "message") and ok
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame

	# A DIALOG: the refusal box every refused order shows.
	ui.ShowRefusal("The mission cannot be launched: the team has no one able to perform it.")
	for _i in 4:
		await process_frame
	ok = _shot(out, "dialog") and ok
	for n in ui.get_children():
		if n is AcceptDialog:
			n.queue_free()
	for _i in 3:
		await process_frame

	# A FINDER.
	ui.OpenPlanetFinder()
	for _i in 5:
		await process_frame
	ok = _shot(out, "finder") and ok
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame

	# THE IN-GAME MENU.
	ui.OnMenuButtonClicked()
	for _i in 5:
		await process_frame
	ok = _shot(out, "menu") and ok

	quit(0 if ok else 1)


func _shot(out: String, what: String) -> bool:
	var path := "%s_%s.png" % [out, what]
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[capture_look] %s %s -> %s" % [what, str(img.get_size()), path if err == OK else ("error %d" % err)])
	return err == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
