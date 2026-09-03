class_name MessageWindow
extends DraggableWindow
## frontend/MessageWindow.cs - the Comms Center / Message Index.

var _tabContainer: TabContainer
var _lists: Dictionary = {}   # String -> VBoxContainer

var _detailSubject: Label
var _detailBody: RichTextLabel
var _gotoButton: Button

var _selectedMessage: GameMessage

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


func OpenToCategory(categoryName: String) -> void:
	# Find the tab index by matching the name
	for i in _tabContainer.get_child_count():
		# Use the == operator for string comparison to avoid the Equals() error
		if _tabContainer.get_child(i).name == categoryName:
			_tabContainer.current_tab = i
			break

	RefreshCategory(categoryName)


func OnTabManuallyChanged(tabIndex: int) -> void:
	# If the user clicks a tab, populate it on the fly
	var newCategory: String = _tabContainer.get_child(tabIndex).name
	RefreshCategory(newCategory)


func RefreshCategory(categoryFilter: String) -> void:
	# Reset the detail pane and Go To button
	_detailSubject.text = "Select a message..."
	_detailBody.text = "Awaiting selection."
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

	# Automatically select and display the newest transmission in the list
	ShowDetail(filteredMessages[0], null)


# "Click the button on the bottom right-hand side of the window to send a
# message to your opponent" (manual p163, Fig 5.10: the last button of the
# right-hand column). Head-to-head only - there is nobody to chat with in a
# single-player game.
var _composeBtn: Button


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
	if _selectedMessage != null and _selectedMessage.AssociatedLocation != null and _uiManager != null:
		print("Jumping to %s Defenses from comms log." % _selectedMessage.AssociatedLocation.Name)
		# _uiManager.OnDefenseClicked(_selectedMessage.AssociatedLocation)


# --- Daily Simulation Refresh ---
# If messages arrive while the window is open, update the currently visible tab safely!
func StateSignature() -> Variant:
	return GameSignature.ForMessages()


func Refresh() -> void:
	if not CanRefresh():
		return

	if _tabContainer != null and _tabContainer.get_child_count() > 0:
		var currentCategory: String = _tabContainer.get_child(_tabContainer.current_tab).name
		RefreshCategory(currentCategory)
