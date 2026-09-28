extends Control
## SEE ALL GAMES (PROJECT.md, TeeJ 2026-09-27): every saved game, newest first,
## on a screen made from the Game Options picture - its Saved Games panel
## widened across the whole frame and its rows rebuilt from that panel's own
## row sockets (saved_games_art.gd), so it reads as part of the original. A row,
## left to right:
##   Save Game | side icon | name | Load Game | Export | Saved MM/DD/YYYY | Day N | Delete
## Save Game and Load Game do what they do on the Saved Games rows (the name is
## the game); Export writes the game to a file; Delete asks first, in the
## original's alert box, then removes it. Eight rows a page; the multiplayer
## screens' arrow boxes turn the pages (the mouse wheel too), their X box
## closes it. Opened by See all games, over the Game Options screen (Host),
## whose orders it shares.
##
## Preloaded by path: a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const SavedArt := preload("res://src/ui/saved_games_art.gd")

const W := 640
const H := 480
const Rows := 8
const RowTop := 81
const RowPitch := 42
## Each column's socket: [kind, x, width] (saved_games_art.gd cuts them from
## the Saved Games row): the Save Game socket, the side icon's, the name field,
## a square socket for Load Game, one for Export, two fields for the dates,
## and the rounded Load Game socket for Delete.
const Columns := [["save", 30, 48], ["side", 78, 35], ["name", 113, 172], ["side", 285, 47],
	["side", 332, 62], ["name", 394, 80], ["name", 474, 66], ["load", 540, 66]]
## Where each row's parts sit (x, and the row top's offset): the buttons as on
## the Saved Games rows (Save Game at 34, the icon at 85 + 2, the name from 116
## with its text from 120, Arial 13, white).
const SaveX := 34
const SideX := 85
const NameRect := Rect2(116, 0, 165, 20)
const LoadX := 288
const ExportRect := Rect2(336, 1, 54, 19)
const DateRect := Rect2(398, 0, 72, 20)
const DayRect := Rect2(478, 0, 58, 20)
const DeleteX := 544
## The heading bar: the title over the rows' left part, the two date columns'
## headings over theirs - green Arial bold 14.5, capitals at y 41 (the Saved
## Games heading's).
const HeadTop := 41
const HeadPx := 14.5
const Title := ["All Saved Games", 181.0]
const ColumnHeads := [["Saved", 434.0], ["Day", 507.0]]
## The page boxes (the multiplayer screens' 89 x 26): back and next, the page
## between them, and the X to close; capitals of the page line at 422.
const BackAt := Vector2(40, 414)
const NextAt := Vector2(232, 414)
const PageCentre := 180.5
const CloseAt := Vector2(510, 414)
## ...on the multiplayer screens' wires, as their boxes sit there (TeeJ,
## 2026-09-28: "this screen is missing the greeblies as well"): the wires
## through the boxes' middle across the panel, a clamp at each end and each
## side of the stretch between Next and X (3 pixels off the boxes, as the
## original's), and the page line in a name socket 78 wide on the wires.
const FootClamps := [33.0, 328.0, 503.0, 606.0]
const PageSocket := [141, 78, 418]
const Green := Color(0, 1, 0)
const Red := Color(1, 0, 0)
const Greyed := Color(0.42, 0.42, 0.42)
const TextPx := 13.0
const ExportPx := 11.0

## The Game Options screen this was opened from.
var Host: Control

var _s: float = 1.0
var _canvas: Control
var _page: int = 0
var _games: Array = []
## Per row on the page: { "id", "name": LineEdit, "save", "side", "load", "export", "date", "day", "delete" }.
var _rows: Array = []


## True when the player's art has this screen's parts.
static func CanBuild() -> bool:
	for w in ["mp_choice", "mp_choice.chosen"]:
		if Art.WindowPicture(w) == null:
			return false
	for b in ["mp_back", "mp_next", "mp_cancel", "msgindex_delete", "options_save", "options_load"]:
		if Art.ButtonIcon(b) == null:
			return false
	return Art.Screen("options") != null


func _ready() -> void:
	name = "AllGames"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	resized.connect(_build)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Turn(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Turn(-1)


## Back to the Game Options screen, its rows brought up to date.
func Close() -> void:
	if Host != null and Host.has_method("_refresh_slots"):
		Host._refresh_slots()
	queue_free()


## Read the list again (after a save, an import, a delete) and redraw the page.
func Refresh() -> void:
	_build()


func Pages() -> int:
	return maxi(1, ceili(float(_games.size()) / Rows))


## Turn `by` pages (clamped).
func Turn(by: int) -> void:
	var to: int = clampi(_page + by, 0, Pages() - 1)
	if to != _page:
		_page = to
		_build()


func _build() -> void:
	for c in _canvas.get_children():
		_canvas.remove_child(c)
		c.queue_free()
	_rows.clear()
	var view: Vector2 = size if size.x > 0 else get_viewport_rect().size
	_s = minf(view.x / W, view.y / H)
	_canvas.position = ((view - Vector2(W, H) * _s) / 2.0).floor()
	_games = SaveManager.Games()
	_page = clampi(_page, 0, Pages() - 1)
	_place(SavedArt.AllGamesPlate(Rows, RowTop, RowPitch, Columns, [int(BackAt.y) + 13, FootClamps, PageSocket]), 0, 0, "Plate")
	_text(Title[0], Title[1] - 150, HeadTop, 300, HeadPx, Green, HORIZONTAL_ALIGNMENT_CENTER, true, "Title")
	for h in ColumnHeads:
		_text(h[0], h[1] - 50, HeadTop, 100, HeadPx, Green, HORIZONTAL_ALIGNMENT_CENTER, true, "Head_" + str(h[0]))

	var playing: bool = Host != null and not bool(Host.get("FromCockpit"))
	var mp: bool = MpSetup.session != null
	for k in Rows:
		var i: int = _page * Rows + k
		var used: bool = i < _games.size()
		var g: Dictionary = _games[i] if used else {}
		var y: float = RowTop + k * RowPitch
		var row := {"id": str(g.get("id", ""))}
		var save := _button("options_save", SaveX, y, "Save the game under this name", "Save%d" % k)
		save.disabled = not playing or mp
		save.pressed.connect(func() -> void: _save(k))
		row["save"] = save
		var side := _place(Host._side_icon(str(g.get("side", ""))) if used else null, SideX, y + 2, "Side%d" % k)
		side.mouse_filter = Control.MOUSE_FILTER_PASS
		side.tooltip_text = SaveManager.SavedLabel(g) if used else ""
		row["side"] = side
		row["name"] = _field(str(g.get("name", "")), y, k, SaveManager.SavedLabel(g) if used else "Click here and type a name, then Save")
		var load := _button("options_load", LoadX, y, "Load this game", "Load%d" % k)
		load.disabled = not used or mp
		load.pressed.connect(func() -> void: Host.LoadGame(row["id"]))
		row["load"] = load
		row["export"] = _export_box(y, k, used)
		row["date"] = _text(SaveManager.SavedDate(g) if used else "", DateRect.position.x, y + 4, DateRect.size.x, TextPx, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Date%d" % k)
		row["day"] = _text(("Day %d" % StrategicTickManager.Shown(int(g["day"]))) if used else "", DayRect.position.x, y + 4, DayRect.size.x, TextPx, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Day%d" % k)
		var del := _button("msgindex_delete", DeleteX, y, "Delete this saved game", "Delete%d" % k)
		del.disabled = not used
		del.pressed.connect(func() -> void: _delete(row["id"]))
		row["delete"] = del
		_rows.append(row)

	# The pages and the way out.
	var prev := _button("mp_back", BackAt.x, BackAt.y, "The newer games", "Back")
	prev.disabled = _page == 0
	prev.pressed.connect(func() -> void: Turn(-1))
	var next := _button("mp_next", NextAt.x, NextAt.y, "The older games", "Next")
	next.disabled = _page >= Pages() - 1
	next.pressed.connect(func() -> void: Turn(1))
	_text("Page %d of %d" % [_page + 1, Pages()], PageCentre - 50, BackAt.y + 8, 100, TextPx, Green, HORIZONTAL_ALIGNMENT_CENTER, false, "Page")
	var close := _button("mp_cancel", CloseAt.x, CloseAt.y, "Back to the Saved Games", "Close")
	close.pressed.connect(Close)


## Save from row `k`: its name, or the row's own if cleared (the Saved Games rule).
func _save(k: int) -> void:
	var nm: String = (_rows[k]["name"] as LineEdit).text.strip_edges()
	if nm.is_empty():
		nm = SaveManager.NameOf(_rows[k]["id"])
	Host.SaveNamed(nm)
	_page = 0   # the saved game is the newest: on the first page
	_build()


func _delete(id: String) -> void:
	if not SaveManager.Exists(id):
		return
	var nm: String = SaveManager.NameOf(id)
	Host._confirm("Delete", "\"%s\" will be gone for good." % nm, func() -> void:
		SaveManager.Delete(id)
		_build(), "Delete this saved game?")


## Export, as a small choice box with its word (the multiplayer screens'
## style, as Import Game / Export Game are).
func _export_box(y: float, k: int, used: bool) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Export%d" % k
	b.texture_normal = SavedArt.Box(Vector2i(ExportRect.size), false)
	b.texture_pressed = SavedArt.Box(Vector2i(ExportRect.size), true)
	b.texture_disabled = b.texture_normal
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = Vector2(ExportRect.position.x, y + ExportRect.position.y) * _s
	b.size = ExportRect.size * _s
	b.tooltip_text = "Save this game to a file"
	b.disabled = not used
	_canvas.add_child(b)
	var words := _text("Export", ExportRect.position.x, y + ExportRect.position.y + 5, ExportRect.size.x, ExportPx, Green if used else Greyed, HORIZONTAL_ALIGNMENT_CENTER, false, "ExportText%d" % k)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.button_down.connect(func() -> void: words.add_theme_color_override("font_color", Red))
	b.button_up.connect(func() -> void: words.add_theme_color_override("font_color", Green))
	var row_k := k
	b.pressed.connect(func() -> void: Host.ExportGame(_rows[row_k]["id"]))
	return b


# ---- drawing, in the original's pixels (as the Game Options screen) ------------

func _field(t: String, y: float, k: int, tip: String) -> LineEdit:
	var field := LineEdit.new()
	field.name = "Name%d" % k
	field.text = t
	field.position = Vector2(NameRect.position.x, y + NameRect.position.y) * _s
	field.size = NameRect.size * _s
	field.max_length = 40
	field.add_theme_font_override("font", OUI.Face(false))
	field.add_theme_font_size_override("font_size", roundi(TextPx * _s))
	field.add_theme_color_override("font_color", Color.WHITE)
	field.add_theme_color_override("caret_color", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2 * _s
	for st in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(st, empty)
	field.tooltip_text = tip
	_canvas.add_child(field)
	return field


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


func _button(pic: String, x: float, y: float, tip: String, node_name: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = node_name
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


func _text(t: String, x: float, cap_top: float, w: float, px: float, color: Color,
		align: HorizontalAlignment, bold: bool, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = t
	l.position = Vector2(x, cap_top - 0.19 * px) * _s
	l.size = Vector2(w, px * 1.4) * _s
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_override("font", OUI.Face(bold))
	l.add_theme_font_size_override("font_size", roundi(px * _s))
	l.add_theme_color_override("font_color", color)
	_canvas.add_child(l)
	return l
