class_name UnitStatusWindow
extends DraggableWindow
## frontend/UnitStatusWindow.cs - the Unit / Capital Ship Status window (manual
## p115-p117; figs 3.61-3.62).

var _associatedUnit: Unit


func _ready() -> void:
	super()


func Populate(unit: Unit) -> void:
	_associatedUnit = unit

	# The kind names and stat labels are the PACK's words (display.json terms,
	# SCHEMA.md section 10); the engine only knows the concepts.
	var titleType: String = "Ship" if unit.Type == Enums.UnitType.CapitalShip else \
		(Terms.label("fighter_squadron") if unit.Type == Enums.UnitType.Fighter else \
		("SpecForces" if unit.Type == Enums.UnitType.SpecForce else Terms.label("trooper_regiment")))

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

	AddStatRow(grid, Terms.field("maintenance"), str(unit.MaintenanceCost))

	# --- DYNAMIC MILITARY STATS ---
	if unit.Type == Enums.UnitType.Troop or unit.Type == Enums.UnitType.SpecForce:
		if unit.Type == Enums.UnitType.SpecForce:
			# Spec forces use different terminology
			AddStatRow(grid, "Detection Value:", str(unit.Detection))
			AddStatRow(grid, "Combat Rating:", str(unit.Attack))
		else:
			AddStatRow(grid, "Attack Strength:", str(unit.Attack))
			AddStatRow(grid, "Defense Strength:", str(unit.Defense))
			AddStatRow(grid, Terms.field("bombardment_defense"), str(unit.BombardmentDefense))
			AddStatRow(grid, "Detection Value:", str(unit.Detection))
	elif unit.Type == Enums.UnitType.Fighter:
		AddStatRow(grid, Terms.field("squadron_size"), "12:12")
		AddStatRow(grid, Terms.field("hyperdrive"), str(unit.Hyperdrive))
		AddStatRow(grid, "Maximum %s:" % Terms.label("shield"), "%d:%d" % [unit.Shield, unit.Shield])
		AddStatRow(grid, Terms.field("sublight"), str(unit.Sublight))
		# fake maneuverability stat based on sublight speed
		AddStatRow(grid, "Maneuverability:", str(maxi(1, unit.Sublight - 3)))
		AddStatRow(grid, Terms.field("detection"), str(unit.Detection))
		AddStatRow(grid, Terms.field("bombardment"), "%d:%d" % [unit.Bombardment, unit.Bombardment])
		AddStatRow(grid, Terms.field("weapons"), "")
		# Whatever the pack fitted, named by the pack (SCHEMA.md section 6).
		for w in MilitaryCatalog.WeaponOrder():
			var fitted: PackDefs.UnitWeaponDef = unit.Weapon(w.Id)
			if fitted == null:
				continue
			AddStatRow(grid, "  %s:" % w.DisplayName, "%d:%d" % [fitted.total(), fitted.total()])
	elif unit.Type == Enums.UnitType.CapitalShip:
		AddStatRow(grid, Terms.field("hyperdrive"), str(unit.Hyperdrive))
		AddStatRow(grid, Terms.field("sublight"), str(unit.Sublight))
		AddStatRow(grid, Terms.field("hull"), str(unit.Hull))
		AddStatRow(grid, Terms.field("shield"), str(unit.Shield))
		AddStatRow(grid, Terms.field("bombardment_modifier"), str(unit.Bombardment))
		if unit.FighterCapacity > 0: AddStatRow(grid, Terms.field("fighter_capacity"), str(unit.FighterCapacity))
		if unit.TroopCapacity > 0: AddStatRow(grid, Terms.field("troop_capacity"), str(unit.TroopCapacity))


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
