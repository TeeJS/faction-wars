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
			rows.append(["Maneuverability:", str(unit.Maneuverability)])
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
## the class picture (GOKRES.DLL, 122x50) - a regiment's over the grey
## spotlight, a damaged ship's over its flames (GOKRES picture + 8192).
static func StatusData(unit: Unit) -> Dictionary:
	var backdrop: Texture2D = null
	if unit.Type == Enums.UnitType.Troop:
		backdrop = OUI.Pic("status_backdrop.troops")
	elif unit.Type == Enums.UnitType.CapitalShip and unit.IsDamaged():
		backdrop = Art.Scaled(Art.Portrait("units", unit.PackId + ".damage"), OUI.K)
	return {
		"title": StatusTitle(unit),
		"fields": PlateFields(unit),
		"picture": Art.Scaled(Art.Portrait("units", unit.PackId), OUI.K),
		"backdrop": backdrop,
		"name": unit.Name,
		"encyclopedia": ["units", unit.PackId],
	}


## The fields of the ORIGINAL'S window, in its order and words (TEXTSTRA.DLL
## 34384-34819), measured on TeeJ's screenshots of a Fighter Squadron and a
## Capital Ship Status (2026-09-23). A heading is a label with no value; a
## sub-item's label starts with one space. Current:maximum pairs read the
## ship's damage state. The regiment's and Spec Forces' lists are StatusFields.
static func PlateFields(unit: Unit) -> Array:
	match unit.Type:
		Enums.UnitType.Fighter:
			return _FighterFields(unit)
		Enums.UnitType.CapitalShip:
			return _CapitalShipFields(unit)
	return StatusFields(unit)


static func _Pair(now: int, most: int) -> String:
	return "%d:%d" % [now, most]


## The Fighter Squadron Status: no Status line; the squadron's aircraft left of
## its twelve; its shield and weapons for the whole squadron - a craft's times
## the craft left : times twelve (the original's X-wing: shield 5, laser 8,
## torpedoes 4 a craft read 60:60, 96:96, 48:48); the three weapons always
## listed, "0:0" for one it lacks. The list ends at Torpedoes (INFERRED from
## the scroll thumb: 15 lines).
static func _FighterFields(unit: Unit) -> Array:
	var d: ShipDamage = unit.DamageState()
	var rows: Array = []
	rows.append(["Attached:", unit.Attached.Name if unit.Attached != null else "None"])
	rows.append(["Maintenance Cost:", str(unit.MaintenanceCost)])
	rows.append(["Squadron Size:", _Pair(d.Aircraft, d.MaxAircraft)])
	rows.append(["Hyperdrive Rating:", str(unit.Hyperdrive)])
	rows.append(["Maximum Shield Strength:", _Pair(d.Shield * d.Aircraft, d.MaxShield * d.MaxAircraft)])
	rows.append(["Sub-Light Engine Rating:", str(unit.Sublight)])
	rows.append(["Maneuverability:", str(unit.Maneuverability)])
	rows.append(["Detection Rating:", str(unit.Detection)])
	rows.append(["Bombardment Value:", _Pair(unit.Bombardment, unit.Bombardment)])
	rows.append(["Weapons Rating:", ""])
	for pair in [[" Laser Rating:", "laser"], [" Ion Cannon:", "ion_cannon"], [" Torpedoes:", "torpedo"]]:
		var fitted: PackDefs.UnitWeaponDef = unit.Weapon(pair[1])
		var n: int = fitted.total() if fitted != null else 0
		rows.append([pair[0], _Pair(n * d.Aircraft, n * d.MaxAircraft)])
	return rows


## The Capital Ship Status, 49 lines. Lines 0-13 are measured; from Damage
## Control on they are INFERRED - the order of the manual's Fig 3.62 (a
## pre-release build), the words of TEXTSTRA - and the scroll thumb's length
## (54 pixels) is reproduced only by exactly these 49 lines.
static func _CapitalShipFields(unit: Unit) -> Array:
	var d: ShipDamage = unit.DamageState()
	var def: PackDefs.UnitDef = MilitaryCatalog.ById(unit.PackId)
	var fleet: Fleet = OrderManager.FleetOf(unit)   # a ship is Attached to the world its fleet orbits
	var fighters: int = Lq.count(unit.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter) if unit.Hangar != null else 0
	var troops: int = Lq.count(unit.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop) if unit.Hangar != null else 0
	var personnel: int = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == unit) \
		if GameState.ActiveRoster != null else 0
	var rows: Array = []
	rows.append(["Class:", def.DisplayName if def != null else unit.Name])
	rows.append(["Fleet:", fleet.Name if fleet != null else "None"])
	rows.append(["Status:", StatusWord(unit.Status)])
	rows.append(["Maintenance Cost:", str(unit.MaintenanceCost)])
	rows.append(["Capacity:", ""])
	rows.append(["Fighter Squadrons:", str(unit.FighterCapacity)])
	rows.append(["Trooper Regiments:", str(unit.TroopCapacity)])
	rows.append(["Embarked:", ""])
	rows.append(["Fighter Squadrons:", str(fighters)])
	rows.append(["Trooper Regiments:", str(troops)])
	rows.append(["Personnel:", str(personnel)])
	rows.append(["Ship Damaged:", "Yes" if unit.IsDamaged() else "No"])
	rows.append(["Hyperdrive Rating:", _Pair(d.Hyperdrive, d.MaxHyperdrive)])
	rows.append(["Hull Value:", _Pair(d.Hull, d.MaxHull)])
	rows.append(["Damage Control Rating:", str(unit.DamageControl)])
	rows.append(["Shield Recharge Rate:", _Pair(d.ShieldRecharge, d.MaxShieldRecharge)])
	rows.append(["Maximum Shield Strength:", _Pair(d.Shield, d.MaxShield)])
	rows.append(["Tractor Beam Power:", _Pair(d.TractorPower, d.MaxTractorPower)])
	rows.append(["Sub-Light Engine Rating:", _Pair(d.Sublight, d.MaxSublight)])
	rows.append(["Maneuverability:", str(unit.Maneuverability)])
	rows.append(["Detection Rating:", str(unit.Detection)])
	rows.append(["Weapon Recharge Rate:", _Pair(d.WeaponRecharge, d.MaxWeaponRecharge)])
	rows.append(["Bombardment Modifier:", str(unit.Bombardment)])
	var arcs: Array = [["Forward", Enums.ShipArc.Fore], ["Aft", Enums.ShipArc.Aft],
		["Starboard", Enums.ShipArc.Starboard], ["Port", Enums.ShipArc.Port]]
	for arc in arcs:
		rows.append(["%s Weapons Arc Rating:" % arc[0], ""])
		for pair in [[" Turbo Laser:", "turbolaser"], [" Ion Cannon:", "ion_cannon"], [" Laser Cannon:", "laser"]]:
			var fitted: PackDefs.UnitWeaponDef = unit.Weapon(pair[1])
			var n: int = fitted.in_arc(arc[1]) if fitted != null else 0
			rows.append([pair[0], _Pair(n, n)])
	return rows


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
