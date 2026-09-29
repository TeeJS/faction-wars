class_name InGameMenuWindow
extends DraggableWindow
## frontend/InGameMenuWindow.cs - the Game Menu: resume, exit to the main
## menu, exit to desktop.


const LookWindow := preload("res://src/ui/look_window.gd")


# C# overrides _Ready WITHOUT calling base._Ready(), so the DraggableWindow
# wiring (title-bar drag, minimise) is not run for this window - kept as is.
func _ready() -> void:
	var btnResume: Button = get_node("%BtnResume")
	var btnExitToMenu: Button = get_node("%BtnExitToMenu")
	var btnExitToDesktop: Button = get_node("%BtnExitToDesktop")
	var btnX: Button = get_node("%CloseButton")

	btnResume.pressed.connect(func() -> void: queue_free())

	# The Game Options screen (manual p073-077) - six named save slots. Head-to-
	# head too: "follow the same procedure as you would to save a single player
	# game" (p163); there the host's Save writes both computers' slot, and the
	# guest's is off (GameOptionsWindow).
	var btnOptions := Button.new()
	btnOptions.text = "Game Options"
	btnOptions.custom_minimum_size = Vector2(0, 30)
	var column: Node = btnResume.get_parent()
	column.add_child(btnOptions)
	column.move_child(btnOptions, btnResume.get_index() + 1)
	btnOptions.pressed.connect(func() -> void:
		var w := GameOptionsWindow.new()
		get_parent().add_child(w))

	# HEAD-TO-HEAD (manual p163). "Bring up the Game Options Screen. Your
	# opponent will receive a Waiting for Opponent message, until you return to
	# the game": the clock tells the opponent while this window is open.
	if MpSetup.session != null:
		var gm: GameManager = get_tree().current_scene as GameManager
		if gm != null:
			gm.MenuOpened(true)
			tree_exited.connect(func() -> void: gm.MenuOpened(false))
	btnX.pressed.connect(func() -> void: queue_free())
	btnExitToMenu.pressed.connect(func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn"))
	btnExitToDesktop.pressed.connect(func() -> void:
		MpSetup.reset()
		get_tree().quit())
	# A browser tab has no desktop to exit to (TeeJ, room #97).
	btnExitToDesktop.visible = not OS.has_feature("web")
	# In a pack's look: the steel frame, the choices as command keys
	# (docs/ww2-look-plan.md, phase 5).
	if Look.Active():
		LookWindow.Dress(self)
		LookWindow.Commands(column)
