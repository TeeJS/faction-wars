extends SceneTree
## The left column as the original's Message Index strip (manual p079 Fig
## 3.19), from the player's own import: each category button shows its 36x41
## socket at 1.5x, the "current" socket on the category on show, the unread
## count as a yellow badge, and text again when nothing is imported. Writes
## and removes its own test files under user://.
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


## Colours read back from a saved PNG are 8-bit: 0.1 comes back as 25/255.
static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


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

	var dir := "user://original/%s/tabs" % pack_id
	DirAccess.make_dir_recursive_absolute(dir)
	var paths: Array[String] = []
	for spec in [["msg_all", Color(0.2, 0.2, 0.5)], ["msg_all.pressed", Color(0.1, 0.1, 0.9)],
			["msg_loyalty.%s" % us.Id, Color(0.6, 0.1, 0.1)], ["msg_loyalty.%s.pressed" % us.Id, Color(0.1, 0.2, 0.8)]]:
		var img := Image.create(36, 41, false, Image.FORMAT_RGBA8)
		img.fill(spec[1])
		var path := "%s/%s.png" % [dir, spec[0]]
		img.save_png(path)
		paths.append(path)
	Art.Reset()
	for m in EventBus.MessageLog:
		m.IsRead = true   # the opening mail must not show a count
	ui.RefreshCommsHighlights()
	_check(loyalty.icon != null and loyalty.text.is_empty() and loyalty.tooltip_text == "Loyalty", "with sockets imported the Loyalty button shows its socket and keeps its name as the tooltip")
	_check(loyalty.icon.get_width() == 54 and loyalty.icon.get_height() == 54, "the socket (its top 36 rows) is drawn 1.5x (54x54)")
	var px: Color = loyalty.icon.get_image().get_pixel(10, 10)
	_check(_near(px, Color(0.6, 0.1, 0.1)), "not the category on show: the normal socket")
	var badge: Label = loyalty.get_node_or_null("Badge")
	_check(badge == null or not badge.visible, "no unread mail: no badge")
	EventBus.Tell(us, GameMessage.new("Test", "Loyalty news.", Enums.MessageCategory.Loyalty, StrategicTickManager.Today, null, null))
	ui.RefreshCommsHighlights()
	badge = loyalty.get_node_or_null("Badge")
	_check(badge != null and badge.visible and badge.text == "1", "unread Loyalty mail: the count on the socket")
	var all: Button = list.get_node("All")
	_check(all != null and all.icon != null and all.text.is_empty(), "All Messages is the galaxy socket")
	ui.OnMessageIndexClicked("Loyalty")
	for _i in 3:
		await process_frame
	ui.RefreshCommsHighlights()
	_check(_near(loyalty.icon.get_image().get_pixel(10, 10), Color(0.1, 0.2, 0.8)), "the category on show: the current (blue) socket")
	var fleets: Button = list.get_node("Fleets")
	_check(fleets.icon == null and fleets.text == "Fleets", "a category with no imported socket stays a text button")

	for p in paths:
		DirAccess.remove_absolute(p)
	Art.Reset()
	UIManager._sockets.clear()
	ui.RefreshCommsHighlights()
	_check(loyalty.icon == null and loyalty.text == "Loyalty", "with the files removed the button is text again")

	print("[original_alerts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
