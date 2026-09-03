class_name DefenseFacilityStatusWindow
extends DraggableWindow
## frontend/DefenseFacilityStatusWindow.cs - the status block for a shield or
## a battery (manual p085, fig 3.28).

var _associatedFacility: Facility


func _ready() -> void:
	super()   # Ensures window dragging/closing logic works


func Populate(facility: Facility) -> void:
	_associatedFacility = facility

	# Title bar
	var facilityType: String
	match facility.Type:
		Enums.FacilityType.PlanetaryShield: facilityType = "Planetary Shield"
		Enums.FacilityType.TurbolaserBattery: facilityType = "Turbolaser Battery"
		Enums.FacilityType.IonCannon: facilityType = "Ion Cannon"
		_: facilityType = "Defense Facility"
	(get_node("%TitleBarLabel") as Label).text = "%s Status" % facilityType

	# Location
	var locationText: String = facility.Attached.Name if facility.Attached != null else "Unknown Planet"
	(get_node("%ValLocation") as Label).text = locationText

	var statusText: String
	var statusColor: Color = Color.WHITE

	# "Status: ACTIVE, UNDER CONSTRUCTION, OR EN ROUTE" (manual p085).
	#
	# This read `facility.IsDamaged ? "Active" : "Offline"` INSIDE the branch
	# where IsDamaged is already false, so every working facility in the game
	# reported itself Offline. The colour test compared against "Operational",
	# a string this method never produces, so it was always gold too.
	if facility.IsDamaged:
		statusText = "Damaged"
		statusColor = Color.RED
	else:
		statusText = "Active"
		statusColor = Color.LIME_GREEN

	var statusLabel: Label = get_node("%ValStatus")
	statusLabel.text = statusText
	statusLabel.add_theme_color_override("font_color", statusColor)

	# Maintenance Cost
	# "Maintenance Cost: HOW MANY MAINTENANCE UNITS facility uses" (p085).
	# Not credits, and not per turn - it is a standing draw on the pool for
	# as long as the facility exists. There is no currency in this game.
	var maintenance: int = facility.MaintenanceCost if facility.MaintenanceCost > 0 else 0
	(get_node("%ValMaintenanceCost") as Label).text = "%d maintenance" % maintenance

	# The manual's status block is Location, Status, Maintenance Cost,
	# STANDARD PROCESSING RATE and Bombardment Value (p085, fig 3.28).
	# Processing rate was missing entirely, while this row printed "N/A" for
	# every facility that is not a gun - so the field the manual specifies
	# was absent and its space was being wasted saying nothing.
	#
	# "Standard Processing Rate: NUMBER OF DAYS TO CONVERT ONE REFINED
	# MATERIAL POINT" - which is why a construction yard's is 0: it does not
	# refine anything.
	var isWeapon: bool = facility.Type == Enums.FacilityType.TurbolaserBattery or facility.Type == Enums.FacilityType.IonCannon
	var weaponKey: Label = get_node_or_null("%LblWeaponRating")
	var weaponVal: Label = get_node("%ValWeaponRating")

	if isWeapon:
		if weaponKey != null:
			weaponKey.text = "Weapons Rating:"
		weaponVal.text = "%d (Damage per shot)" % facility.WeaponRating
	else:
		var rate: int = FacilityCatalog.ProcessingRate(facility.Type, facility.Tier)
		if weaponKey != null:
			weaponKey.text = "Std Processing Rate:"
		weaponVal.text = ("%d days per refined point" % rate) if rate > 0 else "0 (does not refine)"

	# Shield Strength (only for shields)
	var shieldText: String
	match facility.Type:
		Enums.FacilityType.PlanetaryShield: shieldText = "%d HP" % facility.ShieldStrength
		_: shieldText = "N/A"
	(get_node("%ValShieldStrength") as Label).text = shieldText

	# "BOMBARDMENT VALUE" (manual p085, fig 3.28) - how much bombarding
	# firepower it takes to destroy this, straight from the binary tables.
	#
	# This used to read facility.ShieldStrength / 20, which is the shield's
	# hit points and nothing to do with bombardment: it gave a planetary
	# shield two stars and every other facility in the game "None", when the
	# data rates a mine 5 and the headquarters 9.
	var bombardmentText: String = ("%d" % facility.BombardmentDefense) if facility.BombardmentDefense > 0 \
		else "None"
	(get_node("%ValBombardmentDefense") as Label).text = bombardmentText

	# Optional: Add tier info to title or footer
	(get_node("%ValTier") as Label).text = "Level %d" % facility.Tier

	(get_node("%ValTier") as Label).text = "Tier %d" % facility.Tier
	var typeText: String
	match facility.Type:
		Enums.FacilityType.PlanetaryShield: typeText = "Planetary Shield"
		Enums.FacilityType.TurbolaserBattery: typeText = "Turbolaser Battery"
		Enums.FacilityType.IonCannon: typeText = "Ion Cannon"
		_: typeText = "Defense Facility"
	(get_node("%ValType") as Label).text = typeText

	# Also update portrait icon to reflect type
	var iconLabel: Label = get_node("%IconLabel")
	match facility.Type:
		Enums.FacilityType.PlanetaryShield: iconLabel.text = "🛡️"   # Shield
		Enums.FacilityType.TurbolaserBattery: iconLabel.text = "💥"   # Weapon
		Enums.FacilityType.IonCannon: iconLabel.text = "⚡"           # Ion
		_: iconLabel.text = "🛰️"


func Refresh() -> void:
	if _associatedFacility != null:
		Populate(_associatedFacility)
