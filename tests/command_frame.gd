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
	for sub in ["windows", "alerts", "screens"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	# A galaxy picture, so the map has a backdrop to keep in sight.
	_png("%s/screens/galaxy.png" % dir, 640, 480, Color(0.2, 0.25, 0.5))

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
		var backdrop: Sprite2D = (main.get_node("GalaxyMap") as GalaxyMap).Backdrop()
		_check(bg.color == Color.BLACK and bg.visible and not bg.z_as_relative
			and backdrop != null and bg.z_index < backdrop.z_index, "%s: black either side, under the galaxy picture" % side)
		var map: Node2D = main.get_node("GalaxyMap")
		var picAt: Vector2 = CommandFrame.Layout[side]["picture"]
		_check(map.position.is_equal_approx(origin + picAt * s) and is_equal_approx(map.scale.x, 640 * s / GalaxyMap.Frame.x) and map.position != plainAt,
			"%s: the galaxy picture behind the frame where the original draws it, at its scale (%s x%.3f)" % [side, str(map.position), map.scale.x])
		_check(backdrop.region_enabled and backdrop.region_rect.size.is_equal_approx((Vector2(640, 481) - picAt).min(Vector2(640, 480))),
			"%s: the picture cut off at the frame's edge (%s)" % [side, str(backdrop.region_rect)])
		# Every world where the original draws it: the 1024-unit space on the
		# 607x437 picture, the star's centre 7 px in (TeeJ's screenshots).
		var gm: GalaxyMap = map
		var worst := 0.0
		for p in GameState.AllPlanets():
			var drawn: Vector2 = gm.position + gm.MapPos(p.MapX, p.MapY) * gm.scale
			var want: Vector2 = origin + (picAt + Vector2(p.MapX * 607.0 / 1024.0 + 7.0, p.MapY * 437.0 / 1024.0 + 7.0)) * s
			worst = maxf(worst, drawn.distance_to(want))
		_check(worst < 0.5, "%s: every world where the original draws it (worst %.3f px)" % [side, worst])
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

		# THE BOTTOM BARS span the frame exactly, each row of buttons on its
		# middle; Feedback at the blue bar's left end, the build label at its
		# right end; no Menu button, no Galaxy Map Layers (TeeJ, 2026-09-25).
		var across := Rect2(origin, Vector2(640, 481) * s)
		var mid: float = across.get_center().x
		var blue: Rect2 = bar.Panel().get_global_rect()
		var grey: Control = ui.get_node("HBoxContainer")
		_check(absf(blue.position.x - across.position.x) <= 1 and absf(blue.end.x - across.end.x) <= 1
			and absf(grey.get_global_rect().position.x - across.position.x) <= 1 and absf(grey.get_global_rect().end.x - across.end.x) <= 1,
			"%s: the blue and grey bars span the frame (%s, %s; frame %s)" % [side, str(blue), str(grey.get_global_rect()), str(across)])
		var cats := Rect2()
		var anyCat := false
		for n in bar.Row().get_children():
			if n is Control and (n as Control).visible:
				cats = (n as Control).get_global_rect() if not anyCat else cats.merge((n as Control).get_global_rect())
				anyCat = true
		var finders: Rect2 = (grey.get_node("PlanetInfo") as Control).get_global_rect().merge((grey.get_node("Encyclopedia") as Control).get_global_rect())
		_check(absf(cats.get_center().x - mid) <= 1.5 and absf(finders.get_center().x - mid) <= 1.5,
			"%s: both rows centred on the frame (%.1f, %.1f; middle %.1f)" % [side, cats.get_center().x, finders.get_center().x, mid])
		_check(not (grey.get_node("MenuButton") as Control).visible and ui.find_child("GalaxyMapLayers", true, false) == null,
			"%s: no Menu button, no Galaxy Map Layers" % side)
		var ver: Label = ui.find_child("BuildVersion", true, false)
		var verAt: Rect2 = ver.get_global_rect() if ver != null else Rect2()
		var verText: float = verAt.end.x - (ver.get_minimum_size().x if ver != null else 0.0)
		_check(ver != null and ver.get_parent() == ui and ver.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
			and verAt.end.x <= across.end.x and verAt.end.x >= across.end.x - 12 and blue.encloses(verAt) and verText > cats.end.x,
			"%s: the build label at the blue bar's right end, clear of its buttons (text from %.0f, buttons end %.0f)" % [side, verText, cats.end.x])
		var fb: FeedbackPanel = ui.get_node_or_null("FeedbackPanel")
		var fbAt: Rect2 = fb.get_global_rect() if fb != null else Rect2()
		_check(fb != null and fb.OnBar and absf(fbAt.position.x - across.position.x) <= 0.5 and blue.encloses(fbAt) and fbAt.end.x < cats.position.x,
			"%s: Feedback at the blue bar's far left, clear of its buttons (%s, buttons from %.0f)" % [side, str(fbAt), cats.position.x])

		# THE SECTORS keep the grey bar on the right, outside the frame; THE
		# WINDOW REFERENCE BAR on the frame's shelf takes minimised windows, one
		# to a slat (TeeJ, 2026-09-25).
		var shelf: Rect2 = frame.Shelf()
		var tb: Control = ui.get_node("TaskbarPanel")
		_check(tb.get_global_rect().position.x >= origin.x + 640 * s - 1 and ui.PinnedSectors().size() > 0,
			"%s: the sectors in the grey bar right of the frame" % side)
		var refBar: Control = ui.get_node_or_null("ReferenceBar")
		_check(refBar != null and Rect2(refBar.position, refBar.size).is_equal_approx(shelf), "%s: the Window Reference Bar on the frame's shelf" % side)
		var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == GameSettings.PlayerFaction)
		ui.OnEconomyClicked(home)
		for _i in 3:
			await process_frame
		var ew: DraggableWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is EconomyWindow)
		if ew != null:
			ew.MinimizeWindow()
			for _i in 3:
				await process_frame
		_check(ew != null and refBar != null and _shelf_fits(refBar, shelf) and refBar.get_child_count() == 1,
			"%s: a minimised window takes a slat on the shelf" % side)
		if refBar != null and refBar.get_child_count() > 0:
			# The original's entry (TeeJ's Commenor): yellow, Arial 11 at the
			# frame's scale, no outline, no fill, from the slat's left.
			var entry: Button = refBar.get_child(0)
			var normal: StyleBox = entry.get_theme_stylebox("normal")
			_check(entry.get_theme_color("font_color") == Color(1, 1, 0) and entry.get_theme_color("font_hover_color") == Color(1, 1, 0)
				and entry.get_theme_font_size("font_size") == roundi(11.0 * s) and entry.get_theme_constant("outline_size") == 0
				and entry.alignment == HORIZONTAL_ALIGNMENT_LEFT and normal is StyleBoxEmpty
				and entry.get_theme_stylebox("hover") is StyleBoxEmpty and is_equal_approx(normal.content_margin_left, 2.0 * s),
				"%s: the entry as the original draws it - yellow, %d px, no outline or fill, left" % [side, entry.get_theme_font_size("font_size")])
			(refBar.get_child(0) as Button).pressed.emit()
			for _i in 3:
				await process_frame
			_check(ew.visible and refBar.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(),
				"%s: its slat restores it and clears" % side)

		var inWindow: Vector2 = origin + (win.position + win.size / 2.0) * s
		var onMetal: Vector2 = origin + Vector2(320, 5) * s
		_check(not frame._has_point(inWindow) and frame._has_point(onMetal) and not frame._has_point(Vector2(origin.x - 10, 400)),
			"%s: the metal takes clicks; the window and the black do not" % side)
		await _stop(main)

	# A huge galaxy's sectors all fit the grey bar, top to bottom of the screen.
	main = await _start("alliance", Enums.GalaxySize.Huge)
	ui = main.get_node("UIManager")
	await process_frame
	var pins: Dictionary = ui.PinnedSectors()
	var lowest := 0.0
	for n in pins:
		lowest = maxf(lowest, (pins[n] as Control).get_global_rect().end.y)
	_check(pins.size() > 12 and lowest <= ui.get_viewport().get_visible_rect().size.y,
		"a huge galaxy's %d sectors all fit the grey bar (lowest at %d)" % [pins.size(), int(lowest)])
	await _stop(main)
	# A huge galaxy's every world is in the frame's window, not under its metal
	# (TeeJ, 2026-09-25: "in large mode, sectors are being cut off").
	for side in ["alliance", "empire"]:
		main = await _start(side, Enums.GalaxySize.Huge)
		var gm: GalaxyMap = main.get_node("GalaxyMap")
		var outside: Array = GameState.AllPlanets().filter(func(p: Planet) -> bool:
			return not UIManager.MapFrame.has_point(gm.position + gm.MapPos(p.MapX, p.MapY) * gm.scale))
		_check(GameState.AllPlanets().size() == 200 and outside.is_empty(),
			"%s: all 200 worlds of a huge galaxy in the frame's window (%d outside)" % [side, outside.size()])
		await _stop(main)
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[command_frame] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Every entry on the shelf is one slat high (or an even share past twelve)
## and inside it.
func _shelf_fits(list: Node, shelf: Rect2) -> bool:
	var entries: Array = list.get_children().filter(func(n: Node) -> bool:
		return n is Button and not n.is_queued_for_deletion())
	if entries.is_empty():
		return false
	var h: float = shelf.size.y / float(maxi(12, entries.size()))
	for b in entries:
		var r := Rect2((b as Control).global_position, (b as Control).size)
		# Controls size to whole pixels: within one of the exact share.
		if absf((b as Control).size.y - h) > 1.0 or not shelf.grow(1.5).encloses(r):
			print("[command_frame]   entry %s %s outside %s or not %.2f high" % [(b as Button).text, str(r), str(shelf), h])
			return false
	return true


func _start(side: String, galaxy: int = Enums.GalaxySize.Standard) -> Node:
	Art.Reset()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = galaxy
	GameSettings.PlayerFaction = FactionRegistry.ById(side)
	GameSettings.ProvideFeedback = true   # the Feedback box on the blue bar (it sends nothing unless submitted)
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
