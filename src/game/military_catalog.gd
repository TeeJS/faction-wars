class_name MilitaryCatalog
extends RefCounted
## backend/MilitaryCatalog.cs - what a faction can build at a shipyard or a
## training facility, and the one place a Unit is constructed from its stat rule.
## Orbital shipyard -> capital ships and fighters; training facility -> troops
## AND Special Forces (manual p097, p113, p129).


## THE PACK IS THE CATALOG (SCHEMA.md section 6). Units and their weapon classes
## are pack data; the engine asks a weapon what it DOES, never whether it is a
## turbolaser.

## Vector2i(source family, source id) -> PackDefs.UnitDef - the key a day-zero
## logistics row names a unit by.
static var _by_source: Dictionary = {}
static var _all: Array = []
## The pack's weapon classes IN DECLARED ORDER. Iteration order decides the order
## arcs are summed in, so it must be the file's order, not a hash map's.
static var _weapons: Array = []
static var _weapon_by_id: Dictionary = {}
static var _by_id: Dictionary = {}          # unit id -> UnitDef


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_by_source.clear()
	_by_id.clear()
	_all.clear()
	_weapons.clear()
	_weapon_by_id.clear()
	if pack == null:
		push_error("[MilitaryCatalog] no pack loaded!")
		return
	for w in pack.Weapons:
		_weapons.append(w)
		_weapon_by_id[w.Id] = w
	for def in pack.Units:
		_all.append(def)
		_by_id[def.Id] = def
		_by_source[Vector2i(def.SourceFamilyId, def.SourceId)] = def
	print("[MilitaryCatalog] Loaded %d units and %d weapon classes from the pack." % [_all.size(), _weapons.size()])


static func WeaponOrder() -> Array:
	return _weapons


static func WeaponById(id: String) -> PackDefs.WeaponDef:
	return _weapon_by_id.get(id)


static func ById(id: String) -> PackDefs.UnitDef:
	return _by_id.get(id)


## The roles units.json gives this unit (SCHEMA.md section 6).
static func RolesOf(id: String) -> Array:
	var d: PackDefs.UnitDef = _by_id.get(id)
	return d.Roles if d != null else []


static func BySource(key: Vector2i) -> PackDefs.UnitDef:
	return _by_source.get(key)


static func HasSource(key: Vector2i) -> bool:
	return _by_source.has(key)


## UnitType or null for an unrecognised kind.
static func TypeOf(rule: PackDefs.UnitDef) -> Variant:
	if rule == null:
		return null
	match rule.Kind:
		"capital_ship": return Enums.UnitType.CapitalShip
		"fighter":      return Enums.UnitType.Fighter
		"troop":        return Enums.UnitType.Troop
		"spec_force":   return Enums.UnitType.SpecForce
	return null


## Which facility ROLE builds this kind of unit (SCHEMA.md section 5).
static func ProducerFor(type: int) -> String:
	if type == Enums.UnitType.CapitalShip or type == Enums.UnitType.Fighter:
		return "produces_unit"
	return "produces_troop"


static func CanBeBuiltBy(rule: PackDefs.UnitDef, f: Faction) -> bool:
	return rule != null and rule.CanBeBuiltBy(f)


## Every rule, for the research tree to walk.
static func All() -> Array:
	return _all


## Everything `faction` may build at `producer`, cheapest first. Zero-cost
## entries are excluded (the one is "Bounty Hunters", a scripted event); the
## tables repeat a name per tier, so one per name.
static func BuildableAt(producer: String, faction: Faction) -> Array:
	var seen := {}
	var out := []
	for r in _all:
		if r.ConstructionCost <= 0:
			continue
		if not ResearchManager.IsUnlockedUnit(faction, r):
			continue
		if not CanBeBuiltBy(r, faction):
			continue
		var t: Variant = TypeOf(r)
		if t == null or ProducerFor(t) != producer:
			continue
		if seen.has(r.DisplayName):
			continue
		seen[r.DisplayName] = true
		out.append(r)
	return Lq.order_by(out, func(r): return r.ConstructionCost)


static func _or0(v: Variant) -> int:
	return 0 if v == null else int(v)


## The single place a Unit is built from its pack definition. A stat the pack
## does not declare is absent, not null, and stands in as 0.
static func Create(def: PackDefs.UnitDef, faction: Faction, at: Location) -> Unit:
	if def == null:
		return null
	var u := Unit.new()
	u.Name = def.DisplayName
	var t: Variant = TypeOf(def)
	u.Type = t if t != null else Enums.UnitType.Troop
	u.AssetId = def.SourceId
	u.FamilyId = def.SourceFamilyId
	u.PackId = def.Id
	u.Faction = faction
	u.Attached = at

	u.ConstructionCost = def.ConstructionCost
	u.MaintenanceCost = def.MaintenanceCost

	u.Detection = def.stat("detection")
	u.BombardmentDefense = def.stat("bombardment_defense")
	u.Bombardment = def.stat("bombardment")
	u.Hull = def.stat("hull")
	u.Shield = def.stat("shield")
	u.Attack = def.stat("attack")
	u.Defense = def.stat("defense")
	u.Sublight = def.stat("sublight")
	u.Hyperdrive = def.stat("hyperdrive")
	u.FighterCapacity = def.stat("fighter_capacity")
	u.TroopCapacity = def.stat("troop_capacity")
	u.Maneuverability = def.stat("maneuverability")
	u.HyperdriveDamaged = def.stat("hyperdrive_damaged")
	u.DamageControl = def.stat("damage_control")
	u.WeaponRecharge = def.stat("weapon_recharge")
	u.ShieldRecharge = def.stat("shield_recharge")
	u.TractorPower = def.stat("tractor_power")
	u.TractorRange = def.stat("tractor_range")
	u.GravityWell = def.stat("gravity_well")
	u.InterdictionStrength = def.stat("interdiction_strength")
	u.SquadronSize = def.stat("squadron_size")

	# Whatever the pack fitted, by id. Nothing here names a weapon class.
	u.Weapons = def.Weapons.duplicate()

	## A SpecForce's mission ratings (manual p101). Zero for everything else.
	u.DiplomacyRating = def.stat("diplomacy_rating")
	u.EspionageRating = def.stat("espionage_rating")
	u.CombatRating = def.stat("combat_rating")
	u.LeadershipRating = def.stat("leadership_rating")
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
	# LOSING A WORLD IS WITNESSING IT. Without a sighting captured now, a world you
	# just lost has no owner-of-record (View is live only while you HOLD it), so the
	# map would grey it out or keep showing it as yours. A battle/uprising at the
	# system reveals what a Reconnaissance would (manual p121-p123), so record that -
	# the settled, post-withdrawal state - dated today. Human sides only: this is a
	# player-facing correction; the AI's own knowledge model is handled apart.
	if GameSettings.IsHuman(former_holder):
		IntelManager.Capture(former_holder, lost, StrategicTickManager.Today, IntelManager.ReconnaissanceCategories)
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
