extends SceneTree
## The original's Fleet window (manual p112-p113 Figs 3.54-3.56; TeeJ's
## screenshot of the Chandrila window, 2026-09-24): with the art imported the
## window is titled with the system's name; each fleet is a tile down the
## left with its picture, name and badges, the shown one framed; the panel
## carries the name, the picture, four tabs and the contents as rows (a
## picture and a name, a capital ship with its cargo badges); a tab with
## nothing on it is greyed; carried and capacity show on the fighter and
## troop tabs; a double-clicked fleet lists its ships, and a ship shows its
## own three tabs. A person's and a regiment's row stands on the grey plate,
## a ship's and a squadron's does not (TeeJ, 2026-09-25: "just like on
## planet (fighters should NOT)"). Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/fleet_window_original.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_window_original] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_window_original] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-fleet-window-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/fleet_background.png" % dir, 235, 304, Color(0.05, 0.05, 0.1))
	_png("%s/windows/card_plate.png" % dir, 61, 25, Color(0.4, 0.4, 0.45))
	for side in ["alliance", "empire"]:
		_png("%s/windows/fleet_panel.%s.png" % [dir, side], 132, 266, Color(0, 0, 0, 0.5))
		_png("%s/windows/fleet_tile.%s.png" % [dir, side], 73, 47, Color(0, 1, 0, 0.3))
		_png("%s/windows/fleet_small.%s.png" % [dir, side], 66, 25, Color(0.6, 0.6, 0.6))
		_png("%s/windows/status_fleet.%s.png" % [dir, side], 122, 50, Color(0.6, 0.6, 0.6))
		for b in ["fighter", "troop", "personnel"]:
			_png("%s/windows/fleet_badge_%s.%s.png" % [dir, b, side], 15, 11, Color(1, 1, 1))
		for t in ["fleet_tab_ship", "fleet_tab_fighter", "fleet_tab_troop", "fleet_tab_personnel"]:
			for st in ["", ".pressed", ".grey"]:
				_png("%s/tabs/%s.%s%s.png" % [dir, t, side, st], 31, 29, Color(0.3, 0.3, 0.3))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var home: Planet = null
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and (fleet == null or f.Ships.size() > fleet.Ships.size()):
				fleet = f
				home = p
	_check(fleet != null, "a fleet of ours to show")
	if fleet == null:
		_finish()
		return
	# Someone aboard and a regiment in a hold, for the plates.
	var aboard: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and not c.IsOffMap())
	if aboard != null:
		aboard.Attached = fleet
	var regiment: Unit = null
	for p in GameState.AllPlanets():
		for u in p.Garrison:
			if regiment == null and u.Faction == us and u.Type == Enums.UnitType.Troop:
				regiment = u
	if regiment != null and not Lq.any(fleet.Ships, func(s: Unit) -> bool:
			return Lq.any(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop)):
		(regiment.Attached as Planet).Garrison.erase(regiment)
		fleet.Ships[0].Hangar.append(regiment)
		regiment.Attached = fleet
	# And a squadron, which stands on no plate.
	var squadron: Unit = null
	for p in GameState.AllPlanets():
		for u in p.FighterSquadrons:
			if squadron == null and u.Faction == us:
				squadron = u
	if squadron != null and not Lq.any(fleet.Ships, func(s: Unit) -> bool:
			return Lq.any(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)):
		(squadron.Attached as Planet).FighterSquadrons.erase(squadron)
		fleet.Ships[0].Hangar.append(squadron)
		squadron.Attached = fleet
	ui.OnFleetClicked(home)
	for _i in 3:
		await process_frame
	var w: FleetWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetWindow)
	_check(w != null and w._original, "the Fleet window is the original's")
	if w == null or not w._original:
		_finish()
		return
	_check((w.get_node("%TitleBarLabel") as Label).text == home.Name, "titled with the system's name alone")
	var tile: Button = _tile_for(w, fleet)
	_check(tile != null and tile.get_node_or_null("Picture") != null and (tile.get_node("Name") as Label).text == fleet.Name,
		"the fleet's tile: its picture and its name")
	# It opens with the tiles alone (Fig. 3.54; TeeJ's Xyquine screenshot).
	var panel: CanvasItem = (w.get_node("%FleetTabs") as Node).get_parent().get_node("Panel")
	_check(not panel.visible and not (w.get_node("%FleetTabs") as CanvasItem).visible and w._shown == null
		and tile != null and not tile.get_node("Frame").visible, "it opens with the fleets' tiles alone, no contents panel")
	tile.button_pressed = true
	await process_frame
	_check(panel.visible and w._shown == fleet, "clicking a fleet brings up its contents")
	_check(tile != null and tile.get_node("Frame").visible, "the shown fleet's tile is framed")
	var c: Dictionary = FleetWindow.Carried(fleet)
	_check(tile != null and (tile.get_node_or_null("Badge_fighter") != null) == (c["fighters"] > 0)
		and (tile.get_node_or_null("Badge_troop") != null) == (c["troops"] > 0), "its badges say what it carries")
	var name: Label = w.get_node("%SelectedFleetName")
	_check(name.text == fleet.Name and name.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "the panel names the fleet from its left")
	var tabs: TabContainer = w.get_node("%FleetTabs")
	var ships: int = Lq.count(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	_check(FleetWindow._RowsOn(tabs.get_node("Capital Ships")) == ships, "a row per capital ship (%d)" % ships)
	for i in 4:
		var n: int = FleetWindow._RowsOn(tabs.get_child(i))
		_check(tabs.is_tab_disabled(i) == (n == 0 and i != tabs.current_tab), "tab %d greyed only when empty (%d rows)" % [i, n])
	# The grey plate: under people and regiments, not ships or squadrons.
	for page_plated in [["Capital Ships", false], ["Fighters", false], ["Troops", true], ["Personnel", true]]:
		var rows: Array = _rows(tabs.get_node(page_plated[0]))
		var plated: int = Lq.count(rows, func(b: Button) -> bool: return b.get_node_or_null("Plate") != null)
		_check(not rows.is_empty(), "the %s page has rows (%d)" % [page_plated[0], rows.size()])
		_check(plated == (rows.size() if page_plated[1] else 0),
			"%s: %s (%d of %d rows plated)" % [page_plated[0], "on the grey plate" if page_plated[1] else "no plate", plated, rows.size()])
	tabs.current_tab = 1
	await process_frame
	_check(w._oCarried.text == str(c["fighters"]) and w._oCapacity.text == str(c["fighter_cap"]),
		"the fighter tab: carried %s, capacity %s" % [w._oCarried.text, w._oCapacity.text])
	tabs.current_tab = 0
	await process_frame
	_check(w._oCarried.text == "" and w._oCapacity.text == "", "no counts on the capital ships tab")

	# Opened: its ships under it; one shown with three tabs.
	w._opened[fleet] = true
	w.Populate(home, ui)
	await process_frame
	var ship: Unit = Lq.first_or_null(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	_check(_tile_for(w, ship) != null, "double-clicked open, its ships are listed under it")
	w._ShowShip(ship)
	await process_frame
	var strip: Array = tabs.get_meta("tab_strip")
	_check(not (strip[0] as Control).visible, "a ship shows three tabs (no capital ships tab)")
	_check(tabs.current_tab > 0, "and one of those three is current (%d)" % tabs.current_tab)
	var hangar_f: int = Lq.count(ship.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
	_check(FleetWindow._RowsOn(tabs.get_node("Fighters")) == hangar_f, "the fighter page lists its own squadrons (%d)" % hangar_f)
	_check(name.text == ship.Name, "the panel names the ship")
	_finish()


## A page's rows (FleetWindow._Row marks them).
static func _rows(page: Node) -> Array:
	return page.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.has_meta("fleet_row"))


func _tile_for(w: FleetWindow, subject: Object) -> Button:
	for t in w._oTiles:
		if t[1] == subject and is_instance_valid(t[0]):
			return t[0]
	return null


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[fleet_window_original] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
