extends SceneTree
## The Command Center as the original draws it (manual p022 Fig 2.3; TeeJ,
## 2026-09-25: the whole frame, not a strip and a pillar on our own layout):
## with the side's frame in the art set, the frame IS the screen - scaled to
## its height and centred, the black either side - with the galaxy map behind
## its window at the frame's scale; the Speed Control and the resource
## displays on the frame's own boxes; the Message Alert bar in the frame's
## slots (the Alliance's left, the Empire's right) in the original's order,
## dim, lit with unread mail, each opening the Message Index; the Game Options
## monitor where the frame has it. The metal takes clicks, the window does
## not. Windows centre and dock in the frame's window. Without the frame,
## nothing changes. Both sides. Writes and removes its own test art.
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
	for sub in ["windows", "alerts"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])

	# Without the frame: the plain screen.
	var main: Node = await _start("alliance")
	var ui: UIManager = main.get_node("UIManager")
	_check(ui.CommandFrameRef == null and (ui.get_node("CommsPanel") as Control).visible
		and UIManager.MapFrame == UIManager.DefaultMapFrame, "without the frame in the art set, the plain screen stays")
	var plainMap: Node2D = main.get_node("GalaxyMap")
	var plainAt: Vector2 = plainMap.position
	await _stop(main)

	for side in ["alliance", "empire"]:
		var win: Rect2 = CommandFrame.Layout[side]["window"]
		var img := Image.create(640, 481, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.6, 0.6, 0.62))
		img.fill_rect(Rect2i(win), Color(0, 0, 0, 0))
		img.save_png("%s/windows/command.%s.png" % [dir, side])
		_png("%s/windows/hud_speed.%s.png" % [dir, side], 106, 24, Color(0.2, 0.2, 0.2))
		_png("%s/windows/hud_resources.%s.png" % [dir, side], 320, 30, Color(0.2, 0.2, 0.2))
		for c in Order:
			_png("%s/alerts/%s.%s.png" % [dir, side, c.to_lower()], 27, 22, Color(0.1, 0.1, 0.1))
			_png("%s/alerts/%s.%s.lit.png" % [dir, side, c.to_lower()], 27, 22, Color(1, 0.8, 0))
	for side in ["alliance", "empire"]:
		var win: Rect2 = CommandFrame.Layout[side]["window"]
		main = await _start(side)
		ui = main.get_node("UIManager")
		var frame: CommandFrame = ui.CommandFrameRef
		_check(frame != null, "%s: the frame is built" % side)
		if frame == null:
			await _stop(main)
			continue
		var screen: Vector2 = ui.get_viewport().get_visible_rect().size
		var s: float = screen.y / 481.0
		var origin := Vector2(floorf((screen.x - 640 * s) / 2.0), 0)
		var pic: TextureRect = frame.get_node("Frame")
		_check(pic.position == origin and pic.size.is_equal_approx(Vector2(640, 481) * s),
			"%s: the whole frame fills the screen's height, centred (%s, %s)" % [side, str(pic.position), str(pic.size)])
		var bar: GidBar = (main.get_node("GalaxyMap") as GalaxyMap).Bar()
		_check((frame.get_parent() as CanvasLayer).layer == UIManager.FrameLayer and bar != null and bar.layer == GidBar.FramedLayer
			and ui.layer == UIManager.WindowsLayer and UIManager.FrameLayer < GidBar.FramedLayer and GidBar.FramedLayer < UIManager.WindowsLayer
			and not (ui.get_node("CommsPanel") as Control).visible,
			"%s: map, then frame, then the GID bar, then the windows; the socket column put away" % side)
		var bg: ColorRect = main.get_node("Background")
		_check(bg.color == Color.BLACK and bg.visible, "%s: black either side" % side)
		var map: Node2D = main.get_node("GalaxyMap")
		_check(map.position == origin and is_equal_approx(map.scale.x, 640 * s / GalaxyMap.Frame.x) and map.position != plainAt,
			"%s: the galaxy map behind the frame at its scale (%s x%.3f)" % [side, str(map.position), map.scale.x])
		_check(UIManager.MapFrame.is_equal_approx(frame.MapWindow()) and UIManager.MapFrame.position.is_equal_approx(origin + win.position * s),
			"%s: windows centre and dock in the frame's window (%s)" % [side, str(UIManager.MapFrame)])
		var hud: Dictionary = GameManager.HudFrame[side]
		var tc: Control = ui.get_node("TimeControls")
		var res: Control = ui.get_node_or_null("OriginalResources")
		_check(tc.position == (origin + hud["speed"] * s).floor(), "%s: the Speed Control on the frame's box (%s)" % [side, str(tc.position)])
		_check(res != null and res.position == (origin + hud["resources"] * s).floor(), "%s: the resource displays on the frame's box" % side)

		var slot: Vector2 = CommandFrame.Layout[side]["slot"]
		var alerts: Array = []
		for c in Order:
			alerts.append(frame.get_node_or_null("Alert" + c))
		_check(not alerts.has(null), "%s: the nine category icons" % side)
		if not alerts.has(null):
			var placed := true
			for n in 9:
				if not (alerts[n] as Control).position.is_equal_approx(origin + (slot + Vector2(0, n * 25)) * s):
					placed = false
			_check(placed, "%s: in the frame's slots, the original's order" % side)
			var onLeft: bool = (alerts[0] as Control).position.x < origin.x + 320 * s
			_check(onLeft == (side == "alliance"), "%s: the bar on the %s, as the original has it" % [side, "left" if side == "alliance" else "right"])
			_check((alerts[1] as TextureButton).texture_normal == Art.AlertIcon(side, "Fleets", false), "%s: dim while nothing is unread" % side)
			EventBus.Tell(GameSettings.PlayerFaction, GameMessage.new("Test", "A test message.", Enums.MessageCategory.Fleets, StrategicTickManager.Today, null))
			EventBus.BroadcastChanged()
			await process_frame
			_check((alerts[1] as TextureButton).texture_normal == Art.AlertIcon(side, "Fleets", true), "%s: Fleets lights with unread mail" % side)
			(alerts[1] as TextureButton).pressed.emit()
			for _i in 3:
				await process_frame
			_check(ui._openWindows.get("Communications") != null, "%s: its icon opens the Message Index" % side)
		var mon: Rect2 = CommandFrame.Layout[side]["monitor"]
		var options: Button = frame.get_node_or_null("GameOptions")
		_check(options != null and options.position.is_equal_approx(origin + mon.position * s), "%s: the Game Options monitor where the frame has it" % side)

		var inWindow: Vector2 = origin + (win.position + win.size / 2.0) * s
		var onMetal: Vector2 = origin + Vector2(320, 5) * s
		_check(not frame._has_point(inWindow) and frame._has_point(onMetal) and not frame._has_point(Vector2(origin.x - 10, 400)),
			"%s: the metal takes clicks; the window and the black do not" % side)
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
