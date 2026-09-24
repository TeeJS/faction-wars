class_name PlanetFinder
extends DraggableWindow
## frontend/PlanetFinder.cs - the Planetary System Finder (manual p075, fig 3.12).
##
## With the art imported it is the original's (src/ui/original_finder.gd):
## "Planetary System Finder" over the System Name field, five tabs - All,
## Rebel, Imperial, Neutral, Unexplored Systems - the list under a band
## naming the tab, and Close and Display down the frame. Typing locates a
## system rather than filtering ("Enter name or part of name to locate a
## specific system in the list"); Display, or a double-click, brings up the
## Sector and Manufacturing windows for the one picked (TeeJ, 2026-09-24:
## "planet info should be renamed System Finder and match the original").

const OF := preload("res://src/ui/original_finder.gd")
## The tabs' pictures (STRATEGY 10500-10513), in the original's order.
const TabStems := ["finder_tab_all", "finder_tab_rebel", "finder_tab_imperial", "finder_tab_neutral", "finder_tab_unexplored"]

var _allList: VBoxContainer
var _allianceList: VBoxContainer
var _empireList: VBoxContainer
var _neutralList: VBoxContainer
var _unexploredList: VBoxContainer
var _searchBar: LineEdit

var _o: Dictionary = {}     # the original's parts (OriginalFinder.Build)
var _tab: int = 0
var _shown: Array = []      # the Planets listed, in the list's order


func _ready() -> void:
	super()
	if OF.CanBuild(["finder_systems"], TabStems, ["finder_display"]):
		_BuildOriginal()
		return

	_allList = get_node("%AllList")
	_allianceList = get_node("%AllianceList")
	_empireList = get_node("%EmpireList")
	_neutralList = get_node("%NeutralList")
	_unexploredList = get_node("%UnexploredList")

	_searchBar = get_node("%SearchBar")
	_searchBar.text_changed.connect(PopulateLists)

	PopulateLists("")


func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


## Which tab a system goes under for us: by what we KNOW of its owner
## (IntelManager.OwnerSeen) - never its live owner - and unexplored when we
## have not charted it. 1 and 2 are the playable sides in pack order.
static func TabOf(planet: Planet) -> int:
	var viewer: Faction = GameSettings.PlayerFaction
	if not planet.ExploredBy(viewer):
		return 4
	var owner: Faction = IntelManager.OwnerSeen(viewer, planet)
	var order: int = FactionRegistry.OrderOf(owner) if owner != null else -1
	if order == 0:
		return 1
	if order > 0:
		return 2
	return 3


## The band over a tab: "All Systems", "Rebel Systems" (the original's word
## for the Alliance's), "Imperial Systems", "Neutral Systems", "Unexplored
## Systems".
static func Caption(tab: int) -> String:
	match tab:
		1, 2:
			var f: Faction = FactionRegistry.Playable[tab - 1] if FactionRegistry.Playable.size() >= tab else null
			if f == null:
				return "Systems"
			return "Rebel Systems" if f.Id == "alliance" else "%s Systems" % f.Adjective
		3:
			return "Neutral Systems"
		4:
			return "Unexplored Systems"
	return "All Systems"


## The systems a tab lists, by name.
static func SystemsOn(tab: int) -> Array:
	var out: Array = []
	if GameState.ActiveGalaxy == null:
		return out
	for sector in GameState.ActiveGalaxy:
		for planet in sector.Planets:
			if tab == 0 or TabOf(planet) == tab:
				out.append(planet)
	out.sort_custom(func(a: Planet, b: Planet) -> bool: return a.Name.naturalnocasecmp_to(b.Name) < 0)
	return out


# ---- the original's ---------------------------------------------------------------

func _BuildOriginal() -> void:
	var tabs: Array = []
	for i in TabStems.size():
		tabs.append([TabStems[i], Caption(i)])
	_o = OF.Build(self, "Planetary System Finder", "System Name", OUI.Pic("finder_systems"), tabs,
		[["finder_display", "Open the Sector and Manufacturing windows for the selected system."]])
	for i in _o["tabs"].size():
		var tab: int = i
		(_o["tabs"][i] as TextureButton).pressed.connect(func() -> void: ShowTab(tab, true))
	(_o["buttons"]["finder_display"] as TextureButton).pressed.connect(Display)
	(_o["list"] as Control).connect("item_activated", func(_i: int) -> void: Display())
	(_o["field"] as LineEdit).text_changed.connect(func(t: String) -> void: OF.Locate(_o["list"], t))
	(_o["field"] as LineEdit).text_submitted.connect(func(_t: String) -> void: Display())
	ShowTab(0, false)


## Show a tab's systems; a tab with none is greyed. `pick` selects the first.
func ShowTab(tab: int, pick: bool) -> void:
	_tab = tab
	var buttons: Array = _o["tabs"]
	for i in buttons.size():
		var b: TextureButton = buttons[i]
		b.set_pressed_no_signal(i == tab)
		# Never greyed for being empty: the original's Imperial Fleets and
		# Imperial Troops tabs stand normal with nothing on them (TeeJ's
		# screenshots, 2026-09-24).
		b.disabled = false
	(_o["header"] as Label).text = Caption(tab)
	var list: Control = _o["list"]
	list.call("clear")
	_shown = SystemsOn(tab)
	for p in _shown:
		list.call("add_item", (p as Planet).Name)
	if pick and not _shown.is_empty():
		list.call("select", 0)
	var typed: String = (_o["field"] as LineEdit).text
	if not typed.strip_edges().is_empty():
		OF.Locate(list, typed)


## The system picked, or null.
func Selected() -> Planet:
	var picked: PackedInt32Array = _o["list"].call("get_selected_items")
	return _shown[picked[0]] if not picked.is_empty() and picked[0] < _shown.size() else null


## "Click on the Display button to bring up the Sector window for the
## highlighted system, or double-click the system name" (p075) - with its
## Manufacturing window (Fig. 3.12: "Open the Sector and Manufacturing
## windows"). The Finder closes behind them, its Close being for "if you
## don't want to bring up a window".
func Display() -> void:
	var p: Planet = Selected()
	if p == null or _uiManager == null:
		return
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(p))
	if sector != null:
		_uiManager.OnSectorClicked(sector)
	_uiManager.OnEconomyClicked(p)
	CloseWindow()


# ---- the plain window ---------------------------------------------------------------

func PopulateLists(filterText: String) -> void:
	# 1. Clear out the old lists
	for child in _allList.get_children():
		child.queue_free()
	for child in _allianceList.get_children():
		child.queue_free()
	for child in _empireList.get_children():
		child.queue_free()
	for child in _neutralList.get_children():
		child.queue_free()
	for child in _unexploredList.get_children():
		child.queue_free()

	if GameState.ActiveGalaxy == null:
		return

	var lowerFilter: String = filterText.to_lower()

	for sector in GameState.ActiveGalaxy:
		for planet in sector.Planets:
			if not lowerFilter.strip_edges().is_empty() and not planet.Name.to_lower().contains(lowerFilter):
				continue

			# Create the clickable button
			var planetBtn := Button.new()
			planetBtn.text = planet.Name
			planetBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			planetBtn.flat = true

			# Replicate original coloring based on exploration and faction
			var nameColor: Color = planet.GetFactionColor()

			planetBtn.add_theme_color_override("font_color", nameColor)
			planetBtn.add_theme_font_size_override("font_size", 14)
			planetBtn.pressed.connect(func() -> void: OnPlanetClicked(sector))

			# Always add to the "All Systems" tab (create a duplicate button)
			_allList.add_child(planetBtn.duplicate() as Button)
			var allBtn: Button = _allList.get_child(_allList.get_child_count() - 1) as Button
			allBtn.pressed.connect(func() -> void: OnPlanetClicked(sector))

			# Filed by what we know of its owner, as the original's tabs are.
			match TabOf(planet):
				1:
					_allianceList.add_child(planetBtn)
				2:
					_empireList.add_child(planetBtn)
				3:
					_neutralList.add_child(planetBtn)
				_:
					_unexploredList.add_child(planetBtn)


func OnPlanetClicked(sector: Sector) -> void:
	# Route through UIManager to spawn the Defense Window
	_uiManager.OpenWindow(
		"%s" % sector.Name,
		_uiManager.SectorWindowTemplate,
		func(window) -> void: window.Populate(sector, _uiManager),
		Vector2(200, 100)
	)
