extends SceneTree
## The original's Speed Control and pause box (manual p071 Fig. 3.8; TeeJ,
## 2026-09-23): with the art imported the time display is the side's box -
## the day in its window, no unread count, the bars for the speed (none at
## Pause and Very Slow, one to three at Slow to Fast) - and a click drops the
## speed menu under it; Pause brings up "Resume Game Play?" over a blocker,
## and its check resumes at the speed before. Writes and removes its own test
## art, never the player's own.
##
##   .\tools\run-gd.ps1 tests/speed_control.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[speed_control] ok   %s" % what)
	else:
		_fails += 1
		print("[speed_control] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-speed-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for side in ["alliance", "empire"]:
		_png("%s/windows/hud_speed.%s.png" % [dir, side], 102, 24, Color(0.5, 0.5, 0.5))
		for n in 5:
			_png("%s/windows/speed_bars.%s.%d.png" % [dir, side, n], 16, 10, Color(0, n / 4.0, 0))
	_png("%s/windows/dialog_plate1.png" % dir, 412, 176, Color(0.6, 0.6, 0.6))
	_png("%s/buttons/dialog_ok.png" % dir, 57, 28, Color(0.8, 0.8, 0.8))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var gm: GameManager = main
	_check(gm._oSpeed != null and gm._oDay != null and gm._oBars != null, "the time display is the original's box")
	gm.RefreshStatusBar()
	_check(gm._oDay.text == str(StrategicTickManager.Today), "the day in its window, the number alone ('%s')" % gm._oDay.text)
	EventBus.Tell(GameSettings.PlayerFaction, GameMessage.new("A", "a", Enums.MessageCategory.Defense, StrategicTickManager.Today, null, null))
	gm.RefreshStatusBar()
	_check(not gm._dayLabel.text.contains("unread") and not gm._oDay.text.contains("unread"), "no unread count on the day box")

	for level in [2, 3, 4, 1]:
		gm.SetSpeed(level)
		var want: Texture2D = OUI_pic("speed_bars.%s.%d" % [gm._oSide, level])
		_check(gm._oBars.texture == want, "at %s the bars show picture %d" % [GameManager.SpeedNames[level], level])

	# A click pulls the menu down under the control.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = gm._timeControls.global_position + Vector2(10, 10)
	gm._timeControls.gui_input.emit(click)
	await process_frame
	# The original's menu when its bars are imported (original_menu.gd).
	var menu: Window = gm._oSpeedMenu if gm._oSpeedMenu != null else gm._speedMenu
	_check(menu.visible and absf(menu.position.y - (gm._timeControls.global_position.y + gm._timeControls.size.y)) < 2.0,
		"a click drops the speed menu under the control")
	menu.hide()

	# Pause: the original's box over a blocker; its check resumes.
	gm.SetSpeed(3)
	gm.SetSpeed(0)
	await process_frame
	_check(gm._oPause != null and gm._oPause.visible and gm._oPause.mouse_filter == Control.MOUSE_FILTER_STOP, "Pause brings up the original's box, which takes every click")
	var text: Label = gm._oPause.find_child("Text", true, false)
	_check(text != null and text.text == "Resume Game Play?", "it asks \"Resume Game Play?\" (the original's words)")
	_check(gm._oBars.texture == OUI_pic("speed_bars.%s.0" % gm._oSide), "paused, no bar is lit")
	var ok: TextureButton = gm._oPause.find_child("dialog_ok", true, false)
	if ok != null:
		ok.pressed.emit()
	await process_frame
	_check(gm._speed == 3 and not gm._oPause.visible, "the check resumes at Medium, the speed before")

	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[speed_control] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func OUI_pic(name: String) -> Texture2D:
	return Art.WindowPicture(name)   # the HUD scales its node, not the picture


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
