extends DraggableWindow
## THE MISSION WINDOW (manual p109, Figs 3.50 and 3.51), rebuilt from the
## original's bitmaps at the places measured on TeeJ's four screenshots of the
## original's (Mon Calamari, Umgul on both tabs, Coruscant; 2026-09-23), like
## the other original windows (original_ui.gd):
##   the column - "there may be more than one mission on a given system ...
##     you'll be able to see other Mission icons in this column. Click on this
##     icon to bring up the mission-specific information on the right side";
##     each icon is the mission's picture with its name over it, the picked
##     one in the side's frame. Right-click one for "Encyclopedia", "Status"
##     and the order to abort, greyed while the team is in hyperspace (Fig
##     3.50: "you cannot give orders to units in hyperspace");
##   the right side - "Target:", the target's picture and name, and two tabs:
##     "check on status of agent performing mission" and "check on status of
##     decoys, if any"; each member's miniature and name, the "starfield
##     background [indicating the] character is in hyperspace".
## Only the player's own missions are listed (MissionWindow says why).
## UIManager.OnMissionClicked opens it only when the player imported the art;
## the plain MissionWindow stays otherwise.
##
## Preloaded by path: a new script can lag the editor's class cache.

const K := OUI.K

## The plate is the window, 235 x 304; every position is in its pixels.
const PlateW := 235
const PlateH := 304
## The title: Arial bold 13, 4 pixels after the system box.
const TitlePx := 13
const TitleGap := 4
## The column: the first mission's picture (73x48) at (5, 24).
const ColumnAt := Vector2(5, 24)
## A mission every 50 pixels down the column, only the picked one framed
## (measured on TeeJ's screenshot of two on Coruscant, 2026-09-24).
const TilePitch := 50
const TileW := 73
const TileH := 48
## The mission's name over its picture: Arial 11, white, from its corner.
const TileNameAt := Vector2(1, 0)
const TilePx := 11
## The right side: "Target:" and the target's name (Arial bold 12.5 - the
## original's hinted 14 is that narrow), white, centred on x 167; the
## target's picture centred on (169, 62), rounding up and left.
const TextCentreX := 167
const TargetWordY := 26
const TargetNameY := 92
const TargetCentre := Vector2(169, 62)
const TextPx := 12.5
## The tabs (61x16): agents at (105, 127), decoys at (166, 127).
const TabXs := [105, 166]
const TabY := 127
## The team panel under the tabs; a member's miniature (61x25) at x 137 (11
## below the panel's top, the first at y 154), the name (Arial 10.5) centred
## on x 165 under it - the words' middle, not the picture's (measured).
const PanelRect := Rect2(104, 143, 125, 155)
const MemberX := 137
const MemberNameCentreX := 165
const MemberTop := 11
const MemberNameY := 26
## A member every 43 pixels (measured on TeeJ's screenshot of two agents at
## Bpfassh, 2026-09-24).
const MemberPitch := 43
const MemberPx := 10.5

var _planet: Planet
var _faction: Faction
var _side: String = ""
var _missions: Array = []
## The mission on show (by serial, so a refresh keeps it) and its tab.
var _pickedSerial: int = -1
var _page: int = 0

var _canvas: Control
var _column: Control
var _targetPicture: TextureRect
var _targetName: Label
var _tabs: Array = []
var _panel: VBoxContainer


## True when the player imported the art this window is made of.
static func CanBuild() -> bool:
	return OUI.Has(["mission_window", "mission_frame.empire", "mission_frame.alliance"]) \
		and Art.TabIcon("mission_agents_tab", "empire") != null and Art.ButtonIcon("title_system") != null


func Populate(planet: Planet) -> void:
	var fresh: bool = _planet != planet
	_planet = planet
	if _canvas == null:
		_faction = GameSettings.PlayerFaction
		_side = OUI.Side(_faction)
		_build()
	# The original's words (TEXTSTRA): "Mission at ".
	(get_node("%TitleBarLabel") as Label).text = "Mission at %s" % planet.Name
	_missions = Lq.where(MissionManager.Active(), func(m: Mission) -> bool:
		return m.Target == planet and m.Faction == GameSettings.PlayerFaction and not m.Finished)
	if fresh or not Lq.any(_missions, func(m: Mission) -> bool: return m.Serial == _pickedSerial):
		_pickedSerial = (_missions[0] as Mission).Serial if not _missions.is_empty() else -1
		_page = 0
	_fill_column()
	_show_picked()


func _build() -> void:
	OUI.DialogFrame(self, _faction, OUI.Pic("mission_window"), TitlePx, TitleGap, false, true)
	var area: MarginContainer = OUI.Flatten(self)
	for c in area.get_children():
		area.remove_child(c)
		c.queue_free()
	var body := Control.new()
	body.name = "OriginalBody"
	body.custom_minimum_size = Vector2(PlateW - 2 * OUI.DialogBevel, PlateH - 2 * OUI.DialogBevel - OUI.DialogBarH) * K
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(body)
	# Everything below is placed in the plate's own pixels: the canvas starts
	# at the window's corner, under the bevel and the title bar.
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.position = -Vector2(OUI.DialogBevel, OUI.DialogBevel + OUI.DialogBarH) * K
	_canvas.size = Vector2(PlateW, PlateH) * K
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_canvas)

	_column = Control.new()
	_column.name = "Column"
	_column.position = ColumnAt * K
	_column.size = Vector2(TileW, PlateH - ColumnAt.y - 4) * K
	_column.clip_contents = true
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_column)

	# The original's words (TEXTSTRA): "Target:".
	OUI.Text(_canvas, "Target:", TextCentreX - 60, TargetWordY, 120, 18, TextPx, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, "TargetWord")
	_targetPicture = OUI.Place(_canvas, null, 0, 0, "TargetPicture")
	_targetName = OUI.Text(_canvas, "", TextCentreX - 62, TargetNameY, 124, 18, TextPx, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, "TargetName")
	_targetName.clip_text = true

	_tabs.clear()
	for i in 2:
		var stem: String = ["mission_agents_tab", "mission_decoys_tab"][i]
		var b := TextureButton.new()
		b.name = ["TabAgents", "TabDecoys"][i]
		b.set_meta("normal", OUI.Tab(stem, _side))
		b.set_meta("current", OUI.Tab(stem, _side, "pressed"))
		b.texture_normal = b.get_meta("normal")
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(TabXs[i], TabY) * K
		b.size = (b.texture_normal as Texture2D).get_size() if b.texture_normal != null else Vector2(61, 16) * K
		b.tooltip_text = ["Agents", "Decoys"][i]   # the original's words (TEXTSTRA)
		var index := i
		b.pressed.connect(func() -> void:
			_page = index
			_show_picked())
		_canvas.add_child(b)
		_tabs.append(b)

	var scroll := ScrollContainer.new()
	scroll.name = "PanelScroll"
	scroll.position = PanelRect.position * K
	scroll.size = PanelRect.size * K
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_canvas.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.name = "Members"
	_panel.add_theme_constant_override("separation", 0)
	_panel.custom_minimum_size = Vector2(PanelRect.size.x, 0) * K
	scroll.add_child(_panel)


# ---- the column --------------------------------------------------------------

func _fill_column() -> void:
	for c in _column.get_children():
		_column.remove_child(c)
		c.queue_free()
	for i in _missions.size():
		_column.add_child(_tile(_missions[i], i))


## A mission's icon: its 73x48 picture, its name over it, the side's frame
## when it is the one on show. Click to show it; right-click for its orders.
func _tile(m: Mission, i: int) -> Control:
	var b := Button.new()
	b.name = "Mission%d" % m.Serial
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(0, i * TilePitch) * K
	b.size = Vector2(TileW, TileH) * K
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(m.Type)
	var pic: Texture2D = Art.Scaled(Art.MissionTile(d.Id, _side), K) if d != null else null
	if pic != null:
		OUI.Place(b, pic, 0, 0, "Picture")
	var frame := OUI.Place(b, OUI.Pic("mission_frame.%s" % _side), 0, 0, "Frame")
	frame.visible = m.Serial == _pickedSerial
	OUI.Text(b, m.DisplayName(), TileNameAt.x, TileNameAt.y, TileW - 2, 14, TilePx, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Name")
	# How it is going, on hover: the original's window does not print it.
	b.tooltip_text = MissionWindow.Describe(m)
	b.pressed.connect(func() -> void:
		_pickedSerial = m.Serial
		_page = 0
		_fill_column()
		_show_picked())
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_orders(m, e.global_position)
			b.accept_event())
	return b


## Fig 3.50's menu: Encyclopedia, Status, and the order to abort (greyed
## while the team is in hyperspace). Continuing a persistent mission is the
## default and needs no order (p110).
func _orders(m: Mission, at: Vector2) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Encyclopedia", 0)
	popup.add_item("Status", 1)
	popup.add_item("Abort %s" % m.DisplayName(), 2)
	if not m.Arrived():
		var idx: int = popup.get_item_index(2)
		popup.set_item_disabled(idx, true)
		popup.set_item_tooltip(idx, "%s - %dd out. Orders cannot be given in transit." % [Terms.cap("in_transit"), m.DaysToTarget])
	add_child(popup)
	RegisterPopupMenu(popup)
	popup.position = Vector2i(at)
	popup.popup()
	popup.id_pressed.connect(_on_order.bind(m))
	popup.popup_hide.connect(popup.queue_free)


func _on_order(id: int, m: Mission) -> void:
	match id:
		0:
			var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(m.Type)
			if _uiManager != null:
				if d != null:
					_uiManager.OpenEncyclopedia("missions", d.Id)
				else:
					_uiManager.OpenEncyclopedia()
		1:
			_status(m)
		2:
			CommandBus.issue("abort_mission", { "mission": m.Serial })
			Populate(_planet)


## "Status": how the mission stands - its team, where it is, its attempts
## (and a Diplomacy mission's support). OURS: no screenshot shows the
## original's answer.
func _status(m: Mission) -> void:
	var box := AcceptDialog.new()
	box.title = m.DisplayName()
	box.dialog_text = MissionWindow.Describe(m)
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(box.queue_free)
	box.canceled.connect(box.queue_free)


# ---- the right side -----------------------------------------------------------

func _picked() -> Mission:
	return Lq.first_or_null(_missions, func(m: Mission) -> bool: return m.Serial == _pickedSerial)


func _show_picked() -> void:
	var m: Mission = _picked()
	var tex: Texture2D = _target_picture(m)
	_targetPicture.texture = tex
	if tex != null:
		var w: int = int(tex.get_size().x) / K
		var h: int = int(tex.get_size().y) / K
		_targetPicture.size = tex.get_size()
		_targetPicture.position = Vector2(int(TargetCentre.x) - (w + 1) / 2, int(TargetCentre.y) - (h + 1) / 2) * K
	_targetName.text = _target_name(m)
	for i in _tabs.size():
		(_tabs[i] as TextureButton).texture_normal = _tabs[i].get_meta("current" if i == _page else "normal")
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	if m == null:
		return
	var who: Array = Lq.where(m.Team, func(u: Unit) -> bool: return m.Decoys.has(u) == (_page == 1))
	for u in who:
		_panel.add_child(_member(u, not m.Arrived()))


## What the mission is aimed at, as Create Mission shows it: the system's
## sprite, a facility's or unit's 122x50 picture (the original's Sabotage of
## GenCore Level I, measured). A character target's 61x25 miniature is
## INFERRED: no screenshot shows one, and the 80x80 portrait would cover the
## words above and below it.
func _target_picture(m: Mission) -> Texture2D:
	if m != null:
		if m.TargetCharacter != null:
			return OUI.Mini("characters", m.TargetCharacter.PackId)
		if m.TargetFacility != null:
			var fac: Facility = m.TargetFacility
			return Art.Scaled(Art.Portrait("facilities", fac.Def.Id if fac.Def != null else fac.Family()), K)
		if m.TargetUnit != null:
			return Art.Scaled(Art.Portrait("units", m.TargetUnit.PackId), K)
	if not _planet.IsExplored:
		return null
	return Art.Scaled(Art.PlanetSprite(_planet.ArtworkId), K)


func _target_name(m: Mission) -> String:
	if m != null:
		var named: Variant = m.TargetObjectName()
		if named != null and not str(named).is_empty():
			return str(named)
	# The original's words (TEXTSTRA) for a world you have not seen.
	return _planet.Name if _planet.IsExplored else "Target Unknown"


## A member: the miniature on its plate - hyperspace streaks while the team
## is in transit (Fig 3.51) - and the name under it, centred.
func _member(u: Unit, transit: bool) -> Control:
	var c := Control.new()
	c.name = "Member_%s" % u.Name.validate_node_name()
	c.custom_minimum_size = Vector2(PanelRect.size.x, MemberPitch) * K
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.tooltip_text = u.Name
	var x: float = MemberX - PanelRect.position.x
	var plate: Texture2D = OUI.Pic("card_enroute" if transit else "card_plate")
	if plate != null:
		OUI.Place(c, plate, x, MemberTop, "Plate")
	var mini: Texture2D = OUI.Mini("characters" if u is Character else "units", u.PackId)
	if mini != null:
		OUI.Place(c, mini, x, MemberTop, "Picture")
	var name_label := OUI.Text(c, u.Name, 0, MemberTop + MemberNameY, PanelRect.size.x, 14, MemberPx, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, false, "Name")
	name_label.position.x = (MemberNameCentreX - PanelRect.position.x - PanelRect.size.x / 2.0) * K
	name_label.clip_text = true
	return c


func StateSignature() -> Variant:
	return GameSignature.ForPlanet(_planet) if _planet != null else null


func Refresh() -> void:
	if not CanRefresh():
		return
	if _planet != null:
		Populate(_planet)
