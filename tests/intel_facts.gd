extends SceneTree
## FOG-LEGAL FACTS (docs/ai-framework - the intelligence layer the built-in AI reads).
##
##   1. IntelManager.Facts equals the live world at the moment of capture,
##   2. stays FROZEN afterwards however the world changes (the fairness rule),
##   3. carries nothing for a world never seen, and nothing about people after a
##      Reconnaissance (the manual's own exclusion),
##   4. is LIVE for a world we hold.
##
## (jev-brain's copy also checked the AssaultManager/BombardmentManager estimators
## from the same phase-1 commit; those are the Officer fleet brain's, not part of the
## built-in AI's fog reads, and were left on that branch.)
##
##   Godot_console.exe --headless --path . -s tests/intel_facts.gd

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

	_facts(alliance, empire)

	print("[intel_facts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


# ---------------------------------------------------------------------------
# 1-4. FACTS
# ---------------------------------------------------------------------------

func _facts(alliance: Faction, empire: Faction) -> void:
	var opening := StrategicTickManager.Today
	var them: Planet = _first(func(p): return p.ControllingFaction == empire and p.Troopers().size() > 0 and p.ExploredBy(alliance))
	_check(them != null, "a charted Empire world with a garrison exists")
	if them == null:
		return

	# 3a. never seen: nothing.
	var dark: Planet = _first(func(p): return not p.ExploredBy(alliance) and p.ControllingFaction != alliance)
	_check(dark != null, "an uncharted world exists")
	if dark != null:
		var blank := IntelManager.Facts(alliance, dark)
		_check(blank.troops_day == -1 and blank.status_day == -1 and blank.defences_day == -1 and blank.people_day == -1 \
			and blank.ships_day == -1 and blank.production_day == -1 and blank.fighters_day == -1, "an uncharted world has no dated group")
		_check(blank.regiments.is_empty() and blank.owner_id == "" and not blank.ours and not blank.explored, "an uncharted world carries no data")

	# 3b. The opening snapshot is a Reconnaissance (day_zero_generator): it dates
	# troops, defences and status, and says nothing about who is standing there.
	var first_look := IntelManager.Facts(alliance, them)
	_check(first_look.troops_day == opening and first_look.defences_day == opening and first_look.status_day == opening, "the opening Reconnaissance dates troops, defences and status")
	_check(first_look.people_day == -1 and first_look.people.is_empty(), "and says nothing about people")

	# Put a named person there, so Characters has something to freeze.
	var officer: Character = Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Faction == empire and c.Status != Enums.Status.Dead and not c.IsOffMap())
	if officer != null:
		MilitaryCatalog.Relocate(officer, them)

	# 1. equal to the live world at capture.
	var today := opening + 3
	StrategicTickManager.Today = today
	IntelManager.Capture(alliance, them, today, IntelManager.EspionageCategories)
	var f := IntelManager.Facts(alliance, them)
	var live_regiments := them.Troopers().size()
	var live_shields := them.CountOf(Enums.FacilityType.PlanetaryShield)
	var live_support := them.SupportFor(alliance)
	var live_fleets := them.OrbitingFleets.size()
	var live_production := Lq.where(them.Facilities, func(x): return not IntelManager.IsDefensive(x)).size()
	_check(f.troops_day == today and f.status_day == today and f.people_day == today, "every captured group is dated the capture day")
	_check(f.owner_id == empire.Id, "owner is the Empire")
	_check(f.regiments.size() == live_regiments, "regiments %d == live %d" % [f.regiments.size(), live_regiments])
	_check(f.regiments.size() > 0 and int(f.regiments[0]["defense"]) == them.Troopers()[0].Defense, "a regiment's defence is its real defence")
	_check(f.shields == live_shields, "shields %d == live %d" % [f.shields, live_shields])
	_check(f.support_for(alliance) == live_support, "support %d == live %d" % [f.support_for(alliance), live_support])
	_check(f.fleets.size() == live_fleets, "fleets %d == live %d" % [f.fleets.size(), live_fleets])
	_check(f.garrison_requirement == them.GarrisonRequirement(), "garrison requirement matches")
	var counted := 0
	for k in f.facility_counts:
		counted += int(f.facility_counts[k])
	_check(counted == live_production, "production facilities %d == live %d" % [counted, live_production])
	if officer != null:
		_check(f.names_present().has(officer.Name), "%s is named on the world" % officer.Name)
	_check(not f.ours and f.explored, "an enemy world: not ours, but charted")

	# facilities_of: the sighting's per-kind count, the gate the sabotage policy reads.
	_check(f.facilities_of(Enums.FacilityType.PlanetaryShield) == live_shields, "facilities_of(shield) == the sighting's shield count")

	# 2. frozen afterwards.
	StrategicTickManager.Today = today + 25
	them.Garrison.erase(them.Troopers()[0])
	them.AddFacility(Enums.FacilityType.PlanetaryShield, 1)
	them.ShiftSupport(alliance, 15)
	if officer != null:
		var elsewhere: Planet = _first(func(p): return p.ControllingFaction == empire and p != them)
		MilitaryCatalog.Relocate(officer, elsewhere)
	var later := IntelManager.Facts(alliance, them)
	_check(later.troops_day == today, "the sighting keeps its date (%d, today is %d)" % [later.troops_day, StrategicTickManager.Today])
	_check(later.age(later.troops_day, StrategicTickManager.Today) == 25, "and reports its age")
	_check(later.regiments.size() == live_regiments, "a regiment left; the snapshot still says %d" % live_regiments)
	_check(later.shields == live_shields, "a shield went up; the snapshot still says %d" % live_shields)
	_check(later.support_for(alliance) == live_support, "support moved; the snapshot did not")
	if officer != null:
		_check(later.names_present().has(officer.Name), "%s left; the snapshot still names them" % officer.Name)
	_check(them.Troopers().size() == live_regiments - 1 and them.CountOf(Enums.FacilityType.PlanetaryShield) == live_shields + 1, "(the live world really did change)")

	# A later Reconnaissance refreshes what it covers and leaves the people as they were seen.
	IntelManager.Capture(alliance, them, StrategicTickManager.Today, IntelManager.ReconnaissanceCategories)
	var rescouted := IntelManager.Facts(alliance, them)
	_check(rescouted.troops_day == StrategicTickManager.Today and rescouted.regiments.size() == live_regiments - 1, "a fresh Reconnaissance updates the troops")
	_check(rescouted.people_day == today, "and the people are still as of day %d" % today)

	# 4. our own world is live.
	var ours: Planet = _first(func(p): return p.ControllingFaction == alliance and p.Troopers().size() > 0)
	_check(ours != null, "an Alliance world with a garrison exists")
	if ours != null:
		var o := IntelManager.Facts(alliance, ours)
		_check(o.ours and o.troops_day == StrategicTickManager.Today, "our own world is dated today")
		var n := o.regiments.size()
		IntelManager.Capture(empire, ours, StrategicTickManager.Today, IntelManager.ReconnaissanceCategories)
		ours.Garrison.erase(ours.Troopers()[0])
		_check(IntelManager.Facts(alliance, ours).regiments.size() == n - 1, "and follows the world when it changes")
		# ...while the ENEMY's sighting of the same world stays where it was.
		_check(IntelManager.Facts(empire, ours).regiments.size() == n, "the Empire's sighting of it does not")
	StrategicTickManager.Today = opening


# ---------------------------------------------------------------------------

func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null
