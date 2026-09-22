class_name Economy
extends RefCounted
## backend/Economy.cs - the galaxy-wide economy, per faction (ECONOMY-NOTES.md,
## GAMEPLAY.md section 3). Maintenance is DERIVED, never stored.


class FactionEconomy:
	var RawMaterials: int
	var RefinedMaterials: int
	## Fractional progress carried between days (facilities are rated in DAYS PER
	## UNIT, manual p085).
	var RawWork: int
	var RefineWork: int


const MaintenancePerPair := 50

static var _by_faction: Dictionary = {}   # faction id -> FactionEconomy


static func For(faction: Faction) -> FactionEconomy:
	if faction == null:
		return FactionEconomy.new()
	if not _by_faction.has(faction.Id):
		_by_faction[faction.Id] = FactionEconomy.new()
	return _by_faction[faction.Id]


static func Reset() -> void:
	_by_faction.clear()


static func WorldsOf(faction: Faction) -> Array:
	var out := []
	if faction == null:
		return out
	for p in GameState.AllPlanets():
		if p.ControllingFaction == faction:
			out.append(p)
	return out


## A world in uprising contributes nothing (manual p058).
static func ProductiveWorldsOf(f: Faction) -> Array:
	return Lq.where(WorldsOf(f), func(p): return not p.IsInUprising)


static func TotalMines(f: Faction) -> int:
	return Lq.sum(ProductiveWorldsOf(f), func(p): return p.Mines())


static func TotalRefineries(f: Faction) -> int:
	return Lq.sum(ProductiveWorldsOf(f), func(p): return p.Refineries())


## "Each mine/refinery COMBINATION" - matched pairs, galaxy-wide.
static func MatchedPairs(f: Faction) -> int:
	return min(TotalMines(f), TotalRefineries(f))


static func MaintenanceCapacity(f: Faction) -> int:
	return MatchedPairs(f) * MaintenancePerPair


## Everything standing that draws on the pool: facilities, units, everything on
## order, and anything built but still in transit (manual p030, p084).
static func MaintenanceCommitted(f: Faction) -> int:
	var committed := 0
	for p in WorldsOf(f):
		for fac in p.Facilities:
			committed += FacilityCatalog.MaintenanceCost(fac.Family(), fac.Tier)
		for u in p.Garrison:
			committed += u.MaintenanceCost
		for u in p.FighterSquadrons:
			committed += u.MaintenanceCost
		for fleet in p.OrbitingFleets:
			for ship in fleet.Ships:
				committed += ship.MaintenanceCost
		for queue in [p.BuildingQueue, p.ShipyardQueue, p.TrainingQueue]:
			for t in queue:
				committed += t.MaintenanceCost
		for t in p.InTransit():
			committed += t.MaintenanceCost
	return committed


static func MaintenanceAvailable(f: Faction) -> int:
	return MaintenanceCapacity(f) - MaintenanceCommitted(f)


## The daily flow. Mines feed the raw pool; refineries draw from it and feed the
## refined pool. Both are rated in days per unit.
static func ProcessDay(faction: Faction) -> void:
	if faction == null:
		return
	var econ := For(faction)
	var mines := TotalMines(faction)
	var refineries := TotalRefineries(faction)
	# The two rates belong to whatever the PACK builds for the two roles - a
	# quarry and a smelter as readily as a mine and a refinery.
	var mine_rate := FacilityCatalog.ProcessingRateForRole("extracts_raw")
	var ref_rate := FacilityCatalog.ProcessingRateForRole("refines")

	econ.RawWork += mines
	var mined: int = econ.RawWork / mine_rate
	econ.RawWork -= mined * mine_rate
	econ.RawMaterials += mined

	econ.RefineWork += refineries
	var capacity: int = econ.RefineWork / ref_rate
	var refined: int = min(capacity, econ.RawMaterials)
	econ.RefineWork -= refined * ref_rate
	econ.RawMaterials -= refined
	econ.RefinedMaterials += refined
