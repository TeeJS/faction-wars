class_name MpBottomBar
extends HBoxContainer
## The button bar every head-to-head screen repeats (manual Figs 5.2, 5.3, 5.8,
## 5.9): Proceed (the right arrow), Previous / Go back (the left arrow) where the
## figure has it, and Cancel (the X, "return to the Shuttle Cockpit").

signal proceed
signal previous
signal cancel


func _ready() -> void:
	(get_node("%BtnPrevious") as Button).pressed.connect(func() -> void: previous.emit())
	(get_node("%BtnProceed") as Button).pressed.connect(func() -> void: proceed.emit())
	(get_node("%BtnCancel") as Button).pressed.connect(func() -> void: cancel.emit())


func set_previous(shown: bool, label: String = "Previous") -> void:
	var b: Button = get_node("%BtnPrevious")
	b.visible = shown
	b.text = "◄  %s" % label


func set_proceed(label: String) -> void:
	(get_node("%BtnProceed") as Button).text = label


func set_proceed_enabled(enabled: bool, why: String = "") -> void:
	var b: Button = get_node("%BtnProceed")
	b.disabled = not enabled
	b.tooltip_text = why
