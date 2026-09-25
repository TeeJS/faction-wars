extends SceneTree
## A click on a planet in a Sector window does nothing (TeeJ, 2026-09-24: it
## opened the plain Planet window; "it should do nothing") - except name the
## system while the crosshair is up.
##
##   .\tools\run-gd.ps1 tests/planet_click.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[planet_click] ok   %s" % what)
	else:
		_fails += 1
		print("[planet_click] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var sector: Sector = GameState.ActiveGalaxy[0]
	var planet: Planet = sector.Planets[0]
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var win: Node = null
	for c in ui.get_children():
		if c is SectorWindow and (c as DraggableWindow).WindowTitle == sector.Name:
			win = c
	var btn: Button = _button(win, planet)
	_check(btn != null, "the planet's button in the %s window" % sector.Name)
	if btn == null:
		_finish()
		return
	var before := ui.get_child_count()
	btn.pressed.emit()
	for _i in 3:
		await process_frame
	_check(not ui._openWindows.has(planet.Name) and ui.get_child_count() == before, "a click on %s opens nothing" % planet.Name)

	var named: Array = []
	ui.StartTargeting(func(p: Planet) -> void: named.append(p))
	btn = _button(win, planet)   # the window may have repainted (the clock runs)
	btn.pressed.emit()
	for _i in 2:
		await process_frame
	_check(named == [planet], "with the crosshair up, the click names %s" % planet.Name)
	_finish()


## The planet's button as the window has it now.
static func _button(win: Node, planet: Planet) -> Button:
	if win == null:
		return null
	for c in win.find_children("*", "Button", true, false):
		if c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == planet and not c.is_queued_for_deletion():
			return c
	return null


func _finish() -> void:
	print("[planet_click] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
