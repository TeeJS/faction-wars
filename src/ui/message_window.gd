class_name MessageWindow
extends DraggableWindow
## frontend/MessageWindow.cs - the Comms Center / Message Index.

var _tabContainer: TabContainer
var _lists: Dictionary = {}   # String -> VBoxContainer

var _detailSubject: Label
var _detailBody: RichTextLabel
var _gotoButton: Button

var _selectedMessage: GameMessage

const PortraitPath := "MainVBox/ContentArea/SplitView/DetailView/PortraitRect"

# Built in code rather than in the scene, so the .tscn needs no editing:
# continue / abort for a mission report, and delete for any message.
var _actionRow: HBoxContainer
var _continueBtn: Button
var _abortBtn: Button
var _deleteBtn: Button

# THE INDEX'S OWN TWO CONTROLS. TEXTSTRA.DLL carries them by name in the
# Message Index string run - "Select All" and "Delete Selected Messages",
# beside the posting options - and Fig 3.18's window shows them as the two
# buttons on the right of the category header bar. "Selected" is the word
# that makes rows selectable at all: deletion in the original is pick-then-
# clear, not one message at a time.
# C#: HashSet<GameMessage>. An Array kept free of duplicates, so membership,
# add and remove read the same.
var _picked: Array = []
var _selectAllBtn: Button
var _deleteSelectedBtn: Button


func _ready() -> void:
	super()

	_tabContainer = get_node("%MessageTabs")
	_detailSubject = get_node("%DetailSubject")
	_detailBody = get_node("%DetailBody")

	# --- =Grab the Go To button and wire it up ---
	_gotoButton = get_node_or_null("%GotoButton")
	BuildActionRow()
	if _gotoButton != null:
		_gotoButton.pressed.connect(OnGotoClicked)
		_gotoButton.disabled = true

	# These MUST match the exact names of the MarginContainers inside your TabContainer
	var categories: Array[String] = [
		"Loyalty", "Fleets", "Missions", "Resources",
		"Manufacturing", "Defense", "Conflict", "Chat", "Advice"
	]

	for cat in categories:
		# Maps to -> %MessageTabs/Fleets/Scroll/List
		_lists[cat] = get_node("%%MessageTabs/%s/Scroll/List" % cat)

	BuildAllTab()
	BuildIndexBar()
	BuildComposeButton()

	# Two tabs whose display differs from the node/enum name that keys the
	# filtering: the shipped alerts-menu word is the singular "Mission"
	# (TEXTSTRA: Loyalty | Fleets | Mission | Resources | Manufacturing |
	# Defense | Conflict | Chat | Advice), and the first tab carries the
	# index run's own "All Messages".
	for i in _tabContainer.get_child_count():
		var tab: String = _tabContainer.get_child(i).name
		if tab == "Missions":
			_tabContainer.set_tab_title(i, "Mission")
		elif tab == AllTab:
			_tabContainer.set_tab_title(i, "All Messages")
		elif tab == "Chat":
			# "Click the Chat Messages tab" (manual p163, Fig 5.10).
			_tabContainer.set_tab_title(i, "Chat Messages")

	# Listen for when the player manually clicks a different tab inside the window
	_tabContainer.tab_changed.connect(OnTabManuallyChanged)


# ★ ALL MESSAGES - A VIEW THE MANUAL DESCRIBES AND THIS WINDOW DID NOT HAVE.
#
# Manual p079 states it by exclusion, in the very table the nine category
# tabs were built from:
#
#   "Advice - agent tips, THE ONLY CATEGORY NOT ALSO SHOWN UNDER ALL
#    MESSAGES."
#
# So the original has an All Messages view holding every category except
# Advice, and the categories were read off that table while the view
# described in the same row was not built. The plumbing half-existed and hid
# it: UIManager.OnMessageIndexClicked already defaults to "All", and
# OpenToCategory looked for a tab of that name, found none, and fell through
# in silence.
#
# Built in code rather than added to MessageWindow.tscn so the tab cannot
# drift out of step with the list of categories above.
const AllTab := "All"


func BuildAllTab() -> void:
	if _tabContainer == null or _lists.has(AllTab):
		return

	var page := MarginContainer.new()
	page.name = AllTab
	page.add_theme_constant_override("margin_left", 5)
	page.add_theme_constant_override("margin_top", 5)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	scroll.add_child(list)
	page.add_child(scroll)
	_tabContainer.add_child(page)

	# First, because it is the default view the window opens on.
	_tabContainer.move_child(page, 0)
	_lists[AllTab] = list


# The bar above the list column, carrying the index's two shipped
# controls - in the original they are the two buttons at the right end of
# the category header bar, over the message list.
#
# ⚠ THE PARENT IS A ROW. SplitView is an HBoxContainer - tabs on the left,
# detail pane on the right - and the first version of this inserted the
# bar as its child, which made the two buttons full-height COLUMNS beside
# the tab area. Placed by assumption, not by reading the scene. The tabs
# column gets wrapped in a VBox of its own so the bar can sit above it,
# compact and right-aligned, inside the same split slot.
func BuildIndexBar() -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END

	_selectAllBtn = Button.new()
	_selectAllBtn.text = "Select All"
	_selectAllBtn.pressed.connect(func() -> void:
		for m in CurrentTabMessages():
			if not _picked.has(m):
				_picked.append(m)
		RefreshCurrentTab())

	_deleteSelectedBtn = Button.new()
	_deleteSelectedBtn.text = "Delete Selected Messages"
	_deleteSelectedBtn.pressed.connect(func() -> void:
		if _picked.size() == 0:
			return
		CommandBus.issue("delete_messages", { "messages": EntityIndex.ids_of_messages(_picked) })
		_picked.clear()
		_selectedMessage = null
		RefreshCurrentTab())

	bar.add_child(_selectAllBtn)
	bar.add_child(_deleteSelectedBtn)

	# Take the tabs' place in the split row, then stack: bar over tabs.
	# The column inherits the tabs' horizontal flags so the split keeps
	# its proportions; the tabs expand vertically to fill what the bar
	# does not use.
	var split: Node = _tabContainer.get_parent()
	var slot: int = _tabContainer.get_index()

	var column := VBoxContainer.new()
	column.size_flags_horizontal = _tabContainer.size_flags_horizontal
	column.size_flags_stretch_ratio = _tabContainer.size_flags_stretch_ratio

	split.remove_child(_tabContainer)
	column.add_child(bar)
	column.add_child(_tabContainer)
	_tabContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	split.add_child(column)
	split.move_child(column, slot)


# What the open tab is currently showing - the same filter RefreshCategory
# paints from, in one place so Select All cannot drift from the list it
# acts on.
func CurrentTabMessages() -> Array:
	if _tabContainer == null or _tabContainer.get_child_count() == 0:
		return []

	return MessagesFor(_tabContainer.get_child(_tabContainer.current_tab).name)


# One filter for every consumer. All Messages is every category BUT Advice.
# That exclusion is the manual's, not a convenience: p079 singles it out,
# and agent advice is also the one kind never auto-deleted.
static func MessagesFor(categoryFilter: String) -> Array:
	var all: bool = categoryFilter.nocasecmp_to(AllTab) == 0

	return Lq.order_by(
		Lq.where(EventBus.VisibleMessages(), func(m: GameMessage) -> bool:
			return (m.Category != Enums.MessageCategory.Advice) if all \
				else JsonUtil.enum_name(Enums.MessageCategory, m.Category).nocasecmp_to(categoryFilter) == 0),
		func(m: GameMessage) -> int: return m.DayReceived,
		true)


func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager
	if not _original and _can_build_original():
		_build_original()


func OpenToCategory(categoryName: String) -> void:
	# Find the tab index by matching the name
	for i in _tabContainer.get_child_count():
		# Use the == operator for string comparison to avoid the Equals() error
		if _tabContainer.get_child(i).name == categoryName:
			_tabContainer.current_tab = i
			break

	if _original:
		_oCategory = categoryName
		_o_show_index()
		return
	RefreshCategory(categoryName)


func OnTabManuallyChanged(tabIndex: int) -> void:
	# If the user clicks a tab, populate it on the fly
	var newCategory: String = _tabContainer.get_child(tabIndex).name
	RefreshCategory(newCategory)


func RefreshCategory(categoryFilter: String) -> void:
	# Remember what the player was reading, so a repaint (a new message arriving,
	# a state change) does not yank the detail pane back to the newest transmission.
	# Reported from play: manually selected messages kept losing focus.
	var prior: GameMessage = _selectedMessage

	# Reset the detail pane and Go To button
	_detailSubject.text = "Select a message..."
	_detailBody.text = "Awaiting selection."
	Art.Fill(get_node_or_null(PortraitPath), null)
	_selectedMessage = null
	if _gotoButton != null:
		_gotoButton.disabled = true

	# Clear out the old buttons in this specific tab's list
	if not _lists.has(categoryFilter):
		return
	var activeList: VBoxContainer = _lists[categoryFilter]
	for child in activeList.get_children():
		child.queue_free()

	# Query the LIVE EventBus log - one filter shared with Select All, so
	# the pair can never act on a different list than the one painted.
	var filteredMessages: Array = MessagesFor(categoryFilter)

	# Selection follows the log: a message the day tick auto-expired must
	# not survive as a phantom pick.
	_picked = Lq.where(_picked, func(m: GameMessage) -> bool: return EventBus.MessageLog.has(m))

	# 4. Handle empty tabs
	if filteredMessages.size() == 0:
		var empty := Label.new()
		empty.text = "No transmissions."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		activeList.add_child(empty)
		return

	# Populate the list with clickable message buttons. TOGGLES, because
	# "Delete Selected Messages" needs rows that can be selected: a pressed
	# row is picked, and clicking also shows the message as before.
	for msg in filteredMessages:
		var msgBtn := Button.new()
		msgBtn.text = "[Day %d] %s" % [msg.DayReceived, msg.Title]
		msgBtn.custom_minimum_size = Vector2(0, 30)
		msgBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		msgBtn.flat = true
		msgBtn.toggle_mode = true

		msgBtn.add_theme_font_size_override("font_size", 13)

		# --- Read vs Unread Styling ---
		var textColor: Color = Color.GRAY if msg.IsRead else Color.WHITE
		msgBtn.add_theme_color_override("font_color", textColor)

		var capturedMsg: GameMessage = msg
		msgBtn.set_pressed_no_signal(_picked.has(capturedMsg))
		msgBtn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				if not _picked.has(capturedMsg):
					_picked.append(capturedMsg)
			else:
				_picked.erase(capturedMsg)
			ShowDetail(capturedMsg, msgBtn))
		# "Double-click a message to view it" (manual p163): the manual's gesture
		# opens the message and leaves the row picked; a single click still works.
		msgBtn.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
				if not _picked.has(capturedMsg):
					_picked.append(capturedMsg)
				msgBtn.set_pressed_no_signal(true)
				ShowDetail(capturedMsg, msgBtn)
				msgBtn.accept_event())

		activeList.add_child(msgBtn)

	# Keep the player's manually-selected message in focus across a repaint; only
	# fall back to the newest transmission when nothing was selected or the prior
	# selection is no longer in this list. (The prior is already read, so no button
	# needs re-greying and ShowDetail will not re-broadcast.)
	var toShow: GameMessage = prior if (prior != null and filteredMessages.has(prior)) else filteredMessages[0]
	ShowDetail(toShow, null)


# "Click the button on the bottom right-hand side of the window to send a
# message to your opponent" (manual p163, Fig 5.10: the last button of the
# right-hand column). Head-to-head only - there is nobody to chat with in a
# single-player game.
var _composeBtn: Button


## The picture a message can carry, from the player's imported originals:
## the character's portrait, else the world's Encyclopedia picture.
static func MessagePicture(message: GameMessage) -> Texture2D:
	if message == null:
		return null
	if message.AssociatedCharacter != null:
		# The original's 400x200 character panel fits this slot; the small
		# portrait is the fallback, shown 1:1 rather than blown up.
		var pic: Texture2D = Art.Picture("characters", message.AssociatedCharacter.PackId)
		if pic == null:
			pic = Art.Portrait("characters", message.AssociatedCharacter.PackId)
		if pic != null:
			return pic
	if message.AssociatedLocation is Planet:
		return Art.Picture("planets", (message.AssociatedLocation as Planet).PackId)
	return null


func BuildComposeButton() -> void:
	if GameSettings.HumanFactions.size() < 2:
		return
	var detail: VBoxContainer = get_node_or_null("%DetailView")
	if detail == null:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_composeBtn = Button.new()
	_composeBtn.text = "Compose Chat Message"
	_composeBtn.tooltip_text = "Compose chat message - send a message to your opponent."
	_composeBtn.custom_minimum_size = Vector2(0, 30)
	_composeBtn.pressed.connect(func() -> void:
		if _uiManager != null:
			_uiManager.OpenComposeChatMessage())
	row.add_child(_composeBtn)
	detail.add_child(row)


# The original's mission report carries a tick and a cross - "Do you wish
# the mission to continue?" (manual p110) - and every message can be
# cleared. Both live under the message body.
func BuildActionRow() -> void:
	_actionRow = HBoxContainer.new()

	_continueBtn = Button.new()
	_continueBtn.text = "Continue Mission"
	_continueBtn.pressed.connect(func() -> void:
		# Continuing is simply letting it run - the manual's default, since
		# an unanswered report continues on its own (p110).
		_selectedMessage.PendingMission = null
		RefreshCurrentTab())

	_abortBtn = Button.new()
	_abortBtn.text = "Abort Mission"
	_abortBtn.pressed.connect(func() -> void:
		CommandBus.issue("abort_mission", { "mission": _selectedMessage.PendingMission.Serial })
		_selectedMessage.PendingMission = null
		RefreshCurrentTab())

	_deleteBtn = Button.new()
	_deleteBtn.text = "Delete"
	_deleteBtn.pressed.connect(func() -> void:
		if _selectedMessage != null:
			CommandBus.issue("delete_messages", { "messages": [_selectedMessage.Serial] })
		_selectedMessage = null
		RefreshCurrentTab())

	_actionRow.add_child(_continueBtn)
	_actionRow.add_child(_abortBtn)
	_actionRow.add_child(_deleteBtn)

	var host: Node = _detailBody.get_parent() if _detailBody != null else self
	host.add_child(_actionRow)


func RefreshCurrentTab() -> void:
	if _tabContainer == null or _tabContainer.get_child_count() == 0:
		return
	RefreshCategory(_tabContainer.get_child(_tabContainer.current_tab).name)


func ShowDetail(message: GameMessage, clickedButton: Button) -> void:
	_selectedMessage = message

	# Mark as read and dim the button text in the list if they clicked it directly
	#
	# ⚠ ONLY ANNOUNCE AN ACTUAL TRANSITION. This used to set IsRead and
	# broadcast unconditionally, which froze the game the moment a message
	# was opened:
	#
	#   ShowDetail -> BroadcastChanged -> UIManager.RefreshNow
	#     -> MessageWindow.Refresh -> RefreshCategory
	#     -> auto-selects the newest message -> ShowDetail -> ...
	#
	# RefreshCategory ends by selecting the top message itself, so an
	# unconditional broadcast re-entered forever. Guarding on the
	# transition breaks it: the second pass finds the message already read,
	# says nothing, and the recursion stops one level deep.
	var wasUnread: bool = not message.IsRead
	message.IsRead = true

	# Reading clears the unread count, so the alert bar has to repaint now
	# rather than at the next day tick.
	if wasUnread:
		EventBus.BroadcastChanged()
	if clickedButton != null:
		clickedButton.add_theme_color_override("font_color", Color.GRAY)

	# Instantly update the right-hand panel
	_detailSubject.text = "Day %d: %s" % [message.DayReceived, message.Title]
	_detailBody.text = message.Body
	# The message's picture: the character it is about, else its world.
	Art.Fill(get_node_or_null(PortraitPath), MessagePicture(message))

	# --- Enable Go To if this message is attached to a planet ---
	if _gotoButton != null:
		_gotoButton.disabled = (message.AssociatedLocation == null)

	var asks: bool = message.AwaitsDecision()
	if _continueBtn != null:
		_continueBtn.visible = asks
	if _abortBtn != null:
		_abortBtn.visible = asks
	if _deleteBtn != null:
		_deleteBtn.visible = true


func OnGotoClicked() -> void:
	if _selectedMessage == null or _uiManager == null:
		return
	var planet: Planet = _selectedMessage.AssociatedLocation as Planet
	if planet == null:
		return
	_uiManager.OnDefenseClicked(planet)


# --- Daily Simulation Refresh ---
# If messages arrive while the window is open, update the currently visible tab safely!
func StateSignature() -> Variant:
	return GameSignature.ForMessages()


func Refresh() -> void:
	if not CanRefresh():
		return

	if _original:
		if _oSummary != null and _oSummary.visible and _selectedMessage != null and EventBus.MessageLog.has(_selectedMessage):
			_o_show_summary(_selectedMessage)
		else:
			_o_show_index()
		return

	if _tabContainer != null and _tabContainer.get_child_count() > 0:
		var currentCategory: String = _tabContainer.get_child(_tabContainer.current_tab).name
		RefreshCategory(currentCategory)


# ---- THE ORIGINAL'S MESSAGE INDEX ---------------------------------------------
#
# With the player's imported art the Comms Center is the original's Message
# Index (manual p078 Fig 3.18), composed from its bitmaps at the places
# measured on TeeJ's screenshots of the original (both sides, the Advice tab
# with nine rows and the Popular Support tab empty - each rebuilt pixel for
# pixel): the side's frame (10336 / 10335), the plate (10822) with its band and
# starfield list, the ten category tabs, the band's caption, Select All and
# Delete, the rows (the category icon, the title in Arial bold 10, grey, white
# on the side's bar when selected, a row every 21 pixels from y 108), and the
# frame's side buttons: Close, Message Summary, Post Messages with Alert /
# Silently, Open Window, Compose Chat. Reading a message (double-click, or
# Message Summary) shows it in the same frame (Figs 2.38, 3.19): its title on
# the band, its picture, its text, the arrows that step through the tab, and
# the tick and cross of a report that asks. PROVISIONAL until there is a
# screenshot of the original's: that view's layout (it follows the
# Encyclopedia's topic view and the Scrap dialog), the read rows' "lighter
# type", and the row icons of Mission, Manufacturing and Chat.

const OriginalW := 470
const OriginalH := 330
const OTabNames := ["msg_all", "msg_loyalty", "msg_fleets", "msg_missions", "msg_resources",
	"msg_manufacturing", "msg_defense", "msg_conflict", "msg_chat", "msg_advice"]
const OTabCategories := ["All", "Loyalty", "Fleets", "Missions", "Resources",
	"Manufacturing", "Defense", "Conflict", "Chat", "Advice"]
const OTabXs := [22, 60, 98, 136, 173, 211, 249, 285, 323, 360]
const OTabY := 46
## The band names the tab (TEXTSTRA.DLL 32784-32792, 32818).
const OBandCaptions := {"All": "All Messages", "Loyalty": "Popular Support Messages",
	"Fleets": "Fleet Messages", "Missions": "Mission Messages", "Resources": "Resource Messages",
	"Manufacturing": "Manufacturing Messages", "Defense": "Defense Messages",
	"Conflict": "Conflict Messages", "Chat": "Chat Messages", "Advice": "Advice Messages"}
## A row's 15x15 category icon (Advice per side seen; the others matched by
## what they show; Mission, Manufacturing and Chat have none identified yet).
const ORowIcons := {"Loyalty": "msgicon.loyalty", "Fleets": "msgicon.fleets.%s",
	"Resources": "msgicon.resources", "Conflict": "msgicon.conflict", "Defense": "msgicon.defense"}
const OListRect := Rect2(23, 108, 373, 194)
const ORowPitch := 21
const OGrey := Color(120 / 255.0, 120 / 255.0, 120 / 255.0)
## The side buttons: the Empire's 44x41 at x 426, the Alliance's 32x31 at x 423.
const OSideX := {"empire": 426, "alliance": 423}
const OSideYs := {"empire": [21, 89, 148, 207, 266], "alliance": [25, 93, 147, 201, 255]}

var _original := false
var _oSide := "empire"
var _oCategory := "All"
var _oIndex: Control
var _oSummary: Control
var _oTabs: Array = []
var _oCaption: Label
var _oRows: VBoxContainer
var _oScroll: ScrollContainer
var _oSummaryBtn: TextureButton
var _oOpenBtn: TextureButton
var _oPostBtn: TextureButton
var _oComposeBtn: TextureButton
var _oAnchor: GameMessage
var _oSumIcon: TextureRect
var _oSumTitle: Label
var _oSumPicture: TextureRect
var _oSumText: Label
var _oOk: TextureButton
var _oCancel: TextureButton
var _oUp: TextureButton
var _oDown: TextureButton

## Post Messages Silently, per tab (manual p080). The original silences the
## droid's whirs and beeps; this build has no message sounds yet, so the
## toggle is kept and shown but has nothing to silence.
static var _silent: Dictionary = {}


func _can_build_original() -> bool:
	return OUI.Has(["frame.empire", "frame.alliance", "msgindex_plate", "msgindex_selection.empire", "ency_topic_plate"]) \
		and Art.ButtonIcon("msgindex_select_all") != null and Art.ButtonIcon("msgindex_summary.empire") != null \
		and Art.TabIcon("msg_all", "") != null


## The window's size as the original draws it.
func OriginalSize() -> Vector2:
	return Vector2(OriginalW, OriginalH) * OUI.K


func _build_original() -> void:
	_original = true
	var f: Faction = GameSettings.PlayerFaction
	_oSide = "alliance" if f != null and f.Id == "alliance" else "empire"
	var bar: Control = get_node_or_null("%TitleBar")
	if bar != null:
		bar.visible = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var area: MarginContainer = OUI.Flatten(self)
	for c in area.get_children():
		(c as CanvasItem).visible = false   # the plain split view: its lookups stay, hidden
	custom_minimum_size = OriginalSize()
	var body := Control.new()
	body.name = "OriginalBody"
	body.custom_minimum_size = OriginalSize()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(body)
	var K: int = OUI.K

	# ---- the index (Fig 3.18) ----
	_oIndex = _o_view(body, "IndexView", "msgindex_plate")
	OUI.Text(_oIndex, "Message Index", 15, 20, 250, 24, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Title")
	_oTabs.clear()
	for i in OTabNames.size():
		var tb := TextureButton.new()
		tb.name = "Tab_%s" % OTabCategories[i]
		tb.set_meta("normal", OUI.Tab(OTabNames[i], _oSide))
		tb.set_meta("current", OUI.Tab(OTabNames[i], _oSide, "pressed"))
		tb.texture_normal = tb.get_meta("normal")
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.position = Vector2(OTabXs[i], OTabY) * K
		tb.size = (tb.texture_normal as Texture2D).get_size() if tb.texture_normal != null else Vector2(36, 41) * K
		tb.tooltip_text = OBandCaptions[OTabCategories[i]]
		var cat: String = OTabCategories[i]
		tb.pressed.connect(func() -> void: OpenToCategory(cat))
		_oIndex.add_child(tb)
		_oTabs.append(tb)
	_oCaption = OUI.Text(_oIndex, "", 35, 90, 240, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Caption")
	OUI.PictureButton(_oIndex, "msgindex_select_all", 282, 87, "Select All").pressed.connect(func() -> void:
		for m in MessagesFor(_oCategory):
			if not _picked.has(m):
				_picked.append(m)
		_o_show_index())
	OUI.PictureButton(_oIndex, "msgindex_delete", 340, 87, "Delete Selected Messages").pressed.connect(func() -> void:
		if _picked.is_empty():
			return
		CommandBus.issue("delete_messages", { "messages": EntityIndex.ids_of_messages(_picked) })
		_picked.clear()
		_selectedMessage = null
		_o_show_index())
	_oScroll = ScrollContainer.new()
	_oScroll.name = "List"
	_oScroll.position = OListRect.position * K
	_oScroll.size = OListRect.size * K
	_oScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_oIndex.add_child(_oScroll)
	EncyclopediaWindow.StyleScrollBar(_oScroll.get_v_scroll_bar())
	_oRows = VBoxContainer.new()
	_oRows.add_theme_constant_override("separation", 0)
	_oScroll.add_child(_oRows)

	# ---- a message, read (Figs 2.38, 3.19; PROVISIONAL) ----
	_oSummary = _o_view(body, "SummaryView", "ency_topic_plate")
	_oSummary.visible = false
	_oSumIcon = OUI.Place(_oSummary, null, 30, 15, "Icon")
	_oSumTitle = OUI.Text(_oSummary, "", 49, 14, 290, 17, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true, "Title")
	_oSumTitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_oSumTitle.clip_text = true
	_oSumPicture = TextureRect.new()
	_oSumPicture.name = "Picture"
	_oSumPicture.position = Vector2(12, 31) * K
	_oSumPicture.size = Vector2(400, 200) * K
	_oSumPicture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_oSumPicture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_oSumPicture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oSummary.add_child(_oSumPicture)
	_oSumText = OUI.Text(_oSummary, "", 24, 242, 380, 76, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Text")
	_oSumText.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	OUI.LinePitch(_oSumText, 13, 16)
	_oOk = OUI.PictureButton(_oSummary, "decision_ok", 355, 244, "Continue the mission")
	_oOk.pressed.connect(func() -> void:
		if _selectedMessage != null:
			_selectedMessage.PendingMission = null
			_o_show_summary(_selectedMessage))
	_oCancel = OUI.PictureButton(_oSummary, "decision_cancel", 355, 281, "Abort the mission")
	_oCancel.pressed.connect(func() -> void:
		if _selectedMessage != null and _selectedMessage.PendingMission != null:
			CommandBus.issue("abort_mission", { "mission": _selectedMessage.PendingMission.Serial })
			_selectedMessage.PendingMission = null
			_o_show_summary(_selectedMessage))
	_oUp = OUI.PictureButton(_oSummary, "msgsummary_up", 352, 15, "Scroll through messages")
	_oUp.pressed.connect(func() -> void: _o_step(-1))
	_oDown = OUI.PictureButton(_oSummary, "msgsummary_down", 373, 15, "Scroll through messages")
	_oDown.pressed.connect(func() -> void: _o_step(1))

	# ---- the frame over both, and its side buttons ----
	var frame := OUI.Place(body, OUI.Pic("frame." + _oSide), 0, 0, "Frame")
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.gui_input.connect(OnTitleBarGuiInput)
	if _oSide == "alliance":
		OUI.Place(body, OUI.Pic("msgindex_side.alliance"), 412, 0, "SideColumn")
	# The views' own pictures on the band sit above the frame.
	body.move_child(_oIndex, body.get_child_count() - 1)
	body.move_child(_oSummary, body.get_child_count() - 1)
	var x: int = OSideX[_oSide]
	var ys: Array = OSideYs[_oSide]
	OUI.PictureButton(body, "ency_close." + _oSide, x, ys[0], "Close message screen").pressed.connect(func() -> void:
		CloseWindow()
		if _uiManager != null:
			_uiManager.RefreshCommsHighlights.call_deferred())
	_oSummaryBtn = _o_side_button(body, "msgindex_summary." + _oSide, x, ys[1], "Message Summary")
	_oSummaryBtn.pressed.connect(func() -> void:
		if _oSummary.visible:
			_o_show_index()
		elif _selectedMessage != null:
			_o_show_summary(_selectedMessage))
	_oPostBtn = _o_side_button(body, "msgindex_post." + _oSide, x, ys[2], "Post Messages with Alert / Silently")
	_oPostBtn.toggle_mode = true
	_oPostBtn.toggled.connect(func(on: bool) -> void:
		_silent[_oCategory] = on
		_oPostBtn.tooltip_text = "Post Messages Silently" if on else "Post Messages with Alert")
	_oOpenBtn = _o_side_button(body, "msgindex_open." + _oSide, x, ys[3], "Open Window")
	_oOpenBtn.pressed.connect(OnGotoClicked)
	_oComposeBtn = _o_side_button(body, "msgindex_compose." + _oSide, x, ys[4], "Compose Chat Message")
	_oComposeBtn.disabled = GameSettings.HumanFactions.size() < 2
	_oComposeBtn.pressed.connect(func() -> void:
		if _uiManager != null:
			_uiManager.OpenComposeChatMessage())


func _o_view(body: Control, view_name: String, plate: String) -> Control:
	var v := Control.new()
	v.name = view_name
	v.size = OriginalSize()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(v)
	OUI.Place(v, OUI.Pic(plate), 12, 13, "Plate")
	return v


func _o_side_button(parent: Control, button_name: String, x: int, y: int, tip: String) -> TextureButton:
	var b := OUI.PictureButton(parent, button_name, x, y, tip)
	b.texture_disabled = OUI.Btn(button_name, "disabled")
	return b


func _o_show_index() -> void:
	if _oIndex == null:
		return
	_oIndex.visible = true
	_oSummary.visible = false
	for i in _oTabs.size():
		(_oTabs[i] as TextureButton).texture_normal = _oTabs[i].get_meta("current" if OTabCategories[i] == _oCategory else "normal")
	_oCaption.text = OBandCaptions.get(_oCategory, "")
	_oPostBtn.set_pressed_no_signal(bool(_silent.get(_oCategory, false)))
	var messages: Array = MessagesFor(_oCategory)
	_picked = Lq.where(_picked, func(m: GameMessage) -> bool: return messages.has(m))
	if _selectedMessage != null and not messages.has(_selectedMessage):
		_selectedMessage = null
	for c in _oRows.get_children():
		_oRows.remove_child(c)
		c.queue_free()
	for m in messages:
		_oRows.add_child(_o_row(m))
	_o_update_buttons()


## A row: the category icon, the title; picked, the side's bar under it and
## the title in white. Unread titles bold, read ones regular - the manual's
## "lighter type" (p079; not yet on a screenshot).
func _o_row(m: GameMessage) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(OListRect.size.x, ORowPitch) * OUI.K
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var picked: bool = _picked.has(m)
	if picked:
		OUI.Place(row, OUI.Pic("msgindex_selection." + _oSide), 2, 0, "Bar")
	var cat: String = JsonUtil.enum_name(Enums.MessageCategory, m.Category)
	var icon: String = _o_icon(cat)
	if not icon.is_empty():
		OUI.Place(row, OUI.Pic(icon), 3, 1, "Icon")
	var title := OUI.Text(row, m.Title, 35, 1, 338, 19, 10, Color.WHITE if picked else OGrey, HORIZONTAL_ALIGNMENT_LEFT, not m.IsRead, "Title")
	title.clip_text = true
	row.tooltip_text = "Day %d: %s" % [m.DayReceived, m.Title]
	row.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
			return
		row.accept_event()
		if e.double_click:
			_picked = [m]
			_o_show_summary(m)
			return
		_o_pick(m, e.ctrl_pressed, e.shift_pressed))
	return row


## A category's row icon for our side, or "" where none is identified.
func _o_icon(cat: String) -> String:
	if cat == "Advice":
		return "msgicon.advice." + _oSide
	var icon: String = str(ORowIcons.get(cat, ""))
	return icon % _oSide if icon.contains("%s") else icon


## Click picks one; ctrl-click adds or removes one; shift-click picks the run
## from the last click (manual p079).
func _o_pick(m: GameMessage, add: bool, run: bool) -> void:
	var messages: Array = MessagesFor(_oCategory)
	if run and _oAnchor != null and messages.has(_oAnchor):
		var a: int = messages.find(_oAnchor)
		var b: int = messages.find(m)
		_picked = messages.slice(mini(a, b), maxi(a, b) + 1)
	elif add:
		if _picked.has(m):
			_picked.erase(m)
		else:
			_picked.append(m)
	else:
		_picked = [m]
	_oAnchor = m
	_selectedMessage = m
	_o_show_index()


func _o_update_buttons() -> void:
	var one: GameMessage = _selectedMessage
	_oSummaryBtn.disabled = _oIndex.visible and one == null
	_oOpenBtn.disabled = one == null or one.AssociatedLocation == null


## A message read: its category icon and title on the band, its picture, its
## text, and the tick and cross when it asks (Fig 2.38).
func _o_show_summary(m: GameMessage) -> void:
	_selectedMessage = m
	_oIndex.visible = false
	_oSummary.visible = true
	var wasUnread: bool = not m.IsRead
	m.IsRead = true
	if wasUnread:
		EventBus.BroadcastChanged()
	var cat: String = JsonUtil.enum_name(Enums.MessageCategory, m.Category)
	var icon: String = _o_icon(cat)
	_oSumIcon.texture = OUI.Pic(icon) if not icon.is_empty() else null
	_oSumIcon.size = _oSumIcon.texture.get_size() if _oSumIcon.texture != null else Vector2.ZERO
	_oSumTitle.text = m.Title
	var pic: Texture2D = MessagePicture(m)
	_oSumPicture.texture = Art.Scaled(pic, OUI.K) if pic != null else null
	var asks: bool = m.AwaitsDecision()
	_oOk.visible = asks
	_oCancel.visible = asks
	_oSumText.size.x = (325 if asks else 380) * OUI.K
	_oSumText.text = m.Body
	var messages: Array = MessagesFor(_oCategory)
	var at: int = messages.find(m)
	_oUp.disabled = at <= 0
	_oDown.disabled = at < 0 or at >= messages.size() - 1
	_o_update_buttons()


## The band's arrows: the previous or next message on this tab.
func _o_step(delta: int) -> void:
	var messages: Array = MessagesFor(_oCategory)
	var at: int = messages.find(_selectedMessage)
	var to: int = at + delta
	if to >= 0 and to < messages.size():
		_picked = [messages[to]]
		_o_show_summary(messages[to])
