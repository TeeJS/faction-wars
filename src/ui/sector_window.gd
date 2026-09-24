class_name SectorWindow
extends DraggableWindow
## frontend/SectorWindow.cs - the Sector window (manual p025, Fig 2.8): every
## system in the sector, its four corner icons, and the mirrored GID star.
## While the crosshairs are up, a click anywhere on a system - its picture,
## corner icons, star, bars or name - names that system (SystemAt).

var _sector: Sector

## THE ORIGINAL'S SECTOR WINDOW (manual p025 Fig 2.8), with the player's
## imported art, measured on TeeJ's screenshot of the original's Corellian
## sector (2026-09-23) and drawn K times as large: a 235x360 window of
## see-through grey over the map with a one-pixel light frame (solid top and
## bottom, dotted sides) and no shadow; the sector's name in yellow Arial 13
## across the top; the box that switches the window to the other side of the
## screen and the close box; every system's 37x37 picture with its top-left
## in the box (20, 24) - (167, 295), placed by where it lies in the sector;
## the corner cells tiled round the picture's middle; the GID
## star under its lower left; the energy and materials rows (2x3 squares, 3
## apart) and the loyalty bar (the picture's width) under it; the name in its
## side's colour. Set by Populate for the static helpers below.
static var OriginalLook: bool = false
const K := OUI.K
const OW := 235
const OH := 360
const OBox := Rect2(20, 24, 147, 271)
const OSprite := 37
const OTitleColor := Color(240 / 255.0, 240 / 255.0, 0)
const ONeutral := Color(0, 1, 1)
const OBackground := Color(72 / 255.0, 72 / 255.0, 72 / 255.0, 0.78)
## OURS, NOT THE ORIGINAL'S (TeeJ, 2026-09-24: "with sectors being movable,
## they need to be less transparent - can we make them more opaque with a
## generic starfield background"): the original's see-through grey let the
## galaxy - and a second sector window - show through, which reads badly once
## they are moved over each other. Deep space, opaque, with its own stars.
const OSpace := Color(4 / 255.0, 5 / 255.0, 12 / 255.0, 1.0)
const StarCount := 170
const OBorder := Color(192 / 255.0, 192 / 255.0, 192 / 255.0)
## From each system's picture's top-left, in original pixels: the GID star's
## top-left, the energy and materials rows' tops (one pixel in), the loyalty
## bar's top, the name's line.
const OStar := Vector2(0, 26)
const OEnergyTop := 39.0
const ONameTop := 49.0
const ONamePx := 11.0
## The corner cells: the left and upper ones end 1.5 pixels short of the
## picture's middle, the right and lower ones start half a pixel past it.
const OCellNear := 1.5
const OCellFar := 0.5
## The original's bar colours (sampled): blue free energy, yellow mines, the
## orange of raw material still in the ground.
const OCEnergyFree := Color(0, 0, 1)
const OCMineBuilt := Color(1, 1, 0)
const OCMineFree := Color(249 / 255.0, 92 / 255.0, 15 / 255.0)
var _dockRight: bool = true
var _originalTitle: Label


static func CanBuildOriginal() -> bool:
	return Art.PlanetSprite(1) != null and Art.ButtonIcon("sector_switch") != null \
		and Art.ButtonIcon("title_close") != null and Art.ButtonIcon("title_minimize") != null


## Where the original's window sits: against the right or the left edge of
## the map frame (UIManager's Rect2(150, 99, 1070, ...)), and high enough to
## clear the bottom bars. At the map's top (y 99) the 720-pixel window ran 49
## pixels into the GID band and the HUD row under it and made them unusable
## (TeeJ, 2026-09-23: "way better for it to be higher, blocking Popular
## Support"). It is centred in the room between the top row (0-40, Main.tscn's
## Resources) and the GID band (from 80 above the bottom, GidBar): y 45 on the
## 850-pixel screen, 5 pixels clear of each, over the GID mode's name.
const TopRowBottom := 40
const GidBandTop := 80   # above the screen's bottom edge


static func DockPosition(right: bool) -> Vector2:
	var frame := Rect2(150, 99, 1070, 0)
	var screen_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 850))
	var room: float = screen_h - GidBandTop - TopRowBottom
	var y: float = TopRowBottom + floorf(maxf(0.0, room - OH * K) / 2.0)
	return Vector2(frame.end.x - OW * K if right else frame.position.x, y)


## The name's colour in the original: its side's, cyan for a system no side
## holds, the map's own grey for one never seen.
static func _OriginalNameColor(planet: Planet) -> Color:
	var owner: Faction = IntelManager.OwnerSeen(GameSettings.LocalFaction(), planet)
	if owner == null:
		return FactionRegistry.Unknown.FactionColor
	if owner == FactionRegistry.Neutral:
		return ONeutral
	return OUI.SideColor(owner)


## The window itself in the original's look: no title bar; see-through grey
## with the light frame and no shadow; the sector's name; the box that
## switches sides and the close box - plus our minimize box and a drag on
## the name. Built once - Populate runs again on every repaint.
func _BuildOriginalChrome(sector: Sector) -> void:
	if _originalTitle == null:
		(get_node("%TitleBar") as Control).visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = OSpace
		sb.shadow_size = 0
		sb.set_content_margin_all(0)
		add_theme_stylebox_override("panel", sb)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var area: MarginContainer = OUI.Flatten(self)
		# The starfield, under everything else in the window.
		var sky := Control.new()
		sky.name = "Starfield"
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.draw.connect(_DrawStars.bind(sky, sector.Name))
		area.add_child(sky)
		area.move_child(sky, 0)
		var chrome := Control.new()
		chrome.name = "OriginalChrome"
		chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chrome.draw.connect(_DrawFrame.bind(chrome))
		area.add_child(chrome)
		# Right-click on it: the pin menu (UIManager._WireSectorPinMenu).
		_originalTitle = OUI.Text(chrome, "", 0, 4.5, OW, 16, 13, OTitleColor, HORIZONTAL_ALIGNMENT_CENTER, false, "SectorTitle")
		_originalTitle.mouse_filter = Control.MOUSE_FILTER_STOP
		# OURS, NOT THE ORIGINAL'S (TeeJ, 2026-09-23: "allow them to be moved
		# and minimized, that was stupid UI in the original"; manual p063 has
		# Sector windows fixed and never minimized). Dragged by the name strip
		# like any title bar; the original's minimize box, left of the switch
		# box so the original's two boxes stay where they were.
		_originalTitle.gui_input.connect(OnTitleBarGuiInput)
		OUI.PictureButton(chrome, "title_minimize", 190, 2, "Minimize").pressed.connect(MinimizeWindow)
		OUI.PictureButton(chrome, "sector_switch", 204, 2, "Switch window to other side of screen").pressed.connect(_SwitchSide)
		OUI.PictureButton(chrome, "title_close", 218, 2, "Close").pressed.connect(CloseWindow)
	_originalTitle.text = sector.Name


## A generic starfield: points of light, most dim and white, a few bright,
## some faintly blue, one original pixel each (a bright one two). The same
## sky every time for a sector - its own generator, seeded by its name, so
## the game's random numbers are untouched.
static func _DrawStars(c: Control, seed_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_name)
	for i in StarCount:
		var x: int = rng.randi_range(1, OW - 2)
		var y: int = rng.randi_range(1, OH - 2)
		var b: float = rng.randf_range(0.4, 0.9)
		var blue: bool = rng.randf() < 0.18
		var color := Color(b * (0.8 if blue else 1.0), b * (0.85 if blue else 1.0), b, 1.0)
		var big: bool = rng.randf() < 0.05
		if big:
			color = Color(1, 1, 1, 1)
		var px: float = (2 if big else 1) * K
		c.draw_rect(Rect2(Vector2(x, y) * K, Vector2(px, px)), color)


## The frame: one light pixel all round, solid along the top and bottom and
## every other pixel down the sides (as sampled; the second row is lit too).
func _DrawFrame(c: Control) -> void:
	var w: float = OW * K
	var h: float = OH * K
	c.draw_rect(Rect2(0, 0, w, K), OBorder)
	c.draw_rect(Rect2(0, h - K, w, K), OBorder)
	for y in range(1, OH - 1):
		if y % 2 == 0 or y == 1:
			c.draw_rect(Rect2(0, y * K, K, K), OBorder)
			c.draw_rect(Rect2(w - K, y * K, K, K), OBorder)


## "Switch window to other side of screen" (manual p025 Fig 2.8).
func _SwitchSide() -> void:
	_dockRight = not _dockRight
	position = DockPosition(_dockRight)



# The planet markers were built once when the window opened and never
# rebuilt, so the mission icon showed whatever was true at that instant -
# it stayed lit after a mission ended, and a mission launched afterwards
# never lit it or gained its right-click menu.
func StateSignature() -> Variant:
	return GameSignature.ForSector(_sector)


func Refresh() -> void:
	if not CanRefresh():
		return
	if _sector != null and _uiManager != null:
		Populate(_sector, _uiManager)


func Populate(sector: Sector, uiManager: UIManager) -> void:
	_sector = sector
	_uiManager = uiManager
	var sectorMap: Control = get_node("%SectorMap")

	for child in sectorMap.get_children():
		child.queue_free()

	var original: bool = CanBuildOriginal()
	OriginalLook = original
	if original:
		_BuildOriginalChrome(sector)

	# WHILE THE CROSSHAIRS ARE UP the parts of a system that are not buttons
	# (star, bars, name) let the click through to the map, which names the
	# system - see SystemAt. Once only: Populate runs again on every repaint.
	if not sectorMap.gui_input.is_connected(_OnSectorMapInput):
		sectorMap.gui_input.connect(_OnSectorMapInput)

	var minX: float = sector.MinX
	var maxX: float = sector.MaxX
	var minY: float = sector.MinY
	var maxY: float = sector.MaxY

	var sectorWidth: float = maxX - minX
	var sectorHeight: float = maxY - minY

	if sectorWidth == 0:
		sectorWidth = 1.0
	if sectorHeight == 0:
		sectorHeight = 1.0

	# --- 1. ASPECT RATIO SCALING ---
	var maxDimension: float = 600.0   # The longest side of the window will be 300px
	var aspectRatio: float = sectorWidth / sectorHeight
	var mapSize: Vector2

	if aspectRatio >= 1.0:
		# Sector is wider than it is tall (Landscape)
		mapSize = Vector2(maxDimension, maxDimension / aspectRatio)
	else:
		# Sector is taller than it is wide (Portrait)
		mapSize = Vector2(maxDimension * aspectRatio, maxDimension)

	# Safety floor: Prevent the window from collapsing completely if planets are in a straight line
	mapSize.x = maxf(mapSize.x, 100.0)
	mapSize.y = maxf(mapSize.y, 100.0)
	if original:
		mapSize = Vector2(OW, OH) * K

	sectorMap.custom_minimum_size = mapSize

	# Slightly increased padding to make room for text at the bottom edges
	var padding: float = 60.0
	# The three bars and the name below the lowest system need more room
	# under it than the top row needs above it (BarsTop + the bars + the name).
	var paddingBottom: float = 92.0
	var usableWidth: float = mapSize.x - (padding * 2)
	var usableHeight: float = mapSize.y - padding - paddingBottom

	for planet in sector.Planets:
		# Everything added from here to the name label is this system's entry.
		var firstPart: int = sectorMap.get_child_count()

		var normalizedX: float = (planet.MapX - minX) / sectorWidth
		var normalizedY: float = (planet.MapY - minY) / sectorHeight

		var finalX: float = padding + (normalizedX * usableWidth)
		var finalY: float = padding + (normalizedY * usableHeight)
		if original:
			# The original's box: every system's picture has its top-left in
			# (20, 24) - (167, 295), placed by where it lies in the sector
			# (fitted to all ten Corellian systems to the pixel).
			var nx: float = normalizedX if maxX > minX else 0.5
			var ny: float = normalizedY if maxY > minY else 0.5
			finalX = (roundf(OBox.position.x + nx * OBox.size.x) + OSprite / 2.0) * K
			finalY = (roundf(OBox.position.y + ny * OBox.size.y) + OSprite / 2.0) * K

		# --- 1. THE MAIN PLANET BUTTON ---
		var planetCircle := StyleBoxFlat.new()
		planetCircle.bg_color = planet.GetFactionColor()
		planetCircle.corner_radius_top_left = 16
		planetCircle.corner_radius_top_right = 16
		planetCircle.corner_radius_bottom_left = 16
		planetCircle.corner_radius_bottom_right = 16

		# The manual has the Alliance HQ highlighted on the Sector window as
		# well as the Galactic Information Display, for an Alliance player
		# only. Gid.ShowHqHighlight is the single rule both views share.
		if Gid.ShowHqHighlight(planet):
			planetCircle.border_color = Gid.CHighlight
			planetCircle.set_border_width_all(3)

		var planetMapNode := PlanetMapButton.new()
		planetMapNode.AssociatedPlanet = planet
		planetMapNode.UIManagerRef = uiManager
		planetMapNode.custom_minimum_size = Vector2(32, 32)
		planetMapNode.size = Vector2(32, 32)
		planetMapNode.position = Vector2(finalX - 16, finalY - 16)
		planetMapNode.tooltip_text = planet.Name

		# THE PLANET ITSELF, when the player has the original's sprites (manual
		# p025: "planet artwork with the system name beneath, coloured by
		# controlling faction"). The disc's colour moves to the name; the HQ
		# ring stays. Without a sprite the coloured disc is drawn as before.
		var sprite: Texture2D = Art.PlanetSprite(planet.ArtworkId)
		var nameColor := Color(0.8, 0.8, 0.8, 0.9)
		if sprite != null:
			planetMapNode.icon = sprite
			planetMapNode.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			planetMapNode.expand_icon = true
			planetMapNode.set_meta("sprite", true)
			nameColor = planet.GetFactionColor()
			if original:
				# The picture at its own size, drawn K times; the name in the
				# side's colour (the original's neutral is cyan).
				planetMapNode.icon = Art.Scaled(sprite, K)
				planetMapNode.expand_icon = false
				planetMapNode.custom_minimum_size = Vector2(OSprite, OSprite) * K
				planetMapNode.size = planetMapNode.custom_minimum_size
				planetMapNode.position = Vector2(finalX, finalY) - planetMapNode.size / 2.0
				nameColor = _OriginalNameColor(planet)
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(0, 0, 0, 0)
			ring.set_corner_radius_all(16)
			if original:
				# Round the picture, and no margins: the button stays the
				# picture's size, so the picture stays where it was placed.
				ring.set_corner_radius_all(OSprite * K / 2)
				ring.set_content_margin_all(0)
			if Gid.ShowHqHighlight(planet):
				ring.border_color = Gid.CHighlight
				ring.set_border_width_all(3)
			planetCircle = ring

		planetMapNode.add_theme_stylebox_override("normal", planetCircle)
		planetMapNode.add_theme_stylebox_override("hover", planetCircle)
		planetMapNode.add_theme_stylebox_override("pressed", planetCircle)

		# Main planet click opens the Planet Window
		planetMapNode.pressed.connect(func() -> void: uiManager.OnPlanetClicked(planet))
		sectorMap.add_child(planetMapNode)

		# --- THE MIRRORED GID STAR ---
		# "Note the colors of the icons and system names are the same as
		# those in the Galactic Information Display" (manual p025) - and
		# Fig 2.8 shows the DISPLAY'S OWN STAR here too, at each system's
		# lower left. It appears and disappears independently of the System
		# Defenses tower beside it (Praesitlyn carries the star with no
		# tower), so it is the GID marker, not part of that icon.
		#
		# Same mode, same magnitude, same tier table as the galaxy map, so
		# switching the display repaints both views identically.
		AddGidStar(sectorMap, planet, finalX, finalY)

		# YOUR OWN MISSION IS NEVER HIDDEN FROM YOU, even on a system you
		# have never scouted.
		#
		# "Reconnaissance: any system NOT UNDER YOUR CONTROL - explored OR
		# UNEXPLORED. The ONLY mission that can target an unexplored system"
		# (manual p107). Every corner icon here, the mission icon included,
		# was drawn only for explored systems - so the one mission type the
		# manual sends to unexplored space was the one mission that could
		# never be seen running. p109 then makes it worse: the icon is how
		# you reach Status and ABORT, so a probe droid could be sent out and
		# never called back.
		#
		# The other three icons stay hidden, and should: Economy, Fleets and
		# Defenses report system CONTENTS, which is precisely what you have
		# not scouted yet and what the recon mission is being flown to learn.
		var myMissionHere: bool = Lq.any(MissionManager.Active(),
			func(m: Mission) -> bool:
				return m.Target == planet \
					and m.Faction == GameSettings.PlayerFaction \
					and not m.Finished)

		# Ours on the way count too: a fleet of ours heading to a system we have
		# not charted shows there all the same (its fleet corner, below).
		var oursInbound: bool = Lq.any(planet.OrbitingFleets, func(f: Fleet) -> bool:
			return f.Status == Enums.Status.Enroute and f.Destination == planet and f.Faction == GameSettings.PlayerFaction)

		if planet.IsExplored or myMissionHere or oursInbound:
			# --- THE 4 CORNER BUTTONS ---
			# Distance from the exact center of the planet to the center of the corner buttons
			var offset: float = 22.0
			# Corner button size
			var cornerSize: float = 16.0
			var cornerHalf: float = cornerSize / 2.0

			# Calculate the exact Top-Left corner coordinates for the 4 buttons
			var cornerPositions: Array[Vector2] = [
				Vector2(finalX - offset - cornerHalf, finalY - offset - cornerHalf),   # Top-Left
				Vector2(finalX + offset - cornerHalf, finalY - offset - cornerHalf),   # Top-Right
				Vector2(finalX - offset - cornerHalf, finalY + offset - cornerHalf),   # Bottom-Left
				Vector2(finalX + offset - cornerHalf, finalY + offset - cornerHalf),   # Bottom-Right
			]

			var cornerLabels: Array[String] = ["E", "F", "D", "M"]   # the corner's job: Economy, Fleet, Defenses, Mission
			# The glyph each corner shows (manual p070 Fig 3.7): Manufacturing top
			# left, Fleet upper right, Defenses lower left, Mission lower right.
			# Our own artwork (assets/icons, or the pack's via display.json
			# `icons`), white on alpha, tinted with the faction colour as the
			# letters were (TeeJ, 2026-09-22).
			var cornerGlyphs: Array[String] = ["manufacturing", "fleet", "defenses", "mission"]

			# ⚠ THE FLEET MARKER IS CONDITIONAL, AND IT WAS ALWAYS DRAWN.
			#
			# "ANY TIME A FLEET IS IN ORBIT around a system, that system will
			# have a Fleet icon in the upper right corner" (manual p111, Fig
			# 3.53) - so the icon's PRESENCE is the information. Ours sat on
			# every explored world whether or not anything was in orbit, which
			# made it impossible to tell from the map where the fleets were.
			# Reported from play.
			#
			# This is not the mission marker's rule. That one is a persistent
			# corner that lights (manual p109); this one appears and disappears.
			#
			# IN ORBIT means in orbit. Transit files a fleet under its
			# DESTINATION the moment it departs, so OrbitingFleets holds
			# inbound ones too - they have not arrived and must not light it.
			#
			# INTEL-GATED, like the Fleet window itself (FleetWindow, which
			# fogs another side's orbit behind IntelManager.IsLive). Your own
			# fleets are never fogged from you - the standing ruling - but
			# showing the opponent's for free would hand over exactly the fleet
			# positions Reconnaissance and Espionage are flown to buy.
			var orbitIsLive: bool = IntelManager.IsLive(GameSettings.PlayerFaction, planet)
			var fleetsHere: Array = Lq.where(
				Lq.where(planet.OrbitingFleets, func(f: Fleet) -> bool: return f.Status != Enums.Status.Enroute),
				func(f: Fleet) -> bool: return f.Faction == GameSettings.PlayerFaction or orbitIsLive)

			var oursInOrbit: bool = Lq.any(fleetsHere, func(f: Fleet) -> bool: return f.Faction == GameSettings.PlayerFaction)

			# OURS ON THE WAY (TeeJ, 2026-09-24: "I moved a fleet from
			# Coruscant to Yaga Minor - it did not show up until it arrived").
			# The original's sector legend names an icon for "Units Enroute to
			# System" (TEXTSTRA 0x01c54c); with none of ours in orbit, the
			# fleet corner shows it - the side's ship in hyperspace (STRATEGY
			# 11613/11614). INFERRED placement: no screenshot shows it. Only
			# our own: the opponent's inbound fleets are fog we have not
			# earned (inbound_fog).
			var inbound: Array = Lq.where(planet.OrbitingFleets, func(f: Fleet) -> bool:
				return f.Status == Enums.Status.Enroute and f.Destination == planet and f.Faction == GameSettings.PlayerFaction)

			# THE OTHER THREE CORNERS ARE CONDITIONAL TOO (TeeJ, 2026-09-23,
			# against the original's own sector window): the Manufacturing
			# icon is there only when the system has production facilities you
			# know of, the Defenses icon only when it has defenses you know of,
			# and the Mission icon only while a mission runs. In the original a
			# freshly explored enemy world shows its factory and nothing else,
			# because its garrison has not been scouted; ours drew all four on
			# every explored world, so the corners said nothing.
			#
			# "Know of" is the fogged intel, the same readers the windows use:
			# live on a world we hold, else the last sighting, else nothing.
			var viewer: Faction = GameSettings.PlayerFaction
			var hasManufacturing: bool = _KnownManufacturing(viewer, planet)
			var hasDefenses: bool = _KnownDefenses(viewer, planet)

			for i in 4:
				# Unexplored: the mission icon only. See above.
				if not planet.IsExplored and cornerLabels[i] != "M" and not (cornerLabels[i] == "F" and not inbound.is_empty()):
					continue

				# Nothing in orbit, nothing to draw.
				if cornerLabels[i] == "F" and fleetsHere.size() == 0 and inbound.is_empty():
					continue
				if cornerLabels[i] == "E" and not hasManufacturing:
					continue
				if cornerLabels[i] == "D" and not hasDefenses:
					continue
				# The mission corner: our running mission, or the uprising flame.
				var uprisingHere: bool = planet.IsExplored and IntelManager.UprisingSeen(viewer, planet)
				if cornerLabels[i] == "M" and not myMissionHere and not uprisingHere:
					continue

				# The glyph sits straight on the map like the original's; a
				# faint rounded box shows only on hover.
				var cornerStyle := StyleBoxFlat.new()
				cornerStyle.bg_color = Color(0, 0, 0, 0)
				cornerStyle.corner_radius_top_left = 4
				cornerStyle.corner_radius_top_right = 4
				cornerStyle.corner_radius_bottom_left = 4
				cornerStyle.corner_radius_bottom_right = 4

				var cornerBtn := CornerButton.new()   # takes the mouse on its drawn pixels only
				cornerBtn.set_meta("corner", cornerGlyphs[i])
				cornerBtn.icon = FactionRegistry.CornerIcon(cornerGlyphs[i])
				# The owner's side, for the original's per-side icon colours.
				var ownerSeen: Faction = IntelManager.OwnerSeen(GameSettings.LocalFaction(), planet)
				var ownerId: String = ownerSeen.Id if ownerSeen != null else "unknown"
				cornerBtn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cornerBtn.expand_icon = false
				cornerBtn.custom_minimum_size = Vector2(cornerSize, cornerSize)
				cornerBtn.size = Vector2(cornerSize, cornerSize)
				cornerBtn.position = cornerPositions[i]
				cornerBtn.flat = true   # Removes background
				# No inner padding: the glyph fills the button.
				var tight := StyleBoxEmpty.new()
				cornerBtn.add_theme_stylebox_override("focus", tight)
				_TintIcon(cornerBtn, planet.GetFactionColor())
				_OriginalIcon(cornerBtn, cornerGlyphs[i], ownerId, 1.0)

				# WHOSE fleet, not just that there is one. Fig 3.7 (manual p070)
				# puts SEPARATE Imperial and Alliance fleet icons in this
				# corner, each opening that side's Fleet window - so ownership
				# is part of what the original tells you here. One marker
				# carries it as colour for now; two markers and two windows is
				# the fuller match and would need FleetWindow to filter by
				# faction, which it does not.
				#
				# Ours wins the colour when both sides are in orbit - that is
				# the blockade case, and your own force is the one you are
				# looking for - and the tooltip names them all either way.
				if cornerLabels[i] == "F":
					var flagged: Faction = GameSettings.PlayerFaction if oursInOrbit or fleetsHere.is_empty() else fleetsHere[0].Faction

					var tint: Color = flagged.FactionColor if flagged != null else Color.GRAY
					_TintIcon(cornerBtn, tint)
					_OriginalIcon(cornerBtn, "fleet", flagged.Id if flagged != null else "unknown", 1.0)
					cornerBtn.tooltip_text = "In orbit: " + ", ".join(Lq.select(fleetsHere,
						func(f: Fleet) -> String: return "%s (%s)" % [f.Name, f.Faction.DisplayName if f.Faction != null else "unknown"]))
					# RIGHT-CLICK: the fleet command menu (TeeJ's screenshot of
					# the original's, 2026-09-24) for the side the icon shows -
					# ours when ours are here.
					var menuFleets: Array = Lq.where(fleetsHere, func(f: Fleet) -> bool: return f.Faction == flagged)
					if fleetsHere.is_empty():
						# Only ours inbound: the hyperspace icon, their arrival.
						menuFleets = inbound
						cornerBtn.set_meta("corner", "enroute")
						_TintIcon(cornerBtn, Color(GameSettings.PlayerFaction.FactionColor, 0.6))
						_OriginalIcon(cornerBtn, "enroute", GameSettings.PlayerFaction.Id, 1.0)
					if not inbound.is_empty():
						cornerBtn.tooltip_text = ((cornerBtn.tooltip_text + "
") if not fleetsHere.is_empty() else "") 							+ "En route: " + ", ".join(Lq.select(inbound, func(f: Fleet) -> String:
								return "%s (arrives day %d)" % [f.Name, StrategicTickManager.Today + f.DaysToDestination]))
					AttachFleetMenu(cornerBtn, menuFleets, planet, uiManager)

				# "A ... icon to the lower right of a planet indicates a
				# mission is in progress there" (manual p109). Lit only for
				# your own missions - seeing the opponent's operations for
				# free would give away what Espionage exists to find out.
				# Also excludes a mission aborted this frame - Finished is set
				# the instant the order is given, but the mission stays in the
				# active list until the next day tick, so the icon used to stay
				# lit on a mission that had just been called off.
				var missionHere: bool = cornerLabels[i] == "M" and myMissionHere
				if missionHere:
					# Lit in our colour while a mission runs (the corner is
					# only drawn then - see the presence rules above).
					var mine: Color = GameSettings.PlayerFaction.FactionColor
					_TintIcon(cornerBtn, mine)
					_OriginalIcon(cornerBtn, "mission", GameSettings.PlayerFaction.Id, 1.0)
				if missionHere:
					cornerBtn.tooltip_text = "Mission in progress - right-click for orders"

					# "Double-click it for the Mission window; RIGHT-CLICK IT
					# FOR THE MENU, which offers Encyclopedia, Status, and the
					# orders to ABORT OR CONTINUE the mission" (manual p109).
					# The icon was openable but carried no menu, so a mission
					# under way could not be called off from the map at all.
					AttachMissionMenu(cornerBtn, planet, uiManager)

				# ⚠ THE UPRISING MARKER, WHICH THIS MAP NEVER DREW AT ALL.
				#
				# "Systems in uprisings are identified by a FLAMING ICON AT THE
				# LOWER RIGHT of the system" (manual p091), and Fig 3.7's own
				# callout on p070 says "This icon indicates the system is in
				# uprising". The lower right is this corner - it carries the
				# mission marker OR the uprising flame.
				#
				# Nothing in this window referenced IsInUprising, so a revolt
				# was invisible on the map: the only places it surfaced were
				# the Planet window's text suffix and the GID's Uprisings mode.
				# That is what made Subdue Uprising look as though it were
				# being offered against quiet worlds - they were not quiet, and
				# there was no way to see it. Reported from play.
				#
				# Drawn OVER the mission marker when both apply, because a
				# revolt is the more urgent of the two and the manual gives it
				# the same corner. The mission menu stays attached above, so
				# Abort is still reachable on a world that is also rioting.
				#
				# ⚠ The glyph is a stand-in for the original's flame artwork,
				# in keeping with the placeholder lettering on the other three
				# corners. It is not the manual's icon.
				# Fogged: an uprising is shown only where we have SEEN one (live on a
				# world we hold, else the last sighting) - not read live off an enemy
				# world we merely explored once. IsInUprising -> IntelManager.UprisingSeen.
				if cornerLabels[i] == "M" and uprisingHere:
					cornerBtn.set_meta("corner", "uprising")
					cornerBtn.icon = FactionRegistry.CornerIcon("uprising")
					_TintIcon(cornerBtn, CUprising)
					_OriginalIcon(cornerBtn, "uprising", "", 1.0)   # the original's flame, two frames
					cornerBtn.tooltip_text = ("%s is IN UPRISING - right-click for mission orders" % planet.Name) if missionHere \
						else ("%s is IN UPRISING" % planet.Name)

				cornerBtn.add_theme_stylebox_override("normal", cornerStyle)

				# Add hover effect to highlight the corner button
				var hoverStyle: StyleBoxFlat = cornerStyle.duplicate()
				hoverStyle.bg_color = Color(1, 1, 1, 0.18)
				cornerBtn.add_theme_stylebox_override("hover", hoverStyle)
				cornerBtn.add_theme_stylebox_override("pressed", hoverStyle)
				_PlaceCorner(cornerBtn, i, finalX, finalY)

				var actionIndex: int = i
				cornerBtn.pressed.connect(func() -> void:
					# CROSSHAIRS UP: the icon is part of the system, so the click names
					# the system exactly as a click on the planet does. It opened this
					# icon's window instead (TeeJ, 2026-09-23: "it just won't choose the
					# planet").
					if uiManager.IsTargeting:
						uiManager.OnPlanetClicked(planet)
						return
					# "F", "E", "M", "D"
					if cornerLabels[actionIndex] == "D":
						uiManager.OnDefenseClicked(planet)
					elif cornerLabels[actionIndex] == "F":
						uiManager.OnFleetClicked(planet)
					elif cornerLabels[actionIndex] == "E":
						uiManager.OnEconomyClicked(planet)
					elif cornerLabels[actionIndex] == "M":   # <-- Add this
						uiManager.OnMissionClicked(planet)
					else:
						print("Opened Window type %s for %s" % [cornerLabels[actionIndex], planet.Name]))
				sectorMap.add_child(cornerBtn)

		# --- THE THREE BARS (manual p025 Fig 2.9) --- explored systems only:
		# "you'll see the familiar white/blue and yellow/red bars under the
		# system" once a Longprobe reports (p049). They sit between the lower
		# corner icons and the name, so the name moves down to make room.
		var nameY: float = finalY + 30
		var barsTop: float = finalY + BarsTop
		if original:
			barsTop = finalY + (OEnergyTop - OSprite / 2.0) * K
		if planet.IsExplored:
			nameY = barsTop + AddResourceBars(sectorMap, planet, finalX, barsTop)
		if original:
			# The original's names all sit on one line under their pictures.
			nameY = finalY + (ONameTop - OSprite / 2.0) * K

		# --- 3. PLANET NAME LABEL ---
		var nameLabel := Label.new()
		nameLabel.text = planet.Name
		nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameLabel.size = Vector2(100, 20)
		# Shift down further to clear the bottom corner buttons (20 -> 30)
		nameLabel.position = Vector2(finalX - 50, nameY)
		nameLabel.add_theme_font_size_override("font_size", 15)
		nameLabel.add_theme_color_override("font_color", nameColor)
		if original:
			# Arial 11, centred under the picture, as wide as the name (a
			# crosshair click on it names the system - see SystemAt).
			OUI.Style(nameLabel, ONamePx, nameColor)
			var nameW: float = nameLabel.get_combined_minimum_size().x
			nameLabel.size = Vector2(nameW, nameLabel.get_combined_minimum_size().y)
			nameLabel.position = Vector2(floorf(finalX - nameW / 2.0), nameY)

		sectorMap.add_child(nameLabel)

		# THE SYSTEM'S ENTRY - picture, star, corner icons, bars, name: what a
		# crosshair click anywhere on names this system (SystemAt).
		for k in range(firstPart, sectorMap.get_child_count()):
			sectorMap.get_child(k).set_meta("system", planet)

	# No system's name, bars or icons over another's (TeeJ, 2026-09-23).
	var room := Rect2(Vector2(2, 22) * K, Vector2(OW - 4, OH - 24) * K) if original else Rect2(Vector2.ZERO, mapSize)
	SeparateEntries(sectorMap, room)


## NO ENTRY OVER ANOTHER (TeeJ, 2026-09-23: "there are areas where the text
## and icons overlap, this should be avoided"). Every system sits where its
## sector coordinates put it - the original's own placement - so in a crowded
## sector one system's name or bars ran into its neighbour's icons. Where two
## entries' boxes (picture, star, corner icons, bars, name) cross, both are
## pushed apart along the shorter way out, half each, then kept inside `room`;
## repeated until nothing crosses or the room is used up. OURS, NOT THE
## ORIGINAL'S: the original lays the systems out without this.
const EntryGap := 2.0
const SeparatePasses := 60


static func SeparateEntries(sectorMap: Control, room: Rect2) -> void:
	var parts: Dictionary = {}   # Planet -> its Controls
	var order: Array = []
	for c in sectorMap.get_children():
		if not (c is Control) or c.is_queued_for_deletion() or not c.has_meta("system") or not (c as Control).visible:
			continue
		var p: Planet = c.get_meta("system")
		if not parts.has(p):
			parts[p] = []
			order.append(p)
		parts[p].append(c)
	if order.size() < 2:
		return
	var boxes: Array = []
	for p in order:
		var box := Rect2()
		var first := true
		for c: Control in parts[p]:
			var r := Rect2(c.position, c.size)
			box = r if first else box.merge(r)
			first = false
		boxes.append(box)
	var moves: Array = []
	for i in order.size():
		moves.append(Vector2.ZERO)
	for _pass in SeparatePasses:
		var moved := false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				var a: Rect2 = (boxes[i] as Rect2).grow(EntryGap / 2.0)
				var b: Rect2 = (boxes[j] as Rect2).grow(EntryGap / 2.0)
				if not a.intersects(b):
					continue
				var ox: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
				var oy: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
				var push := Vector2.ZERO
				if ox < oy:
					push.x = (ox / 2.0 + 0.5) * (1.0 if a.get_center().x <= b.get_center().x else -1.0)
				else:
					push.y = (oy / 2.0 + 0.5) * (1.0 if a.get_center().y <= b.get_center().y else -1.0)
				_ShiftEntry(boxes, moves, i, -push, room)
				_ShiftEntry(boxes, moves, j, push, room)
				moved = true
		if not moved:
			break
	for i in order.size():
		var d: Vector2 = (moves[i] as Vector2).round()
		if d == Vector2.ZERO:
			continue
		for c: Control in parts[order[i]]:
			c.position += d


## Move entry i by `by`, kept inside `room`.
static func _ShiftEntry(boxes: Array, moves: Array, i: int, by: Vector2, room: Rect2) -> void:
	var box: Rect2 = boxes[i]
	var to: Vector2 = box.position + by
	to.x = clampf(to.x, room.position.x, maxf(room.position.x, room.end.x - box.size.x))
	to.y = clampf(to.y, room.position.y, maxf(room.position.y, room.end.y - box.size.y))
	moves[i] = (moves[i] as Vector2) + (to - box.position)
	boxes[i] = Rect2(to, box.size)


## A CROSSHAIR CLICK ANYWHERE ON A SYSTEM NAMES THAT SYSTEM: "click on the
## system's icon in that system's Sector window" (manual p102 TIP), "click
## on the system where you want a new facility" (p087). The picture and the
## corner icons are buttons and answer for themselves; a click on the star,
## the bars, the name or an icon's transparent part off the picture goes
## through to the map and lands here. Blank space names nothing and the
## crosshair stays up; outside targeting this does nothing at all.
func _OnSectorMapInput(event: InputEvent) -> void:
	if _uiManager == null or not _uiManager.IsTargeting:
		return
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var planet: Planet = SystemAt(event.position)
	if planet == null:
		return
	(get_node("%SectorMap") as Control).accept_event()
	_uiManager.OnPlanetClicked(planet)


## The system with a part of its entry - picture, corner icon, star, bar row
## or name - under `at` (sector-map coordinates), or null. Where two systems'
## parts overlap there, the one whose centre is nearer wins.
func SystemAt(at: Vector2) -> Planet:
	var best: Planet = null
	var bestDist: float = INF
	var centres: Dictionary = {}   # Planet -> its picture's centre
	var under: Array = []
	for c in get_node("%SectorMap").get_children():
		if not (c is Control) or c.is_queued_for_deletion() or not c.has_meta("system"):
			continue
		var box := Rect2(c.position, c.size)
		if c is PlanetMapButton:
			centres[c.get_meta("system")] = box.get_center()
		if box.has_point(at) and not under.has(c.get_meta("system")):
			under.append(c.get_meta("system"))
	for p: Planet in under:
		var d: float = at.distance_to(centres.get(p, at))
		if d < bestDist:
			best = p
			bestDist = d
	return best


## The uprising flame's own colour (manual p091: "a flaming icon").
const CUprising := Color(1.0, 0.55, 0.12)


## WHERE A CORNER SITS: TIGHT AGAINST THE PLANET, AS THE ORIGINAL DRAWS IT
## (TeeJ, 2026-09-23: "tighter to the planet and more like the original").
##
## The original's corner bitmaps are not glyphs but QUADRANT CELLS, 27x19 or
## so, with the glyph drawn in the cell's outer corner (STRATEGY.DLL 10771-
## 10790, measured from their alpha), and the four cells tile around the
## system's centre. Measured on the original at 640x480: the factory's inner
## corner sits 15 px left of and 9 px above the centre, the tower 16 px left
## and 9 px below, the fleet 10 px right and 10 px above. So an imported cell
## is simply laid with its inner corner on the centre. Our own 16 px glyphs
## have no baked margin, so they are anchored by their inner corner at the
## same spot the original's glyphs reach: (+-15, +-9) from the centre.
##
## Either way a cell overlaps the planet's picture, so a corner takes the
## mouse only on its drawn pixels - see CornerButton.
const GlyphInnerX := 15.0
const GlyphInnerY := 9.0

## Called after the button's styleboxes are set: a Button pads its icon by
## its theme's margins, so the ICON's rectangle - not the button's - is what
## gets anchored, and the button is laid around it.
static func _PlaceCorner(btn: Button, corner: int, cx: float, cy: float) -> void:
	var left: bool = corner == 0 or corner == 2      # Top-Left, Bottom-Left
	var top: bool = corner == 0 or corner == 1       # Top-Left, Top-Right
	var icon: Vector2 = btn.icon.get_size() if btn.icon != null else btn.custom_minimum_size
	var original: bool = btn.has_meta("original_icon")
	# The icon's inner corner goes here.
	var ax: float = cx if original else (cx - GlyphInnerX if left else cx + GlyphInnerX)
	var ay: float = cy if original else (cy - GlyphInnerY if top else cy + GlyphInnerY)
	if original and OriginalLook:
		# The original's own sector window (measured on Corellian).
		ax = cx - OCellNear * K if left else cx + OCellFar * K
		ay = cy - OCellNear * K if top else cy + OCellFar * K
	btn.custom_minimum_size = icon
	var box: Vector2 = btn.get_combined_minimum_size()
	var pad: Vector2 = (box - icon).max(Vector2.ZERO) / 2.0
	btn.size = box
	btn.position = Vector2(
		(ax - icon.x - pad.x) if left else (ax - pad.x),
		(ay - icon.y - pad.y) if top else (ay - pad.y))


## The Manufacturing icon's rule: a production facility of any family you
## know of - the Manufacturing and Production window's contents (manual p084
## Fig 3.26: mines, refineries, construction yards, shipyards, training).
## Read from the fogged ProductionFacilities sighting, else the mines the
## status sighting carries (the bars' own reader), so the icon and the yellow
## squares under it never disagree.
static func _KnownManufacturing(viewer: Faction, planet: Planet) -> bool:
	var counts: Dictionary = IntelManager.SeenData(viewer, planet, Enums.IntelSection.ProductionFacilities).get("counts", {})
	for family in counts:
		if int(counts[family]) > 0:
			return true
	return int(IntelManager.StatusSeen(viewer, planet).get("mines", 0)) > 0


## The Defenses icon's rule: anything the System Defenses window would list
## (manual p126 Fig 3.73: personnel and Special Forces, troops, fighters,
## shields, batteries) that you know of.
static func _KnownDefenses(viewer: Faction, planet: Planet) -> bool:
	if not IntelManager.SeenData(viewer, planet, Enums.IntelSection.Troopers).get("regiments", []).is_empty():
		return true
	if int(IntelManager.SeenData(viewer, planet, Enums.IntelSection.Fighters).get("squadrons", 0)) > 0:
		return true
	if int(IntelManager.SeenData(viewer, planet, Enums.IntelSection.SpecForces).get("units", 0)) > 0:
		return true
	if not IntelManager.SeenData(viewer, planet, Enums.IntelSection.Characters).get("people", []).is_empty():
		return true
	var d: Dictionary = IntelManager.SeenData(viewer, planet, Enums.IntelSection.DefensiveFacilities)
	var guns: Variant = d.get("guns", [])
	return int(d.get("shields", 0)) > 0 or int(d.get("batteries", 0)) > 0 \
		or (guns is Array and not guns.is_empty())


## A corner glyph is white on alpha; the button's icon colours carry the tint,
## in every state, so hover and press do not wash it out.
static func _TintIcon(btn: Button, color: Color) -> void:
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		btn.add_theme_color_override(state, color)


## The tint a corner glyph was given (for the tests).
static func IconTint(btn: Button) -> Color:
	return btn.get_theme_color("icon_normal_color")


## THE ORIGINAL'S OWN ICON, when the player imported it: drawn in its own
## shaded colours (so no tint beyond the alpha), with the highlighted version
## on hover. Leaves the button alone when the overlay has nothing.
static func _OriginalIcon(btn: Button, glyph: String, faction_id: String, alpha: float) -> bool:
	var side: String = Faction.SkinOf(faction_id)
	var tex: Texture2D = Art.CornerIcon(glyph, side)
	if tex == null:
		return false
	var k: int = K if OriginalLook else 1
	tex = Art.Scaled(tex, k)
	btn.icon = tex
	btn.set_meta("original_icon", true)
	_TintIcon(btn, Color(1, 1, 1, alpha))
	var hover: Texture2D = Art.Scaled(Art.CornerIcon(glyph, side, true), k)
	if hover != null:
		btn.mouse_entered.connect(func() -> void: btn.icon = hover)
		btn.mouse_exited.connect(func() -> void: btn.icon = tex)
	return true


# ---- THE THREE BARS UNDER A SYSTEM (manual p025 Fig 2.9, p084 Fig 3.26) ----
#
# Row 1  energy:    white square = used slot, blue square = available slot
#                   ("each facility you build changes a blue square to white", p084)
# Row 2  materials: yellow square = built mine, red square = raw material ready
#                   to be mined (p084 NOTE; the "Raw Materials 3/9" hover of Fig 2.12)
# Row 3  loyalty:   one bar, each side's share in that side's colour ("percent
#                   loyal to the Empire (green) / to the Alliance (red)", p025)
#
# What is drawn is what this side KNOWS (IntelManager.StatusSeen: live on a
# world we hold or a Core world's support, else the last sighting) - the same
# readers the GID uses, so the map and the bars never disagree. A world with
# no population has no loyalty bar (p049: "no facilities, defenses, or
# loyalty indicators ... means the system is unpopulated").
#
# ⚠ OURS: the square size (the original's are ~5 px on a 640x480 screen), the
# slightly rounded corners (TeeJ, 2026-09-22: the sharp ones "feel too sharp")
# and the energy hover wording, mirrored from the sourced materials one.
# The sides' order on the loyalty bar is the pack's `loyalty_bar` (SCHEMA §10):
# the Star Wars pack puts the Empire on the left, as Fig 2.9 has it.
const BarsTop: float = 38.0        # clear of the lower corner icons (22 + 8, plus a gap; +2 for icons to come, TeeJ 2026-09-22)
# The rows share one LEFT edge, as Fig 2.9 and the original's sector window
# have them, so the squares line up row over row (TeeJ, 2026-09-22); the
# edge sits under the lower-left icon column.
const BarsLeft: float = 24.0       # from the planet centre to the rows' left edge
const SquareSize: float = 6.0
const SquareGap: float = 1.0
const RowGap: float = 2.0
const LoyaltyHeight: float = 4.0
const BarMinWidth: float = 30.0
const CornerRadius: int = 2
const CEnergyUsed := Color.WHITE
const CEnergyFree := Color(0.3, 0.55, 1.0)
const CMineBuilt := Color(1.0, 0.9, 0.2)
const CMineFree := Color(0.9, 0.15, 0.1)


## Draws the rows from (centerX - BarsLeft, top) and returns the height used,
## so the name label can sit under them. Rows whose figures are unknown are
## skipped.
static func AddResourceBars(sectorMap: Control, planet: Planet, centerX: float, top: float) -> float:
	var viewer: Faction = GameSettings.PlayerFaction
	var seen: Dictionary = IntelManager.StatusSeen(viewer, planet)
	if seen.is_empty():
		return 0.0
	var y: float = top
	var widest: float = BarMinWidth
	if seen.has("energy"):
		var total: int = int(seen["energy"])
		var used: int = int(seen.get("energy_used", 0))
		var tip := "%s %d/%d" % [Terms.label("energy"), used, total]
		y += _AddSquareRow(sectorMap, "energy", centerX, y, total, used, EnergyUsedColor(), EnergyFreeColor(), tip) + _RowGap()
		widest = maxf(widest, _RowWidth(total))
	if seen.has("materials"):
		var total: int = int(seen["materials"])
		var built: int = int(seen.get("mines", 0))
		var tip := "%s %d/%d" % [Terms.label("raw_materials"), built, total]
		y += _AddSquareRow(sectorMap, "materials", centerX, y, total, built, MineBuiltColor(), MineFreeColor(), tip) + _RowGap()
		widest = maxf(widest, _RowWidth(total))
	if seen.has("support") and bool(seen.get("inhabited", true)):
		y += _AddLoyaltyBar(sectorMap, centerX, y, seen["support"], widest) + _RowGap()
	return y - top


# The colours drawn: the original's in its own window, ours otherwise.
static func EnergyUsedColor() -> Color:
	return CEnergyUsed


static func EnergyFreeColor() -> Color:
	return OCEnergyFree if OriginalLook else CEnergyFree


static func MineBuiltColor() -> Color:
	return OCMineBuilt if OriginalLook else CMineBuilt


static func MineFreeColor() -> Color:
	return OCMineFree if OriginalLook else CMineFree


static func LoyaltyColor(side: Faction) -> Color:
	return OUI.SideColor(side) if OriginalLook else side.FactionColor


## Our slightly rounded blocks; the original's are square.
static func BarRadius() -> int:
	return 0 if OriginalLook else CornerRadius


# The original's sector window draws its squares 2x3 with a pixel between,
# its rows a pixel apart and one pixel in from the picture's left edge, and
# the loyalty bar 3 high across the picture's whole width, all square-cornered.
static func _SquareW() -> float:
	return 2.0 * K if OriginalLook else SquareSize


static func _SquareH() -> float:
	return 3.0 * K if OriginalLook else SquareSize


static func _SquareGap() -> float:
	return 1.0 * K if OriginalLook else SquareGap


static func _RowGap() -> float:
	return 1.0 * K if OriginalLook else RowGap


static func _RowsLeft() -> float:
	return (OSprite / 2.0 - 1.0) * K if OriginalLook else BarsLeft


static func _RowWidth(total: int) -> float:
	return maxf(0.0, total * _SquareW() + (total - 1) * _SquareGap())


## One row of `total` squares, the first `filled` in colour A, the rest in B,
## centred on centerX. Returns the row height.
static func _AddSquareRow(sectorMap: Control, kind: String, centerX: float, y: float, total: int, filled: int,
		filledColor: Color, freeColor: Color, tip: String) -> float:
	var row := Control.new()
	row.name = "Bars_%s" % kind
	row.set_meta("bar_row", kind)
	row.set_meta("total", total)
	row.set_meta("filled", filled)
	var width: float = _RowWidth(total)
	row.size = Vector2(maxf(width, 1.0), _SquareH())
	row.position = Vector2(centerX - _RowsLeft(), y)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in total:
		var sq := _Block(filledColor if i < mini(filled, total) else freeColor, Vector2(_SquareW(), _SquareH()), true, true)
		sq.position = Vector2(i * (_SquareW() + _SquareGap()), 0)
		row.add_child(sq)
	sectorMap.add_child(row)
	return _SquareH()


## One coloured block with rounded corners - on the left end, the right end,
## or both - so a bar's segments read as one rounded bar.
static func _Block(color: Color, size: Vector2, round_left: bool, round_right: bool) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var radius: int = BarRadius()
	style.corner_radius_top_left = radius if round_left else 0
	style.corner_radius_bottom_left = radius if round_left else 0
	style.corner_radius_top_right = radius if round_right else 0
	style.corner_radius_bottom_right = radius if round_right else 0
	var block := Panel.new()
	block.add_theme_stylebox_override("panel", style)
	block.size = size
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return block


## The colour a block was drawn in (for the tests).
static func BlockColor(block: Control) -> Color:
	var style: StyleBox = block.get_theme_stylebox("panel")
	return (style as StyleBoxFlat).bg_color if style is StyleBoxFlat else Color.TRANSPARENT


## The loyalty bar: one segment per playable side, in that side's colour,
## its width the side's share of the population. Returns the bar height.
## `width` is the widest square row above it, so the three read as a block.
static func _AddLoyaltyBar(sectorMap: Control, centerX: float, y: float, support: Dictionary, width: float) -> float:
	var sides: Array[Faction] = FactionRegistry.LoyaltyBarOrder()
	var bar := Control.new()
	bar.name = "Bars_loyalty"
	bar.set_meta("bar_row", "loyalty")
	bar.set_meta("support", support.duplicate())
	var height: float = LoyaltyHeight
	bar.position = Vector2(centerX - BarsLeft, y)
	if OriginalLook:
		width = OSprite * K
		height = 3.0 * K
		bar.position = Vector2(centerX - OSprite / 2.0 * K, y)
	bar.size = Vector2(width, height)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var words: PackedStringArray = PackedStringArray()
	var x: float = 0.0
	var drawn: int = 0
	var to_draw: int = 0
	for side in sides:
		if int(support.get(side.Id, 0)) > 0:
			to_draw += 1
	for side in sides:
		var pct: int = int(support.get(side.Id, 0))
		words.append("%s %d%%" % [side.DisplayName, pct])
		var w: float = width * pct / 100.0
		if w <= 0.0:
			continue
		var seg := _Block(LoyaltyColor(side), Vector2(w, height), drawn == 0, drawn == to_draw - 1)
		seg.position = Vector2(x, 0)
		bar.add_child(seg)
		x += w
		drawn += 1
	bar.tooltip_text = "Loyalty: %s" % ", ".join(words)
	sectorMap.add_child(bar)
	return height


# The mission icon's right-click menu (manual p109, fig 3.50).
#
# Abort is listed once per mission, because "there may be more than one
# mission on a given system" (p109) and an order has to name its target.
# Each is disabled while its team is in hyperspace - "you cannot give orders
# to units in hyperspace; you must wait until they reach their destination"
# (p109), which is why the original greys the order out rather than dropping it.
## The fleet icon's right-click menu (FleetWindow.FleetMenu): Move,
## Confirmed Move, Planetary Bombardment, Planetary Assault, Encyclopedia,
## Status, Scrap for our fleets here; Encyclopedia and Status for theirs.
static func AttachFleetMenu(icon: Button, fleets: Array, planet: Planet, uiManager: UIManager) -> void:
	icon.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_RIGHT:
			return
		if uiManager.IsTargeting:
			uiManager.CancelTargeting()
			return
		var popup: PopupMenu = FleetWindow.FleetMenu(fleets, planet, uiManager, false, func() -> void: pass)
		icon.add_child(popup)
		popup.popup_hide.connect(popup.queue_free)
		popup.position = Vector2i(int(e.global_position.x), int(e.global_position.y))
		popup.popup()
		icon.accept_event())


static func AttachMissionMenu(icon: Button, planet: Planet, uiManager: UIManager) -> void:
	icon.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_RIGHT:
			return

		var mine: Array = Lq.where(MissionManager.Active(),
			func(m: Mission) -> bool: return m.Target == planet and m.Faction == GameSettings.PlayerFaction and not m.Finished)
		if mine.size() == 0:
			return

		var popup := PopupMenu.new()
		popup.add_item("Status", 0)

		# Present because the original's menu has it, disabled because no
		# Encyclopedia window exists yet - a visible gap beats a dead click.
		popup.add_item("Encyclopedia", 1)

		popup.add_separator()
		for m in mine.size():
			var mission: Mission = mine[m]
			var id: int = 100 + m
			popup.add_item("Abort %s" % mission.DisplayName(), id)
			if not mission.Arrived():
				var idx: int = popup.get_item_index(id)
				popup.set_item_disabled(idx, true)
				popup.set_item_tooltip(idx, "%s - %dd out. Orders cannot be given in transit." % [Terms.cap("in_transit"), mission.DaysToTarget])

		icon.add_child(popup)
		popup.position = Vector2i(int(e.global_position.x), int(e.global_position.y))
		popup.popup()
		popup.id_pressed.connect(func(id: int) -> void:
			if id == 0:
				uiManager.OnMissionClicked(planet)
			elif id == 1:   # Encyclopedia - the running mission's entry (manual p109)
				var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(mine[0].Type) if not mine.is_empty() else null
				if d != null:
					uiManager.OpenEncyclopedia("missions", d.Id)
				else:
					uiManager.OpenEncyclopedia()
			elif id >= 100 and id - 100 < mine.size():
				CommandBus.issue("abort_mission", { "mission": mine[id - 100].Serial }))
		icon.accept_event())


# The GID marker as the sector window draws it: lower left of the system,
# just inboard of the Defenses icon, matching Fig 2.8's tower-then-star pair.
static func AddGidStar(sectorMap: Control, planet: Planet, centerX: float, centerY: float) -> void:
	var mode: Gid.GidMode = Gid.ActiveMode()

	# "Display Off" is a real mode - the strategic view with no overlay.
	if mode == null or mode == Gid.DisplayOff:
		return

	var size: int
	var color: Color
	if not mode.Reveal.call(planet):
		# Unexplored: the grey marker, exactly as the galaxy map shows it.
		size = 16
		color = Gid.CUnexplored()
	else:
		var tier: Gid.GidTier = mode.TierFor(mode.Magnitude.call(planet))
		size = tier.FlareSize
		color = Gid.FactionColor(planet)

	# A tier with no flare means "none of this here" - draw nothing at all,
	# which is what makes the star meaningful when it IS present.
	if size <= 0:
		return

	var scaled: int = maxi(Gid.SectorFlareMin, roundi(size * Gid.SectorFlareScale))
	color.a = 1.0

	# The original's star bitmap, at its own size, when the player imported it.
	var known: bool = mode.Reveal.call(planet)
	var tierName: String = Gid.FlareName(mode.TierFor(mode.Magnitude.call(planet)).FlareSize) if known else "none"
	var starTex: Texture2D = Art.GidStar(Gid.StarSide(planet, known), tierName)
	if starTex != null:
		var pic := TextureRect.new()
		pic.texture = starTex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_meta("gid_star", true)
		pic.size = starTex.get_size()
		pic.position = Vector2(centerX - StarOffsetX - pic.size.x / 2.0, centerY + StarOffsetY - pic.size.y / 2.0)
		if OriginalLook:
			# The original's sector window: drawn K times, under the
			# picture's lower left (measured on Corellian).
			pic.texture = Art.Scaled(starTex, K)
			pic.size = pic.texture.get_size()
			pic.position = Vector2(centerX, centerY) + (OStar - Vector2(OSprite, OSprite) / 2.0) * K
		pic.tooltip_text = "%s: %s" % [Gid.TitleFor(mode), mode.TierFor(mode.Magnitude.call(planet)).LabelText]
		sectorMap.add_child(pic)
		return

	var star := Label.new()
	star.text = "+"
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Never eat a click meant for the planet or its corner icons.
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size = Vector2(scaled * 2, scaled * 2)
	star.position = Vector2(centerX - StarOffsetX - scaled, centerY + StarOffsetY - scaled)
	star.tooltip_text = "%s: %s" % [Gid.TitleFor(mode), mode.TierFor(mode.Magnitude.call(planet)).LabelText]
	star.add_theme_font_size_override("font_size", scaled)
	star.add_theme_color_override("font_color", color)
	sectorMap.add_child(star)


# Offsets from the planet centre. The Defenses icon sits 22px down and 22px
# left; the star sits inboard of it, as the figure shows.
const StarOffsetX: float = 6.0
const StarOffsetY: float = 24.0


## A CORNER ICON TAKES THE MOUSE ONLY ON ITS DRAWN PIXELS.
##
## The original's Manufacturing, Fleet, Defenses and Mission icons are
## quadrant cells whose glyph sits in the cell's outer corner - 48 to 90 of
## some 500 pixels drawn - and the transparent rest lies over the planet's
## picture (_PlaceCorner); the uprising flame is drawn edge to edge, so all
## of it answers. As a plain Button the whole cell took the mouse, so a
## click, a hover or a drop meant for the planet landed on an icon: it
## opened the icon's window, lit the icon, and refused a character dragged
## onto the system. Our own glyphs' buttons are padded past the glyph and
## clip the picture's edge the same way.
##
## This is the test a TextureButton's click mask makes - the picture's alpha,
## BitMap.create_from_image_alpha - made here because the corners are
## Buttons, which carry the tint and the hover picture as their icon. It
## reads the picture showing NOW, so the original's hover picture, which
## adds an outline to the glyph, answers on the outline while it is lit.
## Anywhere else the point falls through to what is under it: the planet,
## or the sector map. The mouse-over test is the same one, so the hover
## follows the drawn pixels too.
class CornerButton extends Button:
	## BitMap.create_from_image_alpha's own default.
	const AlphaThreshold := 0.1
	## Texture instance id -> BitMap of its drawn pixels, or null when the
	## picture has no image to read (then the whole button answers, as before).
	static var _masks: Dictionary = {}

	func _has_point(point: Vector2) -> bool:
		var mask: BitMap = MaskFor(icon)
		if mask == null:
			return Rect2(Vector2.ZERO, size).has_point(point)
		# Where a Button draws its icon with no text, expand_icon off and no
		# stylebox margins (the corners' own): at its own size, centred, floored.
		var drawn: Vector2 = icon.get_size()
		var at: Vector2 = point - ((size - drawn) / 2.0).floor()
		if at.x < 0.0 or at.y < 0.0 or at.x >= drawn.x or at.y >= drawn.y:
			return false
		# Scaled like the picture, should it ever be drawn at another size.
		var bits: Vector2i = mask.get_size()
		return mask.get_bit(int(at.x * bits.x / drawn.x), int(at.y * bits.y / drawn.y))

	## The picture's drawn pixels, read once per picture.
	static func MaskFor(tex: Texture2D) -> BitMap:
		if tex == null:
			return null
		var key: int = tex.get_instance_id()
		if _masks.has(key):
			return _masks[key]
		var mask: BitMap = null
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			mask = BitMap.new()
			mask.create_from_image_alpha(img, AlphaThreshold)
		_masks[key] = mask
		return mask


## C#: public partial class PlanetMapButton : Button - a top-level class in
## SectorWindow.cs, referenced nowhere else, so it lives here as an inner class.
class PlanetMapButton extends Button:
	var AssociatedPlanet: Planet
	var UIManagerRef: UIManager

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var dragType: String = str(data)

		# Allow drops for Characters, Units, & Fleets
		# (the port's drag lists are [] when idle where the C# ones are null)
		return (dragType == "character_move" and UIManagerRef != null and not UIManagerRef.DraggedCharacters.is_empty()) \
			or (dragType == "unit_move" and UIManagerRef != null and not UIManagerRef.DraggedUnits.is_empty()) \
			or (dragType == "fleet_move" and UIManagerRef != null and not UIManagerRef.DraggedFleets.is_empty())

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if UIManagerRef == null or AssociatedPlanet == null:
			return

		var dragType: String = str(data)

		# Route Characters
		if dragType == "character_move" and not UIManagerRef.DraggedCharacters.is_empty():
			var dragGroup: Array = UIManagerRef.DraggedCharacters
			UIManagerRef.EndCharacterDrag()   # Clean up global reference
			UIManagerRef.ExecuteCharacterMove(dragGroup, AssociatedPlanet, false)
		# Route Loose Units (Troops / Fighters)
		elif dragType == "unit_move" and not UIManagerRef.DraggedUnits.is_empty():
			var dragGroup: Array = UIManagerRef.DraggedUnits
			UIManagerRef.EndUnitDrag()
			UIManagerRef.ExecuteUnitMove(dragGroup, AssociatedPlanet, false)
		# Route Whole Fleets
		elif dragType == "fleet_move" and not UIManagerRef.DraggedFleets.is_empty():
			var dragGroup: Array = UIManagerRef.DraggedFleets
			UIManagerRef.EndFleetDrag()
			UIManagerRef.ExecuteFleetMove(dragGroup, AssociatedPlanet, false)
