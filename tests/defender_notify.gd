extends SceneTree
## Issue #2b: the defending faction is notified when an enemy mission resolves
## against their world. The notice is fog-blind (never names the attacker) and
## sits in the Missions category, where the manual puts "news of enemy missions
## your forces have foiled" (manual p079). AI-only encounters produce no message.
##
## Covered here:
##   AC1 - the _tell_defender helper notifies a HUMAN defender with the right
##         fields (addressed to the defender, Missions category, MissionReport
##         type, fog-blind, linked to the planet for Go To).
##   AC2 - the helper is silent for an AI-controlled defender.
##   AC3 - the SABOTAGE-SUCCESS call site in Resolve() actually fires the helper:
##         an enemy sabotage that destroys a facility on a human world produces a
##         "destroyed" Missions message to the defender.
## The FOIL call site is the identical _tell_defender call two lines above the
## sabotage one in Resolve(); AC1 proves that helper, so it is covered by
## inspection rather than a second (hard to force deterministically) Resolve run.
##
##   Godot_console.exe --headless --path . -s tests/defender_notify.gd

var _fails := 0
var _checks := 0

class AlwaysOnePrng extends Prng:
	func NextRange(min_value: int, max_value: int) -> int: return min_value
	func NextMax(max_value: int) -> int: return 0

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
	_check(alliance != null and empire != null, "both factions exist")

	var ally_planet: Planet = _first(func(p): return p.ControllingFaction == alliance)
	var emp_planet: Planet = _first(func(p): return p.ControllingFaction == empire)
	_check(ally_planet != null and emp_planet != null, "one planet per side")
	if _fails > 0: _finish(); return

	# --- AC1: helper notifies a HUMAN defender, fog-blind, Missions category ---
	var before := EventBus.MessageLog.size()
	MissionManager._tell_defender(ally_planet, 1, "Enemy Mission Foiled", "Our forces foiled an enemy mission.")
	_check(EventBus.MessageLog.size() == before + 1, "AC1: one message added for the human defender")
	var msg: GameMessage = EventBus.MessageLog[EventBus.MessageLog.size() - 1]
	_check(msg.For == alliance, "AC1: addressed to the defending faction")
	_check(msg.Category == Enums.MessageCategory.Missions, "AC1: Missions category")
	_check(msg.Type == Enums.MessageType.MissionReport, "AC1: MissionReport type")
	_check(msg.AssociatedCharacter == null, "AC1: fog-blind - no attacker named")
	_check(msg.AssociatedLocation == ally_planet, "AC1: linked to the planet (Go To)")

	# --- AC2: helper is silent for an AI-controlled defender ---
	var before2 := EventBus.MessageLog.size()
	MissionManager._tell_defender(emp_planet, 1, "Should Not Fire", "AI defender.")
	_check(EventBus.MessageLog.size() == before2, "AC2: no message for an AI defender")

	# --- AC3: sabotage SUCCESS notifies the defender (call site via Resolve) ---
	# Hand-build the mission so the test does not depend on Launch's explored/
	# eligibility validation. Attempts=1 skips the foil and betrayal checks;
	# AlwaysOnePrng makes the success roll (1 <= chance) pass, landing on the
	# sabotage-success branch.
	var saboteur: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead and not c.IsCaptured())
	_check(saboteur != null, "AC3: an Imperial operative exists")
	if saboteur != null:
		ally_planet.AddFacility(Enums.FacilityType.TurbolaserBattery)
		var fac: Facility = ally_planet.Facilities[ally_planet.Facilities.size() - 1]
		var m := Mission.new()
		m.Type = Enums.MissionType.Sabotage
		m.Faction = empire
		m.Target = ally_planet
		m.HomeBase = emp_planet
		m.TargetFacility = fac
		m.Team.append(saboteur)
		m.Attempts = 1
		m.DaysToTarget = 0
		MissionManager.Resolve(m, AlwaysOnePrng.new(), 1)
		_check(not ally_planet.Facilities.has(fac), "AC3: the sabotaged facility was destroyed")
		var found := _find_defender(alliance, "destroyed")
		_check(found != null, "AC3: the defender received a sabotage-success notification")
		if found != null:
			_check(found.Category == Enums.MessageCategory.Missions, "AC3: Missions category")
			_check(found.AssociatedCharacter == null, "AC3: fog-blind - no attacker named")
			_check(found.AssociatedLocation == ally_planet, "AC3: linked to the sabotaged planet")

	_finish()

func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p): return p
	return null

func _first_char(pred: Callable) -> Character:
	for c in GameState.ActiveRoster:
		if pred.call(c): return c
	return null

func _find_defender(faction: Faction, word: String) -> GameMessage:
	for i in range(EventBus.MessageLog.size() - 1, -1, -1):
		var m: GameMessage = EventBus.MessageLog[i]
		if m.Type != Enums.MessageType.MissionReport: continue
		if m.For != faction: continue
		if m.Title.to_lower().contains(word) or m.Body.to_lower().contains(word): return m
	return null

func _finish() -> void:
	print("[defender_notify] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
