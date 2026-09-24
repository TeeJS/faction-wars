extends SceneTree
## The original's Mission window (manual p109, Figs 3.50 and 3.51;
## src/ui/original_mission_window.gd): opens in place of the plain one only
## when the art set holds its parts, titles itself "Mission at <system>",
## lists each of the player's missions there as an icon in its column, shows
## the picked one's target and team, splits agents from decoys on its two
## tabs, puts hyperspace streaks behind a team in transit, and offers
## Encyclopedia, Status and Abort on a right-click - Abort greyed in
## hyperspace. Writes and removes its own test art, never the player's own.
##
##   .\tools\run-gd.ps1 tests/original_mission_window.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_mission_window] ok   %s" % what)
	else:
		_fails += 1
		print("[original_mission_window] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
	Art.UserArtRoot = "user://test-original-mission"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var side: String = us.ArtSkin
	CommandBus.Immediate = true

	# A Diplomacy team of two, one a decoy, sent to a world away from home.
	var team: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap() and c.Attached is Planet).slice(0, 2)
	var dip: int = Enums.MissionType.Diplomacy
	var from: Planet = team[0].Attached
	var far: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p != from and p.IsExplored and MissionManager.CanTarget(dip, us, p).ok and from.DeploymentDaysTo(p) > 0)
	_check(team.size() == 2 and far != null, "a team of two and a world to send it to")
	var m: Mission = MissionManager.Launch(dip, team, from, far, [team[1]])
	_check(m != null and not m.Arrived(), "the Diplomacy mission is launched and in hyperspace")

	# Without the parts: the plain window.
	Art.Reset()
	ui.OnMissionClicked(far)
	for _i in 3:
		await process_frame
	var w: DraggableWindow = ui._openWindows.get(far.Name + " Missions")
	_check(w is MissionWindow, "without the art the plain Mission window opens")
	if w != null:
		w.CloseWindow()
		for _i in 2:
			await process_frame

	# The parts, as plain test pictures where an imported art set lives.
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "tabs", "buttons", "missions", "miniatures/characters"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/windows/mission_window.png" % dir, 235, 304, Color(0.3, 0.3, 0.35))
	for s in ["alliance", "empire"]:
		_png("%s/windows/mission_frame.%s.png" % [dir, s], 73, 48, Color(0, 1, 0))
		for t in ["mission_agents_tab", "mission_decoys_tab"]:
			_png("%s/tabs/%s.%s.png" % [dir, t, s], 61, 16, Color(0.4, 0.4, 0.4))
			_png("%s/tabs/%s.%s.pressed.png" % [dir, t, s], 61, 16, Color(0.6, 0.6, 0.6))
	for b in ["title_system", "title_minimize", "title_close"]:
		_png("%s/buttons/%s.png" % [dir, b], 14, 14, Color(0.8, 0.8, 0.8))
	_png("%s/windows/card_plate.png" % dir, 61, 25, Color(0.5, 0.5, 0.5))
	_png("%s/windows/card_enroute.png" % dir, 61, 25, Color(0.1, 0.1, 0.3))
	if far.ArtworkId > 0:
		DirAccess.make_dir_recursive_absolute("%s/planet_sprites" % dir)
		_png("%s/planet_sprites/%d.png" % [dir, far.ArtworkId], 37, 37, Color(0.5, 0.5, 0.9))
	var d: PackDefs.MissionDefPack = MissionCatalog.DefFor(dip)
	_png("%s/missions/%s.%s.tile.png" % [dir, d.Id, side], 73, 48, Color(0.7, 0.2, 0.2))
	Art.Reset()
	_check(ui.OriginalMissionScript.CanBuild(), "with the parts the original window can be built")

	ui.OnMissionClicked(far)
	for _i in 3:
		await process_frame
	w = ui._openWindows.get(far.Name + " Missions")
	_check(w != null and w.has_method("_show_picked"), "with the art the original Mission window opens")
	if w == null or not w.has_method("_show_picked"):
		_finish()
		return
	_check((w.get_node("%TitleBarLabel") as Label).text == "Mission at %s" % far.Name, "titled 'Mission at %s', the original's words" % far.Name)
	_check(w.size == Vector2(235, 304) * 2, "the window is the plate, drawn twice as large")
	var tiles: Array = w._column.get_children()
	_check(tiles.size() == 1, "one mission running there, one icon in the column")
	if tiles.size() == 1:
		var tile: Control = tiles[0]
		_check((tile.get_node("Picture") as TextureRect).texture != null, "the icon shows the mission's picture")
		_check((tile.get_node("Name") as Label).text == m.DisplayName(), "the mission's name is over its picture")
		_check((tile.get_node("Frame") as Control).visible, "the mission on show is framed in the side's colour")
	_check(w._targetName.text == far.Name, "the target's name is shown")
	_check(w._targetPicture.texture != null or far.ArtworkId <= 0, "the target's picture is shown")

	# The Agents tab: the agent, on hyperspace streaks while in transit.
	var names: Array = Lq.select(w._panel.get_children(), func(c: Control) -> String: return (c.get_node("Name") as Label).text)
	_check(names == [team[0].Name], "the Agents tab lists the agent only (%s)" % str(names))
	var member: Control = w._panel.get_child(0) if w._panel.get_child_count() > 0 else null
	var plate: TextureRect = member.get_node_or_null("Plate") if member != null else null
	_check(plate != null and plate.texture == Art.Scaled(Art.WindowPicture("card_enroute"), 2),
		"the team is in hyperspace: starfield streaks behind the picture (Fig 3.51)")

	# The Decoys tab.
	(w._tabs[1] as TextureButton).pressed.emit()
	for _i in 2:
		await process_frame
	names = Lq.select(w._panel.get_children(), func(c: Control) -> String: return (c.get_node("Name") as Label).text)
	_check(names == [team[1].Name], "the Decoys tab lists the decoy only (%s)" % str(names))
	_check((w._tabs[1] as TextureButton).texture_normal == w._tabs[1].get_meta("current"), "the Decoys tab shows as current")

	# Right-click: Fig 3.50's menu, Abort greyed in hyperspace.
	w._orders(m, Vector2(300, 300))
	var popup: PopupMenu = Lq.first_or_null(w.get_children(), func(c: Node) -> bool: return c is PopupMenu)
	_check(popup != null and popup.item_count == 3, "right-click offers three orders")
	if popup != null and popup.item_count == 3:
		_check(popup.get_item_text(0) == "Encyclopedia" and popup.get_item_text(1) == "Status", "Encyclopedia and Status, as in Fig 3.50")
		_check(popup.get_item_text(2).begins_with("Abort") and popup.is_item_disabled(2), "Abort is greyed while the team is in hyperspace")
		popup.hide()

	# Arrived: Abort is live and calls the mission off.
	m.DaysToTarget = 0
	w._orders(m, Vector2(300, 300))
	var popups: Array = Lq.where(w.get_children(), func(c: Node) -> bool: return c is PopupMenu)
	popup = popups.back() if not popups.is_empty() else null
	_check(popup != null and not popup.is_item_disabled(2), "on station, Abort can be given")
	if popup != null:
		popup.hide()
	w._on_order(2, m)
	for _i in 2:
		await process_frame
	_check(m.Finished and w._column.get_child_count() == 0, "Abort calls the mission off and its icon leaves the column")
	_finish()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[original_mission_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


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
