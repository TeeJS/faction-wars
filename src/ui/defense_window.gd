class_name DefenseWindow
extends DraggableWindow
## frontend/DefenseWindow.cs - the System Defenses window (manual p126, fig
## 3.73): Personnel, Troops, Fighters, Planetary Shield and Planetary Battery
## tabs - the five the manual lists.
##
## With the original's art imported it IS the original's window (TeeJ,
## 2026-09-23, from his screenshots of Chandrila, Coruscant, Yaga Minor,
## Drall and Ajan Kloss): the 235x304 plate, the five tab pictures centred
## on its dark band, each page the original's caption over a grid of cards -
## the miniature, the name under it - and a tab with nothing on it greyed.

var _associatedPlanet: Planet

# Track selected military units ---
var SelectedTroops: Array[Unit] = []
var SelectedFighters: Array[Unit] = []

# Special Forces select on the Personnel tab, separately from the trooper
# regiments they used to be mixed in with (manual p126).
var SelectedSpecForces: Array[Unit] = []

# THE ORIGINAL'S LAYOUT, in its own pixels (drawn OUI.K times as large).
const PlateW := 235
const PlateH := 304
const PagesTop := 53          # the pages start under the plate's tab band
const TabNames := ["personnel", "troops", "fighters", "planetary_shield", "planetary_battery"]
const TabXs := [28, 64, 100, 136, 172]
const TabY := 20
## The original's caption over each page (TEXTSTRA.DLL).
const OriginalCaptions := ["Personnel", "Trooper Regiments", "Fighter Squadrons", "Planetary Shields", "Planetary Batteries"]

var _original: bool = false
var _subject: Planet = null

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
func DrawOwnPersonnel(list: Container, planet: Planet, uiManager: UIManager) -> int:
	var us: Faction = GameSettings.PlayerFaction
	if us == null or GameState.ActiveRoster == null:
		return 0

	# The live branch's own predicate: here and not in transit, OR inbound.
	# Narrowing this to Attached-only dropped your own characters EN ROUTE
	# to a world from that world's Personnel tab, where they had always been
	# listed greyed.
	#
	# A character on a mission is not listed: the ORIGINAL moves them into the
	# Mission window. TeeJ's screenshots of the original (2026-09-23): the
	# Emperor recruiting on Coruscant, gone from Coruscant's Personnel page
	# and shown in its Mission window instead - and the Mission window's
	# "starfield background indicates character is in hyperspace" (p109 Fig
	# 3.51) keeps a team on its way there too. Special Forces the same
	# (DrawOwnUnits).
	var ours: Array = Lq.where(
		Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and not c.IsOffMap()),
		func(c: Character) -> bool: return ((c.Attached == planet and c.Status != Enums.Status.Enroute) \
			or (c.Destination == planet and c.Status == Enums.Status.Enroute)) \
			and not MissionManager.IsOnMissionTeam(c))

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
func DrawUnitRow(list: Container, unit: Unit, uiManager: UIManager,
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
func DrawOwnUnits(list: Container, here: Array,
		uiManager: UIManager, selectionList: Array) -> int:
	var us: Faction = GameSettings.PlayerFaction
	if us == null or here == null:
		return 0

	# A unit on a mission is in the Mission window, not here - the same as a
	# character (TeeJ, 2026-09-24: Special Forces "behave the same as
	# characters"; see DrawOwnPersonnel).
	var ours: Array = Lq.where(here, func(u: Unit) -> bool: return u.Faction == us and not MissionManager.IsOnMissionTeam(u))
	for u in ours:
		DrawUnitRow(list, u, uiManager, selectionList)

	return ours.size()


# Returns true when the caller should go on and draw live rows. Otherwise the
# panel has already been filled in.
static func ShowLive(list: Container, planet: Planet,
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

	var newSubject: bool = _subject != planet
	_subject = planet
	var original: bool = _BuildOriginal()
	# Looked up after the build: the original's grid takes the list's name.
	var _personnelList: Container = get_node_or_null("%PersonnelList")
	# The original titles the window with the system's name alone.
	_titleBarLabel.text = planet.Name if original else " %s Defenses" % planet.Name

	PopulateOrbitalDefenses(_tabs, planet)
	PopulateTroops(_tabs, planet, uiManager)
	PopulateFighters(_tabs, planet, uiManager)
	if _personnelList != null:
		for child in _personnelList.get_children():
			_personnelList.remove_child(child)
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
		if original:
			var personnelPage: Node = _personnelList.get_parent().get_parent()
			OUI.Captions(personnelPage, [OriginalCaptions[0]] if charView.Live or not charView.Known \
				else [OriginalCaptions[0], "Last seen day %d" % charView.Day], PlateW)
		if charView.Live:
			# Query the GameManager's static roster for characters on this planet.
			# OURS ARE ALREADY DRAWN above and unconditionally, so this lists
			# everybody else's - but only those PRESENT now. The inbound clause
			# (Destination == planet while Enroute) applies to OUR OWN personnel
			# only; it must NOT reveal enemy characters in transit to our world,
			# which is fog we have not earned (reported from play: enemy personnel
			# shown en route to a held system). Enemy inbound is invisible until
			# they arrive - or until a mission of theirs is detected.
			var charactersOnPlanet: Array = Lq.where(
				Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction != GameSettings.PlayerFaction),
				func(c: Character) -> bool: return c.Attached == planet and c.Status != Enums.Status.Enroute and c.Status != Enums.Status.OnMission)

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
					_pending_row(_personnelList, pending, uiManager, SelectedSpecForces)
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
				if not IsCardList(_personnelList):
					_personnelList.add_child(HSeparator.new())
					var head := Label.new()
					head.text = "Special forces:"
					head.add_theme_font_size_override("font_size", 10)
					head.add_theme_color_override("font_color", Color.GOLDENROD)
					_personnelList.add_child(head)
				_draw_intel_units(_personnelList, planet, sf, Enums.IntelSection.SpecForces,
					"No special forces seen on the system.")

	if original:
		_GreyEmptyTabs(newSubject)


# ---- THE ORIGINAL'S WINDOW -------------------------------------------------

## Build the original's window once, when its art is imported: the title
## bar, the plate, the tab strip, and the Personnel page's grid (the scene's
## %PersonnelList, moved so its lookups keep working). False without the art.
func _BuildOriginal() -> bool:
	if _original:
		return true
	var side: String = OUI.Side(GameSettings.PlayerFaction)
	if not OUI.Has(["defense_background"]):
		return false
	for n in TabNames:
		if Art.TabIcon(n, side) == null:
			return false
	_original = true
	OUI.TitleBar(self, GameSettings.PlayerFaction)
	var area: MarginContainer = OUI.Flatten(self)
	var body: Control = OUI.Canvas(area, PlateW, PlateH)
	OUI.Place(body, OUI.Pic("defense_background"), 0, 0, "Plate")
	var tabs: TabContainer = get_node("%DefenseTabs")
	tabs.reparent(body, false)
	tabs.tabs_visible = false
	tabs.custom_minimum_size = Vector2.ZERO
	tabs.position = Vector2(0, PagesTop) * OUI.K
	tabs.size = Vector2(PlateW, PlateH - PagesTop) * OUI.K
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	OUI.TabStrip(body, tabs, TabNames, side, TabXs, TabY)
	# Personnel: the page's grid becomes %PersonnelList (the scene's plain
	# list goes), so every lookup of the list finds the cards.
	var old: Node = get_node("%PersonnelList")
	old.unique_name_in_owner = false
	old.get_parent().remove_child(old)
	old.queue_free()
	var grid: HFlowContainer = OUI.Page(tabs.get_node("Personnel"), [OriginalCaptions[0]], PlateW, PlateH - PagesTop)
	grid.name = "PersonnelList"
	grid.owner = self
	grid.unique_name_in_owner = true
	return true


## The grid of a page, for counting what is on it.
func _grid_of(page: Node) -> Node:
	if page.name == "Personnel":
		return get_node_or_null("%PersonnelList")
	return page.get_node_or_null("OriginalPage/Scroll/Grid")


## A tab with nothing on it shows the greyed picture and cannot be picked,
## as the original's does. A new system opens on its first tab with
## something on it.
func _GreyEmptyTabs(newSubject: bool) -> void:
	var tabs: TabContainer = get_node("%DefenseTabs")
	var counts: Array = []
	for i in tabs.get_tab_count():
		tabs.set_tab_disabled(i, false)
		var grid: Node = _grid_of(tabs.get_child(i))
		counts.append(grid.get_child_count() if grid != null else 0)
	if newSubject:
		var first: int = 0
		for i in counts.size():
			if counts[i] > 0:
				first = i
				break
		tabs.current_tab = first
	for i in counts.size():
		tabs.set_tab_disabled(i, counts[i] == 0 and i != tabs.current_tab)
	OUI.RefreshStrip(tabs)


## A page's list: the original's captions over its grid of cards, or the
## plain list headed by the tab's name. A snapshot's day is the second
## caption line (the plain rows carry it themselves).
func _page_list(container: Control, index: int, plainTitle: String, view: IntelManager.IntelView, second: String = "") -> Container:
	if _original:
		var lines: Array = [OriginalCaptions[index]]
		if not second.is_empty():
			lines.append(second)
		elif view != null and view.Known and not view.Live:
			lines.append("Last seen day %d" % view.Day)
		return OUI.Page(container, lines, PlateW, PlateH - PagesTop)
	for child in container.get_children():
		child.queue_free()
	var list := VBoxContainer.new()
	container.add_child(list)
	AddCaption(list, plainTitle)
	return list


## A unit ordered but not yet here: greyed and unselectable.
func _pending_row(list: Container, pending: String, uiManager: UIManager, selection: Array) -> void:
	if not IsCardList(list):
		AddUnitToList(list, null, pending, Color.DARK_GRAY, uiManager, selection)
		return
	# Being built shows the side's grid over the picture, in transit the
	# hyperspace plate - the original's own two states (manual p084).
	var title: String = pending.get_slice("  (", 0)
	OUI.StaticCard(list, title, OUI.Mini("units", _unit_id_named(title)), Color.WHITE, pending,
		"building" if pending.contains("under construction") else "enroute")


## A unit type's pack id by its display name ("" when none matches).
static func _unit_id_named(title: String) -> String:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack == null:
		return ""
	for u in pack.Units:
		if u.DisplayName == title:
			return u.Id
	return ""


## A character's pack id by the name a sighting carries, rank or not.
static func _character_id_named(title: String) -> String:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack == null:
		return ""
	for c in pack.Characters:
		if c.DisplayName == title or title.ends_with(" " + c.DisplayName):
			return c.Id
	return ""


func AddUnitToList(list: Container, unitData: Unit, text: String, color: Color, uiManager: UIManager, selectionList: Array) -> void:
	if unitData == null:
		CreateEmptyLabel(list, text, color)
		return

	# Create the specific Button
	var unitBtn := UnitMenuButton.new()
	unitBtn.text = text
	unitBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The original's list miniature, when the player imported it.
	var mini: Texture2D = Art.Miniature("units", unitData.PackId)
	if mini != null:
		unitBtn.icon = mini
		unitBtn.set_meta("miniature", true)
	# THE ORIGINAL'S CARD (Fig 3.73): the miniature over the unit's name; the
	# status goes to the tooltip.
	if IsCardList(list):
		var cardColor: Color = Color.WHITE if unitData.Faction != null and color == unitData.Faction.FactionColor else color
		OUI.Card(unitBtn, unitData.Name, OUI.Mini("units", unitData.PackId), cardColor,
			OUI.SideColor(GameSettings.PlayerFaction), "enroute" if unitData.Status == Enums.Status.Enroute else "")
		unitBtn.tooltip_text = text
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


## "Planetary Shield: shields protecting the system. Planetary Battery:
## batteries protecting the system" (manual p126 Fig 3.73) - two tabs, as the
## manual has them, split by the facility's role.
func PopulateOrbitalDefenses(tabs: TabContainer, planet: Planet) -> void:
	PopulateDefenceTab(tabs, "Planetary Shield", 3, planet, ["shield"], Terms.lower("planetary_shields"))
	PopulateDefenceTab(tabs, "Planetary Battery", 4, planet, ["anti_ship", "disable"], Terms.lower("orbital_batteries"))


static func _HasAnyRole(f: Facility, roles: Array) -> bool:
	for r in roles:
		if f.HasRole(r):
			return true
	return false


## Which tab a sighting's line belongs on; a line naming no known family
## lands with the batteries.
static func _LineHasAnyRole(line: String, roles: Array) -> bool:
	var t := _defence_type_of(line)
	var d = FacilityCatalog.Get(t, 1) if not t.is_empty() else null
	if d == null:
		return "anti_ship" in roles
	for r in roles:
		if d.HasRole(r):
			return true
	return false


func PopulateDefenceTab(tabs: TabContainer, tabName: String, index: int, planet: Planet, roles: Array, what: String) -> void:
	var container: MarginContainer = tabs.get_node_or_null(tabName)
	if container == null:
		return

	# ROWS, NOT LABELS - because these are SABOTAGE TARGETS. A shield, battery
	# or ion cannon is a facility, and "a sabotage mission destroys a facility"
	# (Encyclopedia; manual p108); the gesture is "select a particular facility
	# to sabotage" (p040). An enemy system's defences are only ever seen here
	# as an intelligence snapshot, and the snapshot was drawn as plain labels,
	# so a system defended only by shields had nothing the crosshair could
	# land on (TeeJ, feedback 2026-09-03T23-56-45, room #198). Same shape as
	# the Manufacturing window's StaleFacilityTab, same approved "small leak".
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.DefensiveFacilities)
	var list: Container = _page_list(container, index, tabName, view)
	if not view.Known:
		return   # nothing seen: an empty page, as the original shows it

	if view.Live:
		var defenses: Array = Lq.where(planet.Facilities, func(f: Facility) -> bool: return IntelManager.IsDefensive(f) and _HasAnyRole(f, roles))
		if defenses.size() == 0:
			_empty_defences(list, "No %s detected." % what)
			return
		for def in defenses:
			_defence_row(list, def.Name() + " (Tier %d)" % def.Tier, def.Family(),
				"[DAMAGED]" if def.IsDamaged else ("[%s]" % Terms.label("shield_active" if def.HasRole("shield") else "weapon_armed")),
				Color.RED if def.IsDamaged else Color.CYAN,
				func() -> Facility: return def, def.Def.Id if def.Def != null else "")
		return

	var lines: Array = Lq.where(view.Lines, func(line) -> bool: return _LineHasAnyRole(str(line), roles))
	if lines.size() == 0:
		_empty_defences(list, "No %s seen." % what)
		return

	# The snapshot: one row per line, re-resolving the nth defence of that
	# type standing there NOW when the crosshair lands on it.
	var world: Planet = planet
	var counted: Dictionary = {}
	for line in lines:
		var type := _defence_type_of(str(line))
		if type.is_empty():
			_defence_row(list, str(line), "", "", Color.LIGHT_GRAY, Callable())
			continue
		var nth: int = int(counted.get(type, 0))
		counted[type] = nth + 1
		var seenDef: PackDefs.FacilityDef = FacilityCatalog.Get(type, 2 if str(line).begins_with("Advanced") else 1)
		_defence_row(list, str(line), type, "(day %d)" % view.Day, Color.LIGHT_GRAY, func() -> Facility:
			var ofType: Array = Lq.where(world.Facilities, func(f: Facility) -> bool: return f.Family() == type)
			return ofType[nth] if nth < ofType.size() else null, seenDef.Id if seenDef != null else "")


static func _defence_type_of(line: String) -> String:
	for d in FacilityCatalog.WithRole("planet_defense"):
		var t: String = d.Family
		var name: String = Facility.NameOf(t)
		if line == name or line == "Advanced %s" % name:
			return t
	return ""


static func _empty_defences(list: Container, text: String) -> void:
	if IsCardList(list):
		return   # the original's grids say nothing when there is nothing
	var empty := Label.new()
	empty.text = text
	empty.add_theme_font_size_override("font_size", 12)
	empty.add_theme_color_override("font_color", Color.GRAY)
	list.add_child(empty)


## One defence row: a flat button the mission crosshair can land on, with its
## status beside it. `resolve` returns the facility to target when clicked
## (null when the sighting is stale and nothing stands there any more).
func _defence_row(list: Container, text: String, family: String, status: String, statusColor: Color, resolve: Callable, packId: String = "") -> void:
	var row := HBoxContainer.new()
	var rowBtn := Button.new()
	rowBtn.text = text
	rowBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rowBtn.flat = true
	rowBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rowBtn.add_theme_font_size_override("font_size", 12)
	rowBtn.set_meta("defence_type", family)
	if IsCardList(list):
		# THE ORIGINAL'S CARD: the facility's miniature over its name
		# ("LNR Series I" on Yaga Minor); the tier and state go to the tooltip.
		OUI.Card(rowBtn, text.get_slice(" (Tier", 0), OUI.Mini("facilities", packId if not packId.is_empty() else family),
			Color.RED if status == "[DAMAGED]" else Color.WHITE, OUI.SideColor(GameSettings.PlayerFaction))
		rowBtn.tooltip_text = "%s %s" % [text, status]
	if resolve.is_valid():
		rowBtn.tooltip_text = (rowBtn.tooltip_text + "\n" if IsCardList(list) else "") \
			+ "With the mission crosshair up, click to make this the Sabotage target."
		rowBtn.pressed.connect(func() -> void:
			# CROSSHAIRS UP: this click names the sabotage target (manual p040).
			if _uiManager == null or not _uiManager.IsTargetingObject():
				return
			var current: Facility = resolve.call()
			if current == null:
				print("[Mission] Nothing answers at that position - the intelligence may be stale.")
				return
			_uiManager.ResolveObjectTarget(current))
	if IsCardList(list):
		list.add_child(rowBtn)
		return
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
func _intel_target_row(list: Container, text: String, day: int, resolve: Callable, mini: Texture2D = null) -> void:
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
	if IsCardList(list):
		# THE ORIGINAL'S CARD for a sighting; the day it was seen is the
		# page's second caption line.
		OUI.Card(rowBtn, text, mini, Color.WHITE, OUI.SideColor(GameSettings.PlayerFaction))
		rowBtn.tooltip_text = "%s (seen day %d)\n%s" % [text, day, rowBtn.tooltip_text]
		list.add_child(rowBtn)
		return
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
## the Planetary Shield and Battery tabs already give facilities.
func _draw_intel_units(list: Container, planet: Planet, view: IntelManager.IntelView, section: int, emptyText: String) -> void:
	if not view.Known:
		return   # nothing seen: an empty page (TeeJ: no "Sensors detect no data")
	if view.Lines.size() == 0:
		_empty_defences(list, emptyText)
		return
	var world: Planet = planet
	var i := 0
	for line in view.Lines:
		var nth := i
		var title: String = str(line)
		var mini: Texture2D = OUI.Mini("characters", _character_id_named(title)) \
			if section == Enums.IntelSection.Characters else OUI.Mini("units", _unit_id_named(title))
		_intel_target_row(list, title, view.Day, func() -> Variant:
			var here: Array = _enemy_here(world, section)
			return here[nth] if nth < here.size() else null, mini)
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

					found.append("%s  (%s)" % [task.UnitRule.DisplayName, state])

	return found


func PopulateTroops(tabs: TabContainer, planet: Planet, uiManager: UIManager) -> void:
	var container: MarginContainer = tabs.get_node_or_null("Troops")
	if container == null:
		return

	# THE GATE IS READ, NOT RETURNED ON. Your own regiments are drawn either
	# way; only the garrison readout and the opponent's units depend on the
	# system still being yours.
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.Troopers)
	var live: bool = view.Live

	# The original's second caption line: "Garrison Requirement: 0" (Fig 3.73;
	# TEXTSTRA.DLL). Present, the uprising and the warning go to its tooltip.
	var list: Container = _page_list(container, 1, "Troops", view,
		("Garrison Requirement: %d" % planet.GarrisonRequirement()) if live else "")
	if live and IsCardList(list):
		var need2: int = planet.GarrisonRequirement()
		var have2: int = planet.TrooperRegiments()
		var cap2: Label = list.get_parent().get_parent().get_node_or_null("Caption2")
		if cap2 != null:
			cap2.tooltip_text = "Present: %d" % have2 \
				+ ("\nUPRISING - production and income halted. Needs %d more regiment(s), or a Subdue Uprising mission." % (need2 - have2) if planet.IsInUprising else "") \
				+ ("\nRemoving a regiment here would trigger an uprising." if need2 > 0 and have2 == need2 else "")

	if live and not IsCardList(list):
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
		_pending_row(list, p, uiManager, SelectedTroops)


func PopulateFighters(tabs: TabContainer, planet: Planet, uiManager: UIManager) -> void:
	var container: MarginContainer = tabs.get_node_or_null("Fighters")
	if container == null:
		return

	# THE CLEAREST CASE OF THE LOT. Neither the uprising flip nor an assault
	# touches FighterSquadrons - the flip counts trooper regiments and the
	# assault defends with them - so your squadrons are still in orbit over
	# a world you have just lost, and this tab used to answer for them with
	# "Sensors detect no data."
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, planet, Enums.IntelSection.Fighters)
	var live: bool = view.Live
	var list: Container = _page_list(container, 2, "Fighters", view)

	var ourFighters: int = DrawOwnUnits(list, planet.FighterSquadrons, uiManager, SelectedFighters)

	if not live:
		# Enemy squadrons seen via intel are legal SABOTAGE targets (manual p108):
		# draw them clickable and dated so the crosshair can land on one.
		_draw_intel_units(list, planet, view, Enums.IntelSection.Fighters,
			"No %s seen in orbit." % Terms.lower("fighter_squadrons"))
		return

	# Ours are already drawn, so this is everybody else's.
	var fighters: Array = Lq.where(planet.FighterSquadrons,
		func(u: Unit) -> bool: return u.Faction != GameSettings.PlayerFaction)
	var pending: Array[String] = PendingFor(planet, Enums.UnitType.Fighter)

	if ourFighters == 0 and fighters.size() == 0 and pending.size() == 0:
		AddUnitToList(list, null, "No %s in orbit." % Terms.lower("fighter_squadrons"), Color.GRAY, uiManager, SelectedFighters)
		return

	for fighter in fighters:
		DrawUnitRow(list, fighter, uiManager, SelectedFighters)

	# Ordered but not yet here. Greyed and unselectable - there is nothing
	# to give orders to yet, and showing them as live units would invite
	# exactly that.
	for p in pending:
		_pending_row(list, p, uiManager, SelectedFighters)


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

		4:   # Encyclopedia - the unit's entry (manual p045 Fig 2.40)
			uiManager.OpenEncyclopedia("units", units[0].PackId)

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

			var scrap := func() -> void:
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
				if is_instance_valid(self):
					Populate(_associatedPlanet, uiManager)
			# The original's own words for units: Scrap, one unit per line.
			ConfirmScrapUnits(Lq.select(doomed, func(u: Unit) -> String: return u.Name),
				"Returns %d %s and the maintenance capacity they were drawing." % [refund, Terms.lower("refined_materials")],
				scrap, func() -> void: ConfirmRetire(what, refund, scrap))

		_:
			print("Unhandled unit menu action %d" % actionId)
