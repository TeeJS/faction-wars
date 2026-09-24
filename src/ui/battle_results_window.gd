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

## THE ORIGINAL'S LOOK with the art imported (src/ui/original_battle.gd): the
## Encyclopedia's frame, a scene, the title and the outcome; the column's close
## box, the summary, the two sides' forces and Goto System. Its forces pages
## are PROVISIONAL: no screenshot shows the original's (Fig. 4.18 is too
## small to measure) - the tables are its pictures, the rest ours.
const OB := preload("res://src/ui/original_battle.gd")
const OUI := preload("res://src/ui/original_ui.gd")
var _o: Control = null
var _oBody: Control = null
var _oPicture: TextureRect = null
var _oButtons: Array = []
var _oSide: String = ""


func Setup(report: FleetBattleManager.BattleReport) -> void:
	_r = report
	if OB.CanBuild() and OUI.Pic("frame.%s" % OUI.Side(GameSettings.LocalFaction())) != null:
		_BuildOriginal()
		return

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
	var local: Faction = GameSettings.LocalFaction()
	Side(side, "%s Forces" % (_r.Mine(local).Faction.DisplayName if _r.Mine(local).Faction != null else "Our"), func() -> void:
		_page = 1
		_tab = 0
		Redraw())
	Side(side, "%s Forces" % (_r.Enemy(local).Faction.DisplayName if _r.Enemy(local).Faction != null else "Enemy"), func() -> void:
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
	if _o != null:
		_ShowPage()
		return
	for child in _body.get_children():
		child.queue_free()

	if _page == 0:
		Summary()
		return

	var ours: bool = _page == 1
	var v: Faction = GameSettings.LocalFaction()
	Forces(_r.MyLosses(v) if ours else _r.EnemyLosses(v), _r.Mine(v) if ours else _r.Enemy(v))


## The composed outcome, clause by clause, in the original's own words.
func Summary() -> void:
	var viewer: Faction = GameSettings.LocalFaction()
	var mine: Fleet = _r.Mine(viewer)
	var enemy: Fleet = _r.Enemy(viewer)
	var us: String = mine.Faction.DisplayName if mine.Faction != null else "Our"
	var them: String = enemy.Faction.DisplayName if enemy.Faction != null else "Enemy"
	var lines: Array[String] = OutcomeLines(_r, viewer)

	for line in lines:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(450, 0)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
		_body.add_child(l)

	_body.add_child(HSeparator.new())

	Row("%s strength" % us, str(_r.MyStrength(viewer)))
	Row("%s strength" % them, str(_r.EnemyStrength(viewer)))


## The composed outcome, clause by clause, in the original's own words: the
## victory clause first (the original's large line), then the system and the
## forces.
static func OutcomeLines(_r: FleetBattleManager.BattleReport, viewer: Faction) -> Array[String]:
	var mine: Fleet = _r.Mine(viewer)
	var enemy: Fleet = _r.Enemy(viewer)
	var us: String = mine.Faction.DisplayName if mine.Faction != null else "Our"
	var them: String = enemy.Faction.DisplayName if enemy.Faction != null else "Enemy"
	var we_lost: bool = _r.Lost(viewer)

	var lines: Array[String] = []

	if _r.DrawBothLost:
		lines.append("The battle at %s is indecisive." % _r.Where.Name)
		lines.append("There has been no victor.")
	elif we_lost:
		lines.append("The %s fleet is defeated." % us)
		lines.append("The %s fleet is victorious." % them)
	else:
		lines.append("The %s fleet is victorious." % us)
		lines.append("The %s fleet is defeated." % them)

	# The system-state clause.
	var holder: Faction = BlockadeManager.BlockaderOf(_r.Where)
	if holder != null:
		lines.append("%s is now under blockade by %s forces." % [_r.Where.Name, holder.DisplayName])
	elif not we_lost:
		lines.append("%s has been cleared of %s forces." % [_r.Where.Name, them])

	# The force-disposition clause.
	if _r.HeldByGravityWell:
		lines.append("A gravity well projector held the losing fleet in place. " \
			+ "It could not withdraw, and has been completely destroyed.")
	elif _r.LoserWithdrew:
		lines.append("The losing fleet has withdrawn.")
	return lines


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

	var names: Array[String] = ["Capital Ships", Terms.label("fighter_squadrons"), Terms.label("trooper_regiments"), "Personnel"]
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


# ---- the original's look ------------------------------------------------------

func _BuildOriginal() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewer: Faction = GameSettings.LocalFaction()
	_oSide = OUI.Side(viewer)
	_o = OB.Canvas(self)
	_oPicture = OUI.Place(_o, null, OB.PictureAt.x, OB.PictureAt.y, "Picture")
	OUI.Place(_o, OUI.Pic("frame.%s" % _oSide), 0, 0, "Frame")
	_oBody = Control.new()
	_oBody.name = "Page"
	_oBody.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_o.add_child(_oBody)
	# The column (TeeJ's screenshot): close, the summary, the Alliance's and
	# the Empire's forces, Goto System.
	OB.Button3(_o, "battle_close.%s" % _oSide, OB.ColumnX, OB.ResultYs[0], "Close").pressed.connect(queue_free)
	var stems: Array = ["battle_summary", "battle_alliance_forces", "battle_empire_forces"]
	var tips: Array = ["Summary", "%s Forces" % _SideName("alliance"), "%s Forces" % _SideName("empire")]
	_oButtons.clear()
	for i in stems.size():
		var b := OB.PageButton(_o, stems[i], _oSide, OB.ColumnX, OB.ResultYs[i + 1], tips[i])
		var page := i
		b.pressed.connect(func() -> void:
			_page = page
			_tab = 0
			_ShowPage())
		_oButtons.append(b)
	OB.Button3(_o, "battle_goto.%s" % _oSide, OB.ColumnX, OB.ResultYs[4], "Goto System").pressed.connect(GotoSystem)
	OB.Centre(self)
	_ShowPage()


func _FleetOf(skin: String) -> Fleet:
	for f in [_r.Ours, _r.Theirs]:
		if f != null and OUI.Side(f.Faction) == skin:
			return f
	return _r.Ours if skin == "alliance" else _r.Theirs


func _SideName(skin: String) -> String:
	var f: Fleet = _FleetOf(skin)
	return f.Faction.DisplayName if f != null and f.Faction != null else skin.capitalize()


## The scene: the side the viewer fought (TeeJ's Imperial victory over an
## Alliance attack shows the Alliance's, 10757), burning where that fleet was
## destroyed, an empty system when both were lost. INFERRED from one
## screenshot and the pictures' content.
func _Scene() -> Texture2D:
	if _r.DrawBothLost:
		return OUI.Pic("battle_result_none")
	var viewer: Faction = GameSettings.LocalFaction()
	var enemy: Fleet = _r.Enemy(viewer)
	var side: String = OUI.Side(enemy.Faction) if enemy != null else "alliance"
	var gone: bool = not _r.Lost(viewer) and (_r.HeldByGravityWell or not _r.LoserWithdrew)
	var pic: Texture2D = OUI.Pic(("battle_result_burning.%s" if gone else "battle_result.%s") % side)
	return pic if pic != null else OUI.Pic("battle_result.%s" % side)


func _ShowPage() -> void:
	OB.SetCurrent(_oButtons, _page)
	for c in _oBody.get_children():
		_oBody.remove_child(c)
		c.queue_free()
	var viewer: Faction = GameSettings.LocalFaction()
	var colour: Color = OUI.SideColor(viewer)
	var pic: Texture2D = _Scene() if _page == 0 else OUI.Pic("battle_table%d" % (3 if _tab == 3 else 2))
	_oPicture.texture = pic
	_oPicture.size = pic.get_size() if pic != null else Vector2.ZERO
	OB.Line(_oBody, "Battle at %s" % _r.Where.Name, OB.ResultTitleCentre - 190, 22, 380, OB.TitlePx, colour,
		HORIZONTAL_ALIGNMENT_CENTER, false, "Title")
	if _page == 0:
		var lines: Array[String] = OutcomeLines(_r, viewer)
		OB.Line(_oBody, lines[0] if not lines.is_empty() else "", OB.OutcomeCentre - 200, OB.OutcomeY, 400, OB.OutcomePx, colour,
			HORIZONTAL_ALIGNMENT_CENTER, false, "Outcome")
		OB.Block(_oBody, " ".join(lines.slice(1)), OB.RestAt, 390, OB.TextPx, 18, colour, "Rest")
		return
	# A side's forces (Fig. 4.18) - PROVISIONAL, see the header.
	var skin: String = "alliance" if _page == 1 else "empire"
	var fleet: Fleet = _FleetOf(skin)
	var losses: FleetBattleManager.Casualties = _r.MyLosses(viewer) if fleet == _r.Mine(viewer) else _r.EnemyLosses(viewer)
	OB.Line(_oBody, "%s Forces" % _SideName(skin), OB.ResultTitleCentre - 190, 44, 380, 13, Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, false, "PageName")
	var names: Array = ["Capital Ships", Terms.label("fighter_squadrons"), Terms.label("trooper_regiments"), "Personnel"]
	for i in names.size():
		var tab := Button.new()
		tab.name = "Filter%d" % i
		tab.text = names[i]
		tab.flat = true
		tab.focus_mode = Control.FOCUS_NONE
		OUI.Style(tab, 10, colour if i == _tab else Color(0.7, 0.7, 0.7), i == _tab)
		tab.position = Vector2(36 + i * 90, 64) * OUI.K
		tab.size = Vector2(88, 16) * OUI.K
		var which := i
		tab.pressed.connect(func() -> void:
			_tab = which
			_ShowPage())
		_oBody.add_child(tab)
	OB.Line(_oBody, names[_tab], 40, 102, 300, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true, "Band")
	var columns: Array = []
	match _tab:
		0:
			columns = [["Operational", losses.CapitalShipsOperational], ["Destroyed", losses.CapitalShipsDestroyed]]
		1:
			columns = [["Operational", losses.SquadronsOperational], ["Destroyed", losses.SquadronsDestroyed]]
		2:
			var troops: Array = []
			if fleet != null:
				for s in fleet.Ships:
					if s.Hangar != null:
						for h in s.Hangar:
							if h.Type == Enums.UnitType.Troop:
								troops.append(h.Name)
			columns = [["Operational", troops], ["Destroyed", []]]
		_:
			columns = [["Survivors", losses.PersonnelSurvivors], ["Captured", losses.PersonnelCaptured], ["Killed", losses.PersonnelKilled]]
	# The table's columns (measured on its pictures): 24-191-374, or
	# 24-136-247-374; the heads from y 105, the rows from 121 to 290.
	var edges: Array = [24, 191, 374] if columns.size() == 2 else [24, 136, 247, 374]
	for i in columns.size():
		var x0: float = edges[i] + OB.PictureAt.x
		var w: float = edges[i + 1] - edges[i]
		OB.Line(_oBody, columns[i][0], x0, 105 + OB.PictureAt.y + 3, w, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Head%d" % i)
		var items: Array = columns[i][1]
		var shown: int = mini(items.size(), 10)
		for j in shown:
			OB.Line(_oBody, str(items[j]), x0 + 4, 121 + OB.PictureAt.y + 4 + j * 16, w - 8, 11, Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, false, "Cell%d_%d" % [i, j])
		if items.size() > shown:
			OB.Line(_oBody, "... and %d more" % (items.size() - shown), x0 + 4, 121 + OB.PictureAt.y + 4 + shown * 16, w - 8, 11,
				Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_LEFT, false, "More%d" % i)
