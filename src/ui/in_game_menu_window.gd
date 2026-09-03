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
	btnX.pressed.connect(func() -> void: queue_free())
	btnExitToMenu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://Menu.tscn"))
	btnExitToDesktop.pressed.connect(func() -> void: get_tree().quit())
