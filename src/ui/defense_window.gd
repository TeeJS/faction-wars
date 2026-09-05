class_name DefenseWindow
extends DraggableWindow
## frontend/DefenseWindow.cs - the System Defenses window (manual p126, fig
## 3.73): Personnel, Troops, Fighters and Orbital Defenses tabs.

var _associatedPlanet: Planet

# Track selected military units ---
var SelectedTroops: Array[Unit] = []
var SelectedFighters: Array[Unit] = []

# Special Forces select on the Personnel tab, separately from the trooper
# regiments they used to be mixed in with (manual p126).
var SelectedSpecForces: Array[Unit] = []

# WHAT THIS WINDOW IS ALLOWED TO SHOW - manual p106.
#
#   "If successful on an enemy or neutral system, the information you see in
#    the Manufacturing/Production and SYSTEM DEFENSE windows for that system
#    is accurate ... a SNAPSHOT that can go stale."
#
# So every panel here is one of three states, and this decides which:
#
#   LIVE     your own system. Current, and the right-click menus mean
#            something because the units answer to you.
#   STALE    somebody else's, and you have intelligence on it. Shows what you
#            last saw, dated, and NOT interactive - there is nothing to order.
#   NOTHING  no intelligence for this category. "Sensors detect no data."
#
# The player's own characters on this world, always visible. Listed before
# the intel gate so that losing sight of a system never loses sight of your
# own people on it.
#
# ⚠ THESE MUST BE REAL ROWS, not labels. The first version of this drew a
# plain Label per character - which meant your own people were the ONLY
# personnel on the tab you could not right-click, so Piett and Veers sat on
# your own capital with no Move, no Mission and no Command menu. Reported
# from play on Kothawui. It goes through DrawCharacterRow like everybody
# else, so a menu can never again exist for the opponent's characters and
# not for yours.
#
# Returns how many were drawn, because the "No personnel present." test
# below counts only what the intel gate yields - and that is everybody
# EXCEPT us. Two of your own officers standing on the world are not "no
# personnel".
func DrawOwnPersonnel(list: VBoxContainer, planet: Planet, uiManager: UIManager) -> int:
	var us: Faction = GameSettings.PlayerFaction
	if us == null or GameState.ActiveRoster == null:
		return 0

	# The live branch's own predicate: here and not in transit, OR inbound.
	# Narrowing this to Attached-only dropped your own characters EN ROUTE
	# to a world from that world's Personnel tab, where they had always been
	# listed greyed.
	var ours: Array = Lq.where(
		Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and not c.IsOffMap()),
		func(c: Character) -> bool: return (c.Attached == planet and c.Status != Enums.Status.Enroute) \
			or (c.Destination == planet and c.Status == Enums.Status.Enroute))

	for c in ours:
		DrawCharacterRow(list, c, uiManager)

	return ours.size()


# THE SAME, FOR UNITS. Troops, fighter squadrons and special forces are
# three tabs' worth of rows that were three copies of one block, and they
# had already drifted: the SpecForce copy grew an "(On Mission - name)"
# branch and the trooper and fighter copies did not - so a regiment sent on
# a mission read as idle on the Troops tab while a commando on the very same
# job read correctly on Personnel. The unit menu offers Mission to all three
# (manual p045), so all three can be on one.
func DrawUnitRow(list: VBoxContainer, unit: Unit, uiManager: UIManager,
		selectionList: Array) -> void:
	var nameColor: Color = unit.Faction.FactionColor if unit.Faction != null else Color.WHITE
	var displayText: String = unit.Name

	if unit.Status == Enums.Status.Enroute:
		displayText += " (Enroute)"
		nameColor = Color.DARK_GRAY   # can't be used yet
	elif unit.Status == Enums.Status.OnMission:
		# Name the job, since a system can host several at once and "there
		# may be more than one mission on a given system" (p109).
		var job: Mission = Lq.first_or_null(MissionManager.Active(),
			func(m: Mission) -> bool: return not m.Finished and m.Team.has(unit))

		displayText += (" (On Mission - %s)" % job.DisplayName()) if job != null \
			else " (On Mission)"
		nameColor = Color.GOLDENROD

	AddUnitToList(list, unit, displayText, nameColor, uiManager, selectionList)


# Your own units on this world, drawn OUTSIDE the intel gate for the same
# reason your own characters are: losing the system does not lose sight of
# what you still have standing on it.
#
# ⚠ THIS IS REACHABLE, and not only in theory. Nothing removes your units
# when a world stops being yours:
#
#   uprising  Planet.cs's flip to neutral requires have == 0, and `have` is
#             TrooperRegiments - it counts Troop only. SpecForces and
#             FighterSquadrons are not consulted and not cleared.
#   assault   AssaultManager defends with Garrison.Where(Type == Troop) and
#             removes only the units it killed. FighterSquadrons is never
#             touched by it at all.
#
# So a captured or revolted world keeps your squadrons in orbit and your
# commandos on the ground, still costing you maintenance, while the tab that
# should list them said "Sensors detect no data".
#
# Returns the count, because every emptiness test below is written against
# what the gate yields - which is deliberately everybody EXCEPT us.
func DrawOwnUnits(list: VBoxContainer, here: Array,
		uiManager: UIManager, selectionList: Array) -> int:
	var us: Faction = GameSettings.PlayerFaction
	if us == null or here == null:
		return 0

	var ours: Array = Lq.where(here, func(u: Unit) -> bool: return u.Faction == us)
	for u in ours:
		DrawUnitRow(list, u, uiManager, selectionList)

	return ours.size()


# Returns true when the caller should go on and draw live rows. Otherwise the
# panel has already been filled in.
static func ShowLive(list: VBoxContainer, planet: Planet,
		section: int, emptyText: String) -> bool:
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, section)
	if view.Live:
		return true

	if not view.Known:
		var none := Label.new()
		none.text = "Sensors detect no data."
		none.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(none)
		return false

	if view.Lines.size() == 0:
		var empty := Label.new()
		empty.text = emptyText
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(empty)
		return false

	for line in view.Lines:
		var row := Label.new()
		row.text = line
		row.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		list.add_child(row)

	return false


func Populate(planet: Planet, uiManager: UIManager) -> void:
	_associatedPlanet = planet
	_uiManager = uiManager
	for c in SelectedCharacters.duplicate():
		if c.Attached != planet or c.Status == Enums.Status.Enroute:
			SelectedCharacters.erase(c)
	for u in SelectedTroops.duplicate():
		if u.Attached != planet or u.Status == Enums.Status.Enroute:
			SelectedTroops.erase(u)
	for u in SelectedFighters.duplicate():
		if u.Attached != planet or u.Status == Enums.Status.Enroute:
			SelectedFighters.erase(u)
	# Not dropped when OnMission - a SpecForce on station is still standing
	# on this system and still has orders that can be given to it.
	for u in SelectedSpecForces.duplicate():
		if u.Attached != planet or u.Status == Enums.Status.Enroute:
			SelectedSpecForces.erase(u)

	var _titleBarLabel: Label = get_node("%TitleBarLabel")
	var _tabs: TabContainer = get_node("%DefenseTabs")
	var _personnelList: VBoxContainer = get_node_or_null("%PersonnelList")

	_titleBarLabel.text = " %s Defenses" % planet.Name

	PopulateOrbitalDefenses(_tabs, planet)
	PopulateTroops(_tabs, planet, uiManager)
	PopulateFighters(_tabs, planet, uiManager)
	if _personnelList != null:
		for child in _personnelList.get_children():
			child.queue_free()

		# THE ONE TAB RECONNAISSANCE CANNOT FILL. "Does not reveal characters
		# or SpecForces present" (manual p107) - so a scouted world shows its
		# batteries and its garrison here and still nothing at all about who
		# is standing on it. Only an Espionage mission or an informant does
		# that, which is the whole reason the two missions are different.
		#
		# Two sections, one tab: characters and special forces are separate
		# categories in the game's own family ranges (160..175 against
		# 48..63) and an informant can hand over one without the other.
		# ⚠ YOUR OWN PEOPLE ARE NEVER FOGGED FROM YOU. This gated the WHOLE
		# section, so when a world went neutral under an uprising the tab
		# read "Sensors detect no data" while the player's own character was
		# still standing on it - and the Personnel Finder cheerfully listed
		# him at the same moment. Reported from play: Piett on Drall.
		#
		# Intel is about what the ENEMY has there. Ours is drawn first and
		# unconditionally; the gate below then decides whether anything
		# further can be seen.
		var ourPersonnel: int = DrawOwnPersonnel(_personnelList, planet, uiManager)

		# OUR SPECIAL FORCES ARE OURS TOO. They were drawn inside the gate
		# below while the characters beside them were drawn outside it, and
		# they are the ones that actually survive a world changing hands -
		# neither the uprising flip nor an assault removes them, because
		# both count trooper regiments only.
		ourPersonnel += DrawOwnUnits(_personnelList, planet.SpecForces(),
			uiManager, SelectedSpecForces)

		var charView: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.Characters)
		if charView.Live:
			# Query the GameManager's static roster for characters on this planet
			# OURS ARE ALREADY DRAWN above and unconditionally, so this
			# lists only what intel has bought us: everybody else's.
			var charactersOnPlanet: Array = Lq.where(
				Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction != GameSettings.PlayerFaction),
				func(c: Character) -> bool: return (c.Attached == planet and c.Status != Enums.Status.Enroute) \
					or (c.Destination == planet and c.Status == Enums.Status.Enroute))

			# "PERSONNEL: characters AND SPECIAL FORCES on the system"
			# (manual p126, fig 3.73). This tab listed characters only, so a
			# Bothan Spy or a probe droid appeared nowhere on it - they were
			# being drawn on the Troops tab instead, which the same figure
			# reserves for trooper regiments.
			# OURS ARE ALREADY DRAWN, as the characters above are.
			var specForcesOnPlanet: Array = Lq.where(planet.SpecForces(),
				func(u: Unit) -> bool: return u.Faction != GameSettings.PlayerFaction)
			var specForcesPending: Array[String] = PendingFor(planet, Enums.UnitType.SpecForce)

			# ourPersonnel COUNTS TOO. Without it this tested only what the
			# intel gate yields - which is deliberately everybody EXCEPT
			# us - so a world holding nothing but your own officers read
			# "No personnel present." directly underneath their names.
			# Reported from play: Piett and Veers on Kothawui.
			if ourPersonnel == 0 and charactersOnPlanet.size() == 0 \
					and specForcesOnPlanet.size() == 0 \
					and specForcesPending.size() == 0:
				AddCharacterToList(_personnelList, null, "No personnel present.", Color.GRAY, uiManager)
			else:
				for character in charactersOnPlanet:
					DrawCharacterRow(_personnelList, character, uiManager)

				# Special Forces, on the same tab and below the characters.
				# They get the UNIT menu, which is the manual's own: "Move,
				# Confirmed Move, Mission, Encyclopedia, Status, Retire"
				# (p045) - so a Longprobe or a probe droid can be given the
				# only job it has from the list it now appears in.
				for sf in specForcesOnPlanet:
					DrawUnitRow(_personnelList, sf, uiManager, SelectedSpecForces)

				# Ordered but not arrived. Greyed and unselectable, the same
				# way the Troops and Fighter tabs show theirs - there is
				# nothing to give orders to yet.
				for pending in specForcesPending:
					AddUnitToList(_personnelList, null, pending, Color.DARK_GRAY, uiManager, SelectedSpecForces)
		else:
			# NOT LIVE: an enemy system seen only through intel. Draw the character
			# snapshot as clickable, dated ABDUCTION/ASSASSINATION targets (the crosshair
			# could not land on a plain label before - reported from play). Special
			# forces are a SEPARATE category (an informant can hand over one without the
			# other) and get their own clickable section below, as SABOTAGE targets.
			_draw_intel_units(_personnelList, planet, charView, Enums.IntelSection.Characters,
				"No personnel seen on the system.")
			var sf: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet,
				Enums.IntelSection.SpecForces)
			if sf.Known and sf.Lines.size() > 0:
				_personnelList.add_child(HSeparator.new())
				var head := Label.new()
				head.text = "Special forces:"
				head.add_theme_font_size_override("font_size", 10)
				head.add_theme_color_override("font_color", Color.GOLDENROD)
				_personnelList.add_child(head)
				_draw_intel_units(_personnelList, planet, sf, Enums.IntelSection.SpecForces,
					"No special forces seen on the system.")


func AddUnitToList(list: VBoxContainer, unitData: Unit, text: String, color: Color, uiManager: UIManager, selectionList: Array) -> void:
	if unitData == null:
		CreateEmptyLabel(list, text, color)
		return

	# Create the specific Button
	var unitBtn := UnitMenuButton.new()
	unitBtn.text = text
	unitBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	unitBtn.UnitData = unitData
	unitBtn.UIManagerRef = uiManager
	unitBtn.ParentWindow = self
	unitBtn.SelectionGroup = selectionList
	unitBtn.add_theme_color_override("font_color", color)
	unitBtn.add_theme_font_size_override("font_size", 16)

	# Create the specific Menu
	var popup := PopupMenu.new()
	popup.add_item("Move", 0)
	popup.add_item("Confirmed Move", 1)
	# "A unit's right-click menu is: Move, Confirmed Move, MISSION,
	# Encyclopedia, Status, Retire" (manual p045). Mission was absent, so a
	# recon craft had no way to be given the only job it can do.
	# Only offered to units that can actually run one. A trooper regiment,
	# fighter squadron or capital ship performs no missions at all, and the
	# original shows them no Mission item - just Move, Confirmed Move,
	# Encyclopedia, Status and Scrap.
	if unitData.Faction == GameSettings.PlayerFaction \
			and MissionManager.CanEverPerformMissions(unitData):
		popup.add_item("Mission", 2)
	popup.add_item("Encyclopedia", 4)
	popup.add_item("Status", 5)

	# "A unit's right-click menu is: Move, Confirmed Move, Mission,
	# Encyclopedia, Status, RETIRE" (manual p045, and Fig 2.40 on that page
	# shows exactly this menu on a Longprobe team).
	#
	# LIVE, and unconditional. It was greyed on the reasoning that Retire is
	# the manual's answer to a traitor and so waits on the loyalty system -
	# but that is the CHARACTER case (p094). Retiring a troop or a SpecForce
	# is just disbanding it, has no prerequisite, and always has had none.
	if unitData.Faction == GameSettings.PlayerFaction:
		popup.add_item("Retire", 6)
		popup.set_item_disabled(popup.get_item_index(6), unitData.Status == Enums.Status.Enroute)

	# Let the Generic Helper wire it all together!
	SetupMenuButton(unitBtn, unitData, selectionList, popup,
		func(id: int, targets: Array) -> void: OnUnitMenuAction(id, targets, uiManager))

	list.add_child(unitBtn)


func _gui_input(event: InputEvent) -> void:
	# Intercept left clicks on the window itself
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _uiManager != null and _uiManager.IsTargeting:
			_uiManager.ResolveTarget(_associatedPlanet)
			accept_event()   # Stops the click from doing anything else (like dragging)
			return

	# C#: base._GuiInput(@event) - Control's own no-op; DraggableWindow defines
	# no _GuiInput (its drag lives on the title bar's gui_input signal), so
	# GDScript refuses super() here. Nothing to forward.


func StateSignature() -> Variant:
	return GameSignature.ForPlanet(_associatedPlanet)


func Refresh() -> void:
	# --- If a popup menu is open, silently abort and set the deferred flag! ---
	if not CanRefresh():
		return

	if _associatedPlanet != null and _uiManager != null:
		Populate(_associatedPlanet, _uiManager)


# Allow the DefenseWindow to accept dropped characters
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (str(data) == "character_move" and _uiManager != null and not _uiManager.DraggedCharacters.is_empty()) \
		or (str(data) == "unit_move" and _uiManager != null and not _uiManager.DraggedUnits.is_empty())


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if str(data) == "character_move" and _uiManager != null and not _uiManager.DraggedCharacters.is_empty():
		var dragGroup: Array = _uiManager.DraggedCharacters
		_uiManager.EndCharacterDrag()
		_uiManager.ExecuteCharacterMove(dragGroup, _associatedPlanet, false)
	elif str(data) == "unit_move" and _uiManager != null and not _uiManager.DraggedUnits.is_empty():
		var dragGroup: Array = _uiManager.DraggedUnits
		_uiManager.EndUnitDrag()
		_uiManager.ExecuteUnitMove(dragGroup, _associatedPlanet, false)


func PopulateOrbitalDefenses(tabs: TabContainer, planet: Planet) -> void:
	var container: MarginContainer = tabs.get_node_or_null("Orbital Defenses")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	var list := VBoxContainer.new()
	container.add_child(list)

	# ROWS, NOT LABELS - because these are SABOTAGE TARGETS. A shield, battery
	# or ion cannon is a facility, and "a sabotage mission destroys a facility"
	# (Encyclopedia; manual p108); the gesture is "select a particular facility
	# to sabotage" (p040). An enemy system's defences are only ever seen here
	# as an intelligence snapshot, and the snapshot was drawn as plain labels,
	# so a system defended only by shields had nothing the crosshair could
	# land on (TeeJ, feedback 2026-09-03T23-56-45, room #198). Same shape as
	# the Manufacturing window's StaleFacilityTab, same approved "small leak".
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.DefensiveFacilities)
	if not view.Known:
		var none := Label.new()
		none.text = "Sensors detect no data."
		none.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(none)
		return

	if view.Live:
		var defenses: Array = Lq.where(planet.Facilities, IntelManager.IsDefensive)
		if defenses.size() == 0:
			_empty_defences(list, "No orbital batteries or planetary shields detected.")
			return
		for def in defenses:
			_defence_row(list, def.Name() + " (Tier %d)" % def.Tier, def.Type,
				"[DAMAGED]" if def.IsDamaged else ("[Active Shielding]" if def.Type == Enums.FacilityType.PlanetaryShield else "[Weapon Armed]"),
				Color.RED if def.IsDamaged else Color.CYAN,
				func() -> Facility: return def)
		return

	if view.Lines.size() == 0:
		_empty_defences(list, "No orbital batteries or planetary shields seen.")
		return

	# The snapshot: one row per line, re-resolving the nth defence of that
	# type standing there NOW when the crosshair lands on it.
	var world: Planet = planet
	var counted: Dictionary = {}
	for line in view.Lines:
		var type := _defence_type_of(str(line))
		if type < 0:
			_defence_row(list, str(line), -1, "", Color.LIGHT_GRAY, Callable())
			continue
		var nth: int = int(counted.get(type, 0))
		counted[type] = nth + 1
		_defence_row(list, str(line), type, "(day %d)" % view.Day, Color.LIGHT_GRAY, func() -> Facility:
			var ofType: Array = Lq.where(world.Facilities, func(f: Facility) -> bool: return f.Type == type)
			return ofType[nth] if nth < ofType.size() else null)


static func _defence_type_of(line: String) -> int:
	for t in [Enums.FacilityType.PlanetaryShield, Enums.FacilityType.TurbolaserBattery, Enums.FacilityType.IonCannon]:
		var name: String = Facility.NameOf(t)
		if line == name or line == "Advanced %s" % name:
			return t
	return -1


static func _empty_defences(list: VBoxContainer, text: String) -> void:
	var empty := Label.new()
	empty.text = text
	empty.add_theme_font_size_override("font_size", 12)
	empty.add_theme_color_override("font_color", Color.GRAY)
	list.add_child(empty)


## One defence row: a flat button the mission crosshair can land on, with its
## status beside it. `resolve` returns the facility to target when clicked
## (null when the sighting is stale and nothing stands there any more).
func _defence_row(list: VBoxContainer, text: String, type: int, status: String, statusColor: Color, resolve: Callable) -> void:
	var row := HBoxContainer.new()
	var rowBtn := Button.new()
	rowBtn.text = text
	rowBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rowBtn.flat = true
	rowBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rowBtn.add_theme_font_size_override("font_size", 12)
	rowBtn.set_meta("defence_type", type)
	if resolve.is_valid():
		rowBtn.tooltip_text = "With the mission crosshair up, click to make this the Sabotage target."
		rowBtn.pressed.connect(func() -> void:
			# CROSSHAIRS UP: this click names the sabotage target (manual p040).
			if _uiManager == null or not _uiManager.IsTargetingObject():
				return
			var current: Facility = resolve.call()
			if current == null:
				print("[Mission] Nothing answers at that position - the intelligence may be stale.")
				return
			_uiManager.ResolveObjectTarget(current))
	row.add_child(rowBtn)
	if not status.is_empty():
		var statusLbl := Label.new()
		statusLbl.text = status
		statusLbl.add_theme_font_size_override("font_size", 11)
		statusLbl.add_theme_color_override("font_color", statusColor)
		row.add_child(statusLbl)
	list.add_child(row)


## A clickable row for an ENEMY sighting seen only through intel (a stale snapshot).
## The mission crosshair lands on it and names the resolved object as the target -
## a Character for Abduction/Assassination, a regiment/squadron/facility for
## Sabotage (all handled by UIManager.ResolveObjectTarget -> the Create Mission
## flow). `resolve` returns the live object standing there NOW, or null if the
## sighting is stale and it has since moved. The "(seen day N)" marker makes the
## snapshot's age plain, so a unit that has moved is not mistaken for being in two
## places at once.
func _intel_target_row(list: VBoxContainer, text: String, day: int, resolve: Callable) -> void:
	var row := HBoxContainer.new()
	var rowBtn := Button.new()
	rowBtn.text = text
	rowBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rowBtn.flat = true
	rowBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rowBtn.add_theme_font_size_override("font_size", 12)
	rowBtn.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	rowBtn.set_meta("intel_target", true)
	rowBtn.tooltip_text = "With the mission crosshair up, click to make this the mission target."
	rowBtn.pressed.connect(func() -> void:
		if _uiManager == null or not _uiManager.IsTargetingObject():
			return
		var current: Variant = resolve.call()
		if current == null:
			print("[Mission] Nothing answers at that position - the intelligence may be stale.")
			return
		_uiManager.ResolveObjectTarget(current))
	row.add_child(rowBtn)
	var dayLbl := Label.new()
	dayLbl.text = "(seen day %d)" % day
	dayLbl.add_theme_font_size_override("font_size", 11)
	dayLbl.add_theme_color_override("font_color", Color.DARK_GRAY)
	row.add_child(dayLbl)
	list.add_child(row)


## The live enemy characters, regiments or squadrons standing on `planet` now, in
## the order intel rendered them, so an intel line's nth entry resolves to the nth
## object of its kind. Fog-legal: the ROW is only drawn from the snapshot; this just
## re-binds a click to the current object (null if it has moved on).
static func _enemy_here(planet: Planet, section: int) -> Array:
	var us: Faction = GameSettings.PlayerFaction
	match section:
		Enums.IntelSection.Characters:
			return Lq.where(GameState.ActiveRoster, func(c: Character) -> bool:
				return c.Faction != us and c.Attached == planet and c.Status != Enums.Status.Enroute \
					and not c.IsOffMap() and c.Status != Enums.Status.Dead)
		Enums.IntelSection.Troopers:
			return Lq.where(planet.Troopers(), func(u: Unit) -> bool: return u.Faction != us)
		Enums.IntelSection.Fighters:
			return Lq.where(planet.FighterSquadrons, func(u: Unit) -> bool: return u.Faction != us)
		Enums.IntelSection.SpecForces:
			return Lq.where(planet.SpecForces(), func(u: Unit) -> bool: return u.Faction != us)
	return []


## Draw an enemy system's intel snapshot for one section as clickable, dated target
## rows (each resolves to the live nth object of its kind). Used for the Personnel,
## Troops and Fighters tabs so the mission crosshair can land on an enemy character
## (abduction/assassination) or regiment/squadron (sabotage) - the same treatment
## the Orbital Defenses tab already gives facilities.
func _draw_intel_units(list: VBoxContainer, planet: Planet, view: IntelManager.IntelView, section: int, emptyText: String) -> void:
	if not view.Known:
		var none := Label.new()
		none.text = "Sensors detect no data."
		none.add_theme_color_override("font_color", Color.GRAY)
		list.add_child(none)
		return
	if view.Lines.size() == 0:
		_empty_defences(list, emptyText)
		return
	var world: Planet = planet
	var i := 0
	for line in view.Lines:
		var nth := i
		_intel_target_row(list, str(line), view.Day, func() -> Variant:
			var here: Array = _enemy_here(world, section)
			return here[nth] if nth < here.size() else null)
		i += 1


# Units ORDERED but not yet standing here: still being built, or built and
# riding a transport in.
#
# The manual shows work in progress in the Manufacturing and Production
# window - a facility under construction is "surrounded by a grid" there
# (Fig 2.21) - and says nothing about the System Defenses window. This is an
# addition: a list of what defends a system that silently omits the six
# regiments arriving next week is answering the wrong question, and the
# player has to hold that in their head instead.
#
# Every planet's queues are searched, not just this one's, because the thing
# that matters is the DESTINATION - a regiment trained on Coruscant for
# Bespin belongs in Bespin's list, not Coruscant's.
static func PendingFor(here: Planet, kind: int) -> Array[String]:
	var found: Array[String] = []
	if GameState.ActiveGalaxy == null:
		return found

	for sector in GameState.ActiveGalaxy:
		for source in sector.Planets:
			for queue in [source.ShipyardQueue, source.TrainingQueue, source.BuildingQueue]:
				for task in queue:
					if task.UnitRule == null or task.Destination != here:
						continue

					# EXACT match on the category now. This used to fold
					# SpecForce into Troop, because both land in the garrison
					# and the Troops tab was the only place either was shown.
					# Now that Personnel lists SpecForces where the manual
					# puts them (p126), an incoming probe droid must be
					# pending on THAT tab, not among the trooper regiments.
					if MilitaryCatalog.TypeOf(task.UnitRule) != kind:
						continue

					# Built already - what remains is the journey (manual's
					# "Best Time To Deployment", p045).
					var state: String = ("in transit from %s, %dd out" % [source.Name, task.TransportDays]) \
						if task.Progress >= task.TotalWork \
						else ("under construction at %s, %d%%" % [source.Name, task.PercentComplete()])

					found.append("%s  (%s)" % [task.UnitRule.Name, state])

	return found


func PopulateTroops(tabs: TabContainer, planet: Planet, uiManager: UIManager) -> void:
	var container: MarginContainer = tabs.get_node_or_null("Troops")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	var list := VBoxContainer.new()
	container.add_child(list)

	# THE GATE IS READ, NOT RETURNED ON. Your own regiments are drawn either
	# way; only the garrison readout and the opponent's units depend on the
	# system still being yours.
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.Troopers)
	var live: bool = view.Live

	if live:
		# "Garrison requirements are stated in the Trooper Regiment tab of the
		# System Defenses window. A garrison requirement of two means you need
		# at least two troopers on the system to keep control." (manual p090)
		var need: int = planet.GarrisonRequirement()
		var have: int = planet.TrooperRegiments()

		var garrison := Label.new()
		garrison.text = "Garrison Requirement: %d   (present: %d)" % [need, have]
		garrison.add_theme_font_size_override("font_size", 12)
		garrison.add_theme_color_override("font_color",
			Color.LIGHT_GREEN if have >= need else Color.INDIAN_RED)
		list.add_child(garrison)

		if planet.IsInUprising:
			# The requirement DOUBLES while an uprising runs (manual p127), so
			# say what it takes to end it rather than only that one exists.
			var flare := Label.new()
			flare.text = "⚑ UPRISING - production and income halted.\n" \
				+ "    Needs %d more regiment(s), or a Subdue Uprising mission." % (need - have)
			flare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			flare.add_theme_font_size_override("font_size", 11)
			flare.add_theme_color_override("font_color", Color.ORANGE)
			list.add_child(flare)
		elif need > 0 and have == need:
			var warn := Label.new()
			warn.text = "Removing a regiment here would trigger an uprising."
			warn.add_theme_font_size_override("font_size", 10)
			warn.add_theme_color_override("font_color", Color.GOLDENROD)
			list.add_child(warn)

		list.add_child(HSeparator.new())

	# YOURS FIRST, AND WHETHER OR NOT THE SYSTEM IS STILL YOURS.
	var ourTroops: int = DrawOwnUnits(list, planet.Troopers(), uiManager, SelectedTroops)

	if not live:
		# Enemy regiments seen via intel are legal SABOTAGE targets (manual p108):
		# draw them clickable and dated so the crosshair can land on one.
		_draw_intel_units(list, planet, view, Enums.IntelSection.Troopers,
			"No ground troops seen on the system.")
		return

	# TROOPER REGIMENTS ONLY. "Troops: trooper regiments on the system, and
	# the garrison requirement if any" (manual p126, fig 3.73) - Special
	# Forces belong on the Personnel tab of the same window and are listed
	# there now. This iterated the whole garrison, so every probe droid,
	# Bothan Spy and commando was drawn here as though it were a regiment.
	#
	# Ours are already drawn, so this is everybody else's.
	var troopers: Array = Lq.where(planet.Troopers(),
		func(u: Unit) -> bool: return u.Faction != GameSettings.PlayerFaction)
	var pending: Array[String] = PendingFor(planet, Enums.UnitType.Troop)

	if ourTroops == 0 and troopers.size() == 0 and pending.size() == 0:
		AddUnitToList(list, null, "No ground troops stationed here.", Color.GRAY, uiManager, SelectedTroops)
		return

	for troop in troopers:
		DrawUnitRow(list, troop, uiManager, SelectedTroops)

	# Ordered but not yet here. Greyed and unselectable - there is nothing
	# to give orders to yet, and showing them as live units would invite
	# exactly that.
	for p in pending:
		AddUnitToList(list, null, p, Color.DARK_GRAY, uiManager, SelectedTroops)


func PopulateFighters(tabs: TabContainer, planet: Planet, uiManager: UIManager) -> void:
	var container: MarginContainer = tabs.get_node_or_null("Fighters")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	var list := VBoxContainer.new()
	container.add_child(list)

	# THE CLEAREST CASE OF THE LOT. Neither the uprising flip nor an assault
	# touches FighterSquadrons - the flip counts trooper regiments and the
	# assault defends with them - so your squadrons are still in orbit over
	# a world you have just lost, and this tab used to answer for them with
	# "Sensors detect no data."
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.Fighters)
	var live: bool = view.Live

	var ourFighters: int = DrawOwnUnits(list, planet.FighterSquadrons, uiManager, SelectedFighters)

	if not live:
		# Enemy squadrons seen via intel are legal SABOTAGE targets (manual p108):
		# draw them clickable and dated so the crosshair can land on one.
		_draw_intel_units(list, planet, view, Enums.IntelSection.Fighters,
			"No fighter squadrons seen in orbit.")
		return

	# Ours are already drawn, so this is everybody else's.
	var fighters: Array = Lq.where(planet.FighterSquadrons,
		func(u: Unit) -> bool: return u.Faction != GameSettings.PlayerFaction)
	var pending: Array[String] = PendingFor(planet, Enums.UnitType.Fighter)

	if ourFighters == 0 and fighters.size() == 0 and pending.size() == 0:
		AddUnitToList(list, null, "No fighter squadrons in orbit.", Color.GRAY, uiManager, SelectedFighters)
		return

	for fighter in fighters:
		DrawUnitRow(list, fighter, uiManager, SelectedFighters)

	# Ordered but not yet here. Greyed and unselectable - there is nothing
	# to give orders to yet, and showing them as live units would invite
	# exactly that.
	for p in pending:
		AddUnitToList(list, null, p, Color.DARK_GRAY, uiManager, SelectedFighters)


func OnUnitMenuAction(actionId: int, units: Array, uiManager: UIManager) -> void:
	if units == null or units.size() == 0:
		return

	match actionId:
		0, 1:   # Move, Confirmed Move
			if TransitEligible(units):
				var currentPlanet: Planet = OrderManager.SystemOf(units[0].Attached)
				if currentPlanet == null:
					return

				# A SYSTEM OR A FLEET, exactly as for characters: "anything
				# movable - character, fleet, troop, SpecForce - can be
				# dragged to its destination instead of using Move"
				# (manual p046-p052), and a fleet is a legal destination
				# (p110). LoadAboard enforces the rules itself: same
				# orbit, same side, and room in a hangar.
				uiManager.StartTargetingObject(
					func(selectedPlanet: Planet) -> void:
						uiManager.ExecuteUnitMove(units, selectedPlanet, actionId == 1),
					func(picked: Variant) -> void:
						var fleet: Fleet = OrderManager.FleetOf(picked)
						if fleet == null:
							print("[Move] That is not somewhere a unit can be sent.")
							return
						var r: Result = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units(units), "fleet": fleet.Name })
						if r.value == 0 and not r.error.is_empty():
							print("[Move] %s" % r.error))

		2:   # Mission - same flow as a character's, targets first.
			if TransitEligible(units):
				StartMissionTargeting(units, uiManager)

		4:   # Encyclopedia
			print("Opening Encyclopedia for %s" % units[0].Name)

		5:   # Status
			for u in units:
				uiManager.OpenUnitStatusWindow(u)

		6:   # Retire
			# RETIRING A UNIT IS UNCONDITIONAL. Fig 2.40 on manual p045 shows
			# it plainly on a Longprobe team's own menu - Move, Confirmed
			# Move, Mission, Encyclopedia, Status, Retire - with no
			# prerequisite of any kind.
			#
			# This was greyed out on the reasoning that Retire is the answer
			# to a traitor and therefore waits on the loyalty system. That
			# conflated two different things: retiring a CHARACTER is how the
			# manual says you deal with one who has turned (p094), but
			# retiring a TROOP or a SpecForce is simply disbanding it, and it
			# has always been available.
			#
			# Routed through ScrapUnit because that is what disbanding does
			# here: it takes the unit off the system and returns the measured
			# half of its construction cost and all of its maintenance.
			var doomed: Array = units.duplicate()
			var refund: int = Lq.sum(doomed, func(u: Unit) -> int: return u.ConstructionCost * Planet.ScrapRefundPercent / 100)
			var what: String = doomed[0].Name if doomed.size() == 1 \
				else "%d units" % doomed.size()

			ConfirmRetire(what, refund, func() -> void:
				for u in doomed:
					# The ORBIT world for anything riding a fleet - the
					# cast this replaced was null for a loaded unit, so
					# ScrapUnit was never even called on it.
					var orbit: Planet = OrderManager.SystemOf(u.Attached)
					if orbit != null:
						CommandBus.issue("scrap_unit", { "unit": u.Serial })
					SelectedTroops.erase(u)
					SelectedSpecForces.erase(u)
					SelectedFighters.erase(u)
				Populate(_associatedPlanet, uiManager))

		_:
			print("Unhandled unit menu action %d" % actionId)
