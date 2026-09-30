extends SceneTree
## THE MESSAGE INDEX NEVER RUNS UNDER THE THEATRE LIST (UIManager.OnMessageIndexClicked).
## Docked at the map's top-left, the original's index drawn 2x is wider than the
## Command Center frame's map window (drawn 1.767x): the Empire's ran 13 px under
## the theatre list at 1440 x 850 (TeeJ, 2026-09-29). For each side, with the
## original's layout from the stand-ins (no art set), the index opened and
## settled lies wholly left of the list and on screen.
##
##   .\tools\run-gd.ps1 tests/message_index_clear.gd
##   .\tools\run-gd.ps1 tests/message_index_clear.gd -- --pack=ww2

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[message_index_clear] %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-message-index-clear-none"
	root.size = Vector2i(1440, 850)
	FactionRegistry.EnsureLoaded()
	for side in FactionRegistry.Playable:
		MpSetup.reset()
		GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
		GameSettings.SelectedSize = Enums.GalaxySize.Standard
		GameSettings.PlayerFaction = side
		var main: Node = load("res://Main.tscn").instantiate()
		root.add_child(main)
		for _i in 10:
			await process_frame
		var ui: UIManager = main.get_node("UIManager")
		ui.OnMessageIndexClicked("All")
		for _i in 4:
			await process_frame
		var w: Control = ui._openWindows.get("Communications")
		var list: Control = ui.find_child("TaskbarPanel", true, false)
		var right: float = w.global_position.x + w.size.x
		var edge: float = list.global_position.x if list != null and list.visible else float(root.size.x)
		_check(right <= edge, "%s: the index (x %.0f to %.0f) ends left of the theatre list (x %.0f)" % [side.Id, w.global_position.x, right, edge])
		_check(w.global_position.x >= 0.0 and w.global_position.y >= 0.0, "%s: and on screen" % side.Id)
		main.queue_free()
		for _i in 3:
			await process_frame
	print("[message_index_clear] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
