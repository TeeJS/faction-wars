extends RefCounted
## THE ORIGINAL'S FINDERS (manual p075 Fig. 3.12, p124-p126; TeeJ's
## screenshots of the Planetary System, Fleet, Ship, Troop and Personnel
## Finders, 2026-09-24): the Encyclopedia's frame and index layout - the
## Finder's plate (the System, Fleet and Ship plates are the Index plate's
## twins to the row: the name field's box at 33-47, the band at 106-123) at
## (12, 13), the title across its top, the name label and field, a row of
## 49x41 tabs 52 apart, the band naming the tab, a list of names 20 apart
## with the original's scroll bar - and down the frame's right edge Close,
## Display and the finder's own buttons. Every picture placed on those
## screenshots by template matching; positions in the frame's pixels, drawn
## OUI.K times as large.
##
## Preloaded by path: a new script can lag the editor's class cache.

const OUI := preload("res://src/ui/original_ui.gd")
const Art := preload("res://src/ui/artwork.gd")
const Ency := preload("res://src/ui/encyclopedia_window.gd")

const FrameW := 470
const FrameH := 331
const PlateAt := Vector2(12, 13)
## The title (bold Arial 13) centred over the plate; the name label (Arial
## 13) at (36, 49); the typed name at (143, 45) in the plate's box.
const TitleCentre := 212.0
const TitleY := 15
const LabelAt := Vector2(36, 49)
const FieldAt := Vector2(143, 45)
const FieldSize := Vector2(243, 16)
const TabsX := 36
const TabsY := 78
const TabsPitch := 52
const TabSize := Vector2(49, 41)
const BandAt := Vector2(40, 120)
const ListAt := Vector2(41, 137)
const ListSize := Vector2(333, 160)
const BarAt := Vector2(374, 137)
## The right-hand column: the Alliance's 32x31 buttons at x 423 on its
## socketed strip (two sockets, 10584, or four, 10586, at (412, 0)); the
## Empire's 44x41 at x 426 on its frame. A button every 54 pixels after
## Display's.
const ButtonX := {"alliance": 423, "empire": 426}
const ButtonYs := {"alliance": [25, 93, 147, 201], "empire": [21, 89, 143, 197]}
const StripAt := Vector2(412, 0)


## The side whose frame and buttons the finder wears: the viewer's.
static func Side() -> String:
	var s: String = OUI.Side(GameSettings.PlayerFaction)
	return s if ButtonX.has(s) else "empire"


## True when the art the finder is made of is imported: the frame, the
## plate, the tabs and every button it names.
static func CanBuild(plates: Array, tabs: Array, buttons: Array) -> bool:
	var side: String = Side()
	if not OUI.Has(["frame." + side] + plates):
		return false
	for t in tabs:
		if Art.TabIcon(t, side) == null:
			return false
	if Art.ButtonIcon("ency_close." + side) == null:
		return false
	for b in buttons:
		if Art.ButtonIcon("%s.%s" % [b, side]) == null:
			return false
	return true


## Build the finder over `window`'s content area. `tabs` is [[tab picture,
## band caption], ...]; `buttons` is [[button name, tooltip], ...] after
## Close. Returns the parts: body, plate (a TextureRect to swap), field,
## header, list, bar, tabs (TextureButtons), buttons (by name).
static func Build(window: DraggableWindow, title: String, label: String, plate: Texture2D,
		tabs: Array, buttons: Array) -> Dictionary:
	var side: String = Side()
	var K: int = OUI.K
	var bar: Control = window.get_node_or_null("%TitleBar")
	if bar != null:
		bar.visible = false
	window.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var area: MarginContainer = OUI.Flatten(window)
	for c in area.get_children():
		if c is Control and not (c is ColorRect):
			(c as Control).visible = false
	window.custom_minimum_size = Vector2(FrameW, FrameH) * K
	window.size = window.custom_minimum_size
	var body := Control.new()
	body.name = "OriginalFinder"
	body.custom_minimum_size = Vector2(FrameW, FrameH) * K
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	area.add_child(body)
	var parts := {"body": body}

	parts["plate"] = OUI.Place(body, plate, PlateAt.x, PlateAt.y, "Plate")
	var t := OUI.Text(body, title, TitleCentre - 150, TitleY, 300, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, "Title")
	t.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	OUI.Text(body, label, LabelAt.x, LabelAt.y, 100, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "NameLabel")
	var field := LineEdit.new()
	field.name = "NameField"
	field.position = FieldAt * K
	field.size = FieldSize * K
	field.flat = true
	OUI.Style(field, 13, Color.WHITE)
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(st, clear)
	body.add_child(field)
	parts["field"] = field

	var tabButtons: Array = []
	var group := ButtonGroup.new()
	for i in tabs.size():
		var tb := TextureButton.new()
		tb.name = "Tab%d" % i
		tb.texture_normal = Ency._tab_picture(OUI.Tab(tabs[i][0], side))
		tb.texture_pressed = Ency._tab_picture(OUI.Tab(tabs[i][0], side, "pressed"))
		tb.texture_disabled = Ency._tab_picture(OUI.Tab(tabs[i][0], side, "grey"))
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.toggle_mode = true
		tb.button_group = group
		tb.position = Vector2(TabsX + TabsPitch * i, TabsY) * K
		tb.size = TabSize * K
		tb.tooltip_text = tabs[i][1]
		tb.set_meta("title", tabs[i][1])
		body.add_child(tb)
		tabButtons.append(tb)
	parts["tabs"] = tabButtons
	parts["header"] = OUI.Text(body, tabs[0][1] if not tabs.is_empty() else "", BandAt.x, BandAt.y, 330, 16, 13, Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT, true, "Header")

	var list := Ency.OriginalIndex.new()
	list.name = "List"
	list.k = K
	list.position = ListAt * K
	list.size = ListSize * K
	list.font = OUI.Face()
	body.add_child(list)
	var scroll := OUI.ScrollBar12.new()
	scroll.name = "ScrollBar"
	scroll.k = K
	scroll.parts = [OUI.Btn("scroll_up"), OUI.Btn("scroll_down"), OUI.Btn("scroll_thumb_top"), OUI.Btn("scroll_thumb_mid"), OUI.Btn("scroll_thumb_bottom")]
	scroll.position = BarAt * K
	scroll.size = Vector2(OUI.ScrollBar12.W - 1, ListSize.y) * K
	body.add_child(scroll)
	list.bar = scroll
	scroll.scrolled.connect(list.scroll_to)
	parts["list"] = list
	parts["bar"] = scroll

	# The frame over the plate, dragged by; the Alliance's socketed strip.
	# Dragged by where it is drawn; a click on the list inside goes through.
	var frame := OUI.PlaceHit(body, OUI.Pic("frame." + side), 0, 0, "Frame")
	frame.gui_input.connect(window.OnTitleBarGuiInput)
	if side == "alliance":
		var strip: Texture2D = OUI.Pic("finder_side%d.alliance" % (2 if buttons.size() <= 1 else 4))
		if strip != null:
			var column := OUI.PlaceHit(body, strip, StripAt.x, StripAt.y, "SideColumn")
			column.gui_input.connect(window.OnTitleBarGuiInput)
	var named := {}
	named["close"] = _Button(body, "ency_close", side, 0, "Close the %s." % title)
	named["close"].pressed.connect(window.CloseWindow)
	for i in buttons.size():
		named[buttons[i][0]] = _Button(body, buttons[i][0], side, i + 1, buttons[i][1])
	parts["buttons"] = named
	return parts


## A button down the frame's right edge: its normal picture, its pressed one
## on the press - and, for a switch, the pressed one while its view is on.
static func _Button(parent: Control, name: String, side: String, row: int, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = name
	var normal: Texture2D = OUI.Btn("%s.%s" % [name, side])
	var pressed: Texture2D = OUI.Btn("%s.%s" % [name, side], "pressed")
	b.set_meta("normal_tex", normal)
	b.set_meta("pressed_tex", pressed if pressed != null else normal)
	b.texture_normal = normal
	b.texture_pressed = b.get_meta("pressed_tex")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = Vector2(ButtonX[side], ButtonYs[side][row]) * OUI.K
	b.size = normal.get_size() if normal != null else Vector2(32, 31) * OUI.K
	b.tooltip_text = tip
	b.set_meta("title", tip)
	parent.add_child(b)
	return b


## A switch button shown lit while its view is the one on show.
static func SetCurrent(b: TextureButton, on: bool) -> void:
	if b != null:
		b.texture_normal = b.get_meta("pressed_tex") if on else b.get_meta("normal_tex")


## Locate a name as typed ("Enter name or part of name to locate a specific
## system in the list", Fig. 3.12): the first that begins with it, else the
## first that contains it - selected and scrolled to. -1 when none does.
static func Locate(list: Control, text: String) -> int:
	var t := text.strip_edges().to_lower()
	if t.is_empty():
		return -1
	var hit := -1
	var count: int = int(list.get("item_count"))
	for i in count:
		if list.call("get_item_text", i).to_lower().begins_with(t):
			hit = i
			break
	if hit < 0:
		for i in count:
			if list.call("get_item_text", i).to_lower().contains(t):
				hit = i
				break
	if hit >= 0:
		list.call("select", hit)
		list.call("ensure_current_is_visible")
	return hit
