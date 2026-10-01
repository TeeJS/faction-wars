extends SceneTree
## THE OBJECTIVES ON THE MAP (src/ui/look_objectives_legend.gd): with a look
## that names its map's legend, a sheet lies exactly over it in the legend's
## colours, a column per side with the Objectives window's conditions, each
## with an open box; a condition met is ticked within a poll. Without one
## (Star Wars), no sheet. One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_objectives_legend.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_objectives_legend.gd -- --pack=star-wars-rebellion --seed=12345

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_objectives_legend] ok   %s" % what)
	else:
		_fails += 1
		print("[look_objectives_legend] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-objectives-legend-none"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var map: GalaxyMap = main.get_node("GalaxyMap")
	var sheet: Control = map.get_node_or_null("ObjectivesLegend")
	var def: Dictionary = Look.ObjectivesLegend() if Look.Active() else {}
	var id := FactionRegistry.LoadedId()

	if def.is_empty():
		_check(sheet == null, "%s: no legend named, no sheet on the map" % id)
		_done()
		return

	_check(sheet != null, "%s: the sheet is on the map" % id)
	if sheet == null:
		_done()
		return
	var fit: float = map._fit
	var r: Rect2 = def["rect"]
	_check(sheet.position.is_equal_approx(r.position * fit) and sheet.size.is_equal_approx(r.size * fit),
		"it lies exactly over the picture's legend (%s at fit %.3f)" % [str(r), fit])
	_check(sheet.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it takes no clicks from the map")

	var cols: HBoxContainer = sheet.get_node("Body/Sides")
	_check(cols.get_child_count() == FactionRegistry.Playable.size(), "a column per side")
	for f in FactionRegistry.Playable:
		var col: VBoxContainer = cols.get_node(NodePath(f.Id))
		var want: Array = VictoryManager.StatusFor(f, GameState.ActiveGalaxy)
		var head: Label = col.get_child(0)
		_check(head.text == f.DisplayName.to_upper(), "%s: its heading" % f.Id)
		_check(col.get_child_count() == want.size() + 1, "%s: every condition (%d)" % [f.Id, want.size()])
		for i in want.size():
			var row: HBoxContainer = col.get_child(i + 1)
			_check((row.get_child(1) as Label).text == want[i][0] and row.get_child(0).name == ("Met" if want[i][1] else "Open"),
				"%s: \"%s\", %s" % [f.Id, want[i][0], "ticked" if want[i][1] else "open"])
		_check((head.get_theme_color("font_color")) == def["ink"], "%s: in the legend's ink" % f.Id)

	# Meet a condition: the first side takes the other's capital.
	var us: Faction = FactionRegistry.Playable[0]
	var them: Faction = FactionRegistry.Playable[1]
	var capital: Planet = null
	if them.Hq != null and not them.HasHiddenHq():
		for s in GameState.ActiveGalaxy:
			for p in s.Planets:
				if p.PackId == them.Hq.Planet:
					capital = p
	_check(capital != null, "the other side's capital is on the map")
	if capital != null:
		var was: Faction = capital.ControllingFaction
		capital.ControllingFaction = us
		await create_timer(0.8).timeout   # past a poll
		cols = sheet.get_node("Body/Sides")   # repainted: new rows
		var row: HBoxContainer = cols.get_node(NodePath(us.Id)).get_child(1)
		_check(row.get_child(0).name == "Met" and (row.get_child(1) as Label).text == VictoryManager.StatusFor(us, GameState.ActiveGalaxy)[0][0],
			"taking it ticks the condition (%s)" % (row.get_child(1) as Label).text)
		capital.ControllingFaction = was
	_done()


func _done() -> void:
	print("[look_objectives_legend] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
