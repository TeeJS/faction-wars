extends SceneTree
## The Diplomacy Mission Report in the original's words (TEXTSTRA RCDATA
## 28880-28891; TeeJ, 2026-09-27/28, with the original's reports beside ours):
##   - a failed attempt: "Diplomacy Mission Report" / "The diplomacy mission to
##     <system> had no effect on our popular support on that system." ... "Do
##     you wish the mission to continue?";
##   - a success: "... has increased popular support on that system.";
##   - then which side the population supports: a side at or over entry 207 (60),
##     else "does not strongly support either side" - both sides, both edges;
##   - a major character in the first person: "<name> Mission Report" / "My
##     diplomacy mission to <system> ..." ("... had no effect on popular support
##     in that system.");
##   - no support figure of our own.
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
	var them: Faction = FactionRegistry.Opponents(us)[0]
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return FactionRegistry.OrderOf(p.ControllingFaction) < 0 and p.IsInhabited)
	var minor: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and not c.IsMajor and c.Status != Enums.Status.Dead)
	var major: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.IsMajor and c.Status != Enums.Status.Dead)
	_check(target != null and minor != null and major != null, "a neutral world, a minor and a major character")
	if target == null or minor == null or major == null:
		_finish()
		return

	# Which side the population supports: 60 and over, per side.
	for case in [[60, "The population supports the %s." % us.ShortName],
			[59, "The population does not strongly support either side."],
			[41, "The population does not strongly support either side."],
			[40, "The population supports the %s." % them.ShortName]]:
		target.SetSupportFor(us, case[0])
		_check(MissionManager.PopulationSupport(target) == case[1],
			"%s %d%% / %s %d%%: '%s' (%s)" % [us.ShortName, target.SupportFor(us), them.ShortName, target.SupportFor(them), case[1], MissionManager.PopulationSupport(target)])

	for who in [minor, major]:
		var mine: bool = who == major
		for case in [["fail", AlwaysMaxPrng.new(), "had no effect on popular support in that system." if mine else "had no effect on our popular support on that system."],
				["succeed", AlwaysOnePrng.new(), "has increased popular support on that system."]]:
			target.SetSupportFor(us, 10)
			var m := Mission.new()
			m.Type = Enums.MissionType.Diplomacy
			m.Faction = us
			m.Target = target
			m.HomeBase = target
			m.Team.append(who)
			m.Attempts = 1
			m.DaysToTarget = 0
			var before := EventBus.MessageLog.size()
			MissionManager.Resolve(m, case[1], 1)
			var msg: GameMessage = EventBus.MessageLog[EventBus.MessageLog.size() - 1] if EventBus.MessageLog.size() > before else null
			var what := "%s %s" % ["major" if mine else "minor", case[0]]
			var title := "%s Mission Report" % who.Name if mine else "Diplomacy Mission Report"
			_check(msg != null and msg.Title == title, "%s: titled '%s' (%s)" % [what, title, msg.Title if msg != null else "none"])
			var opening := "%s diplomacy mission to %s %s  " % ["My" if mine else "The", target.Name, case[2]]
			_check(msg != null and msg.Body.begins_with(opening), "%s: '%s'" % [what, opening])
			_check(msg != null and msg.Body == opening + MissionManager.PopulationSupport(target) + "\nDo you wish the mission to continue?",
				"%s: then who the population supports, then the question" % what)
			_check(msg != null and msg.PendingMission == m, "%s: asks whether to continue" % what)
			_check(msg != null and not msg.Body.contains("Support for"), "%s: no support figure of our own" % what)
			if msg != null:
				print("[diplomacy_report]      %s / %s" % [msg.Title, msg.Body.replace("\n", " / ")])
	_finish()


func _finish() -> void:
	print("[diplomacy_report] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
