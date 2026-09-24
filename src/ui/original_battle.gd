extends RefCounted
## THE BATTLE WINDOWS AS THE ORIGINAL DRAWS THEM (manual p141 Fig. 4.1, p142
## Fig. 4.2, p152-p153 Figs. 4.17-4.18), from its bitmaps at the places
## measured by template matching on TeeJ's five screenshots of the Empire's
## (2026-09-23: the alert, both forces pages, System Assets, and the results):
##   the Battle Alert - the side's 470x331 frame over a 400x310 picture, "Battle
##     at <system>" across its top, the situation in the original's own words
##     at its foot; the right-hand column's Battle Summary, Alliance Forces,
##     Imperial Forces and System Summary; Retreat, Simulate Results and Take
##     Command along the bottom;
##   the forces and system pages - the dimmed picture, the title, the page's
##     name, and a list: each fleet's name, each capital ship's miniature and
##     name with its fighters, troops and personnel under it, a row every 40
##     pixels, the side's scroll bar at the right;
##   the results - the Encyclopedia's frame (as TeeJ's screenshot has it), a
##     scene, the title, the outcome in large type and the rest of it below;
##     the column's close box, the summary, the two forces pages and Goto
##     System.
## Every position is in the frame's pixels, drawn OUI.K times as large. The
## Alliance's parts are the Empire's twins by their pictures (no screenshot).
##
## Preloaded by path: a new script can lag the editor's class cache.

const OUI := preload("res://src/ui/original_ui.gd")
const Art := preload("res://src/ui/artwork.gd")
const K := OUI.K

const FrameW := 470
const FrameH := 331
const PictureAt := Vector2(12, 13)
## The right-hand column: 44-wide buttons (the Empire's; the Alliance's 41 are
## centred on the same line).
const ColumnX := 426
const AlertYs := [17, 80, 143, 206]
const ResultYs := [17, 89, 148, 207, 266]
## Retreat, Simulate Results, Take Command (134x27).
const BottomY := 296
const BottomXs := [12, 146, 280]
## "Battle at <system>": Arial 20.5, the side's colour, centred on x 200 (the
## results' on the picture's middle, 212), capitals from y 20 (22).
const TitlePx := 20.5
const TitleCentre := 200.0
const ResultTitleCentre := 212.0
## The page's name (white, Arial 20.5) centred on x 203, capitals from y 44.
const PageCentre := 203.0
## The situation: Arial 15.5, the side's colour, from x 36, capitals from
## y 219, a line every 18.
const TextPx := 15.5
const TextAt := Vector2(36, 219)
const TextW := 300.0
## The results: the outcome (Arial 21) centred on x 207 from y 229; the rest
## (Arial 15.5) from (25, 258).
const OutcomePx := 21.0
const OutcomeCentre := 207.0
const OutcomeY := 229.0
const RestAt := Vector2(25, 258)
## The lists: a row every 40 pixels from y 80; a heading (Arial bold 13,
## near white) centred on x 203; a picture (61 or 66 x 25) at x 83, the
## name 72 pixels on, its capitals 3 below the picture's top; what a ship
## carries 20 pixels further in. Five rows show, between y 66 and 276 (the
## sixth is scrolled to, as on TeeJ's screenshot); the scroll bar at x 327,
## y 40-274.
const RowTop := 80
const RowPitch := 40
const RowX := 83
const NameGap := 72
const Indent := 20
const RowPx := 13.0
const RowColor := Color(225 / 255.0, 229 / 255.0, 224 / 255.0)
const ListClip := Rect2(12, 66, 312, 210)
const BarAt := Vector2(327, 40)
const BarH := 234


## True when the player imported the art the battle windows are made of.
static func CanBuild() -> bool:
	return Art.WindowPicture("battle_frame.empire") != null and Art.WindowPicture("battle_alert.empire") != null \
		and Art.ButtonIcon("battle_simulate.empire") != null and Art.TabIcon("battle_summary", "empire") != null


## The canvas every part goes on, in the frame's pixels; the window's own
## panel is emptied.
static func Canvas(window: Control) -> Control:
	window.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var c := Control.new()
	c.name = "OriginalBattle"
	c.custom_minimum_size = Vector2(FrameW, FrameH) * K
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(c)
	return c


## The window in the middle of the screen.
static func Centre(window: Control) -> void:
	var view: Vector2 = window.get_viewport_rect().size
	window.position = ((view - Vector2(FrameW, FrameH) * K) / 2.0).floor()


## A line of text whose capitals start at `cap_top` (Arial's caps sit 0.19 of
## the size under the line's top).
static func Line(parent: Control, text: String, x: float, cap_top: float, w: float, px: float, color: Color,
		align: HorizontalAlignment, bold: bool = false, node_name: String = "") -> Label:
	var l := OUI.Text(parent, text, x, cap_top - 0.19 * px, w, px * 1.3, px, color, align, bold, node_name)
	l.clip_text = true
	return l


## Wrapped text from `cap_top`, a line every `pitch`.
static func Block(parent: Control, text: String, at: Vector2, w: float, px: float, pitch: int, color: Color,
		node_name: String = "") -> Label:
	var l := OUI.Text(parent, text, at.x, at.y - 0.19 * px, w, pitch * 4, px, color, HORIZONTAL_ALIGNMENT_LEFT, false, node_name)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	OUI.LinePitch(l, px, pitch)
	# Sized again now it wraps: set before, the size was held at the whole
	# unwrapped line's width (a control is never smaller than its minimum).
	l.size = Vector2(w, pitch * 4) * K
	return l


## A column button: its (normal, current) pictures, swapped by `current`.
static func PageButton(parent: Control, stem: String, side: String, x: float, y: float, tip: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = stem.validate_node_name()
	b.set_meta("normal", OUI.Tab(stem, side))
	b.set_meta("current", OUI.Tab(stem, side, "pressed"))
	b.texture_normal = b.get_meta("normal")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var w: float = (b.texture_normal.get_width() / K) if b.texture_normal != null else 44.0
	b.position = Vector2(x + (44.0 - w) / 2.0, y) * K
	b.size = b.texture_normal.get_size() if b.texture_normal != null else Vector2(44, 41) * K
	b.tooltip_text = tip
	parent.add_child(b)
	return b


static func SetCurrent(buttons: Array, index: int) -> void:
	for i in buttons.size():
		var b: TextureButton = buttons[i]
		if b != null:
			b.texture_normal = b.get_meta("current" if i == index else "normal")


## A button with (normal, pressed, disabled) pictures at frame position.
static func Button3(parent: Control, name: String, x: float, y: float, tip: String) -> TextureButton:
	var b := OUI.PictureButton(parent, name, x, y, tip)
	b.texture_disabled = OUI.Btn(name, "disabled")
	var w: float = (b.texture_normal.get_width() / K) if b.texture_normal != null else 44.0
	if w < 44.0 and x >= ColumnX:
		b.position.x = (x + (44.0 - w) / 2.0) * K   # the Alliance's narrower column buttons
	return b


# ---- the lists -------------------------------------------------------------------

## A list's rows: {"head": text} or {"picture": Texture2D (as drawn), "name":
## text, "indent": 0 or 1}. Returns the list control (a clip with the rows
## and the side's scroll bar).
static func List(parent: Control, rows: Array, side: String) -> Control:
	var clip := Control.new()
	clip.name = "List"
	clip.clip_contents = true
	clip.position = ListClip.position * K
	clip.size = ListClip.size * K
	clip.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(clip)
	var inner := Control.new()
	inner.name = "Rows"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(inner)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var top: float = RowTop + i * RowPitch - ListClip.position.y
		if r.has("head"):
			Line(inner, str(r["head"]), PageCentre - 150 - ListClip.position.x, top + 3, 300, RowPx, RowColor,
				HORIZONTAL_ALIGNMENT_CENTER, true, "Head%d" % i)
			continue
		var x: float = RowX + int(r.get("indent", 0)) * Indent - ListClip.position.x
		var pic: Texture2D = r.get("picture")
		if pic != null:
			OUI.Place(inner, pic, x, top, "Picture%d" % i)
		Line(inner, str(r.get("name", "")), x + NameGap, top + 3, 240, RowPx, RowColor, HORIZONTAL_ALIGNMENT_LEFT, true, "Name%d" % i)
	var shown: int = int(ListClip.size.y) / RowPitch
	clip.set_meta("rows", rows.size())
	var bar := OUI.ScrollBar12.new()
	bar.name = "ScrollBar"
	bar.k = K
	bar.parts = [OUI.Btn("battle_scroll_up.%s" % side), OUI.Btn("battle_scroll_down.%s" % side),
		OUI.Pic("battle_thumb_top.%s" % side), OUI.Pic("battle_thumb_mid.%s" % side), OUI.Pic("battle_thumb_bottom.%s" % side)]
	bar.position = BarAt * K
	bar.size = Vector2(OUI.ScrollBar12.W - 1, BarH) * K
	parent.add_child(bar)
	bar.set_rows(0, shown, rows.size())
	bar.visible = rows.size() > shown
	bar.scrolled.connect(func(first: int) -> void:
		inner.position.y = -first * RowPitch * K)
	clip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and bar.visible:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP:
				bar.step(-1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				bar.step(1))
	return clip


## A fleet's rows for its forces page (Fig. 4.2): its name, then each capital
## ship with what it carries - fighters, troops - and the fleet's personnel
## (manual: "capital ships about to enter battle, and their assigned
## fighters, troops and personnel").
static func FleetRows(fleet: Fleet) -> Array:
	var rows: Array = [{"head": fleet.Name}]
	for s in fleet.Ships:
		if s.Type != Enums.UnitType.CapitalShip:
			continue
		rows.append({"picture": OUI.Mini("units", s.PackId), "name": s.Name, "indent": 0})
		if s.Hangar != null:
			for h in s.Hangar:
				rows.append({"picture": OUI.Mini("units", h.PackId), "name": h.Name, "indent": 1})
	for s in fleet.Ships:
		if s.Type == Enums.UnitType.Fighter:
			rows.append({"picture": OUI.Mini("units", s.PackId), "name": s.Name, "indent": 1})
	for c in GameState.ActiveRoster:
		if c.Attached == fleet and c.Status != Enums.Status.Dead:
			rows.append({"picture": OUI.Mini("characters", c.PackId), "name": c.Name, "indent": 1})
	return rows


## The system's rows (System Summary, TeeJ's "System Assets"): its facilities
## and what stands on it - live for a world of ours, else what intelligence
## last saw (text alone: a sighting carries no picture).
static func SystemRows(p: Planet) -> Array:
	var rows: Array = []
	var live: bool = IntelManager.View(GameSettings.PlayerFaction, p, Enums.IntelSection.DefensiveFacilities).Live
	if live:
		for f in p.Facilities:
			rows.append({"picture": OUI.Mini("facilities", f.Def.Id if f.Def != null else f.Family()), "name": f.Name(), "indent": 0})
		for u in p.Garrison:
			rows.append({"picture": OUI.Mini("units", u.PackId), "name": u.Name, "indent": 0})
		return rows
	for section in [Enums.IntelSection.DefensiveFacilities, Enums.IntelSection.Troopers]:
		var view: IntelManager.IntelView = IntelManager.View(GameSettings.PlayerFaction, p, section)
		if not view.Known:
			rows.append({"name": "Sensors detect no data."})
			break
		for line in view.Lines:
			rows.append({"name": line})
	return rows
