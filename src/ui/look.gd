class_name Look
extends RefCounted
## THE PACK'S LOOK (docs/ww2-look-plan.md; SCHEMA.md section 15). A pack may
## ship `look.json`: the colours, faces, sizes and textures its screens are
## drawn in. This builds ONE Godot Theme from those tokens - the base controls
## and one named variation per shared piece below - and is the only place a
## look's colour is decided.
##
## A pack WITHOUT look.json has no Look: Active() is false, Install() takes
## any theme off, Adopt() does nothing, and every scene keeps the colours it
## was drawn with. That is how the Star Wars pack stays pixel-identical.
##
## Presentation only: look.json is not one of FactionRegistry.PACK_FILES, so
## it never touches the content hash, a save or the simulation.

## Pictures and faces load the way the pack's other pictures do.
const Art := preload("res://src/ui/artwork.gd")

## THE SHARED PIECES (the charter's primitives). A scene tags a node with one of
## these as its theme_type_variation. With a Look installed the node wears it
## (Adopt strips the scene's own colours so the theme shows); without one the
## tag is inert and the scene's own colours stand.
const PANEL := &"LookPanel"            # a window body
const INSET := &"LookInset"            # a recessed well: lists, readouts
const TITLE_BAR := &"LookTitleBar"     # a window's bar (a Panel, or a ColorRect)
const TITLE := &"LookTitle"            # its label
const COMMAND := &"LookCommand"        # a console key, a dialog action
const RAIL := &"LookRail"              # a category on a rail: toggles, one selected
const ROW := &"LookRow"                # a list row: toggles, one selected
const HEADING := &"LookHeading"        # a section label in the display face
const DIVIDER := &"LookDivider"        # the brass rule (an HSeparator)
const CHIP := &"LookChip"              # day, speed, counts
const CHIP_ALERT := &"LookChipAlert"   # the urgent state of one
const DOCUMENT := &"LookDocument"      # parchment: dispatches, briefings, credits
const INK := &"LookInk"                # text on a document
const TYPED := &"LookTyped"            # a typed heading on a document
const MODAL := &"LookModal"            # a dialog's frame
const LAUNCH := &"LookLaunch"          # the Cockpit's launch plate
const PIECES := [PANEL, INSET, TITLE_BAR, TITLE, COMMAND, RAIL, ROW, HEADING, DIVIDER,
	CHIP, CHIP_ALERT, DOCUMENT, INK, TYPED, MODAL, LAUNCH]

## The pairs of tokens a reader must be able to tell apart, with the WCAG
## contrast each needs: 4.5 for text, 3 for large labels, UI edges and a
## disabled control's text. tests/look_system.gd checks every pack's look.
## A selected rail item or row is told from its neighbours by its brass edge,
## so brass is checked against the unselected fills around it.
const CONTRAST_PAIRS := [
	["text", "chassis", 4.5], ["text", "chassis_deep", 4.5], ["text", "chassis_raised", 4.5],
	["text", "chassis_hover", 4.5], ["text", "olive_deep", 4.5],
	["text_muted", "chassis", 4.5], ["text_muted", "chassis_deep", 4.5], ["text_muted", "chassis_raised", 4.5],
	["heading", "chassis", 4.5], ["heading", "chassis_deep", 4.5],
	["ink", "paper", 4.5], ["ink_muted", "paper", 4.5], ["ink", "paper_edge", 4.5],
	["note_ink", "note", 4.5], ["signal_text", "signal", 4.5], ["text", "signal", 4.5],
	["text_disabled", "chassis", 3.0], ["text_disabled", "chassis_raised", 3.0],
	["brass", "chassis", 3.0], ["brass", "chassis_deep", 3.0], ["brass", "chassis_raised", 3.0],
	["brass", "chassis_hover", 3.0],
	["brass_dim", "chassis", 3.0], ["ink", "khaki", 4.5],
	# The dispatches (phase 4): a ledger row under the pointer, a stamp's
	# word, an urgent stamp in red ink on the parchment.
	["text_muted", "chassis_hover", 4.5], ["heading", "chassis_hover", 4.5], ["signal", "paper", 4.5],
]

## When no size is given - the Godot default's, so a look that names none
## lays out as the scenes were drawn.
const DEFAULT_SIZES := {"body": 16, "small": 13, "label": 14, "title": 15, "heading": 18, "display": 34}
const DEFAULT_METRICS := {"radius": 0, "border": 1, "focus": 2, "pad": 8}

static var _built_for: String = ""      # "<pack id>|<dir>" the caches hold
static var _theme: Theme = null
static var _sheet: Theme = null         # the look for a dialog's order sheet
static var _fonts: Dictionary = {}      # role -> Font
static var _textures: Dictionary = {}   # name -> Texture2D or null
static var _insets: Variant = null      # MapInsets(), once loaded
static var _hooked: bool = false


## True when the loaded pack ships a look.
static func Active() -> bool:
	return FactionRegistry.Pack != null and not FactionRegistry.Pack.Look.is_empty()


static func _def() -> Dictionary:
	return FactionRegistry.Pack.Look if Active() else {}


## Clears the caches when the loaded pack changed (the picker's Unload).
static func _check() -> void:
	var key := "%s|%s" % [FactionRegistry.LoadedId() if FactionRegistry.Pack != null else "", Art._pack_dir()]
	if key != _built_for:
		_built_for = key
		_theme = null
		_sheet = null
		_fonts.clear()
		_textures.clear()
		_insets = null


## A colour token. Magenta when the pack has no look or no such token - a
## caller that asks without checking Active() shows up at once.
static func C(token: String) -> Color:
	var colors: Dictionary = _def().get("colors", {})
	return Color.html(str(colors[token])) if colors.has(token) else Color.MAGENTA


## A side's colour in the chrome: the look's `sides`, else factions.json's.
static func SideColor(faction: Faction) -> Color:
	if faction == null:
		return C("text")
	var sides: Dictionary = _def().get("sides", {})
	return Color.html(str(sides[faction.Id])) if sides.has(faction.Id) else faction.FactionColor


static func Size(name: String) -> int:
	return int(_def().get("sizes", {}).get(name, DEFAULT_SIZES.get(name, 16)))


static func Metric(name: String) -> int:
	return int(_def().get("metrics", {}).get(name, DEFAULT_METRICS.get(name, 0)))


## The Cockpit's dossier facts: `subtitle`, `map_rect` ([x, y, w, h] in the
## map picture's pixels), `map_caption`. {} without them.
static func Dossier() -> Dictionary:
	return _def().get("dossier", {})


## The message window's dispatch words (look.json `messages`): the word over
## each dispatch ("" for none).
static func DispatchHeader() -> String:
	return str(_def().get("messages", {}).get("header", ""))


## The small stamp for a message category (its enum name: "Fleets",
## "Missions", ...), or "" for none.
static func Stamp(category: String) -> String:
	return str(_def().get("messages", {}).get("stamps", {}).get(category, ""))


## Whether a message category carries the signal-red band.
static func Urgent(category: String) -> bool:
	return (_def().get("messages", {}).get("urgent", []) as Array).has(category)


## Hold still: the player's Reduce motion box, or the browser's own
## prefers-reduced-motion. Nothing in a look may move when this is true.
static func ReducedMotion() -> bool:
	if GameSettings.ReduceMotion:
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches", true)
		return r == true
	return false


## The dim laid over the map behind a dialog.
static func Dim() -> Color:
	var c := C("overlay")
	c.a = float(_def().get("overlay_alpha", 0.55))
	return c


## A face by role (display, display_bold, body, body_bold, typed, typed_bold):
## the look's file at its weight, tabular figures where it asks. Falls back to
## the body face, then the engine's.
static func F(role: String) -> Font:
	_check()
	if _fonts.has(role):
		return _fonts[role]
	var faces: Dictionary = _def().get("fonts", {})
	var font: Font = null
	if faces.has(role):
		var face: Dictionary = faces[role]
		var file: Font = _load_font(str(face.get("file", "")))
		if file != null:
			var v := FontVariation.new()
			v.base_font = file
			var ts := TextServerManager.get_primary_interface()
			if face.has("weight"):
				v.variation_opentype = {ts.name_to_tag("wght"): int(face["weight"])}
			if bool(face.get("tabular", false)):
				v.opentype_features = {ts.name_to_tag("tnum"): 1}
			font = v
	if font == null and role != "body":
		font = F("body")
	if font == null:
		font = ThemeDB.fallback_font
	_fonts[role] = font
	return font


## A face is drawn as a distance field (TeeJ, 2026-09-30: "text on this
## screen still getting too thin in places", the Economy window's
## "Destination"). The game is drawn at the window's size - in a browser
## rarely a whole multiple of 1440x850 - and a face rasterised at that scale
## lost the thin stems of its i's and t's and spaced its letters unevenly
## ("Destinat ion"). A distance field keeps the letter's shape at any scale.
## Its pixel range is twice the widest outline drawn with it (Godot's rule
## for outlines on a distance field) and more: the map marks' ink rim, a
## fifth of the mark - 9 px on the 46 px flare (galaxy_map.gd Place).
const FontPixelRange := 20

static func _load_font(rel: String) -> Font:
	if rel.is_empty():
		return null
	var path := "%s/%s" % [Art._pack_dir(), rel]
	var f: FontFile = null
	if path.begins_with("res://"):
		if not ResourceLoader.exists(path):
			return null
		var imported: FontFile = load(path) as FontFile
		f = imported.duplicate() as FontFile if imported != null else null
	elif FileAccess.file_exists(path):
		f = FontFile.new()
		f.data = FileAccess.get_file_as_bytes(path)
	if f == null or f.data.is_empty():
		return null
	f.multichannel_signed_distance_field = true
	f.msdf_pixel_range = FontPixelRange
	return f


## A texture by name (paper, paper_frame, desk, grain, rule), or null.
static func Tex(name: String) -> Texture2D:
	_check()
	if _textures.has(name):
		return _textures[name]
	var t: Variant = _def().get("textures", {}).get(name)
	var rel := str(t.get("file", "")) if t is Dictionary else (str(t) if t != null else "")
	var tex: Texture2D = Art._load("%s/%s" % [Art._pack_dir(), rel]) if not rel.is_empty() else null
	_textures[name] = tex
	return tex


## The sector plates' sharper insets (look.json `map_insets`): each
## {"texture": Texture2D, "at": Rect2 in map units} - a larger-scale map of part
## of the world, lined up with the pack's map. An inset whose picture is
## missing is left out. [] without any.
static func MapInsets() -> Array:
	_check()
	if _insets != null:
		return _insets
	var out: Array = []
	for m in _def().get("map_insets", []):
		var r: Array = m.get("at", [])
		var rel := str(m.get("image", ""))
		var tex: Texture2D = Art._load("%s/%s" % [Art._pack_dir(), rel]) if not rel.is_empty() else null
		if tex != null and r.size() == 4:
			out.append({"texture": tex, "at": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))})
	_insets = out
	return out


static func TexMargin(name: String) -> int:
	var t: Variant = _def().get("textures", {}).get(name)
	return int(t.get("margin", 0)) if t is Dictionary else 0


## The objectives on the map (look.json `objectives_legend`): where the map
## picture's own legend is, in its pixels, and the legend's printed colours -
## {"rect": Rect2, "paper": Color, "ink": Color, "accent": Color}; a colour
## left out is the look's paper, ink or signal. {} without one.
static func ObjectivesLegend() -> Dictionary:
	var d: Variant = _def().get("objectives_legend")
	if not d is Dictionary or not (d as Dictionary).get("rect") is Array or (d["rect"] as Array).size() != 4:
		return {}
	var r: Array = d["rect"]
	return {
		"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
		"paper": Color.html(str(d["paper"])) if d.has("paper") else C("paper"),
		"ink": Color.html(str(d["ink"])) if d.has("ink") else C("ink"),
		"accent": Color.html(str(d["accent"])) if d.has("accent") else C("signal"),
	}


## WCAG 2 contrast ratio of two colours, 1 to 21.
## `fg` made readable on `bg`: moved towards white on a dark ground, or black
## on a light one, a step at a time until it reaches `ratio`, so a side's or a
## state's colour keeps its hue. Opaque, since a see-through colour is what
## faded it.
static func Readable(fg: Color, bg: Color, ratio: float = 4.5) -> Color:
	var out := fg
	out.a = 1.0
	var dark_ground: bool = _luminance(bg) < 0.18
	var guard := 0
	while Contrast(out, bg) < ratio and guard < 30:
		out = out.lightened(0.07) if dark_ground else out.darkened(0.07)
		guard += 1
	return out


static func Contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var ch := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


# ---------------------------------------------------------------------------
# Style boxes - the pieces are built from these, and a later screen that needs
# one of the same family asks here rather than making its own.
# ---------------------------------------------------------------------------

## A flat box: `fill` and `edge` are tokens ("" for none).
static func Box(fill: String, edge: String = "", width: int = -1, radius: int = -1, pad: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = not fill.is_empty()
	if not fill.is_empty():
		sb.bg_color = C(fill)
	if not edge.is_empty():
		sb.border_color = C(edge)
		sb.set_border_width_all(Metric("border") if width < 0 else width)
	sb.set_corner_radius_all(Metric("radius") if radius < 0 else radius)
	sb.set_content_margin_all(float(Metric("pad") if pad < 0 else pad))
	sb.anti_aliasing = false
	return sb


## An edge on one side only (left, top, right, bottom) in `edge`, the rest none.
static func Edged(fill: String, edge: String, side: int, width: int, pad: int = -1) -> StyleBoxFlat:
	var sb := Box(fill, "", 0, -1, pad)
	sb.border_color = C(edge)
	sb.set_border_width(side, width)
	return sb


## A folder tab: `fill`, outlined in `edge` along its top (`top` px) and
## sides, with no bottom edge so it opens into its page; rounded top corners;
## drawn a pixel in on each side, so neighbouring tabs stand 2 px apart.
static func _FolderTab(fill: String, edge: String, top: int) -> StyleBoxFlat:
	var sb := Box(fill, "", 0, -1, 6)
	sb.border_color = C(edge)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = top
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.expand_margin_left = -1
	sb.expand_margin_right = -1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


## The focus ring: brass, no fill, standing 3 px clear of the control so it
## reads as "keyboard here", never as the control's own pressed edge.
static func FocusRing() -> StyleBoxFlat:
	var sb := Box("", "brass", Metric("focus"), -1, 0)
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	return sb


## The parchment surface: the nine-slice when the look ships one (texture on
## the edges only, a flat centre under the text), else flat paper.
static func Paper(pad: int = 14) -> StyleBox:
	var frame := Tex("paper_frame")
	if frame == null:
		var flat := Box("paper", "paper_edge", 1, -1, pad)
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = frame
	var m := float(TexMargin("paper_frame"))
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	sb.set_content_margin_all(float(pad))
	return sb


## The brass rule, for a divider.
static func Rule() -> StyleBox:
	var tex := Tex("rule")
	if tex == null:
		var line := StyleBoxLine.new()
		line.color = C("brass_dim")
		line.thickness = 1
		return line
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	# A separator draws its style at the style's minimum height: the rule's.
	sb.content_margin_top = 1
	sb.content_margin_bottom = float(tex.get_height() - 1)
	return sb


# ---------------------------------------------------------------------------
# The theme
# ---------------------------------------------------------------------------

## The look's Theme, or null without one.
static func GetTheme() -> Theme:
	if not Active():
		return null
	_check()
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = F("body")
	t.default_font_size = Size("body")

	# --- The base controls: everything a scene did not colour itself. ---
	var key := Box("chassis_raised", "edge", -1, -1, 6)
	var key_hover := Box("chassis_hover", "brass_dim", -1, -1, 6)
	var key_down := Box("olive_deep", "brass", -1, -1, 6)
	var key_off := Box("chassis", "edge", -1, -1, 6)
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		if type == "Button" or type == "OptionButton" or type == "MenuButton":
			t.set_stylebox("normal", type, key)
			t.set_stylebox("hover", type, key_hover)
			t.set_stylebox("pressed", type, key_down)
			t.set_stylebox("hover_pressed", type, key_down)
			t.set_stylebox("disabled", type, key_off)
		t.set_stylebox("focus", type, FocusRing())
		t.set_color("font_color", type, C("text"))
		t.set_color("font_hover_color", type, C("text"))
		t.set_color("font_pressed_color", type, C("text"))
		t.set_color("font_hover_pressed_color", type, C("text"))
		t.set_color("font_focus_color", type, C("text"))
		t.set_color("font_disabled_color", type, C("text_disabled"))

	# A check box is a Button to the theme: without its own boxes it would
	# wear the key's frame. Its box is its icon; the row lights under the pointer.
	for type in ["CheckBox", "CheckButton"]:
		var bare := Box("", "", 0, 0, 4)
		for style in ["normal", "pressed", "disabled", "hover_pressed"]:
			t.set_stylebox(style, type, bare)
		t.set_stylebox("hover", type, Box("chassis_hover", "", 0, -1, 4))

	t.set_color("font_color", "Label", C("text"))
	t.set_color("default_color", "RichTextLabel", C("text"))
	t.set_font("normal_font", "RichTextLabel", F("body"))
	t.set_font("bold_font", "RichTextLabel", F("body_bold"))

	var body := Box("chassis", "edge")
	t.set_stylebox("panel", "Panel", body)
	t.set_stylebox("panel", "PanelContainer", body)

	# Menus: an instrument panel, the row under the pointer in olive.
	t.set_stylebox("panel", "PopupMenu", Box("chassis_deep", "brass_dim", -1, -1, 4))
	t.set_stylebox("hover", "PopupMenu", Box("olive_deep", "", 0, 0, 2))
	var sep := StyleBoxLine.new()
	sep.color = C("brass_dim")
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", C("text"))
	t.set_color("font_hover_color", "PopupMenu", C("text"))
	t.set_color("font_disabled_color", "PopupMenu", C("text_disabled"))
	t.set_color("font_separator_color", "PopupMenu", C("heading"))
	t.set_color("font_accelerator_color", "PopupMenu", C("text_muted"))

	# Tooltips: a small, high-contrast field note.
	t.set_stylebox("panel", "TooltipPanel", Box("note", "brass_dim", 1, -1, 6))
	t.set_color("font_color", "TooltipLabel", C("note_ink"))
	t.set_font("font", "TooltipLabel", F("body"))
	t.set_font_size("font_size", "TooltipLabel", Size("small"))

	# Text entry, lists, tabs, scroll bars, rules, progress.
	t.set_stylebox("normal", "LineEdit", Box("chassis_deep", "edge", -1, -1, 6))
	t.set_stylebox("focus", "LineEdit", Box("", "brass", Metric("focus"), -1, 6))
	t.set_stylebox("read_only", "LineEdit", Box("chassis", "edge", -1, -1, 6))
	t.set_color("font_color", "LineEdit", C("text"))
	t.set_color("font_placeholder_color", "LineEdit", C("text_muted"))
	t.set_color("caret_color", "LineEdit", C("brass"))
	t.set_color("selection_color", "LineEdit", C("olive_deep"))

	t.set_stylebox("panel", "ItemList", Box("chassis_deep", "edge", -1, -1, 4))
	t.set_stylebox("focus", "ItemList", FocusRing())
	t.set_stylebox("hovered", "ItemList", Box("chassis_hover", "", 0, -1, 2))
	t.set_stylebox("selected", "ItemList", Edged("olive_deep", "brass", SIDE_LEFT, 3, 2))
	t.set_stylebox("selected_focus", "ItemList", Edged("olive_deep", "brass", SIDE_LEFT, 3, 2))
	t.set_color("font_color", "ItemList", C("text"))
	t.set_color("font_hovered_color", "ItemList", C("text"))
	t.set_color("font_selected_color", "ItemList", C("text"))

	# FOLDER TABS (TeeJ, 2026-09-30: "the separation between the tabs ... are
	# not distinct enough - it's hard to tell they are tabs"): every tab its
	# own outlined card with rounded top corners and a gap to the next; the
	# chosen one olive under a heavy brass top edge, open into the page below;
	# a hovered one lifted and brass-edged; an empty one flat, its words grey.
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, _FolderTab("olive_deep", "brass", 3))
		t.set_stylebox("tab_unselected", type, _FolderTab("chassis_raised", "edge", 1))
		t.set_stylebox("tab_hovered", type, _FolderTab("chassis_hover", "brass_dim", 1))
		t.set_stylebox("tab_disabled", type, _FolderTab("chassis_deep", "edge", 1))
		t.set_stylebox("tab_focus", type, FocusRing())
		t.set_color("font_selected_color", type, C("text"))
		t.set_color("font_unselected_color", type, C("text_muted"))
		t.set_color("font_hovered_color", type, C("text"))
		t.set_color("font_disabled_color", type, C("text_disabled"))
	t.set_stylebox("panel", "TabContainer", Box("chassis", "edge"))

	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, Box("chassis_deep", "", 0, 0, 0))
		t.set_stylebox("grabber", type, Box("brass_dim", "", 0, -1, 0))
		t.set_stylebox("grabber_highlight", type, Box("brass", "", 0, -1, 0))
		t.set_stylebox("grabber_pressed", type, Box("brass", "", 0, -1, 0))

	t.set_stylebox("separator", "HSeparator", Rule())
	t.set_constant("separation", "HSeparator", 6)
	var upright := StyleBoxLine.new()
	upright.vertical = true
	upright.color = C("brass_dim")
	upright.thickness = 1
	upright.grow_begin = -6
	upright.grow_end = -6
	t.set_stylebox("separator", "VSeparator", upright)
	t.set_constant("separation", "VSeparator", 12)

	t.set_stylebox("background", "ProgressBar", Box("chassis_deep", "edge", -1, -1, 0))
	t.set_stylebox("fill", "ProgressBar", Box("khaki", "", 0, -1, 0))
	t.set_color("font_color", "ProgressBar", C("text"))

	# Dialogs: an order sheet in a steel frame.
	t.set_stylebox("panel", "AcceptDialog", Box("chassis", "", 0, 0, 12))
	var frame := Box("chassis", "brass_dim", 1, -1, 0)
	frame.expand_margin_top = 28
	frame.expand_margin_left = 1
	frame.expand_margin_right = 1
	frame.expand_margin_bottom = 1
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_font("title_font", "Window", F("display"))
	t.set_font_size("title_font_size", "Window", Size("title"))
	t.set_color("title_color", "Window", C("text"))
	t.set_constant("title_height", "Window", 28)

	# --- The shared pieces. ---
	# A window body: flush, so its title bar meets the frame; its content
	# carries its own margin.
	_variation(t, PANEL, "PanelContainer")
	t.set_stylebox("panel", PANEL, Box("chassis", "brass_dim", -1, -1, 0))

	_variation(t, INSET, "PanelContainer")
	t.set_stylebox("panel", INSET, Box("chassis_deep", "edge", -1, -1, 6))

	_variation(t, TITLE_BAR, "Panel")
	t.set_stylebox("panel", TITLE_BAR, Edged("chassis_deep", "brass_dim", SIDE_BOTTOM, 1, 4))
	t.set_color("bg", TITLE_BAR, C("chassis_deep"))

	_variation(t, TITLE, "Label")
	t.set_font("font", TITLE, F("display"))
	t.set_font_size("font_size", TITLE, Size("title"))
	t.set_color("font_color", TITLE, C("text"))

	_variation(t, COMMAND, "Button")
	var cmd := Box("chassis_raised", "edge", -1, -1, 8)
	cmd.border_width_bottom = 2
	cmd.border_color = C("chassis_deep")
	var cmd_hover := Box("chassis_hover", "brass_dim", -1, -1, 8)
	cmd_hover.border_width_bottom = 2
	var cmd_down := Box("olive_deep", "brass", -1, -1, 8)
	cmd_down.border_width_bottom = 2
	t.set_stylebox("normal", COMMAND, cmd)
	t.set_stylebox("hover", COMMAND, cmd_hover)
	t.set_stylebox("pressed", COMMAND, cmd_down)
	t.set_stylebox("hover_pressed", COMMAND, cmd_down)
	t.set_stylebox("disabled", COMMAND, key_off)
	t.set_font("font", COMMAND, F("display"))
	t.set_font_size("font_size", COMMAND, Size("label"))

	_variation(t, RAIL, "Button")
	t.set_stylebox("normal", RAIL, Box("chassis_raised", "", 0, -1, 6))
	t.set_stylebox("hover", RAIL, Box("chassis_hover", "", 0, -1, 6))
	var rail_on := Edged("olive_deep", "brass", SIDE_LEFT, 4, 6)
	rail_on.border_width_right = 1
	rail_on.border_width_top = 1
	rail_on.border_width_bottom = 1
	t.set_stylebox("pressed", RAIL, rail_on)
	t.set_stylebox("hover_pressed", RAIL, rail_on)
	t.set_stylebox("disabled", RAIL, key_off)
	t.set_font("font", RAIL, F("display"))
	t.set_font_size("font_size", RAIL, Size("label"))

	_variation(t, ROW, "Button")
	# A list row: a hairline under it, as a ruled ledger.
	var row := Edged("", "edge", SIDE_BOTTOM, 1, 4)
	row.set_corner_radius_all(0)
	t.set_stylebox("normal", ROW, row)
	t.set_stylebox("hover", ROW, Box("chassis_hover", "", 0, 0, 4))
	t.set_stylebox("pressed", ROW, Edged("olive_deep", "brass", SIDE_LEFT, 3, 4))
	t.set_stylebox("hover_pressed", ROW, Edged("olive_deep", "brass", SIDE_LEFT, 3, 4))
	t.set_stylebox("disabled", ROW, row)
	t.set_color("font_color", ROW, C("text"))
	t.set_color("font_hover_color", ROW, C("text"))

	_variation(t, HEADING, "Label")
	t.set_font("font", HEADING, F("display"))
	t.set_font_size("font_size", HEADING, Size("heading"))
	t.set_color("font_color", HEADING, C("heading"))

	_variation(t, DIVIDER, "HSeparator")
	t.set_stylebox("separator", DIVIDER, Rule())

	_variation(t, CHIP, "PanelContainer")
	t.set_stylebox("panel", CHIP, Box("chassis_deep", "edge", -1, -1, 4))
	_variation(t, CHIP_ALERT, "PanelContainer")
	t.set_stylebox("panel", CHIP_ALERT, Box("signal", "", 0, -1, 4))

	_variation(t, DOCUMENT, "PanelContainer")
	t.set_stylebox("panel", DOCUMENT, Paper())
	_variation(t, INK, "Label")
	t.set_color("font_color", INK, C("ink"))
	t.set_font("font", INK, F("body"))
	_variation(t, TYPED, "Label")
	t.set_color("font_color", TYPED, C("ink"))
	t.set_font("font", TYPED, F("typed_bold"))
	t.set_font_size("font_size", TYPED, Size("label"))

	_variation(t, MODAL, "PanelContainer")
	t.set_stylebox("panel", MODAL, Box("chassis", "brass_dim", 1, -1, 12))

	_variation(t, LAUNCH, "Button")
	var plate := Box("olive_deep", "brass", 2, -1, 14)
	var plate_hover := Box("olive", "brass", 2, -1, 14)
	t.set_stylebox("normal", LAUNCH, plate)
	t.set_stylebox("hover", LAUNCH, plate_hover)
	t.set_stylebox("pressed", LAUNCH, plate_hover)
	t.set_stylebox("hover_pressed", LAUNCH, plate_hover)
	t.set_stylebox("disabled", LAUNCH, key_off)
	t.set_font("font", LAUNCH, F("display_bold"))
	t.set_font_size("font_size", LAUNCH, Size("heading"))
	return t


static func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.set_type_variation(name, base)


## A DIALOG AS AN ORDER SHEET (phase 5): the look, with the body parchment and
## the words on it in ink. The frame, the title and the keys stay steel.
static func SheetTheme() -> Theme:
	if not Active():
		return null
	_check()
	if _sheet != null:
		return _sheet
	var t: Theme = GetTheme().duplicate()
	t.set_stylebox("panel", "AcceptDialog", Paper(14))
	t.set_color("font_color", "Label", C("ink"))
	t.set_color("default_color", "RichTextLabel", C("ink"))
	# A check box sits bare on the sheet: its words in ink, lit under the
	# pointer by the paper's own edge colour.
	for type in ["CheckBox", "CheckButton"]:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, type, C("ink"))
		t.set_color("font_disabled_color", type, C("ink_muted"))
		t.set_stylebox("hover", type, Box("paper_edge", "", 0, -1, 4))
	t.set_color("font_color", "LinkButton", C("ink"))
	t.set_color("font_hover_color", "LinkButton", C("ink"))
	_sheet = t
	return _sheet


# ---------------------------------------------------------------------------
# Installing it
# ---------------------------------------------------------------------------

## Put the loaded pack's look on the whole tree - or take any off, for a pack
## without one. Idempotent; each scene that can be a first scene calls it.
static func Install(tree: SceneTree) -> void:
	var theme := GetTheme()
	tree.root.theme = theme
	if theme != null and not _hooked:
		tree.node_added.connect(_on_node_added)
		_hooked = true
	elif theme == null and _hooked:
		tree.node_added.disconnect(_on_node_added)
		_hooked = false
	if theme != null:
		AdoptTree(tree.root)


## The meta a tagged node carries when its overrides are the look's own, so
## Adopt keeps them.
const OWN_COLOURS := &"look_own_colours"


static func _on_node_added(node: Node) -> void:
	if node is Control and String((node as Control).theme_type_variation).begins_with("Look"):
		# After the node's own _ready, which is where scenes set their colours.
		Adopt.call_deferred(node)


## A tagged node wears its piece: the colours, styles and faces the scene gave
## it are taken off so the theme's show. Sizes and constants stay - they are
## the layout. A ColorRect (a scene's title bar) takes the piece's `bg`.
static func Adopt(node: Node) -> void:
	if not Active() or not is_instance_valid(node) or not node is Control:
		return
	var c := node as Control
	var v := StringName(c.theme_type_variation)
	if not String(v).begins_with("Look"):
		return
	# Colours the look itself gave it (a finder row's side colour): its own.
	if c.has_meta(OWN_COLOURS):
		return
	for p in c.get_property_list():
		var n: String = p.name
		if n.begins_with("theme_override_colors/"):
			c.remove_theme_color_override(n.get_slice("/", 1))
		elif n.begins_with("theme_override_styles/"):
			c.remove_theme_stylebox_override(n.get_slice("/", 1))
		elif n.begins_with("theme_override_fonts/"):
			c.remove_theme_font_override(n.get_slice("/", 1))
	var theme := GetTheme()
	if c is ColorRect and theme != null and theme.has_color("bg", v):
		(c as ColorRect).color = theme.get_color("bg", v)


static func AdoptTree(root: Node) -> void:
	Adopt(root)
	for child in root.get_children():
		AdoptTree(child)


# ---------------------------------------------------------------------------
# Menus, dialogs and tooltips (phase 5)
# ---------------------------------------------------------------------------

## Above the briefing (ui_manager BriefingLayer 100), below every embedded
## window (Godot draws those at 1024).
const DIM_LAYER := 120

static var _popups_hooked: bool = false


## EVERY MENU, DIALOG AND TOOLTIP IN THE LOOK, wherever it is made: a popup
## menu is an instrument panel, a dialog an order sheet (SheetTheme) over the
## dimmed screen when it is modal, a tooltip a field note. One hook on the
## tree rather than one per call site - the game makes them in forty places.
## Only while a look is active (checked as each one appears), so the Star Wars
## pack's popups are untouched. Idempotent.
static func InstallPopups(tree: SceneTree) -> void:
	if tree == null:
		return
	if not _popups_hooked:
		tree.node_added.connect(_on_popup_added)
		_popups_hooked = true
	# The ones a screen made before it called this (the speed menu).
	_sweep_popups(tree.root)


static func _sweep_popups(node: Node) -> void:
	for c in node.get_children(true):
		_on_popup_added(c)
		_sweep_popups(c)


static func _on_popup_added(node: Node) -> void:
	if not Active() or not node is Window:
		return
	var w := node as Window
	if node is AcceptDialog:
		if w.theme == null:
			w.theme = SheetTheme()
		var keys: Array = [(node as AcceptDialog).get_ok_button()]
		if node is ConfirmationDialog:
			keys.append((node as ConfirmationDialog).get_cancel_button())
		for b in keys:
			if b != null:
				(b as Button).theme_type_variation = COMMAND
		if not w.has_meta("look_dim_hooked"):
			w.set_meta("look_dim_hooked", true)
			w.visibility_changed.connect(_sync_dim.bind(w))
			w.tree_exiting.connect(_drop_dim.bind(w))
			_sync_dim(w)
	elif node is Popup and w.theme == null:
		w.theme = GetTheme()


## A modal dialog's dim: shown with it, gone with it. Only drawn - it takes no
## clicks, so nothing a dialog allowed before is blocked by it.
static func _sync_dim(w: Window) -> void:
	if not is_instance_valid(w) or not w.is_inside_tree():
		return
	var layer: CanvasLayer = w.get_meta("look_dim") if w.has_meta("look_dim") else null
	var want: bool = w.visible and w.exclusive and Active()
	if want and (layer == null or not is_instance_valid(layer)):
		layer = CanvasLayer.new()
		layer.name = "LookDim"
		layer.layer = DIM_LAYER
		var shade := ColorRect.new()
		shade.name = "Shade"
		shade.color = Dim()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(shade)
		w.get_tree().root.add_child.call_deferred(layer)
		w.set_meta("look_dim", layer)
	if layer != null and is_instance_valid(layer):
		layer.visible = want


static func _drop_dim(w: Window) -> void:
	if w.has_meta("look_dim"):
		var layer: Variant = w.get_meta("look_dim")
		if layer is Node and is_instance_valid(layer):
			(layer as Node).queue_free()
		w.remove_meta("look_dim")
