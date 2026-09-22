extends SceneTree
## The theatres are pinned (TeeJ, 2026-09-22): every sector has a permanent
## button on the side panel from the start, in map order; pressing it opens the
## sector window; minimising or closing that window leaves the button where it
## is and pressing it again brings the window back. Other windows still
## minimise to the panel (gaining a button) and close for good.
##
##   .\tools\run-gd.ps1 tests/sector_pins.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/sector_pins.gd              (Star Wars)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[sector_pins] ok   %s" % what)
	else:
		_fails += 1
		print("[sector_pins] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Huge
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame

	var ui: UIManager = main.get_node("UIManager")
	var list: VBoxContainer = ui.get_node("%TaskbarList")
	var galaxy: Array = GameState.ActiveGalaxy
	var pins := ui.PinnedSectors()
	_check(pins.size() == galaxy.size(), "one pinned button per sector (%d of %d)" % [pins.size(), galaxy.size()])
	# The docked GID key button is first; the pins follow it, contiguous, in map order.
	var first := -1
	for i in list.get_child_count():
		if list.get_child(i) == pins[galaxy[0].Name]:
			first = i
	_check(first >= 0 and first <= 1, "the pins start at the top of the panel, after the docked key at most (index %d)" % first)
	var in_order := true
	for i in galaxy.size():
		var b: Button = list.get_child(first + i)
		if b.text != galaxy[i].Name:
			in_order = false
	_check(in_order, "the pinned buttons are contiguous and in map order")
	if first == 1:
		_check(not pins.values().has(list.get_child(0)), "the item above them is the panel's own (the docked key)")
	var panel_before := list.get_child_count()

	# Press one: its window opens.
	var sector: Sector = galaxy[0]
	var pin: Button = pins[sector.Name]
	pin.pressed.emit()
	for _i in 3:
		await process_frame
	var win: DraggableWindow = _window_titled(ui, sector.Name)
	_check(win != null and win.visible, "pressing '%s' opens its window" % sector.Name)

	# Minimise it: no second button appears, and the pin brings it back.
	win.MinimizeWindow()
	for _i in 2:
		await process_frame
	_check(not win.visible, "minimising hides the window")
	_check(list.get_child_count() == panel_before, "minimising a pinned theatre adds no second button (%d)" % list.get_child_count())
	pin.pressed.emit()
	for _i in 2:
		await process_frame
	_check(is_instance_valid(win) and win.visible, "the pin restores the same window")

	# Close it: the pin stays, and reopens a fresh window.
	win.CloseWindow()
	for _i in 3:
		await process_frame
	_check(is_instance_valid(pin) and pin.get_parent() == list, "closing leaves the pin on the panel")
	_check(_window_titled(ui, sector.Name) == null, "the window is gone after close")
	pin.pressed.emit()
	for _i in 3:
		await process_frame
	_check(_window_titled(ui, sector.Name) != null, "the pin opens the theatre again")

	# An ordinary window still minimises to the panel with its own button.
	var planet: Planet = sector.Planets[0]
	ui.OnPlanetClicked(planet)
	for _i in 3:
		await process_frame
	var pw: DraggableWindow = _window_titled(ui, planet.Name)
	_check(pw != null, "a planet window opens as before")
	if pw != null:
		pw.MinimizeWindow()
		for _i in 2:
			await process_frame
		_check(list.get_child_count() == panel_before + 1, "an ordinary window minimises to a new panel button (%d)" % list.get_child_count())

	# --- Unpin / re-pin (TeeJ, 2026-09-22) ---
	var second: Sector = galaxy[1]
	var pin2: Button = pins[second.Name]
	pin2.pressed.emit()
	for _i in 3:
		await process_frame
	_check(_window_titled(ui, second.Name) != null, "'%s' is open before unpinning" % second.Name)
	ui.ShowPinMenu(second)
	_check(ui.PinMenu() != null and ui.PinMenu().get_item_text(0) == "Unpin from menu", "the pinned theatre's menu says 'Unpin from menu'")
	ui.PinMenu().hide()
	ui.UnpinSector(second.Name)
	for _i in 3:
		await process_frame
	_check(not ui.IsPinned(second) and not is_instance_valid(pin2), "unpinning removes the button")
	_check(_window_titled(ui, second.Name) == null, "unpinning closes its open window")
	var count_after_unpin := list.get_child_count()
	ui.OnSectorClicked(second)
	for _i in 3:
		await process_frame
	var w2: DraggableWindow = _window_titled(ui, second.Name)
	_check(w2 != null, "an unpinned theatre still opens from the map")
	ui.ShowPinMenu(second)
	_check(ui.PinMenu().get_item_text(0) == "Pin to menu", "the unpinned theatre's menu says 'Pin to menu'")
	ui.PinMenu().hide()
	w2.MinimizeWindow()
	for _i in 2:
		await process_frame
	_check(list.get_child_count() == count_after_unpin + 1, "an unpinned theatre minimises to a normal panel button")
	ui.PinSector(second)
	for _i in 2:
		await process_frame
	_check(ui.IsPinned(second), "re-pinning restores the button")
	var idx: int = (ui.PinnedSectors()[second.Name] as Button).get_index()
	var idx_first: int = (ui.PinnedSectors()[galaxy[0].Name] as Button).get_index()
	_check(idx == idx_first + 1, "the re-pinned button returns to its place in map order (%d after %d)" % [idx, idx_first])
	# The pin is back (+1) and the minimised-window button is gone (-1).
	_check(list.get_child_count() == count_after_unpin + 1, "re-pinning removed the redundant minimised-window button (%d)" % list.get_child_count())
	(ui.PinnedSectors()[second.Name] as Button).pressed.emit()
	for _i in 2:
		await process_frame
	_check(is_instance_valid(w2) and w2.visible, "the re-pinned button restores the minimised window")

	print("[sector_pins] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
