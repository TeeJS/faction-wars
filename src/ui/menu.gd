class_name Menu
extends Control
## Menu.cs - the root main menu (manual PDF p20, fig 2.2): difficulty, galaxy
## size, Headquarters Only Victory, and the side to play.

var _difficultyGroup: ButtonGroup
var _sizeGroup: ButtonGroup


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

	var milData: Button = get_node("%BtnMilitaryDataEditor")

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

	# Pre-press Medium as the default for both
	btnMedium.button_pressed = true
	btnMediumSize.button_pressed = true

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

	btnExit.pressed.connect(func() -> void: get_tree().quit())
	# The build version, bottom right of the Cockpit (TeeJ, room #106).
	var ver := BuildInfo.label()
	add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -240.0
	ver.offset_top = -30.0
	ver.offset_right = -10.0
	ver.offset_bottom = -10.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# A browser tab has no desktop to exit to (TeeJ, room #97).
	btnExit.visible = not OS.has_feature("web")

	# Visible check boxes (TeeJ, room #152): the default theme's unchecked box
	# is a faint outline on this dark Cockpit; draw our own for both.
	for chk in [get_node("%ChkHQOnly"), get_node("%ChkFeedback")]:
		_visible_checkbox(chk)

	# THE MULTIPLAYER PANEL (manual p156, Fig 5.1): "the small panel at the lower
	# left that depicts a Rebel soldier and an Imperial stormtrooper facing off".
	# No artwork - a labelled button at the lower left, like every other control.
	MpSetup.reset()
	# "Provide feedback" (TeeJ, room #80): remembered across sessions.
	MpSetup.load_names()
	var chkFeedback: CheckBox = get_node("%ChkFeedback")
	chkFeedback.button_pressed = GameSettings.ProvideFeedback
	chkFeedback.toggled.connect(func(on: bool) -> void:
		GameSettings.ProvideFeedback = on
		MpSetup.remember_names())
	(get_node("%BtnMultiplayer") as Button).pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://src/ui/mp/MultiplayerConfiguration.tscn"))

	# EDITOR ONLY. The Military Data Editor writes military_units.json back to
	# disk, and an exported build's data lives inside the read-only .pck.
	if OS.has_feature("editor"):
		milData.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://src/ui/MilitaryDataEditor.tscn"))
	else:
		milData.visible = false


func SetupToggleButton(btn: Button, group: ButtonGroup) -> void:
	btn.toggle_mode = true
	btn.button_group = group


func StartGame(chosenFaction: Faction) -> void:
	# Parse Difficulty
	var selectedDifficultyBtn: BaseButton = _difficultyGroup.get_pressed_button()
	var difficultyLevel: int = Enums.Difficulty.Medium   # Fallback
	if selectedDifficultyBtn.name == "BtnEasy":
		difficultyLevel = Enums.Difficulty.Easy
	if selectedDifficultyBtn.name == "BtnHard":
		difficultyLevel = Enums.Difficulty.Hard

	# Parse Galaxy Size
	var selectedSizeBtn: BaseButton = _sizeGroup.get_pressed_button()
	var sizeLevel: int = Enums.GalaxySize.Large   # Fallback
	if selectedSizeBtn.name == "BtnSmall":
		sizeLevel = Enums.GalaxySize.Standard
	if selectedSizeBtn.name == "BtnLarge":
		sizeLevel = Enums.GalaxySize.Huge

	# Parse Victory Condition
	var isHqOnly: bool = get_node("%ChkHQOnly").button_pressed

	# Save to our static context
	GameSettings.SelectedDifficulty = difficultyLevel
	GameSettings.SelectedSize = sizeLevel
	GameSettings.HQOnlyVictory = isHqOnly
	GameSettings.PlayerFaction = chosenFaction

	print("Starting Game... Faction: %s | Difficulty: %s | Size: %s | HQ Only: %s" % [str(chosenFaction), JsonUtil.enum_name(Enums.Difficulty, difficultyLevel), JsonUtil.enum_name(Enums.GalaxySize, sizeLevel), str(isHqOnly)])

	# Launch the Main scene
	get_tree().change_scene_to_file("res://Main.tscn")


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
