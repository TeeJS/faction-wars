class_name MpScreen
extends Control
## Base of the four Cockpit-side head-to-head screens (docs/multiplayer-ui-design.md
## section 0): a full-screen console panel with the shared bottom bar. Cancel on
## any of them is "return to the Shuttle Cockpit" (manual p157) and resets MpSetup.

const CockpitScene := "res://Menu.tscn"
const ConfigurationScene := "res://src/ui/mp/MultiplayerConfiguration.tscn"
const HostGameScene := "res://src/ui/mp/HostGame.tscn"
const LocateSessionScene := "res://src/ui/mp/LocateSession.tscn"
const OptionsScene := "res://src/ui/mp/MultiplayerOptions.tscn"
const MainScene := "res://Main.tscn"


func bar() -> MpBottomBar:
	return get_node("%BottomBar") as MpBottomBar


func go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func cancel_to_cockpit() -> void:
	MpSetup.reset()
	go(CockpitScene)


## The relay's error line, shown in place; the screen stays.
func show_error(text: String) -> void:
	var box := AcceptDialog.new()
	box.title = "Multiplayer"
	box.dialog_text = text
	add_child(box)
	box.popup_centered()
