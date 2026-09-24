extends SceneTree
## The Fleet Finder and the Ship Finder (manual p125 Fig. 3.70, p126 Fig.
## 3.72; TeeJ, 2026-09-24: "Ship Info should be renamed Fleet Finder and
## implemented with the same UI as original (good reminder we only see what
## we know about)"): the bottom bar's button opens it; three tabs, all and
## each side's; every fleet of ours and only the opponent's we have sighted;
## the switch buttons turn it into the Ship Finder and back; Display opens the
## Fleet and Sector windows where it is. Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/fleet_finder.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_finder] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_finder] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-fleet-finder-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/finder_side4.alliance.png" % dir, 58, 330, Color(0.5, 0.5, 0.6))
	for side in ["alliance", "empire"]:
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		_png("%s/windows/finder_fleets.%s.png" % [dir, side], 400, 306, Color(0.1, 0.1, 0.4))
		_png("%s/windows/finder_ships.%s.png" % [dir, side], 400, 306, Color(0.1, 0.2, 0.4))
		for b in ["ency_close", "finder_display", "finder_btn_ships", "finder_btn_fleets"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 32, 31, Color(0.6, 0.6, 0.6))
			_png("%s/buttons/%s.%s.pressed.png" % [dir, b, side], 32, 31, Color(0.9, 0.3, 0.3))
	for t in ["finder_tab_all", "finder_tab_rebel", "finder_tab_imperial"]:
		for st in ["", ".pressed", ".grey"]:
			_png("%s/tabs/%s%s.png" % [dir, t, st], 49, 41, Color(0.3, 0.3, 0.3))
	for b in ["scroll_up", "scroll_down", "scroll_thumb_top", "scroll_thumb_mid", "scroll_thumb_bottom"]:
		_png("%s/buttons/%s.png" % [dir, b], 13, 9, Color(0.5, 0.5, 0.5))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var viewer: Faction = GameSettings.PlayerFaction
	var btn: Button = main.get_node("UIManager/HBoxContainer/ShipInfo")
	_check(btn.text == "Fleet Finder", "the bottom bar's button says 'Fleet Finder' ('%s')" % btn.text)
	btn.pressed.emit()
	for _i in 3:
		await process_frame
	var w: FleetFinder = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetFinder)
	_check(w != null and not w._o.is_empty(), "it opens the Fleet Finder, the original's")
	if w == null or w._o.is_empty():
		_finish()
		return
	var body: Control = w._o["body"]
	_check((body.get_node("Title") as Label).text == "Fleet Finder" and (body.get_node("NameLabel") as Label).text == "Fleet Name",
		"titled 'Fleet Finder', its field 'Fleet Name'")
	_check(w._o["tabs"].size() == 3 and w.Caption(0) == "All Fleets" and w.Caption(1).ends_with(" Fleets"),
		"three tabs: %s, %s, %s" % [w.Caption(0), w.Caption(1), w.Caption(2)])

	# Every fleet of ours; the opponent's only where sighted or in view.
	var known: Array = FleetFinder.Known(false)
	var ours := 0
	var mine := 0
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == viewer:
				mine += 1
	for e in known:
		if (e as FleetFinder.Entry).Side == viewer:
			ours += 1
	_check(ours == mine, "every fleet of ours is listed (%d)" % mine)
	var unseen := 0
	for e in known:
		var en: FleetFinder.Entry = e
		if en.Side == viewer:
			continue
		var live: bool = IntelManager.IsLive(viewer, en.Where)
		var view: IntelManager.IntelView = IntelManager.View(viewer, en.Where, Enums.IntelSection.OrbitingShips)
		if not live and not Lq.any(view.Groups, func(g: IntelManager.IntelGroup) -> bool: return g.Name == en.Name):
			unseen += 1
	_check(unseen == 0, "no opponent's fleet we have not seen")

	# The Ship Finder, and back.
	(w._o["buttons"]["finder_btn_ships"] as TextureButton).pressed.emit()
	_check(w.Ships and (body.get_node("Title") as Label).text == "Ship Finder" and w.Caption(0) == "All Ships",
		"'Switch to Ship Finder' makes it the Ship Finder")
	_check((w._o["buttons"]["finder_btn_ships"] as TextureButton).texture_normal == w._o["buttons"]["finder_btn_ships"].get_meta("pressed_tex"),
		"its switch lit")
	var capital := 0
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == viewer:
				capital += Lq.count(f.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	_check(Lq.count(FleetFinder.Known(true), func(e: FleetFinder.Entry) -> bool: return e.Side == viewer) == capital,
		"every capital ship of ours is listed (%d)" % capital)
	(w._o["buttons"]["finder_btn_fleets"] as TextureButton).pressed.emit()
	_check(not w.Ships and (body.get_node("Title") as Label).text == "Fleet Finder", "'Switch back to Fleet Finder'")

	# Display: the Fleet and Sector windows where it is.
	(w._o["tabs"][0] as TextureButton).pressed.emit()
	var target: FleetFinder.Entry = null
	for i in w._shown.size():
		if (w._shown[i] as FleetFinder.Entry).Side == viewer:
			w._o["list"].call("select", i)
			target = w._shown[i]
			break
	(w._o["buttons"]["finder_display"] as TextureButton).pressed.emit()
	for _i in 3:
		await process_frame
	var fw: FleetWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetWindow)
	_check(target != null and fw != null, "Display opens the Fleet window for %s" % (target.Name if target != null else "-"))
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[fleet_finder] %d checks, %d failed" % [_checks, _fails])
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
