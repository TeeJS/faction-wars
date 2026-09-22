class_name Menu
extends Control
## Menu.cs - the root main menu, the manual's SHUTTLE COCKPIT (manual PDF p20,
## fig 2.2): difficulty, galaxy size, Headquarters Only Victory, load a saved
## game, view credits, head-to-head, exit, and the side to play.
##
## Two forms of the same screen:
##   - a pack that declares `menu` in pack.json (SCHEMA.md section 2) gets ITS
##     PICTURE, with one clickable region per function laid over it exactly
##     where the pack says - the cockpit the manual labels;
##   - a pack without one gets the labelled buttons in Menu.tscn.
## Both drive the same StartGame; the picture form keeps its choices in
## _difficultyId / _sizeId / _hqOnly, the button form in the toggle groups.

const DIFFICULTY_IDS := {"easy": Enums.Difficulty.Easy, "medium": Enums.Difficulty.Medium, "hard": Enums.Difficulty.Hard}

var _difficultyGroup: ButtonGroup
var _sizeGroup: ButtonGroup

# The picture form. _cockpit stays null in the button form.
var _cockpit: PackDefs.MenuDef = null
var _difficultyId: String = "medium"
var _sizeId: String = ""
var _hqOnly: bool = false
var _picture: TextureRect
var _regions: Control                 # the region buttons, laid over the picture
var _regionButtons: Dictionary = {}   # "action" or "action:value" -> Button
var _readout: Label
var _marks: Control                   # draws the selection brackets


func _ready() -> void:
	# Nothing here may touch FactionRegistry before this.
	FactionRegistry.EnsureLoaded()

	var btnEasy: Button = get_node("%BtnEasy")
	var btnMedium: Button = get_node("%BtnMedium")
	var btnHard: Button = get_node("%BtnHard")

	var btnSmall: Button = get_node("%BtnSmall")
	var btnMediumSize: Button = get_node("%BtnMediumSize")
	var btnLarge: Button = get_node("%BtnLarge")

	var btnAlliance: Button = get_node("%BtnAlliance")
	var btnEmpire: Button = get_node("%BtnEmpire")
	var btnExit: Button = get_node("%BtnExit")

	# Set up the Difficulty "Radio Buttons"
	_difficultyGroup = ButtonGroup.new()
	SetupToggleButton(btnEasy, _difficultyGroup)
	SetupToggleButton(btnMedium, _difficultyGroup)
	SetupToggleButton(btnHard, _difficultyGroup)

	# Set up the Size "Radio Buttons"
	_sizeGroup = ButtonGroup.new()
	SetupToggleButton(btnSmall, _sizeGroup)
	SetupToggleButton(btnMediumSize, _sizeGroup)
	SetupToggleButton(btnLarge, _sizeGroup)

	# Pre-press the pack's defaults (manual p021: easy and standard).
	var setup := FactionRegistry.Pack.Manifest.Setup if FactionRegistry.Pack != null else null
	var sizes: Array[String] = setup.GalaxySizes if setup != null else []
	var diff_default: String = setup.DifficultyDefault if setup != null else "medium"
	var size_default: String = setup.GalaxySizeDefault if setup != null and sizes.has(setup.GalaxySizeDefault) else (sizes[0] if not sizes.is_empty() else "")
	({"easy": btnEasy, "medium": btnMedium, "hard": btnHard}.get(diff_default, btnMedium) as Button).button_pressed = true
	var size_btn: Button = [btnSmall, btnMediumSize, btnLarge][clampi(sizes.find(size_default), 0, 2)]
	size_btn.button_pressed = true

	# Wire up the Faction/Launch buttons from the pack: the two buttons bind to
	# the first two declared factions and their labels come from the pack.
	var first: Faction = FactionRegistry.Playable[0] if FactionRegistry.Playable.size() > 0 else null
	var second: Faction = FactionRegistry.Playable[1] if FactionRegistry.Playable.size() > 1 else null
	if first != null:
		btnAlliance.text = first.DisplayName
		btnAlliance.pressed.connect(func() -> void: StartGame(first))
	if second != null:
		btnEmpire.text = second.DisplayName
		btnEmpire.pressed.connect(func() -> void: StartGame(second))

	# Exit leaves the Cockpit for the pack picker (TeeJ, 2026-09-22); quitting
	# the game is the picker's button.
	btnExit.pressed.connect(func() -> void: PackPicker.ExitToPicker(get_tree()))
	btnExit.text = "Exit to Faction Picker" if PackPicker.CanReturn() else "Exit to Desktop"

	var has_picture: bool = FactionRegistry.Pack != null and FactionRegistry.Pack.Manifest.Menu != null

	# "Load Game" - restore a saved single-player game (issue #6, manual
	# p073-077). Added in code (bottom-left of the Cockpit); opens a slot picker.
	# The picture form has the manual's own region for it instead.
	if not has_picture:
		var btnLoad := Button.new()
		btnLoad.text = "Load Game"
		btnLoad.pressed.connect(OpenLoadGame)
		add_child(btnLoad)
		btnLoad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		btnLoad.offset_left = 10.0
		btnLoad.offset_top = -40.0
		btnLoad.offset_right = 140.0
		btnLoad.offset_bottom = -10.0

	# The build version, bottom right of the Cockpit (TeeJ, room #106).
	var ver := BuildInfo.label()
	add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -240.0
	ver.offset_top = -30.0
	ver.offset_right = -10.0
	ver.offset_bottom = -10.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Exit goes to the picker, not the desktop, so a browser tab has it too;
	# the picker hides ITS quit on the web (TeeJ, room #97).
	btnExit.visible = true

	# Visible check boxes (TeeJ, room #152): the default theme's unchecked box
	# is a faint outline on this dark Cockpit; draw our own for both.
	for chk in [get_node("%ChkHQOnly"), get_node("%ChkFeedback")]:
		_visible_checkbox(chk)

	# THE MULTIPLAYER PANEL (manual p156, Fig 5.1): "the small panel at the lower
	# left that depicts a Rebel soldier and an Imperial stormtrooper facing off".
	# Button form: a labelled button at the lower left, like every other control.
	# Picture form: the pack's own panel, as a region.
	MpSetup.reset()
	# "Provide feedback" (TeeJ, room #80): remembered across sessions.
	MpSetup.load_names()
	var chkFeedback: CheckBox = get_node("%ChkFeedback")
	chkFeedback.button_pressed = GameSettings.ProvideFeedback
	chkFeedback.toggled.connect(func(on: bool) -> void:
		GameSettings.ProvideFeedback = on
		MpSetup.remember_names())
	(get_node("%BtnMultiplayer") as Button).pressed.connect(OpenMultiplayer)

	if has_picture:
		_build_cockpit(FactionRegistry.Pack.Manifest.Menu)


func SetupToggleButton(btn: Button, group: ButtonGroup) -> void:
	btn.toggle_mode = true
	btn.button_group = group


func OpenLoadGame() -> void:
	if get_node_or_null("LoadGameWindow") == null:
		add_child(LoadGameWindow.new())


func OpenMultiplayer() -> void:
	get_tree().change_scene_to_file("res://src/ui/mp/MultiplayerConfiguration.tscn")


func OpenCredits() -> void:
	if get_node_or_null("CreditsWindow") == null:
		var lines: Array[String] = _cockpit.Credits if _cockpit != null else []
		add_child(CreditsWindow.new(FactionRegistry.Pack.Manifest.DisplayName, lines))


## The picture form's choices, for tests and the log. The button form reads its
## toggle groups instead.
func SelectedSettings() -> Dictionary:
	return {"difficulty": _difficultyId, "size": _sizeId, "hq_only": _hqOnly}


func StartGame(chosenFaction: Faction) -> void:
	var difficultyLevel: int = Enums.Difficulty.Medium   # Fallback
	var sizeLevel: int = Enums.GalaxySize.Large          # Fallback
	var isHqOnly: bool = false

	if _cockpit != null:
		difficultyLevel = DIFFICULTY_IDS.get(_difficultyId, Enums.Difficulty.Medium)
		# Sizes rank by their position in setup.galaxy_sizes; Enums.GalaxySize
		# indexes that same list (GalaxyFactory).
		var sizes: Array[String] = FactionRegistry.Pack.Manifest.Setup.GalaxySizes
		var idx := sizes.find(_sizeId)
		if idx >= 0:
			sizeLevel = idx
		isHqOnly = _hqOnly
	else:
		# Parse Difficulty
		var selectedDifficultyBtn: BaseButton = _difficultyGroup.get_pressed_button()
		if selectedDifficultyBtn.name == "BtnEasy":
			difficultyLevel = Enums.Difficulty.Easy
		if selectedDifficultyBtn.name == "BtnHard":
			difficultyLevel = Enums.Difficulty.Hard

		# Parse Galaxy Size
		var selectedSizeBtn: BaseButton = _sizeGroup.get_pressed_button()
		if selectedSizeBtn.name == "BtnSmall":
			sizeLevel = Enums.GalaxySize.Standard
		if selectedSizeBtn.name == "BtnLarge":
			sizeLevel = Enums.GalaxySize.Huge

		# Parse Victory Condition
		isHqOnly = get_node("%ChkHQOnly").button_pressed

	# Save to our static context
	GameSettings.SelectedDifficulty = difficultyLevel
	GameSettings.SelectedSize = sizeLevel
	GameSettings.HQOnlyVictory = isHqOnly
	GameSettings.PlayerFaction = chosenFaction

	print("Starting Game... Faction: %s | Difficulty: %s | Size: %s | HQ Only: %s" % [str(chosenFaction), JsonUtil.enum_name(Enums.Difficulty, difficultyLevel), JsonUtil.enum_name(Enums.GalaxySize, sizeLevel), str(isHqOnly)])

	# Launch the Main scene
	get_tree().change_scene_to_file("res://Main.tscn")


# ---------------------------------------------------------------------------
# THE PICTURE FORM - manual p021, Fig. 2.2, from the pack's `menu`.
# ---------------------------------------------------------------------------

func _build_cockpit(menu: PackDefs.MenuDef) -> void:
	_cockpit = menu
	var setup := FactionRegistry.Pack.Manifest.Setup
	var sizes: Array[String] = setup.GalaxySizes if setup != null else []
	_difficultyId = setup.DifficultyDefault if setup != null and DIFFICULTY_IDS.has(setup.DifficultyDefault) else "medium"
	_sizeId = setup.GalaxySizeDefault if setup != null and sizes.has(setup.GalaxySizeDefault) else (sizes[0] if not sizes.is_empty() else "")
	_hqOnly = false

	# The button form's controls give way to the picture; the one the manual's
	# screen does not have (feedback) moves to a corner.
	(get_node("CenterContainer") as Control).visible = false
	(get_node("Background") as ColorRect).color = Color.BLACK
	(get_node("%BtnMultiplayer") as Button).visible = false
	_to_corner(get_node("%ChkFeedback"), Control.PRESET_BOTTOM_RIGHT, Vector2(-240, -60), Vector2(-10, -34))

	_picture = TextureRect.new()
	_picture.name = "Cockpit"
	_picture.texture = load("%s/%s/%s" % [FactionRegistry.PACKS_ROOT, FactionRegistry.Pack.Manifest.Id, menu.ImageFile])
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picture)
	move_child(_picture, 1)   # over the Background, under everything else

	_regions = Control.new()
	_regions.name = "Regions"
	_regions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regions.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_regions)
	move_child(_regions, 2)

	for r in menu.Regions:
		var b := Button.new()
		var key := _region_key(r)
		b.name = "Region_" + key.replace(":", "_")
		b.flat = true
		b.text = ""
		b.tooltip_text = r.Tooltip
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.12)
		b.add_theme_stylebox_override("hover", hover)
		b.set_meta("cockpit_region", true)
		b.set_meta("rect", r.rect2())
		b.set_meta("color", r.SelectedColorHex)
		b.pressed.connect(_on_region.bind(r))
		if r.Action == "exit":
			b.visible = not OS.has_feature("web")
		_regions.add_child(b)
		_regionButtons[key] = b

	# The readout under the victory-condition screen.
	_readout = Label.new()
	_readout.name = "Readout"
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.clip_text = true
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.BLACK
	_readout.add_theme_stylebox_override("normal", bg)
	_readout.add_theme_color_override("font_color", FactionRegistry.ParseColor(menu.Readout.ColorHex))
	_regions.add_child(_readout)

	# The selection brackets, drawn over the chosen regions.
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	_regions.add_child(_marks)

	resized.connect(_layout_cockpit)
	_layout_cockpit()


static func _region_key(r: PackDefs.MenuRegionDef) -> String:
	return r.Action if r.Value.is_empty() else "%s:%s" % [r.Action, r.Value]


func _to_corner(c: Control, preset: int, from: Vector2, to: Vector2) -> void:
	c.get_parent().remove_child(c)
	add_child(c)
	c.set_anchors_preset(preset)
	c.offset_left = from.x
	c.offset_top = from.y
	c.offset_right = to.x
	c.offset_bottom = to.y


## Where the picture actually lands inside this control (kept aspect, centred),
## and the scale from picture pixels to screen pixels.
func _picture_frame() -> Rect2:
	if _picture == null or _picture.texture == null:
		return Rect2(Vector2.ZERO, size)
	var tex: Vector2 = _picture.texture.get_size()
	if tex.x <= 0 or tex.y <= 0:
		return Rect2(Vector2.ZERO, size)
	var scale := minf(size.x / tex.x, size.y / tex.y)
	var drawn := tex * scale
	return Rect2((size - drawn) * 0.5, drawn)


func _scaled(r: Rect2) -> Rect2:
	var frame := _picture_frame()
	var tex: Vector2 = _picture.texture.get_size() if _picture != null and _picture.texture != null else Vector2.ONE
	var scale := frame.size.x / tex.x
	return Rect2(frame.position + r.position * scale, r.size * scale)


func _layout_cockpit() -> void:
	if _cockpit == null:
		return
	for key in _regionButtons:
		var b: Button = _regionButtons[key]
		var sr := _scaled(b.get_meta("rect"))
		b.position = sr.position
		b.size = sr.size
	if _cockpit.Readout != null:
		var rr := _scaled(_cockpit.Readout.rect2())
		_readout.position = rr.position
		_readout.size = rr.size
		_readout.add_theme_font_size_override("font_size", _readout_font_size(rr.size))
	_refresh_readout()
	_marks.queue_redraw()


## The largest size at which BOTH readout texts fit the panel: height-bound
## first, then shrunk until the wider string clears the width (the longer text
## was clipped on the narrow panel).
func _readout_font_size(panel: Vector2) -> int:
	var font: Font = _readout.get_theme_font("font")
	var size := maxi(8, int(panel.y * 0.6))
	var room := panel.x - 8.0
	while size > 8:
		var widest := 0.0
		for text in [_cockpit.Readout.Standard, _cockpit.Readout.HqOnly]:
			widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if widest <= room:
			break
		size -= 1
	return size


func _refresh_readout() -> void:
	if _cockpit == null or _cockpit.Readout == null:
		return
	_readout.text = _cockpit.Readout.HqOnly if _hqOnly else _cockpit.Readout.Standard


func _draw_marks() -> void:
	if _cockpit == null:
		return
	var default_color := FactionRegistry.ParseColor(_cockpit.SelectedColorHex)
	var chosen: Array[String] = ["difficulty:%s" % _difficultyId, "galaxy_size:%s" % _sizeId]
	if _hqOnly:
		chosen.append("hq_only_victory")
	for key in chosen:
		if not _regionButtons.has(key):
			continue
		var b: Button = _regionButtons[key]
		var own: String = str(b.get_meta("color", ""))
		_bracket(Rect2(b.position, b.size), FactionRegistry.ParseColor(own) if not own.is_empty() else default_color)


## Corner brackets, the original's selection mark (red corners on the chosen
## difficulty, yellow on the chosen galaxy size). Drawn INSIDE the region so
## they land on the screen rather than the bezel, over a dark outline so a
## light colour reads on a light bezel too (TeeJ: the yellow was hard to see).
func _bracket(region: Rect2, color: Color) -> void:
	var inset := minf(region.size.x, region.size.y) * 0.10
	var r := Rect2(region.position + Vector2(inset, inset), region.size - Vector2(inset, inset) * 2.0)
	var l := minf(r.size.x, r.size.y) * 0.32
	var w := maxf(3.0, minf(r.size.x, r.size.y) * 0.07)
	var tl := r.position
	var tr := r.position + Vector2(r.size.x, 0)
	var bl := r.position + Vector2(0, r.size.y)
	var br := r.end
	var arms := [
		[tl, tl + Vector2(l, 0)], [tl, tl + Vector2(0, l)],
		[tr, tr + Vector2(-l, 0)], [tr, tr + Vector2(0, l)],
		[bl, bl + Vector2(l, 0)], [bl, bl + Vector2(0, -l)],
		[br, br + Vector2(-l, 0)], [br, br + Vector2(0, -l)],
	]
	for pass_color in [Color(0, 0, 0, 0.85), color]:
		var width := w + 2.0 if pass_color.a < 1.0 else w
		for a in arms:
			_marks.draw_line(a[0], a[1], pass_color, width)


func _on_region(r: PackDefs.MenuRegionDef) -> void:
	match r.Action:
		"difficulty":
			_difficultyId = r.Value
			_marks.queue_redraw()
		"galaxy_size":
			_sizeId = r.Value
			_marks.queue_redraw()
		"hq_only_victory":
			_hqOnly = not _hqOnly
			_refresh_readout()
			_marks.queue_redraw()
		"start":
			var f := FactionRegistry.ById(r.Value)
			if f != null:
				StartGame(f)
		"load_game":
			OpenLoadGame()
		"credits":
			OpenCredits()
		"multiplayer":
			OpenMultiplayer()
		"exit":
			PackPicker.ExitToPicker(get_tree())


## A light square (off) and the same square with a tick (on), drawn at start,
## so a check box's state is obvious on the dark Cockpit.
static func _visible_checkbox(chk: CheckBox) -> void:
	chk.add_theme_icon_override("unchecked", _box_icon(false))
	chk.add_theme_icon_override("checked", _box_icon(true))
	chk.add_theme_icon_override("unchecked_disabled", _box_icon(false))
	chk.add_theme_icon_override("checked_disabled", _box_icon(true))


static func _box_icon(ticked: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := Color(0.85, 0.88, 0.92)
	for i in n:
		for j in n:
			var border := i < 2 or j < 2 or i >= n - 2 or j >= n - 2
			if border:
				img.set_pixel(i, j, edge)
			elif ticked and i >= 4 and i < n - 4 and j >= 4 and j < n - 4:
				img.set_pixel(i, j, Color(0.3, 0.85, 0.45))
	return ImageTexture.create_from_image(img)
