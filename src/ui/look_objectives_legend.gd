extends Control
## THE OBJECTIVES ON THE MAP (TeeJ, 2026-09-30: "could we permanently put the
## objectives in the corner of the map where the key is, making it look like
## the key (color wise)?"). A pack's look may name where its map picture has
## its own printed legend (look.json `objectives_legend`). This sheet lies over
## that legend in its printed colours and layout: a title in spaced capitals,
## a line in brackets under it, then a column per side under its heading. It
## shows what the Objectives window shows (manual p136-p137, Fig. 3.84: "the
## current status of ALL THREE victory conditions FOR EACH SIDE"), the wording
## from VictoryManager.StatusFor. Each condition has a red box, ticked when
## met, where the legend has its red numerals. The Objectives window (ALT-H)
## is unchanged. Repainted when a condition changes. Added by GalaxyMap over
## its backdrop, so it moves and scales with the map.

const PollSeconds := 0.5
const Pad := 8.0
## The box a condition is marked in, and the space after it.
const MarkSize := 12.0

var _def: Dictionary = {}
var _shown: String = "-"
var _since: float = 0.0
var _body: VBoxContainer


## `def` is Look.ObjectivesLegend(); `fit` the map picture's scale on the map.
func Setup(def: Dictionary, fit: float) -> void:
	name = "ObjectivesLegend"
	_def = def
	var r: Rect2 = def["rect"]
	position = r.position * fit
	size = r.size * fit
	custom_minimum_size = size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.position = Vector2(Pad, Pad - 2.0)
	_body.size = size - Vector2(Pad * 2.0, Pad * 2.0 - 2.0)
	_body.add_theme_constant_override("separation", 1)
	add_child(_body)
	Refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _def["paper"])
	draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), _def["ink"], false, 1.0)


func _process(delta: float) -> void:
	_since += delta
	if _since < PollSeconds:
		return
	_since = 0.0
	if _signature() != _shown:
		Refresh()


## What the sheet shows, as one string: every side's conditions and whether
## each is met, and the winner.
func _signature() -> String:
	var parts: PackedStringArray = []
	for f in FactionRegistry.Playable:
		for e in VictoryManager.StatusFor(f, GameState.ActiveGalaxy):
			parts.append("%s=%s" % [e[0], e[1]])
	parts.append(VictoryManager.Winner.Id if VictoryManager.IsOver() and VictoryManager.Winner != null else "")
	return "|".join(parts)


func Refresh() -> void:
	_shown = _signature()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_body.add_child(_label("OBJECTIVES", Look.F("display"), Look.Size("heading"), _def["ink"], HORIZONTAL_ALIGNMENT_CENTER, 3))
	_body.add_child(_label("(VICTORY CONDITIONS FOR EACH SIDE)", Look.F("body"), Look.Size("small") - 2, _def["ink"], HORIZONTAL_ALIGNMENT_CENTER, 1))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(gap)

	var cols := HBoxContainer.new()
	cols.name = "Sides"
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	for f in FactionRegistry.Playable:
		var col := VBoxContainer.new()
		col.name = f.Id
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		cols.add_child(col)
		col.add_child(_label(f.DisplayName.to_upper(), Look.F("body"), Look.Size("label"), _def["ink"], HORIZONTAL_ALIGNMENT_CENTER, 1))
		for e in VictoryManager.StatusFor(f, GameState.ActiveGalaxy):
			col.add_child(_row(str(e[0]), bool(e[1])))

	if VictoryManager.IsOver() and VictoryManager.Winner != null:
		_body.add_child(_label("%s has won." % VictoryManager.Winner.DisplayName, Look.F("body_bold"), Look.Size("label"), _def["accent"], HORIZONTAL_ALIGNMENT_CENTER, 0))
	queue_redraw()


## One condition: its box, ticked when met, and its words.
func _row(text: String, met: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var mark := Control.new()
	mark.name = "Met" if met else "Open"
	mark.custom_minimum_size = Vector2(MarkSize, MarkSize)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent: Color = _def["accent"]
	mark.draw.connect(func() -> void:
		var b := Rect2(Vector2(0.5, 0.5), Vector2(MarkSize - 1.0, MarkSize - 1.0))
		mark.draw_rect(b, accent, false, 2.0)
		if met:
			mark.draw_polyline(PackedVector2Array([Vector2(2.5, 6.0), Vector2(5.0, 9.0), Vector2(10.0, 2.5)]), accent, 2.0, true))
	row.add_child(mark)
	var words := _label(text, Look.F("body"), Look.Size("body") - 1, _def["ink"], HORIZONTAL_ALIGNMENT_LEFT, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(words)
	return row


## A line of the legend's type; `spacing` spreads the letters as its title is.
func _label(text: String, font: Font, px: int, color: Color, align: HorizontalAlignment, spacing: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: Font = font
	if spacing > 0 and font != null:
		var v := FontVariation.new()
		v.base_font = font
		v.spacing_glyph = spacing
		face = v
	if face != null:
		l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -2)
	return l
