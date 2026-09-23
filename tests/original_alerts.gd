extends SceneTree
## The Message Alert bar's original icons (manual p022, p081), from the
## player's own import: a category button shows the dim icon, the lit one
## while that category has unread mail, and goes back to text when nothing is
## imported. Writes and removes its own test files under user://.
##
##   .\tools\run-gd.ps1 tests/original_alerts.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/original_alerts.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_alerts] ok   %s" % what)
	else:
		_fails += 1
		print("[original_alerts] FAIL %s" % what)


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
	var list: VBoxContainer = ui.get_node("CommsPanel/Margin/CommsList")
	var loyalty: Button = list.get_node("Loyalty")
	_check(loyalty != null and loyalty.text == "Loyalty" and loyalty.icon == null, "without an import the Loyalty button is text")

	var dir := "user://original/%s/alerts" % pack_id
	DirAccess.make_dir_recursive_absolute(dir)
	var dim := Image.create(27, 22, false, Image.FORMAT_RGBA8)
	dim.fill(Color(0.3, 0.1, 0.1))
	var lit := Image.create(27, 22, false, Image.FORMAT_RGBA8)
	lit.fill(Color(1, 0.2, 0.2))
	var paths: Array[String] = ["%s/%s.loyalty.png" % [dir, us.Id], "%s/%s.loyalty.lit.png" % [dir, us.Id]]
	dim.save_png(paths[0])
	lit.save_png(paths[1])
	Art.Reset()
	for m in EventBus.MessageLog:
		m.IsRead = true   # the opening mail must not light the icon
	ui.RefreshCommsHighlights()
	_check(loyalty.icon != null and loyalty.text.is_empty() and loyalty.tooltip_text == "Loyalty", "with icons imported the Loyalty button shows the icon and keeps its name as the tooltip")
	var dim_tex: Texture2D = loyalty.icon
	var px: Color = dim_tex.get_image().get_pixel(5, 5)
	_check(absf(px.r - 0.3) < 0.01 and absf(px.g - 0.1) < 0.01, "no unread mail: the dim icon")
	EventBus.Tell(us, GameMessage.new("Test", "Loyalty news.", Enums.MessageCategory.Loyalty, StrategicTickManager.Today, null, null))
	ui.RefreshCommsHighlights()
	_check(loyalty.icon != dim_tex and loyalty.icon.get_image().get_pixel(5, 5).is_equal_approx(Color(1, 0.2, 0.2)), "unread Loyalty mail: the lit icon")
	var fleets: Button = list.get_node("Fleets")
	_check(fleets.icon == null and fleets.text == "Fleets", "a category with no imported icon stays a text button")

	for p in paths:
		DirAccess.remove_absolute(p)
	Art.Reset()
	ui.RefreshCommsHighlights()
	_check(loyalty.icon == null and loyalty.text == "Loyalty", "with the files removed the button is text again")

	print("[original_alerts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
