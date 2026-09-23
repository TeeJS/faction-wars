extends DraggableWindow
## THE BUILD SELECTION WINDOW (manual p045; p112 Fig 3.58), rebuilt from the
## original's bitmaps at the places measured on TeeJ's screenshot of the
## original (2026-09-23, an Imperial Construction Yard: every part rebuilt
## pixel for pixel): the 210x261 plate is the window, the title centred on the
## bar inside its bevel with only the close box; the item's picture and name,
## the arrow that drops the list of what can be built here; the refined
## material and maintenance costs in their icon boxes; Best Time To Completion
## and Best Time To Deployment; Number to build with its spinner; the
## Encyclopedia, build (the check) and cancel (the X) buttons. Modal, like the
## dialog it replaces. EconomyWindow.OpenBuildChooser opens it (through
## UIManager.OpenBuildSelection) when the art is imported; the plain dialog
## stays otherwise.
##
## Preloaded by path: a new script can lag the editor's class cache.

const K := OUI.K

## The plate is the window, 210 x 261; every position is in its pixels.
const PlateW := 210
const PlateH := 261
## The item picture's middle and top, its name's line.
const PictureCentreX := 103
const PictureTop := 28
const NameY := 72
const ListOpenAt := Vector2(79, 90)
## The costs are centred in their boxes; the times right-aligned at x 200.
const RefinedCentreX := 68
const MaintCentreX := 170
const CostY := 113
const CompletionY := 145
const DeploymentY := 165
const TimesRight := 200
const Cream := Color(255 / 255.0, 251 / 255.0, 240 / 255.0)
const NumberAt := Vector2(141, 196)
const UpAt := Vector2(189, 196)
const DownAt := Vector2(189, 205)
const ButtonXs := [5, 73, 141]
const ButtonY := 224
## The list the arrow drops (measured on TeeJ's screenshot of the original's,
## rebuilt to 0 differing pixels): OUI.DropList over the costs, the times and
## the buttons - each item's 122x50 picture every 70 pixels from y 119, its
## name (Arial 11) centred over the picture's last rows.
const ListRect := Rect2(9, 111, 195, 144)
const ListLayout := {"top": 8, "pitch": 70, "picture_x": 38, "picture_y": 0, "name_y": 44, "name_px": 11}

## [{ name, picture (drawn size), refined, maint, days, blocked, place:
##    Callable(count) -> Result, encyclopedia: [kind, id] }]
var _items: Array = []
var _deployDays: int = 0
var _destination: String = ""
var _helpers: int = 1
var _onDone: Callable
var _faction: Faction
var _choice: int = 0
var _count: int = 1

var _canvas: Control
var _picture: TextureRect
var _name: Label
var _refined: Label
var _maint: Label
var _completion: Label
var _deployment: Label
var _number: Label
var _ok: TextureButton
var _list: Control
var _listRows: Array = []


## True when the player imported the art this window is made of.
static func CanBuild() -> bool:
	return OUI.Has(["build_plate", "list_starfield"]) and Art.ButtonIcon("build_ok") != null \
		and Art.ButtonIcon("build_list_open") != null


func Setup(ui: UIManager, f: Faction, items: Array, deployDays: int, destination: String, helpers: int, onDone: Callable) -> void:
	_uiManager = ui
	_faction = f
	_items = items
	_deployDays = deployDays
	_destination = destination
	_helpers = maxi(1, helpers)
	_onDone = onDone
	_choice = 0
	_count = 1
	_build()
	OUI.Modal(self)
	_show(0)


func _build() -> void:
	# The title is centred on x 102: the label runs from x 11 to the close box.
	OUI.DialogFrame(self, _faction, OUI.Pic("build_plate"), 13, 9, true)
	var area: MarginContainer = OUI.Flatten(self)
	for c in area.get_children():
		area.remove_child(c)
		c.queue_free()
	var body := Control.new()
	body.name = "OriginalBody"
	body.custom_minimum_size = Vector2(PlateW - 2 * OUI.DialogBevel, PlateH - 2 * OUI.DialogBevel - OUI.DialogBarH) * K
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(body)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.position = -Vector2(OUI.DialogBevel, OUI.DialogBevel + OUI.DialogBarH) * K
	_canvas.size = Vector2(PlateW, PlateH) * K
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_canvas)

	_picture = OUI.Place(_canvas, null, 0, PictureTop, "Picture")
	_name = OUI.Text(_canvas, "", PictureCentreX - 100, NameY, 200, 13, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Name")
	OUI.PictureButton(_canvas, "build_list_open", ListOpenAt.x, ListOpenAt.y,
		"Bring up the list of items to build").pressed.connect(func() -> void: _open_list(_list == null or not _list.visible))
	_refined = OUI.Text(_canvas, "", RefinedCentreX - 30, CostY, 60, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Refined")
	_maint = OUI.Text(_canvas, "", MaintCentreX - 30, CostY, 60, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Maintenance")
	OUI.Text(_canvas, "Best Time To Completion:", 10, CompletionY, 140, 14, 11, Cream, HORIZONTAL_ALIGNMENT_LEFT, false, "CompletionLabel")
	OUI.Text(_canvas, "Best Time To Deployment:", 10, DeploymentY, 140, 14, 11, Cream, HORIZONTAL_ALIGNMENT_LEFT, false, "DeploymentLabel")
	_completion = OUI.Text(_canvas, "", TimesRight - 80, CompletionY, 80, 14, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, false, "Completion")
	_deployment = OUI.Text(_canvas, "", TimesRight - 80, DeploymentY, 80, 14, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, false, "Deployment")
	for l in [_completion, _deployment]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_PASS
	OUI.Text(_canvas, "Number to build:", 43, 196, 96, 16, 13, Cream, HORIZONTAL_ALIGNMENT_LEFT, false, "NumberLabel")
	_number = OUI.Text(_canvas, "1", NumberAt.x, NumberAt.y, 44, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Number")
	_number.mouse_filter = Control.MOUSE_FILTER_STOP
	_number.tooltip_text = "Number of units to build consecutively"
	_number.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				_step(1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_step(-1))
	OUI.PictureButton(_canvas, "build_up", UpAt.x, UpAt.y, "Increase").pressed.connect(func() -> void: _step(1))
	OUI.PictureButton(_canvas, "build_down", DownAt.x, DownAt.y, "Decrease").pressed.connect(func() -> void: _step(-1))
	OUI.PictureButton(_canvas, "build_encyclopedia", ButtonXs[0], ButtonY, "Encyclopedia").pressed.connect(_on_encyclopedia)
	_ok = OUI.PictureButton(_canvas, "build_ok", ButtonXs[1], ButtonY, "Build")
	_ok.texture_disabled = OUI.Btn("build_ok", "disabled")
	_ok.pressed.connect(_on_build)
	OUI.PictureButton(_canvas, "build_cancel", ButtonXs[2], ButtonY, "Cancel").pressed.connect(CloseWindow)


## Drops the list (built afresh, so the item on show is the grey one) or
## puts it away. Picking a row shows that item and puts the list away.
func _open_list(open: bool) -> void:
	if not open:
		if _list != null:
			_list.visible = false
		return
	if _list != null:
		_list.queue_free()
	_list = OUI.DropList(_canvas, ListRect, _items, _choice, ListLayout, func(index: int) -> void:
		_show(index)
		_open_list(false))
	_listRows = _list.get_meta("rows")


func _show(index: int) -> void:
	if _items.is_empty():
		return
	_choice = clampi(index, 0, _items.size() - 1)
	var it: Dictionary = _items[_choice]
	var pic: Texture2D = it.get("picture")
	_picture.texture = pic
	if pic != null:
		_picture.size = pic.get_size()
		_picture.position = Vector2(PictureCentreX * K - pic.get_width() / 2.0, PictureTop * K).floor()
	_name.text = str(it.name)
	_refined.text = str(it.refined)
	_maint.text = str(it.maint)
	# Several facilities on one job finish it proportionally sooner - "best"
	# time is with everything selected working it.
	var best: int = maxi(1, int(it.days) / _helpers)
	_completion.text = "%d Days" % best
	_completion.tooltip_text = ("%d facilities working together (%d days with one)" % [_helpers, int(it.days)]) if _helpers > 1 else ""
	_deployment.text = "%d Days" % _deployDays
	_deployment.tooltip_text = "Delivered to %s" % _destination if not _destination.is_empty() else ""
	var blocked: String = str(it.get("blocked", ""))
	_ok.disabled = not blocked.is_empty()
	_ok.tooltip_text = blocked if not blocked.is_empty() else "Build"


func _step(delta: int) -> void:
	_count = clampi(_count + delta, 1, 99)
	_number.text = str(_count)


func _on_encyclopedia() -> void:
	var target: Array = _items[_choice].get("encyclopedia", [])
	if target.size() >= 2 and _uiManager != null:
		_uiManager.OpenEncyclopedia(str(target[0]), str(target[1]))


func _on_build() -> void:
	var place: Callable = _items[_choice].place
	var want: int = _count
	var res: Result = place.call(want)
	var made: int = int(res.value) if res.value != null else 0
	if made > 0 and made < want:
		print("[Build] Queued %d of %d - %s" % [made, want, res.error])
	elif made == 0:
		print("[Build] %s" % res.error)
	var done: Callable = _onDone
	CloseWindow()
	if done.is_valid():
		done.call()
