extends SceneTree
## After a SINGLE-PLAYER load the player's orders must still take effect. The
## Replayer turns CommandBus.Immediate off for the replay; single player has no
## tick that applies CommandBus.Pending, so GameManager must turn it back on or
## every order after a load is logged and never applied.
##
##   Godot_console.exe --headless --path . -s tests/load_orders.gd

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
	SaveManager.Dir = "user://test-load-orders-saves"
	_clean()

	# --- Generate a real save, as tests/load_game.gd does. ---
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-load-orders-gen.jsonl", CommandLog.Header())
	for _i in 3:
		engine.AdvanceDay()
		CommandBus.day_done()
	var saved: String = SaveManager.Save("Orders")
	_check(not saved.is_empty(), "Save writes the current game")
	CommandLog.Close()

	# --- Load it through the GameManager load path. ---
	GameSettings.PendingLoadPath = SaveManager.GamePath(saved)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame

	# --- One real order through the bus: the droid's production automation. ---
	var us: Faction = GameSettings.PlayerFaction
	_check(CommandBus.Session == null, "a single-player load has no lockstep session")
	_check(not AgentDroid.ManagingProduction(us), "production automation starts off")
	var r: Result = CommandBus.issue("droid", {"manage": "production", "on": true})
	_check(r.ok, "the order is accepted")
	_check(AgentDroid.ManagingProduction(us), "the order took effect on the game state")
	_check(CommandBus.Pending.is_empty(), "nothing is left queued in CommandBus.Pending (%d day(s))" % CommandBus.Pending.size())
	_check(CommandBus.Immediate, "CommandBus.Immediate is true after a single-player load")

	_clean()
	_finish()


func _clean() -> void:
	_remove(SaveManager.Dir)


func _finish() -> void:
	print("[load_orders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
