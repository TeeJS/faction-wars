class_name FeedbackPanel
extends PanelContainer
## The tester's feedback box (TeeJ, room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #80):
## shown at the bottom of the left column when "Provide feedback" is ticked on
## the Cockpit. A note typed here goes to the relay's POST /feedback together
## with the facts that make it reproducible: day, seed, the game's settings,
## the client, and this client's whole session log (the same lines the
## replayer rebuilds a game from). If the relay cannot be reached the report
## is kept under user://feedback/ and the panel says so - never lost.

const MaxNote := 2000

var _text: TextEdit
var _submit: Button
var _status: Label
var _http: HTTPRequest
var _pending: Dictionary = {}
var _title: Button
var _body: VBoxContainer
static var _folded: bool = false


## Folded: only the header strip shows, at the bottom of the column.
func set_folded(folded: bool) -> void:
	_folded = folded
	_body.visible = not folded
	_title.text = "Feedback  ▸" if folded else "Feedback  ▾"
	offset_top = -110.0 if folded else -270.0


func _ready() -> void:
	name = "FeedbackPanel"
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Above the two bottom bars (the message-category row and the toolbar),
	# which are ~70 px tall (TeeJ, room #147: the box was hidden behind them).
	offset_left = 4.0
	offset_right = 304.0
	offset_top = -270.0
	offset_bottom = -80.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	# The header folds the box to a one-line strip and back (TeeJ, room #157:
	# a tidy corner). Remembered for the session.
	_title = Button.new()
	_title.text = "Feedback  ▾"
	_title.flat = true
	_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_title.tooltip_text = "Fold or open the feedback box."
	_title.pressed.connect(func() -> void: set_folded(not _folded))
	box.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	_text = TextEdit.new()
	_text.placeholder_text = "What went wrong, or what you expected. Sent with the day, seed and this game's log."
	_text.custom_minimum_size = Vector2(0, 90)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 12)
	_body.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)
	_submit = Button.new()
	_submit.text = "Submit"
	_submit.tooltip_text = "Send this note and the game's log to the server."
	_submit.pressed.connect(submit)
	row.add_child(_submit)
	_body.add_child(row)
	set_folded(_folded)
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_on_completed)
	add_child(_http)


## Where feedback goes: the relay's origin, over HTTP(S), at /feedback.
static func feedback_url() -> String:
	var ws := MpSetup.relay_url()
	var http := ws.replace("wss://", "https://").replace("ws://", "http://")
	if http.ends_with("/ws"):
		http = http.substr(0, http.length() - 3)
	return http + "/feedback"


## Everything a report carries besides the note.
static func report(note: String) -> Dictionary:
	var client := {
		"godot": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"window": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
	}
	if OS.has_feature("web"):
		var ua: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
		if ua is String:
			client["user_agent"] = ua
	var lobby: RelayClient = MpSetup.lobby
	return {
		"player": MpSetup.player_name if MpSetup.session != null else "single",
		"game": lobby.code if (MpSetup.session != null and lobby != null) else "single",
		"day": StrategicTickManager.Today,
		"seed": GameSettings.Seed,
		"header": CommandLog.Header(),
		"speed_rule": GameSettings.SpeedRule,
		"message": note.left(MaxNote),
		"client": client,
		"sent_at": Time.get_datetime_string_from_system(true, true),
		"log": CommandLog.Snapshot(),
	}


func submit() -> void:
	var note := _text.text.strip_edges()
	if note.is_empty():
		_status.text = "Type a note first."
		return
	_pending = report(note)
	_submit.disabled = true
	_status.text = "Sending..."
	var body := JSON.stringify(_pending)
	var err := _http.request(feedback_url(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_keep_locally("request could not start (%d)" % err)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var reply: Variant = JSON.parse_string(body.get_string_from_utf8())
		var id := str(reply.get("id", "")) if reply is Dictionary else ""
		_status.text = "Sent. Thank you. (%s)" % id if not id.is_empty() else "Sent. Thank you."
		_text.text = ""
		_submit.disabled = false
		_pending = {}
		return
	_keep_locally("server answered %d (result %d)" % [code, result])


## The report is not lost when the relay is unreachable: kept under user://feedback/.
func _keep_locally(why: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://feedback")
	var path := "user://feedback/%s.json" % Time.get_datetime_string_from_system(true).replace(":", "-")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_pending))
		f.close()
		_status.text = "Could not send (%s) - saved locally as %s." % [why, path.get_file()]
	else:
		_status.text = "Could not send (%s), and could not save locally." % why
	_submit.disabled = false
