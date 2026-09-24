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
## box, the summary, the two sides' forces and Goto System; the forces pages
## as TeeJ's screenshots of the original's have them (2026-09-24).
const OB := preload("res://src/ui/original_battle.gd")
const OUI := preload("res://src/ui/original_ui.gd")
const Art := preload("res://src/ui/artwork.gd")
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
##
## As TeeJ's screenshots of the original have it (2026-09-24): ONE victory
## clause, the viewer's ("The Imperial fleet is victorious." - never the other
## side's defeat after it), the system's, then the loser's fleet: "Imperial
## forces have maintained the blockade of Chandrila. The Alliance fleet has
## withdrawn." / "Chandrila is now under blockade by Imperial forces. The
## Alliance fleet has been completely destroyed." The sides by their
## `adjective` ("Imperial", "Alliance").
static func OutcomeLines(_r: FleetBattleManager.BattleReport, viewer: Faction) -> Array[String]:
	var mine: Fleet = _r.Mine(viewer)
	var enemy: Fleet = _r.Enemy(viewer)
	var world: String = _r.Where.Name
	var lines: Array[String] = []
	if _r.DrawBothLost:
		lines.append("The battle at %s is indecisive." % world)
		return lines
	var we_lost: bool = _r.Lost(viewer)
	lines.append(("The %s fleet is defeated." if we_lost else "The %s fleet is victorious.") % Adj(mine))
	var winner: Fleet = enemy if we_lost else mine
	var loser: Fleet = mine if we_lost else enemy

	# The system's clause. A side that moved in on its own world was breaking
	# the other's blockade of it.
	var arriving: Fleet = _r.Arriving
	var owner: Faction = _r.Where.ControllingFaction
	if arriving != null and owner == arriving.Faction:
		var holder_fleet: Fleet = _r.Theirs if arriving == _r.Ours else _r.Ours
		if arriving == winner:
			lines.append("%s forces have broken the blockade of %s." % [Adj(arriving), world])
		else:
			lines.append("%s forces have maintained the blockade of %s." % [Adj(holder_fleet), world])
	else:
		var holder: Faction = BlockadeManager.BlockaderOf(_r.Where)
		if holder != null:
			lines.append("%s is now under blockade by %s forces." % [world, holder.Adjective])
		elif owner != null and winner != null and owner == winner.Faction:
			lines.append("%s has been successfully defended from %s forces." % [world, Adj(loser)])
		else:
			lines.append("%s has been cleared of %s forces." % [world, Adj(loser)])

	# The loser's fleet.
	if _r.LoserWithdrew and not _r.HeldByGravityWell:
		lines.append("The %s fleet has withdrawn." % Adj(loser))
	else:
		lines.append("The %s fleet has been completely destroyed." % Adj(loser))
	return lines


## A fleet's side as the sentences name it.
static func Adj(f: Fleet) -> String:
	return f.Faction.Adjective if f != null and f.Faction != null and not f.Faction.Adjective.is_empty() else "Enemy"


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
	# A side's forces (Fig. 4.18), as TeeJ's eight screenshots of the original's
	# have it (2026-09-24): the side's name in its colour under the title;
	# "Filters" and the four tabs (capital ships, fighters, troops, personnel -
	# the viewer's side's pictures); the table (two columns, three for
	# personnel) with the filter's name on its band and the columns' heads; in
	# each column the units' pictures - burning where damaged - with their
	# names under them, or "None" / "No Survivors" / "No Casualties".
	var skin: String = "alliance" if _page == 1 else "empire"
	var fleet: Fleet = _FleetOf(skin)
	var losses: FleetBattleManager.Casualties = _r.MyLosses(viewer) if fleet == _r.Mine(viewer) else _r.EnemyLosses(viewer)
	var side_colour: Color = OUI.SideColor(fleet.Faction) if fleet != null else Color.WHITE
	OB.Line(_oBody, "%s Forces" % BattleResultsWindow.Adj(fleet), 211 - 150, 43, 300, 15.5, side_colour,
		HORIZONTAL_ALIGNMENT_CENTER, false, "PageName")
	OB.Line(_oBody, "Filters", 22, 74, 100, 12.5, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, false, "Filters")
	var stems: Array = ["ency_tab_ship", "battle_filter_fighter", "ency_tab_troop", "ency_tab_personnel"]
	var names: Array = ["Capital Ships", Terms.label("fighter_squadrons"), Terms.label("trooper_regiments"), "Personnel"]
	for i in stems.size():
		var tab := TextureButton.new()
		tab.name = "Filter%d" % i
		tab.texture_normal = OUI.Tab(stems[i], _oSide, "pressed" if i == _tab else "")
		tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tab.position = Vector2(FilterX + i * FilterPitch, FilterY) * OUI.K
		tab.size = tab.texture_normal.get_size() if tab.texture_normal != null else Vector2(49, 41) * OUI.K
		tab.tooltip_text = names[i]
		var which := i
		tab.pressed.connect(func() -> void:
			_tab = which
			_ShowPage())
		_oBody.add_child(tab)
	OB.Line(_oBody, names[_tab], 38, 102, 300, 12.5, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "Band")
	var columns: Array = []   # [head, texts, who, empty text]
	match _tab:
		0:
			columns = [["Operational", "CapitalShipsOperational"], ["Destroyed", "CapitalShipsDestroyed"]]
		1:
			columns = [["Operational", "SquadronsOperational"], ["Destroyed", "SquadronsDestroyed"]]
		2:
			columns = [["Operational", "TroopsOperational"], ["Destroyed", "TroopsDestroyed"]]
		_:
			columns = [["Survivors", "PersonnelSurvivors"], ["Captured", "PersonnelCaptured"], ["Killed", "PersonnelKilled"]]
	# What each column holds: {name, picture, flames}. Fire means DAMAGED -
	# a survivor that was hit (manual p153: "burn marks indicate they are
	# damaged"; TeeJ, 2026-09-24: "fire means damaged, not destroyed").
	var lists: Array = []
	for col in columns:
		var items: Array = []
		var texts: Array = losses.get(col[1]) if losses != null else []
		var who: Array = losses.Who.get(col[1], []) if losses != null else []
		for j in texts.size():
			var w: Dictionary = who[j] if j < who.size() else {}
			var burning: bool = bool(w.get("damaged", false))
			items.append({"name": _PlainName(str(texts[j])), "picture": _Picture(w),
				"flames": _Flames(w) if burning else null})
		lists.append(items)
	var edges: Array = Table2 if columns.size() == 2 else Table3
	var rows: int = 0
	for items in lists:
		rows = maxi(rows, items.size())
	var clip := Control.new()
	clip.name = "Rows"
	clip.clip_contents = true
	clip.position = Vector2(edges[0], BodyTop) * OUI.K
	clip.size = Vector2(edges[edges.size() - 1] - edges[0], BodyBottom - BodyTop) * OUI.K
	clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_oBody.add_child(clip)
	var inner := Control.new()
	inner.name = "Inner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(inner)
	for i in columns.size():
		var centre: float = (edges[i] + edges[i + 1]) / 2.0
		OB.Line(_oBody, columns[i][0], centre - 60, HeadCap, 120, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false, "Head%d" % i)
		var items: Array = lists[i]
		if items.is_empty():
			OB.Line(_oBody, _EmptyText(i, columns.size(), lists), centre - 70, EmptyCap, 140, 15, Color.WHITE,
				HORIZONTAL_ALIGNMENT_CENTER, false, "Empty%d" % i)
			continue
		for j in items.size():
			var it: Dictionary = items[j]
			var img: Texture2D = it.get("picture")
			var small: bool = img != null and img.get_height() < 40
			var top: float = (MiniTop if small else PictureTop) + j * (MiniPitch if small else PicturePitch) - BodyTop
			var flames: Texture2D = it.get("flames")
			if flames != null:
				OUI.Place(inner, Art.Scaled(flames, OUI.K), centre - edges[0] - flames.get_width() / 2.0, top, "Flames%d_%d" % [i, j])
			if img != null:
				OUI.Place(inner, Art.Scaled(img, OUI.K), centre - edges[0] - img.get_width() / 2.0, top, "Picture%d_%d" % [i, j])
			var name_top: float = top + (img.get_height() if img != null else 0) + NameGap
			OB.Line(inner, str(it.get("name", "")), centre - edges[0] - 70, name_top, 140, 9.5, Color.WHITE,
				HORIZONTAL_ALIGNMENT_CENTER, false, "Name%d_%d" % [i, j])
	# The scroll bar inside the table's right edge when a column runs over (two
	# pictures show whole, the third cut off: TeeJ's three Star Destroyers).
	var pitch: float = PicturePitch
	var shown: int = int((BodyBottom - BodyTop) / pitch)
	if rows > shown:
		var bar := OUI.ScrollBar12.new()
		bar.name = "ScrollBar"
		bar.k = OUI.K
		bar.parts = [OUI.Btn("scroll_up"), OUI.Btn("scroll_down"), OUI.Btn("scroll_thumb_top"), OUI.Btn("scroll_thumb_mid"), OUI.Btn("scroll_thumb_bottom")]
		bar.position = Vector2(edges[edges.size() - 1], BodyTop) * OUI.K
		bar.size = Vector2(OUI.ScrollBar12.W - 1, BodyBottom - BodyTop) * OUI.K
		_oBody.add_child(bar)
		bar.set_rows(0, shown, rows)
		bar.scrolled.connect(func(first: int) -> void:
			inner.position.y = -first * pitch * OUI.K)
		clip.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				if e.button_index == MOUSE_BUTTON_WHEEL_UP:
					bar.step(-1)
				elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					bar.step(1))


## The results' forces pages, in the frame's pixels (TeeJ's screenshots): the
## "Filters" (Arial 12.5, right edge 122, capitals from 74), its tabs from
## (130, 59), 49 apart; the table's columns (their right
## edge 13 short of the table's, where the scroll bar goes); the heads
## (Arial 12) from y 122; a unit's 122x50 picture from y 146 and every 70, a person's 61x25
## from y 148; the name 3 under the picture; an empty column's words from 150.
const FilterX := 130
const FilterPitch := 49
const FilterY := 59
const Table2 := [36, 203, 373]
const Table3 := [36, 148, 259, 373]
const HeadCap := 122
const BodyTop := 131
const BodyBottom := 299
const PictureTop := 146
const PicturePitch := 70
const MiniTop := 148
const MiniPitch := 40   # INFERRED: one person on TeeJ's screenshot
const NameGap := 3
const EmptyCap := 150


## A column's words when it holds no one (TeeJ's screenshots): the losses
## columns "No Casualties"; the first, "No Survivors" when the others hold
## someone, else "None"; the rest "None".
static func _EmptyText(i: int, count: int, lists: Array) -> String:
	if i == count - 1:
		return "No Casualties"
	if i == 0:
		for k in range(1, lists.size()):
			if not (lists[k] as Array).is_empty():
				return "No Survivors"
	return "None"


## An entry's picture: a unit's 122x50, a person's miniature.
static func _Picture(w: Dictionary) -> Texture2D:
	var id: String = str(w.get("id", ""))
	if id.is_empty():
		return null
	if str(w.get("kind", "")) == "characters":
		return Art.Miniature("characters", id)
	return Art.Portrait("units", id)


## The flames drawn under a damaged craft's picture (as the Status window
## draws them; TeeJ's screenshot: a damaged TIE).
static func _Flames(w: Dictionary) -> Texture2D:
	var id: String = str(w.get("id", ""))
	if id.is_empty() or str(w.get("kind", "")) == "characters":
		return null
	return Art.Portrait("units", id + ".damage")


## The name alone: the plain window's list adds the hull ("  (hull 40/60)").
static func _PlainName(text: String) -> String:
	var cut: int = text.find("  (")
	return text.substr(0, cut) if cut >= 0 else text
