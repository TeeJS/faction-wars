class_name FleetWindow
extends DraggableWindow
## frontend/FleetWindow.cs - the System Fleets window: fleets on the left, the
## selected fleet's Capital Ships / Fighters / Troops / Personnel tabs on the
## right (manual p112-p113), with the fleet and ship command menus (p111, p115).

var _associatedPlanet: Planet

# Tracking selected items separately by category
var SelectedFleets: Array = []
var SelectedCapitalShips: Array = []
var SelectedFighters: Array = []
var SelectedTroops: Array = []


func Populate(planet: Planet, uiManager: UIManager) -> void:
	_uiManager = uiManager
	_associatedPlanet = planet
	var titleBarLabel: Label = get_node("%TitleBarLabel")
	var tabs: TabContainer = get_node("%FleetTabs")
	var fleetList: VBoxContainer = get_node("%FleetList")
	var selectedFleetName: Label = get_node("%SelectedFleetName")

	titleBarLabel.text = " %s System Fleets" % planet.Name

	# Clear existing fleet buttons on the left
	for child in fleetList.get_children():
		child.queue_free()

	# Ships in orbit are MILITARY UNITS - the game's own family range
	# [0x10,0x20) - so a Reconnaissance or an Espionage snapshot covers them
	# and nothing else does. Somebody else's orbit shows what you last saw
	# of it, IN THE WINDOW'S OWN LAYOUT: fleets on the left, their ships in
	# the tabs (manual p112-p113), because remembered state renders in the
	# normal display (p069/p071). This used to flatten the snapshot into
	# "Ship (Fleet)" text lines under the fleets header, beside live-view
	# boilerplate the cleared tabs had left behind - so on Svivren a
	# remembered Medium Transport read as a fleet holding no capital ships.
	#
	# Lookable, not commandable: the rows open the remembered contents and
	# carry no menu, no selection and no targeting hook - those ships take
	# no orders from you.
	if not IntelManager.IsLive(GameSettings.PlayerFaction, planet):
		var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet,
			Enums.IntelSection.OrbitingShips)
		ClearFleetContents()

		# ⚠ YOUR OWN FLEETS ARE NEVER FOGGED FROM YOU - the standing
		# ruling, met here for the fourth time. Transit files a fleet
		# under its DESTINATION the moment it departs, so a fleet sent to
		# a world you do not control vanished: gone from the origin's
		# window, and invisible here because this branch drew only the
		# snapshot. Reported from play: Coruscant to Chandrila. The same
		# hole hid a fleet ARRIVED over a neutral or enemy world - a
		# blockade invisible to its own commander.
		#
		# Fully interactive, unlike everything else in this branch: these
		# are the player's own ships, and the menus mean something.
		var mine: Array = Lq.where(
			Lq.where(planet.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == GameSettings.PlayerFaction),
			func(f: Fleet) -> bool: return f.Status != Enums.Status.Enroute or f.Destination == planet)

		for fleet in mine:
			AddFleetToList(fleet, fleetList, _uiManager)

		if not view.Known and mine.size() == 0:
			selectedFleetName.text = "Sensors detect no data..."
			return

		if view.Groups.size() == 0 and mine.size() == 0:
			# The same voice as the live branch: the snapshot says the
			# orbit was empty.
			selectedFleetName.text = "No fleets detected in orbit."
			return

		selectedFleetName.text = "Select a fleet to view its composition"

		for g in view.Groups:
			var captured: IntelManager.IntelGroup = g
			var row := Button.new()
			row.text = g.Name
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.flat = true
			row.pressed.connect(func() -> void: DisplayRememberedFleet(captured))
			fleetList.add_child(row)

		# As the live branch does: show the first one - yours first.
		if mine.size() > 0:
			DisplayFleetContents(mine[0])
		else:
			DisplayRememberedFleet(view.Groups[0])
		return

	var orbitingFleets: Array = Lq.where(planet.OrbitingFleets,
		func(f: Fleet) -> bool: return f.Status != Enums.Status.Enroute or f.Destination == planet)

	if orbitingFleets.size() == 0:
		selectedFleetName.text = "No fleets detected in orbit."
		ClearFleetContents()
		return

	selectedFleetName.text = "Select a fleet to view its composition"

	for fleet in orbitingFleets:
		AddFleetToList(fleet, fleetList, _uiManager)

	# Automatically display the first fleet's contents
	if orbitingFleets.size() > 0:
		DisplayFleetContents(orbitingFleets[0])


func AddFleetToList(fleet: Fleet, list: VBoxContainer, uiManager: UIManager) -> void:
	# Same on the fleet's own row - the whole fleet is what is travelling.
	var fleetLabel: String = fleet.Name
	if fleet.Status == Enums.Status.Enroute and fleet.DaysToDestination > 0:
		fleetLabel += " (Enroute - arrives Day %d)" % (StrategicTickManager.Today + fleet.DaysToDestination)

	# CLIPPED, NOT EXPANDING. A Button reports its full text width as its
	# minimum size, so a long fleet name - and the "(Enroute - arrives Day
	# NNN)" suffix above is long - dragged the whole left column wider and
	# took that width straight out of the tab strip beside it. Reported from
	# play: "Galactic Empire Fleet_6c74" left room for Troops and Personnel
	# only, with Capital Ships and Fighters behind the overflow arrows.
	# Clipping pins the column at its 200px minimum; the tooltip keeps the
	# full name reachable.
	var fleetButton := FleetButton.new()
	fleetButton.text = fleetLabel
	fleetButton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fleetButton.clip_text = true
	fleetButton.tooltip_text = fleetLabel
	fleetButton.UnitData = fleet
	fleetButton.UIManagerRef = uiManager
	fleetButton.ParentWindow = self
	fleetButton.toggle_mode = true

	if SelectedFleets.has(fleet):
		fleetButton.button_pressed = true

	fleetButton.toggled.connect(func(isPressed: bool) -> void:
		# CROSSHAIRS UP: the click is picking a TARGET. Every other row in
		# this window resolved itself - the SHIP rows have carried this
		# hook all along - but the fleet row only selected itself, so a
		# player told to "move onto the fleet" clicked the fleet and
		# nothing happened at all. "Characters can also be moved by
		# dragging the icon onto a system OR FLEET" (manual p110), and the
		# crosshair is the same order as the drag.
		if uiManager.IsTargetingObject():
			fleetButton.set_pressed_no_signal(SelectedFleets.has(fleet))
			uiManager.ResolveObjectTarget(fleet)
			return

		if isPressed:
			if not SelectedFleets.has(fleet):
				SelectedFleets.append(fleet)
			# When toggled on, immediately show its contents in the right panel!
			DisplayFleetContents(fleet)
		else:
			SelectedFleets.erase(fleet))

	# BUILT ONCE, AS A CHILD OF THE BUTTON - the way the ship rows do it.
	#
	# This used to construct a fresh PopupMenu on every right-click and never
	# parent it to anything. A PopupMenu that is not in the scene tree cannot
	# be displayed, so Show() did nothing and the fleet appeared to have no
	# menu at all, while the ships inside it - whose menus ARE parented to
	# their buttons - worked fine. It also leaked one menu per click.
	var fleetMenu: PopupMenu = BuildFleetContextMenu(fleet, uiManager)
	fleetButton.add_child(fleetMenu)
	RegisterPopupMenu(fleetMenu)

	fleetButton.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if uiManager.IsTargeting:
				uiManager.CancelTargeting()
			else:
				fleetMenu.position = Vector2i(int(event.global_position.x),
											  int(event.global_position.y))
				fleetMenu.popup()

			fleetButton.accept_event())

	list.add_child(fleetButton)


# --- Dive into the Fleet and populate the Tabs! ---
func DisplayFleetContents(fleet: Fleet) -> void:
	get_node("%SelectedFleetName").text = fleet.Name
	var tabs: TabContainer = get_node("%FleetTabs")

	var capitalShipsTab: MarginContainer = tabs.get_node_or_null("Capital Ships")
	var fightersTab: MarginContainer = tabs.get_node_or_null("Fighters")
	var troopsTab: MarginContainer = tabs.get_node_or_null("Troops")
	var personnelTab: MarginContainer = tabs.get_node_or_null("Personnel")

	var capShips: Array = Lq.where(fleet.Ships, func(u: Unit) -> bool: return u.Type == Enums.UnitType.CapitalShip)
	var fighters: Array = []
	var troops: Array = []

	# Extract the nested Hangar payloads!
	for ship in capShips:
		if ship.Hangar != null:
			fighters.append_array(Lq.where(ship.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Fighter))
			troops.append_array(Lq.where(ship.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop or u.Type == Enums.UnitType.SpecForce))

	# Also grab any loose units in the fleet root just in case
	fighters.append_array(Lq.where(fleet.Ships, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Fighter))
	troops.append_array(Lq.where(fleet.Ships, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop or u.Type == Enums.UnitType.SpecForce))

	if capitalShipsTab != null:
		PopulateUnitTab(capitalShipsTab, capShips, "No capital ships in this fleet.", SelectedCapitalShips)
	if fightersTab != null:
		PopulateUnitTab(fightersTab, fighters, "No fighter squadrons in this fleet.", SelectedFighters)
	if troopsTab != null:
		PopulateUnitTab(troopsTab, troops, "No regiments attached.", SelectedTroops)

	# For personnel, safely query the GameManager
	if personnelTab != null:
		for child in personnelTab.get_children():
			child.queue_free()
		var pList := VBoxContainer.new()
		personnelTab.add_child(pList)

		# Characters are attached directly to the Fleet (Location), so check for direct equality!
		var personnel: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == fleet)

		if personnel.size() == 0:
			var empty := Label.new()
			empty.text = "No characters commanding."
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", Color.GRAY)
			pList.add_child(empty)
		else:
			# THE SAME MENU EVERY OTHER CHARACTER GETS. This block used to
			# build its own row carrying ONLY the Command submenu - the
			# comment that stood here explained that a fleet is the only
			# place an Admiral can be posted (manual p095), which is true,
			# and then stopped. Move, Confirmed Move, Mission, Encyclopedia,
			# Status and Retire were never added, so a character posted to a
			# fleet could be given a rank and no other order at all.
			#
			# DrawCharacterRow is on the shared base now, so the fleet's
			# people and a world's people are drawn by one builder and this
			# cannot drift apart again.
			for p in personnel:
				DrawCharacterRow(pList, p, _uiManager)


# A remembered fleet's contents, in the same tabs the live view uses.
# Capital Ships carries what the snapshot holds; the other three tabs say
# so plainly when the snapshot cannot know - it captures a fleet's ships,
# not their hangars or the people aboard.
func DisplayRememberedFleet(fleet: IntelManager.IntelGroup) -> void:
	get_node("%SelectedFleetName").text = fleet.Name
	var tabs: TabContainer = get_node("%FleetTabs")

	FillTabWithText(tabs.get_node_or_null("Capital Ships"),
					fleet.Lines, "No capital ships were seen.")

	for other in ["Fighters", "Troops", "Personnel"]:
		FillTabWithText(tabs.get_node_or_null(other),
						null, "Sensors detect no data.")


static func FillTabWithText(tab: MarginContainer,
							lines: Variant, emptyText: String) -> void:
	if tab == null:
		return
	for child in tab.get_children():
		child.queue_free()

	var list := VBoxContainer.new()
	tab.add_child(list)

	var any: bool = false
	for line in (lines if lines != null else []):
		any = true
		var row := Label.new()
		row.text = line
		row.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		list.add_child(row)

	if not any:
		var empty := Label.new()
		empty.text = emptyText
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(empty)


func ClearFleetContents() -> void:
	var tabs: TabContainer = get_node("%FleetTabs")
	for tab in tabs.get_children():
		for child in tab.get_children():
			if child is VBoxContainer:
				child.queue_free()


# --- Universal Sub-Unit Tab Builder ---
func PopulateUnitTab(tab: MarginContainer, units: Array, emptyText: String, selectionList: Array) -> void:
	for child in tab.get_children():
		child.queue_free()

	var list := VBoxContainer.new()
	tab.add_child(list)

	if units == null or units.size() == 0:
		var empty := Label.new()
		empty.text = emptyText
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(empty)
		return

	for unit in units:
		var nameColor: Color = unit.Faction.FactionColor if unit.Faction != null else Color.WHITE
		var displayText: String = unit.Name

		# WHEN IT GETS THERE, not just that it is going. The original's Fleet
		# Status window reports "ETA Destination: Day N" outright, and a row
		# that only says "(Enroute)" leaves the player with no idea whether
		# that means tomorrow or in two months.
		if unit.Status == Enums.Status.Enroute:
			displayText += (" (Enroute - arrives Day %d)" % (StrategicTickManager.Today + unit.DaysToDestination)) \
				if unit.DaysToDestination > 0 else " (Enroute)"
			nameColor = Color.DARK_GRAY

		var unitBtn := FleetUnitMenuButton.new()
		unitBtn.text = displayText
		unitBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		unitBtn.UnitData = unit
		unitBtn.UIManagerRef = _uiManager
		unitBtn.ParentWindow = self
		unitBtn.SelectionGroup = selectionList
		unitBtn.toggle_mode = true

		if selectionList.has(unit):
			unitBtn.button_pressed = true

		unitBtn.add_theme_color_override("font_color", nameColor)
		unitBtn.add_theme_font_size_override("font_size", 16)

		unitBtn.toggled.connect(func(isPressed: bool) -> void:
			# A capital ship is a legal sabotage target (manual p108), so
			# while the crosshair is up this click names it rather than
			# selecting it.
			if _uiManager != null and _uiManager.IsTargetingObject():
				unitBtn.set_pressed_no_signal(selectionList.has(unit))
				_uiManager.ResolveObjectTarget(unit)
				return

			if isPressed and not selectionList.has(unit):
				selectionList.append(unit)
			elif not isPressed:
				selectionList.erase(unit))

		# "A built ship's right-click menu: MOVE, CONFIRMED MOVE, CREATE
		# FLEET, RENAME, Encyclopedia, Status, SCRAP" (manual p115).
		#
		# This offered Status and nothing else - six of the seven were
		# missing, Move included, so a ship sitting in a fleet could not be
		# sent anywhere on its own however much the player wanted it to.
		var popup := PopupMenu.new()
		RegisterPopupMenu(popup)

		var ours: bool = unit.Faction == GameSettings.PlayerFaction

		# "Any time a fleet, OR A SHIP WITHIN A FLEET, is in hyperspace, it
		# cannot receive orders" (manual p111).
		var inHyperspace: bool = unit.Status == Enums.Status.Enroute

		if ours:
			popup.add_item("Move", 0)
			popup.set_item_disabled(popup.get_item_index(0), inHyperspace)
			popup.add_item("Confirmed Move", 1)
			popup.set_item_disabled(popup.get_item_index(1), inHyperspace)
			popup.add_item("Create Fleet", 2)
			popup.set_item_disabled(popup.get_item_index(2), inHyperspace)

			# Ships are the ONLY thing Rename applies to - "the only menu
			# option that isn't available under Facilities Under Construction
			# or Troops in Training" (manual p114). Named because the manual
			# names it, disabled because nothing renames anything yet.
			popup.add_item("Rename", 3)
			popup.set_item_disabled(popup.get_item_index(3), true)
			popup.add_separator()

		popup.add_item("Encyclopedia", 4)
		popup.set_item_disabled(popup.get_item_index(4), true)
		popup.add_item("Status", 5)

		if ours:
			popup.add_separator()
			popup.add_item("Scrap", 6)
			popup.set_item_disabled(popup.get_item_index(6), inHyperspace)

		unitBtn.add_child(popup)

		unitBtn.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				popup.position = Vector2i(int(event.global_position.x), int(event.global_position.y))
				popup.popup()
				unitBtn.accept_event())

		var rowShip: Unit = unit
		# C#: popup.IdPressed += (long id) => { switch ... }. Named here because
		# GDScript cannot close a lambda nested inside a match arm of another
		# lambda with a trailing ')'.
		var onShipMenu := func(id: int) -> void:
			match id:
				0, 1:
					# Split FIRST, then move what came out. A ship alone in
					# its fleet detaches to itself, so this is also the
					# plain "move the fleet" case with no special-casing.
					var solo: Fleet = _associatedPlanet.DetachIntoOwnFleet(rowShip) if _associatedPlanet != null else null
					if solo == null:
						return
					var confirm: bool = id == 1
					_uiManager.StartTargeting(func(target: Planet) -> void:
						_uiManager.ExecuteSingleFleetMove(solo, target, confirm))
				2:
					# Create Fleet, without going anywhere.
					if _associatedPlanet != null:
						_associatedPlanet.DetachIntoOwnFleet(rowShip)
					Populate(_associatedPlanet, _uiManager)
				5:
					_uiManager.OpenUnitStatusWindow(rowShip)
				6:
					var refund: int = rowShip.ConstructionCost * Planet.ScrapRefundPercent / 100
					ConfirmScrapShip(rowShip, refund, func() -> void:
						if _associatedPlanet != null:
							CommandBus.issue("scrap_unit", { "unit": rowShip.Serial })
						Populate(_associatedPlanet, _uiManager))
		popup.id_pressed.connect(onShipMenu)

		list.add_child(unitBtn)


# Returns the menu; the caller parents it to the fleet's button and pops it.
func BuildFleetContextMenu(fleet: Fleet, uiManager: UIManager) -> PopupMenu:
	# THE FLEET COMMAND MENU (manual p111): Move, Confirmed Move, Planetary
	# Bombardment with its three targeting options, Planetary Assault,
	# Rename, Encyclopedia, Status, Scrap.
	#
	# "Attack" was not one of them - it was an invented item wired to an
	# empty method, so it read as a working order and did nothing. The two
	# real combat entries are named here and disabled, which says what the
	# fleet WILL do without pretending it does it yet.
	var popup := PopupMenu.new()

	# A fleet with no faction set is still the player's to command if it is
	# orbiting their world - falling through to "not ours" was leaving the
	# whole command half of the menu off.
	var ours: bool = fleet.Faction == GameSettings.PlayerFaction \
			 or (fleet.Faction == null
				 and _associatedPlanet != null and _associatedPlanet.ControllingFaction == GameSettings.PlayerFaction)

	# "NOTE: Any time a fleet, or a ship within a fleet, IS IN HYPERSPACE, IT
	# CANNOT RECEIVE ORDERS." (manual p111). ExecuteTransit already refuses
	# them, but silently - the items looked live and did nothing when picked.
	var inHyperspace: bool = fleet.Status == Enums.Status.Enroute

	if ours:
		popup.add_item("Move", 0)
		popup.set_item_disabled(popup.get_item_index(0), inHyperspace)
		popup.add_item("Confirmed Move", 1)
		popup.set_item_disabled(popup.get_item_index(1), inHyperspace)

		# FOUR options, not three. Manual p122 lists Target Military
		# Facilities, Target Civilian Facilities, General Bombardment AND
		# "DESTROY SYSTEM: this option is only available if you are the
		# Empire and have the DEATH STAR IN YOUR FLEET" - which was missing.
		#
		# "The Planetary Bombardment sub-menu becomes available when your
		# fleet is IN ORBIT AROUND AN ENEMY OR NEUTRAL SYSTEM."
		var canBombard: bool = BombardmentManager.CanBombard(fleet, _associatedPlanet)

		var bombard := PopupMenu.new()
		bombard.name = "BombardSubmenu"
		bombard.add_item("Target Military Facilities", 10)
		bombard.add_item("Target Civilian Facilities", 11)
		bombard.add_item("General Bombardment", 12)
		bombard.add_item("Destroy System", 13)
		for i in 3:
			bombard.set_item_disabled(i, not canBombard or inHyperspace)
		bombard.set_item_disabled(3, not canBombard or inHyperspace
								   or not BombardmentManager.CanDestroySystem(fleet))
		popup.add_child(bombard)
		popup.add_submenu_node_item("Planetary Bombardment", bombard, 2)
		popup.set_item_disabled(popup.get_item_index(2), not canBombard or inHyperspace)

		bombard.id_pressed.connect(func(id: int) -> void:
			var mode: int
			match id:
				10: mode = BombardmentManager.BombardmentMode.MilitaryFacilities
				11: mode = BombardmentManager.BombardmentMode.CivilianFacilities
				13: mode = BombardmentManager.BombardmentMode.DestroySystem
				_:  mode = BombardmentManager.BombardmentMode.General
			CommandBus.issue("bombard", { "fleet": fleet.Name, "planet": _associatedPlanet.Name, "mode": mode })
			Populate(_associatedPlanet, _uiManager))

		# LIVE. "If you are in orbit above an enemy or neutral system, have
		# troops in your fleet, and this option is GRAYED OUT, it means at
		# least two planetary shields are defending the system." (p123) -
		# so the shield gate is exactly what greys it, and AssaultManager
		# owns that test rather than a second copy here.
		var canAssault: bool = AssaultManager.CanAssault(fleet, _associatedPlanet).ok
		popup.add_item("Planetary Assault", 6)
		popup.set_item_disabled(popup.get_item_index(6), not canAssault or inHyperspace)

		popup.add_item("Rename", 7)
		popup.set_item_disabled(popup.get_item_index(7), true)
		popup.add_separator()

	popup.add_item("Encyclopedia", 4)
	popup.set_item_disabled(popup.get_item_index(4), true)
	popup.add_item("Status", 3)

	if ours:
		popup.add_separator()
		popup.add_item("Scrap", 8)
		popup.set_item_disabled(popup.get_item_index(8), inHyperspace)

	# C#: popup.IdPressed += (id) => { switch ... }. Named for the same parser
	# reason as the ship row's menu.
	var onFleetMenu := func(id: int) -> void:
		match id:
			0, 1:
				InitiateFleetMove(fleet, uiManager, id == 1)
			3:
				uiManager.OpenFleetStatusWindow(fleet)
			8:
				# Scrapping a fleet is scrapping every ship in it; the fleet
				# disbands itself once the last one goes (manual p120).
				var ships: Array = fleet.Ships.duplicate()
				var refund: int = 0
				for s in ships:
					refund += s.ConstructionCost * Planet.ScrapRefundPercent / 100
				ConfirmScrapShip(null, refund, func() -> void:
					for s in ships:
						if _associatedPlanet != null:
							CommandBus.issue("scrap_unit", { "unit": s.Serial })
					Populate(_associatedPlanet, _uiManager),
					"%s (%d ship%s)" % [fleet.Name, ships.size(), "" if ships.size() == 1 else "s"])
	popup.id_pressed.connect(onFleetMenu)

	return popup


func InitiateFleetMove(fleet: Fleet, uiManager: UIManager, requireConfirmation: bool) -> void:
	uiManager.StartTargeting(func(selectedPlanet: Planet) -> void:
		uiManager.ExecuteSingleFleetMove(fleet, selectedPlanet, requireConfirmation))


# The original confirms before scrapping - "Are you sure you want to scrap
# the following units?" with the item named. Same shape the Economy window
# uses, since scrapping is irreversible and returns only half the material.
func ConfirmScrapShip(ship: Unit, refund: int, onConfirm: Callable, label: String = "") -> void:
	var what: String = label if not label.is_empty() else (ship.Name if ship != null else "this unit")
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Scrap"
	dialog.dialog_text = "Are you sure you want to scrap the following units?\n\n" \
				 + "    %s\n\n" % what \
				 + "Returns %d refined material, and the maintenance\n" % refund \
				 + "capacity it was drawing."
	dialog.exclusive = true

	dialog.confirmed.connect(func() -> void:
		onConfirm.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)

	add_child(dialog)
	dialog.popup_centered()


func StateSignature() -> Variant:
	return GameSignature.ForPlanet(_associatedPlanet)


func Refresh() -> void:
	if _associatedPlanet != null and _uiManager != null:
		Populate(_associatedPlanet, _uiManager)


func OnFleetMenuAction(actionId: int, fleets: Array, uiManager: UIManager) -> void:
	if fleets == null or fleets.size() == 0:
		return

	match actionId:
		0, 1:
			var currentPlanet: Planet = fleets[0].Attached as Planet
			if currentPlanet == null:
				return

			uiManager.StartTargeting(func(selectedPlanet: Planet) -> void:
				for fleet in fleets:
					uiManager.ExecuteSingleFleetMove(fleet, selectedPlanet, actionId == 1))
		# No case 2. It called an empty InitiateFleetAttack, and "Attack" is
		# not a fleet order the manual has - Planetary Bombardment and
		# Planetary Assault are (p111).

		6:   # Planetary Assault
			for fleet in fleets:
				var r: Result = AssaultManager.CanAssault(fleet, _associatedPlanet)
				if not r.ok:
					print("[Assault] %s" % r.error)
					continue
				CommandBus.issue("assault", { "fleet": fleet.Name, "planet": _associatedPlanet.Name })
			Populate(_associatedPlanet, uiManager)

		3:
			for fleet in fleets:
				uiManager.OpenFleetStatusWindow(fleet)
		4:
			for fleet in fleets:
				# uiManager.OpenUnitEncyclopedia(fleet);
				pass


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# C#: `_uiManager?.DraggedFleets != null` - the port's UIManager holds []
	# when no drag is running, so "not null" is "not empty".
	return str(data) == "fleet_move" and _uiManager != null and not _uiManager.DraggedFleets.is_empty()


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	if _uiManager == null or _uiManager.DraggedFleets.is_empty():
		return
	var draggedFleets: Array = _uiManager.DraggedFleets
	_uiManager.EndFleetDrag()
	_uiManager.ExecuteFleetMove(draggedFleets, _associatedPlanet, false)


func AreFleetsEligibleForAction(fleets: Array) -> bool:
	return Lq.where(fleets, func(f) -> bool: return f.Status == Enums.Status.AwaitingOrders).size() > 0


func AddFleetButton(fleet: Fleet, list: VBoxContainer, uiManager: UIManager) -> void:
	var button := Button.new()
	button.text = fleet.Name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL

	button.pressed.connect(func() -> void: ShowFleetDetails(fleet, uiManager))

	# ⚠ BOARDING - THE VERB THAT DID NOT EXIST.
	#
	# "A character on a ship has that ship as their base" (manual p115), and
	# the engine models it: OrderManager's fleet cascade carries the
	# personnel riding a fleet, and they return to it. But every move path
	# took a Planet destination, so nothing could ever put a character
	# aboard - the state was modelled, handled in transit, and unreachable.
	#
	# The drop has to land on the FLEET ROW rather than on this window,
	# because the window already accepts a fleet_move drop for the system as
	# a whole. SetDragForwarding gives the row its own drop handling without
	# needing a Button subclass.
	# C#: SetDragForwarding(Callable.From(...) x3) with the lambdas inline;
	# named here so each ends by dedent. DraggedCharacters/DraggedUnits are
	# null when idle in C#; the port's UIManager holds [] instead.
	var dragGet := func(_at: Vector2) -> Variant:
		return null
	var dragCan := func(_at: Vector2, data: Variant) -> bool:
		return (str(data) == "character_move" and _uiManager != null and not _uiManager.DraggedCharacters.is_empty()) \
			or (str(data) == "unit_move" and _uiManager != null and not _uiManager.DraggedUnits.is_empty())
	var dragDrop := func(_at: Vector2, data: Variant) -> void:
		if str(data) == "character_move":
			var boarding: Array = _uiManager.DraggedCharacters if _uiManager != null else []
			if _uiManager != null:
				_uiManager.EndCharacterDrag()
			if boarding.is_empty():
				return

			var r: Result = CommandBus.issue("board_fleet", { "characters": EntityIndex.names_of(boarding), "fleet": fleet.Name })
			if r.ok:
				Populate(_associatedPlanet, _uiManager)
			else:
				print("[Board] %s" % r.error)
			return

		# Troops and fighters, which is what makes an invasion possible -
		# "the troops ON YOUR FLEET go down to the planet surface"
		# (manual p057). Until this existed only day zero could put a
		# regiment in a hangar.
		var cargo: Array = _uiManager.DraggedUnits if _uiManager != null else []
		if _uiManager != null:
			_uiManager.EndUnitDrag()
		if cargo.is_empty():
			return

		var load: Result = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units(cargo), "fleet": fleet.Name })
		var n: int = load.value
		if n > 0:
			Populate(_associatedPlanet, _uiManager)
		else:
			print("[Load] %s" % load.error)
	button.set_drag_forwarding(dragGet, dragCan, dragDrop)

	list.add_child(button)


func ShowFleetDetails(fleet: Fleet, uiManager: UIManager) -> void:
	var detailsPanel: Panel = get_node("%FleetDetails")
	var unitList: VBoxContainer = get_node("%FleetUnits")

	ClearExistingUnitButtons(unitList)

	detailsPanel.show()
	for unit in fleet.Hangar:
		AddUnitButton(unit, unitList, uiManager)


func ClearExistingUnitButtons(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func AddUnitButton(unit: Unit, list: VBoxContainer, uiManager: UIManager) -> void:
	var button := Button.new()
	button.text = unit.Name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL

	button.pressed.connect(func() -> void: OnUnitSelected(unit, uiManager))
	list.add_child(button)


func OnUnitSelected(unit: Unit, uiManager: UIManager) -> void:
	if unit == null:
		return

	uiManager.OpenUnitStatusWindow(unit)


func _gui_input(_event: InputEvent) -> void:
	# C#: base._GuiInput(@event) - nothing more.
	pass


## C#: public partial class FleetButton : Button (same file). An inner class
## here because a GDScript file carries one class_name.
class FleetButton extends Button:
	var UnitData: Fleet
	var UIManagerRef: UIManager
	var ParentWindow: FleetWindow

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if UnitData == null or UnitData.Status == Enums.Status.Enroute:
			return null

		# If the fleet isn't in the selected group, create a list containing ONLY the dragged fleet!
		var dragGroup: Array = Lq.where(ParentWindow.SelectedFleets, func(u: Fleet) -> bool: return u.Status != Enums.Status.Enroute) \
			if ParentWindow.SelectedFleets.has(UnitData) \
			else [UnitData]

		if dragGroup.size() == 0:
			return null

		UIManagerRef.StartFleetDrag(dragGroup)
		ParentWindow.move_to_front()

		var previewVBox := VBoxContainer.new()
		var previewLabel := Label.new()
		previewLabel.text = "Fleet(s)"
		previewLabel.add_theme_color_override("font_color", dragGroup[0].Faction.FactionColor if dragGroup[0].Faction != null else Color.WHITE)
		previewLabel.add_theme_font_size_override("font_size", 16)
		previewVBox.add_child(previewLabel)

		set_drag_preview(previewVBox)
		return "fleet_move"


# --- Button that represents individual Ships/Fighters inside the Tab ---
## C#: public partial class FleetUnitMenuButton : Button (same file).
class FleetUnitMenuButton extends Button:
	var UnitData: Unit
	var UIManagerRef: UIManager
	var ParentWindow: FleetWindow
	var SelectionGroup: Array = []

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if UnitData == null or UnitData.Status == Enums.Status.Enroute:
			return null

		var dragGroup: Array = Lq.where(
			SelectionGroup if SelectionGroup.has(UnitData) else [UnitData],
			func(u: Unit) -> bool: return u.Status != Enums.Status.Enroute)

		if dragGroup.size() == 0:
			return null

		UIManagerRef.StartUnitDrag(dragGroup)
		if ParentWindow != null:
			ParentWindow.move_to_front()

		var previewVBox := VBoxContainer.new()
		for u in dragGroup:
			var previewLabel := Label.new()
			previewLabel.text = u.Name
			previewLabel.add_theme_color_override("font_color", u.Faction.FactionColor if u.Faction != null else Color.WHITE)
			previewLabel.add_theme_font_size_override("font_size", 16)
			previewVBox.add_child(previewLabel)

		set_drag_preview(previewVBox)
		return "unit_move"
