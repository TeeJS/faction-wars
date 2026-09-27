extends SceneTree
## The day counter counts the days passed since the game began (manual p033:
## "a number indicating how many days have passed since the game began";
## TeeJ, 2026-09-27, BACKLOG #52: the original's reads 0 at the start). The
## game counts its first day 1 (day 0 is the setup before it), so every day
## shown goes through StrategicTickManager.Shown:
##   - the first day reads 0, the next 1; never below 0;
##   - the counter at a new game reads 0, and 1 after a day;
##   - a message's date and an arrival read the same way.
##
##   .\tools\run-gd.ps1 tests/day_shown.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[day_shown] ok   %s" % what)
	else:
		_fails += 1
		print("[day_shown] FAIL %s" % what)


func _init() -> void:
	await process_frame
	_check(StrategicTickManager.Shown(1) == 0 and StrategicTickManager.Shown(2) == 1 and StrategicTickManager.Shown(0) == 0,
		"day 1 shows 0, day 2 shows 1, the setup's day 0 shows 0")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame
	var gm: GameManager = main
	_check(StrategicTickManager.Today == 1 and gm._dayLabel.text == "Day: 0", "a new game: the counter reads 0 ('%s')" % gm._dayLabel.text)
	gm._strategicEngine.AdvanceDay()
	gm.UpdateDayDisplay(StrategicTickManager.Today)
	_check(gm._dayLabel.text == "Day: 1", "a day on: 1 ('%s')" % gm._dayLabel.text)
	var m := GameMessage.new("Dated", "", Enums.MessageCategory.Conflict, StrategicTickManager.Today)
	EventBus.BroadcastMessage(m)
	ui.OnMessageIndexClicked("All")
	for _i in 3:
		await process_frame
	var mw: Node = ui._openWindows.get("Communications")
	var dated: String = ""
	if mw != null and mw._original:
		mw._o_show_index()
		for r in mw._oRows.get_children():
			if (r as Control).tooltip_text.ends_with("Dated"):
				dated = (r as Control).tooltip_text
	elif mw != null:
		mw.ShowDetail(m, null)
		dated = (mw._detailSubject as Label).text
	_check(dated == "Day 1: Dated", "a message of that day is dated 1 ('%s')" % dated)
	main.queue_free()
	for _i in 2:
		await process_frame
	print("[day_shown] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
