class_name PlanetFinder
extends DraggableWindow
## frontend/PlanetFinder.cs - the Planetary System Finder (manual p075, fig 3.12).

var _allList: VBoxContainer
var _allianceList: VBoxContainer
var _empireList: VBoxContainer
var _neutralList: VBoxContainer
var _unexploredList: VBoxContainer
var _searchBar: LineEdit


func _ready() -> void:
	super()

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

	# 2. Extract all planets from the nested Sector lists
	# var allPlanets = GameManager.ActiveGalaxy.SelectMany(s => s.Planets).ToList();

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

			# 3. Categorize into the tabs

			# Always add to the "All Systems" tab (create a duplicate button)
			_allList.add_child(planetBtn.duplicate() as Button)
			var allBtn: Button = _allList.get_child(_allList.get_child_count() - 1) as Button
			allBtn.pressed.connect(func() -> void: OnPlanetClicked(sector))

			# Add to the specific faction/status tab
			if not planet.IsExplored:
				_unexploredList.add_child(planetBtn)
			# See PersonnelFinder: two scene-bound lists, so routing is by
			# pack order until the tabs are built dynamically (Phase 3).
			elif FactionRegistry.OrderOf(planet.ControllingFaction) == 0:
				_allianceList.add_child(planetBtn)
			elif FactionRegistry.OrderOf(planet.ControllingFaction) > 0:
				_empireList.add_child(planetBtn)
			else:
				_neutralList.add_child(planetBtn)


func OnPlanetClicked(sector: Sector) -> void:
	# Route through UIManager to spawn the Defense Window
	_uiManager.OpenWindow(
		"%s" % sector.Name,
		_uiManager.SectorWindowTemplate,
		func(window) -> void: window.Populate(sector, _uiManager),
		Vector2(200, 100)
	)
