extends SceneTree
## THE MANUAL'S CORE EXCEPTION AND THE FOG THAT SURROUNDS IT (manual p069).
##
##   1. IsCore identifies ring-1 systems (by sector membership, not Planet.SectorId,
##      which the new-game path does not populate).
##   2. On a Core world we do NOT hold, OwnerSeen and SupportSeen are LIVE - they
##      track the world without re-scouting. On a Rim world they FREEZE at the last
##      sighting.
##   3. Uprising is NOT part of the exception: it is fogged everywhere but our own.
##   4. Losing a world captures a sighting of it, so the loser sees who took it.
##   5. An uncharted world has no owner-of-record and paints grey.
##
##   Godot_console.exe --headless --path . -s tests/core_live_fog.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var alliance: Faction = GameSettings.PlayerFaction
	var empire: Faction = FactionRegistry.ById("empire")
	var neutral: Faction = FactionRegistry.Neutral

	# 1. IsCore, resolved by sector membership.
	var core_sector: Sector = _first_sector(func(s: Sector) -> bool: return s.GalaxyRing == 1 and s.Planets.size() > 0)
	var rim_sector: Sector = _first_sector(func(s: Sector) -> bool: return s.GalaxyRing > 1 and s.Planets.size() > 0)
	_check(core_sector != null and rim_sector != null, "the galaxy has both a Core (ring 1) and a Rim sector")
	if core_sector != null:
		_check(IntelManager.IsCore(core_sector.Planets[0]), "a ring-1 world is Core")
	if rim_sector != null:
		_check(not IntelManager.IsCore(rim_sector.Planets[0]), "a ring>1 world is not Core")

	# 2a. A Core world we do not hold: owner + support are LIVE.
	var core_enemy: Planet = _first(func(p: Planet) -> bool: return IntelManager.IsCore(p) and p.ControllingFaction != alliance)
	_check(core_enemy != null, "a Core world we don't hold exists")
	if core_enemy != null:
		_check(IntelManager.OwnerSeen(alliance, core_enemy) == core_enemy.ControllingFaction, "Core owner-seen == the live holder")
		# Flip it live, with NO fresh scouting, and watch owner + support follow.
		var was: Faction = core_enemy.ControllingFaction
		core_enemy.ControllingFaction = neutral if was != neutral else empire
		core_enemy.SetSupportFor(alliance, 37)
		_check(IntelManager.OwnerSeen(alliance, core_enemy) == core_enemy.ControllingFaction, "Core owner-seen tracks the live holder with no re-scouting")
		_check(IntelManager.SupportSeen(alliance, core_enemy, alliance) == 37, "Core support-seen is live (37)")

	# 2b. A Rim world we do not hold: owner + support FREEZE at the sighting. (Both
	# sides start mostly in the Core - manual p069 - so a Rim non-ours world is a
	# neutral one this seed; the rule is the same for any holder we don't control.)
	var rim_enemy: Planet = _first(func(p: Planet) -> bool: return not IntelManager.IsCore(p) and p.ControllingFaction != alliance)
	_check(rim_enemy != null, "a Rim world we don't hold exists")
	if rim_enemy != null:
		var held: Faction = rim_enemy.ControllingFaction
		StrategicTickManager.Today = 5
		rim_enemy.SetSupportFor(alliance, 20)
		IntelManager.Capture(alliance, rim_enemy, 5, IntelManager.ReconnaissanceCategories)
		_check(IntelManager.OwnerSeen(alliance, rim_enemy) == held, "Rim owner-seen == the holder at the moment of capture")
		_check(IntelManager.SupportSeen(alliance, rim_enemy, alliance) == 20, "Rim support-seen == 20 at capture")
		# Flip it live, NO re-scouting: the sighting must not move.
		rim_enemy.ControllingFaction = empire if held != empire else neutral
		rim_enemy.SetSupportFor(alliance, 88)
		_check(IntelManager.OwnerSeen(alliance, rim_enemy) == held, "Rim owner-seen stays STALE (the captured holder) after the world flips")
		_check(IntelManager.SupportSeen(alliance, rim_enemy, alliance) == 20, "Rim support-seen stays STALE (20)")

		# 3. Uprising is fogged (NOT a Core-live datum, and stale on the Rim).
		rim_enemy.IsInUprising = true
		_check(not IntelManager.UprisingSeen(alliance, rim_enemy), "an uprising we did not see is not shown")
		IntelManager.Capture(alliance, rim_enemy, 6, IntelManager.ReconnaissanceCategories)
		_check(IntelManager.UprisingSeen(alliance, rim_enemy), "after re-scouting, the uprising IS seen")

	# 3b. Our own world's uprising is live.
	var ours: Planet = _first(func(p: Planet) -> bool: return p.ControllingFaction == alliance)
	if ours != null:
		ours.IsInUprising = true
		_check(IntelManager.UprisingSeen(alliance, ours), "our own world's uprising is live")
		ours.IsInUprising = false

	# 4. Losing a Rim world we hold captures a sighting of it, so we see the new owner.
	var lose: Planet = _first(func(p: Planet) -> bool: return p.ControllingFaction == alliance \
			and not IntelManager.IsCore(p) and not p.HasHeadquarters())
	_check(lose != null, "we hold a plain Rim world to lose")
	if lose != null:
		_check(IntelManager.OwnerSeen(alliance, lose) == alliance, "before the loss it is ours (live)")
		lose.ControllingFaction = empire
		MilitaryCatalog.OnControlChanged(lose, alliance)
		_check(IntelManager.OwnerSeen(alliance, lose) == empire, "a world we just lost is seen as the Empire's (captured at the moment of loss)")

	# 5. An uncharted Rim world has no owner-of-record and paints grey.
	var dark: Planet = _first(func(p: Planet) -> bool: return not p.ExploredBy(alliance) \
			and p.ControllingFaction != alliance and not IntelManager.IsCore(p))
	if dark != null:
		_check(IntelManager.OwnerSeen(alliance, dark) == null, "an uncharted Rim world has no owner-of-record")
		_check(dark.GetFactionColor() == FactionRegistry.Unknown.FactionColor, "and paints grey")

	print("[core_live_fog] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _first_sector(pred: Callable) -> Sector:
	for s in GameState.ActiveGalaxy:
		if pred.call(s):
			return s
	return null
