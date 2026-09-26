extends SceneTree
## A bombardment's results (manual p122: "After bombardment, a window will
## display the bombardment effects") are the Assault Summary's window, and its
## Conflict message opens it, as an assault's does:
##   - the original's title and sentences (TEXTSTRA.DLL 0xF778-0xF7EE),
##     aligned and non-aligned;
##   - a real bombardment the player orders pops the window up at once, and
##     the message "Orbital bombardment of <system>" carries the report;
##   - the window: the title, the sentence, the attacker's forces first; a
##     side's forces open on the defensive facilities; what the bombardment
##     destroyed is under Destroyed, what stood under Operational.
## On stand-in pictures of the original's, written and removed under user://.
##
##   .\tools\run-gd.ps1 tests/bombardment_summary.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const ArtRoot := "user://test-bombardment-summary-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[bombardment_summary] ok   %s" % what)
	else:
		_fails += 1
		print("[bombardment_summary] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot   # never the player's own
	FactionRegistry.EnsureLoaded()
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	if sets.is_empty():
		print("[bombardment_summary] (this pack declares no art set)")
		print("[bombardment_summary] 0 checks, 0 failed")
		quit(0)
		return
	_stand_ins("%s/%s" % [ArtRoot, sets[0]])
	Art.Reset()

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.LocalFaction()
	var them: Faction = FactionRegistry.Opponents(us)[0]
	_Sentences(us, them)

	# One of our fleets, over one of their worlds with facilities.
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and f.Status != Enums.Status.Enroute and not f.Ships.is_empty():
				fleet = f
	var target: Planet = null
	for p in GameState.AllPlanets():
		if target == null and p.ControllingFaction == them and p.Facilities.size() >= 3 and p.CountByRole("shield") == 0:
			target = p
	_check(fleet != null and target != null, "a fleet of ours, and an unshielded world of theirs with facilities")
	if fleet == null or target == null:
		_finish()
		return
	var facilities: int = target.Facilities.size()
	EventBus.MessageLog.clear()
	var r: BombardmentManager.BombardmentReport = BombardmentManager.Bombard(fleet, target,
		BombardmentManager.BombardmentMode.General, Prng.Session, StrategicTickManager.Today)
	_check(r.Attacker == us and r.Defender == them and r.Fleet == fleet, "the report names the sides and the fleet")
	var d := r.DefenderForces
	var listed: int = d.ManufacturingOperational.size() + d.ManufacturingDestroyed.size() + d.DefenseOperational.size() + d.DefenseDestroyed.size()
	_check(listed == facilities, "the world's %d facilities, each Operational or Destroyed" % facilities)
	var destroyed_names: Array = d.ManufacturingDestroyed + d.DefenseDestroyed + d.TroopsDestroyed + d.SquadronsDestroyed
	_check(destroyed_names.size() == r.Destroyed.size(), "Destroyed holds what the bombardment destroyed (%d)" % r.Destroyed.size())
	_check(r.AttackerForces.CapitalShipsOperational.size() + r.AttackerForces.CapitalShipsDestroyed.size() > 0, "our ships are on our page")

	var msgs: Array = Lq.where(EventBus.MessageLog, func(m: GameMessage) -> bool: return m.Report == r)
	_check(msgs.size() == 1 and (msgs[0] as GameMessage).Title == "Orbital bombardment of %s" % target.Name
			and msgs[0].Category == Enums.MessageCategory.Conflict and (msgs[0] as GameMessage).Body.begins_with(BombardmentManager.Sentence(r)),
		"the message: 'Orbital bombardment of %s', Conflict, the sentence first, carrying the report" % target.Name)

	ui.RefreshNow()
	await process_frame
	var w: BattleResultsWindow = ui.get_node_or_null("BattleResultsWindow")
	_check(w != null and w._a == r and w._bombard, "the results come up at once for the side that bombarded")
	if w == null:
		_finish()
		return
	_check(w._o != null, "in the original's look")
	var title: Label = w._oBody.get_node_or_null("Title")
	_check(title != null and title.text == "Orbital bombardment of %s" % target.Name, "titled 'Orbital bombardment of %s'" % target.Name)
	var said: Label = w._oBody.get_node_or_null("Rest")
	_check(said != null and said.text == BombardmentManager.Sentence(r), "the sentence ('%s')" % (said.text if said != null else ""))
	var scene: String = "bombardment_result" if r.HitTheGround() else "bombardment_held"
	_check(w._oPicture.texture != null and w._oPicture.texture == OUI.Pic(scene), "the scene: %s" % scene)
	_check(w._oButtons.size() == 3 and str(w._oButtons[1].name) == "battle_%s_forces" % OUI.Side(us), "the attacker's forces first")
	(w._oButtons[2] as TextureButton).pressed.emit()
	await process_frame
	var band: Label = w._oBody.get_node_or_null("Band")
	_check(w._page == 2 and band != null and band.text == "Defense Facilities", "their forces open on the defensive facilities")
	(w._oBody.get_node("Filter2") as TextureButton).pressed.emit()
	await process_frame
	band = w._oBody.get_node_or_null("Band")
	_check(band != null and band.text == "Manufacturing Facilities", "... and show the manufacturing facilities")
	ui.remove_child(w)
	w.queue_free()

	# A Death Star's Destroy System: everything on the world under Destroyed.
	var ds: PackDefs.UnitDef = MilitaryCatalog.FirstWithRole("superweapon")
	var other: Planet = null
	for p in GameState.AllPlanets():
		if other == null and p != target and p.ControllingFaction == them and p.Facilities.size() >= 3 and p.CountByRole("shield") == 0:
			other = p
	if ds != null and other != null:
		fleet.Ships.append(MilitaryCatalog.Create(ds, us, fleet.Attached))
		var had: int = other.Facilities.size()
		var r2: BombardmentManager.BombardmentReport = BombardmentManager.Bombard(fleet, other,
			BombardmentManager.BombardmentMode.DestroySystem, Prng.Session, StrategicTickManager.Today)
		var d2 := r2.DefenderForces
		_check(r2.HitTheGround() and d2.ManufacturingOperational.is_empty() and d2.DefenseOperational.is_empty()
				and d2.ManufacturingDestroyed.size() + d2.DefenseDestroyed.size() == had,
			"a system destroyed: all %d of its facilities under Destroyed" % had)
		ui.RefreshNow()
		await process_frame
		w = ui.get_node_or_null("BattleResultsWindow")
		_check(w != null and w._a == r2 and w._oPicture.texture == OUI.Pic("bombardment_result"), "... and the scorched surface")
		if w != null:
			ui.remove_child(w)
			w.queue_free()

	# The message opens it again.
	ui.OnMessageIndexClicked("Conflict")
	for _i in 3:
		await process_frame
	var mw: Control = ui._openWindows.get("Communications")
	if mw != null and mw._original:
		mw._o_show_summary(msgs[0])
		await process_frame
		w = ui.get_node_or_null("BattleResultsWindow")
		_check(w != null and w._a == r and w._bombard, "opening the message opens the bombardment's results")
	else:
		_check(false, "the Message Index opens in the original's look")
	_finish()


## TEXTSTRA.DLL 0xF79E-0xF7EE.
func _Sentences(us: Faction, them: Faction) -> void:
	var empire: Faction = us if us.Adjective == "Imperial" else them
	var alliance: Faction = them if empire == us else us
	var r := BombardmentManager.BombardmentReport.new()
	r.Target = GameState.AllPlanets()[0]
	r.Attacker = empire
	r.Defender = alliance
	var world: String = r.Target.Name
	_check(BombardmentManager.Sentence(r) == "Imperial ships have conducted an orbital strike on the Alliance system of %s" % world,
		"aligned: '%s'" % BombardmentManager.Sentence(r))
	r.Defender = null
	_check(BombardmentManager.Sentence(r) == "Imperial ships have conducted an orbital strike on the non-aligned system %s" % world,
		"non-aligned: '%s'" % BombardmentManager.Sentence(r))


func _stand_ins(dir: String) -> void:
	for sub in ["windows", "buttons", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for side in ["alliance", "empire"]:
		_png("%s/windows/battle_frame.%s.png" % [dir, side], 470, 331)
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331)
		_png("%s/windows/msgindex_selection.%s.png" % [dir, side], 380, 20)
		for w in ["battle_alert", "battle_forces", "battle_result"]:
			_png("%s/windows/%s.%s.png" % [dir, w, side], 400, 310)
		for b in ["battle_retreat", "battle_simulate", "battle_command"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 134, 27)
		for b in ["battle_close", "battle_goto"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 44, 41)
		for b in ["msgindex_summary", "msgindex_post", "msgindex_open", "msgindex_compose", "ency_close", "ency_view_index"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 40, 40)
		for t in ["battle_summary", "battle_alliance_forces", "battle_empire_forces", "battle_system"]:
			_png("%s/tabs/%s.%s.png" % [dir, t, side], 44, 41)
			_png("%s/tabs/%s.%s.pressed.png" % [dir, t, side], 44, 41)
		for t in ["ency_tab_ship", "battle_filter_fighter", "ency_tab_facilities", "ency_tab_troop", "ency_tab_personnel"]:
			_png("%s/tabs/%s.%s.png" % [dir, t, side], 49, 41)
			_png("%s/tabs/%s.%s.pressed.png" % [dir, t, side], 49, 41)
	_png("%s/tabs/ency_tab_defense.png" % dir, 49, 41)
	_png("%s/tabs/ency_tab_defense.pressed.png" % dir, 49, 41)
	for t in ["battle_table2", "battle_table3", "battle_result_none", "bombardment_result", "bombardment_held"]:
		_png("%s/windows/%s.png" % [dir, t], 400, 310)
	_png("%s/windows/msgindex_plate.png" % dir, 400, 305)
	_png("%s/windows/ency_topic_plate.png" % dir, 400, 305)
	for b in ["msgindex_select_all", "msgindex_delete", "decision_ok", "decision_cancel", "msgsummary_up", "msgsummary_down"]:
		_png("%s/buttons/%s.png" % [dir, b], 20, 20)
	for tab in MessageWindow.OTabNames:
		_png("%s/tabs/%s.png" % [dir, tab], 36, 41)
		_png("%s/tabs/%s.pressed.png" % [dir, tab], 36, 41)


func _finish() -> void:
	_remove(ArtRoot)
	Art.Reset()
	print("[bombardment_summary] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.4, 0.4))
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
