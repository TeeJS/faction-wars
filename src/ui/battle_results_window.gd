class_name BattleResultsWindow
extends PanelContainer
## frontend/BattleResultsWindow.cs - THE BATTLE RESULTS WINDOW, manual p152-p153,
## Figs 4.17 and 4.18. "This window comes up at the end of EVERY battle, EVEN IF
## YOU INSTRUCTED THE GAME TO SIMULATE THE BATTLE."
##
## THE OUTCOME SENTENCE IS COMPOSED, NOT PICKED: TEXTSTRA.DLL carries the clause
## templates at 0x0E758-0x0EB2C - a VICTORY clause, a SYSTEM-STATE clause, then a
## FORCE-DISPOSITION clause. 0x0E7B0 / 0x0E9FC give the indecisive outcome the
## manual never mentions.

var _r: FleetBattleManager.BattleReport
var _body: VBoxContainer
var _page: int = 0   # 0 = summary, 1 = ours, 2 = theirs
var _tab: int = 0    # within a force page


func Setup(report: FleetBattleManager.BattleReport) -> void:
	_r = report

	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	position = Vector2(300, 140)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.11, 0.98)
	sb.border_color = Color(0.55, 0.70, 0.95, 0.9)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)

	# "Battle location" - the title is the template `Battle at |`.
	var title := Label.new()
	title.text = "Battle at %s" % _r.Where.Name
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	left.add_child(title)

	left.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 300)
	left.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	# The five side buttons of Fig 4.17, in the figure's own order; the SHIPPED
	# strings where they differ ("Goto System").
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	root.add_child(side)

	Side(side, "Close", queue_free)
	Side(side, "Summary", func() -> void:
		_page = 0
		Redraw())
	Side(side, "%s Forces" % (_r.Ours.Faction.DisplayName if _r.Ours.Faction != null else "Our"), func() -> void:
		_page = 1
		_tab = 0
		Redraw())
	Side(side, "%s Forces" % (_r.Theirs.Faction.DisplayName if _r.Theirs.Faction != null else "Enemy"), func() -> void:
		_page = 2
		_tab = 0
		Redraw())
	Side(side, "Goto System", GotoSystem)

	Redraw()


func Side(into: VBoxContainer, text: String, onPressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 0)
	b.pressed.connect(onPressed)
	into.add_child(b)


func GotoSystem() -> void:
	# "lets you select the System window for the system where the battle took
	# place, or the Fleet window for your fleet (UNLESS IT HAS BEEN COMPLETELY
	# DESTROYED)". ⚠ Only the system half is wired.
	var ui := get_parent() as UIManager
	if ui != null:
		ui.OnPlanetClicked(_r.Where)
	queue_free()


func Redraw() -> void:
	for child in _body.get_children():
		child.queue_free()

	if _page == 0:
		Summary()
		return

	var ours: bool = _page == 1
	Forces(_r.OurLosses if ours else _r.TheirLosses, _r.Ours if ours else _r.Theirs)


## The composed outcome, clause by clause, in the original's own words.
func Summary() -> void:
	var us: String = _r.Ours.Faction.DisplayName if _r.Ours.Faction != null else "Our"
	var them: String = _r.Theirs.Faction.DisplayName if _r.Theirs.Faction != null else "Enemy"

	var lines: Array[String] = []

	if _r.DrawBothLost:
		lines.append("The battle at %s is indecisive." % _r.Where.Name)
		lines.append("There has been no victor.")
	elif _r.WeLost:
		lines.append("The %s fleet is defeated." % us)
		lines.append("The %s fleet is victorious." % them)
	else:
		lines.append("The %s fleet is victorious." % us)
		lines.append("The %s fleet is defeated." % them)

	# The system-state clause.
	var holder: Faction = BlockadeManager.BlockaderOf(_r.Where)
	if holder != null:
		lines.append("%s is now under blockade by %s forces." % [_r.Where.Name, holder.DisplayName])
	elif not _r.WeLost:
		lines.append("%s has been cleared of %s forces." % [_r.Where.Name, them])

	# The force-disposition clause.
	if _r.HeldByGravityWell:
		lines.append("A gravity well projector held the losing fleet in place. " \
			+ "It could not withdraw, and has been completely destroyed.")
	elif _r.LoserWithdrew:
		lines.append("The losing fleet has withdrawn.")

	for line in lines:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(450, 0)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
		_body.add_child(l)

	_body.add_child(HSeparator.new())

	Row("%s strength" % us, str(_r.OurStrength))
	Row("%s strength" % them, str(_r.TheirStrength))


## Fig 4.18 - four tabs, two columns. The headings change for people.
func Forces(c: FleetBattleManager.Casualties, fleet: Fleet) -> void:
	var head := Label.new()
	head.text = "%s - %s" % [fleet.Faction.DisplayName if fleet.Faction != null else "Forces", fleet.Name]
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
	_body.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)

	var names: Array[String] = ["Capital Ships", "Fighter Squadrons", "Trooper Regiments", "Personnel"]
	for i in names.size():
		var which: int = i
		var b := Button.new()
		b.text = names[i]
		b.flat = _tab != i
		b.toggle_mode = false
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func() -> void:
			_tab = which
			Redraw())
		tabs.add_child(b)

	_body.add_child(HSeparator.new())

	match _tab:
		0:
			Columns("Operational", c.CapitalShipsOperational, "Destroyed", c.CapitalShipsDestroyed)
		1:
			Columns("Operational", c.SquadronsOperational, "Destroyed", c.SquadronsDestroyed)
		2:
			# Regiments ride inside a ship's hold; a fleet that never landed them
			# has none of its own to report.
			var troops: Array = []
			for s in fleet.Ships:
				if s.Hangar != null:
					for h in s.Hangar:
						if h.Type == Enums.UnitType.Troop:
							troops.append(h.Name)
			Columns("Operational", troops, "Destroyed", [])
		_:
			Three("Survivors", c.PersonnelSurvivors, "Captured", c.PersonnelCaptured, "Killed", c.PersonnelKilled)


func Columns(leftName: String, left: Array, rightName: String, right: Array) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(HeadLabel(leftName, Color(0.55, 0.9, 0.6)))
	head.add_child(HeadLabel(rightName, Color(0.95, 0.5, 0.45)))
	_body.add_child(head)

	# "No Casualties" / "No Survivors" are the original's own empty states.
	var rows: int = maxi(maxi(left.size(), right.size()), 1)
	for i in rows:
		var l: String = left[i] if i < left.size() else ("No Survivors" if (i == 0 and left.is_empty()) else "")
		var rr: String = right[i] if i < right.size() else ("No Casualties" if (i == 0 and right.is_empty()) else "")
		Row(l, rr)


func Three(aName: String, a: Array, bName: String, b: Array, cName: String, c: Array) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(HeadLabel(aName, Color(0.55, 0.9, 0.6)))
	head.add_child(HeadLabel(bName, Color(0.95, 0.8, 0.45)))
	head.add_child(HeadLabel(cName, Color(0.95, 0.5, 0.45)))
	_body.add_child(head)

	var rows: int = maxi(maxi(a.size(), maxi(b.size(), c.size())), 1)
	for i in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(Cell(a[i] if i < a.size() else ("No Survivors" if (i == 0 and a.is_empty()) else "")))
		row.add_child(Cell(b[i] if i < b.size() else ""))
		row.add_child(Cell(c[i] if i < c.size() else ("No Casualties" if (i == 0 and c.is_empty()) else "")))
		_body.add_child(row)


## C#: private static Label Head(string, Color) - renamed so it does not
## collide with the row-heading convention of the sibling windows.
static func HeadLabel(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", colour)
	return l


static func Cell(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
	return l


func Row(left: String, right: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Cell(left))
	row.add_child(Cell(right))
	_body.add_child(row)
