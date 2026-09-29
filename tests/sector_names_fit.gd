extends SceneTree
## THE PLAIN SECTOR WINDOW KEEPS EVERY SYSTEM INSIDE IT (sector_window.gd
## Populate's safety floor). A flat sector - the WWII pack's British Isles - came
## out shorter than its own padding: the lowest system's name fell out under the
## window, and the systems' north-south order came out upside down. For every
## sector of the pack, in the plain window:
##   1. every system's name lies inside the window's map;
##   2. a system further south on the galaxy map is no higher in the window.
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
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
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
			if c is Label and (c as Label).text == p.Name:
				var r := Rect2((c as Control).position, (c as Control).size)
				_check(box.encloses(r), "%s: %s's name inside the window (%s in %s)" % [sector.Name, p.Name, r, box.size])
			elif c is SectorWin.PlanetMapButton:
				tops[p] = (c as Control).position.y
		for a in tops:
			for b in tops:
				if (a as Planet).MapY < (b as Planet).MapY - 0.001:
					_check(tops[a] <= tops[b] + 0.5, "%s: %s (north) not below %s (south)" % [sector.Name, (a as Planet).Name, (b as Planet).Name])
	_check(sectors > 0, "%s: plain sector windows checked (%d)" % [id, sectors])
	print("[sector_names_fit] %s: %d sectors, %d checks, %d failed" % [id, sectors, _checks, _fails])
	quit(1 if _fails > 0 else 0)
