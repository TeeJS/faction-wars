extends SceneTree
## Renders the Saved Games screen (five rows; Import Game, Export Game and See
## all games in the sixth row's place) and See all games, with twelve games
## saved (as both sides) so the second page shows, to two PNGs cropped to the
## screen's picture. Needs a window (NOT --headless) and the art; its saves go
## to a scratch folder:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_saved_games.gd -- --out=C:/tmp/saved.png --all=C:/tmp/all.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://saved.png")
	var all_out := _arg("--all=", "user://all.png")
	SaveManager.Dir = "user://capture-saved-games"
	_remove(SaveManager.Dir)
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OnMenuButtonClicked()
	for _i in 3:
		await process_frame
	var screen: Control = ui.get_node_or_null("OptionsScreen")
	if screen == null:
		print("[capture_saved_games] the original screen did not open (art imported?)")
		quit(1)
		return
	var was: Faction = GameSettings.PlayerFaction
	var other: Faction = FactionRegistry.ById("empire" if was.Id == "alliance" else "alliance")
	var names := ["Hoth defence", "Kessel run", "Endor push", "Death Star plans", "Bespin", "Dagobah", "Yavin IV", "Mon Cal fleet", "Sullust", "Corellia", "game 1", "game 1 - death star"]
	for i in names.size():
		GameSettings.PlayerFaction = other if i % 3 == 1 else was
		screen.SaveNamed(names[i])
	GameSettings.PlayerFaction = was
	for _i in 3:
		await process_frame
	_shot(screen, out)
	screen._see_all()
	for _i in 3:
		await process_frame
	var all: Control = screen.get_node_or_null("AllGames")
	if all != null:
		_shot(all, all_out)
	_remove(SaveManager.Dir)
	quit(0)


func _shot(screen: Control, path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var canvas: Control = screen.get("_canvas")
	var s: float = screen.get("_s")
	var r := Rect2i(Vector2i(canvas.global_position), Vector2i(Vector2(640, 480) * s))
	print("[capture_saved_games] %s at %s" % [path, str(r)])
	img.get_region(r).save_png(path)


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
