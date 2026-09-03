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
	var usableWidth: float = mapSize.x - (padding * 2)
	var usableHeight: float = mapSize.y - (padding * 2)

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

			var cornerLabels: Array[String] = ["E", "F", "D", "M"]   # Placeholders: Fleet, Economy, Missions, Defense, etc.

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

				var cornerStyle := StyleBoxFlat.new()
				cornerStyle.bg_color = Color(0.2, 0.2, 0.2, 0.9)   # Dark gray background
				cornerStyle.corner_radius_top_left = 8
				cornerStyle.corner_radius_top_right = 8
				cornerStyle.corner_radius_bottom_left = 8
				cornerStyle.corner_radius_bottom_right = 8

				var cornerBtn := Button.new()
				cornerBtn.text = cornerLabels[i]
				cornerBtn.custom_minimum_size = Vector2(cornerSize, cornerSize)
				cornerBtn.size = Vector2(cornerSize, cornerSize)
				cornerBtn.position = cornerPositions[i]
				cornerBtn.flat = true   # Removes background

				cornerBtn.add_theme_font_size_override("font_size", 10)
				cornerBtn.add_theme_color_override("font_color", planet.GetFactionColor())

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
					cornerStyle.bg_color = Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55, 1.0)
					cornerBtn.add_theme_color_override("font_color", Color.WHITE)
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
				if missionHere:
					cornerStyle.bg_color = Color(0.55, 0.45, 0.05, 1.0)
					cornerBtn.add_theme_color_override("font_color", Color.WHITE)
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
				if cornerLabels[i] == "M" and planet.IsExplored and planet.IsInUprising:
					cornerBtn.text = "▲"
					cornerStyle.bg_color = Color(0.72, 0.18, 0.05, 1.0)
					cornerBtn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
					cornerBtn.tooltip_text = ("%s is IN UPRISING - right-click for mission orders" % planet.Name) if missionHere \
						else ("%s is IN UPRISING" % planet.Name)

				cornerBtn.add_theme_stylebox_override("normal", cornerStyle)

				# Add hover effect to highlight the corner button
				var hoverStyle: StyleBoxFlat = cornerStyle.duplicate()
				hoverStyle.bg_color = Color(0.4, 0.4, 0.4, 1.0)
				cornerBtn.add_theme_stylebox_override("hover", hoverStyle)

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

		# --- 3. PLANET NAME LABEL ---
		var nameLabel := Label.new()
		nameLabel.text = planet.Name
		nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameLabel.size = Vector2(100, 20)
		# Shift down further to clear the bottom corner buttons (20 -> 30)
		nameLabel.position = Vector2(finalX - 50, finalY + 30)
		nameLabel.add_theme_font_size_override("font_size", 15)
		nameLabel.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))

		sectorMap.add_child(nameLabel)


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
		popup.set_item_disabled(popup.get_item_index(1), true)

		popup.add_separator()
		for m in mine.size():
			var mission: Mission = mine[m]
			var id: int = 100 + m
			popup.add_item("Abort %s" % mission.DisplayName(), id)
			if not mission.Arrived():
				var idx: int = popup.get_item_index(id)
				popup.set_item_disabled(idx, true)
				popup.set_item_tooltip(idx, "In hyperspace - %dd out. Orders cannot be given in transit." % mission.DaysToTarget)

		icon.add_child(popup)
		popup.position = Vector2i(int(e.global_position.x), int(e.global_position.y))
		popup.popup()
		popup.id_pressed.connect(func(id: int) -> void:
			if id == 0:
				uiManager.OnMissionClicked(planet)
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
