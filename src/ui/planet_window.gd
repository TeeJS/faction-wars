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
	SetTitleIcon(planet)
	# The system's picture above its facts (TeeJ, 2026-09-23), when imported;
	# an unexplored world shows none.
	Art.Fill(get_node_or_null("%picture"), Art.Picture("planets", planet.PackId) if planet.IsExplored else null)
	var player: Faction = GameSettings.PlayerFaction

	# ALWAYS CLEAR PREVIOUS UI DATA FIRST
	for child in _facility.get_children():
		child.queue_free()

	# ⚠ THIS WINDOW WAS READING THE LIVE WORLD FOR ANY EXPLORED SYSTEM - the
	# enemy's current holder, both live supports, its live uprising, and its live
	# facility list (Headquarters included) off a world scouted long ago. Only a
	# world we HOLD reports itself live; everything else is what we last saw, with
	# a Core world's owner and support the one live exception (manual p069). Routed
	# through IntelManager so it obeys the same fog as the Defense/Economy windows.
	if not planet.IsExplored:
		_status.text = "Unexplored Planet"
		_resources.text = ""
	elif IntelManager.IsLive(player, planet):
		_PopulateLive(planet, player, _status, _resources, _facility)
	else:
		_PopulateFromIntel(planet, player, _status, _resources, _facility)


## A world we hold: it reports itself, always and accurately.
func _PopulateLive(planet: Planet, player: Faction, _status: Label, _resources: Label, _facility: VBoxContainer) -> void:
	# Two DIFFERENT factions are being reported here: who holds the world, and how
	# much the populace backs YOU. Name both sides so it cannot be misread.
	var holder: Faction = planet.ControllingFaction
	var mine: String = "%s support: %d%%" % [player.DisplayName, planet.SupportFor(player)]
	var theirs: String = ("  |  %s support: %d%%" % [holder.DisplayName, planet.SupportFor(holder)]) \
		if (holder != null and holder != player and FactionRegistry.OrderOf(holder) >= 0) \
		else ""

	_status.text = ("Held by: %s  |  %s%s" % [holder.DisplayName, mine, theirs]) \
		+ ("   [IN UPRISING]" if planet.IsInUprising else "")
	_resources.text = "%s: %d | %s: %d" % [Terms.label("energy"), planet.BaseEnergy, Terms.label("raw_materials"), planet.BaseRawMaterials]

	for facility in planet.Facilities:
		# The player's own MOVABLE headquarters carries the Fig 3.82 menu
		# {Move, Confirmed Move, Encyclopedia, Status}; every other facility is
		# a plain label. Only the Alliance's hidden HQ is Movable (pack-driven).
		if facility.HasRole("headquarters") and holder == player \
				and player.Hq != null and player.Hq.Movable:
			_AddHqMenuRow(_facility, facility, planet)
			continue
		var facLabel := Label.new()
		facLabel.text = "%s" % facility.Name()
		facLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		facLabel.add_theme_font_size_override("font_size", 10)
		_facility.add_child(facLabel)


## A world we do not hold: the dated sighting, never the live world. Owner and
## support are live only on a Core system (p069); the rest is as last seen, and a
## charted-but-never-scouted world (an Espionage leak) shows nothing at all.
func _PopulateFromIntel(planet: Planet, player: Faction, _status: Label, _resources: Label, _facility: VBoxContainer) -> void:
	var d: Dictionary = IntelManager.StatusSeen(player, planet)
	if d.is_empty():
		_status.text = "Sensors detect no data."
		_resources.text = ""
		return

	var support: Dictionary = d.get("support", {})
	var owner_id: String = str(d.get("owner", ""))
	var holder: Faction = FactionRegistry.ById(owner_id) if not owner_id.is_empty() else null
	var heldName: String = holder.DisplayName if holder != null else "nobody"
	var mine: String = "%s support: %d%%" % [player.DisplayName, int(support.get(player.Id, 0))]
	var theirs: String = ("  |  %s support: %d%%" % [holder.DisplayName, int(support.get(holder.Id, 0))]) \
		if (holder != null and holder != player and FactionRegistry.OrderOf(holder) >= 0) \
		else ""

	_status.text = ("Held by: %s  |  %s%s" % [heldName, mine, theirs]) \
		+ ("   [IN UPRISING]" if bool(d.get("uprising", false)) else "")
	_resources.text = "%s: %d | %s: %d" % [Terms.label("energy"), int(d.get("energy", 0)), Terms.label("raw_materials"), int(d.get("materials", 0))]

	# The facility list is a sighting too: production and defensive facilities as
	# they were last seen (a scouted HQ shows, an unscouted one does not).
	for section in [Enums.IntelSection.ProductionFacilities, Enums.IntelSection.DefensiveFacilities]:
		var view: IntelManager.IntelView = IntelManager.View(player, planet, section)
		for line in view.Lines:
			var facLabel := Label.new()
			facLabel.text = str(line)
			facLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			facLabel.add_theme_font_size_override("font_size", 10)
			_facility.add_child(facLabel)


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
		4:   # Encyclopedia - the headquarters building's entry
			var hq: Facility = Lq.first_or_null(planet.Facilities, func(f: Facility) -> bool: return f.HasRole("headquarters"))
			if hq != null and hq.Def != null:
				_uiManager.OpenEncyclopedia("facilities", hq.Def.Id)
		5:   # Status
			print("[HQ] Headquarters at %s." % planet.Name)
