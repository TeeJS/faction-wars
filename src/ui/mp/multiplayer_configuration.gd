extends MpScreen
## Multiplayer Configuration screen (manual p157, Fig 5.2): the list the
## original calls service providers, "How do you want to play?" with Connect To
## Game / Setup Game, then the right arrow to go on, and Cancel.
##
## The list is TeeJ's (2026-09-25), in place of the original's serial, modem
## and TCP/IP: "Open-games list" (greyed - not in this game yet) and "Shared
## Invite code", the one there is, selected. As in the original, a choice is
## picked ("The currently selected option will be depressed") and the right
## arrow proceeds: Setup Game -> Host Game, Connect To Game -> Locate Session.
## In the original's look when its screen is imported (original_mp.gd), from
## TeeJ's screenshot of the original's, measured.

const OriginalMp := preload("res://src/ui/mp/original_mp.gd")

## The list: each entry's words and whether it can be chosen yet.
const Providers := [["Open-games list", false], ["Shared Invite code", true]]
const Chosen := 1
const NotYet := "Not in this game yet."
const Heading := ["Please select a service provider for the type of", "connection you want to use from the list below."]
const How := "How do you want to play?"
const Choices := ["Connect To Game", "Setup Game"]

## The original's layout (px of its 640 x 480 screen, measured on TeeJ's
## screenshot): the heading's two lines centred on x 318.5, capitals at y 82
## and 100, Arial 15.5; the list from x 145, capitals at y 130 then every 20,
## Arial 13; "How do you want to play?" centred on 318, capitals at 284; the
## two choice boxes (152 x 33) at (139, 313) and (346, 313), their words centred
## in them, capitals at 324, Arial 12.5 - green, red while chosen.
const HeadCentre := 318.5
const HeadTops := [82, 100]
const HeadPx := 15.5
const ListX := 145
const ListTop := 130
const ListPitch := 20
const ListPx := 13.0
const HowTop := 284
const ChoiceAt := [Vector2(139, 313), Vector2(346, 313)]
const ChoiceSize := Vector2(152, 33)
const ChoiceTextTop := 324
const ChoicePx := 12.5
## The greyed entry: darker than the original's grey, which is its colour for
## an entry that can be chosen but is not.
const NotYetGrey := Color(0.3, 0.3, 0.3)

## -1 until a choice is made; then 0 Connect To Game, 1 Setup Game.
var _choice: int = -1
var _look: OriginalMp
var _boxes: Array = []
var _words: Array = []


func _ready() -> void:
	MpSetup.load_names()
	var list: ItemList = get_node("%Providers")
	for i in Providers.size():
		list.add_item(Providers[i][0])
		list.set_item_disabled(i, not Providers[i][1])
		if not Providers[i][1]:
			list.set_item_tooltip(i, NotYet)
	list.select(Chosen)
	list.item_selected.connect(func(_i: int) -> void: list.select(Chosen))
	for i in 2:
		var b: Button = get_node("%BtnConnectToGame" if i == 0 else "%BtnSetupGame")
		b.toggle_mode = true
		var which := i
		b.pressed.connect(func() -> void: _choose(which))
	bar().set_previous(false)
	bar().proceed.connect(_proceed)
	bar().cancel.connect(cancel_to_cockpit)
	if OriginalMp.CanBuild("mp_connection"):
		_dress()
	_refresh()


func _choose(which: int) -> void:
	_choice = which
	_refresh()


func _refresh() -> void:
	(get_node("%BtnConnectToGame") as Button).set_pressed_no_signal(_choice == 0)
	(get_node("%BtnSetupGame") as Button).set_pressed_no_signal(_choice == 1)
	for i in _boxes.size():
		(_boxes[i] as TextureButton).texture_normal = OriginalMp.Art.WindowPicture("mp_choice.chosen" if i == _choice else "mp_choice")
		(_words[i] as Label).add_theme_color_override("font_color", OriginalMp.Red if i == _choice else OriginalMp.Green)
	bar().set_proceed_enabled(_choice >= 0, "" if _choice >= 0 else "Choose Connect To Game or Setup Game.")


func _proceed() -> void:
	if _choice < 0:
		return
	MpSetup.hosting = _choice == 1
	go(HostGameScene if MpSetup.hosting else LocateSessionScene)


func _dress() -> void:
	_look = OriginalMp.Dress(self, "mp_connection") as OriginalMp
	for i in HeadTops.size():
		_look.Text(Heading[i], HeadCentre - 200, HeadTops[i], 400, HeadPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "Heading%d" % i)
	for i in Providers.size():
		var row: Label = _look.Text(Providers[i][0], ListX, ListTop + i * ListPitch, 300, ListPx,
			OriginalMp.Red if i == Chosen else NotYetGrey, HORIZONTAL_ALIGNMENT_LEFT, "Provider%d" % i)
		if not Providers[i][1]:
			row.tooltip_text = NotYet
	_look.Text(How, 318 - 200, HowTop, 400, HeadPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "How")
	for i in 2:
		var box := TextureButton.new()
		box.name = "Choice%d" % i
		box.ignore_texture_size = true
		box.stretch_mode = TextureButton.STRETCH_SCALE
		box.tooltip_text = (get_node("%BtnConnectToGame" if i == 0 else "%BtnSetupGame") as Button).tooltip_text
		var which := i
		box.pressed.connect(func() -> void: _choose(which))
		_look.Add(box, Rect2(ChoiceAt[i], ChoiceSize))
		_boxes.append(box)
		var words: Label = _look.Text(Choices[i], ChoiceAt[i].x, ChoiceTextTop, ChoiceSize.x, ChoicePx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "ChoiceText%d" % i)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_words.append(words)
