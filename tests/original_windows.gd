extends SceneTree
## The original's windows, rebuilt from the imported art (src/ui/original_ui.gd;
## TeeJ, 2026-09-23: "match the UI of the original"). Opens the System
## Defenses, Manufacturing and Galactic Encyclopedia windows and the Message
## Index column over the project's own imported art and checks each piece is
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

	# ---- the Message Index column ----
	ui.RefreshCommsHighlights()
	var list: VBoxContainer = ui.get_node("CommsPanel/Margin/CommsList")
	var allBtn: Button = list.get_node("All")
	_check(allBtn.icon != null and allBtn.icon.get_size() == Vector2(54, 54), "All Messages is the galaxy socket at 1.5x")
	var sockets: int = Lq.count(list.get_children(), func(b) -> bool: return b is Button and b.icon != null)
	_check(sockets == 10, "all ten categories are sockets (%d)" % sockets)

	print("[original_windows] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
