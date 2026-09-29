extends SceneTree
## THE LOOK'S SPECIMEN SHEET (docs/ww2-look-plan.md, phase 1): every shared
## piece of a pack's look (src/ui/look.gd) on one screen - title bar, panel,
## inset, headings, the rule, console keys (normal, down, focused, disabled),
## the rail, list rows, chips, a dispatch on parchment, a field note, a dialog
## over the dimmed map, the launch plate, text entry, a list, tabs, and the
## palette with each pair's contrast. Needs a window (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_look_specimen.gd -- --out=C:/tmp/specimen.png --pack=ww2

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://look-specimen.png")
	FactionRegistry.EnsureLoaded()
	if not Look.Active():
		push_error("[capture_look_specimen] the loaded pack has no look.json")
		quit(3)
		return
	Look.Install(self)
	var board := Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(board)

	# The desk, and the grain over it.
	for name in ["desk", "grain"]:
		var tr := TextureRect.new()
		tr.texture = Look.Tex(name)
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(tr)

	# --- Column 1: a window, and the console. ---
	var win := _window(board, Rect2(24, 24, 440, 380), "Theatre Report")
	var v := win.get_meta("body") as VBoxContainer
	v.add_child(_label("Operations", Look.HEADING))
	v.add_child(_divider())
	var prose := _label("Body text in the humanist face: three fleets are awaiting orders in the North Atlantic.", &"")
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.custom_minimum_size = Vector2(410, 0)
	v.add_child(prose)
	var inset := PanelContainer.new()
	inset.theme_type_variation = Look.INSET
	var readout := _label("War Materiel  1,240     Industry  318     Day  118", &"")
	inset.add_child(readout)
	v.add_child(inset)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(_chip("DAY 118", Look.CHIP))
	chips.add_child(_chip("SLOW", Look.CHIP))
	chips.add_child(_chip("3 UNREAD", Look.CHIP))
	chips.add_child(_chip("BATTLE", Look.CHIP_ALERT))
	v.add_child(chips)
	v.add_child(_label("Console keys", Look.HEADING))
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	var k1 := _key("System Finder", false, false)
	var k2 := _key("Fleet Finder", true, false)
	var k3 := _key("Encyclopedia", false, false)
	var k4 := _key("Agent", false, true)
	for k in [k1, k2, k3, k4]:
		keys.add_child(k)
	v.add_child(keys)

	# The rail: message categories, one selected.
	var rail := VBoxContainer.new()
	rail.position = Vector2(24, 424)
	rail.size = Vector2(170, 360)
	rail.add_theme_constant_override("separation", 4)
	board.add_child(rail)
	rail.add_child(_label("Dispatch rail", Look.HEADING))
	for i in ["All Messages", "Loyalty", "Fleets", "Missions", "Conflict", "Advice"]:
		var b := Button.new()
		b.text = i
		b.theme_type_variation = Look.RAIL
		b.toggle_mode = true
		b.button_pressed = i == "Fleets"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(160, 34)
		rail.add_child(b)

	# List rows.
	var rows := VBoxContainer.new()
	rows.position = Vector2(214, 424)
	rows.size = Vector2(250, 300)
	rows.add_theme_constant_override("separation", 0)
	board.add_child(rows)
	rows.add_child(_label("List rows", Look.HEADING))
	var well := PanelContainer.new()
	well.theme_type_variation = Look.INSET
	rows.add_child(well)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 0)
	well.add_child(rv)
	for i in ["Britain", "France", "Germany", "Italy", "Soviet Union"]:
		var r := Button.new()
		r.text = i
		r.theme_type_variation = Look.ROW
		r.toggle_mode = true
		r.button_pressed = i == "Germany"
		r.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rv.add_child(r)

	# --- Column 2: a dispatch on parchment, a field note, the launch plate. ---
	var doc := PanelContainer.new()
	doc.theme_type_variation = Look.DOCUMENT
	doc.position = Vector2(488, 24)
	doc.size = Vector2(460, 300)
	board.add_child(doc)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	doc.add_child(dv)
	dv.add_child(_label("DISPATCH RECEIVED  0600", Look.TYPED))
	# The subject: ink in the display face (untagged, so its own colours stand).
	var sub := _label("Fleet awaiting orders", &"")
	sub.add_theme_color_override("font_color", Look.C("ink"))
	sub.add_theme_font_override("font", Look.F("display"))
	sub.add_theme_font_size_override("font_size", Look.Size("heading"))
	dv.add_child(sub)
	dv.add_child(_label("North Atlantic  ·  Day 118", Look.INK))
	var body := _label("The Home Fleet has arrived at Scapa Flow and awaits orders. Two cruisers report light damage; repairs are under way. Convoy escorts are available from the Western Approaches.", Look.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	dv.add_child(body)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", Look.Box("note", "brass_dim", 1, -1, 6))
	note.position = Vector2(488, 344)
	board.add_child(note)
	var nl := Label.new()
	nl.text = "Field note: opens the System Finder (F3)."
	nl.add_theme_color_override("font_color", Look.C("note_ink"))
	nl.add_theme_font_size_override("font_size", Look.Size("small"))
	note.add_child(nl)
	var launch := Button.new()
	launch.text = "LAUNCH AS ALLIED POWERS"
	launch.theme_type_variation = Look.LAUNCH
	launch.position = Vector2(488, 400)
	launch.custom_minimum_size = Vector2(460, 64)
	board.add_child(launch)

	# Text entry, a list, tabs.
	var controls := VBoxContainer.new()
	controls.position = Vector2(488, 486)
	controls.size = Vector2(460, 300)
	controls.add_theme_constant_override("separation", 8)
	board.add_child(controls)
	var le := LineEdit.new()
	le.placeholder_text = "Search theatres..."
	controls.add_child(le)
	var tabs := TabBar.new()
	for t in ["All Regions", "Allied", "Axis", "Neutral"]:
		tabs.add_tab(t)
	tabs.current_tab = 1
	controls.add_child(tabs)
	var il := ItemList.new()
	for t in ["Scapa Flow", "Gibraltar", "Malta", "Alexandria"]:
		il.add_item(t)
	il.select(2)
	il.custom_minimum_size = Vector2(460, 130)
	controls.add_child(il)

	# --- Column 3: a dialog over the dimmed map, and the palette. ---
	var map := TextureRect.new()
	map.texture = Art._load("%s/%s" % [Art._pack_dir(), FactionRegistry.Pack.Manifest.MapImage])
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.position = Vector2(972, 24)
	map.size = Vector2(444, 280)
	map.clip_contents = true
	board.add_child(map)
	var dim := ColorRect.new()
	dim.color = Look.Dim()
	dim.position = map.position
	dim.size = map.size
	board.add_child(dim)
	var modal := PanelContainer.new()
	modal.theme_type_variation = Look.MODAL
	modal.position = Vector2(1016, 84)
	modal.custom_minimum_size = Vector2(356, 0)
	board.add_child(modal)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	modal.add_child(mv)
	mv.add_child(_label("Order Refused", Look.HEADING))
	mv.add_child(_divider())
	var mt := _label("The mission cannot be launched: the team has no one able to perform it.", &"")
	mt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mt.custom_minimum_size = Vector2(330, 0)
	mv.add_child(mt)
	var ok := Button.new()
	ok.text = "Orders confirmed"
	ok.theme_type_variation = Look.COMMAND
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	mv.add_child(ok)

	var pal := GridContainer.new()
	pal.columns = 2
	pal.position = Vector2(972, 324)
	pal.add_theme_constant_override("h_separation", 10)
	pal.add_theme_constant_override("v_separation", 4)
	board.add_child(pal)
	for pair in [["text", "chassis"], ["text_muted", "chassis"], ["heading", "chassis"], ["brass", "chassis"],
			["ink", "paper"], ["ink_muted", "paper"], ["note_ink", "note"], ["signal_text", "signal"],
			["text", "olive_deep"], ["text_disabled", "chassis_raised"]]:
		var sw := PanelContainer.new()
		sw.add_theme_stylebox_override("panel", Look.Box(pair[1], "edge", 1, -1, 6))
		sw.custom_minimum_size = Vector2(212, 0)
		var sl := Label.new()
		sl.text = "%s on %s  %.1f:1" % [pair[0], pair[1], Look.Contrast(Look.C(pair[0]), Look.C(pair[1]))]
		sl.add_theme_color_override("font_color", Look.C(pair[0]))
		sl.add_theme_font_size_override("font_size", Look.Size("small"))
		sw.add_child(sl)
		pal.add_child(sw)

	for _i in 4:
		await process_frame
	k3.grab_focus()
	for _i in 3:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_look_specimen] %s -> %s" % [str(img.get_size()), out if err == OK else "error %d" % err])
	quit(0 if err == OK else 1)


const Art := preload("res://src/ui/artwork.gd")


func _window(parent: Control, rect: Rect2, title: String) -> PanelContainer:
	var w := PanelContainer.new()
	w.theme_type_variation = Look.PANEL
	w.position = rect.position
	w.size = rect.size
	parent.add_child(w)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	w.add_child(col)
	var bar := Panel.new()
	bar.theme_type_variation = Look.TITLE_BAR
	bar.custom_minimum_size = Vector2(0, 28)
	col.add_child(bar)
	var t := Label.new()
	t.text = title.to_upper()
	t.theme_type_variation = Look.TITLE
	t.position = Vector2(10, 3)
	bar.add_child(t)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	col.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	w.set_meta("body", body)
	return w


func _label(text: String, piece: StringName) -> Label:
	var l := Label.new()
	l.text = text
	if not String(piece).is_empty():
		l.theme_type_variation = piece
	return l


func _divider() -> HSeparator:
	var s := HSeparator.new()
	s.theme_type_variation = Look.DIVIDER
	return s


func _chip(text: String, piece: StringName) -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = piece
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Look.F("display"))
	l.add_theme_font_size_override("font_size", Look.Size("small"))
	if piece == Look.CHIP_ALERT:
		l.add_theme_color_override("font_color", Look.C("signal_text"))
	c.add_child(l)
	return c


func _key(text: String, down: bool, disabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = Look.COMMAND
	b.toggle_mode = true
	b.button_pressed = down
	b.disabled = disabled
	return b


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
