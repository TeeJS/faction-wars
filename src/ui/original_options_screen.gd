extends Control
## THE GAME OPTIONS SCREEN (manual p075-p076, Fig. 3.16), rebuilt from the
## original's own screen (COMMON.DLL 20002) with its parts at the places
## measured by template matching on TeeJ's screenshot of the original's
## (2026-09-23). It replaces the Game Menu and the Save Game window, which
## were two plain windows (TeeJ: "should be combined and match the original"):
##   Save Game / Load Game - six slots, each "a Save Game button, a name
##     field, and a Load Game button", and "an icon between the name field and
##     the Save Game button [showing] whether you were playing the Empire, the
##     Alliance, or a head-to-head game". Loading over a running game asks
##     first ("the computer asks you to confirm");
##   Sound options (Play Music, the music and sound effects volumes) and the
##     Tactical Display options - NOT IN THIS GAME YET: there is no sound and
##     no tactical view. Drawn greyed, as TeeJ asked (BACKLOG);
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
const Picker := preload("res://src/ui/pack_picker.gd")

const W := 640
const H := 480
## Each slot's row: the Save Game button at x 34, the side icon at 85, the
## name field from 116 to 281 (its text from x 120, Arial 13, white), the
## Load Game button at 287; the first row at y 81, a row every 42.
const SlotTop := 81
const SlotPitch := 42
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
const Headings := [["Saved Games", 177.5, 41], ["Sound Options", 481.5, 41], ["Tactical Display Options", 482, 277]]
const MusicSwitchAt := Vector2(352, 76)
const MusicLabelAt := Vector2(377, 89)
const StateRight := 602.0
## The volume knobs (11x47) slide on tracks from x 393 to 581: music at y 134,
## sound effects at y 194.
const KnobYs := [134, 194]
const KnobX := 393
const Toggles := ["Show Starfield", "Show Planet", "Show Pyrotechnics", "Use High Detail Models", "Display Holocube"]
const ToggleTop := 311
const TogglePitch := 27
const LightX := 357
const ToggleLabelX := 395
const ToggleStateRight := 596.0
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


## True when the player imported the art this screen is made of.
static func CanBuild() -> bool:
	return Art.Screen("options") != null and Art.ButtonIcon("options_save") != null \
		and Art.WindowPicture("options_side.empire") != null


func _ready() -> void:
	name = "OptionsScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_place(Art.Screen("options"), 0, 0, "Plate")
	for h in Headings:
		_text(h[0], h[1] - 150, h[2], 300, HeadPx, Green, HORIZONTAL_ALIGNMENT_CENTER, true, "Head_" + str(h[0]).replace(" ", ""))

	# ---- Save Game / Load Game ------------------------------------------------
	_names.clear()
	_saveBtns.clear()
	_loadBtns.clear()
	_sideIcons.clear()
	var playing: bool = not FromCockpit
	var session: Variant = MpSetup.session
	for k in SaveManager.SLOT_COUNT:
		var y: float = SlotTop + k * SlotPitch
		var save := _button("options_save", SaveX, y, "Save the game in this slot")
		var slot := k
		save.pressed.connect(func() -> void: _save(slot))
		_saveBtns.append(save)
		_sideIcons.append(_place(null, SideX, y + 2, "Side%d" % k))
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
		var load := _button("options_load", LoadX, y, "Load the game in this slot")
		load.pressed.connect(func() -> void: _load(slot))
		_loadBtns.append(load)
	_refresh_slots()
	if not playing or (session != null and not MpSetup.hosting):
		for b in _saveBtns:
			(b as TextureButton).disabled = true
			(b as TextureButton).tooltip_text = "Only the host can save." if session != null and playing else "No game to save."

	# ---- Sound Options and Tactical Display Options: not in this game yet ------
	var not_yet := "Not in this game yet."
	var sw := _place(Art.WindowPicture("options_music.grey"), MusicSwitchAt.x, MusicSwitchAt.y, "MusicSwitch")
	sw.tooltip_text = not_yet
	sw.mouse_filter = Control.MOUSE_FILTER_PASS
	var music := _text("Play Music", MusicLabelAt.x, MusicLabelAt.y, 150, HeadPx, Greyed, HORIZONTAL_ALIGNMENT_LEFT, true, "MusicLabel")
	music.tooltip_text = not_yet
	_text("Off", StateRight - 60, MusicLabelAt.y, 60, HeadPx, Greyed, HORIZONTAL_ALIGNMENT_RIGHT, true, "MusicState")
	for i in KnobYs.size():
		var knob := _place(Art.WindowPicture("options_knob"), KnobX, KnobYs[i], ["MusicKnob", "EffectsKnob"][i])
		knob.modulate = Color(0.55, 0.55, 0.55)
		knob.tooltip_text = not_yet
		knob.mouse_filter = Control.MOUSE_FILTER_PASS
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


func _refresh_slots() -> void:
	var slots: Array = SaveManager.Slots()
	for k in slots.size():
		if k >= _names.size():
			break
		var s: Dictionary = slots[k]
		var field: LineEdit = _names[k]
		if s["used"] and field.text.is_empty():
			field.text = str(s["name"])
		field.tooltip_text = ("%s - Day %d" % [s["name"], int(s["day"])]) if s["used"] else "Click here and type a name, then Save"
		(_loadBtns[k] as TextureButton).disabled = not s["used"] or (MpSetup.session != null)
		var icon: Texture2D = _side_icon(str(s.get("side", ""))) if s["used"] else null
		var rect: TextureRect = _sideIcons[k]
		rect.texture = icon
		rect.size = icon.get_size() * _s if icon != null else Vector2.ZERO


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
	if FromCockpit:
		return
	if MpSetup.session != null:
		if MpSetup.hosting:
			_tell("Save Game", "Saved on both computers: \"%s\", Day %d." % [MpSetup.lobby.name if MpSetup.lobby != null else "this game", StrategicTickManager.Today])
		return
	var nm: String = (_names[slot] as LineEdit).text.strip_edges()
	if nm.is_empty():
		nm = "Saved game"
		(_names[slot] as LineEdit).text = nm
	SaveManager.Save(slot, nm)
	_refresh_slots()


func _load(slot: int) -> void:
	if not SaveManager.IsUsed(slot):
		return
	var go := func() -> void:
		MpSetup.reset()
		GameSettings.PendingLoadPath = SaveManager.SlotPath(slot)
		get_tree().change_scene_to_file("res://Main.tscn")
	if FromCockpit:
		go.call()
		return
	# "If you try to load a game without saving the current game first, the
	# computer asks you to confirm that this is what you want to do."
	_confirm("Load Game", "Load \"%s\"? The game you are playing is lost unless you have saved it." % str(SaveManager.Slots()[slot]["name"]), go)


func _restart() -> void:
	if FromCockpit:
		queue_free()   # already in the Shuttle
		return
	_confirm("Restart the Game", "Abandon this game and start over in the Shuttle?", func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn"))


func _return() -> void:
	if FromCockpit:
		return
	queue_free()


func _exit() -> void:
	_confirm("Exit the Game", "Do you want to quit?", func() -> void:
		MpSetup.reset()
		# A browser tab has no desktop to exit to: back to the pack picker,
		# as the Cockpit's Exit does (TeeJ, room #97).
		if OS.has_feature("web"):
			Picker.ExitToPicker(get_tree())
		else:
			get_tree().quit())


func _confirm(title: String, text: String, yes: Callable) -> void:
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
