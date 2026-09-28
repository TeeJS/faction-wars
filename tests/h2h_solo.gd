extends SceneTree
## Issue #301: a HEAD-TO-HEAD SAVE LOADED IN SINGLE PLAYER is played against the
## AI (TeeJ: "if you open a saved multi-player game in single player mode you
## should be able to play it against the ai"). Loads slot 3 of one computer's
## saves the way the Load Game screens do, and checks: the saved day and state,
## this computer's side is the only human one, the AI plays the other; then
## plays three days, saves that as a single-player game, and loads it again -
## the same day and state, the AI still on the other side.
##
##   Godot_console.exe --headless --path . -s tests/h2h_solo.gd -- --save-dir=user://mpflow-x-guest --box=D:/tmp/box
##
## Run by tools/mp-flow-local.ps1 -Save, once the two clients have saved "The
## Battle of Hoth" (<box>/save.json holds the day and state hash the save was
## made at).

const Art := preload("res://src/ui/artwork.gd")
const SaveName := "The Battle of Hoth"   # what mp_flow --save saves
const Resave := "Alone"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("  %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func _init() -> void:
	await process_frame
	var dir := _arg("--save-dir=", "")
	var box := _arg("--box=", "")
	if dir.is_empty() or box.is_empty() or not FileAccess.file_exists("%s/save.json" % box):
		print("[h2h_solo] SKIP: needs a head-to-head save - run tools/mp-flow-local.ps1 -Save")
		quit(0)
		return
	Art.IgnoreProjectFolder = true   # the player's own art must not change what loads
	Art.UserArtRoot = "user://test-h2h-solo-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	SaveManager.Dir = dir
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/save.json" % box))
	var saved_day := int(saved.get("day", -1))
	var slot: Dictionary = _game(SaveManager.Find(SaveName))
	_check(not slot.is_empty() and slot["side"] == "h2h", "\"%s\" is a head-to-head save" % SaveName)
	var local := str(slot.get("local", ""))

	# --- Load it as the Load Game screens do. ---
	GameSettings.PendingLoadPath = SaveManager.GamePath(SaveManager.Find(SaveName))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	(main as GameManager).SetSpeed(0)   # the test moves the days, not the clock
	for _i in 5:
		await process_frame
	var us: Faction = GameSettings.PlayerFaction
	var them: Faction = MpSetup.other_faction(us)
	_check(StrategicTickManager.Today == saved_day, "loads at the saved day %d (got %d)" % [saved_day, StrategicTickManager.Today])
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == str(saved.get("hash", "")), "loads the saved state")
	_check(us != null and us.Id == local, "plays the side this computer had (%s, got %s)" % [local, us.Id if us != null else "none"])
	_check(GameSettings.HumanFactions.size() == 1 and GameSettings.IsHuman(us), "only that side is human")
	_check(not GameSettings.IsHuman(them), "the AI plays the other side (%s)" % them.Id)
	_check(GameSettings.AiTakeoverDay == saved_day, "from the saved day")
	_check(MpSetup.session == null, "a single-player game, no head-to-head session")

	# --- Play on three days: the AI moves the other side. ---
	var engine: StrategicTickManager = main.get("_strategicEngine")
	for _i in 3:
		engine.AdvanceDay()
		CommandBus.day_done()
	var day_after := StrategicTickManager.Today
	var hash_after := GameSignature.ReplayHash(GameState.ActiveGalaxy)

	# --- Saved as a single-player game, and loaded again. ---
	var resaved: String = SaveManager.Save(Resave)
	_check(not resaved.is_empty(), "saves it as \"%s\"" % Resave)
	var header: Dictionary = CommandLog.Read(SaveManager.GamePath(resaved))[0]
	_check(int(header.get("ai_takeover_day", 0)) == saved_day and (header.get("humans", []) as Array).size() == 2,
		"the save says both sides were human until the AI took over on day %d" % saved_day)
	_check(str(_game(resaved).get("side", "")) == local, "its side icon is this side, not head-to-head")
	main.queue_free()
	await process_frame
	await process_frame
	CommandLog.Reset()
	GameSettings.PendingLoadPath = SaveManager.GamePath(resaved)
	var again: Node = load("res://Main.tscn").instantiate()
	root.add_child(again)
	await process_frame
	(again as GameManager).SetSpeed(0)
	for _i in 5:
		await process_frame
	_check(StrategicTickManager.Today == day_after, "\"Alone\" loads at day %d (got %d)" % [day_after, StrategicTickManager.Today])
	_check(GameSignature.ReplayHash(GameState.ActiveGalaxy) == hash_after, "\"Alone\" loads the same state")
	_check(GameSettings.HumanFactions.size() == 1 and GameSettings.PlayerFaction.Id == local and not GameSettings.IsHuman(them), "and the AI still plays the other side")

	again.queue_free()
	await process_frame
	print("[h2h_solo] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The saved game `id` as SaveManager.Games() lists it ({} if none).
func _game(id: String) -> Dictionary:
	for g: Dictionary in SaveManager.Games():
		if g["id"] == id:
			return g
	return {}


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
