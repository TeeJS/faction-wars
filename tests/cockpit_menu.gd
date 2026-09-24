extends SceneTree
## The Shuttle Cockpit as the pack's picture (manual p021, Fig. 2.2): every
## function the figure labels is a region the pack declares, laid over the
## picture, and pressing one does what the labelled button did.
##
##   Godot_console.exe --headless --path . -s tests/cockpit_menu.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	var pack := FactionRegistry.Pack
	if pack.Manifest.Menu == null:
		print("[cockpit_menu] the active pack declares no menu picture - nothing to test")
		quit(0)
		return
	var menu_def := pack.Manifest.Menu

	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	# A headless window is tiny; lay the Cockpit out at a real screen size so
	# the fit checks below mean something.
	menu.size = Vector2(1440, 1080)
	await process_frame
	await process_frame

	var picture: TextureRect = menu.get_node_or_null("Cockpit")
	_check(picture != null and picture.texture != null, "the Cockpit picture is on screen")
	_check(not (menu.get_node("CenterContainer") as Control).visible, "the labelled-button form is put away")

	var regions: Control = menu.get_node_or_null("Regions")
	_check(regions != null, "the region layer exists")

	# Fig. 2.2: one region per labelled function.
	var sizes: Array[String] = pack.Manifest.Setup.GalaxySizes
	var want: Array[String] = ["load_game", "credits", "hq_only_victory", "multiplayer", "exit"]
	for d in ["easy", "medium", "hard"]:
		want.append("difficulty_%s" % d)
	for s in sizes:
		want.append("galaxy_size_%s" % s)
	for f in FactionRegistry.Playable:
		want.append("start_%s" % f.Id)
	for key in want:
		var b: Button = regions.get_node_or_null("Region_" + key) if regions != null else null
		_check(b != null, "Fig. 2.2: a region for %s" % key)
		if b != null:
			_check(b.size.x > 0 and b.size.y > 0, "the %s region has a size on screen" % key)
			_check(b.text.is_empty(), "the %s region draws no label over the picture" % key)

	# Regions sit inside the picture's frame, scaled with it.
	if picture != null and regions != null:
		var frame: Rect2 = menu.call("_picture_frame")
		for b in regions.get_children():
			if b is Button:
				var r := Rect2(b.position, b.size)
				_check(frame.encloses(r), "%s lies inside the picture (%s in %s)" % [b.name, r, frame])

	# Defaults come from the pack.
	var sel: Dictionary = menu.call("SelectedSettings")
	var want_diff: String = pack.Manifest.Setup.DifficultyDefault
	var want_size: String = pack.Manifest.Setup.GalaxySizeDefault if not pack.Manifest.Setup.GalaxySizeDefault.is_empty() else sizes[0]
	_check(sel["difficulty"] == want_diff, "difficulty starts at the pack default (%s, got %s)" % [want_diff, sel["difficulty"]])
	_check(sel["size"] == want_size, "galaxy size starts at the pack default (%s, got %s)" % [want_size, sel["size"]])
	_check(sel["hq_only"] == false, "Headquarters Only Victory starts off")

	# Pressing a region changes the choice.
	(regions.get_node("Region_difficulty_hard") as Button).pressed.emit()
	(regions.get_node("Region_galaxy_size_%s" % sizes[sizes.size() - 1]) as Button).pressed.emit()
	sel = menu.call("SelectedSettings")
	_check(sel["difficulty"] == "hard", "pressing the hard screen sets difficulty hard")
	_check(sel["size"] == sizes[sizes.size() - 1], "pressing the last galaxy screen sets that size")

	# A region's own bracket colour rides on the button for the marks pass.
	var easy_btn: Button = regions.get_node("Region_difficulty_easy")
	var easy_def: PackDefs.MenuRegionDef = null
	for r in menu_def.Regions:
		if r.Action == "difficulty" and r.Value == "easy":
			easy_def = r
	_check(easy_def != null and str(easy_btn.get_meta("color", "")) == easy_def.SelectedColorHex, "the easy region carries its selected_color (%s)" % str(easy_btn.get_meta("color", "")))

	# The readout follows the victory toggle.
	var readout: Label = regions.get_node_or_null("Readout")
	_check(readout != null and readout.text == menu_def.Readout.Standard, "the readout starts at '%s'" % menu_def.Readout.Standard)
	(regions.get_node("Region_hq_only_victory") as Button).pressed.emit()
	sel = menu.call("SelectedSettings")
	_check(sel["hq_only"] == true, "pressing the victory screen turns Headquarters Only on")
	if readout != null:
		var fs: int = readout.get_theme_font_size("font_size")
		var w: float = readout.get_theme_font("font").get_string_size(readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_check(w <= readout.size.x, "'%s' fits the readout panel (%.0f of %.0f px at %d)" % [readout.text, w, readout.size.x, fs])
	_check(readout != null and readout.text == menu_def.Readout.HqOnly, "the readout says '%s'" % menu_def.Readout.HqOnly)
	(regions.get_node("Region_hq_only_victory") as Button).pressed.emit()
	sel = menu.call("SelectedSettings")
	_check(sel["hq_only"] == false and readout.text == menu_def.Readout.Standard, "pressing it again turns it off")

	# The monitors' pictures (Fig. 2.2: "the rotating red Alliance icon"): one
	# per declared monitor the art set holds, inside the picture, playing.
	var monitors: Control = menu.get_node_or_null("Monitors")
	var shown: Array = monitors.get_children() if monitors != null else []
	var have: int = Lq.count(menu_def.Monitors, func(m: PackDefs.MenuMonitorDef) -> bool:
		return Art.PackImage(m.ImageFile) != null)
	_check(monitors != null and shown.size() == have, "a picture on every monitor the art set has (%d of %d)" % [shown.size(), menu_def.Monitors.size()])
	if picture != null:
		var frame: Rect2 = menu.call("_picture_frame")
		for pic in shown:
			_check(frame.encloses(Rect2(pic.position, pic.size).grow(-0.5)), "%s lies inside the picture" % pic.name)
	var spinning: TextureRect = Lq.first_or_null(shown, func(p: TextureRect) -> bool:
		var d: PackDefs.MenuMonitorDef = p.get_meta("def")
		return d.Frames > 1 and d.Still < 0)
	var still: TextureRect = Lq.first_or_null(shown, func(p: TextureRect) -> bool: return (p.get_meta("def") as PackDefs.MenuMonitorDef).Still >= 0)
	if spinning != null:
		var before: Rect2 = (spinning.texture as AtlasTexture).region
		var held: Rect2 = (still.texture as AtlasTexture).region if still != null else Rect2()
		menu.set("_monitorFrame", int(menu.get("_monitorFrame")) + 1)
		menu.call("_paint_monitors")
		_check((spinning.texture as AtlasTexture).region != before, "%s moves on to its next frame" % spinning.name)
		if still != null:
			# The LucasArts logo does not move in the original (TeeJ, 2026-09-24).
			_check((still.texture as AtlasTexture).region == held, "%s holds its one frame" % still.name)
	var hq: TextureRect = Lq.first_or_null(shown, func(p: TextureRect) -> bool: return (p.get_meta("def") as PackDefs.MenuMonitorDef).Region == "hq_only_victory")
	if hq != null and hq.has_meta("selected"):
		var standard: Texture2D = (hq.texture as AtlasTexture).atlas
		(regions.get_node("Region_hq_only_victory") as Button).pressed.emit()
		_check((hq.texture as AtlasTexture).atlas == hq.get_meta("selected"), "Headquarters Only Victory shows its own picture on the victory screen")
		(regions.get_node("Region_hq_only_victory") as Button).pressed.emit()
		_check((hq.texture as AtlasTexture).atlas == standard, "and back to the standard game's picture")

	# Credits and Load open their windows.
	(regions.get_node("Region_credits") as Button).pressed.emit()
	await process_frame
	var cw: Node = menu.get_node_or_null("CreditsWindow")
	_check(cw != null, "pressing credits opens the Credits window")
	if cw != null:
		var lines_box: Node = cw.find_child("Lines", true, false)
		_check(lines_box != null and lines_box.get_child_count() == menu_def.Credits.size(), "the Credits window lists the pack's %d lines" % menu_def.Credits.size())
	(regions.get_node("Region_load_game") as Button).pressed.emit()
	await process_frame
	_check(menu.get_node_or_null("LoadGameWindow") != null or menu.get_node_or_null("OptionsScreen") != null,
		"pressing load opens the slot picker (the Game Options screen with the art imported)")

	# The ejector handle goes back to the pack picker, which the web build
	# reaches too (TeeJ, 2026-09-24): it is shown on every build.
	var exit_btn: Button = regions.get_node("Region_exit")
	_check(exit_btn.visible, "the ejector handle is shown on every build")

	print("[cockpit_menu] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)
