class_name FleetBattleManager
extends RefCounted
## backend/FleetBattleManager.cs - WHEN FLEETS MEET, manual p124 and Chapter 4's
## Battle Alert. Simulate Results IS the tactical simulation run headless.


class Casualties:
	var CapitalShipsOperational: Array = []
	var CapitalShipsDestroyed: Array = []
	var SquadronsOperational: Array = []
	var SquadronsDestroyed: Array = []
	var PersonnelSurvivors: Array = []
	var PersonnelCaptured: Array = []
	var PersonnelKilled: Array = []


class BattleReport:
	var Where: Planet
	## CANONICAL SIDES. Ours is the fleet of the faction that comes first in the
	## pack's order, Theirs the other - never "the local human's", because the
	## tactical simulation is order-sensitive and both clients of a head-to-head
	## game must run it the same way round (docs/m0-audit.md section 3). The
	## names are the C#'s; the windows use Mine/Enemy/Lost with a viewer.
	var Ours: Fleet
	var Theirs: Fleet
	var OurStrength: int
	var TheirStrength: int
	var WeLost: bool       # Ours lost
	var TheirsLost: bool   # Theirs lost
	var DrawBothLost: bool

	func Mine(viewer: Faction) -> Fleet:
		return Theirs if (Theirs != null and Theirs.Faction == viewer) else Ours

	func Enemy(viewer: Faction) -> Fleet:
		return Ours if (Theirs != null and Theirs.Faction == viewer) else Theirs

	func Lost(viewer: Faction) -> bool:
		return TheirsLost if (Theirs != null and Theirs.Faction == viewer) else WeLost

	func MyStrength(viewer: Faction) -> int:
		return TheirStrength if (Theirs != null and Theirs.Faction == viewer) else OurStrength

	func EnemyStrength(viewer: Faction) -> int:
		return OurStrength if (Theirs != null and Theirs.Faction == viewer) else TheirStrength

	func MyLosses(viewer: Faction) -> Casualties:
		return TheirLosses if (Theirs != null and Theirs.Faction == viewer) else OurLosses

	func EnemyLosses(viewer: Faction) -> Casualties:
		return OurLosses if (Theirs != null and Theirs.Faction == viewer) else TheirLosses
	var LoserWithdrew: bool
	var HeldByGravityWell: bool
	var Destroyed: Array = []
	var Summary: String = ""
	var OurLosses := Casualties.new()
	var TheirLosses := Casualties.new()


static var _awaiting_orders: Array = []
static var _unreported: Array = []


static func AwaitingOrders() -> Array:
	return _awaiting_orders


static func HasPendingBattle() -> bool:
	return _awaiting_orders.size() > 0


static func Unreported() -> Array:
	return _unreported


static func MarkReported(r: BattleReport) -> void:
	_unreported.erase(r)


static func Reset() -> void:
	_awaiting_orders.clear()
	_unreported.clear()


# --- STRENGTH ---

static func PowerOf(u: Unit, against_fighters: bool) -> int:
	if u == null:
		return 0
	var power := u.Turbolaser + u.LaserRating
	if not against_fighters:
		power += u.IonCannon
	return power


static func StrengthOf(f: Fleet) -> int:
	if f == null:
		return 0
	var total := 0
	for ship in f.Ships:
		total += PowerOf(ship, false)
		for carried in ship.Hangar:
			if carried.Type == Enums.UnitType.Fighter:
				total += PowerOf(carried, false)
	return total


## "Gravity wells prevent opposing ships from withdrawing" (p117, p140; 0x5D0F50).
static func EnemyHoldsThemHere(enemy: Fleet) -> bool:
	return enemy != null and Lq.any(enemy.Ships, func(s): return s.GravityWell > 0)


## THE FULL WITHDRAWAL TEST (manual p151): gravity well, a hyperdrive-capable
## ship, and somewhere friendly or neutral to go.
static func CanWithdraw(fleet: Fleet, enemy: Fleet, from: Planet) -> Result:
	if EnemyHoldsThemHere(enemy):
		return Result.fail("%s is projecting a gravity well. We cannot withdraw." % enemy.Name)
	if not Lq.any(fleet.Ships, func(s): return s.Hyperdrive > 0):
		return Result.fail("No hyperdrive-capable ship remains. We cannot withdraw.")
	if Refuge(fleet, from) == null:
		return Result.fail("There is no friendly or neutral system to withdraw to.")
	return Result.success()


static func Refuge(fleet: Fleet, from: Planet) -> Planet:
	if fleet == null:
		return null
	var candidates := Lq.where(GameState.AllPlanets(), func(p):
		return p != from and (p.ControllingFaction == fleet.Faction or p.ControllingFaction == null or p.ControllingFaction == FactionRegistry.Neutral))
	var sorted := Lq.order_by(candidates, func(p): return from.DeploymentDaysTo(p))
	return sorted[0] if not sorted.is_empty() else null


# --- ENGAGEMENT ---

static func ProcessDay(galaxy: Array, day: int, _rng: Prng) -> void:
	if galaxy == null or HasPendingBattle():
		return
	for s in galaxy:
		for world in s.Planets:
			var present := Lq.where(world.OrbitingFleets, func(f): return f.Faction != null and not f.IsEmpty() and f.Status != Enums.Status.Enroute)
			if present.size() < 2:
				continue
			for a in present:
				var b: Fleet = Lq.first_or_null(present, func(x): return x.Faction != a.Faction)
				if b == null:
					continue
				Engage(world, a, b, day)
				return


static func Engage(where: Planet, a: Fleet, b: Fleet, day: int) -> void:
	# Pack order decides side 0, on every client alike.
	var first_a: bool = FactionRegistry.OrderOf(a.Faction) <= FactionRegistry.OrderOf(b.Faction)
	var report := BattleReport.new()
	report.Where = where
	report.Ours = a if first_a else b
	report.Theirs = b if first_a else a
	report.OurStrength = StrengthOf(report.Ours)
	report.TheirStrength = StrengthOf(report.Theirs)

	# No human in it: resolved on the spot. A human side waits for its answer.
	if not GameSettings.IsHuman(a.Faction) and not GameSettings.IsHuman(b.Faction):
		Simulate(report, day)
		return

	_awaiting_orders.append(report)
	print("[Battle] Alert at %s: %s (%d) vs %s (%d)." % [where.Name, report.Ours.Name, report.OurStrength, report.Theirs.Name, report.TheirStrength])
	EventBus.BroadcastChanged()


# --- THE PLAYER'S THREE CHOICES (manual p141) ---

static func SimulateResults(r: BattleReport, day: int) -> void:
	_awaiting_orders.erase(r)
	Simulate(r, day)
	EventBus.BroadcastChanged()


## "Battle continues ... or until one side withdraws" (manual p152): the side
## that answers Retreat is the one that withdraws, subject to CanWithdraw.
static func Retreat(r: BattleReport, day: int, side: Faction = null) -> Result:
	var viewer: Faction = side if side != null else GameSettings.LocalFaction()
	var mine: Fleet = r.Mine(viewer)
	var enemy: Fleet = r.Enemy(viewer)
	var can := CanWithdraw(mine, enemy, r.Where)
	if not can.ok:
		return can
	_awaiting_orders.erase(r)
	Withdraw(mine, r.Where)
	print("[Battle] %s withdrew from %s." % [mine.Name, r.Where.Name])
	var msg := GameMessage.new("%s has withdrawn" % mine.Name,
		"%s broke off at %s and fell back to the nearest system we hold." % [mine.Name, r.Where.Name],
		Enums.MessageCategory.Missions, day, r.Where)
	msg.Type = Enums.MessageType.TacticalAfterActionReport
	EventBus.Tell(mine.Faction, msg)
	EventBus.BroadcastChanged()
	return Result.success()


static func Conclude(r: BattleReport, sim: TacticalBattle, day: int) -> void:
	_awaiting_orders.erase(r)
	if sim != null and sim.LoserIndex >= 0:
		r.WeLost = sim.LoserIndex == 0
		r.TheirsLost = sim.LoserIndex == 1
		r.DrawBothLost = false
	Simulate(r, day)
	EventBus.BroadcastChanged()


# --- RESOLUTION ---

static func Simulate(r: BattleReport, day: int) -> void:
	var sim := TacticalBattle.new(r.Where, r.Ours, r.Theirs, Prng.Session)
	sim.RunToCompletion()

	var s0: int = sim.Sides[0].Strength
	var s1: int = sim.Sides[1].Strength
	r.OurStrength = s0
	r.TheirStrength = s1

	var ours_loses := sim.LoserIndex == 0 or sim.LoserIndex == -1
	var theirs_loses := sim.LoserIndex == 1 or sim.LoserIndex == -1
	r.WeLost = ours_loses
	r.TheirsLost = theirs_loses
	r.DrawBothLost = sim.LoserIndex == -1

	Tally(sim.Sides[0], r.OurLosses, r.Ours)
	Tally(sim.Sides[1], r.TheirLosses, r.Theirs)

	if theirs_loses:
		ResolveLoser(r, r.Theirs, r.Ours, r)
	if ours_loses:
		ResolveLoser(r, r.Ours, r.Theirs, r)

	if r.DrawBothLost:
		r.Summary = "Both fleets were broken at %s." % r.Where.Name
	elif r.WeLost:
		r.Summary = "%s was beaten at %s." % [r.Ours.Name, r.Where.Name]
	else:
		r.Summary = "%s was beaten at %s." % [r.Theirs.Name, r.Where.Name]

	print("[Battle] %s: %s %d vs %s %d -> %s%s" % [r.Where.Name, r.Ours.Name, s0, r.Theirs.Name, s1, r.Summary, " (gravity well - no withdrawal)" if r.HeldByGravityWell else ""])

	var audiences: Array = Lq.where([r.Ours.Faction, r.Theirs.Faction], func(f: Faction) -> bool: return GameSettings.IsHuman(f))
	if audiences.is_empty():
		return

	_unreported.append(r)
	var extra := ""
	if r.HeldByGravityWell:
		extra = "\n\nA gravity well projector held the losing fleet in place. It could not withdraw."
	elif r.LoserWithdrew:
		extra = "\n\nThe losing fleet withdrew to the nearest system its side holds."
	var msg := GameMessage.new("Conflict at %s" % r.Where.Name,
		r.Summary + "\n\nStrength: %s %d, %s %d." % [r.Ours.Name, s0, r.Theirs.Name, s1] + extra
			+ (("\n\nDestroyed: %s" % Lq.join(r.Destroyed)) if not r.Destroyed.is_empty() else "\n\nNo casualties."),
		Enums.MessageCategory.Missions, day, r.Where)
	msg.Type = Enums.MessageType.TacticalAfterActionReport
	for k in audiences.size():
		EventBus.Tell(audiences[k], msg if k == 0 else msg.Copy())


static func Tally(side: TacticalBattle.TacticalSide, into: Casualties, fleet: Fleet) -> void:
	for u in side.Ships:
		(into.CapitalShipsDestroyed if u.Destroyed() else into.CapitalShipsOperational).append(Describe(u))
	for u in side.Squadrons:
		(into.SquadronsDestroyed if u.Destroyed() else into.SquadronsOperational).append(Describe(u))
	# ⚠ The injured/captured/killed split is NOT reproduced: everyone aboard survives.
	for c in GameState.ActiveRoster:
		if c.Attached == fleet and c.Status != Enums.Status.Dead:
			into.PersonnelSurvivors.append(c.Name if c.Rank == Enums.Rank.None else "%s %s" % [JsonUtil.enum_name(Enums.Rank, c.Rank), c.Name])


static func Describe(u: TacticalBattle.TacticalUnit) -> String:
	if u.Destroyed() or u.Damage == null:
		return u.Name()
	if u.Damage.Hull < u.Damage.MaxHull or u.Damage.IsDamaged():
		return "%s  (hull %d/%d)" % [u.Name(), u.Damage.Hull, u.Damage.MaxHull]
	return u.Name()


static func ResolveLoser(r: BattleReport, loser: Fleet, winner: Fleet, into: BattleReport) -> void:
	if loser == null or loser.IsEmpty():
		return
	if CanWithdraw(loser, winner, r.Where).ok:
		into.LoserWithdrew = true
		Withdraw(loser, r.Where)
		return
	into.HeldByGravityWell = EnemyHoldsThemHere(winner)
	for ship in loser.Ships.duplicate():
		into.Destroyed.append(ship.Name)
		for carried in ship.Hangar.duplicate():
			into.Destroyed.append(carried.Name)
	loser.Ships.clear()
	r.Where.OrbitingFleets.erase(loser)


static func Withdraw(fleet: Fleet, from: Planet) -> void:
	var refuge := Refuge(fleet, from)
	if fleet == null or refuge == null:
		return
	from.OrbitingFleets.erase(fleet)
	refuge.OrbitingFleets.append(fleet)
	fleet.Attached = refuge
	fleet.Destination = null
	fleet.DaysToDestination = 0
	fleet.Status = Enums.Status.AwaitingOrders
	for ship in fleet.Ships:
		ship.Attached = refuge
		ship.Destination = null
		ship.DaysToDestination = 0
		ship.Status = Enums.Status.AwaitingOrders
