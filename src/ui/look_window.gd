extends RefCounted
## A PLAIN WINDOW IN THE PACK'S LOOK (docs/ww2-look-plan.md, phases 4-6). Phase
## 6 dresses every window this way from one hook (Install, below). The
## template every scene window shares - a PanelContainer, a TitleBar (a
## ColorRect) holding TitleBarLabel, MinimizeButton and CloseButton, and a
## ContentArea with its Background - dressed as a steel-framed panel: a dark
## bar with a brass hairline under it, the title in the display face, the
## body in the chassis colour. Only the dress changes; drag, minimise, close
## and every control inside keep working as they did.
##
## For a pack with a look (Look.Active()) and a window in its plain form (not
## the original's, built from the player's art set). The theme goes on the
## window, so what is inside it wears the look's base controls.
##
## Preloaded by path (as LookWindow).

static func Dress(window: Control) -> void:
	if not Look.Active():
		return
	window.theme = Look.GetTheme()
	window.add_theme_stylebox_override("panel", Look.Box("chassis", "brass_dim", 1, 0, 0))

	var bar: ColorRect = window.get_node_or_null("%TitleBar")
	if bar != null:
		bar.color = Look.C("chassis_deep")
		if bar.get_node_or_null("LookRule") == null:
			var rule := ColorRect.new()
			rule.name = "LookRule"
			rule.color = Look.C("brass_dim")
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			rule.offset_top = -1
			bar.add_child(rule)
		bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, 26)
	# The sector window names its parts plainly ("Title", not unique).
	var title: Label = window.get_node_or_null("%TitleBarLabel")
	if title == null:
		title = window.get_node_or_null("MainVBox/TitleBar/HBox/Title") as Label
	if title != null:
		title.add_theme_font_override("font", Look.F("display"))
		title.add_theme_font_size_override("font_size", Look.Size("title"))
		title.add_theme_color_override("font_color", Look.C("text"))
		title.uppercase = true
	for n in ["MinimizeButton", "CloseButton"]:
		var b: Button = window.get_node_or_null("%" + n)
		if b == null:
			b = window.get_node_or_null("MainVBox/TitleBar/HBox/" + n) as Button
		if b != null:
			b.theme_type_variation = Look.COMMAND
			b.remove_theme_font_size_override("font_size")
			b.add_theme_font_size_override("font_size", Look.Size("small"))
	# The body's backdrop: the ColorRect straight under ContentArea, whatever
	# the scene named it ("Background", or "ColorRect" in the Game Menu).
	var area: Node = window.get_node_or_null("MainVBox/ContentArea")
	if area != null:
		for c in area.get_children():
			if c is ColorRect:
				(c as ColorRect).color = Look.C("chassis")


## A list's row in a plain window: a ruled ledger line, its words in `ink`
## (a side's colour from Look.SideColor, or the text colour) at the body size.
## A flat button draws no row, so it is made a solid one.
static func ListRow(btn: Button, ink: Color) -> void:
	if not Look.Active():
		return
	btn.flat = false
	btn.theme_type_variation = Look.ROW
	btn.set_meta(Look.OWN_COLOURS, true)
	btn.remove_theme_font_size_override("font_size")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, ink)


## Every button in `root` a command key (the Game Menu's column).
static func Commands(root: Node) -> void:
	if not Look.Active():
		return
	for c in root.get_children():
		if c is Button:
			(c as Button).theme_type_variation = Look.COMMAND


# ---------------------------------------------------------------------------
# Every other window (phase 6)
# ---------------------------------------------------------------------------

## THE PLAIN WINDOWS' OWN COLOURS, AND THE LOOK'S FOR EACH. The plain windows
## share one small palette - the navy bars and bodies, a deeper navy for wells,
## steel-blue headings, a green highlight, greys for what is read or empty -
## so a window is put in the look by trading each of those for the look's
## token, not by editing twenty scenes. A colour not listed (a side's, a
## status's red or green) is left as the window drew it: every plain colour
## was chosen for a dark ground, and the look's chassis is dark too.
## [plain colour, token], matched on RGB within TOLERANCE; alpha is kept.
const BG_MAP := [
	[Color(0.18, 0.22, 0.28), "chassis_deep"],   # a window's title bar
	[Color(0.12, 0.16, 0.22), "chassis"],        # a window's body
	[Color(0.12, 0.16, 0.21), "chassis"],
	[Color(0.08, 0.10, 0.14), "chassis_deep"],   # a well inside it
	[Color(0.06, 0.08, 0.13), "chassis_deep"],   # the code-built windows' panels
	[Color(0.06, 0.07, 0.11), "chassis_deep"],
	[Color(0.20, 0.20, 0.20), "chassis_deep"],   # a picture's empty box
	[Color(0.40, 0.40, 0.40), "chassis_raised"],
	[Color(0.20, 0.60, 0.20), "olive_deep"],     # Manufacturing's queue headers
]
const EDGE_MAP := [
	[Color(0.40, 0.62, 0.92), "brass_dim"],      # the code-built windows' blue edge
	[Color(0.55, 0.70, 0.95), "brass_dim"],
	[Color(0.60, 0.70, 0.80), "brass_dim"],
]
const TEXT_MAP := [
	[Color(0.60, 0.70, 0.80), "heading"],        # a section's heading
	[Color(0.60, 0.90, 0.60), "heading"],        # a highlighted line
	[Color(0.50, 0.70, 1.00), "heading"],        # Manufacturing's "Destination"
	[Color(0.92, 0.94, 1.00), "text"],
	[Color(0.827, 0.827, 0.827), "text"],        # Color.LIGHT_GRAY: a listed line
	[Color(0.80, 0.80, 0.80), "text"],           # a system's name
	[Color(0.95, 0.97, 1.00), "text"],
	[Color(0.95, 0.96, 1.00), "text"],
	[Color(1.00, 1.00, 1.00), "text"],
	[Color(0.62, 0.72, 0.88), "text_muted"],
	[Color(0.70, 0.78, 0.92), "text_muted"],
	[Color(0.55, 0.60, 0.70), "text_muted"],
	[Color(0.45, 0.48, 0.56), "text_muted"],
	[Color(0.75, 0.75, 0.75), "text_muted"],     # Color.GRAY: read, or empty
	[Color(0.663, 0.663, 0.663), "text_muted"],  # Color.DARK_GRAY: not yet usable
	[Color(0.60, 0.60, 0.60), "text_muted"],
	[Color(0.50, 0.50, 0.50), "text_muted"],
	[Color(0.40, 0.40, 0.40), "text_muted"],
]
const TOLERANCE := 0.015

## The windows made outside UIManager.OpenWindow, by their classes; and the
## four head-to-head screens (MpScreen), full screens of the same palette.
static func IsWindow(n: Node) -> bool:
	return n is DraggableWindow or n is BattleAlertWindow or n is BattleResultsWindow \
		or n is GalaxyOverviewWindow or n is ObjectivesWindow or n is GameOptionsWindow \
		or n is LoadGameWindow or n is AllGamesWindow or n is MpScreen

static var _hooked: bool = false


## EVERY WINDOW IN THE LOOK, wherever it is opened: one hook on the tree. A
## window is dressed once it has built itself (deferred past its _ready and
## the opener's setup); what a window adds later - a list repainted, a row -
## is re-coloured as it arrives. Checks Look.Active() each time, so the Star
## Wars pack's windows are untouched. Idempotent.
static func Install(tree: SceneTree) -> void:
	if tree == null:
		return
	if not _hooked:
		tree.node_added.connect(_on_added)
		_hooked = true
	# The ones already open when the screen called this.
	_sweep(tree.root)


static func _sweep(n: Node) -> void:
	for c in n.get_children():
		if IsWindow(c):
			DressAny.call_deferred(c)
		else:
			_sweep(c)


static func _on_added(n: Node) -> void:
	if not Look.Active() or not n is Control:
		return
	if IsWindow(n):
		DressAny.call_deferred(n)
	elif _dressed_above(n):
		_remap_one.call_deferred(n)


static func _dressed_above(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p.has_meta("look_dressed"):
			return true
		p = p.get_parent()
	return false


## Any window: the template's dress where it has the template's parts,
## the look's theme, and every plain colour in it traded for the look's.
static func DressAny(w: Control) -> void:
	if not Look.Active() or not is_instance_valid(w) or w.has_meta("look_dressed"):
		return
	w.set_meta("look_dressed", true)
	if w.get_node_or_null("%TitleBar") != null:
		Dress(w)
	elif w.theme == null:
		w.theme = Look.GetTheme()
	if w is MpScreen:
		DressScreen(w)
	Remap(w)


## A HEAD-TO-HEAD SCREEN (the Cockpit's multiplayer console, manual p156-p158):
## its title in the display face, a dialog on it as a steel panel, and the
## bottom bar's Previous / Proceed / Cancel as command keys. The ground and the
## captions come from the palette (Remap).
static func DressScreen(s: Control) -> void:
	for t in s.find_children("Title", "Label", true, false):
		var title := t as Label
		title.add_theme_font_override("font", Look.F("display"))
		title.add_theme_color_override("font_color", Look.C("text"))
		title.uppercase = true
	var dialog: Node = s.find_child("Dialog", true, false)
	if dialog is PanelContainer:
		(dialog as PanelContainer).theme_type_variation = Look.MODAL
	var bar: Node = s.get_node_or_null("%BottomBar")
	if bar != null:
		Commands(bar)


## A node and everything under it.
static func Remap(n: Node) -> void:
	_remap_one(n)
	for c in n.get_children():
		Remap(c)


static func _remap_one(n: Node) -> void:
	if not is_instance_valid(n) or not n is Control:
		return
	var c := n as Control
	if c is ColorRect:
		(c as ColorRect).color = _map(BG_MAP, (c as ColorRect).color)
	for p in c.get_property_list():
		var name: String = p.name
		if name.begins_with("theme_override_colors/"):
			var key: String = name.get_slice("/", 1)
			if key.contains("outline") or key.contains("shadow") or not (key.contains("font") or key == "default_color"):
				continue
			if not c.has_theme_color_override(key):
				continue
			var was: Color = c.get(name)
			var now: Color = _text(was)
			if now != was:
				c.add_theme_color_override(key, now)
		elif name.begins_with("theme_override_styles/"):
			var sb: Variant = c.get(name)
			if sb is StyleBoxFlat:
				var flat := sb as StyleBoxFlat
				var bg: Color = _map(BG_MAP, flat.bg_color)
				var edge: Color = _map(EDGE_MAP, flat.border_color)
				if bg != flat.bg_color or edge != flat.border_color:
					var copy := flat.duplicate() as StyleBoxFlat
					copy.bg_color = bg
					copy.border_color = edge
					c.add_theme_stylebox_override(name.get_slice("/", 1), copy)
	_floor(c)
	_readable(c)


# ---------------------------------------------------------------------------
# The readability floor (the WWII windows fix, step 1)
# ---------------------------------------------------------------------------

## THE READABILITY FLOOR (TeeJ, 2026-09-30: "things are very hard to read").
## The plain windows set their own text sizes - 10 to 12 px in a hundred
## places - and colours chosen for the old navy ground. In the look, no words
## are smaller than its `small` size: a list's row (a button) goes to the body
## size, the list rows' size everywhere else, a tab strip's titles to `small`
## (so the tabs still fit), and other text to the `label` size. And no words
## read at less than 4.5:1 on what is behind them (3:1 a
## disabled control's): a colour below that is moved towards legibility, its
## hue kept (Look.Readable). A symbol (a GID star's cross, a close box's "X")
## keeps its size - it is a mark, not words. tests/look_legible.gd reads every
## window and every tab against it.
const FONT_SIZE_KEYS := ["font_size", "normal_font_size", "bold_font_size", "italics_font_size",
	"bold_italics_font_size", "mono_font_size"]
## A text colour and the button state whose box is behind it ("" the usual one).
const STATE_OF := {"font_color": "", "font_hover_color": "hover", "font_pressed_color": "pressed",
	"font_hover_pressed_color": "pressed", "font_focus_color": "", "font_disabled_color": "disabled",
	"default_color": ""}


static func _floor(c: Control) -> void:
	if _is_symbol(c):
		return
	var least: int = Look.Size("small")
	var to: int = Look.Size("label")
	if c is Button:
		to = Look.Size("body")
	elif c is TabContainer or c is TabBar:
		to = least   # a tab strip's titles: as small as allowed, so the tabs still fit
	for key in FONT_SIZE_KEYS:
		if c.has_theme_font_size_override(key) and c.get_theme_font_size(key) < least:
			c.add_theme_font_size_override(key, to)


static func _readable(c: Control) -> void:
	for key in STATE_OF:
		if not c.has_theme_color_override(key):
			continue
		var col: Color = c.get_theme_color(key)
		var bg: Color = Background(c, STATE_OF[key])
		var need: float = 3.0 if key == "font_disabled_color" else 4.5
		var seen := Color(lerpf(bg.r, col.r, col.a), lerpf(bg.g, col.g, col.a), lerpf(bg.b, col.b, col.a))
		if Look.Contrast(seen, bg) < need:
			c.add_theme_color_override(key, Look.Readable(col, bg, need))


## Text with no letter or digit in it: a mark, not words.
static func _is_symbol(c: Control) -> bool:
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	else:
		return false
	if t.strip_edges().is_empty():
		return false
	for ch in t:
		if ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			return false
	return true


## What is behind a control's words: the nearest background drawn at or above
## it - its own box or an ancestor's (a ColorRect, a panel's, a tab set's or a
## solid button's flat box; a textured one, or a document's drawn paper, is
## the paper), or a layer drawn under it (the sector plate's paper and wash) -
## else the chassis every window is drawn on. `state` is the button state whose
## box is behind the words ("normal", "hover", "pressed", "disabled").
static func Background(c: Control, state: String = "") -> Color:
	var n: Node = c
	while n != null and n is Control:
		var fill: Variant = _fill_of(n as Control, state if n == c else "")
		if fill != null:
			return fill
		var under: Variant = _layer_under(n as Control)
		if under != null:
			return under
		n = n.get_parent()
	return Look.C("chassis")


## A background layer drawn before `n` in its parent and covering its middle:
## a ColorRect (its colour) or a picture (the paper).
static func _layer_under(n: Control) -> Variant:
	var p: Node = n.get_parent()
	if p == null:
		return null
	var mid: Vector2 = n.get_global_rect().get_center()
	for i in range(n.get_index() - 1, -1, -1):
		var s: Node = p.get_child(i)
		if not (s is ColorRect or s is TextureRect or s is NinePatchRect) or not (s as Control).visible:
			continue
		if not (s as Control).get_global_rect().has_point(mid):
			continue
		if s is ColorRect:
			if (s as ColorRect).color.a >= 0.5:
				return (s as ColorRect).color
			continue
		return Look.C("paper")
	return null


static func _fill_of(c: Control, state: String = "") -> Variant:
	if c.has_meta("look_paper"):
		return Look.C("paper")
	if c is ColorRect:
		return (c as ColorRect).color if (c as ColorRect).color.a >= 0.5 else null
	var box: StyleBox = null
	if c is Button:
		var b := c as Button
		if b.flat:
			return null
		if state.is_empty():
			state = "normal"
			if b.disabled:
				state = "disabled"
			elif b.toggle_mode and b.button_pressed:
				state = "pressed"
		box = b.get_theme_stylebox(state)
	elif c is PanelContainer or c is Panel or c is TabContainer:
		box = c.get_theme_stylebox("panel")
	elif c is LineEdit:
		box = c.get_theme_stylebox("normal")
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		return flat.bg_color if flat.draw_center and flat.bg_color.a >= 0.5 else null
	if box is StyleBoxTexture:
		return Look.C("paper")
	return null


## A plain colour's token, alpha kept; the colour itself when it is none.
static func _map(table: Array, col: Color) -> Color:
	for row in table:
		var plain: Color = row[0]
		if absf(plain.r - col.r) <= TOLERANCE and absf(plain.g - col.g) <= TOLERANCE and absf(plain.b - col.b) <= TOLERANCE:
			var to := Look.C(str(row[1]))
			to.a = col.a
			return to
	return col


## Text: the table, and a playable side's colour for the look's (brighter,
## so it holds its contrast on the chassis).
static func _text(col: Color) -> Color:
	var mapped := _map(TEXT_MAP, col)
	if mapped != col:
		return mapped
	for f in FactionRegistry.Playable:
		var fc: Color = (f as Faction).FactionColor
		if absf(fc.r - col.r) <= TOLERANCE and absf(fc.g - col.g) <= TOLERANCE and absf(fc.b - col.b) <= TOLERANCE:
			var side := Look.SideColor(f)
			side.a = col.a
			return side
	return col
