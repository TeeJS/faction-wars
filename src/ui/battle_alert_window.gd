class_name BattleAlertWindow
extends PanelContainer
## frontend/BattleAlertWindow.cs - THE BATTLE ALERT, manual p021 (Fig 2.1) and
## p141 (Fig 4.1). TEXTSTRA.DLL carries its string block at 0x1D066-0x1D354.
## THREE BUTTONS mapping onto state 6 (WAIT_FOR_TYPE_CHOICE, 0x40A1E9):
## Simulate Results -> state 8, Take Command -> state 7, Retreat.
## FOUR TABS: Battle Summary, <our> Forces, <their> Forces, System Summary.

var _battle: FleetBattleManager.BattleReport
var _body: VBoxContainer
var _tabs: TabBar
var _error: Label

## THE ORIGINAL'S LOOK with the art imported (src/ui/original_battle.gd; TeeJ,
## 2026-09-23: "Conflict/Battle screen does not match"): the same four pages
## and three orders, drawn from its bitmaps.
const OB := preload("res://src/ui/original_battle.gd")
const OUI := preload("res://src/ui/original_ui.gd")
var _o: Control = null
var _oPage: int = 0
var _oButtons: Array = []
var _oBody: Control = null
var _oPicture: TextureRect = null
var _oSide: String = ""


func Setup(battle: FleetBattleManager.BattleReport) -> void:
	_battle = battle
	if OB.CanBuild():
		_BuildOriginal()
		return

	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	position = Vector2(320, 160)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.06, 0.98)
	sb.border_color = Color(0.90, 0.35, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# "Conflict at " - the string block's own opener.
	var title := Label.new()
	title.text = "Conflict at %s" % _battle.Where.Name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.80))
	root.add_child(title)

	root.add_child(HSeparator.new())

	_tabs = TabBar.new()
	_tabs.add_tab("Battle Summary")
	_tabs.add_tab("%s Forces" % (_battle.Ours.Faction.DisplayName if _battle.Ours.Faction != null else "Our"))
	_tabs.add_tab("%s Forces" % (_battle.Theirs.Faction.DisplayName if _battle.Theirs.Faction != null else "Enemy"))
	_tabs.add_tab("System Summary")
	_tabs.tab_changed.connect(func(_i: int) -> void: Redraw())
	root.add_child(_tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 260)
	root.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	_error = Label.new()
	_error.text = ""
	_error.add_theme_font_size_override("font_size", 12)
	_error.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	root.add_child(_error)

	root.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var simulate := Button.new()
	simulate.text = "Simulate Results"
	simulate.tooltip_text = "Have the computer simulate the battle and report the end results."
	simulate.pressed.connect(OnSimulate)
	buttons.add_child(simulate)

	# "Take Command: go to the game's tactical display." ⚠ WHAT THIS OPENS TODAY
	# IS THE ORIGINAL'S *OBSERVE BATTLE* MODE (manual p152): the simulation runs
	# itself and you watch it. The order system is deliberately deferred.
	var command := Button.new()
	command.text = "Take Command"
	command.tooltip_text = "Watch the battle play out. Giving orders is not built yet - " \
		+ "this is the original's Observe Battle mode."
	command.pressed.connect(OnTakeCommand)
	buttons.add_child(command)

	var retreat := Button.new()
	retreat.text = "Retreat"
	retreat.tooltip_text = "Withdraw immediately to the nearest friendly system."
	retreat.pressed.connect(OnRetreat)
	buttons.add_child(retreat)

	Redraw()


func OnSimulate() -> void:
	CommandBus.issue("battle_answer", { "where": _battle.Where.Name, "ours": _battle.Ours.Name, "theirs": _battle.Theirs.Name, "answer": "simulate" })
	queue_free()


## The tactical display, 2D top-down. The battle is the same object either way;
## this one is stepped by the view's clock instead of run out in a loop.
func OnTakeCommand() -> void:
	var sim := TacticalBattle.new(_battle.Where, _battle.Ours, _battle.Theirs, Prng.Session)

	var view := TacticalView.new()
	view.name = "TacticalView"
	get_parent().add_child(view)
	view.Setup(sim, func() -> void: FleetBattleManager.Conclude(_battle, sim, StrategicTickManager.Today))
	view.move_to_front()

	queue_free()


func OnRetreat() -> void:
	var r: Result = CommandBus.issue("battle_answer", { "where": _battle.Where.Name, "ours": _battle.Ours.Name, "theirs": _battle.Theirs.Name, "answer": "retreat" })
	if r.ok:
		queue_free()
		return
	# The gravity-well refusal. Kept in the window rather than filed as a
	# message, because the player still has a choice to make.
	if _o != null:
		_oPage = 0
		_ShowPage(0, r.error)
		return
	_error.text = r.error


func Redraw() -> void:
	if _o != null:
		_ShowPage(_oPage)
		return
	for child in _body.get_children():
		child.queue_free()

	match _tabs.current_tab:
		0: BattleSummary()
		1: Forces(_battle.Ours)
		2: Forces(_battle.Theirs)
		_: SystemSummary()


func BattleSummary() -> void:
	Row("%s" % _battle.Ours.Name, "strength %d" % _battle.OurStrength)
	Row("%s" % _battle.Theirs.Name, "strength %d" % _battle.TheirStrength)
	_body.add_child(HSeparator.new())

	if FleetBattleManager.EnemyHoldsThemHere(_battle.Enemy(GameSettings.LocalFaction())):
		var warn := Label.new()
		warn.text = "A gravity well projector is holding us here.\n" \
			+ "We cannot withdraw from this battle."
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_body.add_child(warn)

	var note := Label.new()
	note.text = "Simulating resolves the engagement on total strength. The losing " \
		+ "fleet withdraws to the nearest system its side holds, unless a " \
		+ "gravity well is holding it - in which case it is destroyed where " \
		+ "it stands."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(430, 0)
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	_body.add_child(note)


## "Capital Ships" / "Fighter Squadrons" - the string block's own headings,
## and "Operational" for what is still flying.
func Forces(fleet: Fleet) -> void:
	Head("Capital Ships")
	var ships: Array = Lq.where(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	if ships.is_empty():
		Row("None", "")
	for s in ships:
		Row(s.Name, "Operational   %s %d   %s %d" % [Terms.lower("hull"), s.Hull, Terms.lower("shield"), s.Shield])

	Head(Terms.label("fighter_squadrons"))
	var fighters: Array = []
	for s in fleet.Ships:
		if s.Hangar != null:
			for h in s.Hangar:
				if h.Type == Enums.UnitType.Fighter:
					fighters.append(h)
	fighters.append_array(Lq.where(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.Fighter))
	if fighters.is_empty():
		Row("None", "")
	for f in fighters:
		Row(f.Name, "Operational")

	Head("Personnel")
	var aboard: Array = Lq.where(GameState.ActiveRoster,
		func(c: Character) -> bool: return c.Attached == fleet and c.Status != Enums.Status.Dead)
	if aboard.is_empty():
		Row("None", "")
	for c in aboard:
		Row(c.TitledName(), "Survivors")


## "System Assets" - what is on the world the battle is over. Read through the
## intel model, so an enemy system reports what we last saw of it.
func SystemSummary() -> void:
	var p: Planet = _battle.Where
	Row("Controller", p.ControllingFaction.DisplayName if p.ControllingFaction != null else "nobody")
	Row("Garrison Requirement: ", str(p.GarrisonRequirement()))
	_body.add_child(HSeparator.new())

	Head("Defense Facilities")
	Section(Enums.IntelSection.DefensiveFacilities)

	Head(Terms.label("trooper_regiments"))
	Section(Enums.IntelSection.Troopers)


func Section(section: int) -> void:
	var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, _battle.Where, section)
	if not view.Known:
		Row("Sensors detect no data.", "")
		return
	if view.Lines.is_empty():
		Row("None seen.", "")
		return
	for line in view.Lines:
		Row(line, "")


func Head(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90))
	_body.add_child(h)


func Row(left: String, right: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var a := Label.new()
	a.text = left
	a.custom_minimum_size = Vector2(230, 0)
	a.add_theme_font_size_override("font_size", 12)
	a.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	row.add_child(a)

	var b := Label.new()
	b.text = right
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(0.68, 0.74, 0.85))
	row.add_child(b)

	_body.add_child(row)


# ---- the original's look ------------------------------------------------------

func _BuildOriginal() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_oSide = OUI.Side(GameSettings.LocalFaction())
	_o = OB.Canvas(self)
	_oPicture = OUI.Place(_o, null, OB.PictureAt.x, OB.PictureAt.y, "Picture")
	OUI.Place(_o, OUI.Pic("battle_frame.%s" % _oSide), 0, 0, "Frame")
	_oBody = Control.new()
	_oBody.name = "Page"
	_oBody.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_o.add_child(_oBody)
	# The column (Fig. 4.1): Battle Summary, Alliance Forces, Imperial Forces,
	# System Summary - the original's order, by side, not ours-then-theirs.
	var stems: Array = ["battle_summary", "battle_alliance_forces", "battle_empire_forces", "battle_system"]
	var tips: Array = ["Battle Summary", "%s Forces" % _SideName("alliance"), "%s Forces" % _SideName("empire"), "System Summary"]
	_oButtons.clear()
	for i in stems.size():
		var b := OB.PageButton(_o, stems[i], _oSide, OB.ColumnX, OB.AlertYs[i], tips[i])
		var page := i
		b.pressed.connect(func() -> void:
			_oPage = page
			_ShowPage(page))
		_oButtons.append(b)
	# Retreat, Simulate Results, Take Command (Fig. 4.1).
	var retreat := OB.Button3(_o, "battle_retreat.%s" % _oSide, OB.BottomXs[0], OB.BottomY,
		"Retreat: withdraw immediately to the nearest friendly system.")
	retreat.pressed.connect(OnRetreat)
	retreat.disabled = FleetBattleManager.EnemyHoldsThemHere(_battle.Enemy(GameSettings.LocalFaction()))
	OB.Button3(_o, "battle_simulate.%s" % _oSide, OB.BottomXs[1], OB.BottomY,
		"Simulate Results: have the computer simulate the battle and report the outcome.").pressed.connect(OnSimulate)
	OB.Button3(_o, "battle_command.%s" % _oSide, OB.BottomXs[2], OB.BottomY,
		"Take Command: watch the battle play out (the original's Observe Battle; giving orders is not built yet).").pressed.connect(OnTakeCommand)
	OB.Centre(self)
	_ShowPage(0)


## The fleet on the given side's page: the one whose faction wears that side's
## look, else (a pack whose sides share one) ours / theirs in order.
func _FleetOf(skin: String) -> Fleet:
	for f in [_battle.Ours, _battle.Theirs]:
		if f != null and OUI.Side(f.Faction) == skin:
			return f
	return _battle.Ours if skin == "alliance" else _battle.Theirs


func _SideName(skin: String) -> String:
	var f: Fleet = _FleetOf(skin)
	return f.Faction.DisplayName if f != null and f.Faction != null else skin.capitalize()


func _ShowPage(page: int, refusal: String = "") -> void:
	OB.SetCurrent(_oButtons, page)
	for c in _oBody.get_children():
		_oBody.remove_child(c)
		c.queue_free()
	var colour: Color = OUI.SideColor(GameSettings.LocalFaction())
	var pic: Texture2D = OUI.Pic(("battle_alert.%s" if page == 0 else "battle_forces.%s") % _oSide)
	_oPicture.texture = pic
	_oPicture.size = pic.get_size() if pic != null else Vector2.ZERO
	# "Battle at <system>" - the original's words (TEXTSTRA).
	OB.Line(_oBody, "Battle at %s" % _battle.Where.Name, OB.TitleCentre - 190, 20, 380, OB.TitlePx, colour,
		HORIZONTAL_ALIGNMENT_CENTER, false, "Title")
	match page:
		0:
			var text: String = refusal if not refusal.is_empty() else _Situation()
			if refusal.is_empty() and FleetBattleManager.EnemyHoldsThemHere(_battle.Enemy(GameSettings.LocalFaction())):
				text += " A gravity well projector is holding us here: we cannot withdraw."
			OB.Block(_oBody, text, OB.TextAt, OB.TextW, OB.TextPx, 18, colour, "Situation")
		1, 2:
			var fleet: Fleet = _FleetOf("alliance" if page == 1 else "empire")
			OB.Line(_oBody, "%s Forces" % _SideName("alliance" if page == 1 else "empire"), OB.PageCentre - 190, 44, 380,
				OB.TitlePx, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "PageName")
			OB.List(_oBody, OB.FleetRows(fleet) if fleet != null else [], _oSide)
		_:
			# "System Assets" - the page's heading on TeeJ's screenshot.
			OB.Line(_oBody, "System Assets", OB.PageCentre - 190, 44, 380, OB.TitlePx, Color.WHITE,
				HORIZONTAL_ALIGNMENT_CENTER, false, "PageName")
			OB.List(_oBody, OB.SystemRows(_battle.Where), _oSide)


## The situation in the original's own sentences (TEXTSTRA's alert block),
## by who moved in (the report's Arriving - the later arrival) and whose world
## it is, as the manual shows them:
##   they moved in on our world - "The Imperial fleet is threatening <world>.
##     Alliance forces are moving to intercept." (p021 Fig. 2.1);
##   we moved in on theirs - "The Alliance fleet has entered the Coruscant
##     system. Imperial forces have been detected on an intercept course."
##     (p141 Fig. 4.1: "move a fleet to Coruscant");
##   a side moved in on its own world, the other's fleet there - "The Alliance
##     fleet is attempting to break the Imperial blockade at Chandrila."
##     (TeeJ's screenshot);
##   otherwise - "<a> and <b> forces are about to engage in battle near the
##     <world> system."
func _Situation() -> String:
	var world: String = _battle.Where.Name
	var arriving: Fleet = _battle.Arriving
	var owner: Faction = _battle.Where.ControllingFaction
	if arriving != null:
		var other: Fleet = _battle.Theirs if arriving == _battle.Ours else _battle.Ours
		var a: String = BattleResultsWindow.Adj(arriving)
		var o: String = BattleResultsWindow.Adj(other)
		if owner == arriving.Faction:
			return "The %s fleet is attempting to break the %s blockade at %s." % [a, o, world]
		if other != null and owner == other.Faction:
			if arriving.Faction == GameSettings.LocalFaction():
				return "The %s fleet has entered the %s system. %s forces have been detected on an intercept course." % [a, world, o]
			return "The %s fleet is threatening %s. %s forces are moving to intercept." % [a, world, o]
	return "%s and %s forces are about to engage in battle near the %s system." \
		% [BattleResultsWindow.Adj(_battle.Ours), BattleResultsWindow.Adj(_battle.Theirs), world]
