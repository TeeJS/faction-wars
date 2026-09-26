extends SceneTree
## Renders the Assault Summary (manual p123, Figs 3.66-3.67) for an assault
## staged as TeeJ's screenshot of the original's has it - the Empire taking
## an Alliance world (Ghorman when the galaxy has it) - to PNGs cropped to the
## window: the summary, each side's forces on every tab, and the held and
## neutral summaries. Needs a window (NOT --headless) and the art (exporter
## 2.4.8 for the scenes and the defense tab):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_assault.gd -- --out=C:/tmp/assault.png [--art=user://capture-art] [--faction=empire]
##   writes <out minus .png>_summary.png, _held.png, _neutral.png, _<side>_<tab>.png

const Art := preload("res://src/ui/artwork.gd")


func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://assault.png").trim_suffix(".png")
	var art := _arg("--art=", "")
	if not art.is_empty():
		Art.UserArtRoot = art
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
	var them: Faction = FactionRegistry.Opponents(us)[0]
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and not f.Ships.is_empty():
				fleet = f
	var target: Planet = null
	for p in GameState.AllPlanets():
		if p.Name == "Ghorman" or (target == null and p.ControllingFaction == them and not p.Facilities.is_empty()):
			target = p
	if fleet == null or target == null:
		print("[capture_assault] no fleet or target")
		quit(1)
		return
	var r := AssaultManager.AssaultReport.new()
	r.Target = target
	r.Attacker = us
	r.Defender = them
	r.Fleet = fleet
	r.Captured = true
	# The fleet's own, and two of each side's regiments: one of ours lost,
	# both of theirs.
	var troop: Unit = null
	var theirs: Unit = null
	for s in fleet.Ships:
		if s.Type == Enums.UnitType.CapitalShip:
			r.AttackerForces.add("CapitalShipsOperational", s.Name, "units", s.PackId, false)
		for h in s.Hangar:
			if h.Type == Enums.UnitType.Fighter:
				r.AttackerForces.add("SquadronsOperational", h.Name, "units", h.PackId, false)
	for p in GameState.AllPlanets():
		for u in p.Garrison:
			if u.Type == Enums.UnitType.Troop:
				if u.Faction == us and troop == null:
					troop = u
				elif u.Faction == them and theirs == null:
					theirs = u
	if troop != null:
		r.AttackerForces.add("TroopsOperational", troop.Name, "units", troop.PackId, false)
		r.AttackerForces.add("TroopsDestroyed", troop.Name, "units", troop.PackId, false)
	if theirs != null:
		for _i in 2:
			r.DefenderForces.add("TroopsDestroyed", theirs.Name, "units", theirs.PackId, false)
	for f in target.Facilities:
		var defensive: bool = f.HasRole("planet_defense") or f.HasRole("shield") or f.HasRole("anti_ship") or f.HasRole("disable")
		r.DefenderForces.add("DefenseOperational" if defensive else "ManufacturingOperational", f.Name(), "facilities", f.TypeId(), false)
	var ok := true
	ui.ShowAssaultSummary(r)
	var w: BattleResultsWindow = ui.get_node("BattleResultsWindow")
	for _i in 3:
		await process_frame
	ok = _shot(w, out + "_summary.png") and ok
	for page in [1, 2]:
		for tab in 6:
			w._page = page
			w._tab = tab
			w._ShowPage()
			for _i in 3:
				await process_frame
			ok = _shot(w, out + "_%s_%d.png" % [w._Skins()[page - 1], tab]) and ok
	w._page = 0
	r.Captured = false
	w._ShowPage()
	for _i in 3:
		await process_frame
	ok = _shot(w, out + "_held.png") and ok
	r.Defender = null
	r.Captured = true
	w._ShowPage()
	for _i in 3:
		await process_frame
	ok = _shot(w, out + "_neutral.png") and ok
	print("[capture_assault] at %s -> %s" % [target.Name, "ok" if ok else "error"])
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
