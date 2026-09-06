extends SceneTree
## The Comms "Go To" button. It calls _uiManager.OnDefenseClicked, but the message
## window only gets its _uiManager when OnMessageIndexClicked calls window.Setup().
## Without that, _uiManager is null and Go To silently does nothing (reported from
## play). This test opens the message index the way the HUD does, then drives Go To.
##
##   Godot_console.exe --headless --path . -s tests/goto_button.gd

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

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var ui: Node = main.get_node_or_null("UIManager")
	_check(ui != null, "UIManager present")
	if ui == null:
		_finish(); return

	# Open the message index the way the HUD does.
	ui.OnMessageIndexClicked("All")
	await process_frame
	var win: Node = ui._openWindows.get("Communications")
	_check(win != null, "the Comms window opened")
	if win == null:
		_finish(); return

	# THE FIX: the window must have its UIManager, or Go To is a no-op.
	_check(win._uiManager != null, "the message window has its UIManager after opening")

	# Drive Go To against a message linked to a planet.
	var planet: Planet = GameState.AllPlanets()[0]
	var msg := GameMessage.new("Test", "Something happened at %s." % planet.Name, Enums.MessageCategory.Fleets, 1, planet, null)
	win._selectedMessage = msg
	win.OnGotoClicked()
	await process_frame
	_check(ui._openWindows.has("%s Defenses" % planet.Name), "Go To opens the planet's Defenses window")

	_finish()


func _finish() -> void:
	print("[goto_button] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
