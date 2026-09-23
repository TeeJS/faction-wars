extends RefCounted
## THE ORIGINAL'S OWN WINDOWS, REBUILT FROM ITS BITMAPS (TeeJ, 2026-09-23:
## "MATCH THE UI OF THE ORIGINAL"). The Manufacturing and Production, System
## Defenses and Galactic Encyclopedia windows are composed exactly as the
## original composes them: its plates, parts and tab pictures, at the
## positions measured by template matching on TeeJ's own screenshots of the
## original (Chandrila, Duros, Mon Calamari, Coruscant, Yaga Minor, Drall,
## the Encyclopedia and the Message Index on both sides). Every position in
## the callers is in the ORIGINAL's pixels; everything is drawn K times as
## large, nearest-neighbour, so a pixel stays a crisp square.
##
## Only when the player imported the art (tools/RebellionArtImporter). A
## window without it keeps its plain look - the WWII pack has none.
##
## Preloaded by path (as OUI): a new class_name can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")

## Every original pixel is drawn K x K.
const K := 2

## The original's title bar: 16 rows of the side's colour inside a one-row
## rim; the system box at x 3, minimise and close 31 and 17 from the right.
const TitleBarH := 18

## A card in the Defenses and Manufacturing grids (Fig 3.73): the 61x25
## miniature, the name under it, 70 x 70, three to a row.
const CardW := 70
const CardH := 70

static var _face: Font = null
static var _bold: Font = null


## The original's face - Arial - where the system has it; the engine's own
## font otherwise (the web build has no system fonts).
static func Face(bold: bool = false) -> Font:
	if bold and _bold != null:
		return _bold
	if not bold and _face != null:
		return _face
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial", "Liberation Sans", "Helvetica", "Nimbus Sans"])
	f.font_weight = 700 if bold else 400
	if bold:
		_bold = f
	else:
		_face = f
	return f


## A window part at the drawn scale.
static func Pic(name: String) -> Texture2D:
	return Art.Scaled(Art.WindowPicture(name), K)


## A button picture ("" / "pressed" / "disabled") at the drawn scale.
static func Btn(name: String, state: String = "") -> Texture2D:
	return Art.Scaled(Art.ButtonIcon(name, state), K)


## A tab picture ("" / "pressed" = current / "grey") at the drawn scale.
static func Tab(name: String, side: String, state: String = "") -> Texture2D:
	return Art.Scaled(Art.TabIcon(name, side, state), K)


## A 61x25 list miniature at the drawn scale.
static func Mini(kind: String, id: String) -> Texture2D:
	return Art.Scaled(Art.Miniature(kind, id), K)


## The side as the art files name it.
static func Side(f: Faction) -> String:
	return f.Id if f != null else ""


## The original's colour for a side: its title bars and a selected name -
## pure red for the Alliance, pure green for the Empire (sampled).
static func SideColor(f: Faction) -> Color:
	if f == null:
		return Color(0.7, 0.7, 0.7)
	match f.Id:
		"alliance":
			return Color(1, 0, 0)
		"empire":
			return Color(0, 1, 0)
	return f.FactionColor


## True when every named window part is imported.
static func Has(parts: Array) -> bool:
	for p in parts:
		if Art.WindowPicture(str(p)) == null:
			return false
	return true


## A picture at original position (x, y), at its drawn size.
static func Place(parent: Control, tex: Texture2D, x: float, y: float, name: String = "") -> TextureRect:
	var r := TextureRect.new()
	if not name.is_empty():
		r.name = name
	r.texture = tex
	r.position = Vector2(x, y) * K
	r.size = tex.get_size() if tex != null else Vector2.ZERO
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## The original's text style on a label: face, size in original pixels.
static func Style(l: Control, px: int, color: Color, bold: bool = false) -> void:
	l.add_theme_font_override("font", Face(bold))
	l.add_theme_font_size_override("font_size", px * K)
	l.add_theme_color_override("font_color", color)
	if l is Label:
		l.add_theme_constant_override("line_spacing", -K)


## A line of text in an original-pixel box.
static func Text(parent: Control, text: String, x: float, y: float, w: float, h: float, px: int,
		color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		bold: bool = false, name: String = "") -> Label:
	var l := Label.new()
	if not name.is_empty():
		l.name = name
	l.text = text
	l.position = Vector2(x, y) * K
	l.size = Vector2(w, h) * K
	l.clip_text = false
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Style(l, px, color, bold)
	parent.add_child(l)
	return l


## Put an existing label (a scene's unique node, so its lookups keep
## working) into an original-pixel box.
static func Seat(l: Control, parent: Control, x: float, y: float, w: float, h: float) -> void:
	if l.get_parent() != parent:
		l.reparent(parent, false)
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.custom_minimum_size = Vector2.ZERO
	l.position = Vector2(x, y) * K
	l.size = Vector2(w, h) * K
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


# ---- the window's title bar --------------------------------------------------

## THE ORIGINAL'S TITLE BAR on a DraggableWindow: the side's colour, the name
## in black bold, the system box at the left and the minimise and close boxes
## at the right. The window's own buttons are restyled, so their wiring and
## the title bar's drag stay as they were.
static func TitleBar(window: Control, f: Faction) -> void:
	var bar: ColorRect = window.get_node_or_null("%TitleBar")
	var label: Label = window.get_node_or_null("%TitleBarLabel")
	if bar == null or label == null or bar.has_meta("original"):
		return
	bar.set_meta("original", true)
	bar.color = SideColor(f)
	bar.custom_minimum_size = Vector2(0, TitleBarH * K)
	Style(label, 14, Color.BLACK, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hbox: HBoxContainer = label.get_parent() as HBoxContainer
	if hbox == null:
		return
	hbox.add_theme_constant_override("separation", 0)
	# Left: 3-pixel rim, the 14x14 system box, 3 pixels, the name.
	var sys := TextureRect.new()
	sys.name = "SystemBox"
	sys.texture = Btn("title_system")
	sys.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sys.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sys.custom_minimum_size = Vector2(14, 14) * K
	sys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(sys)
	hbox.move_child(sys, 0)
	hbox.add_child(_gap(3))
	hbox.move_child(hbox.get_child(hbox.get_child_count() - 1), 0)
	hbox.add_child(_gap(3))
	hbox.move_child(hbox.get_child(hbox.get_child_count() - 1), 2)
	# Right: minimise and close, touching, 3 pixels from the edge.
	for pair in [["MinimizeButton", "title_minimize"], ["CloseButton", "title_close"]]:
		var b: Button = window.get_node_or_null("%" + pair[0])
		if b == null:
			continue
		b.text = ""
		b.icon = Btn(pair[1])
		b.flat = true
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = Vector2(14, 14) * K
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, empty)
	hbox.add_child(_gap(3))
	# The window's own frame: a thin dark rim around the plate.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.06)
	sb.set_border_width_all(K)
	sb.border_color = Color(0, 0, 0.5)   # the original's navy edge (sampled)
	sb.set_content_margin_all(K)
	window.add_theme_stylebox_override("panel", sb)
	var vbox: Control = window.get_node_or_null("MainVBox")
	if vbox != null:
		vbox.add_theme_constant_override("separation", 0)


## A DIALOG'S FRAME, as the original draws Create Mission: the plate IS the
## window, with its own 2-pixel bevel round the edge, and the title bar sits
## inside the bevel - 16 rows of the side's colour, the name in black bold
## Arial 13 from 4 pixels in, and only the close box, 1 pixel from the end
## (measured on TeeJ's screenshot of the original, 2026-09-23).
const DialogBevel := 2
const DialogBarH := 16


static func DialogFrame(window: Control, f: Faction, plate: Texture2D, titlePx: int = 13) -> void:
	var bar: ColorRect = window.get_node_or_null("%TitleBar")
	var label: Label = window.get_node_or_null("%TitleBarLabel")
	if bar == null or label == null:
		return
	bar.color = SideColor(f)
	bar.custom_minimum_size = Vector2(0, DialogBarH * K)
	Style(label, titlePx, Color.BLACK, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hbox: HBoxContainer = label.get_parent() as HBoxContainer
	if hbox != null and not bar.has_meta("original"):
		bar.set_meta("original", true)
		hbox.add_theme_constant_override("separation", 0)
		hbox.add_child(_gap(4))
		hbox.move_child(hbox.get_child(hbox.get_child_count() - 1), 0)
		var mini: Control = window.get_node_or_null("%MinimizeButton")
		if mini != null:
			mini.visible = false
		var close: Button = window.get_node_or_null("%CloseButton")
		if close != null:
			_title_button(close, "title_close")
		hbox.add_child(_gap(1))
	SetPlate(window, plate)
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vbox: Control = window.get_node_or_null("MainVBox")
	if vbox != null:
		vbox.add_theme_constant_override("separation", 0)


## The dialog's plate, drawn as the window's own panel (a tab can swap it).
static func SetPlate(window: Control, plate: Texture2D) -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = plate
	sb.set_content_margin_all(DialogBevel * K)
	window.add_theme_stylebox_override("panel", sb)


## A title-bar button drawn as the original's 14x14 box.
static func _title_button(b: Button, icon: String) -> void:
	b.text = ""
	b.icon = Btn(icon)
	b.flat = true
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size = Vector2(14, 14) * K
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)


## A button drawn with the original's (normal, pressed) pictures, at original
## position (x, y).
static func PictureButton(parent: Control, name: String, x: float, y: float, tip: String = "") -> TextureButton:
	var b := TextureButton.new()
	b.name = name
	b.texture_normal = Btn(name)
	b.texture_pressed = Btn(name, "pressed")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = Vector2(x, y) * K
	b.size = b.texture_normal.get_size() if b.texture_normal != null else Vector2.ZERO
	b.tooltip_text = tip
	parent.add_child(b)
	return b


static func _gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px * K, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## THE PLATE RUNS UNDER THE TITLE BAR, as in the original: its first rows
## are covered by the bar and the tab pictures sit 2 pixels under it. The
## body shows the plate from row TitleBarH down; everything is placed on the
## returned canvas in the plate's own pixels.
static func Canvas(area: Control, w: int, h: int) -> Control:
	var body := Control.new()
	body.name = "OriginalBody"
	body.custom_minimum_size = Vector2(w, h - TitleBarH) * K
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	area.add_child(body)
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.position = Vector2(0, -TitleBarH) * K
	canvas.size = Vector2(w, h) * K
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(canvas)
	return canvas


## The content area laid flat for a plate: no margins, no background.
static func Flatten(window: Control) -> MarginContainer:
	var area: MarginContainer = window.get_node_or_null("%ContentArea")
	if area == null:
		return null
	for side in ["left", "top", "right", "bottom"]:
		area.add_theme_constant_override("margin_" + side, 0)
	for c in area.get_children():
		if c is ColorRect:
			(c as ColorRect).visible = false
	return area


# ---- the tab strip -----------------------------------------------------------

## THE ORIGINAL'S TAB STRIP: its pictures at their measured positions over
## the plate's dark band. The current page shows its "current" picture; a
## page with nothing on it shows the greyed picture and cannot be picked
## ("grayed-out tabs indicate no facilities of that type are on the
## system", p084). Pressing one turns the TabContainer's page.
static func TabStrip(parent: Control, tabs: TabContainer, names: Array, side: String, xs: Array, y: int) -> void:
	var buttons: Array = []
	for i in mini(names.size(), tabs.get_tab_count()):
		var b := TextureButton.new()
		b.name = "Tab_%s" % names[i]
		b.set_meta("normal", Tab(names[i], side))
		b.set_meta("current", Tab(names[i], side, "pressed"))
		b.texture_normal = b.get_meta("normal")
		b.texture_pressed = b.get_meta("current")
		b.texture_disabled = Tab(names[i], side, "grey")
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(xs[i], y) * K
		b.size = (b.texture_normal as Texture2D).get_size()
		b.tooltip_text = tabs.get_tab_title(i)
		b.set_meta("title", tabs.get_tab_title(i))
		var idx := i
		b.pressed.connect(func() -> void:
			if not tabs.is_tab_disabled(idx):
				tabs.current_tab = idx)
		parent.add_child(b)
		buttons.append(b)
	tabs.set_meta("tab_strip", buttons)
	tabs.tab_changed.connect(func(_i: int) -> void: RefreshStrip(tabs))
	RefreshStrip(tabs)


static func RefreshStrip(tabs: TabContainer) -> void:
	if not tabs.has_meta("tab_strip"):
		return
	var buttons: Array = tabs.get_meta("tab_strip")
	for i in buttons.size():
		var b: TextureButton = buttons[i]
		var current: bool = i == tabs.current_tab
		b.disabled = tabs.is_tab_disabled(i) and not current
		b.texture_normal = b.get_meta("current") if current else b.get_meta("normal")


# ---- a page: captions over a grid of cards -------------------------------------

## A page in the original's layout, `width` original pixels wide: up to two
## centred caption lines at y 1 and 13 (the tab's title, then e.g. the
## garrison requirement), and a scrolling grid of cards from (7, 28).
## Returns the grid; cards are added to it. Captions are named Caption1/2.
static func Page(container: Control, captions: Array, width: int, height: int) -> HFlowContainer:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	if container is MarginContainer:
		for side in ["left", "top", "right", "bottom"]:
			container.add_theme_constant_override("margin_" + side, 0)
	var page := Control.new()
	page.name = "OriginalPage"
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	page.custom_minimum_size = Vector2(width, height) * K
	container.add_child(page)
	Captions(page, captions, width)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(7, 28) * K
	scroll.size = Vector2(width - 11, height - 32) * K
	page.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.name = "Grid"
	grid.custom_minimum_size = Vector2(CardW * 3, 0) * K
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.set_meta("cards", true)
	scroll.add_child(grid)
	return grid


## The page's caption lines, centred: the tab's title, then a second line.
static func Captions(page: Control, captions: Array, width: int) -> void:
	for i in 2:
		var old: Node = page.get_node_or_null("Caption%d" % (i + 1))
		if old != null:
			page.remove_child(old)
			old.queue_free()
	for i in mini(captions.size(), 2):
		var l := Text(page, str(captions[i]), 0, 1 + 12 * i, width, 14, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Caption%d" % (i + 1))
		l.mouse_filter = Control.MOUSE_FILTER_PASS


## The card's picture stack: the plate for its state (manual p084: "the
## image for these units shows whether the unit is completed, being built,
## or en route" - the grey plate, hyperspace streaks), the miniature on it,
## and the side's grid over something being built.
static func _picture_stack(parent: Control, mini: Texture2D, state: String) -> void:
	var plate: Texture2D = Pic("card_enroute" if state == "enroute" else "card_plate")
	if plate != null:
		Place(parent, plate, 0, 0, "Plate")
	if mini != null:
		Place(parent, mini, 0, 0, "Picture")
	if state == "building":
		var grid: Texture2D = Pic("card_building.%s" % Side(GameSettings.PlayerFaction))
		if grid != null:
			Place(parent, grid, 0, 0, "Building")


## Turn a list button into a CARD (Fig 3.73): the miniature at the top-left,
## the name under it in white, wrapping; selected, a one-pixel frame round
## the picture and the name in the side's colour. The button keeps its
## menu, selection and drag; its text moves to the Name label.
static func Card(btn: BaseButton, title: String, mini: Texture2D, color: Color, selected: Color, state: String = "") -> void:
	if btn is Button:
		(btn as Button).text = ""
		(btn as Button).icon = null
		(btn as Button).flat = true
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	btn.custom_minimum_size = Vector2(CardW, CardH) * K
	btn.set_meta("card", true)
	_picture_stack(btn, mini, state)
	var frame := ReferenceRect.new()
	frame.name = "Frame"
	frame.editor_only = false
	frame.border_color = selected
	frame.border_width = K
	frame.position = Vector2(-1, -1) * K
	frame.size = Vector2(63, 27) * K
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(frame)
	var name := _card_name(btn, title, color)
	var show := func(on: bool) -> void:
		frame.visible = on
		name.add_theme_color_override("font_color", selected if on else color)
	show.call(btn.button_pressed)
	btn.toggled.connect(show)


## A card that is only a picture and a name (a unit on its way, a stale
## sighting with nothing to click).
static func StaticCard(list: Container, title: String, mini: Texture2D, color: Color, tip: String = "", state: String = "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(CardW, CardH) * K
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.tooltip_text = tip
	_picture_stack(c, mini, state)
	_card_name(c, title, color)
	list.add_child(c)
	return c


## A card's name under its picture: 11-pixel Arial, the lines 14 pixels
## apart, from y 29 (measured on the original's Coruscant Troops page).
static func _card_name(card: Control, title: String, color: Color) -> Label:
	var name := Text(card, title, 0, 29, CardW - 2, CardH - 29, 11, color, HORIZONTAL_ALIGNMENT_LEFT, false, "Name")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.clip_text = true
	name.add_theme_constant_override("line_spacing", 3 * K / 2)
	return name
