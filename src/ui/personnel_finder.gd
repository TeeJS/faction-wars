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

	var lowerFilter: String = filterText.to_lower()

	# 2. Iterate and Filter the global roster
	for c in GameState.ActiveRoster:
		# "NOTE: YOU CANNOT LOCATE LUKE WHEN HE IS AT DAGOBAH, or Han Solo,
		# Luke, Leia, or Chewbacca if they are at Jabba's palace." (p100)
		#
		# Concealment applies to your OWN side, so this is not an intel
		# check - he is simply not findable. Listing him as "Unknown" would
		# still tell the player he exists and is somewhere, which is the one
		# thing this note forbids. Both places count - see Character.IsOffMap.
		if c.IsOffMap():
			continue

		# ⚠ THE ENEMY'S ROSTER IS NOT FREE INFORMATION, AND THIS WINDOW WAS
		# GIVING IT AWAY.
		#
		# It walked the whole global roster with no faction filter and no
		# intel check, listing every enemy character, where they were and
		# where they were headed - so a player could read "Wedge Antilles -
		# Selonia" off a system their sensors reported nothing about.
		# DefenseWindow gates exactly the same data through
		# IntelSection.Characters; this did not.
		#
		# The rule applied here is that window's: your own side always, and
		# somebody else's only where you have actually looked. A character
		# in transit has no system to have looked at, so they are not
		# listed at all.
		if c.Faction != GameSettings.PlayerFaction:
			if not (c.Attached is Planet):
				continue
			var seenAt: Planet = c.Attached as Planet
			if not IntelManager.Knows(GameSettings.PlayerFaction, seenAt,
					Enums.IntelSection.Characters):
				continue

		# If the search bar isn't empty, check if the name matches
		if not lowerFilter.strip_edges().is_empty() and not c.Name.to_lower().contains(lowerFilter):
			continue

		# 3. Create the text "Luke Skywalker - Yavin"
		var locationStr: String = c.Attached.Name if c.Attached != null else "Unknown"
		var displayText: String = "%s - %s" % [c.Name, locationStr]

		# 4. Create a clickable, flat button for the list
		var charBtn := Button.new()
		charBtn.text = displayText
		charBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		charBtn.flat = true

		# Replicate original coloring
		var nameColor: Color = c.Faction.FactionColor if c.Faction != null else FactionRegistry.Unknown.FactionColor
		charBtn.add_theme_color_override("font_color", nameColor)
		charBtn.add_theme_font_size_override("font_size", 14)

		# Bind the click event to our routing method
		charBtn.pressed.connect(func() -> void: OnCharacterClicked(c))

		# Assign to the correct tab
		# NOTE: this panel has exactly two lists bound in the scene, so it is
		# still 2-faction-shaped. Routing by pack order removes the hardcoded
		# identity, but a 3-4 faction pack needs the tabs built dynamically.
		# Tracked in PROJECT.md as a Phase 3 UI item.
		var side: int = FactionRegistry.OrderOf(c.Faction)
		if side <= 0:
			_allianceList.add_child(charBtn)
		else:
			_empireList.add_child(charBtn)


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
