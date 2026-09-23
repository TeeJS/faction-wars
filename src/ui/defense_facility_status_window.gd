class_name DefenseFacilityStatusWindow
extends DraggableWindow
## frontend/DefenseFacilityStatusWindow.cs - the status block for a shield or
## a battery (manual p085, fig 3.28).

var _associatedFacility: Facility


func _ready() -> void:
	super()   # Ensures window dragging/closing logic works


## Everything the original's Status window shows for a facility
## (OUI.StatusPlate). TeeJ's screenshot of the original's Manufacturing Status
## (an Orbital Shipyard on Chandrila) gives the fields and their words:
## Location, Status, Maintenance Cost, Standard Processing Rate, Bombardment
## Value, as bare numbers. A shield or gun is a "Defense Facility Status"
## (TEXTSTRA.DLL 34403); its rows past Maintenance Cost are not on any
## screenshot yet, so they are this window's own (weapons, shield).
static func StatusData(facility: Facility) -> Dictionary:
	var defence: bool = facility.HasRole("shield") or facility.HasRole("anti_ship") or facility.HasRole("disable")
	var rows: Array = []
	rows.append(["Location:", facility.Attached.Name if facility.Attached != null else "Unknown"])
	rows.append(["Status:", "Damaged" if facility.IsDamaged else "Active"])
	rows.append([Terms.field("maintenance"), str(FacilityCatalog.MaintenanceCost(facility.Family(), facility.Tier))])
	if defence:
		# The original's Defense Facility Status (TeeJ's screenshot of a
		# GenCore Level I, 2026-09-23): Weapons Rating even on a shield (0),
		# "Shield Strength" with no colon, "Bombardment Defense Strength:" -
		# broken after "Bombardment", where the original breaks it (our Arial
		# runs narrow enough to fit a word more). A battery's list is INFERRED
		# to be the same (not seen).
		rows.append(["Weapons Rating:", str(facility.WeaponRating)])
		rows.append(["Shield Strength", str(facility.ShieldStrength)])
		rows.append(["Bombardment\nDefense Strength:", str(maxi(0, facility.BombardmentDefense))])
	else:
		rows.append(["Standard Processing Rate:", str(FacilityCatalog.ProcessingRate(facility.Family(), facility.Tier))])
		rows.append(["Bombardment Value:", str(maxi(0, facility.BombardmentDefense))])
	var id: String = facility.Def.Id if facility.Def != null else facility.Family()
	return {
		"title": "Defense Facility Status" if defence else "Manufacturing Status",
		"fields": rows,
		"picture": Art.Scaled(Art.Portrait("facilities", id), OUI.K),
		"name": facility.Name(),
		"encyclopedia": ["facilities", id],
	}


func Populate(facility: Facility) -> void:
	_associatedFacility = facility

	# Title bar: the KIND of defence, which is the pack's tier-1 name for the
	# family ("Planetary Shield Status" for both shield tiers; "Coastal Battery
	# Status" on a pack that has no turbolasers). Never a family id in code.
	var facilityType: String = Facility.NameOf(facility.Family(), 1)
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
	# The catalogue's figure: Planet.AddFacility copies MaintenanceCost onto
	# defences only, so a shipyard's own field reads 0 (the pack says 13).
	var maintenance: int = FacilityCatalog.MaintenanceCost(facility.Family(), facility.Tier)
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
	var isWeapon: bool = facility.HasRole("anti_ship") or facility.HasRole("disable")
	var weaponKey: Label = get_node_or_null("%LblWeaponRating")
	var weaponVal: Label = get_node("%ValWeaponRating")

	if isWeapon:
		if weaponKey != null:
			weaponKey.text = "Weapons Rating:"
		weaponVal.text = "%d (Damage per shot)" % facility.WeaponRating
	else:
		var rate: int = FacilityCatalog.ProcessingRate(facility.Family(), facility.Tier)
		if weaponKey != null:
			weaponKey.text = "Std Processing Rate:"
		weaponVal.text = ("%d days per refined point" % rate) if rate > 0 else "0 (does not refine)"

	# Shield strength (only for a facility with the shield role), under the
	# pack's word for the stat ("Shield Strength:" / "Armour:").
	(get_node("%LblShieldStrength") as Label).text = Terms.field("shield")
	(get_node("%ValShieldStrength") as Label).text = ("%d HP" % facility.ShieldStrength) if facility.HasRole("shield") else "N/A"

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
	(get_node("%ValType") as Label).text = facilityType

	# The portrait glyph follows the ROLE - what the thing does - not its name.
	var iconLabel: Label = get_node("%IconLabel")
	if facility.HasRole("shield"):
		iconLabel.text = "🛡️"
	elif facility.HasRole("disable"):
		iconLabel.text = "⚡"
	elif facility.HasRole("anti_ship"):
		iconLabel.text = "💥"
	else:
		iconLabel.text = "🛰️"


func Refresh() -> void:
	if _associatedFacility != null:
		Populate(_associatedFacility)
