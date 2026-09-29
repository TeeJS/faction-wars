extends SceneTree
## THE SECTOR WINDOW OF EVERY THEATRE (docs/ww2-look-plan.md, phase 8): one
## shot per sector, the window alone on the map. Needs a window (NOT
## --headless), like tests/capture_look.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_look_sectors.gd -- `
##       --out=C:/tmp/look/ww2_sectors --pack=ww2 --seed=12345 --record=user://capture-look.jsonl [--faction=allies]
##
## writes <out>_<sector id>.png. --record= is REQUIRED, so the player's session
## log is untouched. No art set is read, so a pack shows its own look (the
## Star Wars pack's plain window: the stand-ins off).

const Art := preload("res://src/ui/artwork.gd")
const MoviesLib := preload("res://src/ui/movies.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const LookSectorLib := preload("res://src/ui/look_sector.gd")


func _init() -> void:
	await process_frame
	if _arg("--record=", "").is_empty():
		push_error("[capture_look_sectors] pass --record=user://<file>.jsonl so the player's session log is untouched")
		quit(2)
		return
	var out := _arg("--out=", "user://sectors").trim_suffix(".png")
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-capture-look-none"
	MoviesLib.UserRoot = "user://test-capture-look-none"
	MoviesLib.LaunchPlayed = true
	StandIns.Enabled = false
	# --sheet: every theatre on the plain plotting sheet, for comparison.
	if OS.get_cmdline_user_args().has("--sheet"):
		LookSectorLib.SHEET = true
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.HQOnlyVictory = false
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var ok := true
	# --pair=<name>[@x:y],<name>[@x:y],...: several sector windows open at once,
	# each moved to x, y as a player drags it (or where the game puts it); one
	# shot, <out>_pair.png. Underscores stand for spaces in a name.
	var pair := _arg("--pair=", "")
	if not pair.is_empty():
		for item in pair.split(","):
			var bits: PackedStringArray = item.strip_edges().split("@")
			var want: String = bits[0].replace("_", " ")
			var s: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(x: Sector) -> bool: return x.Name == want)
			if s == null:
				continue
			ui.OnSectorClicked(s)
			for _i in 5:
				await process_frame
			if bits.size() > 1:
				var xy: PackedStringArray = bits[1].split(":")
				var w: Control = ui._openWindows.get(s.Name)
				if w != null and xy.size() == 2:
					w.position = Vector2(float(xy[0]), float(xy[1]))
					for _i in 2:
						await process_frame
		var shot: Image = root.get_viewport().get_texture().get_image()
		var e := shot.save_png("%s_pair.png" % out)
		print("[capture_look_sectors] pair %s -> %s" % [pair, "%s_pair.png" % out if e == OK else ("error %d" % e)])
		quit(0 if e == OK else 1)
		return
	for sector in GameState.ActiveGalaxy:
		ui.CloseAllWindows()
		for _i in 3:
			await process_frame
		ui.OnSectorClicked(sector)
		for _i in 5:
			await process_frame
		var path := "%s_%s.png" % [out, (sector as Sector).Id if "Id" in sector else str(sector.Name).to_snake_case()]
		var img: Image = root.get_viewport().get_texture().get_image()
		var err := img.save_png(path)
		print("[capture_look_sectors] %s -> %s" % [sector.Name, path if err == OK else ("error %d" % err)])
		ok = ok and err == OK
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
