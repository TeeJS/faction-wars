extends SceneTree
## With a message open in the original's Message Index, Esc and the close box
## go back to the index, not out to the galaxy (TeeJ, 2026-09-25); on the
## index itself they close the window, as before. On stand-in pictures of the
## original's, written and removed under user://.
##
##   .\tools\run-gd.ps1 tests/message_step_back.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-message-step-back-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[message_step_back] ok   %s" % what)
	else:
		_fails += 1
		print("[message_step_back] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot   # never the player's own
	FactionRegistry.EnsureLoaded()
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	if sets.is_empty():
		print("[message_step_back] (this pack declares no art set)")
		print("[message_step_back] 0 checks, 0 failed")
		quit(0)
		return
	var dir := "%s/%s" % [ArtRoot, sets[0]]
	for sub in ["windows", "buttons", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for side in ["empire", "alliance"]:
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 330)
		_png("%s/windows/msgindex_selection.%s.png" % [dir, side], 380, 20)
		for b in ["msgindex_summary", "msgindex_post", "msgindex_open", "msgindex_compose", "ency_close", "ency_view_index"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 40, 40)
	_png("%s/windows/msgindex_plate.png" % dir, 400, 305)
	_png("%s/windows/ency_topic_plate.png" % dir, 400, 305)
	for b in ["msgindex_select_all", "msgindex_delete", "decision_ok", "decision_cancel", "msgsummary_up", "msgsummary_down"]:
		_png("%s/buttons/%s.png" % [dir, b], 20, 20)
	for tab in MessageWindow.OTabNames:
		_png("%s/tabs/%s.png" % [dir, tab], 36, 41)
		_png("%s/tabs/%s.pressed.png" % [dir, tab], 36, 41)
	Art.Reset()

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	EventBus.MessageLog.clear()
	var m := GameMessage.new("Step back check", "Read me.", Enums.MessageCategory.Conflict, StrategicTickManager.Today, null, null)
	EventBus.Tell(us, m)

	ui.OnMessageIndexClicked("All")
	for _i in 3:
		await process_frame
	var w: Control = ui._openWindows.get("Communications")
	_check(w != null and w._original, "the Message Index opens in the original's look")
	if w == null or not w._original:
		_finish()
		return
	w._o_show_summary(m)
	_check(w._oSummary.visible and not w._oIndex.visible, "a message open")
	ui._unhandled_key_input(_esc())
	for _i in 2:
		await process_frame
	_check(is_instance_valid(w) and not w.is_queued_for_deletion() and w.visible, "Esc with a message open: the window stays")
	_check(w._oIndex.visible and not w._oSummary.visible, "... and shows the Message Index again")

	w._o_show_summary(m)
	var close: TextureButton = w.find_child("ency_close.*", true, false)
	if close == null:
		for c in w.find_children("*", "TextureButton", true, false):
			if (c as TextureButton).tooltip_text == "Close message screen":
				close = c
	_check(close != null, "the close box is there")
	if close != null:
		close.pressed.emit()
		for _i in 2:
			await process_frame
		_check(is_instance_valid(w) and not w.is_queued_for_deletion() and w._oIndex.visible,
			"the close box with a message open: back to the Message Index")

	ui._unhandled_key_input(_esc())
	for _i in 2:
		await process_frame
	_check(not is_instance_valid(w) or w.is_queued_for_deletion(), "Esc on the index closes the window, as before")
	_finish()


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e


func _finish() -> void:
	_remove(ArtRoot)
	Art.Reset()
	print("[message_step_back] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.4, 0.4))
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
