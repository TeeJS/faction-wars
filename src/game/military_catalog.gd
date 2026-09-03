class_name MilitaryCatalog
extends RefCounted
## backend/MilitaryCatalog.cs - what a faction can build at a shipyard or a
## training facility, and the one place a Unit is constructed from its stat rule.
## Orbital shipyard -> capital ships and fighters; training facility -> troops
## AND Special Forces (manual p097, p113, p129).


## UnitType or null for an unrecognised Type string.
static func TypeOf(rule: CatalogDtos.UnitStatRule) -> Variant:
	if rule == null:
		return null
	match rule.Type:
		"CapitalShip": return Enums.UnitType.CapitalShip
		"Fighter":     return Enums.UnitType.Fighter
		"Troop":       return Enums.UnitType.Troop
		"SpecForce":   return Enums.UnitType.SpecForce
	return null


## Which facility builds this kind of unit.
static func ProducerFor(type: int) -> int:
	if type == Enums.UnitType.CapitalShip or type == Enums.UnitType.Fighter:
		return Enums.FacilityType.Shipyard
	return Enums.FacilityType.TrainingFacility


static func CanBeBuiltBy(rule: CatalogDtos.UnitStatRule, f: Faction) -> bool:
	return f != null and rule != null and rule.BuildableBy != null and rule.BuildableBy.has(f.Id)


## Every rule, for the research tree to walk.
static func All() -> Array:
	return SeedManager.MilitaryStats.values()


## Everything `faction` may build at `producer`, cheapest first. Zero-cost
## entries are excluded (the one is "Bounty Hunters", a scripted event); the
## tables repeat a name per tier, so one per name.
static func BuildableAt(producer: int, faction: Faction) -> Array:
	var seen := {}
	var out := []
	for r in SeedManager.MilitaryStats.values():
		if r.ConstructionCost <= 0:
			continue
		if not ResearchManager.IsUnlockedUnit(faction, r):
			continue
		if not CanBeBuiltBy(r, faction):
			continue
		var t: Variant = TypeOf(r)
		if t == null or ProducerFor(t) != producer:
			continue
		if seen.has(r.Name):
			continue
		seen[r.Name] = true
		out.append(r)
	return Lq.order_by(out, func(r): return r.ConstructionCost)


static func _or0(v: Variant) -> int:
	return 0 if v == null else int(v)


## The single place a Unit is built from its stat rule. Stats that do not apply
## to a unit class are null in the seed data and stand in as 0.
static func Create(stats: CatalogDtos.UnitStatRule, faction: Faction, at: Location) -> Unit:
	if stats == null:
		return null
	var u := Unit.new()
	u.Name = stats.Name
	var t: Variant = TypeOf(stats)
	u.Type = t if t != null else Enums.UnitType.Troop
	u.AssetId = stats.Id
	u.FamilyId = stats.FamilyId
	u.Faction = faction
	u.Attached = at

	u.ConstructionCost = stats.ConstructionCost
	u.MaintenanceCost = stats.MaintenanceCost
	u.Detection = stats.Detection

	u.BombardmentDefense = _or0(stats.BombardmentDefense)
	u.Bombardment = _or0(stats.Bombardment)
	u.Turbolaser = _or0(stats.Turbolaser)
	u.LaserRating = _or0(stats.LaserRating)
	u.IonCannon = _or0(stats.IonCannon)
	u.Torpedoes = _or0(stats.Torpedoes)
	u.Hull = _or0(stats.Hull)
	u.Shield = _or0(stats.Shield)
	u.Attack = _or0(stats.Attack)
	u.Defense = _or0(stats.Defense)
	u.Sublight = _or0(stats.Sublight)
	u.Hyperdrive = _or0(stats.Hyperdrive)
	u.FighterCapacity = _or0(stats.FighterCapacity)
	u.TroopCapacity = _or0(stats.TroopCapacity)

	u.Maneuverability = _or0(stats.Maneuverability)
	u.HyperdriveDamaged = _or0(stats.HyperdriveDamaged)
	u.DamageControl = _or0(stats.DamageControl)
	u.WeaponRecharge = _or0(stats.WeaponRecharge)
	u.ShieldRecharge = _or0(stats.ShieldRecharge)
	u.TractorPower = _or0(stats.TractorPower)
	u.TractorRange = _or0(stats.TractorRange)
	u.GravityWell = _or0(stats.GravityWell)
	u.InterdictionStrength = _or0(stats.InterdictionStrength)
	u.SquadronSize = _or0(stats.SquadronSize)
	u.TurbolaserRange = _or0(stats.TurbolaserRange)
	u.IonCannonRange = _or0(stats.IonCannonRange)
	u.LaserRange = _or0(stats.LaserRange)
	u.TorpedoRange = _or0(stats.TorpedoRange)

	u.TurbolaserArc = [_or0(stats.TurbolaserFore), _or0(stats.TurbolaserAft), _or0(stats.TurbolaserStarboard), _or0(stats.TurbolaserPort)]
	u.IonCannonArc = [_or0(stats.IonCannonFore), _or0(stats.IonCannonAft), _or0(stats.IonCannonStarboard), _or0(stats.IonCannonPort)]
	u.LaserArc = [_or0(stats.LaserFore), _or0(stats.LaserAft), _or0(stats.LaserStarboard), _or0(stats.LaserPort)]

	## A SpecForce's mission ratings (manual p101). Zero for everything else.
	u.DiplomacyRating = _or0(stats.DiplomacyRating)
	u.EspionageRating = _or0(stats.EspionageRating)
	u.CombatRating = _or0(stats.CombatRating)
	u.LeadershipRating = _or0(stats.LeadershipRating)
	return u


## Where a finished unit goes (manual p114, p129, p097).
static func Deploy(unit: Unit, destination: Planet) -> void:
	if unit == null or destination == null:
		return
	unit.Attached = destination
	unit.Faction = destination.ControllingFaction
	unit.Status = Enums.Status.AwaitingOrders
	match unit.Type:
		Enums.UnitType.CapitalShip:
			destination.AddCapitalShip(unit)
		Enums.UnitType.Fighter:
			destination.FighterSquadrons.append(unit)
		_:
			destination.Garrison.append(unit)
	print("[%s] Deployed %s (%s)." % [destination.Name, unit.Name, JsonUtil.enum_name(Enums.UnitType, unit.Type)])


## MOVE A UNIT BETWEEN SYSTEMS, LISTS AND ALL. A character IS just its anchor;
## a capital ship's home is its fleet.
static func Relocate(unit: Unit, to: Planet) -> void:
	if unit == null or to == null:
		return
	if not (unit is Character) and unit.Type != Enums.UnitType.CapitalShip:
		if unit.Attached is Planet and unit.Attached != to:
			var from: Planet = unit.Attached
			from.Garrison.erase(unit)
			from.FighterSquadrons.erase(unit)
		var home: Array = to.FighterSquadrons if unit.Type == Enums.UnitType.Fighter else to.Garrison
		if not home.has(unit):
			home.append(unit)
	unit.Attached = to


## EVERYTHING THE LOSER LEAVES BEHIND WHEN A WORLD CHANGES HANDS. One entry
## point, called from every place ControllingFaction is reassigned. Both fates
## are ★ measured in the original game.
static func OnControlChanged(lost: Planet, former_holder: Faction) -> void:
	if lost == null or former_holder == null:
		return
	if lost.ControllingFaction == former_holder:
		return
	_withdraw_personnel(lost, former_holder)
	_disband_ground_fighters(lost, former_holder)
	EventBus.BroadcastChanged()


## GROUND FIGHTER SQUADRONS ARE DESTROYED WITH THE WORLD (★ measured).
static func _disband_ground_fighters(lost: Planet, former_holder: Faction) -> void:
	var doomed := Lq.where(lost.FighterSquadrons, func(u): return u.Faction == former_holder)
	if doomed.is_empty():
		return
	for u in doomed:
		lost.FighterSquadrons.erase(u)
		u.Attached = null
		u.Status = Enums.Status.Dead
	print("[%s] %d of %s's ground fighter squadrons were lost with the world." % [lost.Name, doomed.size(), former_holder.DisplayName])
	if not GameSettings.IsHuman(former_holder):
		return
	var names := Lq.join(Lq.select(doomed, func(u): return u.Name))
	EventBus.Tell(former_holder, GameMessage.new(
		"Squadrons lost with %s" % lost.Name,
		"%s is no longer ours. %s %s on the ground there and %s lost." % [
			lost.Name, names, "was" if doomed.size() == 1 else "were", "is" if doomed.size() == 1 else "are"],
		Enums.MessageCategory.Defense, StrategicTickManager.Today, lost))


## A WORLD THAT CHANGES HANDS PUTS THE LOSER'S PEOPLE OFF IT (★ measured). The
## refuge is "a friendly system NEAREST to where the mission concluded" (p111).
static func _withdraw_personnel(lost: Planet, former_holder: Faction) -> void:
	var leaving: Array = []
	for c in GameState.ActiveRoster:
		if c.Faction == former_holder and c.Attached == lost \
				and c.Status != Enums.Status.Enroute and c.Status != Enums.Status.Dead \
				and not c.IsCaptured():
			leaving.append(c)
	# "Personnel" is characters AND Special Forces (manual p126).
	for u in lost.SpecForces():
		if u.Faction == former_holder and u.Status != Enums.Status.Enroute:
			leaving.append(u)
	if leaving.is_empty():
		return

	var refuge := NearestHeldBy(former_holder, lost)
	if refuge == null:
		print("[%s] %d of %s's personnel have nowhere to go - their side holds no world to fall back to." % [lost.Name, leaving.size(), former_holder.DisplayName])
		return

	for u in leaving:
		Relocate(u, refuge)
		u.Status = Enums.Status.AwaitingOrders

	print("[%s] %d of %s's personnel withdrew to %s when the world was lost." % [lost.Name, leaving.size(), former_holder.DisplayName, refuge.Name])

	if GameSettings.IsHuman(former_holder):
		var names := Lq.join(Lq.select(leaving, func(u): return u.Name))
		EventBus.Tell(former_holder, GameMessage.new(
			"Personnel withdrawn from %s" % lost.Name,
			"%s is no longer ours. %s %s fallen back to %s." % [lost.Name, names, "has" if leaving.size() == 1 else "have", refuge.Name],
			Enums.MessageCategory.Defense, StrategicTickManager.Today, refuge))


static func NearestHeldBy(f: Faction, from: Planet) -> Planet:
	if from == null:
		return null
	var held := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == f)
	var sorted := Lq.order_by(held, func(p): return [from.DeploymentDaysTo(p), p.Name])
	return sorted[0] if not sorted.is_empty() else null
