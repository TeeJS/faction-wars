extends SceneTree
## The original's Game Options screen (manual p075-p076, Fig. 3.16;
## src/ui/original_options_screen.gd): with its art imported, the Menu button
## and F1 open it in place of the Game Menu and the Save Game window; the
## clock stops while it is up; Save Game writes the slot and its side icon;
## Load Game is live only on a used slot; Restart and Exit ask first; Return
## goes back to the game; from the Cockpit there is nothing to save and no
## Command Center to return to; Play Music and the music volume work (the
## music plan, phase 2); the sound effects and tactical options are greyed.
## Writes and removes its own test art and saves, never the player's own.
##
##   .\tools\run-gd.ps1 tests/options_screen.gd

const Art := preload("res://src/ui/artwork.gd")
const Screen := preload("res://src/ui/original_options_screen.gd")
const MusicLib := preload("res://src/ui/music.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[options_screen] ok   %s" % what)
	else:
		_fails += 1
		print("[options_screen] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
	Art.UserArtRoot = "user://test-options-art"
	SaveManager.Dir = "user://test-options-saves"
	_remove(SaveManager.Dir)
	MusicLib.SettingsFile = "user://test-options-music.cfg"
	DirAccess.remove_absolute(MusicLib.SettingsFile)
	MusicLib._loaded = false
	MusicLib.PlayMusic = true
	MusicLib.Volume = MusicLib.DEFAULT_VOLUME
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard

	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["screens", "buttons", "windows"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/screens/options.png" % dir, 640, 480, Color(0.3, 0.3, 0.3))
	for b in ["options_save", "options_load", "options_restart", "options_return", "options_exit"]:
		_png("%s/buttons/%s.png" % [dir, b], 42, 20, Color(0.6, 0.6, 0.6))
		_png("%s/buttons/%s.disabled.png" % [dir, b], 42, 20, Color(0.2, 0.2, 0.2))
	for w in ["options_side.empire", "options_side.alliance", "options_side.h2h", "options_music.lit", "options_music.off", "options_light.off", "options_knob"]:
		_png("%s/windows/%s.png" % [dir, w], 26, 19, Color(0.9, 0.1, 0.1))
	# The original's alert box (REBDLOG): the two-socket plate, check and X.
	_png("%s/windows/dialog_plate2.png" % dir, 412, 176, Color(0.4, 0.4, 0.4))
	for b in ["dialog_ok", "dialog_cancel"]:
		_png("%s/buttons/%s.png" % [dir, b], 57, 28, Color(0.5, 0.5, 0.5))
		_png("%s/buttons/%s.pressed.png" % [dir, b], 57, 28, Color(0.3, 0.3, 0.3))
	Art.Reset()
	_check(Screen.CanBuild(), "with its parts the screen can be built")

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var gm: GameManager = main

	ui.OnMenuButtonClicked()
	await process_frame
	var screen: Control = ui.get_node_or_null("OptionsScreen")
	_check(screen != null and ui._openWindows.get("GameMenu") == null, "the Menu button opens the Game Options screen, not the Game Menu")
	if screen == null:
		_finish()
		return
	_check(gm._menuOpen, "the clock stops while it is up")
	_check(screen._saveBtns.size() == 6 and screen._loadBtns.size() == 6 and screen._names.size() == 6, "six slots, each Save Game, a name, Load Game")
	_check(Lq.all(screen._loadBtns, func(b: TextureButton) -> bool: return b.disabled), "no saves yet: every Load Game is greyed")

	(screen._names[2] as LineEdit).text = "Alliance High Maintenance"
	screen._save(2)
	var s: Dictionary = SaveManager.Slots()[2]
	_check(s["used"] and s["name"] == "Alliance High Maintenance", "Save Game writes slot 3 under its name")
	_check(s["side"] == GameSettings.PlayerFaction.Id, "the slot records the side (%s)" % s["side"])
	_check((screen._sideIcons[2] as TextureRect).texture != null, "the slot shows the side's icon")
	_check(not (screen._loadBtns[2] as TextureButton).disabled, "its Load Game is live")

	var music: Label = screen._canvas.get_node_or_null("MusicLabel")
	var toggle: Label = screen._canvas.get_node_or_null("Toggle0")
	_check(music != null and music.get_theme_color("font_color") == Screen.Green and (screen._canvas.get_node("MusicState") as Label).text == "On",
		"Play Music works: green, and On by default")
	_check(toggle != null and toggle.text == "Show Starfield" and toggle.get_theme_color("font_color") == Screen.Greyed, "the tactical toggles are greyed")
	var sound: Label = screen._canvas.get_node_or_null("Head_SoundOptions")
	_check(sound != null and sound.get_theme_color("font_color") == Screen.Green, "Sound Options is green: its music half works")
	var tactical: Label = screen._canvas.get_node_or_null("Head_TacticalDisplayOptions")
	_check(tactical != null and tactical.get_theme_color("font_color") == Screen.Greyed, "Tactical Display Options is greyed with its options")
	var effects: Control = screen._canvas.get_node_or_null("EffectsKnob")
	_check(effects != null and effects.tooltip_text.begins_with("Not in this game"), "the sound-effects knob is greyed: no sound effects yet")

	# The switch turns the music off and on, and the setting is kept.
	var sw: TextureRect = screen._canvas.get_node_or_null("MusicSwitch")
	_check(sw != null and sw.texture == Art.WindowPicture("options_music.lit"), "the switch shows lit while the music is on")
	sw.gui_input.emit(_press())
	await process_frame
	var off := ConfigFile.new()
	off.load(MusicLib.SettingsFile)
	sw = screen._canvas.get_node_or_null("MusicSwitch")
	_check(not MusicLib.PlayMusic and not bool(off.get_value("music", "play", true)) and sw != null and sw.texture == Art.WindowPicture("options_music.off")
		and (screen._canvas.get_node("MusicState") as Label).text == "Off", "a click turns Play Music off: the switch goes dark, Off, and it is saved")
	sw.gui_input.emit(_press())
	await process_frame
	_check(MusicLib.PlayMusic, "a second click turns it back on")

	# The knob slides: at the left end of its track quiet, at the right end full.
	var knob: Control = screen._canvas.get_node_or_null("MusicKnob")
	_check(knob != null and is_equal_approx(knob.position.x, (Screen.KnobX + Screen.KnobTravel) * screen._s), "the music knob starts at full, the right end of its track")
	var grab := _press()
	grab.position = Vector2((Screen.KnobX + 5.5 + Screen.KnobTravel * 0.5) * screen._s - knob.position.x, 5)
	knob.gui_input.emit(grab)
	_check(absf(MusicLib.Volume - 0.5) < 0.05 and is_equal_approx(knob.position.x, (Screen.KnobX + MusicLib.Volume * Screen.KnobTravel) * screen._s),
		"dragging it to the middle sets half volume (%.2f), and the knob sits there" % MusicLib.Volume)
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(MusicLib.Bus())) - MusicLib.Volume) < 0.01, "the Music bus follows the knob")
	var saved: Label = screen._canvas.get_node_or_null("Head_SavedGames")
	_check(saved != null and saved.get_theme_color("font_color") == Screen.Green, "Saved Games, which works, stays green")

	screen._restart()
	var confirm: Node = screen.get_node_or_null("Confirm")
	_check(confirm != null, "Restart asks first")
	# In the original's alert box, in its words, the check and the X where
	# the original has them (TeeJ's screenshot, 2026-09-25).
	var plate2: bool = Screen.OUI.Pic("dialog_plate2") != null and Art.ButtonIcon("dialog_cancel") != null
	if confirm != null and plate2:
		var q: Label = confirm.find_child("Question", true, false)
		var t: Label = confirm.find_child("Text", true, false)
		var yes: Control = confirm.find_child("dialog_ok", true, false)
		var no: Control = confirm.find_child("dialog_cancel", true, false)
		_check(t != null and t.text == "Returning to the shuttle cockpit will cause unsaved changes to be lost" and q != null and q.text == "Return without saving?"
			and yes != null and yes.position.is_equal_approx(Vector2(138, 135) * Screen.OUI.K) and no != null and no.position.is_equal_approx(Vector2(229, 135) * Screen.OUI.K),
			"Restart asks in the original's box and words, check and X in its places")
		no.pressed.emit()
		await process_frame
		_check(screen.get_node_or_null("Confirm") == null or screen.get_node("Confirm").is_queued_for_deletion(), "the X closes it and stays")
	elif confirm != null:
		confirm.queue_free()
	await process_frame
	screen._return()
	for _i in 2:
		await process_frame
	_check(ui.get_node_or_null("OptionsScreen") == null and not gm._menuOpen, "Return to the Command Center closes it and the clock runs again")

	ui.OpenGameOptions()
	await process_frame
	_check(ui.get_node_or_null("OptionsScreen") != null, "F1 opens it too")
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame
	_check(ui.get_node_or_null("OptionsScreen") == null, "Alt+W closes it with the rest")

	# From the Shuttle Cockpit: nothing to save, no game to return to.
	var cockpit: Control = Screen.new()
	cockpit.FromCockpit = true
	root.add_child(cockpit)
	await process_frame
	var ret: TextureButton = Lq.first_or_null(cockpit._canvas.get_children(), func(n: Node) -> bool: return n.name.begins_with("options_return"))
	_check(ret != null and ret.disabled, "from the Cockpit, Return to the Command Center is greyed")
	_check(Lq.all(cockpit._saveBtns, func(b: TextureButton) -> bool: return b.disabled), "and Save Game with it")
	_check(not (cockpit._loadBtns[2] as TextureButton).disabled, "Load Game is live on the used slot")
	cockpit.queue_free()
	_finish()


func _press() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _finish() -> void:
	_remove(Art.UserArtRoot)
	_remove(SaveManager.Dir)
	DirAccess.remove_absolute(MusicLib.SettingsFile)
	MusicLib.SettingsFile = MusicLib.SETTINGS
	MusicLib._loaded = false
	Art.Reset()
	print("[options_screen] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


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
