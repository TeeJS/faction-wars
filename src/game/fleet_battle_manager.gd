class_name FleetBattleManager
extends RefCounted
## backend/FleetBattleManager.cs - WHEN FLEETS MEET, manual p124 and Chapter 4's
## Battle Alert. Simulate Results IS the tactical simulation run headless.


class Casualties:
	var CapitalShipsOperational: Array = []
	var CapitalShipsDestroyed: Array = []
	var SquadronsOperational: Array = []
	var SquadronsDestroyed: Array = []
	## The troops aboard (they do not fight in space; lost with a fleet that is
	## completely destroyed).
	var TroopsOperational: Array = []
	var TroopsDestroyed: Array = []
	var PersonnelSurvivors: Array = []
	var PersonnelCaptured: Array = []
	var PersonnelKilled: Array = []
	## An assault's two facility tabs (manual p123: "The other tabs summarize
	## damage for capital ships, fighters, manufacturing and defensive
	## facilities, and personnel"). A battle leaves them empty.
	var ManufacturingOperational: Array = []
	var ManufacturingDestroyed: Array = []
	var DefenseOperational: Array = []
	var DefenseDestroyed: Array = []
	## Who each entry is, for the results' pictures: per list's name, in the
	## same order, {kind, id, damaged} (manual p153 Fig. 4.18: "burn marks
	## indicate they are damaged").
	var Who: Dictionary = {}

	func add(list: String, text: String, kind: String, id: String, damaged: bool) -> void:
		(get(list) as Array).append(text)
		if not Who.has(list):
			Who[list] = []
		Who[list].append({"kind": kind, "id": id, "damaged": damaged})

	## One of the survivors killed after all (their fleet wiped out): moved to
	## Killed, with who they are.
	func Kill(id: String) -> void:
		var who: Array = Who.get("PersonnelSurvivors", [])
		for i in who.size():
			if str(who[i].get("id", "")) == id:
				var text: String = PersonnelSurvivors[i]
				PersonnelSurvivors.remove_at(i)
				var w: Dictionary = who[i]
				who.remove_at(i)
				add("PersonnelKilled", text, str(w.get("kind", "characters")), id, false)
				return

	## A fleet completely destroyed: whatever was still operational is lost too.
	func LoseAll() -> void:
		for pair in [["CapitalShipsOperational", "CapitalShipsDestroyed"], ["SquadronsOperational", "SquadronsDestroyed"],
				["TroopsOperational", "TroopsDestroyed"]]:
			(get(pair[1]) as Array).append_array(get(pair[0]))
			(get(pair[0]) as Array).clear()
			if Who.has(pair[0]):
				if not Who.has(pair[1]):
					Who[pair[1]] = []
				Who[pair[1]].append_array(Who[pair[0]])
				Who.erase(pair[0])


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
	## Which fleet moved in - the later arrival (null: neither, or both the
	## same day): what the alert's sentence turns on (manual p021 Fig. 2.1,
	## p141 Fig. 4.1). A fleet arriving at its own side's world, the other
	## already in orbit there, is breaking that fleet's blockade.
	var Arriving: Fleet
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


## The results windows still to pop up: battles, and the assaults a human
## ordered (AssaultManager.Resolve) - "Any time a fleet attempts to take over a
## system by planetary assault, the Assault Summary window comes up" (manual
## p123). UIManager shows them one at a time.
static func Unreported() -> Array:
	return _unreported


static func AddUnreported(r: RefCounted) -> void:
	_unreported.append(r)


static func MarkReported(r: RefCounted) -> void:
	_unreported.erase(r)


static func Reset() -> void:
	_awaiting_orders.clear()
	_unreported.clear()


# --- STRENGTH ---

static func PowerOf(u: Unit, against_fighters: bool) -> int:
	if u == null:
		return 0
	# The strategic mirror of TacticalBattle.PowerOf: everything the unit
	# throws, less the weapons the pack marks no_fighter_effect when the target
	# is a fighter. Summed over all arcs, which is what the table's old
	# "Turbolaser"/"IonCannon"/"LaserRating" columns were.
	var power := 0
	for w in MilitaryCatalog.WeaponOrder():
		var fitted: PackDefs.UnitWeaponDef = u.Weapon(w.Id)
		if fitted == null:
			continue
		if against_fighters and w.HasRole("no_fighter_effect"):
			continue
		power += fitted.total()
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
		return Result.fail("No ship able to leave the system remains. We cannot withdraw.")
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
	if a.ArrivedDay != b.ArrivedDay:
		report.Arriving = a if a.ArrivedDay > b.ArrivedDay else b

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

	Rehome(sim.Sides[0])
	Rehome(sim.Sides[1])
	Tally(sim.Sides[0], r.OurLosses, r.Ours)
	Tally(sim.Sides[1], r.TheirLosses, r.Theirs)
	RemoveWrecks(sim.Sides[0], r)
	RemoveWrecks(sim.Sides[1], r)

	if theirs_loses:
		ResolveLoser(r, r.Theirs, r.Ours, r)
	if ours_loses:
		ResolveLoser(r, r.Ours, r.Theirs, r)
	LoseCrews(r)

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
	# A Conflict message titled as its results window is ("Battle at |",
	# TEXTSTRA.DLL 0xE758), which opening it brings up (TeeJ, 2026-09-26: a
	# conflict message "opens the actual assault/battle screen"). INFERRED from
	# the original's assault message, "Assault on <system>" under Conflict
	# Messages on TeeJ's screenshot; no battle message has been seen.
	var msg := GameMessage.new("Battle at %s" % r.Where.Name,
		r.Summary + "\n\nStrength: %s %d, %s %d." % [r.Ours.Name, s0, r.Theirs.Name, s1] + extra
			+ (("\n\nDestroyed: %s" % Lq.join(r.Destroyed)) if not r.Destroyed.is_empty() else "\n\nNo casualties."),
		Enums.MessageCategory.Conflict, day, r.Where)
	msg.Type = Enums.MessageType.TacticalAfterActionReport
	msg.Report = r
	for k in audiences.size():
		EventBus.Tell(audiences[k], msg if k == 0 else msg.Copy())


static func Tally(side: TacticalBattle.TacticalSide, into: Casualties, fleet: Fleet) -> void:
	var sunk: Array = []   # the ships lost, and so what they carried (RemoveWrecks)
	for u in side.Ships:
		if u.Destroyed() and u.Source != null:
			sunk.append(u.Source)
		into.add("CapitalShipsDestroyed" if u.Destroyed() else "CapitalShipsOperational", Describe(u),
			"units", u.Source.PackId if u.Source != null else "", Damaged(u))
	for u in side.Squadrons:
		var lost: bool = u.Destroyed() or (u.Carrier != null and sunk.has(u.Carrier.Source))
		into.add("SquadronsDestroyed" if lost else "SquadronsOperational", Describe(u),
			"units", u.Source.PackId if u.Source != null else "", Damaged(u) and not lost)
	if fleet != null:
		for ship in fleet.Ships:
			for carried in ship.Hangar:
				if carried.Type == Enums.UnitType.Troop:
					into.add("TroopsDestroyed" if sunk.has(ship) else "TroopsOperational", carried.Name, "units", carried.PackId, false)
	# Everyone aboard survives the fight itself; a fleet wiped out takes them
	# with it (LoseCrews). The injured and captured splits are NOT reproduced.
	for c in GameState.ActiveRoster:
		if c.Attached == fleet and c.Status != Enums.Status.Dead:
			into.add("PersonnelSurvivors", c.Name if c.Rank == Enums.Rank.None else "%s %s" % [JsonUtil.enum_name(Enums.Rank, c.Rank), c.Name],
				"characters", c.PackId, false)


## FIGHTERS OUTLIVE THEIR CARRIER (TeeJ, 2026-09-24: "move to another ship"):
## a squadron still flying whose carrier was lost berths on another ship of
## the fleet with room for it (OrderManager.HasRoomFor, the first in the
## fleet's order). With none, it is lost with its carrier (RemoveWrecks).
## Before the tally, so the results list it operational.
static func Rehome(side: TacticalBattle.TacticalSide) -> void:
	for sq in side.Squadrons:
		if sq.Destroyed() or sq.Source == null or sq.Carrier == null or not sq.Carrier.Destroyed():
			continue
		var berth: TacticalBattle.TacticalUnit = Lq.first_or_null(side.Ships, func(t: TacticalBattle.TacticalUnit) -> bool:
			return not t.Destroyed() and t.Source != null and OrderManager.HasRoomFor(t.Source, Enums.UnitType.Fighter))
		if berth == null:
			continue
		if sq.Carrier.Source != null:
			sq.Carrier.Source.Hangar.erase(sq.Source)
		berth.Source.Hangar.append(sq.Source)
		sq.Carrier = berth


## THE CREW OF A FLEET WIPED OUT (TeeJ, 2026-09-24: "die, but only if every
## ship is destroyed"): the characters aboard a fleet with no ship left are
## killed (MissionManager.Kill) and the results list them killed. A fleet with
## a ship still flying keeps them all.
static func LoseCrews(r: BattleReport) -> void:
	for pair in [[r.Ours, r.OurLosses], [r.Theirs, r.TheirLosses]]:
		var f: Fleet = pair[0]
		if f == null or not f.Ships.is_empty():
			continue
		var losses: Casualties = pair[1]
		for c in GameState.ActiveRoster:
			if c.Attached == f and c.Status != Enums.Status.Dead:
				losses.Kill(c.PackId)
				r.Destroyed.append(c.Name)
				MissionManager.Kill(c)


## THE LOST ARE GONE (TeeJ, 2026-09-24: "destroyed ships are NOT repaired.
## damaged ones are, but destroyed go away!"). A ship or squadron destroyed in
## the battle leaves the game - it was kept, at no hull, and RepairManager
## mended it and sent it back to be destroyed again ("I feel like I've
## destroyed this same medium transport 4 times"). A ship goes with what it
## carried, as Planet.DestroyUnit has always taken it (bombardment): the
## results' Trooper Regiments column lists troops "Destroyed", and troops do
## not fight in space. A fleet left empty is disbanded (p120). Fighters that
## outlive their carrier have moved to another ship with room first (Rehome);
## any with nowhere to go are lost with it.
static func RemoveWrecks(side: TacticalBattle.TacticalSide, r: BattleReport) -> void:
	for u in side.All():
		if not u.Destroyed() or u.Source == null:
			continue
		var carried: Array = u.Source.Hangar.duplicate() if u.Source.Hangar != null else []
		if r.Where.DestroyUnit(u.Source):
			r.Destroyed.append(u.Source.Name)
			for c in carried:
				r.Destroyed.append(c.Name)


## Still flying, but hit.
static func Damaged(u: TacticalBattle.TacticalUnit) -> bool:
	return not u.Destroyed() and u.Damage != null and (u.Damage.Hull < u.Damage.MaxHull or u.Damage.IsDamaged())


static func Describe(u: TacticalBattle.TacticalUnit) -> String:
	if u.Destroyed() or u.Damage == null:
		return u.Name()
	if u.Damage.Hull < u.Damage.MaxHull or u.Damage.IsDamaged():
		return "%s  (%s %d/%d)" % [u.Name(), Terms.lower("hull"), u.Damage.Hull, u.Damage.MaxHull]
	return u.Name()


static func ResolveLoser(r: BattleReport, loser: Fleet, winner: Fleet, into: BattleReport) -> void:
	if loser == null or loser.IsEmpty():
		return
	if CanWithdraw(loser, winner, r.Where).ok:
		into.LoserWithdrew = true
		Withdraw(loser, r.Where)
		return
	into.HeldByGravityWell = EnemyHoldsThemHere(winner)
	(r.OurLosses if loser == r.Ours else r.TheirLosses).LoseAll()
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
	fleet.ArrivedDay = StrategicTickManager.Today
	for ship in fleet.Ships:
		ship.Attached = refuge
		ship.Destination = null
		ship.DaysToDestination = 0
		ship.Status = Enums.Status.AwaitingOrders
