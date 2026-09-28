extends SceneTree
## Personnel who land together are one arrival, in the original's words
## (TEXTSTRA RCDATA 28864-28869; TeeJ, 2026-09-28, from a head-to-head game: a
## team back from one mission "arrive at different times" - ours sent a message
## a person):
##   - two landing at one world on one day: one message, "Personnel Arrive at
##     <system>" / "The following personnel have arrived at <system>." and both
##     names;
##   - one alone: "<name> Arrives at <system>" / "I have arrived at <system>.";
##   - a mission team sent home lands together, one message.
##
##   .\tools\run-gd.ps1 tests/personnel_arrive_together.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[personnel_arrive_together] ok   %s" % what)
	else:
		_fails += 1
		print("[personnel_arrive_together] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var free: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and c.Status == Enums.Status.AwaitingOrders and not c.IsCaptured())
	var dest: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not free.is_empty() and p != free[0].Attached)
	_check(free.size() >= 3 and dest != null, "three of our people and a world to send them to")
	if free.size() < 3 or dest == null:
		_finish()
		return

	# Two together.
	for c in [free[0], free[1]]:
		c.Status = Enums.Status.Enroute
		c.Destination = dest
		c.DaysToDestination = 2
	var before := EventBus.MessageLog.size()
	engine.AdvanceDay()
	engine.AdvanceDay()
	var told: Array = _arrivals(before)
	_check(told.size() == 1, "two landing together: one message (%d)" % told.size())
	if told.size() == 1:
		var m: GameMessage = told[0]
		_check(m.Title == "Personnel Arrive at %s" % dest.Name, "titled '%s'" % m.Title)
		_check(m.Body.begins_with("The following personnel have arrived at %s." % dest.Name) and m.Body.contains(free[0].Name) and m.Body.contains(free[1].Name),
			"the original's words, both named: '%s'" % m.Body.replace("\n", " / "))
		_check(m.For == us, "addressed to our side")

	# One alone.
	var solo: Character = free[2]
	solo.Status = Enums.Status.Enroute
	solo.Destination = dest
	solo.DaysToDestination = 1
	before = EventBus.MessageLog.size()
	engine.AdvanceDay()
	told = _arrivals(before)
	_check(told.size() == 1 and told[0].Title == "%s Arrives at %s" % [solo.Name, dest.Name] and told[0].Body == "I have arrived at %s." % dest.Name,
		"one alone: '%s' / '%s'" % [told[0].Title if told.size() > 0 else "none", told[0].Body if told.size() > 0 else ""])

	# A mission team sent home lands together.
	var team: Array = [free[0], free[1]]
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return FactionRegistry.OrderOf(p.ControllingFaction) < 0 and p.ExploredBy(us) and dest.DeploymentDaysTo(p) > 3)
	var m2: Mission = MissionManager.Launch(Enums.MissionType.Diplomacy, team, dest, target) if target != null else null
	_check(m2 != null, "a Diplomacy team of two sent from %s (%s)" % [dest.Name, MissionManager.LastRefusal])
	if m2 != null:
		for _d in m2.DaysToTarget + 1:
			engine.AdvanceDay()
		MissionManager.Abort(m2)
		var home: int = int(team[0].DaysToDestination)
		before = EventBus.MessageLog.size()
		for _d in home:
			engine.AdvanceDay()
		told = _arrivals(before)
		var landed: bool = team.all(func(c: Character) -> bool: return c.Status == Enums.Status.AwaitingOrders and c.Attached == dest)
		_check(landed and told.size() == 1 and told[0].Title == "Personnel Arrive at %s" % dest.Name,
			"the team, called home, lands on one day with one message (%d messages, landed %s)" % [told.size(), str(landed)])
	_finish()


func _arrivals(since: int) -> Array:
	var out: Array = []
	for i in range(since, EventBus.MessageLog.size()):
		var m: GameMessage = EventBus.MessageLog[i]
		if m.Type == Enums.MessageType.PersonnelArrive and m.For == GameSettings.PlayerFaction:
			out.append(m)
	return out


func _finish() -> void:
	print("[personnel_arrive_together] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
