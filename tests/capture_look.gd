extends SceneTree
## THE LOOK'S BEFORE/AFTER SHOTS (docs/ww2-look-plan.md, phase 0): the Cockpit,
## the strategic map, a message, a dialog, a finder and the in-game menu of a
## fresh game, each the whole screen. Needs a window (NOT --headless), like
## tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_look.gd -- `
##       --out=C:/tmp/look/ww2_1440 --pack=ww2 --record=user://capture-look.jsonl [--faction=allies]
##
## writes <out>_cockpit.png, _credits.png, _map.png, _message.png, _dialog.png,
## _finder.png, _menu.png, and last _message_urgent.png (the Conflict tab) and
## _message_empty.png (the Chat tab, empty in a game against the computer),
## then _popup.png (the speed menu and a tooltip), then one each of the other
## windows: _ency, _economy, _defense, _fleet, _sector, _status, _personnel,
## _options, _overview, _objectives. --record= is REQUIRED: without it the game's session log
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
	# Keyboard focus on the first launch plate (the side buttons are in every
	# form of the Cockpit).
	var plate: Button = menu.find_child("BtnAlliance", true, false)
	if plate != null and plate.is_visible_in_tree():
		plate.grab_focus()
		for _i in 3:
			await process_frame
		ok = _shot(out, "cockpit_focus") and ok
		plate.release_focus()
	# View Credits, from the Cockpit (the button form's; a picture Cockpit has
	# its own region).
	var credits: Button = menu.find_child("BtnCredits", true, false)
	if credits != null:
		credits.pressed.emit()
		for _i in 4:
			await process_frame
		ok = _shot(out, "credits") and ok
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

	# A CONFLICT DISPATCH, AND A CATEGORY WITH NOTHING IN IT (phase 4). Last, so
	# every shot above is taken exactly as before.
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame
	ui.OnMessageIndexClicked("Conflict")
	for _i in 5:
		await process_frame
	ok = _shot(out, "message_urgent") and ok
	var comms: Node = ui._openWindows.get("Communications")
	if comms != null:
		comms.OpenToCategory("Chat")
	for _i in 3:
		await process_frame
	ok = _shot(out, "message_empty") and ok

	# A MENU AND A TOOLTIP (phase 5): the speed menu dropped under the clock,
	# and beside it a tooltip panel as the viewport makes one (a hover cannot be
	# faked headlessly, so its panel and label are made the same way).
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame
	var speed: Variant = main.get("_speedMenu")
	if speed is PopupMenu:
		(speed as PopupMenu).popup(Rect2i(Vector2i(8, 84), Vector2i.ZERO))
	var tip := PopupPanel.new()
	tip.theme_type_variation = &"TooltipPanel"
	var words := Label.new()
	words.theme_type_variation = &"TooltipLabel"
	words.text = "Game Speed Control"
	tip.add_child(words)
	ui.add_child(tip)
	tip.popup(Rect2i(Vector2i(230, 84), Vector2i.ZERO))
	for _i in 4:
		await process_frame
	ok = _shot(out, "popup") and ok
	if speed is PopupMenu:
		(speed as PopupMenu).hide()
	tip.queue_free()

	# THE OTHER WINDOWS (phase 6), one at a time.
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var others := [
		["ency", func() -> void: ui.OpenEncyclopedia()],
		["economy", func() -> void: ui.OnEconomyClicked(home)],
		["defense", func() -> void: ui.OnDefenseClicked(home)],
		["fleet", func() -> void: ui.OnFleetClicked(home)],
		["sector", func() -> void: ui.OnSectorClicked(sector)],
		["status", func() -> void: ui.OpenCharacterStatusWindow(who)],
		["personnel", func() -> void: ui.OpenPersonnelFinder()],
		["options", func() -> void: ui.OpenGameOptions()],
		["overview", func() -> void: ui.OpenGalaxyOverview()],
		["objectives", func() -> void: ui.OpenObjectives()],
	]
	for o in others:
		ui.CloseAllWindows()
		for c in ui.get_children():
			if c is GameOptionsWindow or c is GalaxyOverviewWindow or c is ObjectivesWindow:
				c.queue_free()
		for _i in 3:
			await process_frame
		(o[1] as Callable).call()
		for _i in 5:
			await process_frame
		ok = _shot(out, str(o[0])) and ok

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
