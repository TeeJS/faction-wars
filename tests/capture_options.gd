extends SceneTree
## Renders the original's Game Options screen (manual p076 Fig. 3.16) in play,
## with two games saved (one as each side), to a PNG cropped to the screen's
## picture. Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_options.gd -- --out=C:/tmp/options.png

func _init() -> void:
	await process_frame
	# --noart: as a player with no art set (our stand-ins, the plain build parity plan).
	if OS.get_cmdline_user_args().has("--noart"):
		var art: GDScript = load("res://src/ui/artwork.gd")
		art.IgnoreProjectFolder = true
		art.UserArtRoot = "user://capture-noart"
		art.Reset()
	var out := _arg("--out=", "user://options.png")
	SaveManager.Dir = "user://capture-saves"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OpenGameOptions()
	for _i in 3:
		await process_frame
	var screen: Control = ui.get_node_or_null("OptionsScreen")
	if screen == null:
		_plain(ui, out)
		return
	(screen._names[0] as LineEdit).text = "1"
	screen._save(0)
	var was: Faction = GameSettings.PlayerFaction
	GameSettings.PlayerFaction = FactionRegistry.ById("empire" if was.Id == "alliance" else "alliance")
	# The first save is now the top row; type the second name on the next row.
	(screen._names[1] as LineEdit).text = "start"
	screen._save(1)
	GameSettings.PlayerFaction = was
	for _i in 3:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(screen._canvas.global_position), Vector2i(Vector2(640, 480) * screen._s))
	print("[capture_options] screen at %s, scale %.3f" % [str(r), screen._s])
	var err := img.get_region(r).save_png(out)
	_remove(SaveManager.Dir)
	quit(0 if err == OK else 1)


## Without the art (or a pack with a look): the plain Game Options window,
## two games saved from its rows, cropped to the window.
func _plain(ui: Node, out: String) -> void:
	var w: GameOptionsWindow = ui.get_node_or_null("GameOptionsWindow")
	if w == null:
		print("[capture_options] no Game Options window opened")
		quit(1)
		return
	(w._rows[0]["name"] as LineEdit).text = "Opening moves"
	w._on_save(0)
	(w._rows[1]["name"] as LineEdit).text = "Before the landings"
	w._on_save(1)
	for _i in 4:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position) - Vector2i(8, 8), Vector2i(w.size) + Vector2i(16, 16))
	print("[capture_options] plain window at %s" % str(r))
	var err := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(out)
	_remove(SaveManager.Dir)
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
