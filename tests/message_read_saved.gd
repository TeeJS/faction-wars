extends SceneTree
## A read message stays read across save and load (TeeJ, 2026-09-28: restores
## came back with every message unread). Reading is an order - read_messages,
## like delete_messages - so the replay a load runs reads it again. Its saves
## and art go to scratch folders.
##
##   .\tools\run-gd.ps1 tests/message_read_saved.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[message_read_saved] ok   %s" % what)
	else:
		_fails += 1
		print("[message_read_saved] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-message-read-art"
	SaveManager.Dir = "user://test-message-read-saves"
	_remove(SaveManager.Dir)
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()

	# A game that makes its own messages (so a replay makes them again).
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4242)
	CommandLog.Open("user://test-message-read-gen.jsonl", CommandLog.Header())
	for _i in 60:
		engine.AdvanceDay()
		CommandBus.day_done()
		if EventBus.VisibleMessages().size() >= 2:
			break
	var msgs: Array = EventBus.VisibleMessages()
	_check(msgs.size() >= 2, "the game has made messages of its own (%d)" % msgs.size())
	if msgs.size() < 2:
		_finish()
		return
	var first: GameMessage = msgs[0]
	var second: GameMessage = msgs[1]
	var s1 := first.Serial
	var s2 := second.Serial
	_check(CommandBus.issue("read_messages", { "messages": [s1] }).ok and first.IsRead, "reading one is an order")
	var id := SaveManager.Save("Read one")
	_check(not id.is_empty(), "saved")
	CommandLog.Reset()

	# Load it as the Load button does.
	GameSettings.PendingLoadPath = SaveManager.GamePath(id)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	(main as GameManager).SetSpeed(0)
	for _i in 5:
		await process_frame
	var again1: GameMessage = EntityIndex.message(s1)
	var again2: GameMessage = EntityIndex.message(s2)
	_check(again1 != null and again1.IsRead, "after the load the one read is still read")
	_check(again2 != null and not again2.IsRead, "and the one not read is still unread")

	# Reading through the Message window is the order too.
	var ui: UIManager = main.get_node("UIManager")
	ui.OnMessageIndexClicked("All")
	for _i in 3:
		await process_frame
	var w: Control = ui._openWindows.get("Communications")
	_check(w != null, "the Message window opens")
	if w != null and again2 != null:
		var before := CommandLog.Entries.size()
		w.ShowDetail(again2, null)
		var last: Command = CommandLog.Entries[CommandLog.Entries.size() - 1] if CommandLog.Entries.size() > before else null
		_check(again2.IsRead and last != null and last.Kind == "read_messages", "opening a message in the window reads it by order")
		var id2 := SaveManager.Save("Read both")
		main.queue_free()
		await process_frame
		CommandLog.Reset()
		GameSettings.PendingLoadPath = SaveManager.GamePath(id2)
		var main2: Node = load("res://Main.tscn").instantiate()
		root.add_child(main2)
		await process_frame
		(main2 as GameManager).SetSpeed(0)
		for _i in 5:
			await process_frame
		var r1: GameMessage = EntityIndex.message(s1)
		var r2: GameMessage = EntityIndex.message(s2)
		_check(r1 != null and r1.IsRead and r2 != null and r2.IsRead, "saved again and replayed, both are read")
	_finish()


func _finish() -> void:
	CommandLog.Reset()
	DirAccess.remove_absolute("user://test-message-read-gen.jsonl")
	_remove(SaveManager.Dir)
	print("[message_read_saved] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
