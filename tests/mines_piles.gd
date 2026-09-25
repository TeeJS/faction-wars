extends SceneTree
## The original's Mines tab (manual p027 Fig 2.11: "mines as mechanical units
## and raw material as multicoloured piles"; TeeJ, 2026-09-25, with his
## screenshot of the original's Coruscant Mines tab): the mines as the
## original's 67x35 picture on a 69x40 grid from (8, 24), then one pile per
## free mine slot; a pile's right-click menu is Encyclopedia and Status, both
## greyed. Without the pictures (an older art set) the tab is as before.
## Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/mines_piles.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const K := OUI.K

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mines_piles] ok   %s" % what)
	else:
		_fails += 1
		print("[mines_piles] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-mines-piles-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var side: String = OUI.Side(us)

	# The original's Manufacturing window, as plain test pictures.
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/mfg_background.png" % dir, 226, 304, Color(0.2, 0.2, 0.2))
	_png("%s/windows/mfg_column.png" % dir, 46, 226, Color(0.3, 0.3, 0.3))
	_png("%s/windows/mfg_row.png" % dir, 166, 79, Color(0.1, 0.1, 0.1))
	_png("%s/windows/header.%s.png" % [dir, side], 162, 13, Color(0, 0.6, 0))
	for t in EconomyWindow.TabNames:
		for st in ["", ".pressed", ".grey"]:
			_png("%s/tabs/%s.%s%s.png" % [dir, t, side, st], 36, 33, Color(0.5, 0.5, 0.5))
	for b in ["title_system", "title_minimize", "title_close"]:
		_png("%s/buttons/%s.png" % [dir, b], 14, 14, Color(0.8, 0.8, 0.8))
	Art.Reset()

	# A world of ours with mines and raw material left in the ground.
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and p.Mines() > 0 and p.FreeMineSlots() > 0)
	_check(home != null, "a world of ours with mines and unmined raw material")
	if home == null:
		_finish()
		return

	# An older art set: no mine or pile pictures, no piles.
	var page: Control = await _mines_page(ui, home)
	_check(page != null and _piles(page).is_empty(), "without the pictures the Mines tab has no piles (as before)")

	_png("%s/windows/mine_tile.png" % dir, 67, 35, Color(0.8, 0.6, 0.2))
	_png("%s/windows/mine_pile.png" % dir, 67, 35, Color(0.9, 0.4, 0.1))
	Art.Reset()
	page = await _mines_page(ui, home)
	_check(page != null, "the Mines tab opens")
	if page == null:
		_finish()
		return
	var mines: Array = page.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.has_meta("card"))
	var piles: Array = _piles(page)
	_check(mines.size() == home.Mines(), "a card per mine (%d)" % mines.size())
	_check(piles.size() == home.FreeMineSlots(), "a pile per free mine slot (%d of %d raw material)" % [piles.size(), home.BaseRawMaterials])
	var mine: Control = mines[0] if not mines.is_empty() else null
	_check(mine != null and mine.custom_minimum_size == Vector2(69, 40) * K
		and (mine.get_node("Picture") as TextureRect).position == Vector2(1, 2) * K
		and (mine.get_node("Picture") as TextureRect).texture.get_size() == Vector2(67, 35) * K, "a mine: the 67x35 picture at (1, 2) of its 69x40 cell")
	var pile: Control = piles[0] if not piles.is_empty() else null
	_check(pile != null and pile.custom_minimum_size == Vector2(69, 40) * K
		and (pile.get_node("Picture") as TextureRect).position == Vector2.ZERO, "a pile: its picture at its cell's corner")
	var scroll: Control = (mine.get_parent() as Control).get_parent() if mine != null else null
	_check(scroll != null and scroll.position == Vector2(8, 24) * K, "the grid from (8, 24) of the page")
	if mine != null and pile != null:
		var list: Node = mine.get_parent()
		_check(Lq.all(mines, func(m: Node) -> bool: return m.get_index() < pile.get_index()), "the mines first, then the piles")
		_check(list.get_child_count() == mines.size() + piles.size(), "nothing else on the grid")
	if pile != null:
		var pm: PopupMenu = Lq.first_or_null(pile.get_children(), func(c) -> bool: return c is PopupMenu)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = true
		e.global_position = pile.get_global_rect().get_center()
		pile.gui_input.emit(e)
		await process_frame
		_check(pm != null and pm.visible, "right-clicking a pile brings up its menu")
		_check(pm != null and pm.item_count == 2 and pm.get_item_text(0) == "Encyclopedia" and pm.get_item_text(1) == "Status"
			and pm.is_item_disabled(0) and pm.is_item_disabled(1), "Encyclopedia and Status, both greyed (the original's)")
	_finish()


## The Mines tab of the system's Manufacturing window, opened afresh.
func _mines_page(ui: UIManager, home: Planet) -> Control:
	for c in ui.get_children():
		if c is EconomyWindow:
			(c as EconomyWindow).CloseWindow()
	for _i in 2:
		await process_frame
	ui.OnEconomyClicked(home)
	for _i in 3:
		await process_frame
	var w: EconomyWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is EconomyWindow and not n.is_queued_for_deletion())
	if w == null:
		return null
	var tabs: TabContainer = w.get_node("%EconomyTabs")
	tabs.current_tab = tabs.get_tab_count() - 1
	w.Populate(home)
	for _i in 2:
		await process_frame
	return tabs.get_child(tabs.get_tab_count() - 1)


static func _piles(page: Node) -> Array:
	return page.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b.has_meta("pile"))


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[mines_piles] %d checks, %d failed" % [_checks, _fails])
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
