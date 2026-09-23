extends DraggableWindow
## THE CREATE MISSION WINDOW (manual p042 Fig 2.34; p102-p104, Figs 3.47 and
## 3.48), rebuilt from the original's bitmaps at the places measured on
## TeeJ's screenshot of the original (2026-09-23), like the other original
## windows (original_ui.gd). Two tabs:
##   Select Mission - "the currently selected mission" (its name over its
##     picture), the arrow that "brings down the drop-down list of available
##     missions", and the target (its picture and name);
##   Decoy - the team in two columns, agents and decoys, with the arrows that
##     move the selected between them ("Decoys must be selected before you
##     click on the checkbox", p103).
## Under both: the mission's Encyclopedia entry, assign (the check) and cancel
## (the X). Modal, like the dialog it replaces. UIManager.OpenCreateMission
## opens it only when the player imported the art; the plain dialog in
## DraggableWindow.OpenCreateMission stays otherwise.
##
## Preloaded by path: a new script can lag the editor's class cache.

## OUI (original_ui.gd) comes from DraggableWindow.
const K := OUI.K

## The plate is the window, 259 x 355; every position is in its pixels.
const PlateW := 259
const PlateH := 355
const TabXs := [7, 137]
const TabY := 20
## The mission's name (Arial 13) is centred on the picture's middle.
const NameCentreX := 135
const NameY := 63
const PictureAt := Vector2(70, 86)
const ListOpenAt := Vector2(101, 175)
const TargetWordAt := Vector2(36, 196)
## The Target box (inside its inner brackets); its picture is centred in it,
## the target's name (Arial bold 13) on the window's middle.
const TargetBox := Rect2(50, 210, 167, 81)
const TargetNameY := 295
const ButtonXs := [33, 102, 170]
const ButtonY := 320
## The Decoy tab: two dotted columns, 108 pixels wide inside, the head
## (108x27) at y 65 and the list under it, y 93 to 306.
const ColumnXs := [8, 136]
const HeadY := 65
const ListY := 93
const ListH := 214
## PROVISIONAL until there is a screenshot of the original's Decoy tab and of
## its open mission list: the arrows' places (read off the manual's Fig
## 3.48), a column's rows, and where the list drops down.
const ToDecoysAt := Vector2(118, 130)
const ToAgentsAt := Vector2(118, 219)
const RowH := 44
const ListAt := Vector2(29, 192)
const ListRowH := 15

var _team: Array = []
var _origin: Planet
var _target: Planet
var _victim: Character
var _thing: Variant
var _legal: Array = []
var _launch: Callable
var _faction: Faction
var _side: String = ""
var _choice: int = 0
## The team members on the Decoy column, and the members picked in either.
var _decoys: Array = []
var _picked: Array = []

var _canvas: Control
var _pages: Array = []
var _tabs: Array = []
var _name: Label
var _picture: TextureRect
var _list: Control
var _listRows: Array = []
var _columns: Array = []
var _blocker: Control


## True when the player imported the art this window is made of.
static func CanBuild() -> bool:
	return OUI.Has(["mission_plate", "mission_decoy_plate", "mission_list"]) \
		and Art.ButtonIcon("mission_ok") != null and Art.TabIcon("mission_select", "empire") != null


func Setup(ui: UIManager, team: Array, origin: Planet, target: Planet, victim: Character, thing: Variant,
		legal: Array, launch: Callable) -> void:
	_uiManager = ui
	_team = team.duplicate()
	_origin = origin
	_target = target
	_victim = victim
	_thing = thing
	_legal = legal.duplicate()
	_launch = launch
	_choice = 0
	_decoys.clear()
	_picked.clear()
	_faction = team[0].Faction
	_side = OUI.Side(_faction)
	_build()
	_block_the_rest()
	_show_page(0)
	_show_mission(0)


func _build() -> void:
	OUI.DialogFrame(self, _faction, OUI.Pic("mission_plate"))
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
	_pages = [_page_control("SelectMission"), _page_control("Decoy")]
	_build_select(_pages[0])
	_build_decoy(_pages[1])
	_tabs.clear()
	for i in 2:
		var stem: String = ["mission_select", "mission_decoy"][i]
		var b := TextureButton.new()
		b.name = ["TabSelect", "TabDecoy"][i]
		b.set_meta("normal", OUI.Tab(stem, _side))
		b.set_meta("current", OUI.Tab(stem, _side, "pressed"))
		b.texture_normal = b.get_meta("normal")
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(TabXs[i], TabY) * K
		b.size = (b.texture_normal as Texture2D).get_size()
		b.tooltip_text = ["Select Mission", "Decoy"][i]
		var index := i
		b.pressed.connect(func() -> void: _show_page(index))
		_canvas.add_child(b)
		_tabs.append(b)
	OUI.PictureButton(_canvas, "mission_encyclopedia", ButtonXs[0], ButtonY,
		"Bring up the Encyclopedia entry for this mission").pressed.connect(_on_encyclopedia)
	OUI.PictureButton(_canvas, "mission_ok", ButtonXs[1], ButtonY, "Assign mission").pressed.connect(_on_assign)
	OUI.PictureButton(_canvas, "mission_cancel", ButtonXs[2], ButtonY, "Cancel mission assignment").pressed.connect(CloseWindow)
	_build_list()


func _page_control(page_name: String) -> Control:
	var p := Control.new()
	p.name = page_name
	p.size = Vector2(PlateW, PlateH) * K
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(p)
	return p


# ---- Select Mission ----------------------------------------------------------

func _build_select(page: Control) -> void:
	_name = OUI.Text(page, "", NameCentreX - 100, NameY, 200, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "MissionName")
	_picture = OUI.Place(page, null, PictureAt.x, PictureAt.y, "MissionPicture")
	OUI.PictureButton(page, "mission_list_open", ListOpenAt.x, ListOpenAt.y,
		"Bring up the Mission Type list").pressed.connect(func() -> void: _list.visible = not _list.visible)
	OUI.Text(page, "Target", TargetWordAt.x, TargetWordAt.y, 80, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true, "TargetWord")
	var tex: Texture2D = _target_picture()
	var pic := OUI.Place(page, tex, 0, 0, "TargetPicture")
	if tex != null:
		pic.position = (TargetBox.get_center() * K - tex.get_size() / 2.0).floor()
	OUI.Text(page, _target_name(), 0, TargetNameY, PlateW, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, "TargetName")
	# Transit is real, and orders cannot be given in hyperspace (p109). The
	# original's window does not print how far it is; the target says it on hover.
	var box := Control.new()
	box.name = "TargetBox"
	box.position = TargetBox.position * K
	box.size = TargetBox.size * K
	var days: int = _origin.DeploymentDaysTo(_target)
	box.tooltip_text = ("Transit: %d days each way" % days) if days > 0 else "Already on station"
	page.add_child(box)


## What the mission is aimed at: the system's sprite, or - for an object
## target - that person's, facility's or unit's miniature (PROVISIONAL: no
## screenshot of an object target yet).
func _target_picture() -> Texture2D:
	if _victim != null:
		return OUI.Mini("characters", _victim.PackId)
	if _thing is Facility:
		var fac: Facility = _thing
		return OUI.Mini("facilities", fac.Def.Id if fac.Def != null else fac.Family())
	if _thing is Unit:
		return OUI.Mini("units", (_thing as Unit).PackId)
	return Art.Scaled(Art.PlanetSprite(_target.ArtworkId), K)


func _target_name() -> String:
	if _victim != null:
		return _victim.Name
	if _thing is Facility:
		return (_thing as Facility).Name()   # Facility.Name is a METHOD
	if _thing is Unit:
		return (_thing as Unit).Name
	return _target.Name


## The list the arrow drops down: the missions this team may run here.
func _build_list() -> void:
	_list = Control.new()
	_list.name = "MissionList"
	_list.position = ListAt * K
	var bg: Texture2D = OUI.Pic("mission_list")
	_list.size = bg.get_size() if bg != null else Vector2(200, 113) * K
	_list.clip_contents = true
	_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_list.visible = false
	_pages[0].add_child(_list)
	if bg != null:
		OUI.Place(_list, bg, 0, 0, "Starfield")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(4, 3) * K
	scroll.size = _list.size - Vector2(8, 6) * K
	_list.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	_listRows.clear()
	var empty := StyleBoxEmpty.new()
	for i in _legal.size():
		var row := Button.new()
		row.name = "Row%d" % i
		row.text = MissionCatalog.DisplayNameFor(_legal[i])
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, ListRowH) * K
		row.add_theme_font_override("font", OUI.Face())
		row.add_theme_font_size_override("font_size", 13 * K)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			row.add_theme_stylebox_override(st, empty)
		var index := i
		row.pressed.connect(func() -> void:
			_show_mission(index)
			_list.visible = false)
		rows.add_child(row)
		_listRows.append(row)


func _show_mission(index: int) -> void:
	if _legal.is_empty():
		return
	_choice = clampi(index, 0, _legal.size() - 1)
	_name.text = MissionCatalog.DisplayNameFor(_legal[_choice])
	var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(_legal[_choice])
	var tex: Texture2D = Art.Scaled(Art.MissionCard(d.Id, _side), K) if d != null else null
	_picture.texture = tex
	_picture.size = tex.get_size() if tex != null else Vector2.ZERO
	# The list shows the chosen one in the side's colour, as a selected name.
	for i in _listRows.size():
		var c: Color = OUI.SideColor(_faction) if i == _choice else Color.WHITE
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			(_listRows[i] as Button).add_theme_color_override(key, c)


# ---- Decoy -------------------------------------------------------------------

func _build_decoy(page: Control) -> void:
	OUI.Place(page, OUI.Pic("mission_agents.%s" % _side), ColumnXs[0], HeadY, "AgentsHead")
	OUI.Place(page, OUI.Pic("mission_decoys.%s" % _side), ColumnXs[1], HeadY, "DecoysHead")
	_columns.clear()
	for i in 2:
		var scroll := ScrollContainer.new()
		scroll.name = ["AgentsScroll", "DecoysScroll"][i]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.position = Vector2(ColumnXs[i], ListY) * K
		scroll.size = Vector2(108, ListH) * K
		page.add_child(scroll)
		var column := VBoxContainer.new()
		column.name = ["Agents", "Decoys"][i]
		column.add_theme_constant_override("separation", 0)
		scroll.add_child(column)
		_columns.append(column)
	OUI.PictureButton(page, "mission_to_decoys", ToDecoysAt.x, ToDecoysAt.y,
		"Move the selected agents to the Decoy column").pressed.connect(func() -> void: _move(true))
	OUI.PictureButton(page, "mission_to_agents", ToAgentsAt.x, ToAgentsAt.y,
		"Move the selected decoys to the Agent column").pressed.connect(func() -> void: _move(false))


func _fill_columns() -> void:
	for column in _columns:
		for c in column.get_children():
			column.remove_child(c)
			c.queue_free()
	for m in _team:
		(_columns[1 if _decoys.has(m) else 0] as Control).add_child(_member_card(m))


## One of the team in a column: the miniature on its plate, the name under
## it; picked, a frame all the way round the picture and the name in the
## side's colour, as in the Defenses grid.
func _member_card(m: Unit) -> Control:
	var b := Button.new()
	b.name = "Member_%s" % m.Name.validate_node_name()
	b.toggle_mode = true
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = m.Name
	b.custom_minimum_size = Vector2(108, RowH) * K
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var x: int = (108 - 61) / 2
	var plate: Texture2D = OUI.Pic("card_plate")
	if plate != null:
		OUI.Place(b, plate, x, 4, "Plate")
	var mini: Texture2D = OUI.Mini("characters" if m is Character else "units", m.PackId)
	if mini != null:
		OUI.Place(b, mini, x, 4, "Picture")
	var frame := ReferenceRect.new()
	frame.name = "Frame"
	frame.editor_only = false
	frame.border_color = OUI.SideColor(_faction)
	frame.border_width = K
	frame.position = Vector2(x - 1, 3) * K
	frame.size = Vector2(63, 27) * K
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(frame)
	var name_label := OUI.Text(b, m.Name, 0, 31, 108, 13, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Name")
	name_label.clip_text = true
	var show := func(on: bool) -> void:
		frame.visible = on
		name_label.add_theme_color_override("font_color", OUI.SideColor(_faction) if on else Color.WHITE)
	b.button_pressed = _picked.has(m)
	show.call(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		if on and not _picked.has(m):
			_picked.append(m)
		elif not on:
			_picked.erase(m)
		show.call(on))
	return b


## The arrows: the picked agents to the decoys, or the picked decoys back.
func _move(to_decoys: bool) -> void:
	var moved: Array = []
	for m in _picked:
		var decoy: bool = _decoys.has(m)
		if to_decoys and not decoy:
			_decoys.append(m)
			moved.append(m)
		elif not to_decoys and decoy:
			_decoys.erase(m)
			moved.append(m)
	for m in moved:
		_picked.erase(m)
	_fill_columns()


# ---- the tabs, the buttons ---------------------------------------------------

func _show_page(index: int) -> void:
	for i in _pages.size():
		(_pages[i] as Control).visible = i == index
	for i in _tabs.size():
		(_tabs[i] as TextureButton).texture_normal = _tabs[i].get_meta("current" if i == index else "normal")
	OUI.SetPlate(self, OUI.Pic("mission_plate" if index == 0 else "mission_decoy_plate"))
	if _list != null:
		_list.visible = false
	if index == 1:
		_fill_columns()


func _on_encyclopedia() -> void:
	var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(_legal[_choice])
	if d != null and _uiManager != null:
		_uiManager.OpenEncyclopedia("missions", d.Id)


func _on_assign() -> void:
	var type: int = _legal[_choice]
	var decoys: Array = _decoys.duplicate()
	var launch: Callable = _launch
	CloseWindow()
	if launch.is_valid():
		launch.call(type, decoys)


## Modal, like the dialog it replaces: nothing under it takes a click while it
## is up. The Encyclopedia it opens comes up over it.
func _block_the_rest() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	_blocker = Control.new()
	_blocker.name = "CreateMissionBlocker"
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_blocker)
	parent.move_child(_blocker, get_index())
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_blocker):
			_blocker.queue_free())
