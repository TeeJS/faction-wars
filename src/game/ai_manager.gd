class_name AiManager
extends RefCounted
## backend/AiManager.cs - THE OPPONENT. What survives as sourced from the binary:
## neutral entities are never acted on; dispatch is gated on the maintenance
## budget (FUN_0052e970); daily cadence. The rest follows what the community
## observed - concentrated and short-sighted - and a project ruling that the AI
## does NOT see through fog. Per-day caps are OURS. Difficulty is not an AI dial.

const MovesPerDay := 1
const MissionsPerDay := 1
const ShipsPerDay := 1
const WeakSupportCeiling := 50

static var _announced: bool = false
static var DriveAllFactions: bool = false
static var _front: Dictionary = {}   # faction id -> Sector


static func Reset() -> void:
	_announced = false
	DriveAllFactions = false
	_front.clear()


class GalaxyView:
	var Us: Faction
	var OursStrong: Array = []
	var OursWeak: Array = []
	var TheirsStrong: Array = []
	var TheirsWeak: Array = []
	var Neutral: Array = []
	var Unexplored: Array = []
	var Threatened: Array = []


class Budget:
	var Moves: int = MovesPerDay
	var Missions: int = MissionsPerDay
	var Ships: int = ShipsPerDay


static func ProcessDay(galaxy: Array, day: int, rng: Prng) -> void:
	if galaxy == null:
		return
	for f in FactionRegistry.Playable:
		if not DriveAllFactions and GameSettings.IsHuman(f):
			continue
		if not AgentDroid.ManagingProduction(f):
			AgentDroid.SetManageProduction(f, true)
		if not AgentDroid.ManagingGarrisons(f):
			AgentDroid.SetManageGarrisons(f, true)
		if not _announced:
			print("[AI] %s is under AI control." % f.DisplayName)
		var budget := Budget.new()
		Dispatch(Evaluate(galaxy, f), f, day, rng, budget)
		Dispatch(Evaluate(galaxy, f), f, day, rng, budget)
	_announced = true


## STAGE 1 - categorise the whole galaxy, intel-gated for other sides' worlds.
static func Evaluate(galaxy: Array, us: Faction) -> GalaxyView:
	var view := GalaxyView.new()
	view.Us = us
	for s in galaxy:
		for p in s.Planets:
			if not p.ExploredBy(us):
				view.Unexplored.append(p)
				continue
			if not p.IsInhabited:
				continue
			var owner: Faction = p.ControllingFaction
			if owner == us:
				if Lq.any(p.FleetsInOrbit(), func(f): return f.Faction != null and f.Faction != us and not f.IsEmpty()):
					view.Threatened.append(p)
				if p.SupportFor(us) < WeakSupportCeiling:
					view.OursWeak.append(p)
				else:
					view.OursStrong.append(p)
			elif owner == null or owner == FactionRegistry.Neutral:
				view.Neutral.append(p)
			else:
				if not IntelManager.Knows(us, p, Enums.IntelSection.SystemStatus):
					continue
				if p.SupportFor(owner) < WeakSupportCeiling:
					view.TheirsWeak.append(p)
				else:
					view.TheirsStrong.append(p)
	return view


## Unseen is UNKNOWN (-1), not empty.
static func SeenDefendingShips(p: Planet, us: Faction) -> int:
	if not IntelManager.Knows(us, p, Enums.IntelSection.OrbitingShips):
		return -1
	return Lq.sum(Lq.where(p.FleetsInOrbit(), func(x): return x.Faction == p.ControllingFaction), func(x): return x.Ships.size())


## STAGE 2 - a COUNT, not a weighted score.
static func StrengthAt(p: Planet, f: Faction) -> int:
	var ships := Lq.sum(Lq.where(p.FleetsInOrbit(), func(x): return x.Faction == f), func(x): return x.Ships.size())
	var troops := Lq.count(p.Garrison, func(u): return u.Faction == f)
	var fighters := Lq.count(p.FighterSquadrons, func(u): return u.Faction == f)
	var facilities := (p.Shipyards() + p.TrainingFacilities() + p.ConstructionYards()) if p.ControllingFaction == f else 0
	return ships + troops + fighters + facilities


static func Dispatch(view: GalaxyView, us: Faction, day: int, rng: Prng, budget: Budget) -> void:
	BuildWarships(us, budget)
	Invade(view, us, day, rng, budget)
	MoveFleets(view, us, day, budget)
	LaunchMissions(view, us, day, rng, budget)


## A fleet already flying at a target counts as an answer to it.
static func AlreadyAnswered(target: Planet, us: Faction) -> bool:
	if Lq.any(target.OrbitingFleets, func(f): return f.Faction == us and not f.IsEmpty()):
		return true
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and not f.IsEmpty() and f.Destination == target:
				return true
	return false


static func MoveFleets(view: GalaxyView, us: Faction, _day: int, budget: Budget) -> void:
	if budget.Moves <= 0:
		return
	var guarded := view.Threatened
	var busy := func(f: Fleet) -> bool:
		if not (f.Attached is Planet):
			return false
		var where: Planet = f.Attached
		if guarded.has(where):
			return true
		return BlockadeManager.BlockaderOf(where) == us

	var idle: Array = []
	for p in GameState.AllPlanets():
		for f in p.FleetsInOrbit():
			if f.Faction == us and not f.IsEmpty() and f.Status != Enums.Status.Enroute and not busy.call(f):
				idle.append(f)
	if idle.is_empty():
		return

	# 1. RELIEVE A THREATENED WORLD, weakest first.
	for target in Lq.order_by(view.Threatened, func(p): return StrengthAt(p, us)):
		if budget.Moves <= 0:
			return
		if AlreadyAnswered(target, us):
			continue
		var relief := Nearest(idle, target)
		if relief == null:
			continue
		var moved := OrderManager.MoveFleets([relief], target)
		if moved.ok:
			print("[AI] %s: %s sent to relieve %s (%dd)." % [us.Id, relief.Name, target.Name, moved.value])
			idle.erase(relief)
			budget.Moves -= 1

	# 2. PRESS A WEAK ENEMY WORLD - IN ONE SECTOR AT A TIME.
	var candidates: Array = view.TheirsWeak + view.TheirsStrong
	if candidates.is_empty():
		return
	var front := CurrentFront(us, candidates)
	if front == null:
		return

	var in_front := Lq.where(candidates, func(p): return SectorOf(p) == front)
	for target in Lq.order_by(in_front, func(p): return max(0, SeenDefendingShips(p, us))):
		if budget.Moves <= 0:
			return
		if AlreadyAnswered(target, us):
			continue
		var strike := Nearest(idle, target)
		if strike == null:
			continue
		var defending := SeenDefendingShips(target, us)
		if defending < 0:
			continue
		if strike.Ships.size() < defending:
			continue
		if not CanAffordToCommit(us, strike):
			return
		var moved := OrderManager.MoveFleets([strike], target)
		if moved.ok:
			print("[AI] %s: %s moving on %s in %s (%dd, %d seen defending)." % [us.Id, strike.Name, target.Name, front.Name, moved.value, defending])
			idle.erase(strike)
			budget.Moves -= 1


## ★ Bounded by the maintenance gate; the most capable hull the side can run (⚠ ours).
static func BuildWarships(us: Faction, budget: Budget) -> void:
	if budget.Ships <= 0:
		return
	var yards := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == us and p.HasIdleShipyards())
	var by_size := Lq.order_by(yards, func(p): return p.Shipyards(), true)
	if by_size.is_empty():
		return
	var yard: Planet = by_size[0]
	var headroom := Economy.MaintenanceAvailable(us)
	var affordable := Lq.where(MilitaryCatalog.All(), func(u): return u.Type == "CapitalShip" and MilitaryCatalog.CanBeBuiltBy(u, us) and u.MaintenanceCost <= headroom)
	var picks := Lq.order_by(affordable, func(u): return u.ConstructionCost, true)
	if picks.is_empty():
		return
	var pick: CatalogDtos.UnitStatRule = picks[0]
	if not yard.TryQueueUnit(pick, yard).ok:
		return
	print("[AI] %s: laid down a %s at %s (maint %d of %d free)." % [us.Id, pick.Name, yard.Name, pick.MaintenanceCost, headroom])
	budget.Ships -= 1


## INVASION (manual p057): assault with a loaded fleet in position, else load.
static func Invade(_view: GalaxyView, us: Faction, day: int, rng: Prng, budget: Budget) -> void:
	var fleets: Array = []
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and f.Status != Enums.Status.Enroute:
				fleets.append(f)

	for f in fleets:
		if not (f.Attached is Planet):
			continue
		var target: Planet = f.Attached
		if not AssaultManager.CanAssault(f, target).ok:
			continue
		AssaultManager.Resolve(f, target, rng, day)
		print("[AI] %s: assaulted %s - %s." % [us.Id, target.Name, "TAKEN" if target.ControllingFaction == us else "repulsed"])
		return

	if budget.Moves <= 0:
		return

	for f in fleets:
		if not (f.Attached is Planet):
			continue
		var home: Planet = f.Attached
		if home.ControllingFaction != us:
			continue
		if Lq.sum(f.Ships, func(sh): return sh.TroopCapacity) == 0:
			continue
		if Lq.any(f.Ships, func(sh): return Lq.any(sh.Hangar, func(h): return h.Type == Enums.UnitType.Troop)):
			continue
		var spare: int = home.TrooperRegiments() - max(1, home.GarrisonRequirement())
		if spare <= 0:
			continue
		var lift := Lq.where(home.Garrison, func(u): return u.Type == Enums.UnitType.Troop).slice(0, spare)
		if lift.is_empty():
			continue
		var loaded := OrderManager.LoadAboard(lift, f)
		if loaded.value > 0:
			print("[AI] %s: %d regiment(s) embarked on %s at %s." % [us.Id, loaded.value, f.Name, home.Name])
		return


## THE FRONT: held while the sector still offers a target.
static func CurrentFront(us: Faction, candidates: Array) -> Sector:
	if _front.has(us.Id):
		var held: Sector = _front[us.Id]
		if Lq.any(candidates, func(p): return SectorOf(p) == held):
			return held
	# The sector where we can see the most of their worlds - GroupBy keeps first-
	# seen order, OrderByDescending(count) is stable.
	var order: Array = []
	var counts: Dictionary = {}
	for p in candidates:
		var s := SectorOf(p)
		if s == null:
			continue
		if not counts.has(s):
			counts[s] = 0
			order.append(s)
		counts[s] += 1
	var sorted := Lq.order_by(order, func(s): return counts[s], true)
	var chosen: Sector = sorted[0] if not sorted.is_empty() else null
	if chosen != null:
		_front[us.Id] = chosen
		print("[AI] %s: front is now %s." % [us.Id, chosen.Name])
	return chosen


static func SectorOf(p: Planet) -> Sector:
	for s in GameState.ActiveGalaxy:
		if s.Planets.has(p):
			return s
	return null


## ★ THE MAINTENANCE GATE (FUN_0052e970).
static func CanAffordToCommit(us: Faction, f: Fleet) -> bool:
	var available := Economy.MaintenanceAvailable(us)
	var cost := Lq.sum(f.Ships, func(s): return s.MaintenanceCost)
	return available >= cost


static func Nearest(fleets: Array, to: Planet) -> Fleet:
	var in_orbit := Lq.where(fleets, func(f): return f.Attached is Planet)
	var sorted := Lq.order_by(in_orbit, func(f): return (f.Attached as Planet).DeploymentDaysTo(to))
	return sorted[0] if not sorted.is_empty() else null


## CHARACTERS: the AI's mission handler. Targets in the manual's own priority.
static func LaunchMissions(view: GalaxyView, us: Faction, _day: int, _rng: Prng, budget: Budget) -> void:
	if budget.Missions <= 0:
		return
	var free := Lq.where(GameState.ActiveRoster, func(c):
		return c.Faction == us and c.Status == Enums.Status.AwaitingOrders and c.Attached is Planet \
			and not c.IsCaptured() and not c.IsOffMap() and not MissionManager.IsOnMissionTeam(c))
	if free.is_empty():
		return
	for agent in free:
		if budget.Missions <= 0:
			return
		var team: Array = [agent]
		var can := MissionManager.PerformableBy(team)
		if can.is_empty():
			continue
		var targets: Array = view.Neutral + view.TheirsWeak + view.TheirsStrong + view.Unexplored
		for type in Preferred(can):
			var from: Planet = agent.Attached
			var target: Planet = Lq.first_or_null(targets, func(t):
				return MissionManager.CanTarget(type, us, t).ok \
					and not Lq.any(MissionManager.Active(), func(m): return m.Target == t and m.Faction == us))
			if target == null:
				continue
			if MissionManager.Launch(type, team, from, target) == null:
				continue
			print("[AI] %s: %s sent on %s to %s." % [us.Id, agent.Name, JsonUtil.enum_name(Enums.MissionType, type), target.Name])
			budget.Missions -= 1
			break


## ⚠ THE ORDER IS OURS (argued, not picked).
static func Preferred(available: Array) -> Array:
	var order := [
		Enums.MissionType.Diplomacy, Enums.MissionType.InciteUprising, Enums.MissionType.Espionage,
		Enums.MissionType.Reconnaissance, Enums.MissionType.Recruitment, Enums.MissionType.SubdueUprising,
	]
	return Lq.where(order, func(t): return available.has(t))
