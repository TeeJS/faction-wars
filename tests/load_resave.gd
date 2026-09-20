extends SceneTree
## A LOADED game keeps its past. GameManager opens a fresh session log after a
## load, and SaveManager.Save copies that file - so without carrying the loaded
## history into it, save -> load -> save writes a slot with no earlier orders and
## no earlier day hashes, and that slot restores to day 1.
##
##   Godot_console.exe --headless --path . -s tests/load_resave.gd

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
	SaveManager.Dir = "user://test-resave-saves"
	_clean()

	# --- A game with one real order in its log. ---
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-resave-gen.jsonl", CommandLog.Header())
	_check(CommandBus.issue("droid", {"manage": "production", "on": true}).ok, "an order before the save")
	for _i in 5:
		engine.AdvanceDay()
		CommandBus.day_done()
	var saved_day: int = StrategicTickManager.Today
	var saved_hash: String = GameSignature.ReplayHash(GameState.ActiveGalaxy)
	_check(SaveManager.Save(0, "First"), "Save(0)")
	# A fresh process holds nothing when it loads - do not let this one's memory
	# stand in for what the load must restore.
	CommandLog.Reset()

	# --- Load it through GameManager, then save again WITHOUT playing on. ---
	GameSettings.PendingLoadPath = SaveManager.SlotPath(0)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var us: Faction = GameSettings.PlayerFaction
	_check(StrategicTickManager.Today == saved_day, "restored to day %d (got %d)" % [saved_day, StrategicTickManager.Today])
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == saved_hash, "restored to the saved state hash")
	_check(AgentDroid.ManagingProduction(us), "the order from before the save was replayed")
	_check(SaveManager.Save(1, "Second"), "Save(1) straight after the load")

	var again: Array = CommandLog.Read(SaveManager.SlotPath(1))
	_check((again[1] as Array).size() == 1, "the re-save kept the earlier order (got %d)" % (again[1] as Array).size())
	_check((again[2] as Dictionary).size() == 5, "the re-save kept the 5 day hashes (got %d)" % (again[2] as Dictionary).size())

	# --- An order after the load carries on the numbering, and is saved too. ---
	_check(CommandBus.issue("droid", {"manage": "garrisons", "on": true}).ok, "an order after the load")
	var last: Command = CommandLog.Entries[CommandLog.Entries.size() - 1]
	_check(last.Seq == 2, "the order after the load is Seq 2, not a reused 1 (got %d)" % last.Seq)
	_check(SaveManager.Save(2, "Third"), "Save(2) after a new order")
	var third: Array = CommandLog.Read(SaveManager.SlotPath(2))
	_check((third[1] as Array).size() == 2, "the third save holds both orders (got %d)" % (third[1] as Array).size())

	# --- And the third save restores to the same day and state, both orders in. ---
	var upto := 1
	for d: Variant in (third[2] as Dictionary).keys():
		upto = maxi(upto, int(d))
	var replayed: StrategicTickManager = Replayer.replay_entries(third[0], third[1], upto)
	_check(replayed != null and StrategicTickManager.Today == saved_day, "the third save restores to day %d (got %d)" % [saved_day, StrategicTickManager.Today])
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == saved_hash, "the third save restores the same state hash")
	_check(AgentDroid.ManagingProduction(us), "the third save restores the order from before the first save")

	print("  INFO the order issued ON the saved day is applied by the replay: %s" % str(AgentDroid.ManagingGarrisons(us)))

	_clean()
	print("[load_resave] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-resave-saves/slots.json"):
		DirAccess.remove_absolute("user://test-resave-saves/slots.json")
