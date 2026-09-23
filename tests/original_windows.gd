extends SceneTree
## The original's windows, rebuilt from the imported art (src/ui/original_ui.gd;
## TeeJ, 2026-09-23: "match the UI of the original"). Opens the System
## Defenses, Manufacturing, Galactic Encyclopedia and Create Mission windows
## and the Message Index column over the project's own imported art and checks each piece is
## where the template matching on the original's screenshots put it. Skips
## (passes) when the art is not imported.
##
##   .\tools\run-gd.ps1 tests/original_windows.gd                      (Alliance)
##   .\tools\run-gd.ps1 tests/original_windows.gd -- --faction=empire  (Empire)

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const K := 2

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_windows] ok   %s" % what)
	else:
		_fails += 1
		print("[original_windows] FAIL %s" % what)


func _status_window(ui: UIManager) -> Control:
	for k in ui._openWindows:
		var w: Variant = ui._openWindows[k]
		if str(k).begins_with("Status_") and is_instance_valid(w) and not (w as Node).is_queued_for_deletion():
			return w
	return null


func _cards(node: Node) -> Array:
	var out: Array = []
	if node.has_meta("card") and node is Control:
		out.append(node)
	for c in node.get_children():
		out.append_array(_cards(c))
	return out


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	if Art.WindowPicture("defense_background") == null:
		print("[original_windows] skipped: the original's art is not imported")
		print("[original_windows] 0 checks, 0 failed")
		quit(0)
		return
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var side: Color = OUI.SideColor(us)
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and not p.Facilities.is_empty() \
			and Lq.any(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached == p and not c.IsOffMap()))
	_check(home != null, "%s holds a world with facilities and people on it" % us.Id)

	# ---- System Defenses ----
	ui.OnDefenseClicked(home)
	for _i in 4:
		await process_frame
	var dw: DefenseWindow = ui._openWindows.get(home.Name + " Defenses")
	_check(dw != null and dw._original, "the Defenses window is the original's")
	_check((dw.get_node("%TitleBar") as ColorRect).color == side, "its title bar is the side's colour")
	_check((dw.get_node("%TitleBarLabel") as Label).text == home.Name, "titled with the system's name alone")
	var plate: TextureRect = dw.find_child("Plate", true, false)
	_check(plate != null and plate.texture.get_size() == Vector2(235, 304) * K, "the 235x304 plate")
	var dtabs: TabContainer = dw.get_node("%DefenseTabs")
	var strip: Array = dtabs.get_meta("tab_strip", [])
	_check(strip.size() == 5, "five tab pictures")
	var xs: Array = []
	for b in strip:
		xs.append(int(b.position.x / K))
	_check(xs == [28, 64, 100, 136, 172] and int(strip[0].position.y / K) == 20, "tab pictures at the original's positions %s" % str(xs))
	var plist: Node = dw.get_node("%PersonnelList")
	_check(plist.has_meta("cards"), "Personnel is a grid of cards")
	var ours: int = Lq.count(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap() and c.Attached == home and c.Status != Enums.Status.Enroute)
	var cards: Array = Lq.where(plist.get_children(), func(n) -> bool: return n.has_meta("card"))
	_check(cards.size() >= ours and ours > 0, "one card per person on %s (%d cards, %d ours)" % [home.Name, cards.size(), ours])
	if not cards.is_empty():
		var c0: Control = cards[0]
		_check(c0.custom_minimum_size == Vector2(70, 70) * K, "a card is 70x70")
		var pic: TextureRect = c0.get_node_or_null("Picture")
		_check(pic == null or pic.texture.get_size() == Vector2(61, 25) * K, "its picture is the 61x25 miniature")
		var nm: Label = c0.get_node_or_null("Name")
		_check(nm != null and not nm.text.is_empty() and int(nm.position.y / K) == 29, "the name under the picture")
		(c0 as BaseButton).button_pressed = true
		var fr: ReferenceRect = c0.get_node_or_null("Frame")
		_check(fr != null and fr.visible and fr.position == Vector2.ZERO and fr.size == Vector2(61, 25) * K,
			"picked: the frame on the picture's own outline, inside the grid")
	var cap: Label = plist.get_parent().get_parent().get_node_or_null("Caption1")
	_check(cap != null and cap.text == "Personnel", "the page's caption")
	var greyed: int = 0
	for i in dtabs.get_tab_count():
		if dtabs.is_tab_disabled(i):
			greyed += 1
			_check(strip[i].disabled, "an empty tab's picture is greyed and unpickable (%s)" % strip[i].tooltip_text)
	dtabs.current_tab = 1
	for _i in 2:
		await process_frame
	var troopsCap: Label = dtabs.get_node("Troops").find_child("Caption1", true, false)
	_check(troopsCap != null and troopsCap.text == "Trooper Regiments", "Troops page: the original's caption")
	var garrison: Label = dtabs.get_node("Troops").find_child("Caption2", true, false)
	_check(garrison != null and garrison.text == "Garrison Requirement: %d" % home.GarrisonRequirement(), "Troops page: the garrison requirement line")
	dw.CloseWindow()

	# ---- Manufacturing and Production ----
	ui.OnEconomyClicked(home)
	for _i in 4:
		await process_frame
	var ew: EconomyWindow = ui._openWindows.get(home.Name + " Economy")
	_check(ew != null and ew._original, "the Manufacturing window is the original's")
	var eplate: TextureRect = ew.find_child("Plate", true, false)
	_check(eplate != null and eplate.texture.get_size() == Vector2(226, 304) * K, "the 226x304 plate")
	var etabs: TabContainer = ew.get_node("%EconomyTabs")
	var estrip: Array = etabs.get_meta("tab_strip", [])
	var exs: Array = []
	for b in estrip:
		exs.append(int(b.position.x / K))
	_check(exs == [0, 39, 77, 115, 152, 190], "six tab pictures at the original's positions %s" % str(exs))
	var mfg: Control = ew.find_child("OriginalManufacturing", true, false)
	_check(mfg != null, "the Manufacturing page is laid out as the original's")
	if mfg != null:
		var col: TextureRect = mfg.get_node_or_null("Column")
		_check(col != null and col.position == Vector2(6, 18) * K and col.texture.get_size() == Vector2(46, 226) * K, "the left column at (6, 18)")
		for i in 3:
			var row: TextureRect = mfg.get_node_or_null("Row%d" % i)
			_check(row != null and row.position == Vector2(55, [4, 85, 166][i]) * K, "row frame %d at the original's place" % i)
		var q: Label = ew.get_node("%ShipQueueLabel")
		_check(q.get_parent() == mfg and q.position == Vector2(59, 20) * K, "the ship queue line in its frame")
		if home.ShipyardQueue.is_empty():
			_check(q.text == "No Ships are being built", "an idle queue in the original's words")
		var head: Label = mfg.get_node_or_null("HeaderText0")
		_check(head != null and head.text == "Ship Construction", "the row header")
	# A facility page whose last row is short: every card still on the grid.
	var shortRow: Array = []
	for i in etabs.get_tab_count():
		var fcards: Array = _cards(etabs.get_child(i))
		if fcards.size() > 3 and fcards.size() % 3 != 0:
			etabs.current_tab = i
			shortRow = fcards
			break
	for _i in 2:
		await process_frame
	if not shortRow.is_empty():
		var onGrid: bool = Lq.all(shortRow, func(c: Control) -> bool:
			return c.size == Vector2(70, 70) * K and int(c.position.x) % (70 * K) == 0 and int(c.position.y) % (70 * K) == 0)
		_check(onGrid, "%d facility cards on the 70-pixel grid, the short row too, none stretched" % shortRow.size())
	var shipyards: int = Lq.count(home.Facilities, func(f: Facility) -> bool: return f.HasRole("produces_unit"))
	_check(etabs.is_tab_disabled(1) == (shipyards == 0) and estrip[1].disabled == (shipyards == 0), "the Shipyards picture greyed exactly when there are none")
	ew.CloseWindow()

	# ---- the Galactic Encyclopedia ----
	ui.OpenEncyclopedia()
	for _i in 4:
		await process_frame
	var enc: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	_check(enc != null and enc._original, "the Encyclopedia is the original's")
	var frame: TextureRect = enc.find_child("Frame", true, false)
	_check(frame != null and frame.texture.get_size() == Vector2(470, 331) * K, "in the side's 470x331 frame")
	var iplate: TextureRect = enc._indexView.get_node_or_null("Plate")
	_check(iplate != null and iplate.position == Vector2(12, 13) * K, "the Index plate at (12, 13)")
	_check(enc._tabs.size() == 7, "seven database tabs")
	var ch: PackDefs.CharacterDef = FactionRegistry.Pack.Characters[0]
	enc.ShowTopic("characters", ch.Id)
	for _i in 2:
		await process_frame
	_check(enc._topicView.visible and not enc._indexView.visible, "Topic view")
	var tex: Texture2D = (enc._picture as TextureRect).texture
	_check(tex == null or tex.get_size() == Vector2(400, 200) * K, "the picture at 400x200, drawn 2x")
	_check((enc._picture as Control).position == Vector2(12, 31) * K, "the picture at (12, 31)")
	_check(enc._topicTitle.text == ch.DisplayName, "the topic's name on the band")
	_check(enc._viewTopicBtn.texture_normal == enc._viewTopicBtn.get_meta("pressed_tex"), "View Topic lit in Topic view")
	enc.CloseWindow()

	# ---- Create Mission (p042 Fig 2.34, p103 Fig 3.47, p104 Fig 3.48) ----
	var recruit: int = Enums.MissionType.Recruitment
	var team: Array = []
	var world: Planet = null
	for c in GameState.ActiveRoster:
		if c.Faction != us or c.IsOffMap():
			continue
		var at: Planet = OrderManager.SystemOf(c.Attached)
		if at != null and MissionManager.TeamCanPerform([c], recruit) and MissionManager.CanTarget(recruit, us, at).ok:
			team = [c]
			world = at
			break
	_check(world != null, "somebody of ours may recruit where they stand")
	if world != null:
		ui.OnDefenseClicked(world)
		for _i in 3:
			await process_frame
		var host: DraggableWindow = ui._openWindows.get(world.Name + " Defenses")
		host.OpenCreateMission(team, world, world)
		for _i in 3:
			await process_frame
		var cm: Control = ui._openWindows.get("Create Mission")
		_check(cm != null and cm.get("_canvas") != null, "Create Mission is the original's window")
		if cm != null and cm.get("_canvas") != null:
			_check(cm.size == Vector2(259, 355) * K, "the 259x355 plate is the window (%s)" % str(cm.size / K))
			_check((cm.get_node("%TitleBar") as ColorRect).color == side and not (cm.get_node("%MinimizeButton") as Control).visible,
				"a title bar in the side's colour with only the close box")
			_check(cm.has_meta("modal_blocker") and is_instance_valid(cm.get_meta("modal_blocker")) and cm.CloseOnEscape, "modal, like the dialog it replaces; Esc closes it")
			_check(cm._tabs[0].position == Vector2(7, 20) * K and cm._tabs[1].position == Vector2(137, 20) * K, "the two tabs at (7, 20) and (137, 20)")
			var places: Array = []
			for n in ["mission_encyclopedia", "mission_ok", "mission_cancel"]:
				var b: TextureButton = cm.find_child(n, true, false)
				places.append(b.position / K if b != null and b.size == Vector2(64, 32) * K else null)
			_check(places == [Vector2(33, 320), Vector2(102, 320), Vector2(170, 320)], "Encyclopedia, assign and cancel, 64x32, at the original's places %s" % str(places))
			_check(cm._name.text == MissionCatalog.DisplayNameFor(cm._legal[0]), "the first mission's name")
			_check(cm._picture.position == Vector2(70, 86) * K and cm._picture.texture != null
				and cm._picture.texture.get_size() == Vector2(130, 65) * K, "its 130x65 picture at (70, 86)")
			var tpic: TextureRect = cm.find_child("TargetPicture", true, false)
			_check(tpic != null and tpic.texture != null and tpic.position == Vector2(115, 232) * K, "the system's sprite in the Target box")
			var tname: Label = cm.find_child("TargetName", true, false)
			_check(tname != null and tname.text == world.Name, "the target's name")
			(cm.find_child("mission_list_open", true, false) as TextureButton).pressed.emit()
			_check(cm._list.visible and cm._listRows.size() == cm._legal.size(), "the arrow drops down the %d missions" % cm._legal.size())
			(cm._listRows[cm._legal.find(recruit)] as Button).pressed.emit()
			_check(not cm._list.visible and cm._name.text == MissionCatalog.DisplayNameFor(recruit), "picking Recruitment shows it")
			(cm._tabs[1] as TextureButton).pressed.emit()
			var decoyPlate: Texture2D = (cm.get_theme_stylebox("panel") as StyleBoxTexture).texture
			_check(cm._pages[1].visible and not cm._pages[0].visible and decoyPlate.get_size() == Vector2(259, 355) * K,
				"the Decoy tab, on its own plate")
			_check(cm._columns[0].get_child_count() == team.size() and cm._columns[1].get_child_count() == 0, "the team in the agents column")
			(cm.find_child("mission_ok", true, false) as TextureButton).pressed.emit()
			for _i in 3:
				await process_frame
			_check(ui._openWindows.get("Create Mission") == null and ui.get_node_or_null("ModalBlocker") == null, "assign closes it, and its blocker goes too")
			_check(team[0].Status == Enums.Status.OnMission or team[0].Status == Enums.Status.Enroute,
				"%s is sent (status %s)" % [team[0].Name, Enums.Status.keys()[team[0].Status]])
		host.CloseWindow()

	# ---- Status windows (manual p064: modal, no title bar, the diamond closes) ----
	var regiment: Unit = null
	for p in GameState.AllPlanets():
		for u in p.Garrison:
			if regiment == null and u.Faction == us and u.Type == Enums.UnitType.Troop and not u.PackId.is_empty():
				regiment = u
	_check(regiment != null, "a trooper regiment of ours")
	if regiment != null:
		ui.OpenUnitStatusWindow(regiment)
		for _i in 3:
			await process_frame
		var sw: Control = _status_window(ui)
		_check(sw != null and sw.find_child("StatusCanvas", true, false) != null, "a regiment's Status window is the original's")
		if sw != null and sw.find_child("StatusCanvas", true, false) != null:
			_check(sw.size == Vector2(379, 272) * K and not (sw.get_node("%TitleBar") as Control).visible, "the 379x272 plate, no title bar (%s)" % str(sw.size / K))
			_check(sw.has_meta("modal_blocker") and sw.CloseOnEscape, "modal; Esc closes it")
			var title: Label = sw.find_child("Title", true, false)
			_check(title != null and title.text == "Trooper Regiment Status", "titled as the original: %s" % (title.text if title != null else "?"))
			var l0: Label = sw.find_child("Label0", true, false)
			var v0: Label = sw.find_child("Value0", true, false)
			_check(l0 != null and l0.text == "Attached:" and l0.position == Vector2(18, 47) * K and v0.position == Vector2(121, 47) * K,
				"the first field at (18, 47), its value at (121, 47)")
			var l5: Label = sw.find_child("Label5", true, false)
			_check(l5 != null and l5.text == "Bombardment Value:", "the original's \"Bombardment Value:\" (%s)" % (l5.text if l5 != null else "?"))
			var v1: Label = sw.find_child("Value1", true, false)
			_check(v1 != null and v1.text == "Awaiting Orders", "the status in the original's words (%s)" % (v1.text if v1 != null else "?"))
			var pic: TextureRect = sw.find_child("Picture", true, false)
			var back: TextureRect = sw.find_child("Backdrop", true, false)
			_check(pic != null and pic.position == Vector2(246, 39) * K and back != null and back.position == Vector2(246, 39) * K,
				"the regiment's picture over its spotlight at (246, 39)")
			var nm: Label = sw.find_child("Name", true, false)
			_check(nm != null and nm.text == regiment.Name and nm.position == Vector2(242, 137) * K, "its name under the picture")
			var encBtn: TextureButton = sw.find_child("status_encyclopedia", true, false)
			var shut: TextureButton = sw.find_child("ency_close_alliance", true, false)
			_check(encBtn != null and encBtn.position == Vector2(258, 218) * K and shut != null and shut.position == Vector2(324, 218) * K,
				"the Encyclopedia button and the diamond at (258, 218) and (324, 218)")
			shut.pressed.emit()
			for _i in 2:
				await process_frame
			_check(_status_window(ui) == null and ui.get_node_or_null("ModalBlocker") == null, "the diamond closes it")
	# The Facilities Under Construction queue's Status window (Fig 3.29).
	ui.OpenQueueStatusWindow(home, "produces_facility")
	for _i in 3:
		await process_frame
	var qw: Control = _status_window(ui)
	_check(qw != null and qw.find_child("StatusCanvas", true, false) != null, "the queue's Status window exists, as the original's")
	if qw != null and qw.find_child("StatusCanvas", true, false) != null:
		var qt: Label = qw.find_child("Title", true, false)
		_check(qt.text == "Facilities Under Construction", "titled Facilities Under Construction")
		var q3: Label = qw.find_child("Label3", true, false)
		var qv3: Label = qw.find_child("Value3", true, false)
		_check(q3 != null and q3.text == "Estimated Day of Completion:" and qv3.position == Vector2(121, 103) * K,
			"Estimated Day of Completion wraps, its value on the second line at (121, 103)")
		var qp: TextureRect = qw.find_child("Picture", true, false)
		_check(qp != null and qp.position == Vector2(244, 20) * K, "the queue's 126x88 picture at (244, 20)")
		(qw.find_child("ency_close_alliance", true, false) as TextureButton).pressed.emit()
		for _i in 2:
			await process_frame

	# ---- the Message Index (manual p078 Fig 3.18) ----
	EventBus.BroadcastMessage(GameMessage.new("A test of the index", "It reads in the same frame.", Enums.MessageCategory.Conflict))
	ui.OnMessageIndexClicked("All")
	for _i in 4:
		await process_frame
	var mw: Node = ui._openWindows.get("Communications")
	_check(mw != null and mw._original, "the Comms Center is the original's Message Index")
	if mw != null and mw._original:
		_check(mw.size == Vector2(470, 330) * K, "the 470x330 frame (%s)" % str(mw.size / K))
		var txs: Array = []
		for t in mw._oTabs:
			txs.append(int(t.position.x / K))
		_check(txs == [22, 60, 98, 136, 173, 211, 249, 285, 323, 360] and int(mw._oTabs[0].position.y / K) == 46,
			"ten category tabs at the original's places %s" % str(txs))
		_check(mw._oCaption.text == "All Messages" and mw._oCaption.position == Vector2(35, 90) * K, "the band names the tab")
		var sa: TextureButton = mw.find_child("msgindex_select_all", true, false)
		var dl: TextureButton = mw.find_child("msgindex_delete", true, false)
		_check(sa != null and sa.position == Vector2(282, 87) * K and dl != null and dl.position == Vector2(340, 87) * K,
			"Select All and Delete on the band at (282, 87) and (340, 87)")
		var sx: int = 426 if us.Id == "empire" else 423
		var sys: Array = [21, 89, 148, 207, 266] if us.Id == "empire" else [25, 93, 147, 201, 255]
		var sideNames: Array = ["ency_close_%s", "msgindex_summary_%s", "msgindex_post_%s", "msgindex_open_%s", "msgindex_compose_%s"]
		var sidePlaces: Array = []
		for i in sideNames.size():
			var sb: TextureButton = mw.find_child(sideNames[i] % us.Id, true, false)
			sidePlaces.append(sb.position / K if sb != null else null)
		_check(sidePlaces == [Vector2(sx, sys[0]), Vector2(sx, sys[1]), Vector2(sx, sys[2]), Vector2(sx, sys[3]), Vector2(sx, sys[4])],
			"the five side buttons at the original's places")
		var rows: Array = mw._oRows.get_children()
		_check(not rows.is_empty() and (rows[0] as Control).custom_minimum_size.y == 21 * K, "rows 21 pixels apart (%d rows)" % rows.size())
		var target: GameMessage = Lq.first_or_null(MessageWindow.MessagesFor("All"), func(m: GameMessage) -> bool: return m.Title == "A test of the index")
		mw._o_pick(target, false, false)
		for _i in 2:
			await process_frame
		var picked: Control = null
		for r in mw._oRows.get_children():
			var t: Label = r.get_node_or_null("Title")
			if t != null and t.text == "A test of the index":
				picked = r
		_check(picked != null and picked.get_node_or_null("Bar") != null, "a picked row carries the side's bar")
		(mw.find_child("msgindex_summary_%s" % us.Id, true, false) as TextureButton).pressed.emit()
		for _i in 2:
			await process_frame
		_check(mw._oSummary.visible and not mw._oIndex.visible and mw._oSumTitle.text == "A test of the index" and target.IsRead,
			"Message Summary reads it in the same frame, and marks it read")
		(mw.find_child("msgindex_summary_%s" % us.Id, true, false) as TextureButton).pressed.emit()
		for _i in 2:
			await process_frame
		_check(mw._oIndex.visible, "and brings the index back")
		(mw.find_child("ency_close_%s" % us.Id, true, false) as TextureButton).pressed.emit()
		for _i in 3:
			await process_frame

	# ---- the Message Index column ----
	ui.RefreshCommsHighlights()
	var list: VBoxContainer = ui.get_node("CommsPanel/Margin/CommsList")
	var allBtn: Button = list.get_node("All")
	_check(allBtn.icon != null and allBtn.icon.get_size() == Vector2(54, 54), "All Messages is the galaxy socket at 1.5x")
	var sockets: int = Lq.count(list.get_children(), func(b) -> bool: return b is Button and b.icon != null)
	_check(sockets == 10, "all ten categories are sockets (%d)" % sockets)

	print("[original_windows] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
