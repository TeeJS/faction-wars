class_name ConstructionTask
extends RefCounted
## backend/Planet.cs ConstructionTask - one order in a production queue. Builds
## EITHER a facility (Type/Tier) or a unit (UnitRule).

## The FAMILY being built, e.g. "shipyard", with Tier picking the variant.
## Was Enums.FacilityType; the pack owns the vocabulary now.
var Family: String = ""
var Tier: int = 1

## Non-null when this order is for a ship, fighter, trooper regiment or SpecForce.
var UnitRule: CatalogDtos.UnitStatRule

## Refined material, already spent when the order was placed; refunded on cancel.
var RefinedCost: int
## Standing withdrawal from the maintenance pool for as long as this is queued.
var MaintenanceCost: int

## Facility-days required: refined cost x the producing yard's rate.
var TotalWork: int
var Progress: int

## Where this is being delivered, and the transport leg still to run once built.
var Destination: Planet
var TransportDays: int


func PercentComplete() -> int:
	return 0 if TotalWork <= 0 else clampi(Progress * 100 / TotalWork, 0, 100)


func DisplayName() -> String:
	if UnitRule != null:
		return UnitRule.Name
	var r := FacilityCatalog.Get(Family, Tier)
	return r.DisplayName if r != null else Family


static func _enum_fields() -> Dictionary:
	return {}
