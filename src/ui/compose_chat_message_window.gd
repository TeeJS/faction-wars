class_name ComposeChatMessageWindow
extends DraggableWindow
## Compose Chat Message window (manual p163, Fig 5.11): "Type your message
## here", Send message, Cancel, the Close button, and Return to Display Message
## Index. The message travels as a `chat` command and lands in the opponent's
## Chat Messages ("processed through SD-7 or R2-D2's messaging system", p162).
## _uiManager comes from DraggableWindow.


func _ready() -> void:
	super()
	var entry: LineEdit = get_node("%MessageEntry")
	entry.text_submitted.connect(func(_t: String) -> void: _send())
	(get_node("%BtnSend") as Button).pressed.connect(_send)
	(get_node("%BtnCancel") as Button).pressed.connect(CloseWindow)
	(get_node("%BtnReturn") as Button).pressed.connect(func() -> void:
		CloseWindow()
		if _uiManager != null:
			_uiManager.OnMessageIndexClicked("Chat"))
	entry.grab_focus()


func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


func _send() -> void:
	var text := (get_node("%MessageEntry") as LineEdit).text.strip_edges()
	if text.is_empty():
		return
	CommandBus.issue("chat", { "text": text })
	CloseWindow()
