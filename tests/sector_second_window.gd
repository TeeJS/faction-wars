extends SceneTree
## A second sector window opens on the other side from the one already open,
## not over it (TeeJ, 2026-09-25: "it should default to the opposite side of
## the screen"): in the original's look (docked right, then left) and the
## plain one (upper left, then right). With both sides taken, the usual side.
## Writes and removes its own stand-in art under user://.
##
##   .\tools\run-gd.ps1 tests/sector_second_window.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-sector-second-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[sector_second_window] ok   %s" % what)
	else:
		_fails += 1
		print("[sector_second_window] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot   # never the player's own
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	await _run(false)
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	if not sets.is_empty():
		var dir := "%s/%s" % [ArtRoot, sets[0]]
		for sub in ["planet_sprites", "buttons"]:
			DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
		_png("%s/planet_sprites/1.png" % dir, 20, 20)
		for b in ["sector_switch", "title_close", "title_minimize"]:
			_png("%s/buttons/%s.png" % [dir, b], 14, 14)
		Art.Reset()
		await _run(true)
		_remove(ArtRoot)
		Art.Reset()
	print("[sector_second_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run(original: bool) -> void:
	var look := "original" if original else "plain"
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	_check(SectorWindow.CanBuildOriginal() == original, "%s: the %s sector window" % [look, look])
	var galaxy: Array = GameState.ActiveGalaxy
	var mid: float = UIManager.MapFrame.get_center().x if original else root.get_visible_rect().size.x / 2.0
	var side := func(w: Control) -> String: return "right" if w.get_global_rect().get_center().x >= mid else "left"
	var usual := "right" if original else "left"
	var other := "left" if original else "right"
	var opened: Array = []
	for i in 3:
		ui.OnSectorClicked(galaxy[i])
		for _f in 3:
			await process_frame
		opened.append(ui._openWindows.get((galaxy[i] as Sector).Name))
	var a: Control = opened[0]
	var b: Control = opened[1]
	var c: Control = opened[2]
	_check(a != null and side.call(a) == usual, "%s: the first opens on the %s" % [look, usual])
	_check(b != null and side.call(b) == other, "%s: the second opens on the %s, not over the first" % [look, other])
	_check(c != null and side.call(c) == usual, "%s: with both sides taken, the third on the %s" % [look, usual])
	if original and b != null:
		_check(b.get("_dockRight") == false, "original: the second's side box knows it is on the left")
	# Close the first: the next opens on the side it freed.
	(a as DraggableWindow).CloseWindow()
	(c as DraggableWindow).CloseWindow()
	for _f in 3:
		await process_frame
	ui.OnSectorClicked(galaxy[3])
	for _f in 3:
		await process_frame
	var d: Control = ui._openWindows.get((galaxy[3] as Sector).Name)
	_check(d != null and side.call(d) == usual, "%s: its side freed, the next opens on the %s again" % [look, usual])
	root.remove_child(main)
	main.free()
	for _f in 2:
		await process_frame


static func _png(path: String, w: int, h: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
