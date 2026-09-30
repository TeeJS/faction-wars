extends SceneTree
## THE SECTOR WINDOW AS A THEATRE PLATE (src/ui/look_sector.gd; docs/ww2-look-plan.md
## phase 8). One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_sector.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_sector.gd -- --pack=star-wars-rebellion --seed=12345
##
## The Huge galaxy, so every theatre a pack has is checked. With a look, in
## every sector's window: the plate (the theatre cut from the map picture, or
## from the look's inset where one holds the theatre; the wash; the frame) lies
## under every entry and takes no
## clicks; every system still has its mark and its name (manual p025); a mark
## is its holder's map colour ink-rimmed, or an ink ring - or, for a system
## with its own picture (the WWII flags), the picture with no disc behind it,
## the HQ edged in brass; a name is in the
## look's face with a paper halo and reads at 4.5:1 on parchment; a corner
## glyph is ink (an uprising's signal red) on a paper tab; every bar block is
## ink-edged, energy used ink, mines built olive, free ones open; none of the
## Star Wars window's own colours is left. WWII: every theatre is a map (TeeJ,
## 2026-09-29: "we need them all to be the same"), the five small European ones
## cut from the Europe inset. Without a look (Star Wars, the plain window):
## none of it.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const LookSector := preload("res://src/ui/look_sector.gd")
## The WWII theatres too small for the world map (5.1-8.8 times), which the
## Europe inset holds.
const EUROPE := ["British Isles", "Western Europe", "Central Europe", "Iberia", "Italian Peninsula"]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_sector] ok   %s" % what)
	else:
		_fails += 1
		print("[look_sector] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-sector-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Huge
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()
	_check(not GameState.ActiveGalaxy.is_empty(), "%s: the game started" % id)

	var sw_colours := [SectorWindow.CEnergyFree, SectorWindow.CMineBuilt, SectorWindow.CMineFree]
	var sectors := 0
	for sector in GameState.ActiveGalaxy:
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnSectorClicked(sector)
		for _i in 3:
			await process_frame
		var w: Node = ui._openWindows.get(sector.Name)
		if w == null or w.get("OriginalLook") == true:
			continue
		sectors += 1
		var map: Control = w.get_node("%SectorMap")
		var s: String = sector.Name
		if not Look.Active():
			_check(map.get_node_or_null("LookPlate") == null, "%s: %s - no plate" % [id, s])
			continue

		# The ground: the map where it stays sharp, else the plotting sheet;
		# under every entry, taking no clicks.
		var ground: String = str(map.get_meta("look_plate", ""))
		var zoom: float = float(map.get_meta("look_zoom", 0.0))
		var want_kind: String = "map" if zoom > 0.0 and zoom <= LookSector.SHARP_ZOOM else "sheet"
		_check(ground == want_kind, "%s: %s at zoom %.2f (sharp up to %.1f)" % [s, ground, zoom, LookSector.SHARP_ZOOM])
		var layers: Array = ["LookPaper", "LookPlate", "LookWash", "LookFrame"] if ground == "map" else ["LookPaper", "LookGrid", "LookFrame"]
		var ground_ok := true
		for i in layers.size():
			var layer: Control = map.get_node_or_null(layers[i])
			if layer == null or layer.get_index() != i or layer.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				ground_ok = false
		_check(ground_ok, "%s: %s, under every entry, taking no clicks" % [s, ", ".join(layers)])
		if id == "ww2":
			_check(ground == "map", "%s: a map, as every theatre (zoom %.2f)" % [s, zoom])
		var plate: TextureRect = map.get_node_or_null("LookPlate")
		var detail: Texture2D = Look.Tex("map_detail")
		if ground == "map" and detail != null and plate != null:
			var atlas: Texture2D = (plate.texture as AtlasTexture).atlas if plate.texture is AtlasTexture else null
			var from_inset: bool = Look.MapInsets().any(func(m: Dictionary) -> bool: return m["texture"] == atlas)
			var want_inset: bool = id == "ww2" and EUROPE.has(s)
			_check(atlas != null and (from_inset if want_inset else atlas == detail), "%s: cut from the look's %s" % [s, "Europe inset" if want_inset else "detail map"])

		# Every system: its mark and its name (manual p025), dressed.
		var marks := 0
		var pictures := 0
		var names := 0
		var bad: Array = []
		for c in map.get_children():
			if c.is_queued_for_deletion() or not c.has_meta("system"):
				continue
			var p: Planet = c.get_meta("system")
			var holder: Faction = LookSector.Holder(p)
			if c is SectorWindow.PlanetMapButton:
				marks += 1
				var sb: StyleBoxFlat = (c as Button).get_theme_stylebox("normal") as StyleBoxFlat
				if c.has_meta("sprite"):
					# Its own picture (the WWII flags): no disc behind it, the HQ
					# edged in brass, any other unedged.
					pictures += 1
					var hq_edge: bool = sb != null and sb.border_color.is_equal_approx(Look.C("brass")) and sb.border_width_left > 0
					if sb == null or sb.bg_color.a > 0.0 or (hq_edge != Gid.ShowHqHighlight(p)) or (c as Button).icon == null:
						bad.append("%s picture" % p.Name)
					continue
				var want_fill: Color = holder.FactionColor if holder != null else Look.C("paper")
				var want_rim: Color = Look.C("brass") if Gid.ShowHqHighlight(p) else Look.C("ink")
				if sb == null or not sb.bg_color.is_equal_approx(want_fill) or not sb.border_color.is_equal_approx(want_rim):
					bad.append("%s mark" % p.Name)
			elif c is Label and (c as Label).text == p.Name:
				names += 1
				var l := c as Label
				if l.get_theme_font("font") != Look.F("body_bold") or Look.Contrast(l.get_theme_color("font_color"), Look.C("paper")) < 4.5 \
						or l.get_theme_color("font_outline_color") != Look.C("paper"):
					bad.append("%s name" % p.Name)
			elif c.has_meta("corner"):
				var b := c as Button
				# Every icon says what it is (TeeJ, 2026-09-30), and a pack
				# that names its own icons shows them.
				if b.tooltip_text.strip_edges().is_empty():
					bad.append("%s %s icon has no tooltip" % [p.Name, c.get_meta("corner")])
				var own: Dictionary = FactionRegistry.Pack.Display.Icons
				var corner_id: String = str(c.get_meta("corner"))
				if own.has(corner_id) and (b.icon == null or not b.icon.resource_path.ends_with(str(own[corner_id]))):
					bad.append("%s %s icon is not the pack's" % [p.Name, corner_id])
				# The pack's word for a fleet held at a system (TeeJ, 2026-09-30:
				# WWII fleets are not "in orbit").
				if corner_id == "fleet" and not b.tooltip_text.contains(Terms.lower("in_orbit")):
					bad.append("%s fleet icon's words are not the pack's (%s)" % [p.Name, b.tooltip_text.get_slice("\n", 0)])
				var glyph: Color = b.get_theme_color("icon_normal_color")
				var want: Color = Look.C("signal") if str(c.get_meta("corner")) == "uprising" else Look.C("ink")
				var tab: StyleBox = b.get_theme_stylebox("normal")
				if not glyph.is_equal_approx(want) or not (tab is StyleBoxFlat and (tab as StyleBoxFlat).bg_color.is_equal_approx(Look.C("paper"))):
					bad.append("%s %s icon" % [p.Name, c.get_meta("corner")])
			elif c.has_meta("bar_row"):
				var kind: String = str(c.get_meta("bar_row"))
				var filled: int = int(c.get_meta("filled", 0))
				var i := 0
				for blk in c.get_children():
					if not blk is Panel:
						continue
					var bs: StyleBoxFlat = (blk as Panel).get_theme_stylebox("panel") as StyleBoxFlat
					if bs == null or not bs.border_color.is_equal_approx(Look.C("ink")):
						bad.append("%s %s block unedged" % [p.Name, kind])
						break
					for sw in sw_colours:
						if bs.bg_color.is_equal_approx(sw):
							bad.append("%s %s block in a Star Wars colour" % [p.Name, kind])
					if kind != "loyalty":
						var want_blk: Color = (Look.C("ink") if kind == "energy" else Look.C("olive")) if i < filled else Look.C("paper")
						if not bs.bg_color.is_equal_approx(want_blk):
							bad.append("%s %s block %d" % [p.Name, kind, i])
					i += 1
		var in_sector: int = sector.Planets.size()
		_check(marks == in_sector and names == in_sector, "%s: every system has its mark and name (%d of %d, %d)" % [s, marks, in_sector, names])
		if id == "ww2":
			_check(pictures == in_sector, "%s: every system flies its flag (%d of %d)" % [s, pictures, in_sector])
		_check(bad.is_empty(), "%s: every mark, name, icon and bar in the look%s" % [s, "" if bad.is_empty() else " - " + ", ".join(bad.slice(0, 5))])
	_check(sectors > 0, "%s: plain sector windows checked (%d)" % [id, sectors])
	_done()


func _done() -> void:
	print("[look_sector] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
