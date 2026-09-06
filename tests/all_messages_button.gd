extends SceneTree
## Issue #5: an "All Messages" entry sits at the TOP of the left-column category
## list (UIManager/CommsPanel/Margin/CommsList) on the main screen. It is built in
## ui_manager.gd _ready (code, not the .tscn) and reuses the same dynamic wiring
## the nine category buttons use, so pressing it calls OnMessageIndexClicked("All")
## -> the Comms Center's existing All tab.
##
## Also checks the semantics that light it: UnreadCount(MessageCategory.All)
## aggregates every unread message, so the All button highlights whenever any
## category has unread mail.
##
##   Godot_console.exe --headless --path . -s tests/all_messages_button.gd

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

	# Main.tscn's GameManager starts the game in its own _ready; UIManager._ready
	# then builds the CommsList (adding the All button). Give the tree a few
	# frames to run both.
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var commsList: Node = main.get_node_or_null("UIManager/CommsPanel/Margin/CommsList")
	_check(commsList != null, "the CommsList exists under Main")
	if commsList != null and commsList.get_child_count() > 0:
		var first: Node = commsList.get_child(0)
		_check(first is Button, "the first entry is a Button")
		_check(first.name == "All", "the first entry is named 'All' (top of the list)")
		if first is Button:
			_check((first as Button).text == "All Messages", "the first entry reads 'All Messages'")
		# The original nine category buttons are still there, after All.
		_check(commsList.get_node_or_null("Loyalty") != null, "the Loyalty category button is still present")
		_check(commsList.get_node_or_null("Advice") != null, "the Advice category button is still present")
		# Exactly one All button - idempotent, not double-added.
		var alls := 0
		for c in commsList.get_children():
			if c is Button and c.name == "All":
				alls += 1
		_check(alls == 1, "exactly one All button (idempotent)")

	# Aggregate-unread semantics (what lights the All button): an unread message
	# in ANY category is counted by UnreadCount(MessageCategory.All).
	_check(Enums.MessageCategory.has("All"), "MessageCategory has an All member")
	var base: int = EventBus.UnreadCount(Enums.MessageCategory.All)
	var m := GameMessage.new("Test", "An unread transmission.", Enums.MessageCategory.Fleets, 1, null, null)
	EventBus.Tell(GameSettings.PlayerFaction, m)
	_check(EventBus.UnreadCount(Enums.MessageCategory.All) == base + 1, "UnreadCount(All) counts a new unread message in any category")

	_finish()


func _finish() -> void:
	print("[all_messages_button] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
