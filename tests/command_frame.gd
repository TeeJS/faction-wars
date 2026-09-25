extends SceneTree
## The Command Center's frame (manual p022 Fig 2.3; TeeJ, 2026-09-25: the
## frame across the top from the day counter and down the left-hand column,
## then that column): with the side's frame in the art set, its top bar lines
## up under the Speed Control, the Message Alert bar's column stands against
## the map's left edge with the nine category icons in its slots in the
## original's order (dim, lit with unread mail, each opening the Message Index
## on its category) and the Game Options monitor under them; the socket column
## is put away. Without the frame, nothing changes. Both sides. Writes and
## removes its own test art.
##
##   .\tools\run-gd.ps1 tests/command_frame.gd

const Art := preload("res://src/ui/artwork.gd")
const Order := ["Loyalty", "Fleets", "Missions", "Resources", "Manufacturing", "Defense", "Conflict", "Advice", "Chat"]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[command_frame] ok   %s" % what)
	else:
		_fails += 1
		print("[command_frame] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-command-frame-art"
	FactionRegistry.EnsureLoaded()
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "alerts", "hud"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])

	# Without the frame: the socket column as before.
	var main: Node = await _start("alliance")
	var ui: UIManager = main.get_node("UIManager")
	_check(ui.CommandFrameRef == null and (ui.get_node("CommsPanel") as Control).visible, "without the frame in the art set, the plain column stays")
	await _stop(main)

	for side in ["alliance", "empire"]:
		_png("%s/windows/command.%s.png" % [dir, side], 640, 481, Color(0.6, 0.6, 0.62))
		_png("%s/windows/hud_speed.%s.png" % [dir, side], 106, 24, Color(0.2, 0.2, 0.2))
		_png("%s/windows/hud_resources.%s.png" % [dir, side], 320, 30, Color(0.2, 0.2, 0.2))
		for c in Order:
			_png("%s/alerts/%s.%s.png" % [dir, side, c.to_lower()], 27, 22, Color(0.1, 0.1, 0.1))
			_png("%s/alerts/%s.%s.lit.png" % [dir, side, c.to_lower()], 27, 22, Color(1, 0.8, 0))
	for side in ["alliance", "empire"]:
		main = await _start(side)
		ui = main.get_node("UIManager")
		var frame: CommandFrame = ui.CommandFrameRef
		_check(frame != null, "%s: the frame is built" % side)
		if frame == null:
			await _stop(main)
			continue
		_check(not (ui.get_node("CommsPanel") as Control).visible, "%s: the socket column is put away" % side)
		_check(frame.get_index() == 0, "%s: behind every window and panel" % side)
		var lay: Dictionary = CommandFrame.Layout[side]
		var tc: Control = ui.get_node("TimeControls")
		var speed: Vector2 = GameManager.HudFrame[side]["speed"]
		var band: TextureRect = frame.get_node("Band")
		var expected: float = tc.position.x - speed.x * 1.5 + (lay["band"] as Rect2i).position.x * 1.5
		_check(absf(band.position.x - expected) < 1.0 and band.position.y == 0,
			"%s: the top bar lines up under the Speed Control (%.1f, expected %.1f)" % [side, band.position.x, expected])
		var fills: Array = frame.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Fill"))
		var reach := [INF, -INF]
		for f in [band] + fills:
			reach[0] = minf(reach[0], (f as Control).position.x)
			reach[1] = maxf(reach[1], (f as Control).position.x + (f as Control).size.x)
		_check(reach[0] <= 0 and reach[1] >= 1440, "%s: the bar runs from edge to edge (%d to %d)" % [side, int(reach[0]), int(reach[1])])
		var col: Rect2 = frame.ColumnRect()
		_check(is_equal_approx(col.end.x, UIManager.MapLeft), "%s: the column stands against the map's left edge" % side)
		var alerts: Array = []
		for c in Order:
			alerts.append(frame.get_node_or_null("Alert" + c))
		_check(not alerts.has(null), "%s: the nine category icons" % side)
		if alerts.has(null):
			await _stop(main)
			continue
		var pitch: float = (alerts[1] as Control).position.y - (alerts[0] as Control).position.y
		var inOrder := true
		for n in range(1, 9):
			if not is_equal_approx((alerts[n] as Control).position.y - (alerts[n - 1] as Control).position.y, 37.5):
				inOrder = false
		_check(inOrder and is_equal_approx(pitch, 37.5), "%s: in the original's order, one slot (25 x 1.5) apart" % side)
		_check(Lq.all(alerts, func(a: TextureButton) -> bool: return col.encloses(Rect2(a.position, a.size).grow(-1))),
			"%s: every icon inside the column" % side)
		var dimTex: Texture2D = (alerts[0] as TextureButton).texture_normal
		_check(dimTex == Art.AlertIcon(side, "Loyalty", false) or EventBus.UnreadCount(Enums.MessageCategory.Loyalty) > 0,
			"%s: dim while nothing is unread" % side)
		var msg := GameMessage.new("Test", "A test message.", Enums.MessageCategory.Fleets, StrategicTickManager.Today, null)
		EventBus.Tell(GameSettings.PlayerFaction, msg)
		EventBus.BroadcastChanged()
		await process_frame
		_check((alerts[1] as TextureButton).texture_normal == Art.AlertIcon(side, "Fleets", true), "%s: Fleets lights with unread mail" % side)
		(alerts[1] as TextureButton).pressed.emit()
		for _i in 3:
			await process_frame
		var mw: Node = ui._openWindows.get("Communications")
		_check(mw != null, "%s: its icon opens the Message Index" % side)
		var options: Button = frame.get_node_or_null("GameOptions")
		_check(options != null and col.encloses(Rect2(options.position, options.size)), "%s: the Game Options monitor, in the column" % side)
		await _stop(main)
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[command_frame] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _start(side: String) -> Node:
	Art.Reset()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(side)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	return main


func _stop(main: Node) -> void:
	main.queue_free()
	for _i in 3:
		await process_frame


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
