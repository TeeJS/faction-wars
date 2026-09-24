extends SceneTree
## The original's resource displays (manual p030 Fig. 2.15; TeeJ, 2026-09-23):
## with the art imported the plain row gives way to the strip from the side's
## Command Center frame - raw material, refined material and maintenance
## AVAILABLE, each a number in its panel, the counts and the capacity on the
## panels' tooltips - centred at the top, clear of the docked sector window.
## Writes and removes its own test art, never the player's own.
##
##   .\tools\run-gd.ps1 tests/resource_displays.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[resource_displays] ok   %s" % what)
	else:
		_fails += 1
		print("[resource_displays] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-resource-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	DirAccess.make_dir_recursive_absolute("%s/windows" % dir)
	for side in ["alliance", "empire"]:
		_png("%s/windows/hud_resources.%s.png" % [dir, side], 320, 30, Color(0.2, 0.2, 0.2))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var gm: GameManager = main
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	_check(gm._oResources != null and not (ui.get_node("Resources") as Control).visible, "the plain row gives way to the original's strip")
	if gm._oResources == null:
		_finish()
		return
	gm.RefreshStatusBar()
	var econ: Economy.FactionEconomy = Economy.For(us)
	var figures: Array = Lq.select(gm._oFigures, func(l: Label) -> String: return l.text)
	_check(figures == [str(econ.RawMaterials), str(econ.RefinedMaterials), str(Economy.MaintenanceAvailable(us))],
		"raw, refined and maintenance available, as numbers alone (%s)" % str(figures))
	var tip: String = (gm._oResources.get_node("Hover2") as Control).tooltip_text
	_check(tip.contains(str(Economy.MaintenanceCapacity(us))), "the maintenance panel's tooltip gives the capacity ('%s')" % tip)
	var mid: float = gm._oResources.position.x + gm._oResources.size.x / 2.0
	_check(absf(mid - main.get_viewport().get_visible_rect().size.x / 2.0) <= 1.0, "centred at the top")
	var bottom: float = gm._oResources.position.y + gm._oResources.size.y
	_check(bottom <= SectorWindow.DockPosition(true).y, "clear of the docked sector window (%.0f <= %.0f)" % [bottom, SectorWindow.DockPosition(true).y])
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[resource_displays] %d checks, %d failed" % [_checks, _fails])
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
