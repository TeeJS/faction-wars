extends RefCounted
## THE MESSAGE WINDOW AS DISPATCHES (docs/ww2-look-plan.md, phase 4). For a
## pack with a look, the Comms Center's plain form is a ledger on the left and
## the message read as a dispatch on the right: parchment, the look's header
## word with the category's stamp, the subject in the display face, where and
## when, then the text and the actions. A category the look calls urgent
## (look.json `messages.urgent`: Conflict) carries a signal-red band on its row
## and across its dispatch. Nothing moves or flashes.
##
## Only the dress changes: picking, double-click, Go To, Continue / Abort
## Mission, Delete, Select All and Delete Selected Messages work as before.
## The window's own nodes keep their paths - message_window.gd finds the
## picture by PortraitPath - so the parchment is drawn under the detail column
## rather than wrapped round it, and the new pieces sit beside the scene's.
##
## Preloaded by path (as LookDispatch).

const LookWindow := preload("res://src/ui/look_window.gd")

## How far the parchment reaches past the detail column, each side.
const PaperPad := 14
## The signal band's depth across the top of an urgent dispatch.
const PaperBand := 6
const RowHeight := 52
const RowBand := 4
## How strongly the brass rule under each ledger row shows.
const RuleAlpha := 0.55


## The whole window: its frame, the ledger's well, the keys, the dispatch.
static func Dress(w: Control) -> void:
	if not Look.Active():
		return
	LookWindow.Dress(w)
	var area: MarginContainer = w.get_node_or_null("MainVBox/ContentArea")
	if area != null:
		for side in ["margin_top", "margin_right", "margin_bottom"]:
			area.add_theme_constant_override(side, PaperPad + 6)
	var split: HBoxContainer = w.get_node_or_null("MainVBox/ContentArea/SplitView")
	if split != null:
		split.add_theme_constant_override("separation", 15 + PaperPad)

	# The ledger: a recessed well the rows are ruled on.
	var tabs: TabContainer = w.get("_tabContainer")
	if tabs != null:
		tabs.add_theme_stylebox_override("panel", Look.Box("chassis_deep", "edge", 1, -1, 4))
	for b in [w.get("_selectAllBtn"), w.get("_deleteSelectedBtn")]:
		_command(b, "small")
	for b in [w.get("_gotoButton"), w.get("_continueBtn"), w.get("_abortBtn"), w.get("_deleteBtn"), w.get("_composeBtn")]:
		_command(b, "label")

	var detail: VBoxContainer = w.get_node_or_null("%DetailView")
	if detail == null:
		return
	detail.add_theme_constant_override("separation", 8)
	detail.set_meta("look_paper", Look.Paper(PaperPad))
	detail.draw.connect(_draw_paper.bind(detail))
	detail.resized.connect(detail.queue_redraw)

	# The header: the look's word for a dispatch, and the category's stamp.
	var head := HBoxContainer.new()
	head.name = "LookHead"
	var word := Label.new()
	word.name = "Header"
	word.theme_type_variation = Look.TYPED
	word.text = Look.DispatchHeader().to_upper()
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(word)
	var stamp := _stamp(true)
	head.add_child(stamp)
	detail.add_child(head)
	detail.move_child(head, 0)

	# The subject, then where and when, then a rule.
	var subject: Label = w.get("_detailSubject")
	if subject != null:
		subject.remove_theme_color_override("font_color")
		subject.remove_theme_font_size_override("font_size")
		subject.add_theme_font_override("font", Look.F("display"))
		subject.add_theme_font_size_override("font_size", Look.Size("heading") + 4)
		subject.add_theme_color_override("font_color", Look.C("ink"))
		detail.move_child(subject, 1)
	var meta := Label.new()
	meta.name = "LookMeta"
	meta.add_theme_font_override("font", Look.F("body"))
	meta.add_theme_font_size_override("font_size", Look.Size("label"))
	meta.add_theme_color_override("font_color", Look.C("ink_muted"))
	detail.add_child(meta)
	detail.move_child(meta, 2)
	var rule := HSeparator.new()
	rule.name = "LookRule"
	var line := StyleBoxLine.new()
	line.color = Look.C("ink_muted")
	line.thickness = 1
	rule.add_theme_stylebox_override("separator", line)
	detail.add_child(rule)
	detail.move_child(rule, 3)

	# The picture, when the message has one, mounted below the rule.
	var portrait: ColorRect = detail.get_node_or_null("PortraitRect")
	if portrait != null:
		portrait.color = Look.C("ink")
		detail.move_child(portrait, 4)

	# The text, in ink.
	var body: RichTextLabel = w.get("_detailBody")
	if body != null:
		body.remove_theme_font_size_override("normal_font_size")
		body.add_theme_color_override("default_color", Look.C("ink"))
		body.add_theme_font_override("normal_font", Look.F("body"))
		body.add_theme_font_override("bold_font", Look.F("body_bold"))
		body.add_theme_font_size_override("normal_font_size", Look.Size("body"))
		body.add_theme_font_size_override("bold_font_size", Look.Size("body"))
	Clear(w)


## Nothing picked: a blank dispatch, the window's own "Select a message..."
## on it; no stamp, no band, no picture.
static func Clear(w: Control) -> void:
	if not Look.Active():
		return
	var detail: Control = w.get_node_or_null("%DetailView")
	if detail == null or detail.get_node_or_null("LookHead") == null:
		return
	(detail.get_node("LookHead/Stamp") as Control).visible = false
	var meta: Label = detail.get_node("LookMeta")
	meta.text = ""
	meta.visible = false
	detail.set_meta("look_urgent", false)
	var portrait: Control = detail.get_node_or_null("PortraitRect")
	if portrait != null:
		portrait.visible = false
	detail.queue_redraw()


## A message read as a dispatch. After the window has filled it (ShowDetail).
static func Show(w: Control, m: GameMessage) -> void:
	if not Look.Active() or m == null:
		return
	var detail: Control = w.get_node_or_null("%DetailView")
	if detail == null or detail.get_node_or_null("LookHead") == null:
		return
	var cat: String = JsonUtil.enum_name(Enums.MessageCategory, m.Category)
	var urgent: bool = Look.Urgent(cat)
	var subject: Label = w.get("_detailSubject")
	if subject != null:
		subject.text = m.Title
	var meta: Label = detail.get_node("LookMeta")
	meta.text = WhereWhen(m, true)
	meta.visible = true
	_set_stamp(detail.get_node("LookHead/Stamp"), Look.Stamp(cat), urgent, true)
	detail.set_meta("look_urgent", urgent)
	var portrait: Control = detail.get_node_or_null("PortraitRect")
	if portrait != null:
		portrait.visible = portrait.get_node_or_null("Picture") != null
	detail.queue_redraw()


## "Britain, British Isles  ·  Day 12" on a dispatch; the theatre alone on a
## row. The theatre is the sector whose worlds include the message's (a
## world's own SectorId is not kept on every path: intel_manager.gd _RingOf).
## Just the day for a message about no world.
static func WhereWhen(m: GameMessage, full: bool) -> String:
	var day := "Day %d" % StrategicTickManager.Shown(m.DayReceived)
	var place := ""
	var loc: Variant = m.AssociatedLocation
	if loc is Planet:
		var planet: Planet = loc
		var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
		if sector == null:
			place = planet.Name
		elif full:
			place = "%s, %s" % [planet.Name, sector.Name]
		else:
			place = sector.Name
	elif loc is Sector:
		place = (loc as Sector).Name
	return day if place.is_empty() else "%s  ·  %s" % [place, day]


## A ledger row: the subject (bold until read), where and when under it, the
## category's stamp on the right, the signal band down the left of an urgent
## one. The row stays the window's toggle button; its words are drawn by
## labels the pointer passes through.
static func Row(btn: Button, m: GameMessage) -> void:
	if not Look.Active():
		return
	var cat: String = JsonUtil.enum_name(Enums.MessageCategory, m.Category)
	var urgent: bool = Look.Urgent(cat)
	btn.text = ""
	btn.theme_type_variation = Look.ROW
	btn.remove_theme_color_override("font_color")
	btn.remove_theme_font_size_override("font_size")
	btn.custom_minimum_size.y = RowHeight
	btn.set_meta("look_read", m.IsRead)
	btn.tooltip_text = m.Title
	if urgent:
		var band := ColorRect.new()
		band.name = "LookBand"
		band.color = Look.C("signal")
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		band.offset_right = RowBand
		btn.add_child(band)
	var box := HBoxContainer.new()
	box.name = "LookRow"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -8
	box.offset_top = 4
	box.offset_bottom = -5
	box.add_theme_constant_override("separation", 8)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	var subject := Label.new()
	subject.name = "Subject"
	subject.text = m.Title
	subject.clip_text = true
	subject.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subject.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(subject)
	var meta := Label.new()
	meta.name = "Meta"
	meta.text = WhereWhen(m, false)
	meta.clip_text = true
	meta.add_theme_font_size_override("font_size", Look.Size("small"))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(meta)
	box.add_child(lines)
	var word: String = Look.Stamp(cat)
	if not word.is_empty():
		var stamp := _stamp(false)
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(stamp)
		_set_stamp(stamp, word, urgent, false)
	btn.add_child(box)
	# A ruled line under every row, as a ledger's (TeeJ, 2026-09-30: "there is
	# no separation between lines").
	var rule := ColorRect.new()
	rule.name = "LookRule"
	rule.color = Color(Look.C("brass_dim"), RuleAlpha)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rule.offset_top = -1
	btn.add_child(rule)
	btn.toggled.connect(func(_on: bool) -> void: _paint_row(btn))
	_paint_row(btn)


## The row's message has been read (the window greys a plain row's text).
static func RowRead(btn: Button) -> void:
	if btn == null:
		return
	btn.set_meta("look_read", true)
	_paint_row(btn)


## Unread in the bold face; read in the regular one, muted. A picked row's
## fill is olive, where only the full text colour holds its contrast.
static func _paint_row(btn: Button) -> void:
	var subject: Label = btn.get_node_or_null("LookRow/Lines/Subject")
	if subject == null:
		return
	var read: bool = bool(btn.get_meta("look_read", false))
	var on: bool = btn.button_pressed
	subject.add_theme_font_override("font", Look.F("body" if read else "body_bold"))
	subject.add_theme_color_override("font_color", Look.C("text") if on or not read else Look.C("text_muted"))
	var meta: Label = btn.get_node("LookRow/Lines/Meta")
	meta.add_theme_color_override("font_color", Look.C("text") if on else Look.C("text_muted"))
	var stamp: PanelContainer = btn.get_node_or_null("LookRow/Stamp")
	if stamp != null and not bool(stamp.get_meta("urgent", false)):
		var ink: Color = Look.C("text") if on else Look.C("heading")
		(stamp.get_node("Word") as Label).add_theme_color_override("font_color", ink)
		(stamp.get_theme_stylebox("panel") as StyleBoxFlat).border_color = ink


## An empty category: the pack's words for it (Terms `no_messages`).
static func Empty(label: Label) -> void:
	if not Look.Active():
		return
	label.remove_theme_font_size_override("font_size")
	label.add_theme_font_size_override("font_size", Look.Size("body"))
	label.add_theme_color_override("font_color", Look.C("text_muted"))
	label.custom_minimum_size.y = 80
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func _stamp(on_paper: bool) -> PanelContainer:
	var stamp := PanelContainer.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.set_meta("paper", on_paper)
	var word := Label.new()
	word.name = "Word"
	word.add_theme_font_override("font", Look.F("typed_bold"))
	word.add_theme_font_size_override("font_size", Look.Size("label") if on_paper else Look.Size("small"))
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(word)
	return stamp


## A stamp's word and ink. Urgent: signal-red - a filled chip on the dark
## ledger, red ink on the parchment. Otherwise an outline in the surface's
## muted ink. Hidden with no word.
static func _set_stamp(stamp: PanelContainer, text: String, urgent: bool, on_paper: bool) -> void:
	stamp.visible = not text.is_empty()
	stamp.set_meta("urgent", urgent)
	var word: Label = stamp.get_node("Word")
	word.text = text.to_upper()
	var sb: StyleBoxFlat
	var ink: Color
	if urgent and not on_paper:
		sb = Look.Box("signal", "", 0, -1, 0)
		ink = Look.C("signal_text")
	else:
		ink = Look.C("signal") if urgent else Look.C("ink_muted" if on_paper else "heading")
		sb = Look.Box("", "", 0, -1, 0)
		sb.border_color = ink
		sb.set_border_width_all(2 if on_paper else 1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	stamp.add_theme_stylebox_override("panel", sb)
	word.add_theme_color_override("font_color", ink)


## The parchment under the detail column, past its edges by PaperPad; an
## urgent dispatch's signal band across its top.
static func _draw_paper(detail: Control) -> void:
	var paper: StyleBox = detail.get_meta("look_paper") if detail.has_meta("look_paper") else null
	if paper == null:
		return
	var r := Rect2(Vector2(-PaperPad, -PaperPad), detail.size + Vector2(2 * PaperPad, 2 * PaperPad))
	paper.draw(detail.get_canvas_item(), r)
	if bool(detail.get_meta("look_urgent", false)):
		detail.draw_rect(Rect2(r.position, Vector2(r.size.x, PaperBand)), Look.C("signal"))


static func _command(b: Variant, size: String) -> void:
	if not (b is Button):
		return
	var btn: Button = b
	btn.theme_type_variation = Look.COMMAND
	btn.remove_theme_font_size_override("font_size")
	btn.add_theme_font_size_override("font_size", Look.Size(size))
