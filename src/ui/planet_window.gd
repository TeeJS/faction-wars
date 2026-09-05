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
			# The player's own MOVABLE headquarters carries the Fig 3.82 menu
			# {Move, Confirmed Move, Encyclopedia, Status}; every other facility is
			# a plain label. Only the Alliance's hidden HQ is Movable (pack-driven).
			if facility.Type == Enums.FacilityType.Headquarters and holder == player \
					and player.Hq != null and player.Hq.Movable:
				_AddHqMenuRow(_facility, facility, planet)
				continue
			var facLabel := Label.new()
			facLabel.text = "%s" % facility.Name()
			facLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			facLabel.add_theme_font_size_override("font_size", 10)
			_facility.add_child(facLabel)
	else:
		_status.text = "Unexplored Planet"
		_resources.text = ""


## The Alliance HQ's Fig 3.82 menu {Move, Confirmed Move, Encyclopedia, Status}
## (GAMEPLAY.md:2996-2998). Move / Confirmed Move raise the map crosshair to pick the
## destination system (manual p090); OrderManager.MoveHeadquarters re-validates it
## (own world, not blockaded). Right-click opens the menu, matching the port's other
## entity menus. Encyclopedia/Status are stubs, as they are for every facility today.
func _AddHqMenuRow(list: VBoxContainer, facility: Facility, planet: Planet) -> void:
	var btn := Button.new()
	btn.text = facility.Name()
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 10)
	var popup := PopupMenu.new()
	popup.add_item("Move", 0)
	popup.add_item("Confirmed Move", 1)
	popup.add_item("Encyclopedia", 4)
	popup.add_item("Status", 5)
	btn.add_child(popup)
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			popup.position = Vector2i(int(event.global_position.x), int(event.global_position.y))
			popup.popup()
			btn.accept_event())
	popup.id_pressed.connect(func(id: int) -> void: _OnHqMenuAction(id, planet))
	list.add_child(btn)


func _OnHqMenuAction(id: int, planet: Planet) -> void:
	match id:
		0, 1:   # Move / Confirmed Move - target the destination system on the map.
			var ui: UIManager = get_parent() as UIManager
			if ui == null:
				return
			ui.StartTargeting(func(dest: Planet) -> void:
				var r: Result = CommandBus.issue("move_hq", { "destination": dest.Name })
				if not r.ok:
					print("[HQ] %s" % r.error))
		4:   # Encyclopedia - stubbed, as for all facilities.
			print("[HQ] Encyclopedia for the headquarters at %s." % planet.Name)
		5:   # Status
			print("[HQ] Headquarters at %s." % planet.Name)
