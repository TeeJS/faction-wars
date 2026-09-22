class_name GalaxyMap
extends Node2D
## frontend/GalaxyMap.cs - the strategic map: a click target per sector, and
## every planet as a faction-colored dot with a "+" flare behind it sized by the
## active GID mode's tier (manual p021, p061-p062, p069-p072).

enum MapLayer { PopularSupport = 0, IdlePersonnel = 1, IdleConstructionYards = 2, IdleTroopTraining = 3, IdleShipyards = 4, Fleets = 5 }

var _uiManager: UIManager
var _bar: GidBar   # the selector overlay + active-mode label

# Every planet draws as two stacked glyphs: a faction-colored dot that always
# marks the world, and a "+" flare BEHIND it whose size is the planet's tier.
var _planetStars: Dictionary = {}    # Planet -> Label
## THE PACK'S MAP PICTURE (pack.json map_image), drawn behind everything at
## origin, scaled to fit Frame. map.json coordinates are PIXELS OF THAT PICTURE
## at its native size (SCHEMA.md section 4), so every marker is placed at
## coordinate * _scale and lines up with the picture whatever its size.
var _backdrop: Sprite2D = null
var _scale: float = 1.0
## One invisible button per region, centred on its dot: a click opens the
## region's THEATRE (the sector window), so a crowded theatre is reachable
## through any of its regions even where theatre boxes overlap. Added after
## every theatre button so they sit on top for input.
var _regionHits: Dictionary = {}     # Planet -> Button
## Padding around a theatre's regions for its click box. Was 30: with the WWII
## pack's Europe, eight theatre boxes 60 px larger than their regions stacked
## on top of each other and only the topmost took the click.
const SectorPadding := 8.0
const RegionHitSize := 18.0
## The map area on screen, in this node's space: the rectangle the scene used
## to give the Star Wars picture (Main.tscn, 1070.67 x 803 at 150,99).
const Frame := Vector2(1070.6666, 803.0)
var _planetFlares: Dictionary = {}   # Planet -> Label
# The Alliance HQ, highlighted for an Alliance player only; drawn in _draw().
var _hqPlanet: Planet = null

var _paintedVisuals: String = ""
var _sincePoll: float = 0.0

# Same cadence as UIManager's window poll.
const PollSeconds := 0.25


## C#: private GidMode _mode, backed by Gid.ActiveMode.
func _mode() -> Gid.GidMode:
	return Gid.ActiveMode()


func InitializeMap(galaxyData: Array, uiManager: UIManager) -> void:
	_uiManager = uiManager
	# Register this map with the UIManager so it can send layer change commands.
	_uiManager.ActiveGalaxyMap = self

	# Clear out any old debug nodes and references.
	for child in get_children():
		child.queue_free()
	_planetStars.clear()
	_planetFlares.clear()
	_regionHits.clear()
	_hqPlanet = null
	_backdrop = null
	_scale = 1.0
	_load_backdrop()

	print("\n--- DRAWING GALAXY: %d Sectors Loaded ---" % galaxyData.size())

	if galaxyData.is_empty():
		push_error("CRITICAL: Galaxy data is empty! Did the JSON files load?")
		return

	for sector in galaxyData:
		var sectorButton := Button.new()
		sectorButton.text = ("Sector %d" % sector.SectorId) if sector.Name.is_empty() else sector.Name
		sectorButton.flat = true
		sectorButton.add_theme_color_override("font_color", Color(1, 1, 1, 0))
		sectorButton.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		sectorButton.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.8, 1))

		var localSector: Sector = sector
		sectorButton.pressed.connect(func() -> void: _uiManager.OnSectorClicked(localSector))

		var scaleFactor := _scale
		sector.MinX = INF
		sector.MinY = INF
		sector.MaxX = -INF
		sector.MaxY = -INF

		for planet in sector.Planets:
			# Flare behind the dot. ZIndex rather than child order so the
			# stacking can't be broken by anything added to this node later.
			var planetFlare := Label.new()
			planetFlare.text = "+"
			planetFlare.z_index = 0
			add_child(planetFlare)
			_planetFlares[planet] = planetFlare

			var planetStar := Label.new()
			planetStar.text = "•"
			planetStar.z_index = 1
			add_child(planetStar)
			_planetStars[planet] = planetStar

			if planet.MapX < sector.MinX:
				sector.MinX = planet.MapX
			if planet.MapY < sector.MinY:
				sector.MinY = planet.MapY
			if planet.MapX > sector.MaxX:
				sector.MaxX = planet.MapX
			if planet.MapY > sector.MaxY:
				sector.MaxY = planet.MapY

		var padding := SectorPadding

		if is_inf(sector.MinX):
			sectorButton.position = Vector2(sector.MapX * scaleFactor, sector.MapY * scaleFactor)
			sectorButton.size = Vector2(100, 100)
		else:
			var width: float = (sector.MaxX - sector.MinX) * scaleFactor + (padding * 2)
			var height: float = (sector.MaxY - sector.MinY) * scaleFactor + (padding * 2)
			sectorButton.size = Vector2(width, height)
			sectorButton.position = Vector2((sector.MinX * scaleFactor) - padding, (sector.MinY * scaleFactor) - padding)

		add_child(sectorButton)
		print("Spawned [%s] at X:%s, Y:%s (Planets: %d)" % [sectorButton.text, str(sector.MapX * scaleFactor), str(sector.MapY * scaleFactor), sector.Planets.size()])

	# Region hit buttons last, so every one is above every theatre box for input.
	for sector in galaxyData:
		var localSector: Sector = sector
		for planet in sector.Planets:
			var hit := Button.new()
			hit.flat = true
			hit.tooltip_text = "%s - %s" % [planet.Name, sector.Name]
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			hit.size = Vector2(RegionHitSize, RegionHitSize)
			hit.position = MapPos(planet.MapX, planet.MapY) - Vector2(RegionHitSize, RegionHitSize) / 2.0
			hit.pressed.connect(func() -> void: _uiManager.OnSectorClicked(localSector))
			add_child(hit)
			_regionHits[planet] = hit

	# Attach the Galactic Information Display selector + active-mode label.
	_bar = GidBar.new()
	add_child(_bar)
	_bar.Setup(self)
	_bar.SetActiveLabel(_mode().LabelText)
	_bar.ShowKeyFor(_mode())

	# Refresh highlights whenever a day passes (support shifts, arrivals, builds).
	EventBus.OnDayAdvanced.erase(OnDayAdvanced)
	EventBus.OnDayAdvanced.append(OnDayAdvanced)

	# Apply initial visual coloring
	RefreshVisuals()


func OnDayAdvanced(_day: int) -> void:
	RefreshVisuals()


## Switch the active GID mode (from the selector bar).
func SetMode(mode: Gid.GidMode) -> void:
	Gid.SetActiveMode(mode)
	if _bar != null:
		_bar.SetActiveLabel(mode.LabelText)
		_bar.ShowKeyFor(mode)
	RefreshVisuals()
	# Open sector windows mirror this mode, so they have to repaint too.
	EventBus.BroadcastChanged()


## By pack mode id (display.json). Falls back to the default mode.
static func FindMode(id: String) -> Gid.GidMode:
	var m := Gid.ModeById(id)
	return m if m != null else Gid.Default()


## Back-compat shim: the old "Galaxy Map Layers" MenuButton still calls this
## with a MapLayer index - map it onto the GID modes.
func SetLayer(layerIndex: int) -> void:
	if not MapLayer.values().has(layerIndex):
		return
	var m: Gid.GidMode
	match layerIndex:
		MapLayer.PopularSupport:        m = FindMode("popular_support")
		MapLayer.IdlePersonnel:         m = FindMode("idle_personnel")
		MapLayer.IdleConstructionYards: m = FindMode("construction_yards")
		MapLayer.IdleTroopTraining:     m = FindMode("training_facilities")
		MapLayer.IdleShipyards:         m = FindMode("shipyards")
		MapLayer.Fleets:                m = FindMode("idle_fleets")
		_:                              m = Gid.Default()
	SetMode(m)


## WHAT THE OVERLAY IS CURRENTLY DRAWING, as a cheap string, so the poll can
## repaint the map the instant any of it changes (the map is a Node2D, not a
## DraggableWindow, so it has no StateSignature).
func VisualSignature() -> String:
	var m: Gid.GidMode = _mode()
	if m == null:
		return "-"
	var parts: PackedStringArray = PackedStringArray([m.LabelText, "|"])
	for p in _planetStars.keys():
		var known: bool = m.Reveal.call(p)
		var flare: int = (0 if m == Gid.DisplayOff else m.TierFor(m.Magnitude.call(p)).FlareSize) if known else -1
		parts.append("%d.%s.%s," % [flare, p.ControllingFaction.Id if p.ControllingFaction != null else "-", "1" if Gid.ShowHqHighlight(p) else "0"])
	return "".join(parts)


func _process(delta: float) -> void:
	if _planetStars.is_empty():
		return
	_sincePoll += delta
	if _sincePoll < PollSeconds:
		return
	_sincePoll = 0
	var now: String = VisualSignature()
	if now == _paintedVisuals:
		return
	RefreshVisuals()


func RefreshVisuals() -> void:
	var displayOff: bool = _mode() == Gid.DisplayOff
	_hqPlanet = null

	# Recorded before the repaint, so a redraw triggered from anywhere else
	# also settles the poll.
	_paintedVisuals = VisualSignature()

	for planet in _planetStars.keys():
		var dot: Label = _planetStars[planet]
		var flare: Label = _planetFlares[planet]

		var known: bool = _mode().Reveal.call(planet)

		# Independent of the active mode and of Display Off: your HQ stays marked.
		if Gid.ShowHqHighlight(planet):
			_hqPlanet = planet

		if not known:
			# Unexplored: grey "+" only.
			Place(flare, "+", 16, Gid.CUnexplored(), planet)
			Place(dot, "", 0, Gid.CUnexplored(), planet)
			continue

		var faction: Color = Gid.FactionColor(planet)
		Place(dot, "•", Gid.DotSize, faction, planet)

		if displayOff:
			# Default strategic view: dots only, no magnitude overlay.
			Place(flare, "", 0, faction, planet)
			continue

		var tier: Gid.GidTier = _mode().TierFor(_mode().Magnitude.call(planet))
		if tier.FlareSize > 0:
			Place(flare, "+", tier.FlareSize, faction, planet)
		else:
			Place(flare, "", 0, faction, planet)

	queue_redraw()   # repaint the HQ highlight


## Where a map.json coordinate lands in this node's space.
func MapPos(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _scale


## The picture's scale on screen, for anything else that places by coordinate.
func MapScale() -> float:
	return _scale


func Backdrop() -> Sprite2D:
	return _backdrop


## Planet -> the invisible button on its dot (opens its theatre).
func RegionButtons() -> Dictionary:
	return _regionHits


## The pack's map picture, fitted into Frame from the top-left corner. A pack
## whose picture is missing draws nothing and places markers unscaled.
func _load_backdrop() -> void:
	var pack := FactionRegistry.Pack
	if pack == null or pack.Manifest.MapImage.is_empty():
		return
	var tex: Texture2D = load("%s/%s/%s" % [FactionRegistry.PACKS_ROOT, pack.Manifest.Id, pack.Manifest.MapImage])
	if tex == null:
		push_error("[GalaxyMap] map_image '%s' could not be loaded." % pack.Manifest.MapImage)
		return
	var size := tex.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_scale = minf(Frame.x / size.x, Frame.y / size.y)
	_backdrop = Sprite2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.texture = tex
	_backdrop.centered = false
	_backdrop.scale = Vector2(_scale, _scale)
	_backdrop.z_index = -10
	_backdrop.z_as_relative = false
	add_child(_backdrop)


## The Alliance HQ highlight: a thin white 8-point burst centered exactly on
## the planet's point, painted before any child Label.
func _draw() -> void:
	if _hqPlanet == null:
		return
	var c := MapPos(_hqPlanet.MapX, _hqPlanet.MapY)
	var half: float = Gid.HaloSpan / 2.0
	var t: float = Gid.HaloThickness
	var d: float = half * Gid.HaloDiagonal

	# Straight rays.
	draw_line(Vector2(c.x - half, c.y), Vector2(c.x + half, c.y), Gid.CHighlight, t)
	draw_line(Vector2(c.x, c.y - half), Vector2(c.x, c.y + half), Gid.CHighlight, t)

	# Diagonal rays, shorter - together these read as the original's burst.
	var dg: float = d * 0.7071
	draw_line(Vector2(c.x - dg, c.y - dg), Vector2(c.x + dg, c.y + dg), Gid.CHighlight, t)
	draw_line(Vector2(c.x - dg, c.y + dg), Vector2(c.x + dg, c.y - dg), Gid.CHighlight, t)


## Center a glyph precisely on the planet's point. An empty glyph hides the label.
## An instance method since the point is coordinate * this map's picture scale.
func Place(lbl: Label, glyph: String, size_: int, color: Color, planet: Planet) -> void:
	if glyph.is_empty() or size_ <= 0:
		lbl.visible = false
		return
	lbl.visible = true
	lbl.text = glyph
	lbl.add_theme_font_size_override("font_size", size_)
	color.a = 1.0
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(size_ * 2, size_ * 2)
	lbl.position = MapPos(planet.MapX, planet.MapY) - Vector2(size_, size_)


func NewDayUpdate() -> void:
	RefreshVisuals()
