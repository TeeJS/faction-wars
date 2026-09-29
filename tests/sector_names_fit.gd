extends SceneTree
## THE PLAIN SECTOR WINDOW KEEPS EVERY SYSTEM INSIDE IT (sector_window.gd
## Populate's safety floor). A flat sector - the WWII pack's British Isles - came
## out shorter than its own padding: the lowest system's name fell out under the
## window, and the systems' north-south order came out upside down. Then
## (TeeJ, 2026-09-29) a system near the right edge with a long row of squares -
## Hungary, Switzerland - had its squares run past the window's edge. For every
## sector of the pack (the Huge galaxy, so every sector there is), in the plain
## window:
##   1. every part of every system's entry - its picture, star, corner icons,
##      bars and name - lies inside the window's map;
##   2. the sector is the right way up: its northernmost system on the galaxy
##      map is no lower in the window than its southernmost.
##
##   .\tools\run-gd.ps1 tests/sector_names_fit.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/sector_names_fit.gd -- --seed=12345      (Star Wars)

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const SectorWin := preload("res://src/ui/sector_window.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("[sector_names_fit] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-sector-names-none"
	# The plain window (without the art the Star Wars pack builds the
	# original's from our stand-ins).
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Huge
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()
	_check(not GameState.ActiveGalaxy.is_empty(), "%s: the game started" % id)

	var sectors := 0
	for sector in GameState.ActiveGalaxy:
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnSectorClicked(sector)
		for _i in 3:
			await process_frame
		var w: Node = ui._openWindows.get(sector.Name)
		if w == null:
			_check(false, "%s: its window opened" % sector.Name)
			continue
		if w.get("OriginalLook") == true:
			continue   # the original's box, measured on the original's
		sectors += 1
		var map: Control = w.get_node("%SectorMap")
		var box := Rect2(Vector2.ZERO, map.custom_minimum_size)
		var tops: Dictionary = {}   # Planet -> its button's top
		for c in map.get_children():
			if not c.has_meta("system") or c.is_queued_for_deletion():
				continue
			var p: Planet = c.get_meta("system")
			if not (c is Control) or not (c as Control).visible:
				continue
			var r := Rect2((c as Control).position, (c as Control).size)
			var part: String = "name" if c is Label and (c as Label).text == p.Name else \
					("%s bar" % c.get_meta("bar_row") if c.has_meta("bar_row") else \
					("%s icon" % c.get_meta("corner") if c.has_meta("corner") else \
					("picture" if c is SectorWin.PlanetMapButton else str(c.name))))
			_check(box.encloses(r), "%s: %s's %s inside the window (%s in %s)" % [sector.Name, p.Name, part, r, box.size])
			if c is SectorWin.PlanetMapButton:
				tops[p] = (c as Control).position.y
		# The sector the right way up: its northernmost system above its
		# southernmost. (Not every pair: SeparateEntries may nudge two systems
		# at nearly one latitude past each other to keep them apart - Libya and
		# Egypt, 182 and 185 - which is its job.)
		var north: Planet = null
		var south: Planet = null
		for p in tops:
			if north == null or (p as Planet).MapY < north.MapY:
				north = p
			if south == null or (p as Planet).MapY > south.MapY:
				south = p
		if north != null and south != null and north.MapY < south.MapY:
			_check(tops[north] <= tops[south], "%s: %s (north, map y %.0f, top %.1f) above %s (south, map y %.0f, top %.1f)" % [sector.Name,
				north.Name, north.MapY, tops[north], south.Name, south.MapY, tops[south]])
	_check(sectors > 0, "%s: plain sector windows checked (%d)" % [id, sectors])
	print("[sector_names_fit] %s: %d sectors, %d checks, %d failed" % [id, sectors, _checks, _fails])
	quit(1 if _fails > 0 else 0)
