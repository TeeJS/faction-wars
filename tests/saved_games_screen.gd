extends SceneTree
## The Saved Games screen's additions (PROJECT.md, TeeJ 2026-09-27): five rows,
## the sixth painted over by the panel's own band; Import Game and Manage Games
## (TeeJ, 2026-09-28: two buttons, wide enough for room round the words) as
## the multiplayer screens' choice boxes; an import lands on top, never
## overwriting, and says so in the original's one-socket alert box; Manage
## Games lists every saved game, eight to a page, with its dates, Save, Load,
## Export and Delete (which asks first), and closes back to the rows. The plain
## windows (no art) carry the same two. Writes and removes its own test art and saves.
##
##   .\tools\run-gd.ps1 tests/saved_games_screen.gd

const Art := preload("res://src/ui/artwork.gd")
const Screen := preload("res://src/ui/original_options_screen.gd")
const AllScreen := preload("res://src/ui/original_all_games_screen.gd")
const SavedArt := preload("res://src/ui/saved_games_art.gd")
const AllPlain := preload("res://src/ui/all_games_window.gd")
const MusicLib := preload("res://src/ui/music.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[saved_games_screen] ok   %s" % what)
	else:
		_fails += 1
		print("[saved_games_screen] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-saved-games-art"
	SaveManager.Dir = "user://test-saved-games-saves"
	_remove(SaveManager.Dir)
	_remove(Art.UserArtRoot)
	MusicLib.SettingsFile = "user://test-saved-games-music.cfg"
	MusicLib._loaded = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	_write_art()
	Art.Reset()
	SavedArt.Reset()
	_check(Screen.CanBuild() and AllScreen.CanBuild(), "with its parts both screens can be built")

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OnMenuButtonClicked()
	await process_frame
	var screen: Control = ui.get_node_or_null("OptionsScreen")
	_check(screen != null, "the Game Options screen opens")
	if screen == null:
		_finish()
		return

	# Five rows, and the sixth painted over.
	_check(screen._names.size() == 5 and Screen.Rows == 5, "five rows")
	var plate: Image = (screen._canvas.get_node("Plate") as TextureRect).texture.get_image()
	var band: Color = plate.get_pixel(150, SavedArt.Band.position.y + 2)
	_check(plate.get_pixel(150, 300).is_equal_approx(band), "the sixth row's place is the panel's own band")

	# The two boxes, their words green.
	var names: Array = screen._bars.map(func(b: Node) -> String: return b.name)
	_check(names == ["Bar_ImportGame", "Bar_ManageGames"], "Import Game, Manage Games (%s)" % str(names))
	var words: Array = screen._barWords.map(func(l: Label) -> String: return l.text)
	_check(words == ["Import Game", "Manage Games"], "their words")
	_check(Lq.all(screen._barWords, func(l: Label) -> bool: return l.get_theme_color("font_color") == Screen.Green), "in green")
	_check((screen._bars[0] as TextureButton).texture_pressed != (screen._bars[0] as TextureButton).texture_normal, "pressed, the box shows the chosen (red-ended) box")
	# 308 inside the panel - 3 gaps x 12 = 272: two boxes of 136, the words well inside.
	_check(is_equal_approx(Screen.BarSize.x, 136.0), "each box 136 wide (was 86.7)")
	for l: Label in screen._barWords:
		var w: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		var room: float = (Screen.BarSize.x * screen._s - w) / 2.0 / screen._s
		_check(room >= 25.0, "'%s' has room to the box's edges (%.1f each side)" % [l.text, room])
	# The panel's sides and the boxes all one gap apart (TeeJ, 2026-09-28), a
	# clamp on the multiplayer screens' wires in every gap.
	var s: float = screen._s
	var edges: Array = [float(SavedArt.PanelInside.x)]
	for b in screen._bars:
		edges.append((b as Control).position.x / s)
		edges.append(((b as Control).position.x + (b as Control).size.x) / s)
	edges.append(float(SavedArt.PanelInside.y))
	var gaps: Array = []
	for i in range(0, edges.size(), 2):
		gaps.append(edges[i + 1] - edges[i])
	_check(Lq.all(gaps, func(g: float) -> bool: return absf(g - gaps[0]) < 0.01) and gaps[0] >= 10.0,
		"the frame to the boxes and the boxes to each other: one gap (%s)" % str(gaps))
	var mid: int = Screen.BarTop + int(Screen.BarSize.y) / 2
	for c in Screen.BarWiring()[2]:
		_check(not plate.get_pixel(int(c), mid).is_equal_approx(band), "a clamp at x %.1f" % c)
	# The empty bands above and below the row filled with wires (TeeJ,
	# 2026-09-28: "I want the dang empty space filled").
	_check(not plate.get_pixel(100, 277).is_equal_approx(band) and not plate.get_pixel(100, 284).is_equal_approx(band)
		and not plate.get_pixel(100, 329).is_equal_approx(band) and plate.get_pixel(100, 274).is_equal_approx(band),
		"wires looped over the boxes and under them, the band above them left clear")

	# Save three games, then import an exported one: on top, " (2)", a note.
	for nm in ["Alpha", "Bravo", "Charlie"]:
		screen.SaveNamed(nm)
	var text: String = SaveManager.ExportText(SaveManager.Find("Bravo"))
	var r: Dictionary = screen.ImportBytes(text.to_utf8_buffer(), "Bravo.fwsave")
	_check(r["ok"] and (screen._names[0] as LineEdit).text == "Bravo (2)", "an import lands on the top row, never overwriting (%s)" % (screen._names[0] as LineEdit).text)
	var note: Node = screen.get_node_or_null("Note")
	_check(note != null, "and says so in the alert box")
	if note != null:
		var t: Label = note.find_child("Text", true, false)
		_check(t != null and t.text.contains("Bravo (2)"), "naming the game (%s)" % (t.text if t != null else ""))
		note.queue_free()
	var bad: Dictionary = screen.ImportBytes("not a save".to_utf8_buffer(), "junk.txt")
	_check(not bad["ok"] and SaveManager.Games().size() == 4, "a file that is not a saved game adds nothing")
	var n2: Node = screen.get_node_or_null("Note")
	if n2 != null:
		n2.queue_free()
	await process_frame

	# Manage Games: ten games, eight to a page.
	for i in 6:
		screen.SaveNamed("Game %d" % i)
	screen._see_all()
	await process_frame
	var all: Control = screen.get_node_or_null("AllGames")
	_check(all != null, "Manage Games opens")
	if all != null:
		_check(all._rows.size() == 8 and all.Pages() == 2, "eight rows a page, two pages for ten games")
		var top: Dictionary = SaveManager.Games()[0]
		_check((all._rows[0]["name"] as LineEdit).text == top["name"] and (all._rows[0]["date"] as Label).text == SaveManager.SavedDate(top)
			and (all._rows[0]["day"] as Label).text == "Day %d" % StrategicTickManager.Shown(int(top["day"])), "each row: name, Saved MM/DD/YYYY, Day N")
		_check(not (all._rows[0]["delete"] as TextureButton).disabled and not (all._rows[0]["export"] as TextureButton).disabled, "Delete and Export are live")
		var prev: TextureButton = all._canvas.get_node("Back")
		var next: TextureButton = all._canvas.get_node("Next")
		_check(prev.disabled and not next.disabled, "on page one: back greyed, next live")
		all.Turn(1)
		_check(all._page == 1 and (all._rows[1]["name"] as LineEdit).text == SaveManager.Games()[9]["name"] and (all._rows[2]["delete"] as TextureButton).disabled,
			"page two: the last two games, the rest of the rows empty")
		# Delete asks, then removes.
		var gone: String = all._rows[1]["id"]
		all._delete(gone)
		var ask: Node = screen.get_node_or_null("Confirm")
		_check(ask != null, "Delete asks first")
		if ask != null:
			var q: Label = ask.find_child("Question", true, false)
			_check(q != null and q.text == "Delete this saved game?", "\"Delete this saved game?\"")
			var yes: TextureButton = ask.find_child("dialog_ok", true, false)
			if yes != null:
				yes.pressed.emit()
			else:
				ask.queue_free()
		await process_frame
		_check(not SaveManager.Exists(gone) and SaveManager.Games().size() == 9, "and the game is gone")
		# Save from a Manage Games row under a new name: a new game, on top.
		all.Turn(-1)
		(all._rows[3]["name"] as LineEdit).text = "From the list"
		all._save(3)
		_check(SaveManager.Games()[0]["name"] == "From the list" and all._page == 0 and (all._rows[0]["name"] as LineEdit).text == "From the list", "Save on a row makes the game, the newest, on page one")
		all.Close()
		await process_frame
		_check(screen.get_node_or_null("AllGames") == null and (screen._names[0] as LineEdit).text == "From the list", "closing goes back to the rows, brought up to date")

	# From the Cockpit: both live.
	var cockpit: Control = Screen.new()
	cockpit.FromCockpit = true
	root.add_child(cockpit)
	await process_frame
	_check(cockpit._bars.size() == 2 and not (cockpit._bars[0] as TextureButton).disabled and not (cockpit._bars[1] as TextureButton).disabled, "from the Cockpit, Import Game and Manage Games are live")
	cockpit.queue_free()

	# The plain windows carry the same.
	var gow := GameOptionsWindow.new()
	root.add_child(gow)
	await process_frame
	var plain_words: Array = []
	for b in gow.find_children("*", "Button", true, false):
		plain_words.append((b as Button).text)
	_check(plain_words.has("Import Game") and plain_words.has("Manage Games") and not plain_words.has("Export Game") and not plain_words.has("See all games"), "the plain Game Options window has the same two")
	var r2: Dictionary = gow.ImportBytes(text.to_utf8_buffer(), "Bravo.fwsave")
	_check(r2["ok"] and r2["name"] == "Bravo (3)", "and imports")
	gow.queue_free()
	var plain_all: Control = AllPlain.new()
	root.add_child(plain_all)
	await process_frame
	_check(plain_all._rows.size() == SaveManager.Games().size(), "the plain Manage Games lists every game")
	plain_all.queue_free()
	_finish()


func _write_art() -> void:
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["screens", "buttons", "windows"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	# The Game Options picture: grey, with a lighter band where the sixth row is.
	var opt := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	opt.fill(Color(0.3, 0.3, 0.3))
	opt.fill_rect(Rect2i(23, 284, 314, 34), Color(0.8, 0.2, 0.2))
	opt.save_png("%s/screens/options.png" % dir)
	# A multiplayer screen, for its wires and clamps: yellow.
	_png("%s/screens/mp_connection.png" % dir, 640, 480, Color(1, 1, 0))
	for b in ["options_save", "options_load", "options_restart", "options_return", "options_exit", "msgindex_delete", "mp_back", "mp_next", "mp_cancel"]:
		_png("%s/buttons/%s.png" % [dir, b], 42, 20, Color(0.6, 0.6, 0.6))
		_png("%s/buttons/%s.disabled.png" % [dir, b], 42, 20, Color(0.2, 0.2, 0.2))
	for w in ["options_side.empire", "options_side.alliance", "options_side.h2h", "options_music.lit", "options_music.off", "options_light.off", "options_knob"]:
		_png("%s/windows/%s.png" % [dir, w], 26, 19, Color(0.9, 0.1, 0.1))
	_png("%s/windows/mp_choice.png" % dir, 152, 33, Color(0.25, 0.25, 0.25))
	_png("%s/windows/mp_choice.chosen.png" % dir, 152, 33, Color(0.5, 0.1, 0.1))
	_png("%s/windows/dialog_plate1.png" % dir, 412, 176, Color(0.4, 0.4, 0.4))
	_png("%s/windows/dialog_plate2.png" % dir, 412, 176, Color(0.4, 0.4, 0.4))
	for b in ["dialog_ok", "dialog_cancel"]:
		_png("%s/buttons/%s.png" % [dir, b], 57, 28, Color(0.5, 0.5, 0.5))
		_png("%s/buttons/%s.pressed.png" % [dir, b], 57, 28, Color(0.3, 0.3, 0.3))


func _finish() -> void:
	_remove(Art.UserArtRoot)
	_remove(SaveManager.Dir)
	DirAccess.remove_absolute(MusicLib.SettingsFile)
	MusicLib.SettingsFile = MusicLib.SETTINGS
	MusicLib._loaded = false
	Art.Reset()
	SavedArt.Reset()
	print("[saved_games_screen] %d checks, %d failed" % [_checks, _fails])
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
