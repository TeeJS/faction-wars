class_name UnitStatusWindow
extends DraggableWindow
## frontend/UnitStatusWindow.cs - the Unit / Capital Ship Status window (manual
## p115-p117; figs 3.61-3.62).

var _associatedUnit: Unit


func _ready() -> void:
	super()


func Populate(unit: Unit) -> void:
	_associatedUnit = unit

	var titleType: String = "Ship" if unit.Type == Enums.UnitType.CapitalShip else \
		("Fighter Squadron" if unit.Type == Enums.UnitType.Fighter else \
		("SpecForces" if unit.Type == Enums.UnitType.SpecForce else "Trooper Regiment"))

	(get_node("%TitleBarLabel") as Label).text = " %s Status" % titleType
	(get_node("%UnitNameLabel") as Label).text = unit.Name

	# Grab our grid and clear out any old data
	var grid: GridContainer = get_node("%StatsGrid")
	for child in grid.get_children():
		child.queue_free()

	# --- UNIVERSAL STATS ---
	AddStatRow(grid, "Attached:", unit.Attached.Name if unit.Attached != null else "None")

	if unit.Status == Enums.Status.Enroute:
		AddStatRow(grid, "Status:", "Enroute to %s (%dd)" % [unit.Destination.Name if unit.Destination != null else "", unit.DaysToDestination])
	else:
		AddStatRow(grid, "Status:", JsonUtil.enum_name(Enums.Status, unit.Status))

	AddStatRow(grid, "Maintenance Cost:", str(unit.MaintenanceCost))

	# --- DYNAMIC MILITARY STATS ---
	if unit.Type == Enums.UnitType.Troop or unit.Type == Enums.UnitType.SpecForce:
		if unit.Type == Enums.UnitType.SpecForce:
			# Spec forces use different terminology
			AddStatRow(grid, "Detection Value:", str(unit.Detection))
			AddStatRow(grid, "Combat Rating:", str(unit.Attack))
		else:
			AddStatRow(grid, "Attack Strength:", str(unit.Attack))
			AddStatRow(grid, "Defense Strength:", str(unit.Defense))
			AddStatRow(grid, "Bombardment Defense:", str(unit.BombardmentDefense))
			AddStatRow(grid, "Detection Value:", str(unit.Detection))
	elif unit.Type == Enums.UnitType.Fighter:
		AddStatRow(grid, "Squadron Size:", "12:12")
		AddStatRow(grid, "Hyperdrive Rating:", str(unit.Hyperdrive))
		AddStatRow(grid, "Maximum Shield Strength:", "%d:%d" % [unit.Shield, unit.Shield])
		AddStatRow(grid, "Sub-Light Engine Rating:", str(unit.Sublight))
		# fake maneuverability stat based on sublight speed
		AddStatRow(grid, "Maneuverability:", str(maxi(1, unit.Sublight - 3)))
		AddStatRow(grid, "Detection Rating:", str(unit.Detection))
		AddStatRow(grid, "Bombardment Value:", "%d:%d" % [unit.Bombardment, unit.Bombardment])
		AddStatRow(grid, "Weapons Rating:", "")
		AddStatRow(grid, "  Laser Rating:", "%d:%d" % [unit.LaserRating, unit.LaserRating])
		AddStatRow(grid, "  Ion Cannon:", "%d:%d" % [unit.IonCannon, unit.IonCannon])
		AddStatRow(grid, "  Torpedoes:", "%d:%d" % [unit.Torpedoes, unit.Torpedoes])
	elif unit.Type == Enums.UnitType.CapitalShip:
		AddStatRow(grid, "Hyperdrive Rating:", str(unit.Hyperdrive))
		AddStatRow(grid, "Sub-Light Engine Rating:", str(unit.Sublight))
		AddStatRow(grid, "Hull Value:", str(unit.Hull))
		AddStatRow(grid, "Shield Strength:", str(unit.Shield))
		AddStatRow(grid, "Bombardment Modifier:", str(unit.Bombardment))
		if unit.FighterCapacity > 0: AddStatRow(grid, "Fighter Capacity:", str(unit.FighterCapacity))
		if unit.TroopCapacity > 0: AddStatRow(grid, "Troop Capacity:", str(unit.TroopCapacity))


func AddStatRow(grid: GridContainer, labelText: String, valueText: String) -> void:
	var lbl := Label.new()
	lbl.text = labelText
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))   # Light Gray
	lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl)

	var val := Label.new()
	val.text = valueText
	val.add_theme_font_size_override("font_size", 12)
	grid.add_child(val)


func Refresh() -> void:
	if _associatedUnit != null:
		Populate(_associatedUnit)
