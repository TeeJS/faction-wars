class_name InGameMenuWindow
extends DraggableWindow
## frontend/InGameMenuWindow.cs - the Game Menu: resume, exit to the main
## menu, exit to desktop.


# C# overrides _Ready WITHOUT calling base._Ready(), so the DraggableWindow
# wiring (title-bar drag, minimise) is not run for this window - kept as is.
func _ready() -> void:
	var btnResume: Button = get_node("%BtnResume")
	var btnExitToMenu: Button = get_node("%BtnExitToMenu")
	var btnExitToDesktop: Button = get_node("%BtnExitToDesktop")
	var btnX: Button = get_node("%CloseButton")

	btnResume.pressed.connect(func() -> void: queue_free())

	# HEAD-TO-HEAD (manual p163). "Bring up the Game Options Screen. Your
	# opponent will receive a Waiting for Opponent message, until you return to
	# the game": the clock tells the opponent while this window is open.
	# "Only the host player can save the game": Save Game, host only.
	if MpSetup.session != null:
		var gm: GameManager = get_tree().current_scene as GameManager
		if gm != null:
			gm.MenuOpened(true)
			tree_exited.connect(func() -> void: gm.MenuOpened(false))
		var save := Button.new()
		save.text = "Save Game"
		save.custom_minimum_size = Vector2(0, 30)
		var column: Node = btnResume.get_parent()
		column.add_child(save)
		column.move_child(save, btnResume.get_index() + 1)
		if MpSetup.hosting:
			save.tooltip_text = "Save the game on both computers."
			save.pressed.connect(_save)
		else:
			save.disabled = true
			save.tooltip_text = "Only the host can save."
	btnX.pressed.connect(func() -> void: queue_free())
	btnExitToMenu.pressed.connect(func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn"))
	btnExitToDesktop.pressed.connect(func() -> void:
		MpSetup.reset()
		get_tree().quit())


## "Star Wars Rebellion will create a saved game on both computers in the same
## saved game slots" (p163-p164). Every line of the game is already on the relay
## and in both clients' logs, so Save confirms rather than writes: it names the
## game and the day, or says honestly that the relay cannot be reached.
func _save() -> void:
	var lobby: RelayClient = MpSetup.lobby
	var ok: bool = lobby != null and lobby.transport.is_connected_now() and MpSetup.session.state != LockstepSession.State.Desync
	var box := AcceptDialog.new()
	box.title = "Save Game"
	if ok:
		box.dialog_text = "Saved on both computers: \"%s\", Day %d." % [lobby.name, StrategicTickManager.Today]
	else:
		box.dialog_text = "Not saved: the relay cannot be reached right now."
	add_child(box)
	box.popup_centered()
