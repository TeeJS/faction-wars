extends Control
## THE GID CONTROL'S MENU (manual p024 Fig 2.7: "You can change the display
## by clicking on the Galactic Information Display button on the Control Panel
## at the bottom of the screen. Sub-menus for this control let you change what
## the stars on the Galactic Information Display indicate"). Opened by the
## Control Panel's GID monitor. Measured on TeeJ's screenshots of the
## original, both sides, every submenu (2026-09-25), in original pixels:
##   - the box: the original's menu box (OriginalMenu.MenuBox), 158 x 158, at
##     a fixed place in the frame (CommandFrame.Layout "gid_menu") - drawn at
##     the menus' scale (OUI.K), its bottom-right corner on the original's;
##   - the six categories, then Display Off: rows 22 apart from 8 down; the
##     caret 10 in (the side's colour at half strength, full while its
##     category is open), the category's icon 29 in (windows/gid_menu_<id>.
##     <side>, exporter 2.4.6), its name 50 in, Arial 13; Display Off 18 high,
##     with no caret or icon;
##   - the category under the mouse opens its submenu to the left, touching
##     it: 238 wide, rows 22 apart from 5 down and 4 under the last; its top a
##     pixel above the category's row, or - where that would pass the menu's
##     bottom (Resources, Manufacturing, Defense) - its bottom on the row's;
##   - a mode's icon 29 in, its words (the pack's control_label, TEXTSTRA
##     5632-5662) 50 in; the category and the mode under the mouse in the
##     side's colour.
## Choosing a mode, or Display Off, puts it on the map (`chosen`) and closes
## the menu; a click anywhere else, or Escape, closes it. No mode is marked as
## the one on the map: no screenshot shows one.
## Preloaded by path (a new class_name can lag the editor's class cache).

const OriginalMenu := preload("res://src/ui/original_menu.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const Art := preload("res://src/ui/artwork.gd")

const K := OUI.K
const MainW := 158
const SubW := 238
const Pitch := 22
const MainTop := 8
const SubTop := 5
const SubBottom := 4
const OffRowH := 18
const CaretX := 10
const IconX := 29
const TextX := 50
const Px := 13

signal chosen(mode: Object)

var _side := ""
var _lit := Color.WHITE
var _cats: Array = []
var _main: Panel = null
var _sub: Panel = null
var _open := -1                # the category whose submenu is open
var _carets: Array = []        # per category: its caret
var _names: Array = []         # per category: its name
var _off: Label = null
var _subNames: Array = []      # the open submenu's words
var _hotSub := -1


func Open(bottom_right: Vector2, side: String, cats: Array) -> void:
	name = "GidControlMenu"
	_side = side
	_cats = cats
	_lit = OUI.SideColor(GameSettings.PlayerFaction)
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_main = _box(Vector2(MainW, MainTop + cats.size() * Pitch + OffRowH))
	_main.name = "Main"
	_main.position = (bottom_right - _main.size).floor()
	for i in cats.size():
		var cat: Gid.GidCategory = cats[i]
		var y: float = MainTop + i * Pitch
		var caret := TextureRect.new()
		caret.texture = OriginalMenu.Caret(GameSettings.PlayerFaction)
		caret.position = Vector2(CaretX, y + (Pitch - OriginalMenu.CaretRows.size()) / 2) * K
		caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main.add_child(caret)
		_carets.append(caret)
		_icon(_main, "gid_menu_%s.%s" % [cat.Id, side], y)
		_names.append(_words(_main, cat.Name, y, Pitch, MainW, "Cat_" + cat.Id))
	_off = _words(_main, Gid.DisplayOff.LabelText, MainTop + cats.size() * Pitch, OffRowH, MainW, "DisplayOff")


## The box on screen, and the open submenu's (for tests).
func MainBox() -> Rect2:
	return _main.get_rect()


func SubBox() -> Rect2:
	return _sub.get_rect() if _sub != null else Rect2()


func OpenCategory() -> int:
	return _open


func Close() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _box(sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", OriginalMenu.MenuBox.new())
	p.size = sz * K
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _icon(box: Control, picture: String, y: float) -> void:
	var tex: Texture2D = Art.WindowPicture(picture)
	if tex == null:
		return
	var t := TextureRect.new()
	t.texture = Art.Scaled(tex, K)
	t.position = Vector2(IconX, y + 1) * K
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)


func _words(box: Control, text: String, y: float, h: float, w: float, node_name: String) -> Label:
	var l: Label = OUI.Text(box, text, TextX, y, w - TextX - 2, h, Px, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, node_name)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## The category's submenu, to the left of the menu (see the header).
func _OpenSub(i: int) -> void:
	if _open == i:
		return
	_open = i
	if _sub != null:
		_sub.queue_free()
		_sub = null
	_subNames.clear()
	_hotSub = -1
	for k in _carets.size():
		(_carets[k] as TextureRect).texture = OriginalMenu.Caret(GameSettings.PlayerFaction, k == i)
		(_names[k] as Label).add_theme_color_override("font_color", _lit if k == i else Color.WHITE)
	if i < 0:
		return
	var modes: Array = (_cats[i] as Gid.GidCategory).Modes
	var h: float = SubTop + modes.size() * Pitch + SubBottom
	var rowTop: float = MainTop + i * Pitch
	var top: float = rowTop - 1
	if top + h > _main.size.y / K:
		top = rowTop + Pitch - h
	_sub = _box(Vector2(SubW, h))
	_sub.name = "Sub"
	_sub.position = _main.position + Vector2(-(SubW - 1), top) * K
	for j in modes.size():
		var mode: Gid.GidMode = modes[j]
		var y: float = SubTop + j * Pitch
		_icon(_sub, "gid_menu_%s.%s" % [mode.Id, _side], y)
		_subNames.append(_words(_sub, mode.ControlLabel, y, Pitch, SubW, "Mode_" + mode.Id))


## Which row of the menu `p` is on: a category's index, the category count for
## Display Off, or -1.
func _main_row(p: Vector2) -> int:
	var r: Rect2 = _main.get_rect()
	if not r.has_point(p):
		return -1
	var y: float = (p.y - r.position.y) / K - MainTop
	if y < 0:
		return -1
	return mini(int(y / Pitch), _cats.size())


func _sub_row(p: Vector2) -> int:
	if _sub == null or not _sub.get_rect().has_point(p):
		return -1
	var y: float = (p.y - _sub.position.y) / K - SubTop
	if y < 0 or y >= _subNames.size() * Pitch:
		return -1
	return int(y / Pitch)


func _gui_input(e: InputEvent) -> void:
	var m := e as InputEventMouse
	if m == null:
		return
	var mainRow: int = _main_row(m.position)
	var subRow: int = _sub_row(m.position)
	if e is InputEventMouseMotion:
		if mainRow >= 0 and mainRow < _cats.size():
			_OpenSub(mainRow)
		elif mainRow == _cats.size():
			_OpenSub(-1)
		_off.add_theme_color_override("font_color", _lit if mainRow == _cats.size() else Color.WHITE)
		if subRow != _hotSub:
			_hotSub = subRow
			for j in _subNames.size():
				(_subNames[j] as Label).add_theme_color_override("font_color", _lit if j == subRow else Color.WHITE)
	elif e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.pressed and mainRow < 0 and subRow < 0:
			Close()
		elif not b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
			if subRow >= 0:
				var mode: Object = (_cats[_open] as Gid.GidCategory).Modes[subRow]
				Close()
				chosen.emit(mode)
			elif mainRow == _cats.size():
				Close()
				chosen.emit(Gid.DisplayOff)
	accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		Close()
		get_viewport().set_input_as_handled()
