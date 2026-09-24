extends SceneTree
## What outlives a lost ship (TeeJ, 2026-09-24): a squadron still flying when
## its carrier is destroyed "move[s] to another ship" of its fleet with room -
## or, with none, is lost with the carrier; the characters aboard a fleet "die,
## but only if every ship is destroyed".
##
##   .\tools\run-gd.ps1 tests/battle_survivors.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[battle_survivors] ok   %s" % what)
	else:
		_fails += 1
		print("[battle_survivors] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)

	# A carrier with a squadron aboard, and a second capital ship in its fleet.
	var carrier: Unit = null
	var squad: Unit = null
	var fleet: Fleet = null
	var where: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			for s in f.Ships:
				var sq: Unit = Lq.first_or_null(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
				if carrier == null and sq != null:
					carrier = s
					squad = sq
					fleet = f
					where = p
	_check(carrier != null, "a carrier with a squadron aboard")
	if carrier == null:
		_finish()
		return
	var other: Unit = Lq.first_or_null(fleet.Ships, func(s: Unit) -> bool: return s != carrier and s.Type == Enums.UnitType.CapitalShip)
	if other == null:
		for p in GameState.AllPlanets():
			for f in p.OrbitingFleets:
				if other == null and f != fleet and f.Faction == fleet.Faction:
					other = Lq.first_or_null(f.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
					if other != null:
						f.Ships.erase(other)
						fleet.Ships.append(other)
	_check(other != null, "a second capital ship in its fleet")
	if other == null:
		_finish()
		return

	# 1. Room aboard the other ship: the squadron moves there.
	other.FighterCapacity = Lq.count(other.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter) + 1
	var side := TacticalBattle.Build(fleet, 0)
	(Lq.first_or_null(side.Ships, func(t: TacticalBattle.TacticalUnit) -> bool: return t.Source == carrier) as TacticalBattle.TacticalUnit).Damage.Hull = 0
	FleetBattleManager.Rehome(side)
	var losses := FleetBattleManager.Casualties.new()
	FleetBattleManager.Tally(side, losses, fleet)
	var r := FleetBattleManager.BattleReport.new()
	r.Where = where
	FleetBattleManager.RemoveWrecks(side, r)
	_check(not fleet.Ships.has(carrier), "the carrier is lost")
	_check(other.Hangar.has(squad), "its squadron moved to %s, which had room" % other.Name)
	# Every squadron still in the fleet is listed operational; the rest (no
	# room left for them) destroyed.
	var flying := 0
	for s in fleet.Ships:
		flying += Lq.count([s] + s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
	_check(losses.SquadronsOperational.size() == flying, "the results list the %d squadrons still flying operational" % flying)

	# 2. No room: lost with its carrier.
	var carrier2: Unit = other
	var squad2: Unit = squad
	var third: Unit = Lq.first_or_null(fleet.Ships, func(s: Unit) -> bool: return s != carrier2 and s.Type == Enums.UnitType.CapitalShip)
	if third != null:
		third.FighterCapacity = Lq.count(third.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
	var side2 := TacticalBattle.Build(fleet, 0)
	(Lq.first_or_null(side2.Ships, func(t: TacticalBattle.TacticalUnit) -> bool: return t.Source == carrier2) as TacticalBattle.TacticalUnit).Damage.Hull = 0
	FleetBattleManager.Rehome(side2)
	var losses2 := FleetBattleManager.Casualties.new()
	FleetBattleManager.Tally(side2, losses2, fleet)
	FleetBattleManager.RemoveWrecks(side2, r)
	_check(not _anywhere(squad2) and losses2.SquadronsDestroyed.size() > 0, "with no room aboard any other ship, it is lost with its carrier")

	# 3. The crew of a fleet: alive while a ship flies, dead when none does.
	var c: Character = Lq.first_or_null(GameState.ActiveRoster, func(x: Character) -> bool:
		return x.Faction == fleet.Faction and x.Status != Enums.Status.Dead and not x.IsOffMap())
	c.Attached = fleet
	c.Status = Enums.Status.AwaitingOrders
	var r2 := FleetBattleManager.BattleReport.new()
	r2.Where = where
	r2.Ours = fleet
	r2.Theirs = null
	if not fleet.Ships.is_empty():
		FleetBattleManager.LoseCrews(r2)
		_check(c.Status != Enums.Status.Dead, "aboard a fleet with a ship still flying, %s lives" % c.Name)
	var side3 := TacticalBattle.Build(fleet, 0)
	for t in side3.All():
		if t.Damage.MaxAircraft > 0:
			t.Damage.Aircraft = 0
		else:
			t.Damage.Hull = 0
	FleetBattleManager.Tally(side3, r2.OurLosses, fleet)
	FleetBattleManager.RemoveWrecks(side3, r2)
	FleetBattleManager.LoseCrews(r2)
	_check(fleet.Ships.is_empty() and c.Status == Enums.Status.Dead, "every ship destroyed: %s dies" % c.Name)
	_check(r2.OurLosses.PersonnelKilled.size() > 0 and not r2.OurLosses.PersonnelSurvivors.has(c.Name), "and the results list them killed")
	_finish()


func _anywhere(u: Unit) -> bool:
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Ships.has(u):
				return true
			for s in f.Ships:
				if s.Hangar.has(u):
					return true
	return false


func _finish() -> void:
	print("[battle_survivors] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
