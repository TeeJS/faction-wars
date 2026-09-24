extends SceneTree
## Renders the original's Battle Alert window (manual p141 Fig. 4.1) on its
## four pages and the battle's results (p152) for a battle staged between the
## two sides' first fleets over an Imperial world, to PNGs cropped to the
## window. Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_battle.gd -- --out=C:/tmp/battle.png [--faction=alliance]
##   writes <out minus .png>_summary.png, _alliance.png, _empire.png, _system.png, _results.png, _results_<side>_<filter>.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://battle.png").trim_suffix(".png")
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
	var fleets := {}
	var where: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			var side: String = f.Faction.Id if f.Faction != null else ""
			if not fleets.has(side) and not f.Ships.is_empty():
				fleets[side] = f
				if side == "empire":
					where = p
	if not (fleets.has("alliance") and fleets.has("empire")):
		print("[capture_battle] no fleet on each side")
		quit(1)
		return
	var r := FleetBattleManager.BattleReport.new()
	r.Where = where
	r.Ours = fleets["alliance"]
	r.Theirs = fleets["empire"]
	r.OurStrength = 500
	r.TheirStrength = 800
	r.WeLost = true
	r.LoserWithdrew = true
	for s in r.Theirs.Ships:
		var kind: String = "CapitalShips" if s.Type == Enums.UnitType.CapitalShip else "Squadrons"
		r.TheirLosses.add(kind + "Operational", s.Name, "units", s.PackId, false)
		for h in s.Hangar:
			if h.Type == Enums.UnitType.Fighter:
				r.TheirLosses.add("SquadronsOperational", h.Name, "units", h.PackId, false)
			elif h.Type == Enums.UnitType.Troop:
				r.TheirLosses.add("TroopsOperational", h.Name, "units", h.PackId, false)
	for c in GameState.ActiveRoster:
		if c.Faction == r.Theirs.Faction and r.TheirLosses.PersonnelSurvivors.is_empty():
			r.TheirLosses.add("PersonnelSurvivors", c.Name, "characters", c.PackId, false)
	for s in r.Ours.Ships:
		r.OurLosses.add("CapitalShipsDestroyed" if s.Type == Enums.UnitType.CapitalShip else "SquadronsDestroyed", s.Name, "units", s.PackId, false)
		for h in s.Hangar:
			if h.Type == Enums.UnitType.Fighter:
				r.OurLosses.add("SquadronsDestroyed", h.Name, "units", h.PackId, false)
	# One of each side's first entries damaged, to show the flames.
	for list in ["CapitalShipsOperational", "SquadronsOperational"]:
		if r.TheirLosses.Who.has(list) and not r.TheirLosses.Who[list].is_empty():
			r.TheirLosses.Who[list][0]["damaged"] = true
	var alert := BattleAlertWindow.new()
	alert.name = "BattleAlertWindow"
	ui.add_child(alert)
	alert.Setup(r)
	var ok := true
	for page in 4:
		alert._oPage = page
		alert._ShowPage(page)
		for _i in 3:
			await process_frame
		ok = _shot(alert, out + "_%s.png" % ["summary", "alliance", "empire", "system"][page]) and ok
	alert.queue_free()
	var results := BattleResultsWindow.new()
	results.name = "BattleResultsWindow"
	ui.add_child(results)
	results.Setup(r)
	for _i in 3:
		await process_frame
	ok = _shot(results, out + "_results.png") and ok
	for page in [1, 2]:
		for tab in 4:
			results._page = page
			results._tab = tab
			results._ShowPage()
			for _i in 3:
				await process_frame
			ok = _shot(results, out + "_results_%s_%d.png" % ["alliance" if page == 1 else "empire", tab]) and ok
	print("[capture_battle] at %s -> %s" % [where.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position), Vector2i(w.size))
	return img.get_region(r).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
