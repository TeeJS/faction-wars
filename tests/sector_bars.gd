extends SceneTree
## The three bars under every explored system in the Sector window (manual p025
## Fig 2.9, p084 Fig 3.26, p049): energy squares (white used / blue free),
## materials squares (yellow built mine / red free site), a loyalty bar in the
## sides' colours; none on an unexplored system; no loyalty bar on an
## unpopulated one; figures are what this side KNOWS (a sighting, not live).
##
##   .\tools\run-gd.ps1 tests/sector_bars.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/sector_bars.gd              (Star Wars)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[sector_bars] ok   %s" % what)
	else:
		_fails += 1
		print("[sector_bars] FAIL %s" % what)


func _init() -> void:
	await process_frame
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

	# --- A world we hold: live figures, all three rows. ---
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and p.IsInhabited and p.BaseEnergy > 0 and p.BaseRawMaterials > 0)
	_check(home != null, "%s holds an inhabited world with energy and raw material (%s)" % [us.Id, home.Name if home != null else "-"])
	if home == null:
		quit(1)
		return
	var rows: Dictionary = await _rows_for(ui, home)
	_check(rows.has("energy"), "an energy row is drawn under %s" % home.Name)
	_check(rows.has("materials"), "a materials row is drawn under %s" % home.Name)
	_check(rows.has("loyalty"), "a loyalty bar is drawn under %s" % home.Name)
	if rows.has("energy"):
		var r: Control = rows["energy"]
		_check(r.get_child_count() == home.BaseEnergy, "energy: one square per slot (%d of %d)" % [r.get_child_count(), home.BaseEnergy])
		_check(_count(r, SectorWindow.EnergyUsedColor()) == home.UsedEnergySlots(), "energy: white squares = used slots (%d of %d)" % [_count(r, SectorWindow.EnergyUsedColor()), home.UsedEnergySlots()])
		_check(_count(r, SectorWindow.EnergyFreeColor()) == home.FreeEnergySlots(), "energy: blue squares = free slots (%d of %d)" % [_count(r, SectorWindow.EnergyFreeColor()), home.FreeEnergySlots()])
		_check(r.tooltip_text == "%s %d/%d" % [Terms.label("energy"), home.UsedEnergySlots(), home.BaseEnergy], "energy hover reads '%s'" % r.tooltip_text)
	if rows.has("materials"):
		var r: Control = rows["materials"]
		_check(r.get_child_count() == home.BaseRawMaterials, "materials: one square per site (%d of %d)" % [r.get_child_count(), home.BaseRawMaterials])
		_check(_count(r, SectorWindow.MineBuiltColor()) == home.Mines(), "materials: yellow squares = built mines (%d of %d)" % [_count(r, SectorWindow.MineBuiltColor()), home.Mines()])
		_check(_count(r, SectorWindow.MineFreeColor()) == home.FreeMineSlots(), "materials: red squares = free sites (%d of %d)" % [_count(r, SectorWindow.MineFreeColor()), home.FreeMineSlots()])
		_check(r.tooltip_text == "%s %d/%d" % [Terms.label("raw_materials"), home.Mines(), home.BaseRawMaterials], "materials hover reads '%s' (Fig 2.12: 'Raw Materials 3/9')" % r.tooltip_text)
	if rows.has("loyalty"):
		var bar: Control = rows["loyalty"]
		var ok := true
		var total_w := 0.0
		for seg in bar.get_children():
			total_w += (seg as Control).size.x
		for side in FactionRegistry.Playable:
			var pct: int = home.SupportFor(side)
			var seg: Control = Lq.first_or_null(bar.get_children(), func(c) -> bool: return SectorWindow.BlockColor(c) == SectorWindow.LoyaltyColor(side))
			if pct > 0 and (seg == null or absf(seg.size.x - bar.size.x * pct / 100.0) > 0.51):
				ok = false
		_check(ok, "loyalty: each side's segment is its share of the bar, in its colour (%s)" % bar.tooltip_text)
		_check(absf(total_w - bar.size.x) < 0.51, "loyalty: the segments fill the bar")
		# Left to right in the pack's declared order (Fig 2.9: the Empire on the left).
		var order: Array[Faction] = FactionRegistry.LoyaltyBarOrder()
		var seen_x: float = -1.0
		var in_order := true
		for side in order:
			var seg: Control = Lq.first_or_null(bar.get_children(), func(c) -> bool: return SectorWindow.BlockColor(c) == SectorWindow.LoyaltyColor(side))
			if seg == null:
				continue
			if seg.position.x <= seen_x:
				in_order = false
			seen_x = seg.position.x
		_check(in_order, "loyalty: the sides run left to right as display.json loyalty_bar says (%s)" % ", ".join(Lq.select(order, func(f: Faction) -> String: return f.Id)))
		if Lq.any(FactionRegistry.Playable, func(f: Faction) -> bool: return f.Id == "empire"):
			_check(order[0].Id == "empire", "Star Wars: the Empire is on the left (Fig 2.9)")
		var first: Control = bar.get_child(0)
		_check((first.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left == SectorWindow.BarRadius(),
			"the bar's corners are rounded (square in the original's window)")
	if rows.size() == 3:
		# The original's loyalty bar starts a pixel left of its squares, under
		# the picture's edge; ours share one edge.
		var loyalty_x: float = rows["energy"].position.x - (SectorWindow.K if SectorWindow.OriginalLook else 0)
		_check(rows["energy"].position.x == rows["materials"].position.x and rows["loyalty"].position.x == loyalty_x,
			"the square rows share one left edge, so the squares line up (x=%.0f), the loyalty bar at x=%.0f" % [rows["energy"].position.x, loyalty_x])
	var name_lbl: Label = _name_label(ui, home)
	# The original's name line starts over the loyalty bar's last rows (the
	# letters are under it: the line's top is space); ours clears the bars.
	var name_top: float = 0.0
	if name_lbl != null:
		name_top = name_lbl.position.y + (name_lbl.size.y / 2.0 if SectorWindow.OriginalLook else 0.0)
	_check(name_lbl != null and rows.has("loyalty") and name_top >= rows["loyalty"].position.y + rows["loyalty"].size.y,
		"the name sits below the bars")

	# --- An unexplored world: no bars at all. ---
	var dark: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return not p.ExploredBy(us))
	_check(dark != null, "there is an unexplored world (%s)" % (dark.Name if dark != null else "-"))
	if dark != null:
		_check((await _rows_for(ui, dark)).is_empty(), "no bars under an unexplored world")

	# --- A sighting, not live: an unpopulated world we do not hold, reconnoitred. ---
	var empty: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return not p.IsInhabited and p.ControllingFaction != us and p.BaseEnergy > 0)
	_check(empty != null, "there is an unpopulated world we do not hold (%s)" % (empty.Name if empty != null else "-"))
	if empty != null:
		IntelManager.Capture(us, empty, StrategicTickManager.Today, IntelManager.ReconnaissanceCategories)
		var rows2: Dictionary = await _rows_for(ui, empty)
		_check(rows2.has("energy") and rows2.has("materials"), "a reconnoitred world shows its resource rows")
		_check(not rows2.has("loyalty"), "an unpopulated world has no loyalty bar (p049)")
		if rows2.has("energy"):
			_check(rows2["energy"].get_child_count() == empty.BaseEnergy, "the sighting carries the energy figure (%d)" % empty.BaseEnergy)

	print("[sector_bars] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Opens the planet's sector window and returns its bar rows by kind, or {}.
func _rows_for(ui: UIManager, planet: Planet) -> Dictionary:
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var w: DraggableWindow = _window_titled(ui, sector.Name)
	var map: Control = w.get_node("%SectorMap")
	var out := {}
	# The rows of THIS planet: every part of a system's entry names it.
	for c in map.get_children():
		if c is Control and not c.is_queued_for_deletion() and c.has_meta("bar_row") and c.get_meta("system", null) == planet:
			out[c.get_meta("bar_row")] = c
	return out


func _name_label(ui: UIManager, planet: Planet) -> Label:
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
	var w: DraggableWindow = _window_titled(ui, sector.Name)
	for c in w.get_node("%SectorMap").get_children():
		if c is Label and c.text == planet.Name:
			return c
	return null


static func _count(row: Control, color: Color) -> int:
	var n := 0
	for c in row.get_children():
		if SectorWindow.BlockColor(c) == color:
			n += 1
	return n


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
