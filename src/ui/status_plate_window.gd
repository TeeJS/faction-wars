extends DraggableWindow
## A STATUS WINDOW (manual p064: modal, closed by its diamond or Esc). With the
## player's imported art it is the original's (OUI.StatusPlate: no title bar,
## the side's plate, fields left, picture and name right); without it, the
## same content in a plain window. Used for units, facilities and the
## manufacturing queues (Fig 3.29, "Facilities Under Construction").
##
## Its content comes from `source`, a Callable returning
##   { title, fields: [[label, value], ...], picture, backdrop, name,
##     encyclopedia: [kind, id] or [] }
## asked again on every refresh, so the window follows what it describes.
##
## Preloaded by path: a new script can lag the editor's class cache.

var _source: Callable
var _faction: Faction


func Setup(ui: UIManager, f: Faction, source: Callable) -> void:
	_uiManager = ui
	_faction = f
	_source = source
	_paint()
	OUI.Modal(self)


func Refresh() -> void:
	if _source.is_valid():
		_paint()


func _paint() -> void:
	var data: Dictionary = _source.call()
	WindowTitle = str(data.get("title", "Status"))
	if OUI.HasStatus():
		# A repaint keeps the list where the player scrolled it.
		var old: Node = find_child("ScrollBar", true, false)
		var first: int = int(old.get("first")) if old != null else 0
		var canvas: Control = OUI.StatusPlate(self, _faction, data)
		var bar: Node = canvas.get_node_or_null("ScrollBar")
		if bar != null and first > 0:
			bar.step(first)
		(canvas.get_node("ency_close_alliance") as BaseButton).pressed.connect(CloseWindow)
		_wire_encyclopedia(canvas.get_node("status_encyclopedia") as BaseButton, data)
		return
	_paint_plain(data)


func _wire_encyclopedia(button: BaseButton, data: Dictionary) -> void:
	var target: Array = data.get("encyclopedia", [])
	button.disabled = target.size() < 2 or _uiManager == null
	button.pressed.connect(func() -> void:
		if target.size() >= 2 and _uiManager != null:
			_uiManager.OpenEncyclopedia(str(target[0]), str(target[1])))


## The same content without the original's art: title bar, the fields, the
## picture and the name.
func _paint_plain(data: Dictionary) -> void:
	(get_node("%TitleBarLabel") as Label).text = " " + str(data.get("title", ""))
	var area: MarginContainer = get_node("%ContentArea")
	for c in area.get_children():
		area.remove_child(c)
		c.queue_free()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	area.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.custom_minimum_size = Vector2(260, 0)
	box.add_child(grid)
	for pair in data.get("fields", []):
		var l := Label.new()
		l.text = str(pair[0])
		l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		grid.add_child(l)
		var v := Label.new()
		v.text = str(pair[1])
		grid.add_child(v)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 0)
	box.add_child(right)
	var pic: Texture2D = data.get("picture")
	if pic != null:
		var r := TextureRect.new()
		r.texture = pic
		r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		right.add_child(r)
	var n := Label.new()
	n.text = str(data.get("name", ""))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(n)
	var enc := Button.new()
	enc.text = "Encyclopedia"
	right.add_child(enc)
	_wire_encyclopedia(enc, data)
