extends MpScreen
## Multiplayer Configuration screen (manual p157, Fig 5.2): the service provider
## list ("the provider that is currently selected appears in red"), "How do you
## want to play?" with Connect To Game / Setup Game ("the currently selected
## option will be depressed and the text will appear dark"), Proceed and Cancel.
## One honest provider entry (TeeJ, decision 3).

var _group: ButtonGroup


func _ready() -> void:
	MpSetup.load_names()
	var providers: ItemList = get_node("%Providers")
	providers.clear()
	providers.add_item("Internet Connection")
	providers.set_item_custom_fg_color(0, Color(1.0, 0.25, 0.25))
	providers.select(0)

	_group = ButtonGroup.new()
	var connect_btn: Button = get_node("%BtnConnectToGame")
	var setup_btn: Button = get_node("%BtnSetupGame")
	for b in [connect_btn, setup_btn]:
		b.toggle_mode = true
		b.button_group = _group
		b.toggled.connect(func(_on: bool) -> void: _refresh())

	bar().set_previous(false)
	bar().proceed.connect(_proceed)
	bar().cancel.connect(cancel_to_cockpit)
	_refresh()


func _refresh() -> void:
	var picked := _group.get_pressed_button()
	bar().set_proceed_enabled(picked != null, "" if picked != null else "Choose Connect To Game or Setup Game first.")
	# "depressed and the text will appear dark"
	for b in _group.get_buttons():
		if b.button_pressed:
			b.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
			b.add_theme_color_override("font_pressed_color", Color(0.15, 0.15, 0.15))
		else:
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_pressed_color")


func _proceed() -> void:
	var picked := _group.get_pressed_button()
	if picked == null:
		return
	MpSetup.hosting = picked.name == "BtnSetupGame"
	go(HostGameScene if MpSetup.hosting else LocateSessionScene)
