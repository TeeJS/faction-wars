class_name PersonnelFinder
extends DraggableWindow
## frontend/PersonnelFinder.cs - the Personnel Finder (manual p039, p045,
## p098-p100; figs 2.31, 2.39, 3.42-3.43).

var _allianceList: VBoxContainer
var _empireList: VBoxContainer
var _searchBar: LineEdit


func _ready() -> void:
	super()   # Retains drag & close functionality

	_allianceList = get_node("%AllianceList")
	_empireList = get_node("%EmpireList")

	_searchBar = get_node("%SearchBar")

	# Dynamically update the lists every time the user types a letter!
	_searchBar.text_changed.connect(PopulateLists)

	PopulateLists("")   # Initial load of everyone


## UIManager passes itself in so this window can spawn other windows
func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


func PopulateLists(filterText: String) -> void:
	# 1. Clear out the old lists
	for child in _allianceList.get_children():
		child.queue_free()
	for child in _empireList.get_children():
		child.queue_free()

	if GameState.ActiveRoster == null:
		return

	var player: Faction = GameSettings.PlayerFaction
	var lowerFilter: String = filterText.to_lower().strip_edges()

	# --- 2a. OUR OWN SIDE: never fogged from us, so the live location stands. ---
	for c in GameState.ActiveRoster:
		if c.Faction != player:
			continue
		# "NOTE: YOU CANNOT LOCATE LUKE WHEN HE IS AT DAGOBAH, or Han Solo, Luke,
		# Leia, or Chewbacca if they are at Jabba's palace." (p100) Concealment
		# applies to your OWN side; he is simply not findable. Both places count -
		# see Character.IsOffMap.
		if c.IsOffMap():
			continue
		if not lowerFilter.is_empty() and not c.Name.to_lower().contains(lowerFilter):
			continue
		var loc: String = c.Attached.Name if c.Attached != null else "Unknown"
		_AddCharacterRow(c, "%s - %s" % [c.Name, loc], func() -> void: OnCharacterClicked(c))

	# --- 2b. SOMEBODY ELSE'S SIDE: only where we have actually SEEN them. ---
	# ⚠ THE ENEMY'S ROSTER IS NOT FREE INFORMATION, AND THIS WINDOW WAS GIVING IT
	# AWAY. The old code gated an enemy on Knows() AT THEIR LIVE LOCATION - i.e. "we
	# once scouted the world they happen to stand on TODAY", not "we saw them there"
	# - so a player read "Wedge Antilles - Selonia" off a system their sensors had
	# reported nothing new about in weeks. Fig 3.42's list is a record of SIGHTINGS;
	# this rebuilds it from the dated Characters snapshots, showing each enemy at the
	# world and on the day we last saw them, never their live position.
	var seen: Dictionary = _EnemySightings(player)
	for c in GameState.ActiveRoster:
		if c.Faction == null or c.Faction == player:
			continue
		if not seen.has(c.Name):
			continue
		if not lowerFilter.is_empty() and not c.Name.to_lower().contains(lowerFilter):
			continue
		var where: Planet = seen[c.Name]["planet"]
		var day: int = int(seen[c.Name]["day"])
		_AddCharacterRow(c, "%s - %s (day %d)" % [c.Name, where.Name, day], func() -> void: _OpenDefense(where))


## One clickable, coloured row on the correct side tab.
## NOTE: this panel has exactly two lists bound in the scene, so it is still
## 2-faction-shaped. Routing by pack order removes the hardcoded identity, but a
## 3-4 faction pack needs the tabs built dynamically (PROJECT.md, Phase 3 UI item).
func _AddCharacterRow(c: Character, text: String, onClick: Callable) -> void:
	var charBtn := Button.new()
	charBtn.text = text
	charBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	charBtn.flat = true
	var nameColor: Color = c.Faction.FactionColor if c.Faction != null else FactionRegistry.Unknown.FactionColor
	charBtn.add_theme_color_override("font_color", nameColor)
	charBtn.add_theme_font_size_override("font_size", 14)
	charBtn.pressed.connect(onClick)
	var side: int = FactionRegistry.OrderOf(c.Faction)
	if side <= 0:
		_allianceList.add_child(charBtn)
	else:
		_empireList.add_child(charBtn)


## name -> {planet, day}: the most recently seen world for each enemy character,
## read from the dated Characters snapshots (our own worlds' live rosters included -
## who stands on a world WE hold is legitimately ours to see). An agent on a mission
## is hidden and never listed (issue #2a / tests/onmission_fog.gd).
func _EnemySightings(player: Faction) -> Dictionary:
	var out: Dictionary = {}
	for p in GameState.AllPlanets():
		var v: IntelManager.IntelView = IntelManager.View(player, p, Enums.IntelSection.Characters)
		if not v.Known:
			continue
		for line in v.Lines:
			var c: Character = _CharForLine(str(line))
			if c == null or c.Faction == player or c.Status == Enums.Status.OnMission:
				continue
			if not out.has(c.Name) or int(out[c.Name]["day"]) < v.Day:
				out[c.Name] = { "planet": p, "day": v.Day }
	return out


## Match a Characters line ("Name" or "Rank Name") back to a roster entry - the
## line always ends with the character's Name (IntelManager.Render, Characters).
func _CharForLine(line: String) -> Character:
	for c in GameState.ActiveRoster:
		if line == c.Name or line.ends_with(" " + c.Name):
			return c
	return null


## Open a world's Defense window - the destination for an enemy we saw there.
func _OpenDefense(planet: Planet) -> void:
	if _uiManager == null:
		return
	_uiManager.OpenWindow(
		"Defense_%s" % planet.Name,
		_uiManager.DefenseWindowTemplate,
		func(window) -> void: window.Populate(planet, _uiManager),
		Vector2(250, 150))


func OnCharacterClicked(character: Character) -> void:
	if character.Attached == null:
		print("%s is currently unassigned or in transit. No location to display." % character.Name)
		return

	# C# Pattern Matching: Safely checks if the Attached Location is a Planet,
	# and if it is, casts it to the variable 'planet' instantly.
	if character.Attached is Planet:
		var planet: Planet = character.Attached as Planet
		# Route through UIManager to spawn the Defense Window
		_uiManager.OpenWindow(
			"Defense_%s" % planet.Name,
			_uiManager.DefenseWindowTemplate,
			func(window) -> void: window.Populate(planet, _uiManager),
			Vector2(250, 150)   # Slightly offset so it doesn't overlap perfectly
		)
	else:
		# TODO: In the future, check `if (character.Attached is Fleet fleet)`
		print("TODO: %s is on %s (Ship/Fleet). Fleet window not yet implemented." % [character.Name, character.Attached.Name])
