extends SceneTree
## THE MESSAGE INDEX'S KEYS ACT ONLY ON A MESSAGE (message_window.gd). Opened on
## a tab with nothing in it, the plain window used to show Continue Mission,
## Abort Mission and Delete with no message to act on - and Continue or Abort
## pressed there hit a null message. Now, for each pack:
##   1. a tab empty from the first paint shows none of the three;
##   2. pressing them anyway does nothing;
##   3. a tab with a message shows Delete, and Continue / Abort only when the
##      message asks (manual p110).
##
##   .\tools\run-gd.ps1 tests/message_empty_actions.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/message_empty_actions.gd -- --seed=12345      (Star Wars)

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[message_empty_actions] ok   %s" % what)
	else:
		_fails += 1
		print("[message_empty_actions] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-message-empty-none"
	# The plain window (without the art the Star Wars pack builds the
	# original's from our stand-ins).
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()

	# Chat is empty in a game against the computer: the window's first paint.
	ui.OnMessageIndexClicked("Chat")
	for _i in 3:
		await process_frame
	var w: MessageWindow = ui._openWindows.get("Communications")
	_check(w != null and w._original == false, "%s: the plain Message Index opened on Chat" % id)
	if w == null:
		_done()
		return
	_check(MessageWindow.MessagesFor("Chat").is_empty(), "the Chat tab is empty")
	_check(not w._continueBtn.visible and not w._abortBtn.visible and not w._deleteBtn.visible,
		"nothing picked: no Continue Mission, Abort Mission or Delete")
	w._continueBtn.pressed.emit()
	w._abortBtn.pressed.emit()
	w._deleteBtn.pressed.emit()
	await process_frame
	_check(is_instance_valid(w) and w._selectedMessage == null, "pressed anyway, they do nothing")

	# A tab with a message: Delete for it; Continue and Abort only if it asks.
	var us: Faction = GameSettings.PlayerFaction
	var m := GameMessage.new("Empty-actions test", "A plain report.", Enums.MessageCategory.Fleets, StrategicTickManager.Today)
	EventBus.Tell(us, m)
	w.OpenToCategory("Fleets")
	for _i in 2:
		await process_frame
	_check(w._selectedMessage != null, "Fleets: a message is shown")
	_check(w._deleteBtn.visible, "Delete is there for it")
	var asks: bool = w._selectedMessage != null and w._selectedMessage.AwaitsDecision()
	_check(w._continueBtn.visible == asks and w._abortBtn.visible == asks,
		"Continue / Abort only when the message asks (%s)" % ("it does" if asks else "it does not"))

	# Back to the empty tab: the keys go again.
	w.OpenToCategory("Chat")
	for _i in 2:
		await process_frame
	_check(not w._continueBtn.visible and not w._abortBtn.visible and not w._deleteBtn.visible,
		"back on the empty tab: the keys are gone again")
	_done()


func _done() -> void:
	print("[message_empty_actions] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
