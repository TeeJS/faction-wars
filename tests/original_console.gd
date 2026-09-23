extends SceneTree
## The bottom bar's buttons wear the original's console screens (manual p022
## Fig 2.3) when the player imported them: the System / Fleet / Troop /
## Personnel Finders, the GID control and the Encyclopedia button, with the
## label as the tooltip; text buttons again when the files are gone. Writes
## and removes its own test files under user://.
##
##   .\tools\run-gd.ps1 tests/original_console.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/original_console.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_console] ok   %s" % what)
	else:
		_fails += 1
		print("[original_console] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
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
	var pack_id: String = FactionRegistry.Pack.Manifest.Id
	var bar: HBoxContainer = ui.get_node("HBoxContainer")
	var planet: Button = bar.get_node("PlanetInfo")
	var ency: Button = bar.get_node("Encyclopedia")
	_check(planet.icon == null and planet.text == "Planet Info.", "without an import the Planet Info button is text")

	var dir := "user://original/%s/console" % pack_id
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.3, 0.6))
	var paths: Array[String] = ["%s/%s.system_finder.png" % [dir, us.Id], "%s/%s.encyclopedia.png" % [dir, us.Id]]
	for p in paths:
		img.save_png(p)
	Art.Reset()
	ui.DressConsole()
	_check(planet.icon != null and planet.text.is_empty() and planet.tooltip_text == "Planet Info.", "with a screen imported the Planet Info button shows it, name as tooltip")
	_check(planet.custom_minimum_size == Vector2(32, 20) * UIManager.ConsoleScale + Vector2(8, 8), "the screen is drawn at 2x")
	_check(ency.icon != null and ency.text.is_empty(), "the Encyclopedia button shows its screen")
	var ship: Button = bar.get_node("ShipInfo")
	_check(ship.icon == null and ship.text == "Ship Info.", "a control with no imported screen stays a text button")

	for p in paths:
		DirAccess.remove_absolute(p)
	Art.Reset()
	ui.DressConsole()
	_check(planet.icon == null and planet.text == "Planet Info." and ency.text == "Encyclopedia", "with the files removed the buttons are text again")

	print("[original_console] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
