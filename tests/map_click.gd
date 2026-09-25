extends SceneTree
## Theatres are reachable through their regions: every region on the galaxy
## map carries an invisible button centred on its dot, above every theatre
## box, and pressing it opens that region's theatre (the sector window). The
## theatre box padding is small enough that crowded theatres mostly separate.
##
##   .\tools\run-gd.ps1 tests/map_click.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/map_click.gd              (Star Wars)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[map_click] ok   %s" % what)
	else:
		_fails += 1
		print("[map_click] FAIL %s" % what)


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

	var map: GalaxyMap = main.get_node("GalaxyMap")
	var ui: UIManager = main.get_node("UIManager")
	var planets := 0
	for sector in GameState.ActiveGalaxy:
		planets += sector.Planets.size()
	var hits := map.RegionButtons()
	_check(hits.size() == planets, "one hit button per region (%d of %d)" % [hits.size(), planets])

	# Centred on the dot, and above every theatre box in the tree.
	var last_theatre := -1
	var first_hit := 1 << 30
	for c in map.get_children():
		if c is Button and (c as Button).text.begins_with("") and hits.values().has(c):
			first_hit = mini(first_hit, c.get_index())
		elif c is Button:
			last_theatre = maxi(last_theatre, c.get_index())
	_check(first_hit > last_theatre, "every region button comes after every theatre box (input goes to the region first)")
	var sector0: Sector = GameState.ActiveGalaxy[0]
	var p0: Planet = sector0.Planets[0]
	var hit0: Button = hits[p0]
	_check((hit0.position + hit0.size / 2.0).is_equal_approx(map.MapPos(p0.MapX, p0.MapY)), "%s's button is centred on its dot" % p0.Name)
	_check(hit0.tooltip_text.contains(p0.Name) and hit0.tooltip_text.contains(sector0.Name), "its tooltip names the region and its theatre")

	# Pressing it opens the theatre: a window titled with the sector's name.
	hit0.pressed.emit()
	for _i in 3:
		await process_frame
	var opened := false
	for w in ui.find_children("*", "", true, false):
		if w is Label and (w as Label).text == sector0.Name and w.name == "Title":
			opened = true
	_check(opened, "pressing it opened the '%s' theatre window" % sector0.Name)

	# Theatre names are drawn only while hovered: the plain look's text AND
	# outline on the box, or the original's own label (with its art).
	var theatre_btn: Button = map.SectorButton(sector0)
	var title: Label = map.SectorTitle(sector0)
	_check(theatre_btn != null and not map.IsTitleShown(sector0), "a theatre's name is hidden when not hovered")
	if title == null:
		_check(theatre_btn.get_theme_color("font_color").a == 0.0, "(plain look) no outline, transparent text")
	theatre_btn.mouse_entered.emit()
	_check(map.IsTitleShown(sector0), "hovering shows it")
	if title == null:
		_check(theatre_btn.get_theme_color("font_color").a == 1.0, "(plain look) dark with an outline")
	else:
		# The original's (TeeJ's Calaron): yellow, Arial 14 at the picture's
		# scale, two lines - the name, then "Sector" - top-left at the sector's
		# point on the picture, 7 px up-left of where a star there is centred.
		var fit: float = map.Backdrop().scale.x if map.Backdrop() != null else 1.0
		var at: Vector2 = map.MapPos(sector0.MapX, sector0.MapY) - Vector2(7, 7) * fit
		_check(title.text == "%s\n%s" % [sector0.Name, Terms.label("sector")] and title.get_theme_color("font_color") == Color(240 / 255.0, 240 / 255.0, 0)
			and title.get_theme_font_size("font_size") == roundi(14.0 * fit) and title.get_theme_constant("outline_size") == 0
			and title.position.is_equal_approx(at),
			"(original look) '%s', yellow, %d px, no outline, at the sector's point" % [title.text.replace("\n", " / "), title.get_theme_font_size("font_size")])
	# Off the box onto one of its own regions: the name stays up (it blinked
	# on every star - TeeJ, 2026-09-25: "more flickery than the original").
	var hitIn: Button = hits[sector0.Planets[0]]
	theatre_btn.mouse_exited.emit()
	hitIn.mouse_entered.emit()
	await process_frame
	_check(map.IsTitleShown(sector0), "moving onto one of its regions keeps it up")
	hitIn.mouse_exited.emit()
	await process_frame
	_check(not map.IsTitleShown(sector0), "leaving hides it again")

	# The padding: theatre boxes are their regions plus SectorPadding a side.
	var eu_overlaps := 0
	var eu_pairs := 0
	var boxes: Dictionary = {}
	for c in map.get_children():
		if c is Button and not hits.values().has(c) and not (c as Button).text.is_empty():
			boxes[(c as Button).text] = Rect2((c as Control).position, (c as Control).size)
	var names := boxes.keys()
	for i in names.size():
		for j in i:
			eu_pairs += 1
			if boxes[names[i]].intersects(boxes[names[j]]):
				eu_overlaps += 1
	print("[map_click] theatre boxes overlapping: %d of %d pairs (padding %d)" % [eu_overlaps, eu_pairs, int(GalaxyMap.SectorPadding)])

	print("[map_click] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
