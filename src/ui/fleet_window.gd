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
	var original: bool = _BuildOriginal()

	# The original titles the window with the system's name alone.
	titleBarLabel.text = planet.Name if original else " %s System Fleets" % planet.Name

	# Clear existing fleet buttons on the left
	for child in fleetList.get_children():
		fleetList.remove_child(child)
		child.queue_free()
	_oTiles.clear()

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
			selectedFleetName.text = "" if original else "Sensors detect no data..."
			_ClearPanel()
			return

		if view.Groups.size() == 0 and mine.size() == 0:
			# The same voice as the live branch: the snapshot says the
			# orbit was empty.
			selectedFleetName.text = "" if original else "No fleets detected in orbit."
			_ClearPanel()
			return

		selectedFleetName.text = "" if original else "Select a fleet to view its composition"

		for g in view.Groups:
			var captured: IntelManager.IntelGroup = g
			var row := Button.new()
			row.text = g.Name
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.flat = true
			row.pressed.connect(func() -> void: DisplayRememberedFleet(captured))
			fleetList.add_child(row)
			if original:
				_TileRemembered(row, captured)

		# As the live branch does: show the first one - yours first. The
		# original's opens with the tiles alone (below).
		if original:
			_PanelVisible(false)
		elif mine.size() > 0:
			DisplayFleetContents(mine[0])
		else:
			DisplayRememberedFleet(view.Groups[0])
		return

	var orbitingFleets: Array = Lq.where(planet.OrbitingFleets,
		func(f: Fleet) -> bool: return f.Status != Enums.Status.Enroute or f.Destination == planet)

	if orbitingFleets.size() == 0:
		selectedFleetName.text = "" if original else "No fleets detected in orbit."
		ClearFleetContents()
		_ClearPanel()
		return

	selectedFleetName.text = "" if original else "Select a fleet to view its composition"

	for fleet in orbitingFleets:
		AddFleetToList(fleet, fleetList, _uiManager)

	# Automatically display the first fleet's contents. The original's opens
	# with the fleets' tiles alone, the contents panel appearing when one is
	# clicked (Fig. 3.54; TeeJ's screenshot of Xyquine, 2026-09-24); what was
	# shown stays shown (an opened fleet's ship too).
	if original and _shown is Unit and Lq.any(orbitingFleets, func(f: Fleet) -> bool: return f.Ships.has(_shown)):
		_ShowShip(_shown)
	elif original and _shown is Fleet and orbitingFleets.has(_shown):
		DisplayFleetContents(_shown)
	elif original:
		_shown = null
		_PanelVisible(false)
	elif orbitingFleets.size() > 0:
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
	if _original:
		_TileFleet(fleetButton, fleet, list)


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
		PopulateUnitTab(fightersTab, fighters, "No %s in this fleet." % Terms.lower("fighter_squadrons"), SelectedFighters)
	if troopsTab != null:
		PopulateUnitTab(troopsTab, troops, "No regiments attached.", SelectedTroops)

	# For personnel, safely query the GameManager
	if personnelTab != null:
		for child in personnelTab.get_children():
			personnelTab.remove_child(child)
			child.queue_free()
		var pList: VBoxContainer = _PageList(personnelTab)

		# Characters are attached directly to the Fleet (Location), so check for direct equality!
		var personnel: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == fleet)

		if personnel.size() == 0 and _original:
			pass   # the original's page is empty and its tab greyed
		elif personnel.size() == 0:
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
			if _original:
				for b in pList.get_children():
					if b is Button and b.get("CharacterData") != null:
						_RowCharacter(b, b.CharacterData)
	if _original:
		_ShowFleet(fleet)


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
	if _original:
		_ShowRemembered(fleet)


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
			if child is VBoxContainer or child is ScrollContainer:
				tab.remove_child(child)
				child.queue_free()


# --- Universal Sub-Unit Tab Builder ---
func PopulateUnitTab(tab: MarginContainer, units: Array, emptyText: String, selectionList: Array) -> void:
	for child in tab.get_children():
		tab.remove_child(child)
		child.queue_free()

	var list: VBoxContainer = _PageList(tab)

	if units == null or units.size() == 0:
		if _original:
			return   # the original's page is empty and its tab greyed
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

		_AttachUnitMenu(unitBtn, unit)

		list.add_child(unitBtn)
		if _original:
			_RowUnit(unitBtn, unit)


## A unit's right-click menu on its row (manual p115): Move, Confirmed Move,
## Create Fleet, Rename, Encyclopedia, Status, Scrap.
func _AttachUnitMenu(unitBtn: Control, unit: Unit) -> void:
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

	# "You can right-click on a Ship icon and select Encyclopedia to learn
	# more about it" (manual p112, Tip).
	popup.add_item("Encyclopedia", 4)
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
			4:
				_uiManager.OpenEncyclopedia("units", rowShip.PackId)
			5:
				_uiManager.OpenUnitStatusWindow(rowShip)
			6:
				var refund: int = rowShip.ConstructionCost * Planet.ScrapRefundPercent / 100
				ConfirmScrapShip(rowShip, refund, func() -> void:
					if _associatedPlanet != null:
						CommandBus.issue("scrap_unit", { "unit": rowShip.Serial })
					Populate(_associatedPlanet, _uiManager))
	popup.id_pressed.connect(onShipMenu)


# Returns the menu; the caller parents it to the fleet's button and pops it.
func BuildFleetContextMenu(fleet: Fleet, uiManager: UIManager) -> PopupMenu:
	return FleetMenu([fleet], _associatedPlanet, uiManager, true, func() -> void:
		if _associatedPlanet != null:
			Populate(_associatedPlanet, _uiManager))


## THE FLEET COMMAND MENU (manual p121, Fig. 3.64): Move, Confirmed Move,
## Planetary Bombardment with its targeting options, Planetary Assault,
## Rename, Encyclopedia, Status, Scrap - for one fleet in this window, or for
## a side's fleets at a system from the Sector window's fleet icon, whose menu
## is the same less Rename (TeeJ's screenshot of the original's, 2026-09-24:
## Move, Confirmed Move, Planetary Bombardment, Planetary Assault,
## Encyclopedia, Status, Scrap). An order given to several fleets is given to
## each. `refresh` runs after an order that changes what is shown.
##
## "Attack" was not one of them - it was an invented item wired to an empty
## method, so it read as a working order and did nothing.
static func FleetMenu(fleets: Array, planet: Planet, uiManager: UIManager, withRename: bool, refresh: Callable) -> PopupMenu:
	var popup := PopupMenu.new()
	popup.name = "FleetMenu"
	if fleets.is_empty():
		return popup
	var fleet: Fleet = fleets[0]

	# A fleet with no faction set is still the player's to command if it is
	# orbiting their world - falling through to "not ours" was leaving the
	# whole command half of the menu off.
	var ours: bool = fleet.Faction == GameSettings.PlayerFaction \
			 or (fleet.Faction == null and planet != null and planet.ControllingFaction == GameSettings.PlayerFaction)

	# "NOTE: Any time a fleet, or a ship within a fleet, IS IN HYPERSPACE, IT
	# CANNOT RECEIVE ORDERS." (manual p111). ExecuteTransit already refuses
	# them, but silently - the items looked live and did nothing when picked.
	var inHyperspace: bool = Lq.any(fleets, func(f: Fleet) -> bool: return f.Status == Enums.Status.Enroute)

	if ours:
		popup.add_item("Move", 0)
		popup.set_item_disabled(popup.get_item_index(0), inHyperspace)
		popup.add_item("Confirmed Move", 1)
		popup.set_item_disabled(popup.get_item_index(1), inHyperspace)

		# FOUR options, not three. Manual p122 lists Target Military
		# Facilities, Target Civilian Facilities, General Bombardment AND
		# "DESTROY SYSTEM: this option is only available if you are the
		# Empire and have the DEATH STAR IN YOUR FLEET".
		#
		# "The Planetary Bombardment sub-menu becomes available when your
		# fleet is IN ORBIT AROUND AN ENEMY OR NEUTRAL SYSTEM."
		var bombarders: Array = Lq.where(fleets, func(f: Fleet) -> bool: return BombardmentManager.CanBombard(f, planet))
		var canBombard: bool = not bombarders.is_empty()
		var bombard := PopupMenu.new()
		bombard.name = "BombardSubmenu"
		bombard.add_item("Target Military Facilities", 10)
		bombard.add_item("Target Civilian Facilities", 11)
		bombard.add_item("General Bombardment", 12)
		bombard.add_item("Destroy System", 13)
		for i in 3:
			bombard.set_item_disabled(i, not canBombard or inHyperspace)
		bombard.set_item_disabled(3, not canBombard or inHyperspace
								   or not Lq.any(bombarders, func(f: Fleet) -> bool: return BombardmentManager.CanDestroySystem(f)))
		popup.add_child(bombard)
		popup.add_submenu_node_item("Planetary Bombardment", bombard, 2)
		popup.set_item_disabled(popup.get_item_index(2), not canBombard or inHyperspace)
		bombard.id_pressed.connect(func(id: int) -> void:
			var mode: int = BombardmentManager.BombardmentMode.General
			if id == 10:
				mode = BombardmentManager.BombardmentMode.MilitaryFacilities
			elif id == 11:
				mode = BombardmentManager.BombardmentMode.CivilianFacilities
			elif id == 13:
				mode = BombardmentManager.BombardmentMode.DestroySystem
			for f in bombarders:
				if mode == BombardmentManager.BombardmentMode.DestroySystem and not BombardmentManager.CanDestroySystem(f):
					continue
				CommandBus.issue("bombard", { "fleet": f.Name, "planet": planet.Name, "mode": mode })
			refresh.call())

		# LIVE. "If you are in orbit above an enemy or neutral system, have
		# troops in your fleet, and this option is GRAYED OUT, it means at
		# least two planetary shields are defending the system." (p123) -
		# so the shield gate is exactly what greys it, and AssaultManager
		# owns that test rather than a second copy here.
		var assaulters: Array = Lq.where(fleets, func(f: Fleet) -> bool: return AssaultManager.CanAssault(f, planet).ok)
		popup.add_item("Planetary Assault", 6)
		popup.set_item_disabled(popup.get_item_index(6), assaulters.is_empty() or inHyperspace)

		if withRename:
			popup.add_item("Rename", 7)
			popup.set_item_disabled(popup.get_item_index(7), true)

		popup.id_pressed.connect(func(id: int) -> void:
			if id == 6:
				for f in assaulters:
					CommandBus.issue("assault", { "fleet": f.Name, "planet": planet.Name })
				refresh.call())

	# A fleet has no entry of its own: the Encyclopedia's ship database.
	popup.add_item("Encyclopedia", 4)
	popup.add_item("Status", 3)

	if ours:
		popup.add_item("Scrap", 8)
		popup.set_item_disabled(popup.get_item_index(8), inHyperspace)

	popup.id_pressed.connect(func(id: int) -> void:
		_OnFleetMenu(id, fleets, uiManager, popup, refresh))
	return popup


## A fleet menu item picked (a method: a match cannot sit in a lambda).
static func _OnFleetMenu(id: int, fleets: Array, uiManager: UIManager, popup: PopupMenu, refresh: Callable) -> void:
	match id:
		0, 1:
			uiManager.StartTargeting(func(selectedPlanet: Planet) -> void:
				for f in fleets:
					uiManager.ExecuteSingleFleetMove(f, selectedPlanet, id == 1))
		3:
			for f in fleets:
				uiManager.OpenFleetStatusWindow(f)
		4:
			uiManager.OpenEncyclopedia()
			var w: EncyclopediaWindow = uiManager._openWindows.get("Encyclopedia")
			if w != null:
				w.ShowIndex(2)
		8:
			# Scrapping a fleet is scrapping every ship in it; the fleet
			# disbands itself once the last one goes (manual p120).
			var ships: Array = []
			for f in fleets:
				ships.append_array(f.Ships)
			var refund: int = 0
			for sh in ships:
				refund += sh.ConstructionCost * Planet.ScrapRefundPercent / 100
			var label: String = "%s (%d ship%s)" % [", ".join(Lq.select(fleets, func(f: Fleet) -> String: return f.Name)),
				ships.size(), "" if ships.size() == 1 else "s"]
			_ConfirmFleetScrap(popup, uiManager, label, refund, func() -> void:
				for sh in ships:
					CommandBus.issue("scrap_unit", { "unit": sh.Serial })
				refresh.call())


## The original's confirmation (with the art), else a plain dialog.
static func _ConfirmFleetScrap(anchor: Node, uiManager: UIManager, what: String, refund: int, onConfirm: Callable) -> void:
	var note: String = "Returns %d %s, and the maintenance capacity it was drawing." % [refund, Terms.lower("refined_materials")]
	if uiManager != null and uiManager.ConfirmScript.CanBuild():
		var f: Faction = GameSettings.PlayerFaction
		var side: String = "alliance" if f != null and f.ArtSkin == "alliance" else "empire"
		uiManager.OpenConfirmation(f, OUI.Pic("scrap_picture." + side),
			"Are you sure you want to scrap the following units?\n" + what, note, onConfirm)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Scrap"
	dialog.dialog_text = "Are you sure you want to scrap the following units?\n\n    %s\n\n%s" % [what, note]
	dialog.exclusive = true
	dialog.confirmed.connect(func() -> void:
		onConfirm.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	(uiManager if uiManager != null else anchor).add_child(dialog)
	dialog.popup_centered()


# ---- THE ORIGINAL'S FLEET WINDOW -------------------------------------------------

## Manual p112-p113 (Figs 3.54-3.56) and TeeJ's screenshot of the original's
## Chandrila window (2026-09-24), every picture placed on it by template
## matching; positions in the 235x304 backdrop's pixels, drawn OUI.K times as
## large:
##   the system's name on the title bar, over the backdrop (STRATEGY 10770);
##   down the left, each fleet's 73x47 tile - its picture, its name over it,
##   a badge for each of fighters, troops and personnel it carries - the
##   side's frame round the one shown; double-click one to open it and list
##   its capital ships under it, click one of those to examine it (Fig. 3.56);
##   on the right the contents panel: the name in the side's colour, carried
##   and capacity on the fighter and troop tabs ("Fleet contains one fighter,
##   but has room for two", Fig. 3.55), the 122x50 picture (the blue engine
##   glow of a fleet in hyperspace, Fig. 3.54; flames when damaged), the four
##   tabs (three for a ship, Fig. 3.56), and the contents - each picture
##   centred with its badges and its name under it, a row every 50 pixels.
const PlateW := 235
const PlateH := 304
const TileAt := Vector2(4, 29)
const TileSize := Vector2(73, 47)
## INFERRED: the screenshot shows one fleet; Figs. 3.54 and 3.56 read 49-53
## pixels a fleet.
const TileGap := 3
const TilePicture := Vector2(5, 5)
const TileNameAt := Vector2(2, 6)       # the name's capitals
const TileBadgeXs := [25, 41, 57]       # fighter, troop, personnel
const TileBadgeY := 33
const PanelAt := Vector2(97, 29)
const NameAt := Vector2(101, 32)        # the name's capitals
const PictureAt := Vector2(101, 42)
## INFERRED from Figs. 3.55 and 3.56 (no screenshot of those tabs): carried
## under the name at the left, capacity at the right.
const CountCap := 45
const TabNames := ["fleet_tab_ship", "fleet_tab_fighter", "fleet_tab_troop", "fleet_tab_personnel"]
const TabXs := [100, 132, 164, 196]
const TabY := 96
const ListRect := Rect2(98, 126, 130, 170)
const RowTop := 131                     # the first row's picture
const RowPitch := 50
const RowCentre := 162
const RowBadges := [Vector2(-3, 19), Vector2(13, 19)]   # fighter, troop: from the picture's corner
const RowNameCap := 29
const NamePx := 12.5
const RowPx := 10.0
const TextShadow := Color(0, 0, 0.55)

var _original: bool = false
var _opened: Dictionary = {}            # Fleet -> true: its ships listed under it
var _shown: Object = null               # the Fleet or Unit on the panel
var _oPicture: TextureRect
var _oOver: TextureRect
var _oUnder: TextureRect
var _oCarried: Label
var _oCapacity: Label
var _oTiles: Array = []                 # [Control, subject]


## Build the original's window once, when its art is imported. False without it.
func _BuildOriginal() -> bool:
	if _original:
		return true
	var side: String = OUI.Side(GameSettings.PlayerFaction)
	if not OUI.Has(["fleet_background", "fleet_panel." + side, "fleet_tile." + side, "fleet_small." + side]):
		return false
	for n in TabNames:
		if Art.TabIcon(n, side) == null:
			return false
	_original = true
	OUI.TitleBar(self, GameSettings.PlayerFaction)
	var area: MarginContainer = OUI.Flatten(self)
	var body: Control = OUI.Canvas(area, PlateW, PlateH)
	OUI.Place(body, OUI.Pic("fleet_background"), 0, 0, "Plate")
	OUI.Place(body, OUI.Pic("fleet_panel." + side), PanelAt.x, PanelAt.y, "Panel")

	# The fleets down the left, in a column that scrolls when they run over.
	var column := ScrollContainer.new()
	column.name = "FleetColumn"
	column.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.position = TileAt * OUI.K
	column.size = Vector2(PanelAt.x - TileAt.x - 1, PlateH - TileAt.y - 4) * OUI.K
	body.add_child(column)
	var list: VBoxContainer = get_node("%FleetList")
	list.reparent(column, false)
	list.add_theme_constant_override("separation", TileGap * OUI.K)

	# The panel: name, counts, picture.
	var name: Label = get_node("%SelectedFleetName")
	OUI.Seat(name, body, NameAt.x, NameAt.y - 0.19 * NamePx, 124, NamePx * 1.3)
	OUI.Style(name, NamePx, OUI.SideColor(GameSettings.PlayerFaction), true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name.clip_text = true
	_oUnder = OUI.Place(body, null, PictureAt.x, PictureAt.y, "PictureUnder")
	_oPicture = OUI.Place(body, null, PictureAt.x, PictureAt.y, "Picture")
	_oOver = OUI.Place(body, null, PictureAt.x, PictureAt.y, "PictureOver")
	_oCarried = OUI.Text(body, "", NameAt.x, CountCap - 0.19 * RowPx, 40, RowPx * 1.3, RowPx, Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT, false, "Carried")
	_oCapacity = OUI.Text(body, "", PanelAt.x + 132 - 44, CountCap - 0.19 * RowPx, 40, RowPx * 1.3, RowPx, Color.WHITE,
		HORIZONTAL_ALIGNMENT_RIGHT, false, "Capacity")

	# The four tabs over the contents.
	var tabs: TabContainer = get_node("%FleetTabs")
	tabs.reparent(body, false)
	tabs.tabs_visible = false
	tabs.custom_minimum_size = Vector2.ZERO
	tabs.position = ListRect.position * OUI.K
	tabs.size = ListRect.size * OUI.K
	tabs.clip_contents = true
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for page in tabs.get_children():
		if page is MarginContainer:
			for m in ["left", "top", "right", "bottom"]:
				(page as MarginContainer).add_theme_constant_override("margin_" + m, 0)
	OUI.TabStrip(body, tabs, TabNames, side, TabXs, TabY)
	tabs.tab_changed.connect(func(_i: int) -> void: _ShowCounts())

	# The plain layout's frame goes, and the window is the backdrop's size.
	var split: Node = get_node_or_null("MainVBox/ContentArea/SplitView")
	if split != null:
		split.visible = false
	custom_minimum_size = Vector2.ZERO
	reset_size.call_deferred()
	return true


## A fleet's side as its pictures show it.
static func _FleetSide(f: Fleet) -> String:
	var side: String = OUI.Side(f.Faction) if f != null else ""
	return side if side == "alliance" or side == "empire" else OUI.Side(GameSettings.PlayerFaction)


## What a fleet carries: [fighters, troops, personnel] counts, capacities.
static func Carried(f: Fleet) -> Dictionary:
	var fighters := 0
	var troops := 0
	var fighterCap := 0
	var troopCap := 0
	for s in f.Ships:
		if s.Type == Enums.UnitType.Fighter:
			fighters += 1
		elif s.Type == Enums.UnitType.Troop or s.Type == Enums.UnitType.SpecForce:
			troops += 1
		fighterCap += s.FighterCapacity
		troopCap += s.TroopCapacity
		for h in s.Hangar:
			if h.Type == Enums.UnitType.Fighter:
				fighters += 1
			elif h.Type == Enums.UnitType.Troop or h.Type == Enums.UnitType.SpecForce:
				troops += 1
	var personnel: int = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == f)
	return {"fighters": fighters, "troops": troops, "personnel": personnel, "fighter_cap": fighterCap, "troop_cap": troopCap}


## A tile in the left column: the button keeps its menu, drag, selection and
## crosshair hooks; its text becomes the original's picture, name and badges.
func _Tile(btn: Button, subject: Object, title: String, picture: Texture2D, over: Texture2D, badges: Array, side: String) -> void:
	btn.text = ""
	btn.icon = null
	btn.flat = true
	btn.clip_text = false
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.custom_minimum_size = TileSize * OUI.K
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if picture != null:
		OUI.Place(btn, picture, TilePicture.x, TilePicture.y, "Picture")
	if over != null:
		OUI.Place(btn, over, TilePicture.x, TilePicture.y, "Over")
	var l := OUI.Text(btn, title, TileNameAt.x, TileNameAt.y - 0.19 * NamePx, TileSize.x - TileNameAt.x - 1, NamePx * 1.3,
		NamePx, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Name")
	l.clip_text = true
	_Shadow(l)
	var kinds := ["fighter", "troop", "personnel"]
	for i in 3:
		if i < badges.size() and badges[i]:
			OUI.Place(btn, OUI.Pic("fleet_badge_%s.%s" % [kinds[i], side]), TileBadgeXs[i], TileBadgeY, "Badge_" + kinds[i])
	var frame: TextureRect = OUI.Place(btn, OUI.Pic("fleet_tile." + OUI.Side(GameSettings.PlayerFaction)), 0, 0, "Frame")
	frame.visible = subject != null and subject == _shown
	_oTiles.append([btn, subject])


## Frame the tile of whatever the panel shows.
func _FrameShown() -> void:
	for t in _oTiles:
		var btn: Control = t[0]
		if is_instance_valid(btn) and btn.get_node_or_null("Frame") != null:
			btn.get_node("Frame").visible = t[1] != null and t[1] == _shown


## A fleet's tile, and - opened - its capital ships' tiles under it.
func _TileFleet(btn: Button, fleet: Fleet, list: VBoxContainer) -> void:
	var side: String = _FleetSide(fleet)
	var c: Dictionary = Carried(fleet)
	var damaged: bool = Lq.any(fleet.Ships, func(s: Unit) -> bool: return s.IsDamaged())
	var over: Texture2D = OUI.Pic("fleet_small_glow." + side) if fleet.Status == Enums.Status.Enroute \
		else (OUI.Pic("fleet_small_damage." + side) if damaged else null)
	_Tile(btn, fleet, fleet.Name, OUI.Pic("fleet_small." + side), over,
		[c["fighters"] > 0, c["troops"] > 0, c["personnel"] > 0], side)
	# "Double-click on a fleet to 'open it up' and see its capital ships
	# below" (Fig. 3.56).
	btn.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			if _opened.has(fleet):
				_opened.erase(fleet)
			else:
				_opened[fleet] = true
			btn.accept_event()
			Populate.call_deferred(_associatedPlanet, _uiManager))
	if not _opened.has(fleet):
		return
	for ship in fleet.Ships:
		if ship.Type != Enums.UnitType.CapitalShip:
			continue
		var row := Button.new()
		row.toggle_mode = false
		var s: Unit = ship
		row.pressed.connect(func() -> void:
			if _uiManager != null and _uiManager.IsTargetingObject():
				_uiManager.ResolveObjectTarget(s)
				return
			_ShowShip(s))
		_AttachUnitMenu(row, s)
		list.add_child(row)
		var cargo: Array = [Lq.any(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter),
			Lq.any(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop or h.Type == Enums.UnitType.SpecForce)]
		_Tile(row, s, s.Name, OUI.Mini("units", s.PackId), null, cargo, side)


## The panel for a fleet (every tab its whole contents, Fig. 3.55).
func _ShowFleet(fleet: Fleet) -> void:
	_shown = fleet
	_PanelVisible(true)
	var side: String = _FleetSide(fleet)
	var damaged: bool = Lq.any(fleet.Ships, func(s: Unit) -> bool: return s.IsDamaged())
	_SetPicture(OUI.Pic("status_fleet." + side), null,
		OUI.Pic("fleet_large_glow." + side) if fleet.Status == Enums.Status.Enroute \
			else (OUI.Pic("status_fleet_damage." + side) if damaged else null))
	_ShowTabs(true)
	_FrameShown()
	_ShowCounts()


## The panel for one capital ship (Fig. 3.56): its picture, and its fighters,
## troops and personnel - three tabs, no capital ships tab.
func _ShowShip(ship: Unit) -> void:
	_shown = ship
	_PanelVisible(true)
	get_node("%SelectedFleetName").text = ship.Name
	var tabs: TabContainer = get_node("%FleetTabs")
	var fighters: Array = Lq.where(ship.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Fighter)
	var troops: Array = Lq.where(ship.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop or u.Type == Enums.UnitType.SpecForce)
	PopulateUnitTab(tabs.get_node("Capital Ships"), [], "", SelectedCapitalShips)
	PopulateUnitTab(tabs.get_node("Fighters"), fighters, "", SelectedFighters)
	PopulateUnitTab(tabs.get_node("Troops"), troops, "", SelectedTroops)
	var personnel: Node = tabs.get_node("Personnel")
	for child in personnel.get_children():
		personnel.remove_child(child)
		child.queue_free()
	var flames: Texture2D = Art.Scaled(Art.Portrait("units", ship.PackId + ".damage"), OUI.K) if ship.IsDamaged() else null
	_SetPicture(Art.Scaled(Art.Portrait("units", ship.PackId), OUI.K), flames, null)
	_ShowTabs(false)
	_FrameShown()
	_ShowCounts()


func _SetPicture(picture: Texture2D, under: Texture2D, over: Texture2D) -> void:
	for pair in [[_oUnder, under], [_oPicture, picture], [_oOver, over]]:
		var r: TextureRect = pair[0]
		r.texture = pair[1]
		r.size = (pair[1] as Texture2D).get_size() if pair[1] != null else Vector2.ZERO


## The tabs for what is shown: the capital ships tab only for a fleet; a tab
## with nothing on it greyed, as the other windows' are; the page kept if it
## has something, else the first that does.
func _ShowTabs(fleetShown: bool) -> void:
	var tabs: TabContainer = get_node("%FleetTabs")
	var strip: Array = tabs.get_meta("tab_strip", [])
	if strip.size() > 0:
		(strip[0] as Control).visible = fleetShown
	var counts: Array = []
	for i in tabs.get_tab_count():
		tabs.set_tab_disabled(i, false)
		counts.append(_RowsOn(tabs.get_child(i)))
	if not fleetShown:
		counts[0] = 0
	var current: int = tabs.current_tab
	if counts[current] == 0 or (current == 0 and not fleetShown):
		current = 0 if fleetShown else 1
		for i in counts.size():
			if counts[i] > 0 and (fleetShown or i > 0):
				current = i
				break
	tabs.current_tab = current
	for i in counts.size():
		tabs.set_tab_disabled(i, counts[i] == 0 and i != current)
	OUI.RefreshStrip(tabs)


static func _RowsOn(page: Node) -> int:
	var n := 0
	for c in page.find_children("*", "Button", true, false):
		if c.has_meta("fleet_row"):
			n += 1
	return n


## Carried and capacity on the fighter and troop tabs ("Fleet contains one
## fighter, but has room for two", Fig. 3.55; "both of the spaces for
## fighters in this fleet are on the Victory Destroyer", Fig. 3.56).
func _ShowCounts() -> void:
	if _oCarried == null:
		return
	var tabs: TabContainer = get_node("%FleetTabs")
	var carried := -1
	var capacity := -1
	if _shown is Fleet:
		var c: Dictionary = Carried(_shown)
		if tabs.current_tab == 1:
			carried = c["fighters"]
			capacity = c["fighter_cap"]
		elif tabs.current_tab == 2:
			carried = c["troops"]
			capacity = c["troop_cap"]
	elif _shown is Unit:
		var u: Unit = _shown
		if tabs.current_tab == 1:
			carried = Lq.count(u.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
			capacity = u.FighterCapacity
		elif tabs.current_tab == 2:
			carried = Lq.count(u.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop or h.Type == Enums.UnitType.SpecForce)
			capacity = u.TroopCapacity
	_oCarried.text = str(carried) if carried >= 0 else ""
	_oCapacity.text = str(capacity) if capacity >= 0 else ""


## A row on the panel: the picture centred, its badges, its name under it.
## The button keeps its menu, drag and selection.
func _Row(btn: Button, title: String, picture: Texture2D, badges: Array, side: String, selected: Color) -> void:
	btn.text = ""
	btn.icon = null
	btn.flat = true
	btn.set_meta("fleet_row", true)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.custom_minimum_size = Vector2(ListRect.size.x, RowPitch) * OUI.K
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var top: float = RowTop - ListRect.position.y
	var w: float = picture.get_width() / float(OUI.K) if picture != null else 66.0
	var left: float = RowCentre - ListRect.position.x - w / 2.0
	if picture != null:
		OUI.Place(btn, picture, left, top, "Picture")
	var kinds := ["fighter", "troop"]
	for i in 2:
		if i < badges.size() and badges[i]:
			OUI.Place(btn, OUI.Pic("fleet_badge_%s.%s" % [kinds[i], side]), left + RowBadges[i].x, top + RowBadges[i].y, "Badge_" + kinds[i])
	var l := OUI.Text(btn, title, 0, top + RowNameCap - 0.19 * RowPx, ListRect.size.x, RowPx * 1.3, RowPx, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, false, "Name")
	l.clip_text = true
	_Shadow(l)
	var frame := OUI.SelectionFrame(left, top, selected)
	btn.add_child(frame)
	frame.visible = btn.button_pressed
	btn.toggled.connect(func(on: bool) -> void: frame.visible = on)


## A unit's row (a capital ship with its cargo badges, a squadron, a regiment).
func _RowUnit(btn: Button, unit: Unit) -> void:
	var side: String = _FleetSide(unit.Attached as Fleet) if unit.Attached is Fleet else OUI.Side(unit.Faction)
	var badges: Array = [false, false]
	if unit.Type == Enums.UnitType.CapitalShip:
		badges = [Lq.any(unit.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter),
			Lq.any(unit.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop or h.Type == Enums.UnitType.SpecForce)]
	_Row(btn, unit.Name, OUI.Mini("units", unit.PackId), badges, side if side != "" else "empire",
		OUI.SideColor(GameSettings.PlayerFaction))


## A person's row: the miniature in its status (manual p096), the name.
func _RowCharacter(btn: Button, c: Character) -> void:
	_Row(btn, c.Name, OUI.Mini("characters", c.PackId), [], OUI.Side(c.Faction), OUI.SideColor(GameSettings.PlayerFaction))
	var pic: Node = btn.get_node_or_null("Picture")
	var state: String = OUI.CharacterState(c)
	var over: Texture2D = OUI.CharacterOver(c) if state == "captured" else (OUI.Pic("card_injured") if state == "injured" else null)
	if pic != null and over != null:
		var r: TextureRect = OUI.Place(btn, over, (pic as Control).position.x / OUI.K, (pic as Control).position.y / OUI.K, "Over")
		btn.move_child(r, pic.get_index() + 1)


## The name labels' dark-blue drop shadow (the screenshot's).
static func _Shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", TextShadow)
	l.add_theme_constant_override("shadow_offset_x", -1)
	l.add_theme_constant_override("shadow_offset_y", OUI.K / 2)


## A remembered fleet (a sighting): its tile, then its ships by name - the
## sighting keeps no more (the other tabs stay greyed).
func _TileRemembered(btn: Button, group: IntelManager.IntelGroup) -> void:
	var side: String = "alliance" if OUI.Side(GameSettings.PlayerFaction) == "empire" else "empire"
	_Tile(btn, group, group.Name, OUI.Pic("fleet_small." + side), null, [], side)


func _ShowRemembered(group: IntelManager.IntelGroup) -> void:
	_shown = group
	_PanelVisible(true)
	var side: String = "alliance" if OUI.Side(GameSettings.PlayerFaction) == "empire" else "empire"
	var tabs: TabContainer = get_node("%FleetTabs")
	for i in tabs.get_tab_count():
		var page: Node = tabs.get_child(i)
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	tabs.get_node("Capital Ships").add_child(list)
	for line in group.Lines:
		var row := Button.new()
		var title: String = str(line)
		var cls: String = title
		var cut: int = cls.rfind(" ")
		if cut > 0 and cls.substr(cut + 1).is_valid_int():
			cls = cls.substr(0, cut)
		_Row(row, title, OUI.Mini("units", DefenseWindow._unit_id_named(cls)), [], side, OUI.SideColor(GameSettings.PlayerFaction))
		row.disabled = true
		list.add_child(row)
	_SetPicture(OUI.Pic("status_fleet." + side), null, null)
	_ShowTabs(true)
	_FrameShown()
	_ShowCounts()


## A page's list: in the original's look, in a column that scrolls (by the
## wheel) when the rows run past the panel.
func _PageList(tab: Control) -> VBoxContainer:
	var list := VBoxContainer.new()
	if not _original:
		tab.add_child(list)
		return list
	list.add_theme_constant_override("separation", 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	scroll.add_child(list)
	return list


## The contents panel and everything on it - the frame, the name, the
## counts, the picture, the tabs and their pages - shown or not.
func _PanelVisible(on: bool) -> void:
	if not _original:
		return
	var tabs: TabContainer = get_node("%FleetTabs")
	var body: Node = tabs.get_parent()
	for n in ["Panel", "PictureUnder", "Picture", "PictureOver", "Carried", "Capacity"]:
		var c: CanvasItem = body.get_node_or_null(n)
		if c != null:
			c.visible = on
	(get_node("%SelectedFleetName") as CanvasItem).visible = on
	tabs.visible = on
	for b in tabs.get_meta("tab_strip", []):
		(b as CanvasItem).visible = on
	if not on:
		_FrameShown()


## Nothing to show: the panel empty, every tab greyed.
func _ClearPanel() -> void:
	if not _original:
		return
	_shown = null
	_SetPicture(null, null, null)
	var tabs: TabContainer = get_node("%FleetTabs")
	for i in tabs.get_tab_count():
		var page: Node = tabs.get_child(i)
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	_ShowTabs(true)
	_ShowCounts()


func InitiateFleetMove(fleet: Fleet, uiManager: UIManager, requireConfirmation: bool) -> void:
	uiManager.StartTargeting(func(selectedPlanet: Planet) -> void:
		uiManager.ExecuteSingleFleetMove(fleet, selectedPlanet, requireConfirmation))


# The original confirms before scrapping - "Are you sure you want to scrap
# the following units?" with the item named. Same shape the Economy window
# uses, since scrapping is irreversible and returns only half the material.
func ConfirmScrapShip(ship: Unit, refund: int, onConfirm: Callable, label: String = "") -> void:
	var what: String = label if not label.is_empty() else (ship.Name if ship != null else "this unit")
	ConfirmScrapUnits([what], "Returns %d %s, and the maintenance capacity it was drawing." % [refund, Terms.lower("refined_materials")],
		onConfirm, func() -> void: _PlainConfirmScrapShip(what, refund, onConfirm))


func _PlainConfirmScrapShip(what: String, refund: int, onConfirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Scrap"
	dialog.dialog_text = "Are you sure you want to scrap the following units?\n\n" \
				 + "    %s\n\n" % what \
				 + "Returns %d %s, and the maintenance\n" % [refund, Terms.lower("refined_materials")] \
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
		4:   # Encyclopedia - a fleet has no entry of its own; the Ship database
			uiManager.OpenEncyclopedia()
			var w: EncyclopediaWindow = uiManager._openWindows.get("Encyclopedia")
			if w != null:
				w.ShowIndex(2)


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
	# The original's list miniature, when the player imported it.
	var mini: Texture2D = Art.Miniature("units", unit.PackId)
	if mini != null:
		button.icon = mini
		button.set_meta("miniature", true)
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
