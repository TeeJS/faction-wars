extends DraggableWindow
## THE ORIGINAL'S CONFIRMATION DIALOG, as its Scrap asks (TeeJ's screenshots
## of the original, both sides, rebuilt pixel for pixel 2026-09-23): no title
## bar, the side's 424x331 frame drawn whole (STRATEGY.DLL 11126 / 11125, its
## last row pure blue), the 400x200 console picture (1033 / 1032) at (12, 30), the question and one
## line per unit in white Arial 13 from (24, 242) a line every 16, and the
## tick and cross at (355, 244) and (355, 281). Modal; Esc is the cross,
## Enter the tick (manual p064). Opened through DraggableWindow.ConfirmScrapUnits.
##
## Preloaded by path: a new script can lag the editor's class cache.

const K := OUI.K
const FrameW := 424
const FrameH := 331

var _onConfirm: Callable
var _faction: Faction


static func CanBuild() -> bool:
	return OUI.Has(["confirm_frame.empire", "confirm_frame.alliance", "scrap_picture.empire"]) \
		and Art.ButtonIcon("decision_ok") != null


func Setup(ui: UIManager, f: Faction, picture: Texture2D, text: String, okTip: String, onConfirm: Callable) -> void:
	_uiManager = ui
	_faction = f
	_onConfirm = onConfirm
	var side: String = "alliance" if f != null and f.ArtSkin == "alliance" else "empire"
	var bar: Control = get_node_or_null("%TitleBar")
	if bar != null:
		bar.visible = false
	var sb := StyleBoxTexture.new()
	sb.texture = OUI.Pic("confirm_frame." + side)
	add_theme_stylebox_override("panel", sb)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var area: MarginContainer = OUI.Flatten(self)
	for c in area.get_children():
		area.remove_child(c)
		c.queue_free()
	var canvas := Control.new()
	canvas.name = "Canvas"
	canvas.custom_minimum_size = Vector2(FrameW, FrameH) * K
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(canvas)
	OUI.Place(canvas, picture, 12, 30, "Picture")
	var words := OUI.Text(canvas, text, 24, 242, 325, 76, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Text")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.clip_text = true
	OUI.LinePitch(words, 13, 16)
	var ok := OUI.PictureButton(canvas, "decision_ok", 355, 244, okTip)
	ok.pressed.connect(_confirm)
	OUI.PictureButton(canvas, "decision_cancel", 355, 281, "Cancel").pressed.connect(CloseWindow)
	OUI.Modal(self)


func _confirm() -> void:
	var done: Callable = _onConfirm
	CloseWindow()
	if done.is_valid():
		done.call()


## Enter is the tick ("Accept/Activate Current Selection (same as clicking
## OK)", manual p064); Esc, the cross, is the base class's.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() \
			and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_confirm()
		return
	super(event)
