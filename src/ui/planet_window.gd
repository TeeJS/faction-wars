class_name PlanetWindow
extends DraggableWindow
## frontend/PlanetWindow.cs - the Planet Data window: holder, support for both
## sides, base resources and the facility list.


# These match the nodes in your updated PlanetWindow.tscn
func Populate(planet: Planet) -> void:
	# Use the unique name references directly
	var _title: Label = get_node("%TitleBarLabel")
	var _status: Label = get_node("%status")
	var _resources: Label = get_node("%resources")
	var _facility: VBoxContainer = get_node("%facilities")

	_title.text = planet.Name

	# ALWAYS CLEAR PREVIOUS UI DATA FIRST
	for child in _facility.get_children():
		child.queue_free()

	if planet.IsExplored:
		# Two DIFFERENT factions are being reported here: who holds the
		# world, and how much the populace backs YOU. "Faction: Rebel
		# Alliance | Support: 100%" read as the Alliance having 100% when it
		# meant the Alliance holds it and the Empire's support was 100%.
		# Name both sides so it cannot be misread.
		var holder: Faction = planet.ControllingFaction
		var player: Faction = GameSettings.PlayerFaction
		var mine: String = "%s support: %d%%" % [player.DisplayName, planet.SupportFor(player)]
		var theirs: String = ("  |  %s support: %d%%" % [holder.DisplayName, planet.SupportFor(holder)]) \
			if (holder != null and holder != player and FactionRegistry.OrderOf(holder) >= 0) \
			else ""

		_status.text = ("Held by: %s  |  %s%s" % [holder.DisplayName, mine, theirs]) \
			+ ("   [IN UPRISING]" if planet.IsInUprising else "")
		_resources.text = "Energy: %d | Materials: %d" % [planet.BaseEnergy, planet.BaseRawMaterials]

		for child in _facility.get_children():
			child.queue_free()

		for facility in planet.Facilities:
			var facLabel := Label.new()
			facLabel.text = "%s" % facility.Name()
			facLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			facLabel.add_theme_font_size_override("font_size", 10)
			_facility.add_child(facLabel)
	else:
		_status.text = "Unexplored Planet"
		_resources.text = ""
