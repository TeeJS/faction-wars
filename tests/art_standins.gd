extends SceneTree
## OUR STAND-INS FOR THE ORIGINAL'S PICTURES (art_standins.gd; the plain build
## parity plan, phases 2-8). With no art set:
##   - they are on, and every picture in the table is drawn at its listed size,
##     in each state its file name can ask for;
##   - a window in the original's look builds from them - the Message Index
##     (phase 2): its tabs, band, list, side buttons and reading view; the
##     sector window (3), the Status plate (4), the Game Options screen (7);
## and they are off with an art set present, and for a pack with a look of its
## own.
##
##   .\tools\run-gd.ps1 tests/art_standins.gd

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const Root := "user://test-standins-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[art_standins] ok   %s" % what)
	else:
		_fails += 1
		print("[art_standins] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = Root
	_remove(Root)
	Art.Reset()
	FactionRegistry.EnsureLoaded()
	_check(StandIns.Active(), "no art set: the stand-ins are on")

	# Every picture in the table, at its size, in every state.
	var sized := true
	var bad: Array = []
	for rel in StandIns.Table():
		var spec: Dictionary = StandIns.Table()[rel]
		for state in ["", "pressed", "disabled"]:
			var path: String = rel if state.is_empty() else rel.trim_suffix(".png") + "." + state + ".png"
			var tex: Texture2D = StandIns.Picture(path)
			if tex == null or Vector2i(tex.get_size()) != (spec["size"] as Vector2i):
				sized = false
				bad.append(path)
	_check(sized, "every stand-in drawn at its listed size, plain, pressed and disabled (%d pictures%s)" % [StandIns.Table().size(), (": " + str(bad.slice(0, 4))) if not bad.is_empty() else ""])
	var plain: Texture2D = Art.ButtonIcon("msgindex_delete")
	var down: Texture2D = Art.ButtonIcon("msgindex_delete", "pressed")
	_check(plain != null and down != null and plain.get_image().get_data() != down.get_image().get_data(), "the art loader hands them out; pressed is drawn differently")
	var frame: Texture2D = Art.WindowPicture("frame.alliance")
	var img: Image = frame.get_image() if frame != null else null
	_check(img != null and img.get_pixel(200, 150).a == 0.0 and img.get_pixel(5, 5).a == 1.0, "a window frame is see-through where the window shows through it")

	# The Message Index in the original's look, from the stand-ins.
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	EventBus.BroadcastMessage(GameMessage.new("A stand-in test", "Read me.", Enums.MessageCategory.Conflict))
	ui.OnMessageIndexClicked("All")
	await process_frame
	var mw: MessageWindow = ui._openWindows.get("Communications")
	_check(mw != null and mw._original, "the Message Index builds in the original's look")
	if mw != null and mw._original:
		_check(mw._oTabs.size() == 10 and mw.size.is_equal_approx(mw.OriginalSize()) and mw.position.is_equal_approx(UIManager.MapFrame.position),
			"its ten tabs, at its own size, at the map window's corner")
		_check(mw._oCaption.text == "All Messages" and mw._oRows.get_child_count() > 0, "the band names the tab; the list has its rows")
		(mw._oTabs[7] as BaseButton).pressed.emit()
		await process_frame
		_check(mw._oCaption.text == "Conflict Messages", "a tab opens its category")
		var m: GameMessage = MessageWindow.MessagesFor("Conflict")[0]
		mw._o_show_summary(m)
		await process_frame
		_check(mw._oSummary.visible and mw._oSumTitle.text == m.Title, "a message reads in the same frame")
		_check(mw.StepBack() and mw._oIndex.visible, "and steps back to the index")
	# The sector window in the original's look (phase 3): its boxes, and every
	# system's picture, from the stand-ins.
	_check(SectorWindow.CanBuildOriginal() and Art.PlanetSprite(26) != null and Art.GidStar("neutral", "big") != null,
		"the sector window's pictures are there: its boxes, 26 planet pictures, the stars")
	var sector: Sector = GameState.ActiveGalaxy[0]
	ui.OnSectorClicked(sector)
	await process_frame
	var sw: Control = ui._openWindows.get(sector.Name)
	_check(sw != null and SectorWindow.OriginalLook and sw.position.is_equal_approx(SectorWindow.DockPosition(true)),
		"the sector window opens in the original's look, docked at the map window's edge")
	# The Status window in the original's look (phase 4): a character's, a fleet's.
	_check(OUI.HasStatus() and OUI.Has(["status_fleet.alliance", "status_fleet.empire"]), "the Status window's plate and pictures are there")
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == GameSettings.PlayerFaction)
	if who != null:
		ui.OpenCharacterStatusWindow(who)
		await process_frame
		var plate: Node = ui._openWindows.get("Status_%s" % who.Name.replace(" ", ""))
		_check(plate != null and plate.get_script() == preload("res://src/ui/status_plate_window.gd"), "a character's Status opens as the original's plate")
	# The Game Options screen and the alert boxes (phase 7).
	_check(preload("res://src/ui/original_options_screen.gd").CanBuild() and OUI.Pic("dialog_plate1") != null and OUI.Pic("dialog_plate2") != null
		and Art.WindowPicture("options_music.off") != null and Art.WindowPicture("options_light.off") != null,
		"the Game Options screen's pictures are there, and the alert boxes'")
	ui.OnMenuButtonClicked()
	for _i in 3:
		await process_frame
	var options: Node = ui.get_node_or_null("OptionsScreen")
	_check(options != null, "the Game Options screen opens in the original's look")
	if options != null:
		options.queue_free()   # closed while the game is up, which restarts its clock
		await process_frame
	root.remove_child(main)
	main.free()

	# With an art set present, off; and for a pack with a look of its own.
	DirAccess.make_dir_recursive_absolute(Root + "/swr-original/windows")
	var f := FileAccess.open(Root + "/swr-original/windows/placeholder.txt", FileAccess.WRITE)
	f.store_string("x")
	f.close()
	Art.Reset()
	_check(not StandIns.Active(), "an art set present: off (its own gaps stay gaps)")
	_remove(Root)
	Art.Reset()
	print("[art_standins] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
