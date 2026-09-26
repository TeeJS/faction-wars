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
const OUI := preload("res://src/ui/original_ui.gd")
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
	for sub in ["windows", "alerts", "screens", "buttons", "gid"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	# A galaxy picture, so the map has a backdrop to keep in sight.
	_png("%s/screens/galaxy.png" % dir, 640, 480, Color(0.2, 0.25, 0.5))
	# The original's key: its closed button, legend marks, close box, stars.
	_png("%s/windows/gid_key_closed.png" % dir, 47, 25, Color(0.2, 0.18, 0.13))
	for m in ["alliance", "empire", "neutral"]:
		_png("%s/windows/gid_key_%s.png" % [dir, m], 9, 9, Color(1, 0, 0))
	_png("%s/windows/gid_key_unexplored.png" % dir, 15, 15, Color(0.8, 0.8, 0.8))
	_png("%s/buttons/title_close.png" % dir, 14, 14, Color(0.9, 0.9, 0.9))
	for t in ["big", "mid", "low", "none"]:
		_png("%s/gid/unexplored.%s.png" % [dir, t], 15, 15, Color(0.9, 0.9, 0.9))

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
		# The droids' idle runs: three frames each, clear round a drawn middle.
		for role in ["agent", "messenger"]:
			var r: Rect2 = CommandFrame.Layout[side][role]
			var strip := Image.create(int(r.size.x) * 3, int(r.size.y), false, Image.FORMAT_RGBA8)
			for f in 3:
				strip.fill_rect(Rect2i(f * int(r.size.x) + int(r.size.x) / 4, int(r.size.y) / 4, int(r.size.x) / 2, int(r.size.y) / 2), Color(0.8, 0.7, 0.2 + 0.2 * f))
			strip.save_png("%s/windows/droid_%s.%s.png" % [dir, role, side])
		# The Control Panel's monitors held down, and the Game Options monitor.
		var consoles: Dictionary = CommandFrame.Layout[side]["consoles"]
		for key in consoles:
			_png("%s/windows/console_%s.%s.pressed.png" % [dir, key, side], int(consoles[key].size.x), int(consoles[key].size.y), Color(0.3, 0.5, 1))
		var op: Rect2 = CommandFrame.Layout[side]["options_picture"]
		_png("%s/windows/console_options.%s.pressed.png" % [dir, side], int(op.size.x), int(op.size.y), Color(0.3, 0.5, 1))
	var tick := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	tick.fill_rect(Rect2i(2, 2, 16, 16), Color.WHITE)
	tick.save_png("%s/windows/menu_check.png" % dir)
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
			var fleets: TextureButton = alerts[1]
			var badge: Label = fleets.get_node_or_null("Badge")
			_check(fleets.texture_normal == Art.AlertIcon(side, "Fleets", false) and (badge == null or not badge.visible),
				"%s: dim, and no number, while nothing is unread" % side)
			EventBus.Tell(GameSettings.PlayerFaction, GameMessage.new("Test", "A test message.", Enums.MessageCategory.Fleets, StrategicTickManager.Today, null))
			EventBus.BroadcastChanged()
			await process_frame
			_check(fleets.texture_normal == Art.AlertIcon(side, "Fleets", true), "%s: Fleets lights with unread mail" % side)
			# The unread count on its corner, as the message column had it.
			badge = fleets.get_node_or_null("Badge")
			var unread: int = EventBus.UnreadCount(Enums.MessageCategory.Fleets)
			_check(unread > 0 and badge != null and badge.visible and badge.text == str(unread)
				and badge.get_theme_color("font_color") == Color.YELLOW and Rect2(Vector2.ZERO, fleets.size).grow(3).encloses(Rect2(badge.position, badge.size)),
				"%s: the unread count on its corner (%s)" % [side, badge.text if badge != null else "none"])
			(alerts[1] as TextureButton).pressed.emit()
			for _i in 3:
				await process_frame
			_check(ui._openWindows.get("Communications") != null, "%s: its icon opens the Message Index" % side)
		var mon: Rect2 = CommandFrame.Layout[side]["monitor"]
		var options: Button = frame.get_node_or_null("GameOptions")
		_check(options != null and options.position.is_equal_approx(origin + mon.position * s), "%s: the Game Options monitor where the frame has it" % side)

		# THE BOTTOM: the grey bar spans the frame exactly, its finders on the
		# middle; no Menu button, no Galaxy Map Layers; the blue bar gone - the
		# left-hand menu does its job - with Feedback and the build label at
		# the grey bar's two ends (TeeJ, 2026-09-25).
		var across := Rect2(origin, Vector2(640, 481) * s)
		var mid: float = across.get_center().x
		var grey: Control = ui.get_node("HBoxContainer")
		var greyAt: Rect2 = grey.get_global_rect()
		_check(absf(greyAt.position.x - across.position.x) <= 1 and absf(greyAt.end.x - across.end.x) <= 1 and not bar.Panel().visible,
			"%s: the grey bar spans the frame; the blue bar is gone (%s; frame %s)" % [side, str(greyAt), str(across)])
		var finders: Rect2 = (grey.get_node("PlanetInfo") as Control).get_global_rect().merge((grey.get_node("Encyclopedia") as Control).get_global_rect())
		_check(absf(finders.get_center().x - mid) <= 1.5, "%s: the finders centred on the frame (%.1f; middle %.1f)" % [side, finders.get_center().x, mid])
		_check(not (grey.get_node("MenuButton") as Control).visible and ui.find_child("GalaxyMapLayers", true, false) == null,
			"%s: no Menu button, no Galaxy Map Layers" % side)
		var band := Rect2(across.position.x, screen.y - 34, across.size.x, 31).grow(1)
		var ver: Label = ui.find_child("BuildVersion", true, false)
		var verAt: Rect2 = ver.get_global_rect() if ver != null else Rect2()
		var verText: float = verAt.end.x - (ver.get_minimum_size().x if ver != null else 0.0)
		_check(ver != null and ver.get_parent() == ui and ver.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
			and verAt.end.x <= across.end.x and verAt.end.x >= across.end.x - 12 and band.encloses(verAt) and verText > finders.end.x,
			"%s: the build label at the grey bar's right end, clear of its buttons (text from %.0f, buttons end %.0f)" % [side, verText, finders.end.x])
		var fb: FeedbackPanel = ui.get_node_or_null("FeedbackPanel")
		var fbAt: Rect2 = fb.get_global_rect() if fb != null else Rect2()
		_check(fb != null and fb.OnBar and absf(fbAt.position.x - across.position.x) <= 0.5 and band.encloses(fbAt) and fbAt.end.x < finders.position.x,
			"%s: Feedback at the grey bar's far left, clear of its buttons (%s, buttons from %.0f)" % [side, str(fbAt), finders.position.x])

		# THE LEFT-HAND MENU (TeeJ, 2026-09-25): every GID mode under its
		# category, the pack's short lines, the mode on the map in the side's
		# colour; "Loyalty to <side>" opens and closes the key; Display Off;
		# all in the black left of the frame, top to bottom of the screen.
		var leftMenu: Control = ui.GidMenu()
		_check(leftMenu != null and absf(leftMenu.size.x - origin.x) < 0.5 and leftMenu.position.x == 0.0, "%s: the menu fills the black left of the frame" % side)
		if leftMenu != null:
			var lowest := 0.0
			var allModes := true
			for cat in Gid.Categories:
				for mode in (cat as Gid.GidCategory).Modes:
					var r: Button = leftMenu.call("Row", mode)
					if r == null or r.text != mode.MenuLabel:
						allModes = false
					else:
						lowest = maxf(lowest, r.get_global_rect().end.y)
						if r.get_global_rect().end.x > origin.x + 0.5:
							allModes = false
			var keyRow: Button = leftMenu.call("KeyRow")
			var offRow: Button = leftMenu.find_child("DisplayOff", false, false)
			lowest = maxf(lowest, offRow.get_global_rect().end.y if offRow != null else 9999.0)
			_check(allModes and lowest <= screen.y, "%s: a line for every mode, inside the black, the lowest at %d of %d" % [side, int(lowest), int(screen.y)])
			# TeeJ's refinement (2026-09-25): the sector column's greys - its
			# panel behind, its button boxes on the rows - the rows' text 10px
			# in from the old 6, 4px more before each heading, 16px icons, no
			# rules.
			var pin: Button = ui.PinnedSectors().values()[0]
			var rowBox: StyleBox = (leftMenu.call("Row", Gid.ModeById("idle_fleets")) as Button).get_theme_stylebox("normal")
			var back: Panel = leftMenu.find_child("Back", false, false)
			var colBox: StyleBox = (ui.get_node("TaskbarPanel") as Control).get_theme_stylebox("panel")
			_check(rowBox is StyleBoxFlat and pin.get_theme_stylebox("normal") is StyleBoxFlat
				and (rowBox as StyleBoxFlat).bg_color == (pin.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
				and back != null and back.size == leftMenu.size and back.get_theme_stylebox("panel") is StyleBoxFlat and colBox is StyleBoxFlat
				and (back.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == (colBox as StyleBoxFlat).bg_color,
				"%s: the sector column's greys, the panel and the rows" % side)
			var fleetsHead: Label = leftMenu.find_child("Head_fleets", false, false)
			var uprisings: Button = leftMenu.call("Row", Gid.ModeById("uprisings"))
			var firstFleet: Button = leftMenu.call("Row", Gid.ModeById("idle_fleets"))
			_check(firstFleet != null and is_equal_approx(firstFleet.position.x + firstFleet.get_theme_stylebox("normal").content_margin_left, 16.0)
				and fleetsHead != null and uprisings != null and is_equal_approx(fleetsHead.position.y - uprisings.get_rect().end.y, 15.0),
				"%s: rows' text 10px further in, 4px more before a heading" % side)
			var ruled := false
			var iconsSmall := true
			for c in leftMenu.get_children():
				if c is ColorRect:
					ruled = true
				if c is TextureRect and ((c as TextureRect).size.x > 16.0 or (c as TextureRect).size.y > 16.0):
					iconsSmall = false
			_check(not ruled and iconsSmall, "%s: no rules, the icons at 16px" % side)
			var idle: Button = leftMenu.call("Row", Gid.ModeById("idle_fleets"))
			_check(idle != null and idle.text == "Idle", "%s: the pack's short lines ('Idle' under Fleets)" % side)
			idle.pressed.emit()
			await process_frame
			_check(Gid.ActiveMode() == Gid.ModeById("idle_fleets") and idle.get_theme_color("font_color") == OUI.SideColor(GameSettings.PlayerFaction),
				"%s: a line puts its mode on the map, in the side's colour" % side)
			_check(keyRow != null and keyRow.text == GameSettings.PlayerFaction.LoyaltyLabelShort and not (ui.get_node_or_null("MapKeyButton") != null and (ui.get_node("MapKeyButton") as Control).visible)
				and (ui.get_node("TaskbarPanel") as Control).offset_bottom == 0.0,
				"%s: '%s' in the menu, not at the sector column's foot" % [side, keyRow.text if keyRow != null else ""])
			var k: Control = bar.Key()
			var wasOpen: bool = bool(k.get("IsOpen")) if k != null and k.get("IsOpen") != null else false
			keyRow.pressed.emit()
			await process_frame
			_check(k != null and k.get("IsOpen") != null and bool(k.get("IsOpen")) != wasOpen, "%s: its line opens and closes the key" % side)
			if k != null and k.get("IsOpen") != null and bool(k.get("IsOpen")):
				k.call("Close")
			offRow.pressed.emit()
			await process_frame
			_check(Gid.ActiveMode() == Gid.DisplayOff, "%s: Display Off" % side)
			(main.get_node("GalaxyMap") as GalaxyMap).SetMode(Gid.Default())

		# THE DROIDS (manual p022 Fig 2.3, p077-p078): the agent and the message
		# droid where the original stands them, idling; the agent's menu at a
		# right-click, flipped to stay on the frame; the message droid's
		# left-click is the Message Index, its right-click its menu; the bottom
		# row's agent button goes.
		var droids: Array = frame.Droids()
		var placed := droids.size() == 2
		for i in droids.size():
			var role: String = ["agent", "messenger"][i]
			var want: Rect2 = CommandFrame.Layout[side][role]
			var got: Rect2 = (droids[i] as Control).get_global_rect()
			placed = placed and got.position.distance_to(origin + want.position * s) < 1.0 and got.size.distance_to(want.size * s) < 1.0
		_check(placed, "%s: the agent and the message droid where the original stands them" % side)
		if droids.size() == 2:
			var agent: CommandFrame.Droid = droids[0]
			var messenger: CommandFrame.Droid = droids[1]
			_check(agent.tooltip_text == AgentDroid.NameFor(GameSettings.PlayerFaction) and messenger.tooltip_text == AgentDroid.MessengerFor(GameSettings.PlayerFaction)
				and messenger.tooltip_text == ("R2-D2" if side == "alliance" else "SD-7"),
				"%s: named %s and %s" % [side, agent.tooltip_text, messenger.tooltip_text])
			var was: int = agent.Frame
			agent.Step()
			_check(agent.Frames == 3 and agent.Frame == (was + 1) % 3, "%s: the agent steps through its idle run" % side)
			_check(agent._has_point(agent.size / 2.0) and not agent._has_point(Vector2(1, 1)), "%s: a droid takes the mouse only on its own pixels" % side)
			var agentBtn: Control = ui.get_node_or_null("HBoxContainer/AgentButton")
			_check(ui.HasDroids() and agentBtn != null and not agentBtn.visible, "%s: the bottom row's agent button goes" % side)
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = false
			click.global_position = agent.get_global_rect().get_center()
			agent.gui_input.emit(click)
			await process_frame
			var am: PopupMenu = ui.get_node_or_null("AgentPopup")
			var box := Rect2(Vector2(am.position), Vector2(am.size)) if am != null else Rect2()
			_check(am != null and am.visible and am.item_count == 9 and frame.ScreenRect().grow(1).encloses(box)
				and (box.end.x <= click.global_position.x + 1 if side == "alliance" else box.position.x >= click.global_position.x - 1),
				"%s: right-click opens the agent's menu at the click, on the frame (%s)" % [side, str(box)])
			if am != null:
				am.hide()
			click.global_position = messenger.get_global_rect().get_center()
			messenger.gui_input.emit(click)
			await process_frame
			var mm: PopupMenu = ui.get_node_or_null("MessengerPopup")
			_check(mm != null and mm.visible and mm.get_item_text(0) == "Messages" and mm.get_item_text(1) == "Message Alerts" and mm.is_item_disabled(1),
				"%s: right-click on the message droid: Messages, Message Alerts" % side)
			if mm != null:
				mm.hide()
			var left := InputEventMouseButton.new()
			left.button_index = MOUSE_BUTTON_LEFT
			left.pressed = false
			left.global_position = click.global_position
			messenger.gui_input.emit(left)
			for _i in 2:
				await process_frame
			_check(ui._openWindows.has("Communications"), "%s: left-click on the message droid opens the Message Index" % side)

		# THE CONTROL PANEL (manual p022 Fig 2.3): the consoles' monitors open
		# their finders and the Encyclopedia, with the original's tooltips and
		# their pressed pictures while held; the GID's waits for its menu.
		# CLASSIC CONTROLS hides our row of finders, nothing else.
		var cons: Dictionary = frame.Consoles()
		var consAt := cons.size() == 5 and not cons.has("gid")
		for key in cons:
			var want: Rect2 = CommandFrame.Layout[side]["consoles"][key]
			var got: Rect2 = (cons[key] as Control).get_global_rect()
			consAt = consAt and got.position.distance_to(origin + want.position * s) < 1.0 and (cons[key] as Control).tooltip_text == CommandFrame.ConsoleTips[key]
		_check(consAt, "%s: five console monitors where the frame has them, with the original's tooltips" % side)
		var opened := true
		for pair in [["system_finder", "PlanetFinder"], ["fleet_finder", "FleetFinder"], ["troop_finder", "TroopFinder"], ["personnel_finder", "PersonnelFinder"], ["encyclopedia", "Encyclopedia"]]:
			if cons.has(pair[0]):
				(cons[pair[0]] as Button).pressed.emit()
				await process_frame
				opened = opened and ui._openWindows.has(pair[1])
		_check(opened, "%s: each opens its finder, or the Encyclopedia" % side)
		if cons.has("system_finder"):
			var sf: Button = cons["system_finder"]
			var held: Control = sf.get_node_or_null("Held")
			sf.button_down.emit()
			var down: bool = held != null and held.visible
			sf.button_up.emit()
			var optHeld: Control = frame.get_node("GameOptions").get_node_or_null("Held")
			_check(down and not held.visible and optHeld != null and not optHeld.visible
				and (frame.get_node("GameOptions") as Button).tooltip_text == "Game Controls",
				"%s: a monitor shows its pressed picture while held; Game Options is 'Game Controls'" % side)
		var classic: CheckBox = ui.get_node_or_null("ClassicControls")
		var row: Control = ui.get_node("HBoxContainer")
		var wasRow: bool = row.visible
		if classic != null:
			classic.set_pressed_no_signal(true)
			GameSettings.ClassicControls = true
			ui._ShowClassic()
		var hidden: bool = not row.visible
		GameSettings.ClassicControls = false
		ui._ShowClassic()
		_check(classic != null and wasRow and hidden and row.visible and classic.get_global_rect().end.x <= row.get_global_rect().position.x + 1 + row.get_global_rect().size.x
			and classic.get_global_rect().position.x >= frame.ScreenRect().position.x,
			"%s: Classic controls hides the row of finders, and brings it back" % side)

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

		# THE ORIGINAL'S KEY (TeeJ, 2026-09-25, his screenshots of the
		# original): closed, its small button on the map's corner; open, the
		# 180-wide box where the original first opens it, then where it was
		# last dragged to; the button gone while it is open.
		var key: Control = bar.Key()
		var kl: Dictionary = key.get("Layout")[side] if key != null and key.get("Layout") != null else {}
		_check(key != null and key.name == "OriginalGidKey", "%s: the original's key replaces the plain one" % side)
		if key != null and key.name == "OriginalGidKey":
			var btn: Control = key.get_node("KeyButton")
			var box: Control = key.get_node("Key")
			_check(btn.visible and not box.visible and btn.position.is_equal_approx(origin + (kl["closed"] as Vector2) * s)
				and btn.size.is_equal_approx(Vector2(29, 23) * s) and ui.get_node_or_null("MapKeyButton") != null,
				"%s: it starts closed - its button at the map's corner, the sector column's button too (%s %s %s %s %s)" % [side,
					btn.visible, box.visible, str(btn.position), str(btn.size), ui.get_node_or_null("MapKeyButton") != null])
			key.call("Open")
			await process_frame
			var tiers: int = Gid.ActiveMode().Tiers.size()
			_check(box.visible and not btn.visible and box.position.is_equal_approx(origin + (kl["key"] as Vector2) * s)
				and box.size.is_equal_approx(Vector2(180, 20 + 20 * tiers + 35) * s)
				and (key.get("_title") as Label).text == Gid.TitleFor(Gid.ActiveMode()),
				"%s: open, where the original opens it, 180 wide, titled '%s' (%s)" % [side, Gid.TitleFor(Gid.ActiveMode()), str(box.position)])
			var moved: Vector2 = box.position + Vector2(40, 30) * s
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			box.gui_input.emit(press)
			box.global_position = moved
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			box.gui_input.emit(release)
			key.call("Close")
			await process_frame
			_check(not box.visible and btn.visible, "%s: closed again, its button back" % side)
			key.call("Open")
			await process_frame
			_check(box.position.is_equal_approx(moved), "%s: it reopens where it was left (%s)" % [side, str(box.position)])
			key.call("Close")
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
	# "Loyalty to <side>" moved from the sector column to the left-hand menu:
	# the column is whole again, the sectors in it (TeeJ, 2026-09-25).
	var column: Rect2 = (ui.get_node("TaskbarPanel") as Control).get_global_rect()
	_check(ui.GidMenu() != null and absf(column.end.y - ui.get_viewport().get_visible_rect().size.y) <= 1 and lowest <= column.end.y,
		"the sector column is whole again with the key's line in the left-hand menu (%s; lowest sector at %d)" % [str(column), int(lowest)])
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
