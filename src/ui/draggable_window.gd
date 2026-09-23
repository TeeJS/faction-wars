class_name DraggableWindow
extends PanelContainer
## frontend/DraggableWindow.cs - the base of every data window: title-bar drag,
## close, minimise to the taskbar, the change-driven repaint, and the personnel
## row builder with its menu (manual p045, Fig 2.40) shared by every window that
## lists people.

## The player's own artwork overlay (tools/RebellionArtImporter).
const Art := preload("res://src/ui/artwork.gd")

var _pendingRefresh: bool = false

## Shared by every window that lists people or units.
var _uiManager: UIManager
var SelectedCharacters: Array[Character] = []

## The UIManager listens to this. C#: event Action<DraggableWindow> OnMinimized.
signal OnMinimized(window: DraggableWindow)

## So the taskbar knows what to name the button.
var WindowTitle: String = "Data Window"

var _isDragging: bool = false
var _dragOffset: Vector2

var _paintedSignature: Variant = null
var _everPainted: bool = false


func _ready() -> void:
	# As in the C#: the two buttons are required lookups first (a scene without
	# them is malformed and says so), then fetched again optionally for wiring.
	var closeBtn: Button = get_node("%CloseButton")
	var minBtn: Button = get_node("%MinimizeButton")
	var titleBar: Control = get_node("%TitleBar")

	var closeButton: Button = get_node_or_null("%CloseButton")
	if closeButton != null:
		closeButton.pressed.connect(queue_free)
	var minimizeButton: Button = get_node_or_null("%MinimizeButton")
	if minimizeButton != null:
		minimizeButton.pressed.connect(MinimizeWindow)
	titleBar.gui_input.connect(OnTitleBarGuiInput)


func OnTitleBarGuiInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_isDragging = true
			_dragOffset = get_global_mouse_position() - global_position
			move_to_front()
		else:
			_isDragging = false
	elif event is InputEventMouseMotion and _isDragging:
		global_position = get_global_mouse_position() - _dragOffset


func CloseWindow() -> void:
	queue_free()


## A modal window (OUI.Modal) closes on Esc: "Cancel/Close Window - cancels
## the current command (same as clicking Close or Cancel)" (manual p064).
var CloseOnEscape: bool = false


func _unhandled_key_input(event: InputEvent) -> void:
	if CloseOnEscape and visible and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		CloseWindow()


func MinimizeWindow() -> void:
	# Hide the entire window and tell the UIManager to create a taskbar button.
	visible = false
	OnMinimized.emit(self)


## Overridden by every dynamic window to re-run its Populate().
func Refresh() -> void:
	pass


## What this window is currently showing, as a cheap string. Null means "I
## cannot describe my state" - such a window is left to the day tick. See
## GameSignature for why it is derived rather than announced.
func StateSignature() -> Variant:
	return null


## Called by the UIManager poll. Repaints ONLY on a real difference, so a window
## nobody has disturbed is never rebuilt out from under a click.
func RefreshIfChanged() -> void:
	var now: Variant = StateSignature()
	if now == null:
		return
	# A menu or a dialog is open on this window - leave it completely alone.
	if HasOpenPopup():
		return
	if _everPainted and now == _paintedSignature:
		return
	_paintedSignature = now
	_everPainted = true
	Refresh()


## IS ANYTHING OPEN ON THIS WINDOW RIGHT NOW - asked of the tree, not of a
## counter. A PopupMenu and a ConfirmationDialog are both Windows.
func HasOpenPopup() -> bool:
	return _HasOpenPopup(self)


static func _HasOpenPopup(node: Node) -> bool:
	for child in node.get_children():
		if child is Window:
			if is_instance_valid(child) and child.visible:
				return true
			continue   # a hidden popup cannot contain a visible one
		if _HasOpenPopup(child):
			return true
	return false


func CanRefresh() -> bool:
	# Checked here as well, so the day tick and the state event cannot walk over
	# a dialog either - they call Refresh() directly, bypassing the poll.
	if HasOpenPopup():
		_pendingRefresh = true
		return false
	_pendingRefresh = false
	return true


func RegisterPopupMenu(popup: PopupMenu) -> void:
	# Nudge the window the instant a menu closes instead of waiting for the poll.
	popup.popup_hide.connect(func() -> void:
		if _pendingRefresh and CanRefresh():
			Refresh())


# =======================================================================
#  PERSONNEL ROWS - SHARED (manual p045 Fig 2.40; p055-p056; p115)
# =======================================================================

## ONE ROW BUILDER FOR EVERY CHARACTER on this tab, yours and theirs.
func DrawCharacterRow(list: Container, character: Character, uiManager: UIManager) -> void:
	var nameColor: Color = character.Faction.FactionColor
	# RANK IS A PREFIX: "Admiral Ackbar", "General Madine" (TEXTSTRA.DLL).
	var displayText: String = character.Name if character.Rank == Enums.Rank.None \
		else "%s %s" % [JsonUtil.enum_name(Enums.Rank, character.Rank), character.Name]

	# "Characters have FOUR statuses: Ready, In transit, CAPTURED, INJURED"
	# (manual p096); the Status field reads "awaiting orders; ON A MISSION at a
	# system; in transit between systems" (p101).
	if character.IsCaptured():
		displayText += " (Captured - %s)" % character.CapturedBy.DisplayName
		nameColor = Color.MEDIUM_PURPLE
	elif character.Status == Enums.Status.Enroute:
		displayText += " (Enroute)"
		nameColor = Color.DARK_GRAY
	elif character.Status == Enums.Status.OnMission:
		var job: Mission = Lq.first_or_null(MissionManager.Active(),
			func(m: Mission) -> bool: return not m.Finished and m.Team.has(character))
		displayText += (" (On Mission - %s)" % job.DisplayName()) if job != null else " (On Mission)"
		nameColor = Color.GOLDENROD
	elif character.IsInjured():
		displayText += " (Injured)"
		nameColor = Color.INDIAN_RED

	# ONLY ONCE EXPOSED, and never the number (manual p094).
	if character.TraitorRevealed:
		displayText += " [TRAITOR]"
		nameColor = Color.ORANGE

	AddCharacterToList(list, character, displayText, nameColor, uiManager)


## Right-click a character, choose Mission, "the cursor changes to cross hairs,
## then select a target" - and only THEN "the Create Mission window comes up"
## (manual p102).
func StartMissionTargeting(team: Array, uiManager: UIManager) -> void:
	# "All team members must be on the same system OR FLEET to begin together".
	var origin: Planet = OrderManager.SystemOf(team[0].Attached)
	if origin == null:
		print("Team is not on a system.")
		return

	print("[Mission] Select a target - a system, or a person in a System Defenses window.")

	# "Missions are OBJECT-SPECIFIC... click on ANY AREA OF BLANK SPACE in the
	# system's window" (p040). A FLEET PICKED AS A MISSION TARGET MEANS ITS SYSTEM.
	uiManager.StartTargetingObject(
		func(target: Planet) -> void: OpenCreateMission(team, origin, target),
		func(picked: Variant) -> void:
			OpenCreateMission(team, origin, PlanetOf(picked), null if picked is Fleet else picked))


## Where a targetable object is standing, so the team knows where to fly.
static func PlanetOf(picked: Variant) -> Planet:
	if picked is Character:
		return OrderManager.SystemOf(picked.Attached)
	if picked is Unit:
		return OrderManager.SystemOf(picked.Attached)
	if picked is Facility:
		return picked.Attached
	if picked is Fleet:
		return picked.Attached
	return null


## The Create Mission window (manual p102, figs 2.34 and 3.47).
func OpenCreateMission(team: Array, origin: Planet, target: Planet, picked: Variant = null) -> void:
	if target == null:
		print("[Mission] That target is nowhere we can reach.")
		return
	var actor: Faction = team[0].Faction

	# A person is one kind of object; a facility or a unit is the other.
	var victim: Character = picked as Character
	var thing: Variant = null if picked is Character else picked

	var legal: Array[int] = []

	# Three filters: what the TEAM can do, what the SYSTEM accepts, and - when a
	# person was clicked - what may be done to THEM (manual p102).
	for t in Enums.MissionType.values():
		if not MissionManager.TeamCanPerform(team, t):
			continue
		if not MissionManager.CanTarget(t, actor, target).ok:
			continue
		var needsPerson: bool = MissionManager.NeedsCharacterTarget(t)
		var needsThing: bool = MissionManager.NeedsObjectTarget(t)
		if needsPerson != (victim != null):
			continue
		if needsThing != (thing != null):
			continue
		if needsPerson and not MissionManager.CanTargetPerson(t, actor, victim).ok:
			continue
		if needsThing and not MissionManager.CanSabotage(actor, thing, target).ok:
			continue
		legal.append(t)

	if legal.is_empty():
		# Say WHY, and say the RIGHT why.
		var elsewhere: Array = MissionManager.PerformableBy(team)
		var why: String = ""
		var sab: Result = MissionManager.CanSabotage(actor, thing, target) if thing != null else null
		# A mission this team could run here but for a team rule (Recruitment
		# without a major character) - name the rule.
		var ruled_out: String = ""
		if thing == null and victim == null:
			for t in Enums.MissionType.values():
				if MissionManager.NeedsCharacterTarget(t) or MissionManager.NeedsObjectTarget(t):
					continue
				if not MissionManager.CanTarget(t, actor, target).ok or not Lq.all(team, func(u: Unit) -> bool: return MissionManager.CanPerform(u, t)):
					continue
				var rule: Result = MissionManager.TeamMeetsExtraRule(team, t)
				if not rule.ok:
					ruled_out = rule.error
					break
		if thing != null and not sab.ok:
			why = sab.error
		elif not ruled_out.is_empty():
			why = ruled_out
		elif thing == null and victim == null and MissionManager.TeamCanPerform(team, Enums.MissionType.Sabotage):
			# The targets are named in the PACK's words (display.json terms): a
			# setting without shields or squadrons lists what it does have.
			why = ("Sabotage needs a specific target, not the system: open the "
				+ "system's Defenses or Manufacturing window and put the crosshair on "
				+ "the %s, %s, %s, %s or facility itself, or on a ship in a fleet.") \
				% [Terms.lower("planetary_shields"), Terms.lower("orbital_batteries"), Terms.lower("trooper_regiment"), Terms.lower("fighter_squadron")]
		elif elsewhere.is_empty():
			why = "%s cannot perform any mission this game has implemented yet." \
				% ", ".join(Lq.select(team, func(u: Unit) -> String: return u.Name))
		else:
			why = MissionManager.CanTarget(elsewhere[0], actor, target).error
			if why.is_empty():
				why = "%s is not a valid target for this team." % target.Name
		var refuse := AcceptDialog.new()
		refuse.title = "No Mission Available"
		refuse.dialog_text = why
		refuse.exclusive = true
		add_child(refuse)
		refuse.popup_centered()
		refuse.confirmed.connect(refuse.queue_free)
		refuse.canceled.connect(refuse.queue_free)
		return

	# The original's own window when the player imported its art (Figs 2.34,
	# 3.47, 3.48); the plain dialog below otherwise.
	if _uiManager != null and _uiManager.OpenCreateMission(team, origin, target, victim, thing, legal,
			_Launcher(_uiManager, team, origin, target, victim, thing)):
		return

	# Fixed content width, so an autowrapping label has something to wrap against.
	const ContentWidth := 376

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(ContentWidth, 0)
	# "the target" (Fig 2.34); when the target is a PERSON, name the person.
	var objectName: String = ""
	if victim != null:
		objectName = victim.Name
	elif thing is Facility:
		objectName = (thing as Facility).Name()   # Facility.Name is a METHOD, not a field
	elif thing is Unit:
		objectName = thing.Name
	var targetLabel := Label.new()
	targetLabel.text = ("Target:  %s  (at %s)" % [objectName, target.Name]) if not objectName.is_empty() \
		else ("Target:  %s" % target.Name)
	box.add_child(targetLabel)
	var teamLabel := Label.new()
	teamLabel.text = "Team:  %s" % ", ".join(Lq.select(team, func(c: Unit) -> String: return c.Name))
	teamLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teamLabel.custom_minimum_size = Vector2(ContentWidth, 0)
	box.add_child(teamLabel)
	box.add_child(HSeparator.new())
	var missionLabel := Label.new()
	missionLabel.text = "Mission:"
	box.add_child(missionLabel)

	# "The currently selected mission" (Fig 2.34): its picture for our side,
	# when the player imported the original's; a plain plate otherwise.
	var missionPic := ColorRect.new()
	missionPic.color = Color(0.08, 0.1, 0.14, 1)
	missionPic.custom_minimum_size = Vector2(ContentWidth, ContentWidth / 2.0)
	box.add_child(missionPic)

	var picker := OptionButton.new()
	for i in legal.size():
		picker.add_item(MissionCatalog.DisplayNameFor(legal[i]), i)
	picker.selected = 0
	box.add_child(picker)
	var showMission := func(index: int) -> void:
		var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(legal[index])
		Art.Fill(missionPic, Art.MissionPicture(d.Id, actor.Id) if d != null else null)
	picker.item_selected.connect(showMission)
	showMission.call(0)

	# The Decoy tab (manual p102, fig 3.48).
	var decoyBoxes: Array[CheckBox] = []
	if team.size() > 1:
		box.add_child(HSeparator.new())
		var decoyLabel := Label.new()
		decoyLabel.text = "Decoys (drawn attention, excluded from the roll):"
		decoyLabel.add_theme_font_size_override("font_size", 11)
		box.add_child(decoyLabel)

		# Scrolled and height-capped: fixed height, NOT ExpandFill.
		var scroller := ScrollContainer.new()
		scroller.custom_minimum_size = Vector2(0, mini(team.size() * 26, 120))
		var decoyList := VBoxContainer.new()
		decoyList.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.add_child(decoyList)

		for c in team:
			var cb := CheckBox.new()
			cb.text = c.Name
			cb.add_theme_font_size_override("font_size", 11)
			decoyBoxes.append(cb)
			decoyList.add_child(cb)
		box.add_child(scroller)

	# Transit is real, and orders cannot be given in hyperspace (p109).
	var days: int = origin.DeploymentDaysTo(target)
	var eta := Label.new()
	eta.text = ("Transit: %d days each way" % days) if days > 0 else "Already on station"
	eta.add_theme_font_size_override("font_size", 11)
	eta.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	box.add_child(eta)

	var dialog := ConfirmationDialog.new()
	dialog.title = "Create Mission"
	dialog.exclusive = true
	# "Bring up Encyclopedia entry for this mission" (Fig 2.34's i button).
	var encyBtn: Button = dialog.add_button("Encyclopedia", false, "encyclopedia")
	encyBtn.tooltip_text = "Bring up the Encyclopedia entry for this mission."
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"encyclopedia":
			var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(legal[picker.selected])
			if d != null:
				_uiManager.OpenEncyclopedia("missions", d.Id))

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(box)
	dialog.add_child(pad)

	var contentHeight: int = 210 + int(ContentWidth / 2.0) + 8 + ((mini(team.size() * 26, 120) + 44) if team.size() > 1 else 0)

	dialog.confirmed.connect(func() -> void:
		var decoys: Array = []
		for i in decoyBoxes.size():
			if decoyBoxes[i].button_pressed:
				decoys.append(team[i])
		LaunchMission(self, legal[picker.selected], team, origin, target, victim, thing, decoys)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)

	# Hard ceiling as well as a requested size, so the button row stays on screen.
	dialog.max_size = Vector2i(ContentWidth + 24, contentHeight)

	add_child(dialog)
	dialog.popup_centered(Vector2i(ContentWidth + 24, contentHeight))


## Send the team the Create Mission window assembled; the engine's refusal,
## if any, goes up on `host`.
static func LaunchMission(host: Node, type: int, team: Array, origin: Planet, target: Planet,
		victim: Character, thing: Variant, decoys: Array) -> void:
	# Everyone cannot be a decoy - somebody has to do the job.
	if decoys.size() == team.size():
		decoys = []
	var args := { "type": type, "team": EntityIndex.ids_of_units(team), "origin": origin.Name,
		"target": target.Name, "decoys": EntityIndex.ids_of_units(decoys), "victim": victim.Name if victim != null else "" }
	if thing is Facility:
		args["facility"] = thing.Serial
	elif thing is Unit:
		args["unit"] = thing.Serial
	var r: Result = CommandBus.issue("launch_mission", args)
	if not r.ok and host != null and is_instance_valid(host):
		RefusalOn(host, "Mission Refused", r.error)


## LaunchMission for one team and target, waiting for the mission and the
## decoys. Made in a static function, so it holds no window that may close.
static func _Launcher(host: Node, team: Array, origin: Planet, target: Planet, victim: Character, thing: Variant) -> Callable:
	return func(type: int, decoys: Array) -> void:
		LaunchMission(host, type, team, origin, target, victim, thing, decoys)


## An order the engine turned down, in front of the player rather than on
## the console (TeeJ, 2026-09-22).
func ShowRefusal(title: String, text: String) -> void:
	RefusalOn(self, title, text)


static func RefusalOn(host: Node, title: String, text: String) -> void:
	var box := AcceptDialog.new()
	box.title = title
	box.dialog_text = text
	box.exclusive = true
	host.add_child(box)
	box.popup_centered()
	box.confirmed.connect(box.queue_free)
	box.canceled.connect(box.queue_free)


func CreateEmptyLabel(list: Container, text: String, color: Color) -> void:
	if IsCardList(list):
		return   # the original's grids say nothing when there is nothing
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	list.add_child(lbl)


## Wires up button, toggle, and popup logic. C#: SetupMenuButton<T> where
## T : ITransitEntity; on_menu_action is Action<int, List<T>>.
func SetupMenuButton(btn: Button, entityData: Variant, selectionList: Array, popup: PopupMenu, onMenuAction: Callable) -> void:
	# 1. Sync Toggle State
	btn.toggle_mode = true
	if selectionList.has(entityData):
		btn.button_pressed = true

	btn.toggled.connect(func(isPressed: bool) -> void:
		# CROSSHAIRS UP: the click is picking a TARGET, not making a selection
		# (p040). The mission decides whether it will accept what was clicked.
		if _uiManager.IsTargetingObject():
			btn.set_pressed_no_signal(selectionList.has(entityData))
			_uiManager.ResolveObjectTarget(entityData)
			return
		if isPressed and not selectionList.has(entityData):
			selectionList.append(entityData)
		elif not isPressed:
			selectionList.erase(entityData))

	# 2. Attach Popup
	RegisterPopupMenu(popup)
	btn.add_child(popup)

	# 3. Handle Right Click
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if _uiManager.IsTargeting:
				_uiManager.CancelTargeting()
			else:
				popup.position = Vector2i(int(event.global_position.x), int(event.global_position.y))
				popup.popup()
			btn.accept_event())

	# 4. Handle Menu Action
	var fire := func(id: int) -> void:
		var targets: Array = selectionList.duplicate() if selectionList.has(entityData) else [entityData]
		btn.release_focus()
		onMenuAction.call_deferred(id, targets)

	popup.id_pressed.connect(fire)

	# SUBMENUS EMIT THEIR OWN SIGNAL. A PopupMenu attached with
	# add_submenu_node_item does NOT route its selections through the parent's
	# id_pressed - it fires its own.
	for child in popup.get_children():
		if child is PopupMenu:
			child.id_pressed.connect(fire)


func AddCharacterToList(list: Container, characterData: Character, text: String, color: Color, uiManager: UIManager) -> void:
	if characterData == null:
		CreateEmptyLabel(list, text, color)
		return

	# 1. Create the specific Button
	var characterBtn := CharacterMenuButton.new()
	characterBtn.text = text
	characterBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# "right-click the character's portrait" (manual p100): the original's
	# list miniature beside the name, when the player imported it.
	var mini: Texture2D = Art.Miniature("characters", characterData.PackId)
	if mini != null:
		characterBtn.icon = mini
		characterBtn.set_meta("miniature", true)
	# THE ORIGINAL'S CARD (Fig 3.73): the miniature over the name alone - the
	# rank, status and job go to the tooltip.
	if IsCardList(list):
		# White, as the original's names are - unless a status colours it.
		var cardColor: Color = Color.WHITE if characterData.Faction != null and color == characterData.Faction.FactionColor else color
		OUI.Card(characterBtn, characterData.Name, OUI.Mini("characters", characterData.PackId), cardColor,
			OUI.SideColor(GameSettings.PlayerFaction), "enroute" if characterData.Status == Enums.Status.Enroute else "")
		characterBtn.tooltip_text = text
	characterBtn.CharacterData = characterData
	characterBtn.UIManagerRef = uiManager
	characterBtn.ParentWindow = self
	characterBtn.add_theme_color_override("font_color", color)
	characterBtn.add_theme_font_size_override("font_size", 16)

	# 2. Create the specific Menu. You may only give ORDERS to your own people
	# (manual p100); a prisoner and an injured character take none (p096).
	var isOurs: bool = characterData.Faction == GameSettings.PlayerFaction
	var fit: bool = characterData.CanTakeOrders()

	var popup := PopupMenu.new()

	if isOurs:
		popup.add_item("Move", 0)
		popup.set_item_disabled(popup.get_item_index(0), not fit)
		popup.add_item("Confirmed Move", 1)
		popup.set_item_disabled(popup.get_item_index(1), not fit)
		popup.add_item("Mission", 2)
		popup.set_item_disabled(popup.get_item_index(2), not fit)

		# THE COMMAND SUBMENU (manual p055): the ranks a character cannot hold
		# are greyed, not hidden. Labels are the game's own (TEXTSTRA.DLL).
		var postable: bool = characterData.Status != Enums.Status.Enroute and not characterData.IsCaptured()

		var commandSubmenu := PopupMenu.new()
		commandSubmenu.name = "CommandSubmenu"

		# Admiral is greyed here, always: this window lists the people ON A
		# SYSTEM, and "all ships in a fleet" is the only thing an admiral
		# commands (manual p095).
		commandSubmenu.add_item("Admiral", 100)
		commandSubmenu.set_item_disabled(commandSubmenu.get_item_index(100), true)
		commandSubmenu.add_item("General", 101)
		commandSubmenu.set_item_disabled(commandSubmenu.get_item_index(101), not postable or not characterData.CanBeGeneral)
		commandSubmenu.add_item("Commander", 102)
		commandSubmenu.set_item_disabled(commandSubmenu.get_item_index(102), not postable or not characterData.CanBeCommander)

		# "None" is the game's own string, and it is how a post is given up.
		commandSubmenu.add_separator()
		commandSubmenu.add_item("None", 103)
		commandSubmenu.set_item_disabled(commandSubmenu.get_item_index(103), characterData.Rank == Enums.Rank.None)

		popup.add_child(commandSubmenu)
		popup.add_submenu_node_item("Command", commandSubmenu, 3)

		# A character with no possible rank at all has nothing to pick.
		popup.set_item_disabled(popup.get_item_index(3),
			not characterData.CanHoldAnyRank() and characterData.Rank == Enums.Rank.None)

	popup.add_item("Encyclopedia", 4)
	popup.add_item("Status", 5)

	# LIVE. Only the unreachable are excluded: someone in hyperspace takes no
	# orders (p111), and a prisoner is not yours to dismiss.
	if isOurs:
		popup.add_item("Retire", 6)
		popup.set_item_disabled(popup.get_item_index(6),
			characterData.Status == Enums.Status.Enroute or characterData.IsCaptured())

	# 3. Let the Generic Helper wire it all together!
	SetupMenuButton(characterBtn, characterData, SelectedCharacters, popup,
		func(id: int, targets: Array) -> void: OnCharacterMenuAction(id, targets, uiManager))

	list.add_child(characterBtn)


## EVERY selected entity has to be free, not just one of them (p102, p109).
func TransitEligible(entities: Array) -> bool:
	var busy: Array = Lq.where(entities, func(e) -> bool: return e.Status == Enums.Status.Enroute)
	if not busy.is_empty():
		print("[Orders] %d of the selected are in hyperspace and cannot be given orders." % busy.size())
		return false

	# On a mission counts as committed too - the team is out doing something.
	var onMission: Array = Lq.where(entities, func(e) -> bool: return e is Unit and MissionManager.IsOnMissionTeam(e))
	if not onMission.is_empty():
		print("[Orders] %s are already on a mission." % ", ".join(Lq.select(onMission, func(u: Unit) -> String: return u.Name)))
		return false

	return not entities.is_empty()


func OnCharacterMenuAction(actionId: int, characters: Array, uiManager: UIManager) -> void:
	if characters == null or characters.is_empty():
		return

	match actionId:
		0, 1:   # Move, Confirmed Move
			if TransitEligible(characters):
				var currentPlanet: Planet = OrderManager.SystemOf(characters[0].Attached)
				if currentPlanet == null:
					return
				# A SYSTEM OR A FLEET. "Characters can also be moved by dragging
				# the icon onto a system or fleet" (manual p110).
				_uiManager.StartTargetingObject(
					func(selectedPlanet: Planet) -> void:
						_uiManager.ExecuteCharacterMove(characters, selectedPlanet, actionId == 1),
					func(picked: Variant) -> void:
						var fleet: Fleet = OrderManager.FleetOf(picked)
						if fleet == null:
							print("[Move] That is not a place a character can go.")
							return
						var r: Result = CommandBus.issue("board_fleet", { "characters": EntityIndex.names_of(characters), "fleet": fleet.Name })
						if not r.ok:
							print("[Move] %s" % r.error))

		2:
			# "Right-click on a character or team and select Mission. The cursor
			# changes to a cross hair, then select a target." (manual p102)
			if not TransitEligible(characters):
				print("Some of those characters cannot act - in transit or captured.")
				return
			StartMissionTargeting(characters, uiManager)

		4:   # Encyclopedia (manual p101: the character's entry)
			if not characters.is_empty():
				uiManager.OpenEncyclopedia("characters", characters[0].PackId)

		5:
			for c in characters:
				uiManager.OpenCharacterStatusWindow(c)

		# --- COMMAND RANKS (manual p056) -----------------------------------
		100, 101, 102, 103:
			var rank: int
			match actionId:
				100: rank = Enums.Rank.Admiral
				101: rank = Enums.Rank.General
				102: rank = Enums.Rank.Commander
				_:   rank = Enums.Rank.None

			for c in characters:
				var r: Result = CommandBus.issue("take_command", { "character": c.Name, "rank": rank })
				if r.ok:
					print(("[Command] %s has been relieved of command." % c.Name) if rank == Enums.Rank.None
						else ("[Command] %s %s now commands %s." % [JsonUtil.enum_name(Enums.Rank, rank), c.Name, c.Commanding.Name if c.Commanding != null else ""]))
				else:
					print("[Command] %s" % r.error)

			EventBus.BroadcastChanged()
			# Refresh(), not Populate() - each window overrides Refresh to
			# repaint itself from its own subject.
			Refresh()

		6:   # Retire
			# RETIRING A CHARACTER IS AT WILL, exactly as for a unit. A character
			# costs no materials to raise, so nothing comes back.
			var leaving: Array = characters.duplicate()
			var who: String = leaving[0].Name if leaving.size() == 1 else "%d characters" % leaving.size()

			ConfirmRetire(who, 0, func() -> void:
				CommandBus.issue("retire", { "characters": EntityIndex.names_of(leaving) })
				for c in leaving:
					SelectedCharacters.erase(c)
				Refresh())

		_:
			print("Unhandled menu action %d" % actionId)


## SCRAP ASKS FIRST, in the original's own dialog when the art is imported:
## "Are you sure you want to scrap the following units?" (TEXTSTRA.DLL 28752)
## and each unit on its own line (28756), over the console picture, with the
## tick and the cross (TeeJ's screenshot of the original, 2026-09-23). What
## scrapping gives back is not in the original's dialog; it is on the tick.
## `plain` is the caller's own dialog, for a player without the art.
func ConfirmScrapUnits(names: Array, refundNote: String, onConfirm: Callable, plain: Callable) -> void:
	var ui: UIManager = _uiManager if _uiManager != null else get_parent() as UIManager
	if ui == null or not ui.ConfirmScript.CanBuild():
		plain.call()
		return
	var text: String = "Are you sure you want to scrap the following units?"
	for n in names:
		text += "\n" + str(n)
	var f: Faction = GameSettings.PlayerFaction
	var side: String = "alliance" if f != null and f.Id == "alliance" else "empire"
	ui.OpenConfirmation(f, OUI.Pic("scrap_picture." + side), text, refundNote, onConfirm)


## Retiring is irreversible and gives back only half the material, so it asks
## first - the same shape the Economy window uses for scrapping a facility.
func ConfirmRetire(what: String, refund: int, onConfirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Retire"
	dialog.dialog_text = "Are you sure you want to retire the following?\n\n" \
		+ "    %s\n\n" % what \
		+ "Returns %d %s and the maintenance\n" % [refund, Terms.lower("refined_materials")] \
		+ "capacity they were drawing."
	dialog.exclusive = true

	dialog.confirmed.connect(func() -> void:
		onConfirm.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)

	add_child(dialog)
	dialog.popup_centered()


# ---- THE ORIGINAL'S WINDOWS (src/ui/original_ui.gd builds them) ----------

## The original's window builder; preloaded by path, on the base class only.
const OUI := preload("res://src/ui/original_ui.gd")


## The system's own sprite in the title bar, left of the name (the System
## window, which has no original plate to match).
func SetTitleIcon(planet: Planet) -> void:
	var label: Label = get_node_or_null("%TitleBarLabel")
	if label == null or planet == null:
		return
	var hbox: Node = label.get_parent()
	var icon: TextureRect = hbox.get_node_or_null("TitleIcon")
	var tex: Texture2D = Art.PlanetSprite(planet.ArtworkId)
	if tex == null:
		if icon != null:
			icon.queue_free()
		return
	if icon == null:
		icon = TextureRect.new()
		icon.name = "TitleIcon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
		hbox.move_child(icon, 0)
	icon.texture = tex


## A list laid out as the original's grid of cards (OUI.Page) takes cards.
static func IsCardList(list: Node) -> bool:
	return list != null and list.has_meta("cards")


## The tab's name above a plain list (the look without the original's art).
static func AddCaption(list: Container, text: String) -> void:
	var cap := Label.new()
	cap.text = text
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	list.add_child(cap)
