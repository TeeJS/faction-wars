extends SceneTree
## The Assault Summary (manual p123, Figs 3.66-3.67) is the Battle Results
## window (TeeJ, 2026-09-26: "it's what already appears [after a] lost
## battle"), and a Conflict message opens it ("if there is a conflict message
## in the messages tab, it opens the actual assault/battle screen"):
##   - an assault the player orders pops the window up at once; each human
##     side gets "Assault on <system>" under Conflict, carrying the report;
##   - the original's sentences (TEXTSTRA.DLL), captured, held, neutral;
##   - the window: "Assault on <system>", the sentence, the column's close at
##     y 21, Summary and the two sides' forces (the attacker's first), Goto
##     System; a side's forces open on the troops, six tabs from x 30;
##   - the regiments as the contest left them, the world's facilities by kind;
##   - opening the message in the Message Index opens the window again, and a
##     battle's message opens the battle's.
## On stand-in pictures of the original's, written and removed under user://.
##
##   .\tools\run-gd.ps1 tests/assault_summary.gd

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const ArtRoot := "user://test-assault-summary-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[assault_summary] ok   %s" % what)
	else:
		_fails += 1
		print("[assault_summary] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot   # never the player's own
	FactionRegistry.EnsureLoaded()
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	if sets.is_empty():
		print("[assault_summary] (this pack declares no art set)")
		print("[assault_summary] 0 checks, 0 failed")
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

	# One of our fleets carrying a regiment, and one of their worlds with a garrison.
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and f.Status != Enums.Status.Enroute and not AssaultManager.LandingForce(f).is_empty():
				fleet = f
	var target: Planet = null
	for p in GameState.AllPlanets():
		if target == null and p.ControllingFaction == them and Lq.any(p.Garrison, func(u): return u.Type == Enums.UnitType.Troop):
			target = p
	_check(fleet != null and target != null, "a fleet of ours with a regiment aboard, and a world of theirs with a garrison")
	if fleet == null or target == null:
		_finish()
		return
	var landing: int = AssaultManager.LandingForce(fleet).size()
	var holding: int = Lq.where(target.Garrison, func(u): return u.Type == Enums.UnitType.Troop).size()
	var facilities: int = target.Facilities.size()
	EventBus.MessageLog.clear()

	var r: AssaultManager.AssaultReport = AssaultManager.Resolve(fleet, target, Prng.Session, StrategicTickManager.Today)
	_check(r.Attacker == us and r.Defender == them and r.Fleet == fleet, "the report names the sides and the fleet")
	var a := r.AttackerForces
	var d := r.DefenderForces
	_check(a.TroopsOperational.size() + a.TroopsDestroyed.size() == landing and a.TroopsDestroyed.size() == r.AttackerLost.size(),
		"our regiments: %d landed, %d lost" % [landing, a.TroopsDestroyed.size()])
	_check(d.TroopsOperational.size() + d.TroopsDestroyed.size() == holding and d.TroopsDestroyed.size() == r.DefenderLost.size(),
		"their regiments: %d held it, %d lost" % [holding, d.TroopsDestroyed.size()])
	_check(d.ManufacturingOperational.size() + d.ManufacturingDestroyed.size() + d.DefenseOperational.size() + d.DefenseDestroyed.size() == facilities,
		"the world's %d facilities, manufacturing or defensive" % facilities)
	_check(a.CapitalShipsOperational.size() > 0 and a.CapitalShipsDestroyed.is_empty(), "our ships in orbit, all operational")

	var ours: Array = Lq.where(EventBus.MessageLog, func(m: GameMessage) -> bool: return m.For == us)
	_check(ours.size() == 1 and (ours[0] as GameMessage).Title == "Assault on %s" % target.Name
			and ours[0].Category == Enums.MessageCategory.Conflict and ours[0].Report == r,
		"our message: 'Assault on %s', a Conflict message carrying the report" % target.Name)

	# The window pops up for the side that ordered it.
	ui.RefreshNow()
	await process_frame
	var w: BattleResultsWindow = ui.get_node_or_null("BattleResultsWindow")
	_check(w != null and w._a == r, "the Assault Summary comes up at once")
	if w == null:
		_finish()
		return
	_check(w._o != null, "in the original's look")
	var title: Label = w._oBody.get_node_or_null("Title")
	_check(title != null and title.text == "Assault on %s" % target.Name, "titled 'Assault on %s'" % target.Name)
	var said: Label = w._oBody.get_node_or_null("Rest")
	_check(said != null and said.text == AssaultManager.Sentence(r), "the sentence ('%s')" % (said.text if said != null else ""))
	_check(said != null and said.get_theme_color("font_shadow_color") == Color.BLACK, "... with its black shadow")
	var close: TextureButton = null
	for c in w._o.get_children():
		if c is TextureButton and (c as TextureButton).tooltip_text == "Close":
			close = c
	_check(close != null and is_equal_approx(close.position.y, 21 * OUI.K), "the close box at y 21")
	var skin: String = OUI.Side(us)
	_check(w._oButtons.size() == 3 and str(w._oButtons[1].name) == "battle_%s_forces" % skin,
		"Summary, then the attacker's forces (%s), then the other's" % skin)

	# Our forces: the troops tab, six tabs, no Filters.
	(w._oButtons[1] as TextureButton).pressed.emit()
	await process_frame
	_check(w._page == 1 and w._tab == BattleResultsWindow.AssaultTroopsTab, "our forces open on the troops")
	var band: Label = w._oBody.get_node_or_null("Band")
	_check(band != null and band.text == Terms.label("trooper_regiments"), "the band: '%s'" % (band.text if band != null else ""))
	var tabs: int = 0
	for i in 8:
		if w._oBody.get_node_or_null("Filter%d" % i) != null:
			tabs += 1
	_check(tabs == 6 and w._oBody.get_node_or_null("Filters") == null, "six tabs, no 'Filters'")
	var fourth: Control = w._oBody.get_node_or_null("Filter3")
	_check(fourth != null and is_equal_approx(fourth.position.x, (30 + 3 * 62) * OUI.K), "the tabs from x 30, 62 apart")
	# Their forces, the defensive facilities.
	(w._oButtons[2] as TextureButton).pressed.emit()
	await process_frame
	(w._oBody.get_node("Filter3") as TextureButton).pressed.emit()
	await process_frame
	band = w._oBody.get_node_or_null("Band")
	_check(w._page == 2 and band != null and band.text == "Defense Facilities", "their defensive facilities")
	var page_name: Label = w._oBody.get_node_or_null("PageName")
	_check(page_name != null and page_name.text == "%s Forces" % them.Adjective, "named '%s Forces'" % them.Adjective)
	ui.remove_child(w)
	w.queue_free()

	# The message opens it again, from the Message Index.
	ui.OnMessageIndexClicked("Conflict")
	for _i in 3:
		await process_frame
	var mw: Control = ui._openWindows.get("Communications")
	_check(mw != null and mw._original, "the Message Index opens in the original's look")
	if mw != null and mw._original:
		(ours[0] as GameMessage).IsRead = false
		mw._o_show_summary(ours[0])
		await process_frame
		w = ui.get_node_or_null("BattleResultsWindow")
		_check(w != null and w._a == r, "opening the message opens the Assault Summary")
		_check(mw._oIndex.visible and not mw._oSummary.visible and ours[0].IsRead, "... the index stays, the message read")
		if w != null:
			ui.remove_child(w)
			w.queue_free()

		# A battle's message opens the battle's window.
		var b := FleetBattleManager.BattleReport.new()
		b.Where = target
		b.Ours = fleet
		b.Theirs = fleet
		var m := GameMessage.new("Battle at %s" % target.Name, "", Enums.MessageCategory.Conflict, StrategicTickManager.Today, target)
		m.Report = b
		EventBus.Tell(us, m)
		mw._o_show_summary(m)
		await process_frame
		w = ui.get_node_or_null("BattleResultsWindow")
		_check(w != null and w._r == b and w._a == null, "a battle's message opens the Battle Results")
		var other := GameMessage.new("Plain", "Read me.", Enums.MessageCategory.Conflict, StrategicTickManager.Today)
		EventBus.Tell(us, other)
		mw._o_show_summary(other)
		_check(mw._oSummary.visible, "a message without a report still reads as a message")
	_finish()


## TEXTSTRA.DLL 0xF67E-0xF76E, the first as TeeJ's screenshot has it.
func _Sentences(us: Faction, them: Faction) -> void:
	var empire: Faction = us if us.Adjective == "Imperial" else them
	var alliance: Faction = them if empire == us else us
	var r := AssaultManager.AssaultReport.new()
	r.Target = GameState.AllPlanets()[0]
	var world: String = r.Target.Name
	r.Attacker = empire
	r.Defender = alliance
	r.Captured = true
	_check(AssaultManager.Sentence(r) == "Imperial troops have taken control of the Alliance system %s" % world, "captured: '%s'" % AssaultManager.Sentence(r))
	r.Captured = false
	_check(AssaultManager.Sentence(r) == "Alliance Troops have defended %s from an Imperial assault." % world, "held: '%s'" % AssaultManager.Sentence(r))
	r.Defender = null
	r.Captured = true
	_check(AssaultManager.Sentence(r) == "Imperial troops have seized control of the neutral system %s" % world, "neutral taken: '%s'" % AssaultManager.Sentence(r))
	r.Captured = false
	_check(AssaultManager.Sentence(r) == "The neutral system %s has repulsed an attack by Imperial troops." % world, "neutral held: '%s'" % AssaultManager.Sentence(r))


func _stand_ins(dir: String) -> void:
	for sub in ["windows", "buttons", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for side in ["alliance", "empire"]:
		_png("%s/windows/battle_frame.%s.png" % [dir, side], 470, 331)
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331)
		_png("%s/windows/msgindex_selection.%s.png" % [dir, side], 380, 20)
		_png("%s/windows/assault_captured.%s.png" % [dir, side], 400, 310)
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
	for t in ["battle_table2", "battle_table3", "battle_result_none", "assault_repulsed"]:
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
	print("[assault_summary] %d checks, %d failed" % [_checks, _fails])
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
