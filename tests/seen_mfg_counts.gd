extends SceneTree
## Another side's or a neutral world's Manufacturing counts (the "n:n" beside
## each production row) are what we know is there (TeeJ, 2026-09-27: a
## neutral world showed 0:0 beside the shipyard its map icon shows):
##   - never seen: 0:0;
##   - sighted with a shipyard and a construction yard: 1:1 and 1:1, the
##     training row 0:0 - the same counts the Sector window's icons read;
##   - a shipyard added after the sighting is not counted until seen again.
##
##   .\tools\run-gd.ps1 tests/seen_mfg_counts.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[seen_mfg_counts] ok   %s" % what)
	else:
		_fails += 1
		print("[seen_mfg_counts] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return FactionRegistry.OrderOf(p.ControllingFaction) < 0 and p.IsInhabited and not IntelManager.IsLive(us, p) \
			and IntelManager.SeenData(us, p, Enums.IntelSection.ProductionFacilities).is_empty())
	_check(world != null, "a neutral world we have never sighted")
	if world == null:
		_finish()
		return
	for i in range(world.Facilities.size() - 1, -1, -1):
		if world.Facilities[i].HasRole("produces_unit") or world.Facilities[i].HasRole("produces_troop") or world.Facilities[i].HasRole("produces_facility"):
			world.Facilities.remove_at(i)
	_check(EconomyWindow.SeenPair(us, world, "produces_unit") == "0:0", "never seen: 0:0 (%s)" % EconomyWindow.SeenPair(us, world, "produces_unit"))

	world.AddFacility("shipyard")
	world.AddFacility("construction_yard")
	IntelManager.Capture(us, world, 1, [Enums.IntelCategory.ProductionFacilities])
	_check(EconomyWindow.SeenPair(us, world, "produces_unit") == "1:1", "the shipyard seen: 1:1 (%s)" % EconomyWindow.SeenPair(us, world, "produces_unit"))
	_check(EconomyWindow.SeenPair(us, world, "produces_facility") == "1:1", "the construction yard seen: 1:1")
	_check(EconomyWindow.SeenPair(us, world, "produces_troop") == "0:0", "no training facility: 0:0")

	world.AddFacility("shipyard")
	_check(EconomyWindow.SeenPair(us, world, "produces_unit") == "1:1", "a shipyard built since is not counted until seen again")
	IntelManager.Capture(us, world, 2, [Enums.IntelCategory.ProductionFacilities])
	_check(EconomyWindow.SeenPair(us, world, "produces_unit") == "2:2", "seen again: 2:2")
	_finish()


func _finish() -> void:
	print("[seen_mfg_counts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
