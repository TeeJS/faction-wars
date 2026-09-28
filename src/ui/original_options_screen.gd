extends Control
## THE GAME OPTIONS SCREEN (manual p075-p076, Fig. 3.16), rebuilt from the
## original's own screen (COMMON.DLL 20002) with its parts at the places
## measured by template matching on TeeJ's screenshot of the original's
## (2026-09-23). It replaces the Game Menu and the Save Game window, which
## were two plain windows (TeeJ: "should be combined and match the original"):
##   Save Game / Load Game - rows, each "a Save Game button, a name
##     field, and a Load Game button", and "an icon between the name field and
##     the Save Game button [showing] whether you were playing the Empire, the
##     Alliance, or a head-to-head game". Loading over a running game asks
##     first ("the computer asks you to confirm"). The rows are the NEWEST
##     saved games (PROJECT.md, TeeJ 2026-09-27, departing from p075's six
##     fixed slots): a name is a game - Save with the name unchanged overwrites
##     it, a new name makes a new game - and hovering a row shows
##     "Saved MM/DD/YYYY - Day N". Five rows; in the sixth's place Import
##     Game, Export Game and See all games - the multiplayer screens' choice
##     boxes, words in green (saved_games_art.gd; See all games is
##     original_all_games_screen.gd);
##   Sound options - Play Music and the music volume (the original's score,
##     docs/music-plan.md), and the sound effects volume (the droids' voices
##     and the controls' sounds, docs/advisor-plan.md). The Tactical Display
##     options are greyed: there is no tactical view (BACKLOG);
##   Restart the game ("abandons the current game and starts over in the
##     Shuttle ... asks you to confirm"), Return to the Command Center
##     ("unavailable if you come to this screen from the Shuttle Cockpit"),
##     and Exit the game ("asks you to confirm that you want to quit").
## Reached from the Menu button and F1 in play, and from the Cockpit's Load
## icon (p075: "from the Load a Saved Game icon in the Shuttle Cockpit"). The
## original's screen fills the game's window; this one fills ours, the
## picture's aspect kept, like the Cockpit. Only with the art imported: the
## plain windows stay otherwise.
##
## Preloaded by path: a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const MusicLib := preload("res://src/ui/music.gd")
const SoundLib := preload("res://src/ui/sound.gd")
const Picker := preload("res://src/ui/pack_picker.gd")
const SavedArt := preload("res://src/ui/saved_games_art.gd")
const SaveFiles := preload("res://src/ui/save_files.gd")
const AllGames := preload("res://src/ui/original_all_games_screen.gd")
const AllGamesPlain := preload("res://src/ui/all_games_window.gd")

const W := 640
const H := 480
## Each slot's row: the Save Game button at x 34, the side icon at 85, the
## name field from 116 to 281 (its text from x 120, Arial 13, white), the
## Load Game button at 287; the first row at y 81, a row every 42.
const SlotTop := 81
const SlotPitch := 42
## The rows: five of the six the picture draws (TeeJ, 2026-09-27); the sixth
## is painted over for the three boxes below.
const Rows := 5
const SaveX := 34
const SideX := 85
const NameRect := Rect2(116, 0, 165, 20)
const LoadX := 287
## The headings, the Play Music line and the toggles: Arial bold 14.5
## (measured widths), green (0, 255, 0) - dim (0, 128, 0) when off.
const HeadPx := 14.5
const Green := Color(0, 1, 0)
const DimGreen := Color(0, 128 / 255.0, 0)
const Greyed := Color(0.42, 0.42, 0.42)
## Each heading's text, centre x, cap top, and whether its section works yet:
## the two that do not are greyed with their options (TeeJ, 2026-09-24).
const Headings := [["Saved Games", 177.5, 41, true], ["Sound Options", 481.5, 41, true], ["Tactical Display Options", 482, 277, false]]
const MusicSwitchAt := Vector2(352, 76)
const MusicLabelAt := Vector2(377, 89)
const StateRight := 602.0
## The volume knobs (11x47) slide on tracks from x 393 to 581: music at y 134,
## sound effects at y 194.
const KnobYs := [134, 194]
const KnobX := 393
## How far a knob's left edge travels: the track's 188 pixels less its width.
const KnobTravel := 581 - 393 - 11
const Toggles := ["Show Starfield", "Show Planet", "Show Pyrotechnics", "Use High Detail Models", "Display Holocube"]
const ToggleTop := 311
const TogglePitch := 27
const LightX := 357
const ToggleLabelX := 395
const ToggleStateRight := 596.0
## Import Game, Export Game, See all games: the choice box cut to 96 x 33, three
## across the Saved Games panel where the sixth row was; the words centred,
## capitals 11 below the box's top (as the multiplayer screens place theirs),
## Arial 11.5 - the original's 12.5 would not fit "See all games" between the
## box's brackets.
const Bars := ["Import Game", "Export Game", "See all games"]
const BarTop := 293
const BarSize := Vector2(96, 33)
const BarX := [33, 135, 237]
const BarPx := 11.5
const Red := Color(1, 0, 0)
## The alert box with one socket (REBDLOG): the check at (176, 134), the words
## white Arial bold 13, centred, capitals from y 63 (the pause box's).
const NoteText := Color(1, 251 / 255.0, 240 / 255.0)
## Restart, Return to the Command Center, Exit (42x42).
const ButtonAt := [Vector2(76, 381), Vector2(162, 382), Vector2(248, 381)]
## "Version: ...", Arial 11, black, centred on x 179.
const VersionCentre := Vector2(179, 442)

## Opened from the Shuttle Cockpit: no game to return to or save.
var FromCockpit: bool = false

var _s: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _canvas: Control
var _names: Array = []
var _saveBtns: Array = []
var _loadBtns: Array = []
var _sideIcons: Array = []
## Each row's saved game id ("" for an empty row), newest first.
var _rowIds: Array = []
var _bars: Array = []
var _barWords: Array = []


## True when the player imported the art this screen is made of.
static func CanBuild() -> bool:
	return Art.Screen("options") != null and Art.ButtonIcon("options_save") != null \
		and Art.WindowPicture("options_side.empire") != null \
		and Art.WindowPicture("mp_choice") != null and Art.WindowPicture("mp_choice.chosen") != null


func _ready() -> void:
	name = "OptionsScreen"
	# The whole screen, so its black and its click-stop cover the sides too:
	# under a CanvasLayer the anchors alone left it 0x0, and a click beside
	# the picture reached the sector column - a sector opened over the screen
	# (TeeJ, 2026-09-25).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.name = "Back"
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_build()
	resized.connect(_rebuild)
	# The clock stops while the screen is up; head-to-head, the opponent is
	# told to wait (manual p163).
	# The game is the ancestor that runs the clock (Main.tscn's GameManager).
	var gm: Node = get_parent()
	while gm != null and not gm.has_method("MenuOpened"):
		gm = gm.get_parent()
	if not FromCockpit and gm != null:
		gm.MenuOpened(true)
		tree_exiting.connect(func() -> void:
			if is_instance_valid(gm):
				gm.MenuOpened(false))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if FromCockpit:
			queue_free()
		else:
			_return()


func _rebuild() -> void:
	for c in _canvas.get_children():
		_canvas.remove_child(c)
		c.queue_free()
	_build()


func _build() -> void:
	var view: Vector2 = size if size.x > 0 else get_viewport_rect().size
	_s = minf(view.x / W, view.y / H)
	_origin = ((view - Vector2(W, H) * _s) / 2.0).floor()
	_canvas.position = _origin
	_place(SavedArt.OptionsPlate(), 0, 0, "Plate")
	for h in Headings:
		var head := _text(h[0], h[1] - 150, h[2], 300, HeadPx, Green if h[3] else Greyed, HORIZONTAL_ALIGNMENT_CENTER, true, "Head_" + str(h[0]).replace(" ", ""))
		if not h[3]:
			head.tooltip_text = "Not in this game yet."

	# ---- Save Game / Load Game ------------------------------------------------
	_names.clear()
	_saveBtns.clear()
	_loadBtns.clear()
	_sideIcons.clear()
	var playing: bool = not FromCockpit
	var session: Variant = MpSetup.session
	for k in Rows:
		var y: float = SlotTop + k * SlotPitch
		var save := _button("options_save", SaveX, y, "Save the game under this name")
		var slot := k
		save.pressed.connect(func() -> void: _save(slot))
		_saveBtns.append(save)
		var side := _place(null, SideX, y + 2, "Side%d" % k)
		side.mouse_filter = Control.MOUSE_FILTER_PASS   # its hover shows the saved date
		_sideIcons.append(side)
		var field := LineEdit.new()
		field.name = "Name%d" % k
		field.position = (Vector2(NameRect.position.x, y + NameRect.position.y)) * _s
		field.size = NameRect.size * _s
		field.max_length = 40
		field.placeholder_text = ""
		field.add_theme_font_override("font", OUI.Face(false))
		field.add_theme_font_size_override("font_size", roundi(13 * _s))
		field.add_theme_color_override("font_color", Color.WHITE)
		field.add_theme_color_override("caret_color", Color.WHITE)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 2 * _s   # the text from x 120 (measured)
		for st in ["normal", "focus", "read_only"]:
			field.add_theme_stylebox_override(st, empty)
		field.tooltip_text = "Click here and type a name, then Save"
		_canvas.add_child(field)
		_names.append(field)
		var load := _button("options_load", LoadX, y, "Load this game")
		load.pressed.connect(func() -> void: _load(slot))
		_loadBtns.append(load)
	_refresh_slots()
	if not playing or (session != null and not MpSetup.hosting):
		for b in _saveBtns:
			(b as TextureButton).disabled = true
			(b as TextureButton).tooltip_text = "Only the host can save." if session != null and playing else "No game to save."

	# ---- Import Game, Export Game, See all games (PROJECT.md) -------------------
	_bars.clear()
	_barWords.clear()
	_bar(0, "Bring in a saved game: one of ours (.fwsave) or a Star Wars: Rebellion SAVEGAME file", _import)
	_bar(1, "Save the game you are playing to a file", _export)
	_bar(2, "Every saved game, with its dates, to load, export or delete", _see_all)
	if not playing or session != null:
		_disable_bar(1, "No game to export." if not playing else "A head-to-head game is saved on both computers.")

	# ---- Sound Options: Play Music, the music volume (docs/music-plan.md) and
	# the sound effects volume - the droids' voices and the controls' sounds
	# (docs/advisor-plan.md) ------------------------------------------------
	var not_yet := "Not in this game yet."
	MusicLib.Load()
	SoundLib.Load()
	var on: bool = MusicLib.PlayMusic
	var sw := _place(Art.WindowPicture("options_music.lit" if on else "options_music.off"), MusicSwitchAt.x, MusicSwitchAt.y, "MusicSwitch")
	sw.tooltip_text = "Play Music"
	sw.mouse_filter = Control.MOUSE_FILTER_STOP
	sw.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			MusicLib.SetPlayMusic(not MusicLib.PlayMusic)
			_rebuild())
	var music := _text("Play Music", MusicLabelAt.x, MusicLabelAt.y, 150, HeadPx, Green if on else DimGreen, HORIZONTAL_ALIGNMENT_LEFT, true, "MusicLabel")
	music.tooltip_text = "Play Music"
	_text("On" if on else "Off", StateRight - 60, MusicLabelAt.y, 60, HeadPx, Green if on else DimGreen, HORIZONTAL_ALIGNMENT_RIGHT, true, "MusicState")
	for i in KnobYs.size():
		var knob := _place(Art.WindowPicture("options_knob"), KnobX, KnobYs[i], ["MusicKnob", "EffectsKnob"][i])
		# Each knob slides along its track: left quiet, right full.
		var effects: bool = i == 1
		knob.position.x = (KnobX + (SoundLib.Volume if effects else MusicLib.Volume) * KnobTravel) * _s
		knob.tooltip_text = "Sound effects volume" if effects else "Music volume"
		knob.mouse_filter = Control.MOUSE_FILTER_STOP
		knob.gui_input.connect(func(e: InputEvent) -> void: _drag_knob(knob, e, effects))
	for i in Toggles.size():
		var y: float = ToggleTop + i * TogglePitch
		var light := _place(Art.WindowPicture("options_light.off"), LightX, y, "Light%d" % i)
		light.tooltip_text = not_yet
		light.mouse_filter = Control.MOUSE_FILTER_PASS
		# The manual's defaults ("default to on"), greyed.
		var label := _text(Toggles[i], ToggleLabelX, y + 5, 180, HeadPx, Greyed, HORIZONTAL_ALIGNMENT_LEFT, true, "Toggle%d" % i)
		label.tooltip_text = not_yet
		_text("On", ToggleStateRight - 40, y + 5, 40, HeadPx, Greyed, HORIZONTAL_ALIGNMENT_RIGHT, true, "ToggleState%d" % i)

	# ---- Restart, Return, Exit ------------------------------------------------
	var restart := _button("options_restart", ButtonAt[0].x, ButtonAt[0].y, "Restart the game")
	restart.pressed.connect(_restart)
	var ret := _button("options_return", ButtonAt[1].x, ButtonAt[1].y, "Return to the Command Center")
	ret.pressed.connect(_return)
	ret.disabled = FromCockpit
	var exit := _button("options_exit", ButtonAt[2].x, ButtonAt[2].y, "Exit the game")
	exit.pressed.connect(_exit)
	_text("Version: %s" % BuildInfo.version(), VersionCentre.x - 150, VersionCentre.y, 300, 11, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false, "Version")


## The music knob follows the mouse along its track while held; the volume
## follows the knob.
func _drag_knob(knob: Control, e: InputEvent, effects: bool = false) -> void:
	var drag: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) \
		or (e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if not drag:
		return
	# The mouse on the canvas (the event is the knob's own), held by the knob's middle.
	var x: float = (knob.position.x + (e as InputEventMouse).position.x) / _s - KnobX - 5.5
	var v: float = clampf(x / KnobTravel, 0.0, 1.0)
	if effects:
		SoundLib.SetVolume(v)
	else:
		MusicLib.SetVolume(v)
	knob.position.x = (KnobX + v * KnobTravel) * _s
	knob.accept_event()


## Fill the rows with the newest saved games, newest at the top.
func _refresh_slots() -> void:
	var games: Array = SaveManager.Recent(_names.size())
	_rowIds.clear()
	for k in _names.size():
		var used: bool = k < games.size()
		var g: Dictionary = games[k] if used else {}
		_rowIds.append(str(g["id"]) if used else "")
		var field: LineEdit = _names[k]
		field.text = str(g["name"]) if used else ""
		var tip: String = SaveManager.SavedLabel(g) if used else "Click here and type a name, then Save"
		field.tooltip_text = tip
		(_loadBtns[k] as TextureButton).disabled = not used or (MpSetup.session != null)
		var icon: Texture2D = _side_icon(str(g.get("side", ""))) if used else null
		var rect: TextureRect = _sideIcons[k]
		rect.texture = icon
		rect.size = icon.get_size() * _s if icon != null else Vector2.ZERO
		rect.tooltip_text = tip if used else ""


## The slot's side: the Empire's, the Alliance's (a faction's art skin), or
## head-to-head.
static func _side_icon(side: String) -> Texture2D:
	if side.is_empty():
		return null
	if side == "h2h":
		return Art.WindowPicture("options_side.h2h")
	var f: Faction = FactionRegistry.ById(side)
	var skin: String = f.ArtSkin if f != null else side
	return Art.WindowPicture("options_side.%s" % skin)


# ---- the orders ----------------------------------------------------------------

## Public so a test can drive it without a real button press.
func _save(slot: int) -> void:
	# The name is the game: unchanged, the row's game is overwritten; a new
	# name makes a new game. A cleared name means the row's own (or, on an
	# empty row, the next free "Saved game").
	var nm: String = (_names[slot] as LineEdit).text.strip_edges()
	if nm.is_empty():
		nm = SaveManager.NameOf(_rowIds[slot])
	SaveNamed(nm)


## Save the game being played under `nm` (a taken name overwrites that game);
## the rows follow. Shared with See all games. Returns the game's id, or "".
func SaveNamed(nm: String) -> String:
	if FromCockpit:
		return ""
	if MpSetup.session != null:
		if MpSetup.hosting:
			_tell("Save Game", "Saved on both computers: \"%s\", Day %d." % [MpSetup.lobby.name if MpSetup.lobby != null else "this game", StrategicTickManager.Shown(StrategicTickManager.Today)])
		return ""
	var id: String = SaveManager.Save(nm)   # an empty name takes the next free "Saved game"
	_refresh_slots()
	return id


func _load(slot: int) -> void:
	LoadGame(_rowIds[slot] if slot < _rowIds.size() else "")


## Load saved game `id`, asking first over a running game. Shared with See all games.
func LoadGame(id: String) -> void:
	if not SaveManager.Exists(id):
		return
	var go := func() -> void:
		MpSetup.reset()
		GameSettings.PendingLoadPath = SaveManager.GamePath(id)
		get_tree().change_scene_to_file("res://Main.tscn")
	if FromCockpit:
		go.call()
		return
	# "If you try to load a game without saving the current game first, the
	# computer asks you to confirm that this is what you want to do."
	# The original's words (REBDLOG.DLL).
	_confirm("Load Game", "Loading the selected game will destroy unsaved changes", go, "Load without saving?")


## Import Game: a file dialog; the game comes in on top of the list, its Saved
## date today, overwriting nothing (SaveManager.Import tells ours from the
## original's). Public so a test can hand it a file without the dialog.
func _import() -> void:
	SaveFiles.Pick(ImportBytes)


func ImportBytes(bytes: PackedByteArray, file_name: String) -> Dictionary:
	var r: Dictionary = SaveManager.Import(bytes, file_name)
	_refresh_slots()
	var all: Node = get_node_or_null("AllGames")
	if all != null:
		all.Refresh()
	_note(("\"%s\" is in your saved games." % r["name"]) if r["ok"] else str(r["message"]))
	return r


## Export Game: the game being played, as a .fwsave file.
func _export() -> void:
	if FromCockpit or MpSetup.session != null:
		return
	var nm: String = SaveManager.CurrentName()
	var text: String = SaveManager.ExportCurrentText(nm)
	if text.is_empty():
		_note("There is no game to export.")
		return
	SaveFiles.Save(text, SaveManager.FileNameFor(nm), _exported)


## Export a saved game from See all games.
func ExportGame(id: String) -> void:
	var text: String = SaveManager.ExportText(id)
	if not text.is_empty():
		SaveFiles.Save(text, SaveManager.ExportFileName(id), _exported)


func _exported(ok: bool, where: String) -> void:
	_note(("Saved to %s." % where.get_file()) if ok else "The game could not be exported.")


## See all games: over this screen, back to it when closed.
func _see_all() -> void:
	if get_node_or_null("AllGames") != null or get_node_or_null("AllGamesWindow") != null:
		return
	if not AllGames.CanBuild():
		# An art set without the multiplayer screens' boxes: the plain window.
		var plain: Control = AllGamesPlain.new()
		plain.InGame = not FromCockpit
		add_child(plain)
		plain.Closed.connect(_refresh_slots)
		return
	var all: Control = AllGames.new()
	all.Host = self
	add_child(all)


## A line in the original's alert box with one socket (REBDLOG's plate, the
## check), over a shade that takes every other click.
func _note(text: String) -> void:
	var plate: Texture2D = OUI.Pic("dialog_plate1")
	if plate == null or Art.ButtonIcon("dialog_ok") == null:
		_tell("Saved Games", text)
		return
	var shade := Control.new()
	shade.name = "Note"
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := Control.new()
	box.name = "Box"
	box.size = plate.get_size()
	box.position = ((get_viewport_rect().size - box.size) / 2.0).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(box)
	OUI.Place(box, plate, 0, 0, "Plate")
	var words := OUI.Text(box, text, 30, 40, 352, 60, 13, NoteText, HORIZONTAL_ALIGNMENT_CENTER, true, "Text")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	OUI.PictureButton(box, "dialog_ok", 176, 134, "OK").pressed.connect(shade.queue_free)


## One of Import Game / Export Game / See all games: the choice box, its words
## green, red while it is pressed (the original's colour for a chosen box).
func _bar(i: int, tip: String, act: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Bar_" + str(Bars[i]).replace(" ", "")
	b.texture_normal = SavedArt.Box(Vector2i(BarSize), false)
	b.texture_pressed = SavedArt.Box(Vector2i(BarSize), true)
	b.texture_disabled = b.texture_normal
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = Vector2(BarX[i], BarTop) * _s
	b.size = BarSize * _s
	b.tooltip_text = tip
	_canvas.add_child(b)
	var words := _text(Bars[i], BarX[i], BarTop + 11, BarSize.x, BarPx, Green, HORIZONTAL_ALIGNMENT_CENTER, false, "BarText%d" % i)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.button_down.connect(func() -> void: words.add_theme_color_override("font_color", Red))
	b.button_up.connect(func() -> void: words.add_theme_color_override("font_color", Greyed if b.disabled else Green))
	b.pressed.connect(act)
	_bars.append(b)
	_barWords.append(words)
	return b


func _disable_bar(i: int, tip: String) -> void:
	(_bars[i] as TextureButton).disabled = true
	(_bars[i] as TextureButton).tooltip_text = tip
	(_barWords[i] as Label).add_theme_color_override("font_color", Greyed)


func _restart() -> void:
	if FromCockpit:
		queue_free()   # already in the Shuttle
		return
	# The original's words (TeeJ's screenshot, 2026-09-25; REBDLOG.DLL).
	_confirm("Restart the Game", "Returning to the shuttle cockpit will cause unsaved changes to be lost", func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn"), "Return without saving?")


func _return() -> void:
	if FromCockpit:
		return
	queue_free()


func _exit() -> void:
	# The original's words (REBDLOG.DLL); the question's own place in the box.
	_confirm("Exit the Game", "", func() -> void:
		MpSetup.reset()
		# A browser tab has no desktop to exit to: back to the pack picker,
		# as the Cockpit's Exit does (TeeJ, room #97).
		if OS.has_feature("web"):
			Picker.ExitToPicker(get_tree())
		else:
			get_tree().quit(), "Are you sure you want to quit?")


## A question, in the original's alert box when its pictures are imported
## (TeeJ, 2026-09-25: "we need this menu to match the original", with his
## screenshot of the original's "Return without saving?"): REBDLOG's plate with
## two button sockets, over a shade that takes every other click; the message
## centred on its panel in white Arial bold 13, capitals from y 28, lines 16
## apart, the question under it (capitals at y 87); the check at (138,135) and
## the X at (229,135) - both matched to the pixel. No title: the original's
## box has none.
const ConfirmText := Color(1, 1, 1)


func _confirm(title: String, text: String, yes: Callable, question: String = "") -> void:
	if OUI.Pic("dialog_plate2") == null or Art.ButtonIcon("dialog_ok") == null or Art.ButtonIcon("dialog_cancel") == null:
		var parts: Array = [text, question].filter(func(s: String) -> bool: return not s.is_empty())
		_confirm_plain(title, "\n\n".join(PackedStringArray(parts)), yes)
		return
	var shade := Control.new()
	shade.name = "Confirm"
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # the screen's whole size (#222)
	var plate: Texture2D = OUI.Pic("dialog_plate2")
	var box := Control.new()
	box.name = "Box"
	box.size = plate.get_size()
	box.position = ((get_viewport_rect().size - box.size) / 2.0).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(box)
	OUI.Place(box, plate, 0, 0, "Plate")
	var words := OUI.Text(box, text, 40, 25.5, 332, 40, 13, ConfirmText, HORIZONTAL_ALIGNMENT_CENTER, true, "Text")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	OUI.LinePitch(words, 13, 16, true)
	if not question.is_empty():
		OUI.Text(box, question, 0, 84.5, 412, 18, 13, ConfirmText, HORIZONTAL_ALIGNMENT_CENTER, true, "Question")
	OUI.PictureButton(box, "dialog_ok", 138, 135, "Yes").pressed.connect(func() -> void:
		shade.queue_free()
		yes.call())
	OUI.PictureButton(box, "dialog_cancel", 229, 135, "No").pressed.connect(shade.queue_free)


func _confirm_plain(title: String, text: String, yes: Callable) -> void:
	var box := ConfirmationDialog.new()
	box.name = "Confirm"
	box.title = title
	box.dialog_text = text
	box.exclusive = true
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(func() -> void:
		box.queue_free()
		yes.call())
	box.canceled.connect(box.queue_free)


func _tell(title: String, text: String) -> void:
	var box := AcceptDialog.new()
	box.title = title
	box.dialog_text = text
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(box.queue_free)


# ---- drawing, in the original's pixels -----------------------------------------

func _place(tex: Texture2D, x: float, y: float, node_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2(x, y) * _s
	r.size = tex.get_size() * _s if tex != null else Vector2.ZERO
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(r)
	return r


func _button(pic: String, x: float, y: float, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = "%s_%d_%d" % [pic, int(x), int(y)]
	b.texture_normal = Art.ButtonIcon(pic)
	b.texture_pressed = Art.ButtonIcon(pic, "pressed")
	b.texture_disabled = Art.ButtonIcon(pic, "disabled")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = Vector2(x, y) * _s
	b.size = b.texture_normal.get_size() * _s if b.texture_normal != null else Vector2(42, 20) * _s
	b.tooltip_text = tip
	_canvas.add_child(b)
	return b


## A line of text whose capital letters start at `cap_top` (Arial's caps sit
## 0.19 of the size below the top of its line).
func _text(t: String, x: float, cap_top: float, w: float, px: float, color: Color,
		align: HorizontalAlignment, bold: bool, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = t
	l.position = Vector2(x, cap_top - 0.19 * px) * _s
	l.size = Vector2(w, px * 1.4) * _s
	l.horizontal_alignment = align
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_override("font", OUI.Face(bold))
	l.add_theme_font_size_override("font_size", roundi(px * _s))
	l.add_theme_color_override("font_color", color)
	_canvas.add_child(l)
	return l
