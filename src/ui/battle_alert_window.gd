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


func Setup(battle: FleetBattleManager.BattleReport) -> void:
	_battle = battle

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
	_error.text = r.error


func Redraw() -> void:
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
		Row(s.Name, "Operational   hull %d   shield %d" % [s.Hull, s.Shield])

	Head("Fighter Squadrons")
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
		Row(c.Name if c.Rank == Enums.Rank.None else "%s %s" % [JsonUtil.enum_name(Enums.Rank, c.Rank), c.Name], "Survivors")


## "System Assets" - what is on the world the battle is over. Read through the
## intel model, so an enemy system reports what we last saw of it.
func SystemSummary() -> void:
	var p: Planet = _battle.Where
	Row("Controller", p.ControllingFaction.DisplayName if p.ControllingFaction != null else "nobody")
	Row("Garrison Requirement: ", str(p.GarrisonRequirement()))
	_body.add_child(HSeparator.new())

	Head("Defense Facilities")
	Section(Enums.IntelSection.DefensiveFacilities)

	Head("Trooper Regiments")
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
