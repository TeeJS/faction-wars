class_name UnitStatusWindow
extends DraggableWindow
## frontend/UnitStatusWindow.cs - the Unit / Capital Ship Status window (manual
## p115-p117; figs 3.61-3.62). With the player's imported art the original's
## Status window shows the same content (StatusData, UIManager.OpenUnitStatusWindow).

var _associatedUnit: Unit


func _ready() -> void:
	super()


const PortraitPath := "MainVBox/ContentArea/SplitHBox/RightPanel/PortraitRect"


## The window's title, from the kind of unit, in the pack's words (display.json
## terms, SCHEMA.md section 10); the original's for Star Wars: "Trooper
## Regiment Status", "Spec Forces Status", "Fighter Squadron Status", "Capital
## Ship Status" (TEXTSTRA.DLL 34405, 34416, 34384, 34562).
static func StatusTitle(unit: Unit) -> String:
	match unit.Type:
		Enums.UnitType.CapitalShip:
			return "Capital Ship Status"
		Enums.UnitType.Fighter:
			return "%s Status" % Terms.label("fighter_squadron")
		Enums.UnitType.SpecForce:
			return "Spec Forces Status"
	return "%s Status" % Terms.label("trooper_regiment")


## A unit's status as the original words it: "Awaiting Orders", "Enroute",
## "On Mission", "Captured" (TEXTSTRA.DLL 34628-34632).
static func StatusWord(status: int) -> String:
	match status:
		Enums.Status.AwaitingOrders:
			return "Awaiting Orders"
		Enums.Status.Enroute:
			return "Enroute"
		Enums.Status.OnMission:
			return "On Mission"
		Enums.Status.Kidnapped:
			return "Captured"
	return JsonUtil.enum_name(Enums.Status, status)


## The status fields, [label, value], in the original's order and words where
## its window has been seen: a Trooper Regiment (Attached, Status, Maintenance
## Cost, Attack / Defense Strength, Bombardment Value, Detection Value) and
## Spec Forces (Attached, Status, Maintenance Cost, Diplomacy / Espionage /
## Combat / Leadership Rating) on TeeJ's screenshots of the original.
static func StatusFields(unit: Unit) -> Array:
	var rows: Array = []
	rows.append(["Attached:", unit.Attached.Name if unit.Attached != null else "None"])
	rows.append(["Status:", StatusWord(unit.Status)])
	if unit.Status == Enums.Status.Enroute:
		rows.append(["Time to Destination:", "%d Days" % unit.DaysToDestination])
	rows.append([Terms.field("maintenance"), str(unit.MaintenanceCost)])
	match unit.Type:
		Enums.UnitType.SpecForce:
			rows.append(["Diplomacy Rating:", str(unit.DiplomacyRating)])
			rows.append(["Espionage Rating:", str(unit.EspionageRating)])
			rows.append(["Combat Rating:", str(unit.CombatRating)])
			rows.append(["Leadership Rating:", str(unit.LeadershipRating)])
		Enums.UnitType.Troop:
			rows.append(["Attack Strength:", str(unit.Attack)])
			rows.append(["Defense Strength:", str(unit.Defense)])
			rows.append([Terms.field("bombardment_defense"), str(unit.BombardmentDefense)])
			rows.append(["Detection Value:", str(unit.Detection)])
		Enums.UnitType.Fighter:
			rows.append([Terms.field("squadron_size"), "12:12"])
			rows.append([Terms.field("hyperdrive"), str(unit.Hyperdrive)])
			rows.append(["Maximum %s:" % Terms.label("shield"), "%d:%d" % [unit.Shield, unit.Shield]])
			rows.append([Terms.field("sublight"), str(unit.Sublight)])
			# fake maneuverability stat based on sublight speed
			rows.append(["Maneuverability:", str(maxi(1, unit.Sublight - 3))])
			rows.append([Terms.field("detection"), str(unit.Detection)])
			rows.append([Terms.field("bombardment"), "%d:%d" % [unit.Bombardment, unit.Bombardment]])
			rows.append([Terms.field("weapons"), ""])
			# Whatever the pack fitted, named by the pack (SCHEMA.md section 6).
			for w in MilitaryCatalog.WeaponOrder():
				var fitted: PackDefs.UnitWeaponDef = unit.Weapon(w.Id)
				if fitted != null:
					rows.append(["  %s:" % w.DisplayName, "%d:%d" % [fitted.total(), fitted.total()]])
		Enums.UnitType.CapitalShip:
			rows.append([Terms.field("hyperdrive"), str(unit.Hyperdrive)])
			rows.append([Terms.field("sublight"), str(unit.Sublight)])
			rows.append([Terms.field("hull"), str(unit.Hull)])
			rows.append([Terms.field("shield"), str(unit.Shield)])
			rows.append([Terms.field("bombardment_modifier"), str(unit.Bombardment)])
			if unit.FighterCapacity > 0:
				rows.append([Terms.field("fighter_capacity"), str(unit.FighterCapacity)])
			if unit.TroopCapacity > 0:
				rows.append([Terms.field("troop_capacity"), str(unit.TroopCapacity)])
	return rows


## Everything the original's Status window shows for a unit (OUI.StatusPlate):
## the class picture (GOKRES.DLL, 122x50), a regiment's over the grey spotlight.
static func StatusData(unit: Unit) -> Dictionary:
	return {
		"title": StatusTitle(unit),
		"fields": StatusFields(unit),
		"picture": Art.Scaled(Art.Portrait("units", unit.PackId), OUI.K),
		"backdrop": OUI.Pic("status_backdrop.troops") if unit.Type == Enums.UnitType.Troop else null,
		"name": unit.Name,
		"encyclopedia": ["units", unit.PackId],
	}


func Populate(unit: Unit) -> void:
	_associatedUnit = unit
	# The unit's portrait, when the player imported the original's
	# (original/portraits/units/<id>.png), else the placeholder.
	Art.Fill(get_node_or_null(PortraitPath), Art.Portrait("units", unit.PackId))

	(get_node("%TitleBarLabel") as Label).text = " " + StatusTitle(unit)
	(get_node("%UnitNameLabel") as Label).text = unit.Name

	# Grab our grid and clear out any old data
	var grid: GridContainer = get_node("%StatsGrid")
	for child in grid.get_children():
		child.queue_free()
	for row in StatusFields(unit):
		AddStatRow(grid, row[0], row[1])


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
