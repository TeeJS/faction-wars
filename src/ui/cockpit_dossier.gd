extends RefCounted
## THE COCKPIT AS A CAMPAIGN DOSSIER (docs/ww2-look-plan.md, phase 2): the
## button Cockpit (Menu.tscn, manual p021 Fig. 2.2) of a pack that ships a look
## (Look.Active()) and no Cockpit picture. The officer's desk before the map
## room opens: the campaign's dossier on the left - its name, years, summary
## and a plate of its map - the orders on the right, the two launch plates
## across the desk, and the secondary controls along its edge.
##
## THE SAME BUTTONS. Nothing here is a new control for an old function: the
## scene's own difficulty, size, option, side, load, multiplayer, credits and
## exit buttons are moved into this layout and keep every connection menu.gd
## made. Pressing a launch plate is still one click that starts the game.
## A pack without a look never comes here: its Cockpit is exactly as before.
##
## Preloaded by path (as Dossier) from menu.gd.

const Art := preload("res://src/ui/artwork.gd")

## How long one drift of the Cockpit's light takes, seconds. Slow on purpose:
## a lamp, not an animation. Held still under Look.ReducedMotion().
const DRIFT_SECONDS := 26.0


## Lays `menu` out as the dossier. `first`/`second` are the factions the two
## side buttons start; `load_btn` is the code-added Load Game button.
static func Build(menu: Control, first: Faction, second: Faction, load_btn: Button) -> void:
	menu.theme = Look.GetTheme()
	(menu.get_node("Background") as ColorRect).color = Look.C("chassis_deep")
	_desk(menu)

	var layout := MarginContainer.new()
	layout.name = "DossierLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [["left", 44], ["right", 44], ["top", 24], ["bottom", 20]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	menu.add_child(layout)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	layout.add_child(col)

	# The header: the scene's own "New Game", as an operational label.
	var title: Label = menu.get_node("CenterContainer/MenuVBox/Title")
	title.reparent(col, false)
	title.theme_type_variation = Look.HEADING
	title.remove_theme_font_size_override("font_size")
	title.add_theme_font_size_override("font_size", Look.Size("heading") + 4)
	title.uppercase = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_rule())

	var main := HBoxContainer.new()
	main.name = "DossierMain"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 22)
	col.add_child(main)
	main.add_child(_dossier())
	main.add_child(_orders(menu))

	# The launch plates: the scene's side buttons, one click each, as before.
	var faction_label: Label = menu.get_node("CenterContainer/MenuVBox/FactionLabel")
	faction_label.reparent(col, false)
	_label_as_heading(faction_label)
	var plates: HBoxContainer = menu.get_node("CenterContainer/MenuVBox/FactionHBox")
	plates.reparent(col, false)
	plates.add_theme_constant_override("separation", 22)
	for pair in [[menu.get_node("%BtnAlliance"), first], [menu.get_node("%BtnEmpire"), second]]:
		_launch_plate(pair[0], pair[1])

	# The desk's edge: Load Game, Multiplayer, View Credits ... Exit, build.
	col.add_child(_rule())
	var edge := HBoxContainer.new()
	edge.name = "DossierEdge"
	edge.add_theme_constant_override("separation", 10)
	col.add_child(edge)
	for b in [load_btn, menu.get_node("%BtnMultiplayer"), menu.get_node("BtnCredits")]:
		_secondary(b as Button, edge)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edge.add_child(gap)
	var ver: Label = menu.get_node_or_null("BuildVersion")
	if ver != null:
		ver.reparent(edge, false)
		ver.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ver.add_theme_color_override("font_color", Look.C("text_muted"))
	_secondary(menu.get_node("%BtnExit") as Button, edge)

	(menu.get_node("CenterContainer") as Control).visible = false
	Look.AdoptTree(menu)


# ---------------------------------------------------------------------------
# The desk
# ---------------------------------------------------------------------------

## The chassis: the desk texture, a lamp's slow light, the static grain and
## the shadow at the desk's edges. Nothing here takes a click.
static func _desk(menu: Control) -> void:
	var desk := Control.new()
	desk.name = "Desk"
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(desk)
	menu.move_child(desk, 1)   # over the Background, under everything else
	desk.add_child(_tiled(Look.Tex("desk")))

	var lamp := TextureRect.new()
	lamp.name = "Lamp"
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp.texture = _radial(Color(Look.C("paper"), 0.075), Color(Look.C("paper"), 0.0))
	lamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lamp.size = Vector2(1500, 1100)
	lamp.position = Vector2(-130, -260)
	desk.add_child(lamp)

	desk.add_child(_tiled(Look.Tex("grain")))

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.texture = _radial(Color(Look.C("chassis_deep"), 0.0), Color(Look.C("chassis_deep"), 0.6), 0.45)
	desk.add_child(vignette)

	Drift(menu)


## The lamp's drift - or none, when motion is to be held still. Called again
## when the player ticks Reduce motion.
static func Drift(menu: Control) -> void:
	var lamp: TextureRect = menu.get_node_or_null("Desk/Lamp")
	if lamp == null:
		return
	var old: Variant = menu.get_meta("drift", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	lamp.position = Vector2(-130, -260)
	if Look.ReducedMotion():
		menu.set_meta("drift", null)
		return
	var t := menu.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(lamp, "position", Vector2(-40, -220), DRIFT_SECONDS)
	t.tween_property(lamp, "position", Vector2(-200, -300), DRIFT_SECONDS)
	t.tween_property(lamp, "position", Vector2(-130, -260), DRIFT_SECONDS)
	menu.set_meta("drift", t)


static func _tiled(tex: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## A radial fade from `inner` at the centre to `outer` at the rim; `hold` is
## how far out the inner colour holds before it starts to fade.
static func _radial(inner: Color, outer: Color, hold: float = 0.0) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	if hold > 0.0:
		g.add_point(hold, inner)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	return tex


# ---------------------------------------------------------------------------
# The dossier and the orders
# ---------------------------------------------------------------------------

## The campaign on parchment: the years, the name, the summary and a plate of
## its map with its caption.
static func _dossier() -> Control:
	var m := FactionRegistry.Pack.Manifest
	var facts := Look.Dossier()
	var sheet := PanelContainer.new()
	sheet.name = "Dossier"
	sheet.theme_type_variation = Look.DOCUMENT
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.55
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)

	if not str(facts.get("subtitle", "")).is_empty():
		var sub := Label.new()
		sub.name = "Subtitle"
		sub.text = str(facts["subtitle"]).to_upper()
		sub.theme_type_variation = Look.TYPED
		v.add_child(sub)
	var campaign := Label.new()
	campaign.name = "CampaignName"
	campaign.text = m.DisplayName.to_upper()
	campaign.add_theme_font_override("font", Look.F("display_bold"))
	campaign.add_theme_font_size_override("font_size", Look.Size("display"))
	campaign.add_theme_color_override("font_color", Look.C("ink"))
	v.add_child(campaign)
	v.add_child(_rule())
	if not m.Summary.is_empty():
		var summary := Label.new()
		summary.name = "Summary"
		summary.text = m.Summary
		summary.theme_type_variation = Look.INK
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(420, 0)
		v.add_child(summary)

	var map_tex: Texture2D = Art.PackImage(m.MapImage)
	if map_tex != null:
		var frame := PanelContainer.new()
		frame.name = "MapPlate"
		frame.add_theme_stylebox_override("panel", Look.Box("paper_edge", "ink_muted", 1, 0, 3))
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.clip_contents = true
		var plate := TextureRect.new()
		var r: Variant = facts.get("map_rect")
		if r is Array and (r as Array).size() == 4:
			var at := AtlasTexture.new()
			at.atlas = map_tex
			var want := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			at.region = want.intersection(Rect2(Vector2.ZERO, map_tex.get_size()))
			plate.texture = at
		else:
			plate.texture = map_tex
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.custom_minimum_size = Vector2(0, 150)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(plate)
		v.add_child(frame)
		if not str(facts.get("map_caption", "")).is_empty():
			var cap := Label.new()
			cap.name = "MapCaption"
			cap.text = str(facts["map_caption"])
			cap.add_theme_font_override("font", Look.F("typed"))
			cap.add_theme_font_size_override("font_size", Look.Size("small"))
			cap.add_theme_color_override("font_color", Look.C("ink_muted"))
			v.add_child(cap)
	return sheet


## The orders: the scene's difficulty, size and option controls, in a steel
## panel, each choice a selector rail.
static func _orders(menu: Control) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Orders"
	panel.theme_type_variation = Look.PANEL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# As tall as its orders, sitting on the desk - not stretched to the dossier.
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var vbox := "CenterContainer/MenuVBox/"
	var size_label: Label = menu.get_node(vbox + "SizeLabel")
	for part in ["DifficultyLabel", "DifficultyHBox", "SizeLabel", "SizeHBox", "OptionsLabel"]:
		var n: Control = menu.get_node(vbox + part)
		n.reparent(v, false)
		if n is Label:
			_label_as_heading(n as Label)
		else:
			(n as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
			(n as BoxContainer).add_theme_constant_override("separation", 6)
			for b in n.get_children():
				(b as Button).theme_type_variation = Look.COMMAND
				(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				(b as Button).custom_minimum_size = Vector2(96, 40)
	size_label.text = Terms.label("galaxy_size")

	for chk_name in ["%ChkHQOnly", "%ChkFeedback"]:
		var chk: CheckBox = menu.get_node(chk_name)
		chk.reparent(v, false)
		chk.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_look_checkbox(chk)
	var reduce := CheckBox.new()
	reduce.name = "ChkReduceMotion"
	reduce.text = "Reduce motion"
	reduce.tooltip_text = "Hold the Cockpit's lighting still. The browser's own reduced-motion setting does the same."
	reduce.button_pressed = GameSettings.ReduceMotion
	reduce.toggled.connect(func(on: bool) -> void:
		GameSettings.ReduceMotion = on
		MpSetup.remember_names()
		Drift(menu))
	reduce.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(reduce)
	_look_checkbox(reduce)
	return panel


# ---------------------------------------------------------------------------
# The controls
# ---------------------------------------------------------------------------

## A launch plate: the side's button, weighted, its side's colour as a band
## on the plate's left. The text says what the click does.
static func _launch_plate(btn: Button, f: Faction) -> void:
	btn.theme_type_variation = Look.LAUNCH
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 74)
	if f != null:
		btn.text = "LAUNCH AS %s" % f.DisplayName.to_upper()
		btn.tooltip_text = "Begin the campaign as the %s." % f.DisplayName
		var band := ColorRect.new()
		band.name = "SideBand"
		band.color = Look.SideColor(f)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		band.offset_left = 2
		band.offset_top = 2
		band.offset_bottom = -2
		band.offset_right = 12
		btn.add_child(band)


static func _secondary(btn: Button, row: HBoxContainer) -> void:
	btn.reparent(row, false)
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn.theme_type_variation = Look.COMMAND
	btn.custom_minimum_size = Vector2(150, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


static func _label_as_heading(l: Label) -> void:
	l.theme_type_variation = Look.HEADING
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.remove_theme_font_size_override("font_size")
	l.add_theme_font_size_override("font_size", Look.Size("label"))


static func _rule() -> HSeparator:
	var s := HSeparator.new()
	s.theme_type_variation = Look.DIVIDER
	return s


## A check box drawn in the look: a text-coloured square, a brass square when
## ticked (the Cockpit's own icons are bright green on slate).
static func _look_checkbox(chk: CheckBox) -> void:
	for pair in [["unchecked", false], ["checked", true], ["unchecked_disabled", false], ["checked_disabled", true]]:
		chk.add_theme_icon_override(pair[0], _box_icon(pair[1]))


static func _box_icon(ticked: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Look.C("text")
	var tick := Look.C("brass")
	for i in n:
		for j in n:
			if i < 2 or j < 2 or i >= n - 2 or j >= n - 2:
				img.set_pixel(i, j, edge)
			elif ticked and i >= 4 and i < n - 4 and j >= 4 and j < n - 4:
				img.set_pixel(i, j, tick)
	return ImageTexture.create_from_image(img)
