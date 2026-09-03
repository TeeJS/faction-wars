extends MpScreen
## Locate Session dialog (manual p159, Fig 5.6), the join side: one box, OK,
## Cancel. "Leave blank to search" lists every game waiting on the relay; a typed
## value is a GAME CODE (the web's deviation from an IP address, settled with
## Doof - docs/multiplayer-ui-design.md question A).

func _ready() -> void:
	MpSetup.load_names()
	var box: LineEdit = get_node("%CodeBox")
	box.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			box.text = up
			box.caret_column = up.length())
	box.text_submitted.connect(func(_t: String) -> void: _ok())
	(get_node("%BtnOK") as Button).pressed.connect(_ok)
	(get_node("%BtnCancel") as Button).pressed.connect(func() -> void: go(ConfigurationScene))
	(get_node("%BtnClose") as Button).pressed.connect(func() -> void: go(ConfigurationScene))
	box.grab_focus()


func _ok() -> void:
	MpSetup.hosting = false
	MpSetup.join_code = (get_node("%CodeBox") as LineEdit).text.strip_edges().to_upper()
	go(JoinGameScene)
