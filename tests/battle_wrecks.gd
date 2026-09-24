extends SceneTree
## A ship destroyed in a fleet battle leaves the game (TeeJ, 2026-09-24:
## "destroyed ships are NOT repaired. damaged ones are, but destroyed go
## away!"): it is taken out of its fleet with what it carried, the results
## list its troops as destroyed, repair never sees it again, and a fleet left
## with no ships is disbanded (manual p120). A damaged survivor stays, to be
## repaired.
##
##   .\tools\run-gd.ps1 tests/battle_wrecks.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[battle_wrecks] ok   %s" % what)
	else:
		_fails += 1
		print("[battle_wrecks] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)

	# A fleet of two or more ships, one of them carrying troops.
	var fleet: Fleet = null
	var where: Planet = null
	var carrier: Unit = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet != null or f.Ships.size() < 2:
				continue
			for s in f.Ships:
				if carrier == null and Lq.any(s.Hangar, func(h): return h.Type == Enums.UnitType.Troop):
					carrier = s
			if carrier != null:
				fleet = f
				where = p
			else:
				carrier = null
	_check(fleet != null, "a fleet with a ship carrying troops")
	if fleet == null:
		_finish()
		return
	var troops: Array = Lq.where(carrier.Hangar, func(h): return h.Type == Enums.UnitType.Troop)
	var other: Unit = Lq.first_or_null(fleet.Ships, func(s): return s != carrier)

	var side := TacticalBattle.Build(fleet, 0)
	var sunk: TacticalBattle.TacticalUnit = Lq.first_or_null(side.Ships, func(u): return u.Source == carrier)
	var hit: TacticalBattle.TacticalUnit = Lq.first_or_null(side.All(), func(u): return u.Source == other)
	sunk.Damage.Hull = 0
	if hit != null and hit.Damage.MaxHull > 1:
		hit.Damage.Hull = hit.Damage.MaxHull - 1

	var r := FleetBattleManager.BattleReport.new()
	r.Where = where
	var losses := FleetBattleManager.Casualties.new()
	FleetBattleManager.Tally(side, losses, fleet)
	_check(losses.CapitalShipsDestroyed.has(carrier.Name) or losses.SquadronsDestroyed.has(carrier.Name), "the lost ship is listed destroyed")
	_check(troops.all(func(t): return losses.TroopsDestroyed.has(t.Name)), "the troops it carried are listed destroyed (%d)" % troops.size())
	FleetBattleManager.RemoveWrecks(side, r)
	_check(not fleet.Ships.has(carrier), "the lost ship is out of its fleet")
	_check(r.Destroyed.has(carrier.Name), "and named in the battle's report")
	_check(fleet.Ships.has(other), "the survivor stays")
	_check(other == null or hit == null or other.IsDamaged() or hit.Damage.MaxHull <= 1, "a damaged survivor stays damaged, for repair")

	# Repair never sees the lost ship again.
	RepairManager.ProcessDay(GameState.ActiveGalaxy, StrategicTickManager.Today + 1)
	_check(not _anywhere(carrier), "the lost ship is nowhere in the galaxy")

	# A fleet whose every ship is lost is disbanded.
	var side2 := TacticalBattle.Build(fleet, 0)
	for u in side2.Ships:
		u.Damage.Hull = 0
	for u in side2.Squadrons:
		if u.Damage.MaxAircraft > 0:
			u.Damage.Aircraft = 0
		else:
			u.Damage.Hull = 0
	FleetBattleManager.RemoveWrecks(side2, r)
	_check(fleet.Ships.is_empty() and not where.OrbitingFleets.has(fleet), "a fleet with nothing left is disbanded")
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
	print("[battle_wrecks] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
