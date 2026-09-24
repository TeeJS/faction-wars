extends SceneTree
## No system's name, bars or icons over another's in any Sector window (TeeJ,
## 2026-09-23: "there are areas where the text and icons overlap, this should
## be avoided"): every sector of a standard galaxy is opened and each pair of
## systems' entries (picture, star, corner icons, bars, name) is checked, in
## the look this checkout has (the original's with the art imported).
##
##   .\tools\run-gd.ps1 tests/sector_overlaps.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[sector_overlaps] ok   %s" % what)
	else:
		_fails += 1
		print("[sector_overlaps] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var sectors: int = 0
	for sector: Sector in GameState.ActiveGalaxy:
		if sector.Planets.size() < 2:
			continue
		sectors += 1
		ui.OnSectorClicked(sector)
		for _i in 2:
			await process_frame
		var w: Control = ui._openWindows.get(sector.Name)
		if w == null:
			_check(false, "%s's window opens" % sector.Name)
			continue
		var crossing: Array = _Crossing(w.get_node("%SectorMap"))
		_check(crossing.is_empty(), "%s: no two systems' entries cross%s" % [sector.Name,
			"" if crossing.is_empty() else " (" + ", ".join(crossing) + ")"])
		w.CloseWindow()
		for _i in 2:
			await process_frame
	_check(sectors > 3, "%d sectors looked at" % sectors)
	print("[sector_overlaps] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The pairs of systems whose entries' boxes cross.
static func _Crossing(sectorMap: Control) -> Array:
	var boxes: Dictionary = {}
	for c in sectorMap.get_children():
		if not (c is Control) or c.is_queued_for_deletion() or not c.has_meta("system") or not (c as Control).visible:
			continue
		var p: Planet = c.get_meta("system")
		var r := Rect2(c.position, c.size)
		boxes[p] = (boxes[p] as Rect2).merge(r) if boxes.has(p) else r
	var out: Array = []
	var planets: Array = boxes.keys()
	for i in planets.size():
		for j in range(i + 1, planets.size()):
			if (boxes[planets[i]] as Rect2).intersects(boxes[planets[j]]):
				out.append("%s/%s" % [planets[i].Name, planets[j].Name])
	return out
