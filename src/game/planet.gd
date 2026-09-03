class_name Planet
extends Location
## backend/Planet.cs - a star system: its facilities, garrison, queues, orbit,
## popular support and the uprising state machine (manual p127-p128). Every rule
## comment in the source applies; the ones that decide arithmetic are repeated
## here so a reader of this file sees the same sources.

var StartsInhabited: bool
var IsInhabited: bool = false
var SectorId: int
var BaseEnergy: int
var BaseRawMaterials: int
var ControllingFaction: Faction   # set to the pack's neutral at generation
var IsExplored: bool = false

var Garrison: Array[Unit] = []
var FighterSquadrons: Array[Unit] = []
var Facilities: Array[Facility] = []

# --- PRODUCTION QUEUES --- (front of the queue is index 0)
var BuildingQueue: Array[ConstructionTask] = []
var ShipyardQueue: Array[ConstructionTask] = []
var TrainingQueue: Array[ConstructionTask] = []

# Fleet tracking for the Galaxy Map "Fleets" layer
var OrbitingFleets: Array[Fleet] = []

var IsInUprising: bool = false
## "Near Uprising" / "Garrison Warning" are shipped strings in TEXTSTRA.DLL - the
## original models an under-garrisoned world as a STATE OF ITS OWN.
var IsNearUprising: bool = false

# The shipped uprising timers, entries 167/168 and 166.
var _uprising_ends: int
var _next_support_drift: int
var _next_uprising_incident: int

## Facilities finished but not yet delivered. Held on the PRODUCER.
var _in_transit: Array[ConstructionTask] = []

var _completed_this_tick: int

## Support is a percentage PER PLAYABLE FACTION, summing to 100.
var _support: Dictionary = {}   # faction id -> int

## "Some of the refined material" is exactly half (measured); maintenance comes
## back whole.
const ScrapRefundPercent := 50

## FITTED: how often a revolt costs the holder something (one loss roll per day).
const UprisingLossChancePercent := 6
## ⚠ OURS - the same figures Mission.cs uses for a seized team member, so the two
## never drift apart on a rule the manual states identically.
const UprisingKilledPercent := 20
const CaptureInjuryPercent := 35

## Ratings in entries 1, 60 and every ship's hyperdrive are percentages.
const PercentBase := 100


# --- FACILITY COUNTS --- DERIVED from Facilities. Never stored.
func CountOf(type: int) -> int:
	var n := 0
	for f in Facilities:
		if f.Type == type:
			n += 1
	return n

func Mines() -> int:               return CountOf(Enums.FacilityType.Mine)
func Refineries() -> int:          return CountOf(Enums.FacilityType.Refinery)
func ConstructionYards() -> int:   return CountOf(Enums.FacilityType.ConstructionYard)
func Shipyards() -> int:           return CountOf(Enums.FacilityType.Shipyard)
func TrainingFacilities() -> int:  return CountOf(Enums.FacilityType.TrainingFacility)
func PlanetaryShields() -> int:    return CountOf(Enums.FacilityType.PlanetaryShield)
func TurbolaserBatteries() -> int: return CountOf(Enums.FacilityType.TurbolaserBattery)
func IonCannons() -> int:          return CountOf(Enums.FacilityType.IonCannon)
func HasHeadquarters() -> bool:    return CountOf(Enums.FacilityType.Headquarters) > 0

func HasIdleConstructionYards() -> bool: return ConstructionYards() > 0 and BuildingQueue.is_empty()
func HasIdleShipyards() -> bool:         return Shipyards() > 0 and ShipyardQueue.is_empty()
func HasIdleTroopTraining() -> bool:     return TrainingFacilities() > 0 and TrainingQueue.is_empty()


## ⚠ FLEETS THAT HAVE ACTUALLY ARRIVED - OrbitingFleets ALONE IS NOT THAT (an
## ordered fleet sits in its destination's list, Enroute, for the whole journey).
func FleetsInOrbit() -> Array:
	return Lq.where(OrbitingFleets, func(f): return f.Status != Enums.Status.Enroute)


# --- CAPACITY GAUGES --- energy and raw material are SLOT COUNTS (manual p024, p084).
func UsedEnergySlots() -> int:
	return Lq.count(Facilities, func(f): return f.Type != Enums.FacilityType.Headquarters)

func FreeEnergySlots() -> int:
	return max(0, BaseEnergy - UsedEnergySlots())

func UsedMineSlots() -> int:
	return Mines()

func FreeMineSlots() -> int:
	return max(0, BaseRawMaterials - Mines())


func InTransit() -> Array:
	return _in_transit


## Returns the number of orders completed this tick (C# PlanetTickResult).
func ProcessDailyTick() -> int:
	# Anything finished but still in transit gets a day closer.
	for i in range(_in_transit.size() - 1, -1, -1):
		var shipment := _in_transit[i]
		shipment.TransportDays -= 1
		if shipment.TransportDays > 0:
			continue
		_in_transit.remove_at(i)
		Deliver(shipment, shipment.Destination)
		print("[%s] %s arrived at %s." % [Name, shipment.DisplayName(), shipment.Destination.Name])

	UpdateGarrisonState()

	# "An uprising prevents you from ... using the facilities" (manual p058), and
	# so does a blockade (p059, p084).
	if IsInUprising or BlockadeManager.IsBlockaded(self):
		return 0

	if BuildingQueue.size() > 0 and ConstructionYards() > 0:
		ProcessQueueItem(BuildingQueue, ConstructionYards(), "Facility")
	if ShipyardQueue.size() > 0 and Shipyards() > 0:
		ProcessQueueItem(ShipyardQueue, Shipyards(), "Ship")
	if TrainingQueue.size() > 0 and TrainingFacilities() > 0:
		ProcessQueueItem(TrainingQueue, TrainingFacilities(), "Troop Regiment")

	var completed := _completed_this_tick
	_completed_this_tick = 0
	# There is no brownout penalty and there never should be again (see source).
	return completed


func BestYardRateForUi() -> int:
	return BestYardRate()

func BestProducerRateForUi(producer: int) -> int:
	return BestProducerRate(producer)

func BestYardRate() -> int:
	return BestProducerRate(Enums.FacilityType.ConstructionYard)

## Lowest days-per-unit among this world's facilities of that kind.
func BestProducerRate(producer: int) -> int:
	var best := 0x7FFFFFFF
	for f in Facilities:
		if f.Type == producer:
			best = min(best, FacilityCatalog.ProcessingRate(f.Type, f.Tier))
	return FacilityCatalog.ProcessingRate(producer) if best == 0x7FFFFFFF else best


func ProcessQueueItem(queue: Array, daily_progress: int, _category: String) -> void:
	var active_job: ConstructionTask = queue[0]
	active_job.Progress += daily_progress
	if active_job.Progress >= active_job.TotalWork:
		queue.pop_front()
		_completed_this_tick += 1
		# EVERY completed order is delivered, not only facilities.
		FinishConstruction(active_job)


# --- PLACING A BUILD ORDER --- (manual p054, p084, p086, p131)
func FacilitiesOutOfAction() -> Result:
	if IsInUprising:
		return Result.fail("%s is in uprising - its facilities cannot be used." % Name)
	if BlockadeManager.IsBlockaded(self):
		return Result.fail("%s is blockaded - its facilities cannot be used until the blockade ends." % Name)
	return Result.success()


func CanQueueFacility(type: int, tier: int, destination: Planet) -> Result:
	var owner := ControllingFaction
	if destination == null:
		destination = self

	var gate := FacilitiesOutOfAction()
	if not gate.ok:
		return gate

	if ConstructionYards() <= 0:
		return Result.fail("%s has no construction yard - orders must be placed at a world that has one." % Name)

	var stats := FacilityCatalog.Get(type, tier)
	if stats == null:
		return Result.fail("No build data for %s." % JsonUtil.enum_name(Enums.FacilityType, type))
	if not stats.CanBeBuiltBy(owner):
		return Result.fail("%s cannot be built by %s." % [stats.Name, owner.DisplayName if owner != null else "nobody"])

	if destination.ControllingFaction != owner:
		return Result.fail("%s is not under your control." % destination.Name)

	if destination.FreeEnergySlots() <= 0:
		return Result.fail("%s has no free energy slots (%d/%d used). Scrap a facility to make room." % [destination.Name, destination.UsedEnergySlots(), destination.BaseEnergy])

	if type == Enums.FacilityType.Mine and destination.FreeMineSlots() <= 0:
		return Result.fail("%s has no raw material sites left (%d/%d mined)." % [destination.Name, destination.UsedMineSlots(), destination.BaseRawMaterials])

	if Economy.For(owner).RefinedMaterials < stats.ConstructionCost:
		return Result.fail("Need %d refined material, have %d." % [stats.ConstructionCost, Economy.For(owner).RefinedMaterials])

	# A zero-maintenance item is ALWAYS buildable (manual p086's escape hatch).
	var available_maintenance := Economy.MaintenanceAvailable(owner)
	if stats.MaintenanceCost > 0 and available_maintenance < stats.MaintenanceCost:
		return Result.fail("Need %d maintenance capacity, have %d. Build a mine/refinery pair." % [stats.MaintenanceCost, available_maintenance])

	return Result.success()


## ⚠ NOT THE TRAVEL DIVISOR ANY MORE - kept only because callers outside travel
## may read it; TravelDaysTo does not.
static func HyperspaceDivisor(traveller: Faction = null) -> int:
	return RuleManager.Get(RuleId.SpaceTravelDistanceDiv, traveller) * PercentBase

static func StandardTravelSpeed(traveller: Faction = null) -> int:
	return RuleManager.Get(RuleId.SpaceTravelBase, traveller)

static func HanSoloTravelSpeed(traveller: Faction = null) -> int:
	return RuleManager.Get(RuleId.SpaceTravelHanSolo, traveller)


func DistanceTo(other: Planet) -> float:
	if other == null:
		return 0.0
	var dx := other.MapX - MapX
	var dy := other.MapY - MapY
	return sqrt(dx * dx + dy * dy)


## ✅ THE GAME'S OWN LAW (sub_55c090): days = floor(floor(isqrt(d²) / entry74) * rating / 100).
## The whole point is the INTEGER TRUNCATION at both steps.
func TravelDaysTo(destination: Planet, hyperdrive: int = 0, unshipped_speed: int = 0) -> int:
	if destination == null or destination == self:
		return 0
	var rating: int
	if hyperdrive > 0:
		rating = hyperdrive
	elif unshipped_speed > 0:
		rating = unshipped_speed
	else:
		rating = StandardTravelSpeed()
	var divisor := RuleManager.Get(RuleId.SpaceTravelDistanceDiv)
	if divisor <= 0:
		return 1   # a pack with no entry 74 - visible, not fatal
	var distance := IntegerDistanceTo(destination)
	return max(1, distance / divisor * rating / PercentBase)


## THE GAME NEVER USES FLOATS: an integer square root, truncated.
func IntegerDistanceTo(other: Planet) -> int:
	if other == null:
		return 0
	var dx: float = other.MapX - MapX
	var dy: float = other.MapY - MapY
	return int(sqrt(dx * dx + dy * dy))


func DeploymentDaysTo(destination: Planet) -> int:
	return TravelDaysTo(destination, 0)


## "You also choose NUMBER TO BUILD in one order" (manual p045). value = placed.
func TryQueueMany(type: int, tier: int, destination: Planet, count: int) -> Result:
	var placed := 0
	var last := Result.success()
	for i in max(1, count):
		last = TryQueueFacility(type, tier, destination)
		if not last.ok:
			break
		placed += 1
	return Result.success(placed) if placed > 0 else Result.fail(last.error, 0)


func TryQueueManyUnits(rule: CatalogDtos.UnitStatRule, destination: Planet, count: int) -> Result:
	var placed := 0
	var last := Result.success()
	for i in max(1, count):
		last = TryQueueUnit(rule, destination)
		if not last.ok:
			break
		placed += 1
	return Result.success(placed) if placed > 0 else Result.fail(last.error, 0)


func TryQueueFacility(type: int, tier: int, destination: Planet) -> Result:
	if destination == null:
		destination = self
	var can := CanQueueFacility(type, tier, destination)
	if not can.ok:
		return can

	var owner := ControllingFaction
	var stats := FacilityCatalog.Get(type, tier)
	var econ := Economy.For(owner)
	econ.RefinedMaterials -= stats.ConstructionCost
	EventBus.BroadcastChanged()

	var task := ConstructionTask.new()
	task.Type = type
	task.Tier = tier
	task.RefinedCost = stats.ConstructionCost
	task.MaintenanceCost = stats.MaintenanceCost
	# Work is refined cost x the PRODUCING yard's processing rate (fig 3.25 etc).
	task.TotalWork = stats.ConstructionCost * BestYardRate()
	task.Destination = destination
	task.TransportDays = DeploymentDaysTo(destination)
	BuildingQueue.append(task)

	print("[%s] Queued %s for %s: %d refined, %d maintenance, +%dd transport." % [Name, stats.Name, destination.Name, stats.ConstructionCost, stats.MaintenanceCost, DeploymentDaysTo(destination)])
	return Result.success()


## Ships, fighters, troops and SpecForces: a unit does NOT occupy an energy slot.
func CanQueueUnit(rule: CatalogDtos.UnitStatRule, destination: Planet) -> Result:
	var owner := ControllingFaction
	if destination == null:
		destination = self

	var gate := FacilitiesOutOfAction()
	if not gate.ok:
		return gate

	if rule == null:
		return Result.fail("No build data for that unit.")
	var type: Variant = MilitaryCatalog.TypeOf(rule)
	if type == null:
		return Result.fail("%s has an unrecognised unit type '%s'." % [rule.Name, rule.Type])
	if not MilitaryCatalog.CanBeBuiltBy(rule, owner):
		return Result.fail("%s cannot be built by %s." % [rule.Name, owner.DisplayName if owner != null else "nobody"])

	var producer := MilitaryCatalog.ProducerFor(type)
	var producer_count := Shipyards() if producer == Enums.FacilityType.Shipyard else TrainingFacilities()
	if producer_count <= 0:
		var what := "orbital shipyard" if producer == Enums.FacilityType.Shipyard else "training facility"
		return Result.fail("%s has no %s - orders must be placed at a world that has one." % [Name, what])

	if destination.ControllingFaction != owner:
		return Result.fail("%s is not under your control." % destination.Name)

	if Economy.For(owner).RefinedMaterials < rule.ConstructionCost:
		return Result.fail("Need %d refined material, have %d." % [rule.ConstructionCost, Economy.For(owner).RefinedMaterials])

	var available_maintenance := Economy.MaintenanceAvailable(owner)
	if rule.MaintenanceCost > 0 and available_maintenance < rule.MaintenanceCost:
		return Result.fail("Need %d maintenance capacity, have %d. Build a mine/refinery pair." % [rule.MaintenanceCost, available_maintenance])

	return Result.success()


func TryQueueUnit(rule: CatalogDtos.UnitStatRule, destination: Planet) -> Result:
	if destination == null:
		destination = self
	var can := CanQueueUnit(rule, destination)
	if not can.ok:
		return can

	var owner := ControllingFaction
	var type: int = MilitaryCatalog.TypeOf(rule)
	var producer := MilitaryCatalog.ProducerFor(type)

	Economy.For(owner).RefinedMaterials -= rule.ConstructionCost
	EventBus.BroadcastChanged()

	var task := ConstructionTask.new()
	task.UnitRule = rule
	task.RefinedCost = rule.ConstructionCost
	task.MaintenanceCost = rule.MaintenanceCost
	task.TotalWork = rule.ConstructionCost * BestProducerRate(producer)
	task.Destination = destination
	task.TransportDays = DeploymentDaysTo(destination)

	if producer == Enums.FacilityType.Shipyard:
		ShipyardQueue.append(task)
	else:
		TrainingQueue.append(task)

	print("[%s] Queued %s for %s: %d refined, %d maintenance, %d work, +%dd transport." % [Name, rule.Name, destination.Name, rule.ConstructionCost, rule.MaintenanceCost, task.TotalWork, task.TransportDays])
	return Result.success()


## Worlds this planet's yards may build for: anything the same faction holds.
## The producer sorts first so "build here" stays the default.
func ValidDestinations() -> Array:
	if ControllingFaction == null or GameState.ActiveGalaxy.is_empty():
		return [self]
	var held := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == ControllingFaction)
	return Lq.order_by(held, func(p): return [0 if p == self else 1, p.Name])


# --- GARRISONS AND UPRISINGS --- (manual p127; entries 207/208, 150)
func GarrisonSupportThreshold() -> int:
	return RuleManager.Get(RuleId.GarrisonUprisingThresh, ControllingFaction)

## ENTRY 208 IS STORED NEGATIVE; magnitude is what the arithmetic needs.
func GarrisonTroopContribution() -> int:
	return abs(RuleManager.Get(RuleId.GarrisonTroopOrder, ControllingFaction))

## Only trooper regiments count (manual p097).
func TrooperRegiments() -> int:
	return Lq.count(Garrison, func(u): return u.Type == Enums.UnitType.Troop)

func SpecForces() -> Array:
	return Lq.where(Garrison, func(u): return u.Type == Enums.UnitType.SpecForce)

func Troopers() -> Array:
	return Lq.where(Garrison, func(u): return u.Type == Enums.UnitType.Troop)


## A garrison requirement only exists for a world a PLAYABLE faction holds.
func HasOwnerWhoCanGarrison() -> bool:
	return IsInhabited and ControllingFaction != null and FactionRegistry.OrderOf(ControllingFaction) >= 0


func GarrisonRequirement() -> int:
	if not HasOwnerWhoCanGarrison():
		return 0
	var shortfall := GarrisonSupportThreshold() - SupportFor(ControllingFaction)
	if shortfall <= 0:
		return 0
	var step := GarrisonTroopContribution()
	if step <= 0:
		return 0
	var need := (shortfall + step - 1) / step
	# "While a system is in uprising, its garrison requirement DOUBLES." (p127)
	if not IsInUprising:
		return need
	var multiple := RuleManager.Get(RuleId.UprisingGarrisonMultiple, ControllingFaction)
	return need * max(1, multiple)


func UpdateGarrisonState() -> void:
	if not HasOwnerWhoCanGarrison():
		IsInUprising = false
		IsNearUprising = false
		_next_uprising_incident = 0
		return

	var need := GarrisonRequirement()
	if need <= 0:
		IsInUprising = false
		IsNearUprising = false
		_next_uprising_incident = 0
		return

	var have := TrooperRegiments()

	# Zero troops is simply the worst case of "fewer than needed" (see source).
	if have < need:
		if not IsInUprising:
			ConsiderUprising(need, have)
	else:
		_next_uprising_incident = 0
		IsNearUprising = false
		if IsInUprising:
			IsInUprising = false
			print("[%s] Uprising subdued - %d regiments now meet the requirement." % [Name, have])

	# WHILE IT RUNS, IT EATS THE OWNER'S SUPPORT (entries 165/166).
	if IsInUprising and StrategicTickManager.Today >= _next_support_drift:
		var shift := RuleManager.Get(RuleId.ActiveUprisingSupportShift, ControllingFaction)
		ShiftSupport(ControllingFaction, shift)
		_next_support_drift = StrategicTickManager.Today + max(1, RuleManager.Get(RuleId.UprisingSupportDriftDelay, ControllingFaction))

	# AND WHEN IT RUNS ITS COURSE, THE OWNER EITHER HELD IT OR LOST IT (p091, p128).
	if IsInUprising and StrategicTickManager.Today >= _uprising_ends and have == 0:
		print("[%s] Lost to unrest - the uprising ran its course with no garrison to answer it." % Name)
		var ousted := ControllingFaction
		ControllingFaction = FactionRegistry.Neutral
		IsInUprising = false
		MilitaryCatalog.OnControlChanged(self, ousted)
		return

	# ATTRITION (manual p091).
	if IsInUprising:
		SufferUprisingLosses()


## ⚠ AN UNDER-GARRISONED WORLD DOES NOT RIOT ON THE SPOT. IT IS WARNED, AND THEN
## IT IS ROLLED FOR, PERIODICALLY (entries 169/170, 175/176, UPRIS1TB).
func ConsiderUprising(need: int, have: int) -> void:
	var rng := Prng.Session
	if _next_uprising_incident == 0:
		_next_uprising_incident = StrategicTickManager.Today + RuleManager.Roll(RuleId.UprisingIncidentBase, RuleId.UprisingIncidentSpread, rng, ControllingFaction)
		WarnGarrison(need, have)
		return

	if StrategicTickManager.Today < _next_uprising_incident:
		return

	var roll := RuleManager.Roll(RuleId.UprisingRollBase, RuleId.UprisingRollSpread, rng, ControllingFaction)

	# Re-armed whichever way the roll goes.
	_next_uprising_incident = StrategicTickManager.Today + RuleManager.Roll(RuleId.UprisingIncidentBase, RuleId.UprisingIncidentSpread, rng, ControllingFaction)

	if UprisingTable.StartOutcome(roll) <= 0:
		print("[%s] Unrest incident passed - rolled %d, order held. Next check day %d." % [Name, roll, _next_uprising_incident])
		WarnGarrison(need, have)
		return

	IsNearUprising = false
	IsInUprising = true
	_uprising_ends = StrategicTickManager.Today + RuleManager.Roll(RuleId.UprisingClearBase, RuleId.UprisingClearSpread, rng, ControllingFaction)
	_next_support_drift = StrategicTickManager.Today + max(1, RuleManager.Get(RuleId.UprisingSupportDriftDelay, ControllingFaction))

	print("[%s] UPRISING - rolled %d, %d regiments against a requirement of %d. Runs to day %d." % [Name, roll, have, need, _uprising_ends])

	if not GameSettings.IsHuman(ControllingFaction):
		return

	# The original's own strings (TEXTSTRA 0x021a66) and the shipped droid advice.
	var msg := GameMessage.new("Uprising Begins on %s" % Name,
		"An uprising has begun on %s. Production there has stopped, and the garrison requirement has doubled to %d regiments while it lasts.\n\nUprisings can be subdued by placing twice the normal garrison on the system, or by sending a character to perform a 'Subdue Uprising' mission at that location." % [Name, GarrisonRequirement()],
		Enums.MessageCategory.Defense, StrategicTickManager.Today, self)
	msg.Type = Enums.MessageType.Uprising
	EventBus.Tell(ControllingFaction, msg)


## THE ORIGINAL'S OWN MESSAGE, word for word (TEXTSTRA 0x00f3f6). Raised once per
## episode, not once per day.
func WarnGarrison(need: int, have: int) -> void:
	if IsNearUprising:
		return
	IsNearUprising = true
	print("[%s] NEAR UPRISING - %d of %d regiments. First unrest check on day %d." % [Name, have, need, _next_uprising_incident])
	if not GameSettings.IsHuman(ControllingFaction):
		return
	var msg := GameMessage.new("Near Uprising",
		"Unrest has pushed %s close to uprising.\n\nIt holds %d trooper regiment(s) against a garrison requirement of %d. Move troops there, or train more, before the populace rises." % [Name, have, need],
		Enums.MessageCategory.Defense, StrategicTickManager.Today, self)
	msg.Type = Enums.MessageType.GarrisonWarning
	EventBus.Tell(ControllingFaction, msg)


## Troops first, then facilities (never the headquarters), then the people
## (manual p091).
func SufferUprisingLosses() -> void:
	var rng := Prng.Session
	if rng.NextRange(1, 101) > UprisingLossChancePercent:
		return

	var regiment: Unit = Lq.first_or_null(Garrison, func(u): return u.Type == Enums.UnitType.Troop)
	if regiment != null:
		Garrison.erase(regiment)
		print("[%s] Uprising: %s destroyed by the populace." % [Name, regiment.Name])
		return

	var fac: Facility = Lq.first_or_null(Facilities, func(f): return f.Type != Enums.FacilityType.Headquarters)
	if fac != null:
		Facilities.erase(fac)
		print("[%s] Uprising: %s destroyed by the populace." % [Name, fac.Name()])
		return

	StrikeAtPersonnel()


## Capture or kill, in the manual's own order; the captor is the side that will
## end up holding the ground (see source).
func StrikeAtPersonnel() -> void:
	var rng := Prng.Session
	var roster := GameState.ActiveRoster
	if roster == null:
		return
	var victim: Character = Lq.first_or_null(roster, func(c):
		return c.Attached == self and c.Faction == ControllingFaction \
			and not c.IsCaptured() and c.Status != Enums.Status.Dead and not c.IsOffMap())
	if victim == null:
		return

	var captor: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f): return f != ControllingFaction)

	var dies := rng.NextRange(1, 101) <= UprisingKilledPercent and not victim.IsMajor
	if dies:
		MissionManager.Kill(victim)
		print("[%s] Uprising: %s killed in the fighting." % [Name, victim.Name])
		return

	victim.CapturedBy = captor
	victim.Status = Enums.Status.Kidnapped
	victim.Commanding = null
	victim.Destination = null
	victim.DaysToDestination = 0

	var hurt := ""
	if rng.NextRange(1, 101) <= CaptureInjuryPercent:
		hurt = " and died of their wounds" if MissionManager.Injure(victim, rng) else " and was injured"

	print("[%s] Uprising: %s seized by the populace%s%s." % [Name, victim.Name, (" and handed to the %s" % captor.DisplayName) if captor != null else "", hurt])


# --- SCRAPPING --- (manual p086; measured: refined 50%, maintenance 100%)
func CanScrap(f: Facility) -> bool:
	return f != null and f.Type != Enums.FacilityType.Headquarters


## DESTROYED, not scrapped: the owner gets nothing back (manual p108).
func DestroyFacility(f: Facility) -> bool:
	if f == null or not Facilities.has(f):
		return false
	Facilities.erase(f)
	print("[%s] %s destroyed." % [Name, f.Name()])
	return true


## WHEREVER IT ACTUALLY IS: garrison, squadrons, a fleet's ships, or a hangar.
func TakeUnitFromWherever(u: Unit) -> bool:
	if Garrison.has(u):
		Garrison.erase(u)
		return true
	if FighterSquadrons.has(u):
		FighterSquadrons.erase(u)
		return true
	for fleet in OrbitingFleets:
		if fleet.Ships.has(u):
			fleet.Ships.erase(u)
			return true
		for ship in fleet.Ships:
			if ship.Hangar != null and ship.Hangar.has(u):
				ship.Hangar.erase(u)
				return true
	return false


func _remove_empty_fleets() -> void:
	for i in range(OrbitingFleets.size() - 1, -1, -1):
		if OrbitingFleets[i].Ships.is_empty():
			OrbitingFleets.remove_at(i)


func DestroyUnit(u: Unit) -> bool:
	if u == null:
		return false
	if not TakeUnitFromWherever(u):
		return false
	# "If you move all the ships out of a fleet, the fleet is automatically disbanded" (p120).
	_remove_empty_fleets()
	print("[%s] %s destroyed." % [Name, u.Name])
	return true


func ScrapFacility(f: Facility) -> int:
	if not CanScrap(f) or not Facilities.has(f):
		return 0
	Facilities.erase(f)
	var refund := FacilityCatalog.ConstructionCost(f.Type, f.Tier) * ScrapRefundPercent / 100
	Economy.For(ControllingFaction).RefinedMaterials += refund
	print("[%s] Scrapped %s: +%d refined, +%d maintenance, energy slot freed." % [Name, f.Name(), refund, FacilityCatalog.MaintenanceCost(f.Type, f.Tier)])
	return refund


## "You can scrap any facility, troop, or ship in this way" (manual p086).
func ScrapUnit(u: Unit) -> int:
	if u == null:
		return 0
	if not TakeUnitFromWherever(u):
		return 0
	_remove_empty_fleets()
	var refund := u.ConstructionCost * ScrapRefundPercent / 100
	Economy.For(ControllingFaction).RefinedMaterials += refund
	print("[%s] Scrapped %s: +%d refined, +%d maintenance." % [Name, u.Name, refund, u.MaintenanceCost])
	return refund


## The production queue a given kind of facility feeds (manual p114). Returns
## null for anything that is not a producer.
func QueueFor(producer: int) -> Variant:
	match producer:
		Enums.FacilityType.Shipyard:         return ShipyardQueue
		Enums.FacilityType.TrainingFacility: return TrainingQueue
		Enums.FacilityType.ConstructionYard: return BuildingQueue
	return null


## "STOP: halt construction of the current item" (manual p114) - the current
## item of THAT producer's queue. Refined material comes back; maintenance
## releases itself because Economy reads the queue.
func CancelCurrentBuild(producer: int) -> void:
	var queue: Variant = QueueFor(producer)
	if queue == null or queue.is_empty():
		return
	var job: ConstructionTask = queue.pop_front()
	Economy.For(ControllingFaction).RefinedMaterials += job.RefinedCost
	print("[%s] Cancelled %s, refunded %d refined." % [Name, job.DisplayName(), job.RefinedCost])


func AddFacility(type: int, tier: int = 1) -> void:
	var new_fac := Facility.new()
	new_fac.Type = type
	new_fac.Tier = tier
	# If it's a defensive structure, look up its authentic combat stats.
	if type == Enums.FacilityType.PlanetaryShield or type == Enums.FacilityType.TurbolaserBattery or type == Enums.FacilityType.IonCannon:
		var key := Vector2i(type, tier)
		if SeedManager.DefenseStats.has(key):
			var stats: CatalogDtos.DefenseStatRule = SeedManager.DefenseStats[key]
			new_fac.ConstructionCost = stats.ConstructionCost
			new_fac.MaintenanceCost = stats.MaintenanceCost
			new_fac.WeaponRating = stats.WeaponRating
			new_fac.ShieldStrength = stats.ShieldStrength
	var rule := FacilityCatalog.Get(type, tier)
	new_fac.BombardmentDefense = rule.BombardmentDefense if rule != null else 0
	new_fac.Attached = self
	Facilities.append(new_fac)
	print("[%s] Added Facility: %s (Tier %d)" % [Name, JsonUtil.enum_name(Enums.FacilityType, type), tier])


func FinishConstruction(completed_job: ConstructionTask) -> void:
	if completed_job.Destination != null and completed_job.Destination != self and completed_job.TransportDays > 0:
		_in_transit.append(completed_job)
		print("[%s] %s built, en route to %s - %dd." % [Name, completed_job.DisplayName(), completed_job.Destination.Name, completed_job.TransportDays])
		return
	Deliver(completed_job, completed_job.Destination if completed_job.Destination != null else self)


## A finished order becomes a real thing at its destination.
static func Deliver(job: ConstructionTask, destination: Planet) -> void:
	if job.UnitRule != null:
		var unit := MilitaryCatalog.Create(job.UnitRule, destination.ControllingFaction, destination)
		MilitaryCatalog.Deploy(unit, destination)
		var cat := Enums.MessageCategory.Defense if (unit.Type == Enums.UnitType.Troop or unit.Type == Enums.UnitType.SpecForce) else Enums.MessageCategory.Manufacturing
		ReportDelivery(destination, unit.Name, cat)
		return

	destination.AddFacility(job.Type, job.Tier)
	var category: int
	match job.Type:
		Enums.FacilityType.Mine, Enums.FacilityType.Refinery:
			category = Enums.MessageCategory.Resources
		Enums.FacilityType.PlanetaryShield, Enums.FacilityType.TurbolaserBattery, Enums.FacilityType.IonCannon:
			category = Enums.MessageCategory.Defense
		_:
			category = Enums.MessageCategory.Manufacturing
	var rule := FacilityCatalog.Get(job.Type, job.Tier)
	ReportDelivery(destination, rule.Name if rule != null else JsonUtil.enum_name(Enums.FacilityType, job.Type), category)


static func ReportDelivery(where: Planet, what: String, category: int) -> void:
	if not GameSettings.IsHuman(where.ControllingFaction):
		return
	var msg := GameMessage.new("%s ready at %s" % [what, where.Name],
		"Construction of %s is complete and it has been deployed on %s." % [what, where.Name],
		category, StrategicTickManager.Today, where)
	msg.Type = Enums.MessageType.UnitDeployment
	EventBus.Tell(where.ControllingFaction, msg)


# --- Popular support --- a percentage PER PLAYABLE FACTION, summing to 100.
func Support() -> Dictionary:
	EnsureSupportInitialised()
	return _support


func EnsureSupportInitialised() -> void:
	if _support.size() > 0 or FactionRegistry.Playable.is_empty():
		return
	SetEvenSupport()


func SetEvenSupport() -> void:
	var playable := FactionRegistry.Playable
	if playable.is_empty():
		return
	var each := 100 / playable.size()
	for f in playable:
		_support[f.Id] = each
	_support[playable[0].Id] += 100 - (each * playable.size())


func SupportFor(faction: Faction) -> int:
	if faction == null:
		return 0
	EnsureSupportInitialised()
	return _support.get(faction.Id, 0)


## C# Math.Round rounds half to EVEN; GDScript round() rounds half away from zero.
static func _round_to_even(x: float) -> int:
	var f: float = floorf(x)
	var diff: float = x - f
	var fi: int = int(f)
	if diff > 0.5:
		return fi + 1
	if diff < 0.5:
		return fi
	return fi if fi % 2 == 0 else fi + 1


## Set one faction's support and rebalance the others so the total stays 100.
## This is the ONLY mutator.
func SetSupportFor(faction: Faction, pct: int) -> void:
	if faction == null or FactionRegistry.OrderOf(faction) < 0:
		return
	EnsureSupportInitialised()
	pct = clampi(pct, 0, 100)
	_support[faction.Id] = pct

	var others := Lq.where(FactionRegistry.Playable, func(f): return f != faction)
	if others.is_empty():
		_support[faction.Id] = 100
		return

	var remainder := 100 - pct
	var others_total := 0
	for f in others:
		others_total += _support.get(f.Id, 0)

	var assigned := 0
	for i in others.size():
		var share: int
		if i == others.size() - 1:
			share = remainder - assigned
		elif others_total <= 0:
			share = remainder / others.size()
		else:
			var current: int = _support.get(others[i].Id, 0)
			share = _round_to_even(remainder * (float(current) / float(others_total)))
		_support[others[i].Id] = share
		assigned += share


func ShiftSupport(faction: Faction, delta: int) -> void:
	if faction == null:
		return
	SetSupportFor(faction, SupportFor(faction) + delta)


## Color encodes CONTROL and nothing else (manual fig 2.6).
func GetFactionColor() -> Color:
	if not IsExplored:
		return FactionRegistry.Unknown.FactionColor
	return ControllingFaction.FactionColor if ControllingFaction != null else FactionRegistry.Unknown.FactionColor


## ONE SHIP LEAVING A FLEET BECOMES A FLEET OF ITS OWN (manual p115, p120).
func DetachIntoOwnFleet(ship: Unit) -> Fleet:
	if ship == null:
		return null
	var parent: Fleet = Lq.first_or_null(OrbitingFleets, func(f): return f.Ships.has(ship))
	if parent == null:
		return null
	if parent.Ships.size() <= 1:
		return parent
	parent.Ships.erase(ship)

	var serial := Fleet.NextSerial()
	var split := Fleet.new()
	split.ID = Fleet.IdFor(serial)
	split.Name = "%s Fleet_%04d" % [ControllingFaction.DisplayName if ControllingFaction != null else "", serial]
	split.Faction = ship.Faction if ship.Faction != null else ControllingFaction
	split.Attached = self
	split.Status = Enums.Status.AwaitingOrders
	split.AddShip(ship)
	OrbitingFleets.append(split)
	print("[%s] %s split from %s into %s." % [Name, ship.Name, parent.Name, split.Name])
	return split


func AddCapitalShip(unit: Unit) -> void:
	if unit == null:
		return
	if OrbitingFleets.is_empty():
		var serial := Fleet.NextSerial()
		var fleet := Fleet.new()
		fleet.ID = Fleet.IdFor(serial)
		fleet.Name = "%s Fleet_%04d" % [ControllingFaction.DisplayName, serial]
		fleet.Faction = ControllingFaction
		fleet.Attached = self
		fleet.Status = Enums.Status.AwaitingOrders
		OrbitingFleets.append(fleet)
		OrbitingFleets[0].AddShip(unit)
	else:
		OrbitingFleets[0].AddShip(unit)
