class_name CreditsWindow
extends PanelContainer
## "View credits" on the Shuttle Cockpit (manual p021, Fig. 2.2). The lines are
## the pack's (`menu.credits`, else `credits`, in pack.json) - who made the setting is content,
## not engine. Built in code (repo convention), shown as a centered modal overlay.
##
## A pack with a look (SCHEMA.md section 15) gets the CREDITS SHEET instead: a
## parchment document over the dimmed desk, the same lines, then "Artwork and
## fonts" - every picture and font the pack and the engine ship, from the
## credits.json files (section 16): what it is, who made it, its licence and
## where it came from, each link openable. In the browser a link opens a new
## tab; on the desktop it is the address with a Copy button, because the game
## starts no other program (the pack picker's convention).

const ENGINE_CREDITS := "res://assets/credits.json"


func _init(title: String = "", lines: Array[String] = []) -> void:
	name = "CreditsWindow"
	if Look.Active():
		_build_sheet(title, lines)
		return
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(420, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var head := Label.new()
	head.name = "Title"
	head.text = "Credits" if title.is_empty() else "%s - Credits" % title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	box.add_child(head)

	var body := VBoxContainer.new()
	body.name = "Lines"
	body.add_theme_constant_override("separation", 4)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
	if lines.is_empty():
		var l := Label.new()
		l.text = "(this pack declares no credits)"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
	box.add_child(body)

	var close := Button.new()
	close.name = "BtnClose"
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	box.add_child(close)


func _ready() -> void:
	if has_meta("sheet"):
		return
	# Centre once the contents have a size.
	await get_tree().process_frame
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)


# ---------------------------------------------------------------------------
# The Credits sheet (a pack with a look)
# ---------------------------------------------------------------------------

func _build_sheet(title: String, lines: Array[String]) -> void:
	set_meta("sheet", true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Look.Dim()
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # the desk behind is not live
	add_child(dim)
	var center := CenterContainer.new()
	add_child(center)
	var sheet := PanelContainer.new()
	sheet.name = "Sheet"
	sheet.theme_type_variation = Look.DOCUMENT
	sheet.custom_minimum_size = Vector2(880, 0)
	center.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)

	var kicker := Label.new()
	kicker.text = "CREDITS"
	kicker.theme_type_variation = Look.TYPED
	v.add_child(kicker)
	var head := Label.new()
	head.name = "Title"
	head.text = (title if not title.is_empty() else "Faction Wars").to_upper()
	_ink(head, Look.F("display_bold"), Look.Size("heading") + 10, "ink")
	v.add_child(head)
	v.add_child(_rule())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(840, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	var box := VBoxContainer.new()
	box.name = "Lines"
	box.add_theme_constant_override("separation", 4)
	for line in lines:
		box.add_child(_para(line, "ink"))
	if lines.is_empty():
		box.add_child(_para("(this pack declares no credits)", "ink_muted"))
	body.add_child(box)

	var pack_assets: Array = FactionRegistry.Pack.AssetCredits if FactionRegistry.Pack != null else []
	var engine: Variant = JsonUtil.parse(ENGINE_CREDITS)
	var engine_assets: Array = engine.get("assets", []) if engine is Dictionary else []
	var assets := VBoxContainer.new()
	assets.name = "Assets"
	assets.add_theme_constant_override("separation", 14)
	body.add_child(_rule())
	body.add_child(_section("Artwork and fonts"))
	for a in pack_assets:
		if a is Dictionary:
			assets.add_child(_entry(a))
	body.add_child(assets)
	if not engine_assets.is_empty():
		body.add_child(_rule())
		body.add_child(_section("Faction Wars"))
		var eng := VBoxContainer.new()
		eng.name = "EngineAssets"
		eng.add_theme_constant_override("separation", 14)
		for a in engine_assets:
			if a is Dictionary:
				eng.add_child(_entry(a))
		body.add_child(eng)

	var foot := HBoxContainer.new()
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var close := Button.new()
	close.name = "BtnClose"
	close.text = "Close"
	close.theme_type_variation = Look.COMMAND
	close.custom_minimum_size = Vector2(130, 40)
	close.pressed.connect(queue_free)
	foot.add_child(close)
	v.add_child(foot)


## One asset: its title and what it is for, who made it, its licence and
## source (each a link where the credits give one), and what was changed.
func _entry(a: Dictionary) -> Control:
	var e := VBoxContainer.new()
	e.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = str(a.get("title", ""))
	_ink(t, Look.F("body_bold"), Look.Size("label") + 1, "ink")
	head.add_child(t)
	if not str(a.get("what", "")).is_empty():
		var w := Label.new()
		w.text = "·  %s" % str(a["what"])
		_ink(w, Look.F("body"), Look.Size("label"), "ink_muted")
		head.add_child(w)
	e.add_child(head)
	e.add_child(_para(str(a.get("author", "")), "ink"))
	var licence := str(a.get("licence", ""))
	if not str(a.get("licence_url", "")).is_empty():
		e.add_child(_link("Licence", licence, str(a["licence_url"])))
	else:
		e.add_child(_para("Licence: %s" % licence, "ink"))
	if not str(a.get("source", "")).is_empty():
		e.add_child(_link("Source", "", str(a["source"])))
	if not str(a.get("changes", "")).is_empty():
		e.add_child(_para("Changes: %s" % str(a["changes"]), "ink_muted"))
	return e


## "<what>: <text>" and its address - a link in the browser, the address and
## Copy on the desktop.
func _link(what: String, text: String, url: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "%s:%s" % [what, (" " + text) if not text.is_empty() else ""]
	_ink(l, Look.F("body"), Look.Size("label"), "ink")
	row.add_child(l)
	if OS.has_feature("web"):
		var link := LinkButton.new()
		link.text = url if text.is_empty() else "open"
		link.tooltip_text = url
		link.add_theme_color_override("font_color", Look.C("ink"))
		link.add_theme_color_override("font_hover_color", Look.C("ink_muted"))
		link.add_theme_font_size_override("font_size", Look.Size("label"))
		link.pressed.connect(func() -> void: JavaScriptBridge.eval("window.open(%s, '_blank')" % JSON.stringify(url), true))
		row.add_child(link)
	else:
		var address := LineEdit.new()
		address.text = url
		address.editable = false
		address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		address.add_theme_font_size_override("font_size", Look.Size("small"))
		row.add_child(address)
		var copy := Button.new()
		copy.text = "Copy"
		copy.theme_type_variation = Look.COMMAND
		copy.custom_minimum_size = Vector2(70, 0)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(url)
			copy.text = "Copied")
		row.add_child(copy)
	return row


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	_ink(l, Look.F("display"), Look.Size("heading"), "ink")
	return l


func _para(text: String, colour: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(800, 0)
	_ink(l, Look.F("body"), Look.Size("label"), colour)
	return l


## Untagged, so the colours set here stand (Look.Adopt strips a TAGGED node's).
func _ink(l: Label, font: Font, size: int, colour: String) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.C(colour))


func _rule() -> HSeparator:
	var s := HSeparator.new()
	s.theme_type_variation = Look.DIVIDER
	return s
