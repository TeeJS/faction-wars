extends SceneTree
## The original's Game Options screen (manual p075-p076, Fig. 3.16;
## src/ui/original_options_screen.gd): with its art imported, the Menu button
## and F1 open it in place of the Game Menu and the Save Game window; the
## clock stops while it is up; Save Game writes the slot and its side icon;
## Load Game is live only on a used slot; Restart and Exit ask first; Return
## goes back to the game; from the Cockpit there is nothing to save and no
## Command Center to return to; the sound and tactical options are greyed.
## Writes and removes its own test art and saves, never the player's own.
##
##   .\tools\run-gd.ps1 tests/options_screen.gd

const Art := preload("res://src/ui/artwork.gd")
const Screen := preload("res://src/ui/original_options_screen.gd")

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
	for w in ["options_side.empire", "options_side.alliance", "options_side.h2h", "options_music.grey", "options_light.off", "options_knob"]:
		_png("%s/windows/%s.png" % [dir, w], 26, 19, Color(0.9, 0.1, 0.1))
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
	_check(music != null and music.get_theme_color("font_color") == Screen.Greyed and music.tooltip_text.begins_with("Not in this game"),
		"Play Music is greyed: there is no sound yet")
	_check(toggle != null and toggle.text == "Show Starfield" and toggle.get_theme_color("font_color") == Screen.Greyed, "the tactical toggles are greyed")
	for head in ["Head_SoundOptions", "Head_TacticalDisplayOptions"]:
		var l: Label = screen._canvas.get_node_or_null(head)
		_check(l != null and l.get_theme_color("font_color") == Screen.Greyed, "%s is greyed with its options" % head)
	var saved: Label = screen._canvas.get_node_or_null("Head_SavedGames")
	_check(saved != null and saved.get_theme_color("font_color") == Screen.Green, "Saved Games, which works, stays green")

	screen._restart()
	var confirm: Node = screen.get_node_or_null("Confirm")
	_check(confirm is ConfirmationDialog, "Restart asks first")
	if confirm != null:
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


func _finish() -> void:
	_remove(Art.UserArtRoot)
	_remove(SaveManager.Dir)
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
