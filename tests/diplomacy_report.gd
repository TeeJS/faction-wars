extends SceneTree
## The Diplomacy Mission Report in the original's words (TEXTSTRA RCDATA
## 28884-28891; TeeJ, 2026-09-27, with the original's report beside ours):
##   - a failed attempt: "Diplomacy Mission Report" / "The diplomacy mission to
##     <system> had no effect on our popular support on that system." ... "Do
##     you wish the mission to continue?";
##   - a success: "... has increased popular support on that system."
##
##   .\tools\run-gd.ps1 tests/diplomacy_report.gd

var _fails := 0
var _checks := 0


class AlwaysOnePrng extends Prng:
	func NextRange(min_value: int, _max_value: int) -> int: return min_value
	func NextMax(_max_value: int) -> int: return 0


class AlwaysMaxPrng extends Prng:
	func NextRange(_min_value: int, max_value: int) -> int: return max_value - 1
	func NextMax(max_value: int) -> int: return max_value - 1


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[diplomacy_report] ok   %s" % what)
	else:
		_fails += 1
		print("[diplomacy_report] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return FactionRegistry.OrderOf(p.ControllingFaction) < 0 and p.IsInhabited)
	var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Status != Enums.Status.Dead)
	_check(target != null and agent != null, "a neutral world and an agent")
	if target == null or agent == null:
		_finish()
		return
	target.SetSupportFor(us, 10)

	for case in [["fail", AlwaysMaxPrng.new(), "had no effect on our popular support on that system."],
			["succeed", AlwaysOnePrng.new(), "has increased popular support on that system."]]:
		var m := Mission.new()
		m.Type = Enums.MissionType.Diplomacy
		m.Faction = us
		m.Target = target
		m.HomeBase = target
		m.Team.append(agent)
		m.Attempts = 1
		m.DaysToTarget = 0
		var before := EventBus.MessageLog.size()
		MissionManager.Resolve(m, case[1], 1)
		var msg: GameMessage = EventBus.MessageLog[EventBus.MessageLog.size() - 1] if EventBus.MessageLog.size() > before else null
		_check(msg != null and msg.Title == "Diplomacy Mission Report", "%s: titled 'Diplomacy Mission Report' (%s)" % [case[0], msg.Title if msg != null else "none"])
		_check(msg != null and msg.Body.begins_with("The diplomacy mission to %s %s" % [target.Name, case[2]]),
			"%s: 'The diplomacy mission to %s %s'" % [case[0], target.Name, case[2]])
		_check(msg != null and msg.Body.ends_with("Do you wish the mission to continue?") and msg.PendingMission == m,
			"%s: asks whether to continue" % case[0])
		if msg != null:
			print("[diplomacy_report]      %s" % msg.Body.replace("\n", " / "))
	_finish()


func _finish() -> void:
	print("[diplomacy_report] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
