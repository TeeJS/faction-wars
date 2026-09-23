class_name SectorWindow
extends DraggableWindow
## frontend/SectorWindow.cs - the Sector window (manual p025, Fig 2.8): every
## system in the sector, its four corner icons, and the mirrored GID star.

var _sector: Sector



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

	sectorMap.custom_minimum_size = mapSize

	# Slightly increased padding to make room for text at the bottom edges
	var padding: float = 60.0
	# The three bars and the name below the lowest system need more room
	# under it than the top row needs above it (BarsTop + the bars + the name).
	var paddingBottom: float = 92.0
	var usableWidth: float = mapSize.x - (padding * 2)
	var usableHeight: float = mapSize.y - padding - paddingBottom

	for planet in sector.Planets:
		var normalizedX: float = (planet.MapX - minX) / sectorWidth
		var normalizedY: float = (planet.MapY - minY) / sectorHeight

		var finalX: float = padding + (normalizedX * usableWidth)
		var finalY: float = padding + (normalizedY * usableHeight)

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
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(0, 0, 0, 0)
			ring.set_corner_radius_all(16)
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

		if planet.IsExplored or myMissionHere:
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

			for i in 4:
				# Unexplored: the mission icon only. See above.
				if not planet.IsExplored and cornerLabels[i] != "M":
					continue

				# Nothing in orbit, nothing to draw.
				if cornerLabels[i] == "F" and fleetsHere.size() == 0:
					continue

				# The glyph sits straight on the map like the original's; a
				# faint rounded box shows only on hover.
				var cornerStyle := StyleBoxFlat.new()
				cornerStyle.bg_color = Color(0, 0, 0, 0)
				cornerStyle.corner_radius_top_left = 4
				cornerStyle.corner_radius_top_right = 4
				cornerStyle.corner_radius_bottom_left = 4
				cornerStyle.corner_radius_bottom_right = 4

				var cornerBtn := Button.new()
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
				# No inner padding: a 16 px glyph in a 16 px button.
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
					var flagged: Faction = GameSettings.PlayerFaction if oursInOrbit else fleetsHere[0].Faction

					var tint: Color = flagged.FactionColor if flagged != null else Color.GRAY
					_TintIcon(cornerBtn, tint)
					_OriginalIcon(cornerBtn, "fleet", flagged.Id if flagged != null else "unknown", 1.0)
					cornerBtn.tooltip_text = "In orbit: " + ", ".join(Lq.select(fleetsHere,
						func(f: Fleet) -> String: return "%s (%s)" % [f.Name, f.Faction.DisplayName if f.Faction != null else "unknown"]))

				# "A ... icon to the lower right of a planet indicates a
				# mission is in progress there" (manual p109). Lit only for
				# your own missions - seeing the opponent's operations for
				# free would give away what Espionage exists to find out.
				# Also excludes a mission aborted this frame - Finished is set
				# the instant the order is given, but the mission stays in the
				# active list until the next day tick, so the icon used to stay
				# lit on a mission that had just been called off.
				var missionHere: bool = cornerLabels[i] == "M" and myMissionHere
				if cornerLabels[i] == "M":
					# Lit in our colour while a mission runs, faint otherwise -
					# the corner is still the way to the Mission window.
					var mine: Color = GameSettings.PlayerFaction.FactionColor
					_TintIcon(cornerBtn, mine if missionHere else Color(mine.r, mine.g, mine.b, 0.35))
					_OriginalIcon(cornerBtn, "mission", GameSettings.PlayerFaction.Id, 1.0 if missionHere else 0.35)
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
				if cornerLabels[i] == "M" and planet.IsExplored and IntelManager.UprisingSeen(GameSettings.PlayerFaction, planet):
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

				var actionIndex: int = i
				cornerBtn.pressed.connect(func() -> void:
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
		if planet.IsExplored:
			nameY = finalY + BarsTop + AddResourceBars(sectorMap, planet, finalX, finalY + BarsTop)

		# --- 3. PLANET NAME LABEL ---
		var nameLabel := Label.new()
		nameLabel.text = planet.Name
		nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameLabel.size = Vector2(100, 20)
		# Shift down further to clear the bottom corner buttons (20 -> 30)
		nameLabel.position = Vector2(finalX - 50, nameY)
		nameLabel.add_theme_font_size_override("font_size", 15)
		nameLabel.add_theme_color_override("font_color", nameColor)

		sectorMap.add_child(nameLabel)


## The uprising flame's own colour (manual p091: "a flaming icon").
const CUprising := Color(1.0, 0.55, 0.12)


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
	var tex: Texture2D = Art.CornerIcon(glyph, faction_id)
	if tex == null:
		return false
	btn.icon = tex
	btn.set_meta("original_icon", true)
	_TintIcon(btn, Color(1, 1, 1, alpha))
	var hover: Texture2D = Art.CornerIcon(glyph, faction_id, true)
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
		y += _AddSquareRow(sectorMap, "energy", centerX, y, total, used, CEnergyUsed, CEnergyFree, tip) + RowGap
		widest = maxf(widest, _RowWidth(total))
	if seen.has("materials"):
		var total: int = int(seen["materials"])
		var built: int = int(seen.get("mines", 0))
		var tip := "%s %d/%d" % [Terms.label("raw_materials"), built, total]
		y += _AddSquareRow(sectorMap, "materials", centerX, y, total, built, CMineBuilt, CMineFree, tip) + RowGap
		widest = maxf(widest, _RowWidth(total))
	if seen.has("support") and bool(seen.get("inhabited", true)):
		y += _AddLoyaltyBar(sectorMap, centerX, y, seen["support"], widest) + RowGap
	return y - top


static func _RowWidth(total: int) -> float:
	return maxf(0.0, total * SquareSize + (total - 1) * SquareGap)


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
	row.size = Vector2(maxf(width, 1.0), SquareSize)
	row.position = Vector2(centerX - BarsLeft, y)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in total:
		var sq := _Block(filledColor if i < mini(filled, total) else freeColor, Vector2(SquareSize, SquareSize), true, true)
		sq.position = Vector2(i * (SquareSize + SquareGap), 0)
		row.add_child(sq)
	sectorMap.add_child(row)
	return SquareSize


## One coloured block with rounded corners - on the left end, the right end,
## or both - so a bar's segments read as one rounded bar.
static func _Block(color: Color, size: Vector2, round_left: bool, round_right: bool) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = CornerRadius if round_left else 0
	style.corner_radius_bottom_left = CornerRadius if round_left else 0
	style.corner_radius_top_right = CornerRadius if round_right else 0
	style.corner_radius_bottom_right = CornerRadius if round_right else 0
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
	bar.size = Vector2(width, LoyaltyHeight)
	bar.position = Vector2(centerX - BarsLeft, y)
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
		var seg := _Block(side.FactionColor, Vector2(w, LoyaltyHeight), drawn == 0, drawn == to_draw - 1)
		seg.position = Vector2(x, 0)
		bar.add_child(seg)
		x += w
		drawn += 1
	bar.tooltip_text = "Loyalty: %s" % ", ".join(words)
	sectorMap.add_child(bar)
	return LoyaltyHeight


# The mission icon's right-click menu (manual p109, fig 3.50).
#
# Abort is listed once per mission, because "there may be more than one
# mission on a given system" (p109) and an order has to name its target.
# Each is disabled while its team is in hyperspace - "you cannot give orders
# to units in hyperspace; you must wait until they reach their destination"
# (p109), which is why the original greys the order out rather than dropping it.
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
