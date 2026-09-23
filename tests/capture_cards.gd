extends SceneTree
## Renders the card grids with a card picked: the Manufacturing window on a
## world of ours with four or more of one facility (the second row's card
## picked - TeeJ's Selonia Refineries), and the System Defenses window with
## the first person picked (his Coruscant Personnel). Needs a window (NOT
## --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_cards.gd -- --out=C:/tmp/cards.png [--faction=alliance]
##   writes <out minus .png>_facilities.png and _personnel.png, each the window

const FacilityTabs := ["Shipyards", "Training Facilities", "Construction Yards", "Refineries", "Mines"]


func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://cards.png").trim_suffix(".png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "empire"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var ok := true
	# A world with 4+ of one facility family, and the tab that lists them.
	var world: Planet = null
	var family: String = ""
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		var counts: Dictionary = {}
		for f in p.Facilities:
			counts[f.Family()] = int(counts.get(f.Family(), 0)) + 1
		for fam in counts:
			if counts[fam] >= 4:
				world = p
				family = fam
		if world != null:
			break
	if world != null:
		ui.OnEconomyClicked(world)
		for _i in 3:
			await process_frame
		var ew: Node = ui._openWindows.get(world.Name + " Economy")
		var tabs: TabContainer = ew.get_node("%EconomyTabs")
		for i in tabs.get_tab_count():
			var cards: Array = _cards(tabs.get_child(i))
			if cards.size() >= 4 and (cards[0] as Control).tooltip_text.to_lower().contains(family.split("_")[0]):
				tabs.current_tab = i
				for _k in 2:
					await process_frame
				(cards[4 if cards.size() > 4 else 3] as BaseButton).button_pressed = true
				break
		for _i in 3:
			await process_frame
		ok = _shot(ew, out + "_facilities.png") and ok
		print("[capture_cards] %s: %s" % [world.Name, family])
		ew.CloseWindow()
	# The Defenses Personnel grid, the first person picked.
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and Lq.count(GameState.ActiveRoster, func(c: Character) -> bool:
			return c.Faction == us and c.Attached == p and not c.IsOffMap()) >= 2)
	if home != null:
		ui.OnDefenseClicked(home)
		for _i in 3:
			await process_frame
		var dw: Node = ui._openWindows.get(home.Name + " Defenses")
		var cards: Array = _cards(dw.get_node("%PersonnelList"))
		if not cards.is_empty():
			(cards[0] as BaseButton).button_pressed = true
		for _i in 3:
			await process_frame
		ok = _shot(dw, out + "_personnel.png") and ok
		print("[capture_cards] %s personnel: %d cards" % [home.Name, cards.size()])
	quit(0 if ok else 1)


func _cards(node: Node) -> Array:
	var out: Array = []
	if node.has_meta("card") and node is BaseButton:
		out.append(node)
	for c in node.get_children():
		out.append_array(_cards(c))
	return out


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	return img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
