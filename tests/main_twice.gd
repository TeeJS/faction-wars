extends SceneTree
## Issue #301: a second Main.tscn in one process - Load Game from the in-game
## Game Options, or a test that loads twice - must find nothing of the first
## game on the static EventBus. The galaxy map never took its OnDayAdvanced
## callback off the bus, so every day of the second game called the freed map:
## "SCRIPT ERROR: Attempt to call function 'null::OnDayAdvanced (Callable)' on
## a null instance."
##   - the first game freed, every callback left on the bus is to a live object;
##   - the second game up, every list holds as many callbacks as the first
##     game's did (nothing left behind, nothing lost);
##   - a day of the second game logs no call on a null instance.
##
##   .\tools\run-gd.ps1 tests/main_twice.gd


var _fails := 0
var _checks := 0


## Every error the engine logs, script errors included (Godot 4.5+ Logger).
## Called from any thread, hence the lock.
class Catch extends Logger:
	var _lock := Mutex.new()
	var _seen: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		_seen.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])
		_lock.unlock()

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		_lock.lock()
		_seen.append(message)
		_lock.unlock()

	func NullCalls() -> Array:
		_lock.lock()
		var out: Array = _seen.filter(func(s: String) -> bool: return s.contains("null instance"))
		_lock.unlock()
		return out


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[main_twice] ok   %s" % what)
	else:
		_fails += 1
		print("[main_twice] FAIL %s" % what)


## Every callback list on the bus, by name.
func _lists() -> Dictionary:
	return {
		"OnGameNotification": EventBus.OnGameNotification,
		"OnDayAdvanced": EventBus.OnDayAdvanced,
		"OnStateChanged": EventBus.OnStateChanged,
		"OnMessageReceived": EventBus.OnMessageReceived,
		"OnMovieCue": EventBus.OnMovieCue,
	}


## Each list's callback count.
func _counts() -> Dictionary:
	var out := {}
	var lists := _lists()
	for n: String in lists:
		out[n] = (lists[n] as Array).size()
	return out


## The callbacks whose object is gone, as "List: callable".
func _dead() -> Array:
	var out: Array = []
	var lists := _lists()
	for n: String in lists:
		for cb: Callable in lists[n]:
			if not cb.is_valid():
				out.append("%s: %s" % [n, cb])
	return out


## A new game, briefing skipped so nothing holds the clock.
func _start() -> Node:
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var briefing: Node = (main.get_node("UIManager") as UIManager).Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame
	return main


func _init() -> void:
	var catch := Catch.new()
	OS.add_logger(catch)
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()

	var first: Node = await _start()
	var firstCounts := _counts()
	_check(firstCounts["OnDayAdvanced"] > 0, "the first game listens for the day (%s)" % str(firstCounts))
	first.queue_free()
	for _i in 3:
		await process_frame
	var left: Array = _dead()
	_check(left.is_empty(), "the first game freed: nothing of it left on the bus %s" % str(left))

	var second: Node = await _start()
	var secondCounts := _counts()
	_check(secondCounts == firstCounts, "the second game: as many callbacks as the first (%s, first %s)" % [str(secondCounts), str(firstCounts)])
	left = _dead()
	_check(left.is_empty(), "the second game: every callback is to a live object %s" % str(left))

	var day: int = StrategicTickManager.Today
	(second as GameManager)._strategicEngine.AdvanceDay()
	await process_frame
	_check(StrategicTickManager.Today == day + 1, "a day of the second game passed (%d -> %d)" % [day, StrategicTickManager.Today])
	var nulls: Array = catch.NullCalls()
	_check(nulls.is_empty(), "no call on a null instance %s" % str(nulls))

	second.queue_free()
	for _i in 2:
		await process_frame
	OS.remove_logger(catch)
	print("[main_twice] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
