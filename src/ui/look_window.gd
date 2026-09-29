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

## The windows made outside UIManager.OpenWindow, by their classes.
static func IsWindow(n: Node) -> bool:
	return n is DraggableWindow or n is BattleAlertWindow or n is BattleResultsWindow \
		or n is GalaxyOverviewWindow or n is ObjectivesWindow or n is GameOptionsWindow \
		or n is LoadGameWindow or n is AllGamesWindow

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
	Remap(w)


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
