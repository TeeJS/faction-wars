class_name GalaxyMap
extends Node2D
## frontend/GalaxyMap.cs - the strategic map: a click target per sector, and
## every planet as a faction-colored dot with a "+" flare behind it sized by the
## active GID mode's tier (manual p021, p061-p062, p069-p072).

var _uiManager: UIManager
var _bar: GidBar   # the selector overlay + active-mode label

# Every planet draws as two stacked glyphs: a faction-colored dot that always
# marks the world, and a "+" flare BEHIND it whose size is the planet's tier.
var _planetStars: Dictionary = {}    # Planet -> Label
## THE PACK'S MAP PICTURE (pack.json map_image), drawn behind everything where
## pack.json's map_image_rect puts it in the pack's MAP COORDINATE SPACE
## (SCHEMA.md section 4; the picture's own pixels when no rect is given). The
## picture is fitted into Frame keeping its shape, and the rect is laid onto
## the picture PER AXIS - the axes may scale differently: the original draws
## its 1024-unit square space onto its 607x437 galaxy picture - so every
## marker at coordinate * _scale lands on the picture where the pack says.
## Coordinates are never rescaled to the picture: Planet.DistanceTo reads
## them, so they are travel time.
var _backdrop: Sprite2D = null
## The player's own artwork overlay (tools/FactionWarsExporter).
const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
## The original drew its 15 px stars on a 640-wide screen; ours is 1440.
const StarScale := 2.0
var _planetSprites: Dictionary = {}   # Planet -> TextureRect (the original's star)
var _scale: Vector2 = Vector2.ONE
## The map-space point at the frame's top-left corner (map_image_rect's x, y).
## Star Wars: where the original's 1024 space starts on its picture; WWII: (0, 0).
var _origin: Vector2 = Vector2.ZERO
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
## The theatre name on hover (TeeJ, 2026-09-22: "larger and darker", but not
## so big it spills far past its theatre). Only the hovered one shows.
const TitleFontSize := 17   # 20 less 15% (TeeJ, 2026-09-22)
## Black letters with a thin light rim, drawn ABOVE the stars (TeeJ,
## 2026-09-23: "in the foreground and darker so they can be SEEN" - the
## 4 px cream outline had swallowed the letters, and the GID stars, at
## z_index 1, drew over the name).
const TitleColor := Color(0.02, 0.02, 0.02, 1)
const TitleOutline := Color(1, 0.97, 0.88, 0.95)
const TitleOutlineSize := 2
const TitleZIndex := 3
## Emboldened, so the black strokes carry the name and the rim stays a rim.
static var _titleFont: FontVariation = null

static func TitleFont() -> Font:
	if _titleFont == null:
		_titleFont = FontVariation.new()
		_titleFont.base_font = ThemeDB.fallback_font
		_titleFont.variation_embolden = 0.9
	return _titleFont
## THE ORIGINAL'S SECTOR NAME, when its art is in use (TeeJ, 2026-09-25:
## "tool tips/sector names are still too hard to read, please match the
## original"). Measured on his screenshot of Calaron: yellow (240,240,0), Arial
## 14, regular weight, two lines - the name, then "Sector" - left-aligned, no
## outline; the text's top-left at the sector's own point on the picture,
## where a star's 15 px bitmap has its top-left (7 px up and left of the
## star's centre, which is where MapPos puts a coordinate).
const OTitleColor := Color(240 / 255.0, 240 / 255.0, 0)
const OTitlePx := 14.0
const StarHalf := 7.0
## The picture's pixels in this node's space (the backdrop's scale).
var _fit: float = 1.0
## WHICH NAME SHOWS: the sector under the pointer, over its box or any of its
## regions. The region buttons sit on top of the box, so the box's own exit
## fired on every star and the name went out until the pointer was off the
## star again ("they also seem more flickery than the original?"); the
## regions now hold their sector's name up too.
var _titles: Dictionary = {}       # Sector -> its name: a Label, or the plain look's button
var _sectorButtons: Dictionary = {}  # Sector -> its click box
var _hoverOwner: Dictionary = {}   # Control (a box or a region) -> Sector
var _under: Array = []             # the boxes and regions the pointer is over, last entered last
var _hovered: Sector = null
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
	_uiManager.PinSectors(galaxyData)

	# Clear out any old debug nodes and references.
	for child in get_children():
		child.queue_free()
	_planetStars.clear()
	_planetFlares.clear()
	_regionHits.clear()
	_titles.clear()
	_sectorButtons.clear()
	_hoverOwner.clear()
	_under.clear()
	_hovered = null
	_hqPlanet = null
	_backdrop = null
	_scale = Vector2.ONE
	_fit = 1.0
	_origin = Vector2.ZERO
	_load_backdrop()
	var original: bool = OriginalLook()

	print("\n--- DRAWING GALAXY: %d Sectors Loaded ---" % galaxyData.size())

	if galaxyData.is_empty():
		push_error("CRITICAL: Galaxy data is empty! Did the JSON files load?")
		return

	for sector in galaxyData:
		var sectorButton := Button.new()
		var sectorName: String = ("Sector %d" % sector.SectorId) if sector.Name.is_empty() else sector.Name
		sectorButton.flat = true
		sectorButton.z_index = TitleZIndex
		if original:
			# The original's name: its own label, at the sector's point.
			var title := Label.new()
			title.name = "SectorName"
			title.text = "%s\n%s" % [sectorName, Terms.label("sector")]
			title.add_theme_font_override("font", OUI.Face(false))
			title.add_theme_font_size_override("font_size", roundi(OTitlePx * _fit))
			title.add_theme_color_override("font_color", OTitleColor)
			title.position = MapPos(sector.MapX, sector.MapY) - Vector2(StarHalf, StarHalf) * _fit
			title.z_index = TitleZIndex
			title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title.visible = false
			add_child(title)
			_titles[sector] = title
		else:
			# The theatre's name shows ONLY while hovered: dark, with a light
			# outline, so it reads on a paper map (WWII) as well as on a starfield
			# (Star Wars). A theme outline draws even on transparent text, which
			# put every name on screen at once; so the outline is switched on and
			# off with the mouse.
			sectorButton.text = sectorName
			sectorButton.add_theme_font_size_override("font_size", TitleFontSize)
			sectorButton.add_theme_font_override("font", TitleFont())
			sectorButton.add_theme_color_override("font_outline_color", TitleOutline)
			_title_visible(sectorButton, false)
			_titles[sector] = sectorButton

		var localSector: Sector = sector
		_sectorButtons[sector] = sectorButton
		_hoverOwner[sectorButton] = sector
		sectorButton.mouse_entered.connect(_Enter.bind(sectorButton))
		sectorButton.mouse_exited.connect(_Leave.bind(sectorButton))
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

			# The original's star bitmap, used instead of both labels when the
			# player imported it (src/ui/artwork.gd); hidden otherwise.
			var sprite := TextureRect.new()
			sprite.z_index = 1
			sprite.visible = false
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.stretch_mode = TextureRect.STRETCH_SCALE
			add_child(sprite)
			_planetSprites[planet] = sprite

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
			sectorButton.position = MapPos(sector.MapX, sector.MapY)
			sectorButton.size = Vector2(100, 100)
		else:
			var width: float = (sector.MaxX - sector.MinX) * scaleFactor.x + (padding * 2)
			var height: float = (sector.MaxY - sector.MinY) * scaleFactor.y + (padding * 2)
			sectorButton.size = Vector2(width, height)
			sectorButton.position = MapPos(sector.MinX, sector.MinY) - Vector2(padding, padding)

		add_child(sectorButton)
		print("Spawned [%s] at X:%s, Y:%s (Planets: %d)" % [sectorButton.text, str(sector.MapX * scaleFactor.x), str(sector.MapY * scaleFactor.y), sector.Planets.size()])

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
			# Over a region is over its sector: its name stays up.
			_hoverOwner[hit] = sector
			hit.mouse_entered.connect(_Enter.bind(hit))
			hit.mouse_exited.connect(_Leave.bind(hit))
			add_child(hit)
			_regionHits[planet] = hit

	# Attach the Galactic Information Display selector + active-mode label.
	_bar = GidBar.new()
	add_child(_bar)
	_bar.Setup(self)
	# A map rebuilt under the Command Center frame (a loaded game) fits it again.
	if _uiManager != null and _uiManager.CommandFrameRef != null:
		_bar.FitToFrame(UIManager.MapFrame)
		_bar.FitAcross(_uiManager.CommandFrameRef.ScreenRect())
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

		# THE ORIGINAL'S STAR, when imported: the side's colour and the tier's
		# size are the bitmap's own. Display Off and an unknown world draw the
		# smallest star; nothing found means the labels below, as before.
		var tierName: String = "none"
		if known and not displayOff:
			tierName = Gid.FlareName(_mode().TierFor(_mode().Magnitude.call(planet)).FlareSize)
		var starTex: Texture2D = Art.GidStar(Gid.StarSide(planet, known), tierName)
		var sprite: TextureRect = _planetSprites[planet]
		if starTex != null:
			sprite.texture = starTex
			sprite.size = starTex.get_size() * StarScale
			sprite.position = MapPos(planet.MapX, planet.MapY) - sprite.size / 2.0
			sprite.visible = true
			flare.visible = false
			dot.visible = false
			continue
		sprite.visible = false

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


## Show or hide a theatre's name: text and outline together, so nothing of it
## is drawn while the mouse is elsewhere.
static func _title_visible(b: Button, on: bool) -> void:
	var c := TitleColor if on else Color(TitleColor, 0.0)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c)
	b.add_theme_color_override("font_pressed_color", c.darkened(0.3) if on else c)
	b.add_theme_color_override("font_focus_color", c)
	b.add_theme_constant_override("outline_size", TitleOutlineSize if on else 0)


## Whether a theatre's name is currently drawn (its outline is on).
static func TitleShown(b: Button) -> bool:
	return b.get_theme_constant("outline_size") > 0


## Whether the original's art is in use, so the original's sector names.
static func OriginalLook() -> bool:
	return Art.ButtonIcon("title_close") != null


## The pointer came onto a sector's box or one of its regions, or left one:
## the sector shown is the owner of the last one it is still over, so moving
## off a box onto one of its own regions keeps the name up.
func _Enter(c: Control) -> void:
	_under.erase(c)
	_under.append(c)
	_PickHovered()


func _Leave(c: Control) -> void:
	_under.erase(c)
	_PickHovered()


func _PickHovered() -> void:
	_hovered = null
	while not _under.is_empty() and _hovered == null:
		_hovered = _hoverOwner.get(_under.back(), null)
		if _hovered == null:
			_under.pop_back()
	_PaintTitles()


func _PaintTitles() -> void:
	for s in _titles:
		var t: Control = _titles[s]
		if not is_instance_valid(t):
			continue
		var on: bool = s == _hovered
		if t is Button:
			_title_visible(t, on)
		else:
			t.visible = on


## A sector's click box, and whether its name is showing.
func SectorButton(sector: Sector) -> Button:
	return _sectorButtons.get(sector, null)


func IsTitleShown(sector: Sector) -> bool:
	var t: Control = _titles.get(sector, null)
	if t == null:
		return false
	return TitleShown(t) if t is Button else t.visible


## A sector's name label in the original's look (null in the plain look).
func SectorTitle(sector: Sector) -> Label:
	var t: Variant = _titles.get(sector, null)
	return t if t is Label else null


## Where a map.json coordinate lands in this node's space: the frame's
## top-left is map_image_rect's (x, y), and the space is scaled onto the
## picture per axis.
func MapPos(x: float, y: float) -> Vector2:
	return (Vector2(x, y) - _origin) * _scale


## The map space's scale on screen, per axis, for anything else that places
## by coordinate.
func MapScale() -> Vector2:
	return _scale


func Backdrop() -> Sprite2D:
	return _backdrop


## The GID's mode name and selector (for the Command Center frame to fit).
func Bar() -> GidBar:
	return _bar


## Planet -> the invisible button on its dot (opens its theatre).
func RegionButtons() -> Dictionary:
	return _regionHits


## The pack's map picture, fitted into Frame from the top-left corner, its
## shape kept; the map space laid onto it per axis. The picture may come from
## an art set the player has not imported: the map is still placed by
## map_image_rect, with no picture under it - taken to be the frame's shape,
## as the Star Wars galaxy is (640x480 in a 4:3 frame). A pack with neither a
## picture nor a rect places markers unscaled.
func _load_backdrop() -> void:
	var pack := FactionRegistry.Pack
	if pack == null or pack.Manifest.MapImage.is_empty():
		return
	var tex: Texture2D = Art.PackImage(pack.Manifest.MapImage)
	var rect := pack.Manifest.MapImageRect
	if tex == null:
		print("[GalaxyMap] map_image '%s' is not available - no backdrop." % pack.Manifest.MapImage)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			_scale = Frame / rect.size
			_origin = rect.position
		return
	var size := tex.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(Vector2.ZERO, size)   # no rect: coordinates are picture pixels
	var fit: float = minf(Frame.x / size.x, Frame.y / size.y)
	_fit = fit
	_scale = size / rect.size * fit
	_origin = rect.position
	_backdrop = Sprite2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.texture = tex
	_backdrop.centered = false
	_backdrop.position = Vector2.ZERO   # the frame's top-left IS the picture's
	_backdrop.scale = Vector2(fit, fit)
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
