extends SceneTree
## THE MAP SCREEN'S SHELL IN A PACK'S LOOK (src/ui/look_hud.gd; docs/ww2-look-plan.md
## phase 3). One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_hud.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_hud.gd -- --pack=star-wars-rebellion --seed=12345
##
## With a look: the desk under the screen, the operations strip, the dispatch
## rail (unread mail a brass count - no yellow glow), the theatre directory (an
## open theatre reads as selected), the console (the mode on show held down),
## the paused clock in the signal colour, and the map's markers with an ink rim.
## Without one (Star Wars, no art set): none of it - the shell as it was.

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_hud] ok   %s" % what)
	else:
		_fails += 1
		print("[look_hud] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-hud-none"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var map: GalaxyMap = main.get_node("GalaxyMap")
	var id := FactionRegistry.LoadedId()
	# A map screen whose script failed to load would pass the checks below
	# vacuously: the game must really be up first.
	_check(not GameState.ActiveGalaxy.is_empty() and main.get_script() != null and main.has_method("SetSpeed"),
		"%s: the game started (%d theatres)" % [id, GameState.ActiveGalaxy.size()])

	if not Look.Active():
		_check(main.get_node_or_null("LookDesk") == null and ui.get_node_or_null("OpsStrip") == null
			and ui.get_node_or_null("ConsoleBacking") == null, "%s: no look - no desk, strip or console backing" % id)
		_check(String((ui.get_node("CommsPanel") as Control).theme_type_variation).is_empty()
			and (ui.get_node("CommsPanel") as Control).theme == null, "%s: the rail is as it was drawn" % id)
		_done()
		return

	_check(main.get_node_or_null("LookDesk") is CanvasLayer, "%s: the desk lies under the screen" % id)
	_check(ui.get_node_or_null("OpsStrip") != null, "the operations strip is behind the readouts")
	var clock: PanelContainer = ui.get_node("TimeControls")
	_check(clock.theme == Look.GetTheme(), "the day-and-speed chip wears the look")

	# The dispatch rail, and unread mail as a count.
	for btn in ui.get_node("CommsPanel/Margin/CommsList").get_children():
		_check((btn as Button).theme_type_variation == Look.RAIL, "rail drawer %s" % btn.name)
	var us: Faction = GameSettings.PlayerFaction
	EventBus.Tell(us, GameMessage.new("Fleet awaiting orders", "Test.", Enums.MessageCategory.Fleets, StrategicTickManager.Today))
	await process_frame
	ui.RefreshCommsHighlights()
	var fleets: Button = ui.get_node("CommsPanel/Margin/CommsList/Fleets")
	var count: Label = fleets.get_node_or_null("LookUnread")
	_check(count != null and count.visible and count.text.to_int() >= 1, "unread Fleets mail shows as a count (%s)" % (count.text if count else "none"))
	_check(not fleets.has_theme_color_override("font_color") and fleets.modulate == Color.WHITE, "and no yellow glow")

	# The theatre directory: an open theatre reads as selected.
	var pins: Dictionary = ui.PinnedSectors()
	_check(not pins.is_empty(), "the theatres are pinned")
	var first: Sector = GameState.ActiveGalaxy[0]
	var pin: Button = pins.get(first.Name)
	_check(pin != null and pin.theme_type_variation == Look.ROW, "a pin is a directory row")
	ui.PollOpenWindows()
	_check(pin != null and not pin.has_theme_stylebox_override("normal"), "closed, it is not marked")
	ui.OnSectorClicked(first)
	for _i in 3:
		await process_frame
	ui.PollOpenWindows()
	_check(pin != null and pin.has_theme_stylebox_override("normal"), "open, %s reads as selected" % first.Name)
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame
	ui.PollOpenWindows()
	_check(pin != null and not pin.has_theme_stylebox_override("normal"), "closed again, unmarked")

	# The console: the command row's keys, the mode on show held down.
	_check(ui.get_node_or_null("ConsoleBacking") != null, "the console has its backing")
	for b in ui.get_node("HBoxContainer").get_children():
		if b is Button:
			_check((b as Button).theme_type_variation == Look.COMMAND, "console key %s" % (b as Button).text)
	map.SetMode(Gid.DisplayOff)
	var off: Button = null
	for b in map.Bar()._row.get_children():
		if b.has_meta("display_off"):
			off = b
	_check(off != null and off.has_theme_stylebox_override("normal"), "Display Off on show: its key is held down")

	# The clock chip: signal while paused.
	var gm: Node = main
	gm.SetSpeed(0)
	await process_frame
	var sb: StyleBox = clock.get_theme_stylebox("panel")
	_check(sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color == Look.C("signal"), "paused: the chip shows the signal colour")
	gm.SetSpeed(1)
	await process_frame
	sb = clock.get_theme_stylebox("panel")
	_check(sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color == Look.C("chassis_deep"), "running again: back to steel")

	# The markers: an ink rim.
	var rimmed := 0
	for c in map.get_children():
		if c is Label and (c as Label).visible and (c as Label).get_theme_constant("outline_size") > 0:
			rimmed += 1
	_check(rimmed > 0, "the map's markers carry an ink rim (%d)" % rimmed)
	_done()


func _done() -> void:
	print("[look_hud] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
