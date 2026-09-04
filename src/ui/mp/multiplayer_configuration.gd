extends MpScreen
## Multiplayer Configuration screen (manual p157, Fig 5.2): "How do you want to
## play?" with Connect To Game / Setup Game, and Cancel.
##
## Deviation, at TeeJ's instruction (room #197 item 2): the figure's service
## provider list and Proceed are gone - the web has one connection, so the two
## buttons are the whole choice and clicking one goes straight on: Setup Game
## -> Host Game, Connect To Game -> Locate Session.


func _ready() -> void:
	MpSetup.load_names()
	(get_node("%BtnConnectToGame") as Button).pressed.connect(func() -> void: _choose(false))
	(get_node("%BtnSetupGame") as Button).pressed.connect(func() -> void: _choose(true))
	bar().set_previous(false)
	bar().set_proceed_enabled(false, "Choose Connect To Game or Setup Game.")
	(bar().get_node("%BtnProceed") as Button).visible = false
	bar().cancel.connect(cancel_to_cockpit)


func _choose(hosting: bool) -> void:
	MpSetup.hosting = hosting
	go(HostGameScene if hosting else LocateSessionScene)
