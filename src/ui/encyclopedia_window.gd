class_name EncyclopediaWindow
extends DraggableWindow
## THE GALACTIC ENCYCLOPEDIA (manual p073-p074, Figs 3.10 and 3.11).
##
## Index view (Fig 3.10): a Topic entry box ("type in its name in the Topic
## entry box"), one tab per database - All Databases, System, Ship,
## Facilities, Mission, Troop, Personnel - the list of entries, and the
## buttons View Topic, View Index and Close. Topic view (Fig 3.11): the
## topic's name with left/right arrows to browse ("Click here to browse
## through Encyclopedia"), its picture, and its description in a box that
## scrolls; "if applicable, tells you how many resources it takes to build and
## maintain the item". The database chosen in the Index stays chosen in Topic
## view, so the arrows step through that database only.
##
## Reachable from the Encyclopedia control on the bottom bar, F7 (manual
## p081), right-click -> Encyclopedia on any item, and the i button on the
## Create Mission window (p042 Fig 2.34).
##
## Content: every row of the loaded pack. The picture and the description
## come from the player's imported originals (src/ui/artwork.gd:
## original/<kind>/<id>.png and original/descriptions.json); a row with no
## description shows what the pack itself knows - costs, ratings, the home
## sector - so no entry is ever blank.

const LookDispatch := preload("res://src/ui/look_dispatch.gd")
const Databases := ["All Databases", "System", "Ship", "Facilities", "Mission", "Troop", "Personnel"]


## A database's name on screen: the places' and the ships' in the pack's
## words (Terms "system", "ship_database"; TeeJ, 2026-09-30: "rename ships to
## Units"), the rest as the original's.
static func DatabaseName(i: int) -> String:
	if i == 1:
		return Terms.label("system")
	if i == 2:
		return Terms.label("ship_database")
	return Databases[i]
## Entry kinds, as the overlay files are named.
const KindSystem := "planets"
const KindUnit := "units"
const KindFacility := "facilities"
const KindMission := "missions"
const KindCharacter := "characters"

class Entry:
	var Kind: String
	var Id: String
	var Name: String
	var Database: int      # index into Databases (1..6)
	func _init(kind: String, id: String, name: String, db: int) -> void:
		Kind = kind; Id = id; Name = name; Database = db

var _entries: Array[Entry] = []       # every entry, sorted by name within database
var _database: int = 0                # the chosen database (0 = All)
var _current: int = -1                # index into _shown, in Topic view
var _shown: Array[Entry] = []         # the entries of the chosen database
var _inTopic: bool = false

var _topicBox: LineEdit
var _tabs: Array[BaseButton] = []
## The Index view's list: an ItemList in the plain window, OriginalIndex in
## the original's (the same calls).
var _index
var _indexView: Control
var _topicView: Control
var _topicTitle: Label
var _picture: Control
var _text: RichTextLabel
## The plain window's topic page (TeeJ, 2026-09-30: "the stats are being cut
## off and the window is way too big for the content ... why are the stats
## being pushed down in the corner"): a reference file - the picture at its
## own size, the particulars ledger beside it, the entry's words under both.
var _sheet: PanelContainer
var _facts: GridContainer
var _factsHead: Label
## The page's database stamp in a pack's look (the dispatches' stamp): a
## mission's page only now.
var _stamp: PanelContainer
## THE FILE CARD (TeeJ, 2026-09-30): a territory's, a unit's or a facility's
## page is the personnel card's layout turned round - a ruled index card on
## the left with the particulars written along its top lines, the picture on
## the right. A person's picture already is such a card. In a pack's look the
## card carries the database's rubber stamp, struck across its lines at an
## angle in the entry's side's colour (red for the one, blue for the other).
var _head: HBoxContainer
var _card: Control
var _factsCol: VBoxContainer
var _mark: Control
var _viewTopicBtn: BaseButton
var _viewIndexBtn: BaseButton
var _indexHeader: Label

# THE ORIGINAL'S ENCYCLOPEDIA (Figs 3.10 / 3.11; TeeJ's screenshots of both
# sides' Topic view): the side's 470x331 frame, the Index plate (10338) or
# the Topic plate (10337) inside it at (12, 13), the browse arrows, the
# 400x200 picture at (12, 31), the text box under it with the original's
# scrollbar, and the side's three buttons down the frame's right edge. All
# in the original's pixels, drawn OUI.K times as large.
const FrameW := 470
const FrameH := 331
const PlateX := 12
const PlateY := 13
## The Empire's buttons are 44x41 at x 426, the Alliance's 32x31 at x 423.
const SideButtonsX := {"empire": 426, "alliance": 423}
const SideButtonsY := {"empire": [21, 89, 143], "alliance": [25, 93, 147]}
## The seven database tabs (Fig 3.10), measured on TeeJ's screenshots of the
## original's Alliance Index view (rebuilt to 0 differing pixels): each
## picture's top 49x41 at x 36 + 52i, y 78; the Empire's are the Alliance's
## twins (not seen). The band names the database (TEXTSTRA.DLL 6224-6230).
const TabNames := ["ency_tab_all", "ency_tab_system", "ency_tab_ship", "ency_tab_facilities",
	"ency_tab_missions", "ency_tab_troop", "ency_tab_personnel"]
const TabsX := 36
const TabsY := 78
const TabsPitch := 52
const TabSize := Vector2(49, 41)
const BandCaptions := ["All Databases", "System Database", "Ship Database", "Facilities Database",
	"Missions Database", "Troop Database", "Personnel Database"]

var _original: bool = false


func _ready() -> void:
	super()
	_original = _can_build_original()
	if _original:
		_build_original()
	else:
		_build()
	_load_entries()
	ShowIndex(_database)


func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


# ---- the entries ----------------------------------------------------------

func _load_entries() -> void:
	_entries.clear()
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack == null:
		return
	if pack.Map != null:
		for p in pack.Map.Planets:
			_entries.append(Entry.new(KindSystem, p.Id, p.DisplayName, 1))
	for u in pack.Units:
		var db: int = 2 if u.Kind == "capital_ship" or u.Kind == "fighter" else 5
		# The original files the special forces under Personnel (TeeJ's
		# screenshot of its Personnel Database lists Bothan Spies among the
		# characters). In its own window only.
		if _original and u.Kind == "spec_force":
			db = 6
		_entries.append(Entry.new(KindUnit, u.Id, u.DisplayName, db))
	for f in pack.Facilities:
		_entries.append(Entry.new(KindFacility, f.Id, f.DisplayName, 3))
	for m in pack.Missions:
		if m.Id.begins_with("unnamed"):
			continue   # the original's placeholder rows
		_entries.append(Entry.new(KindMission, m.Id, m.DisplayName, 4))
	for c in pack.Characters:
		_entries.append(Entry.new(KindCharacter, c.Id, c.DisplayName, 6))
	_entries.sort_custom(func(a: Entry, b: Entry) -> bool:
		return a.Name.naturalnocasecmp_to(b.Name) < 0 if a.Database == b.Database else a.Database < b.Database)


## The entries of a database (0 = every database, in database order - one
## alphabetical list in the original's window, as its All Databases is:
## A-wing, Abduction, Ackbar, Adar Tallon, Adega...).
func EntriesOf(db: int) -> Array[Entry]:
	var out: Array[Entry] = []
	for e in _entries:
		if db == 0 or e.Database == db:
			out.append(e)
	if db == 0 and _original:
		out.sort_custom(func(a: Entry, b: Entry) -> bool: return a.Name.naturalnocasecmp_to(b.Name) < 0)
	return out


# ---- the two views --------------------------------------------------------

## Index view: the list of the chosen database, the Topic box ready.
func ShowIndex(db: int = -1) -> void:
	if db >= 0:
		_database = db
	_shown = EntriesOf(_database)
	_inTopic = false
	_index.clear()
	for e in _shown:
		_index.add_item(e.Name)
	if _current >= 0 and _current < _shown.size():
		_index.select(_current)
	elif _original and not _shown.is_empty():
		_index.select(0)   # the original shows the first entry picked on a tab
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _database
	_indexView.visible = true
	_topicView.visible = false
	_viewTopicBtn.disabled = _shown.is_empty()
	_viewIndexBtn.disabled = true
	if _indexHeader != null:
		_indexHeader.text = BandCaptions[_database] if _original else DatabaseName(_database)
	_side_states()
	(get_node("%TitleBarLabel") as Label).text = " %s - %s" % [Terms.label("encyclopedia"), DatabaseName(_database)]


## Topic view of one entry, by kind and id (from a right-click menu or the i
## button); the database becomes that entry's own so the arrows browse it.
func ShowTopic(kind: String, id: String) -> void:
	for e in _entries:
		if e.Kind == kind and e.Id == id:
			_database = e.Database
			_shown = EntriesOf(_database)
			_current = _shown.find(e)
			_show_current()
			return
	push_warning("[Encyclopedia] no entry for %s/%s" % [kind, id])
	ShowIndex()


## Topic view of the entry selected in the index (View Topic).
func ViewTopic() -> void:
	if _shown.is_empty():
		return
	var sel: PackedInt32Array = _index.get_selected_items()
	_current = sel[0] if sel.size() > 0 else maxi(_current, 0)
	_show_current()


func Next() -> void:
	if _shown.is_empty():
		return
	_current = (_current + 1) % _shown.size()
	_show_current()


func Prev() -> void:
	if _shown.is_empty():
		return
	_current = (_current - 1 + _shown.size()) % _shown.size()
	_show_current()


## The topic on show, or null in Index view.
func CurrentEntry() -> Entry:
	return _shown[_current] if _inTopic and _current >= 0 and _current < _shown.size() else null


func _show_current() -> void:
	if _current < 0 or _current >= _shown.size():
		ShowIndex()
		return
	var e: Entry = _shown[_current]
	_inTopic = true
	_indexView.visible = false
	_topicView.visible = true
	_viewTopicBtn.disabled = true
	_viewIndexBtn.disabled = false
	_topicTitle.text = e.Name
	(get_node("%TitleBarLabel") as Label).text = " %s - %s" % [Terms.label("encyclopedia"), e.Name]
	if _original:
		# The picture at the original's 400x200, drawn K times as large.
		(_picture as TextureRect).texture = Art.Scaled(PictureFor(e), OUI.K)
		_text.text = _bbcode(TextFor(e))
		_text.scroll_to_line(0)
	else:
		_show_page(e)
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _database
	_side_states()


## The plain window's page: the picture in a box its own shape and size (a
## 400 x 200 plate at 1:1; a larger one drawn smaller to fit), the pack's
## particulars beside it, the entry's words under both.
func _show_page(e: Entry) -> void:
	var picture: Texture2D = PictureFor(e)
	_picture.visible = picture != null
	var k: float = 1.0
	if picture != null:
		k = minf(1.0, minf(PictureMax.x / picture.get_width(), PictureMax.y / picture.get_height()))
		_picture.custom_minimum_size = Vector2(roundf(picture.get_width() * k), roundf(picture.get_height() * k))
	Art.Fill(_picture, picture)
	for c in _facts.get_children():
		_facts.remove_child(c)
		c.queue_free()
	var rows: Array = ParticularsFor(e)
	_factsHead.visible = not rows.is_empty()
	for r in rows:
		var key := Label.new()
		key.text = str(r[0])
		var value := Label.new()
		value.text = str(r[1])
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_facts.add_child(key)
		_facts.add_child(value)
		_dress_fact(key, value)
	if _stamp != null:
		LookDispatch._set_stamp(_stamp, DatabaseName(e.Database), false, true)
	_lay_out(e, k)
	if _mark != null:
		_mark.set("Word", DatabaseName(e.Database).to_upper())
		_mark.set("Ink", StampInk(e))
		_mark.queue_redraw()
	var words: String = WordsFor(e)
	_text.text = words if not words.is_empty() else "No entry has been written for %s." % e.Name
	_text.scroll_to_line(0)


## Where the page's parts go for `e` (k: the picture's scale on the page):
##   a territory, a unit, a facility - the card on the left, the particulars
##   along its top lines and the stamp across it, the picture on the right;
##   a person - the picture (itself a card) on the left with the stamp across
##   its card, the particulars centred in the column beside it;
##   a mission - the picture, then its particulars under their heading, and
##   the database's stamp in the corner, as before.
func _lay_out(e: Entry, k: float) -> void:
	var on_card: bool = e.Kind in [KindSystem, KindUnit, KindFacility]
	var person: bool = e.Kind == KindCharacter
	_card.visible = on_card
	_factsCol.visible = not on_card
	_factsHead.visible = e.Kind == KindMission and _facts.get_child_count() > 0
	if _stamp != null:
		_stamp.visible = e.Kind == KindMission
	var holder: Control = _card.get_node("Lines") if on_card else _factsCol
	if _facts.get_parent() != holder:
		_facts.get_parent().remove_child(_facts)
		holder.add_child(_facts)
	_facts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if person else Control.SIZE_EXPAND_FILL
	# On a card a long value (a theatre's name) runs on to the next line;
	# beside a picture each value keeps to its one line.
	for i in _facts.get_child_count():
		var l: Label = _facts.get_child(i)
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP if on_card else VERTICAL_ALIGNMENT_BOTTOM
		l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if on_card else Control.SIZE_FILL
		if i % 2 == 1:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if on_card else TextServer.AUTOWRAP_OFF
	_factsCol.alignment = BoxContainer.ALIGNMENT_CENTER if person else BoxContainer.ALIGNMENT_BEGIN
	_head.move_child(_card, 0)
	_head.move_child(_picture, 1 if on_card else 0)
	# The card's head band in the side's colour, as a person's card has it.
	var side: Faction = SideOf(e)
	(_card as FileCard).Band = Color(Look.SideColor(side) if side != null else Look.C("ink_muted"), 0.9) if Look.Active() else Color(0, 0, 0, 0)
	_card.queue_redraw()
	if _mark == null:
		return
	# The stamp: across the card's ruled lines, under what is written on it;
	# on a person's picture, across the card printed on its left half.
	var stage: Control = _card if on_card else _picture
	if _mark.get_parent() != stage:
		_mark.get_parent().remove_child(_mark)
		stage.add_child(_mark)
	_mark.visible = on_card or (person and _picture.visible)
	if on_card:
		var top: float = CardLines + int(_facts.get_child_count() / 2.0) * CardPitch
		_mark.set("Centre", Vector2(CardSize.x / 2.0, (top + CardSize.y) / 2.0))
	else:
		_mark.set("Centre", PersonCardCentre * k)


## A card's size, its first written line and the pitch of its ruled lines -
## the personnel card's own (tools/look/make_ww2_portraits.py: a 200 x 200
## half of the picture, ruled every 18 px from 58, the head rule at 40), a
## little wider so a theatre's name fits on one line.
const CardSize := Vector2(250, 200)
const CardLines := 25.0
const CardPitch := 18.0
## Where a person's card is on their picture: the middle of its ruled part.
const PersonCardCentre := Vector2(107, 113)


## The colour a page's stamp is struck in: the entry's side's (TeeJ: "red for
## axis and blue for allies") - a person's own side; the one side that can
## build a unit or a facility; a territory's owner when the war begins - else
## the look's muted ink.
static func StampInk(e: Entry) -> Color:
	var side: Faction = SideOf(e)
	var c: Color = side.FactionColor.darkened(0.12) if side != null else Look.C("ink_muted")
	c.a = 0.82
	return c


static func SideOf(e: Entry) -> Faction:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var id := ""
	match e.Kind:
		KindCharacter:
			for c in pack.Characters:
				if c.Id == e.Id:
					id = c.FactionId
		KindUnit:
			var u: PackDefs.UnitDef = MilitaryCatalog.ById(e.Id)
			if u != null and u.BuildableBy.size() == 1:
				id = u.BuildableBy[0]
		KindFacility:
			for f in pack.Facilities:
				if f.Id == e.Id and f.BuildableBy.size() == 1:
					id = f.BuildableBy[0]
		KindSystem:
			for f in FactionRegistry.Playable:
				if f.Hq != null and f.Hq.Planet == e.Id:
					id = f.Id
				for sp in f.StartingPlanets:
					if sp.Planet == e.Id:
						id = f.Id
	if id.is_empty():
		return null
	for f in FactionRegistry.Playable:
		if f.Id == id:
			return f
	return null


## The card: a ruled index card in a pack's look (the personnel card's paper,
## its side band, head rule and lines), a plain dark panel without one.
class FileCard extends Control:
	var Band: Color = Color(0, 0, 0, 0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if not Look.Active():
			draw_rect(r, Color(0.11, 0.13, 0.18))
			draw_rect(r, Color(0.25, 0.32, 0.42), false, 1.0)
			return
		var paper: StyleBox = Look.Paper(0)
		if paper != null:
			draw_style_box(paper, r)
		else:
			draw_rect(r, Look.C("paper"))
		draw_rect(r.grow(-0.5), Color(Look.C("paper_edge"), 0.9), false, 1.0)
		draw_rect(Rect2(18, 18, size.x - 36, 5), Band)
		draw_line(Vector2(18, 40), Vector2(size.x - 18, 40), Color(Look.C("signal"), 0.6), 1.0)
		var y := 58.0
		while y < size.y - 12:
			draw_line(Vector2(18, y), Vector2(size.x - 18, y), Color8(0x8d, 0x9c, 0xae, 95), 1.0)
			y += 18.0


## A rubber stamp: the word in capitals inside a double rule, struck across
## the card at 40 degrees, in its ink (the dispatches' stamp, inked by hand).
class RubberStamp extends Control:
	var Word: String = ""
	var Ink: Color = Color.BLACK
	var Centre: Vector2 = Vector2.ZERO
	const Angle := -40.0

	func _draw() -> void:
		if Word.is_empty():
			return
		var font: Font = Look.F("display_bold") if Look.Active() else ThemeDB.fallback_font
		var px := 24
		var spaced := " ".join(Word.split(""))
		var w: float = font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var box := Rect2(Vector2(-w / 2.0 - 12.0, -px * 0.5 - 9.0), Vector2(w + 24.0, px + 18.0))
		draw_set_transform(Centre, deg_to_rad(Angle))
		draw_rect(box, Ink, false, 3.0)
		draw_rect(box.grow(-5.0), Ink, false, 1.0)
		draw_string(font, Vector2(-w / 2.0, font.get_ascent(px) * 0.5 + 1.0), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Ink)
		draw_set_transform(Vector2.ZERO)


## "Type in its name in the Topic entry box" - the first entry of the chosen
## database whose name starts with the text (then contains it) is selected;
## in Topic view it is shown at once.
func JumpTo(text: String) -> void:
	var t := text.strip_edges().to_lower()
	if t.is_empty():
		return
	var hit := -1
	for i in _shown.size():
		if _shown[i].Name.to_lower().begins_with(t):
			hit = i
			break
	if hit < 0:
		for i in _shown.size():
			if _shown[i].Name.to_lower().contains(t):
				hit = i
				break
	if hit < 0:
		return
	_current = hit
	if _inTopic:
		_show_current()
	else:
		_index.select(hit)
		_index.ensure_current_is_visible()


# ---- what an entry shows --------------------------------------------------

static func PictureFor(e: Entry) -> Texture2D:
	if e.Kind == KindMission:
		var side: String = GameSettings.PlayerFaction.ArtSkin if GameSettings.PlayerFaction != null else ""
		return Art.MissionPicture(e.Id, side)
	return Art.Picture(e.Kind, e.Id)


## The plain window's size, and the largest a picture is shown on its page:
## the pictures are the original's 400 x 200 (TeeJ, 2026-09-30: "the window
## is way too big for the content").
const PlainSize := Vector2(820, 610)
const PictureMax := Vector2(400, 200)


## An entry's own words - its description, the pack's or an art set's - or
## "" when it has none. The pack's facts are its particulars, not these.
static func WordsFor(e: Entry) -> String:
	return Art.Description(e.Kind, e.Id).strip_edges()


## What the pack itself knows of an entry, as [label, value] rows for the
## particulars ledger: a unit's or a facility's cost and upkeep, a person's
## ratings, a territory's theatre, who may run a mission.
static func ParticularsFor(e: Entry) -> Array:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var rows: Array = []
	match e.Kind:
		KindUnit:
			var u: PackDefs.UnitDef = MilitaryCatalog.ById(e.Id)
			if u != null:
				rows.append([Terms.label("refined_materials"), str(u.ConstructionCost)])
				rows.append([Terms.label("maintenance"), str(u.MaintenanceCost)])
		KindFacility:
			for f in pack.Facilities:
				if f.Id == e.Id:
					rows.append([Terms.label("refined_materials"), str(f.ConstructionCost)])
					rows.append([Terms.label("maintenance"), str(f.MaintenanceCost)])
		KindCharacter:
			for c in pack.Characters:
				if c.Id == e.Id:
					for rating in c.Ratings:
						rows.append([str(rating).capitalize(), str(c.Ratings[rating].Base)])
		KindSystem:
			if pack.Map != null:
				for p in pack.Map.Planets:
					if p.Id == e.Id:
						for s in pack.Map.Sectors:
							if s.Id == p.Sector:
								rows.append([Terms.label("sector"), s.DisplayName])
		KindMission:
			var d: PackDefs.MissionDefPack = MissionCatalog.ById(e.Id)
			if d != null:
				var sides: Array = d.AvailableTo.map(func(id: String) -> String:
					var f: Faction = FactionRegistry.ById(id)
					return f.DisplayName if f != null else id)
				rows.append(["Available to", ", ".join(sides)])
	return rows


## The page in the look: parchment, the ledger in the typed face, the words in
## ink - the dispatch's paper (look_dispatch.gd); plain, a dark well.
func _dress_sheet() -> void:
	if Look.Active():
		_sheet.add_theme_stylebox_override("panel", Look.Paper(16))
		_sheet.set_meta("look_paper", true)
		_factsHead.add_theme_font_override("font", Look.F("typed_bold"))
		_factsHead.add_theme_font_size_override("font_size", Look.Size("small"))
		_factsHead.add_theme_color_override("font_color", Look.C("ink"))
		_text.add_theme_font_override("normal_font", Look.F("body"))
		_text.add_theme_color_override("default_color", Look.C("ink"))
		var rule := Look.Rule()
		for c in _sheet.find_children("*", "HSeparator", true, false):
			if rule != null:
				(c as HSeparator).add_theme_stylebox_override("separator", rule)
		return
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.08, 0.1, 0.14, 1)
	well.set_content_margin_all(14)
	_sheet.add_theme_stylebox_override("panel", well)
	_factsHead.add_theme_font_size_override("font_size", 12)
	_factsHead.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))


## One ledger line: its label quiet, its value firm. On a card each sits on
## one of its ruled lines.
func _dress_fact(key: Label, value: Label) -> void:
	for l in [key, value]:
		l.custom_minimum_size.y = CardPitch
	if Look.Active():
		key.add_theme_font_override("font", Look.F("typed"))
		value.add_theme_font_override("font", Look.F("typed_bold"))
		key.add_theme_color_override("font_color", Look.Readable(Look.C("ink_muted"), Look.C("paper")))
		value.add_theme_color_override("font_color", Look.C("ink"))
		for l in [key, value]:
			l.add_theme_font_size_override("font_size", Look.Size("label"))
		return
	key.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
	for l in [key, value]:
		l.add_theme_font_size_override("font_size", 15)


## The imported description when there is one, else what the pack knows.
static func TextFor(e: Entry) -> String:
	var imported: String = Art.Description(e.Kind, e.Id)
	if not imported.is_empty():
		return imported
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var lines: PackedStringArray = PackedStringArray()
	match e.Kind:
		KindUnit:
			var u: PackDefs.UnitDef = MilitaryCatalog.ById(e.Id)
			if u != null:
				lines.append("%s %d" % [Terms.field("refined_materials"), u.ConstructionCost])
				lines.append("%s %d" % [Terms.field("maintenance"), u.MaintenanceCost])
		KindFacility:
			for f in pack.Facilities:
				if f.Id == e.Id:
					lines.append("%s %d" % [Terms.field("refined_materials"), f.ConstructionCost])
					lines.append("%s %d" % [Terms.field("maintenance"), f.MaintenanceCost])
		KindCharacter:
			for c in pack.Characters:
				if c.Id == e.Id:
					for rating in c.Ratings:
						lines.append("%s: %d" % [str(rating).capitalize(), c.Ratings[rating].Base])
		KindSystem:
			if pack.Map != null:
				for p in pack.Map.Planets:
					if p.Id == e.Id:
						for s in pack.Map.Sectors:
							if s.Id == p.Sector:
								lines.append("%s %s" % [s.DisplayName, Terms.lower("sector")])
		KindMission:
			var d: PackDefs.MissionDefPack = MissionCatalog.ById(e.Id)
			if d != null:
				lines.append("Available to: %s" % ", ".join(d.AvailableTo))
	if lines.is_empty():
		lines.append("No description.")
	return "\n".join(lines)


# ---- the original's window -------------------------------------------------

func _side() -> String:
	var s0: String = OUI.Side(GameSettings.PlayerFaction)
	return s0 if SideButtonsX.has(s0) else "empire"


func _can_build_original() -> bool:
	var side: String = _side()
	if not OUI.Has(["frame." + side, "ency_topic_plate", "ency_index_plate"]):
		return false
	if Art.TabIcon("ency_tab_all", side) == null:
		return false
	for b in ["ency_close.", "ency_view_topic.", "ency_view_index."]:
		if Art.ButtonIcon(b + side) == null:
			return false
	return Art.ButtonIcon("ency_prev") != null and Art.ButtonIcon("ency_next") != null


## The pressed look on the button of the view on show (Fig 3.11: View Topic
## lit in Topic view), the normal one on the other.
func _side_states() -> void:
	if not _original:
		return
	for pair in [[_viewTopicBtn, _inTopic], [_viewIndexBtn, not _inTopic]]:
		var b: TextureButton = pair[0]
		b.texture_normal = b.get_meta("pressed_tex") if pair[1] else b.get_meta("normal_tex")


## One of the frame's right-hand buttons, at its place for the side.
func _frame_button(parent: Control, name: String, row: int, tip: String, action: Callable) -> TextureButton:
	var side: String = _side()
	var b := TextureButton.new()
	b.name = name
	var normal: Texture2D = OUI.Btn("%s.%s" % [name, side])
	var pressed: Texture2D = OUI.Btn("%s.%s" % [name, side], "pressed")
	b.set_meta("normal_tex", normal)
	b.set_meta("pressed_tex", pressed if pressed != null else normal)
	b.texture_normal = normal
	b.texture_pressed = b.get_meta("pressed_tex")
	# No greyed picture: the original shows the current view's button lit,
	# the other one normal (Fig 3.11), and nothing greyed.
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	OUI.ClickSound(b)
	b.position = Vector2(SideButtonsX[side], SideButtonsY[side][row]) * OUI.K
	b.size = normal.get_size()
	b.tooltip_text = tip
	b.set_meta("title", tip)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## A browse arrow (Fig 3.11: "Click here to browse through Encyclopedia").
func _arrow_button(parent: Control, name: String, x: int, action: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.name = name
	b.texture_normal = OUI.Btn(name)
	b.texture_pressed = OUI.Btn(name, "pressed")
	b.texture_disabled = OUI.Btn(name, "disabled")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = Vector2(x, 14) * OUI.K
	b.size = b.texture_normal.get_size()
	b.tooltip_text = "Click here to browse through the Encyclopedia"
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The original's scrollbar on a list or text box: its arrow pictures at the
## ends, its three-part thumb, a black track, 13 pixels wide.
static func StyleScrollBar(bar: ScrollBar) -> void:
	if bar == null:
		return
	var up: Texture2D = OUI.Btn("scroll_up")
	var down: Texture2D = OUI.Btn("scroll_down")
	if up == null or down == null:
		return
	for n in ["decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(n, up)
	for n in ["increment", "increment_highlight", "increment_pressed"]:
		bar.add_theme_icon_override(n, down)
	var track := StyleBoxFlat.new()
	track.bg_color = Color.BLACK
	track.content_margin_left = 13 * OUI.K
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	var top: Image = Art.ButtonIcon("scroll_thumb_top").get_image()
	var mid: Image = Art.ButtonIcon("scroll_thumb_mid").get_image()
	var bottom: Image = Art.ButtonIcon("scroll_thumb_bottom").get_image()
	if top != null and mid != null and bottom != null:
		var thumb := Image.create(13, top.get_height() + mid.get_height() + bottom.get_height(), false, Image.FORMAT_RGBA8)
		for img in [top, mid, bottom]:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		thumb.blit_rect(top, Rect2i(0, 0, 13, top.get_height()), Vector2i(0, 0))
		thumb.blit_rect(mid, Rect2i(0, 0, 13, mid.get_height()), Vector2i(0, top.get_height()))
		thumb.blit_rect(bottom, Rect2i(0, 0, 13, bottom.get_height()), Vector2i(0, top.get_height() + mid.get_height()))
		thumb.resize(13 * OUI.K, thumb.get_height() * OUI.K, Image.INTERPOLATE_NEAREST)
		var grab := StyleBoxTexture.new()
		grab.texture = ImageTexture.create_from_image(thumb)
		grab.texture_margin_top = top.get_height() * OUI.K
		grab.texture_margin_bottom = bottom.get_height() * OUI.K
		for n in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(n, grab)
	bar.custom_minimum_size = Vector2(13 * OUI.K, 0)


## The imported description's "label<TAB><TAB>value" lines as a two-column
## table, the values lined up as the original lines them up.
static func _bbcode(text: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var rows: PackedStringArray = PackedStringArray()
	for line in text.split("\n"):
		if line.contains("\t"):
			var parts: PackedStringArray = line.split("\t", false)
			rows.append("[cell padding=0,0,%d,0]%s[/cell][cell]%s[/cell]" % [16 * OUI.K, parts[0].strip_edges(), (parts[parts.size() - 1] if parts.size() > 1 else "").strip_edges()])
			continue
		if not rows.is_empty():
			out.append("[table=2]%s[/table]" % "".join(rows))
			rows.clear()
		out.append(line)
	if not rows.is_empty():
		out.append("[table=2]%s[/table]" % "".join(rows))
	return "\n".join(out)


func _build_original() -> void:
	var side: String = _side()
	var K: int = OUI.K
	# No title bar: the original's Encyclopedia is its frame. Dragged by it.
	var bar: Control = get_node_or_null("%TitleBar")
	if bar != null:
		bar.visible = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var area: MarginContainer = OUI.Flatten(self)
	custom_minimum_size = Vector2(FrameW, FrameH) * K
	size = custom_minimum_size   # not the plain window's 1000x671
	var body := Control.new()
	body.name = "OriginalBody"
	body.custom_minimum_size = Vector2(FrameW, FrameH) * K
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	area.add_child(body)

	# ---- Index view (Fig 3.10) ----
	_indexView = Control.new()
	_indexView.name = "IndexView"
	_indexView.mouse_filter = Control.MOUSE_FILTER_PASS
	_indexView.size = Vector2(FrameW, FrameH) * K
	body.add_child(_indexView)
	OUI.Place(_indexView, OUI.Pic("ency_index_plate"), PlateX, PlateY, "Plate")
	# Measured: the title (bold Arial 13) from (140, 14), "Topic" (Arial 13)
	# from (36, 48), the typed text from (143, 45) in the plate's own box.
	OUI.Text(_indexView, Terms.label("encyclopedia"), 140, 15, 250, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true, "Title")
	OUI.Text(_indexView, "Topic", 36, 49, 90, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false, "TopicLabel")
	_topicBox = LineEdit.new()
	_topicBox.name = "TopicBox"
	_topicBox.position = Vector2(143, 45) * K
	_topicBox.size = Vector2(243, 16) * K
	_topicBox.placeholder_text = ""
	_topicBox.flat = true
	OUI.Style(_topicBox, 13, Color.WHITE)
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "focus", "read_only"]:
		_topicBox.add_theme_stylebox_override(st, clear)
	_topicBox.text_changed.connect(JumpTo)
	_topicBox.text_submitted.connect(func(t: String) -> void:
		JumpTo(t)
		if not _inTopic:
			ViewTopic())
	_indexView.add_child(_topicBox)
	# The seven database tabs.
	var group := ButtonGroup.new()
	for i in Databases.size():
		var tb := TextureButton.new()
		tb.name = "Database%d" % i
		tb.texture_normal = _tab_picture(OUI.Tab(TabNames[i], side))
		tb.texture_pressed = _tab_picture(OUI.Tab(TabNames[i], side, "pressed"))
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.toggle_mode = true
		tb.button_group = group
		tb.position = Vector2(TabsX + TabsPitch * i, TabsY) * K
		tb.size = TabSize * K
		tb.tooltip_text = BandCaptions[i]
		tb.set_meta("title", Databases[i])
		var db := i
		tb.pressed.connect(func() -> void:
			_current = -1
			ShowIndex(db))
		_indexView.add_child(tb)
		_tabs.append(tb)
	# The list under its header band.
	# The band's caption (bold Arial 13) from (40, 119).
	_indexHeader = OUI.Text(_indexView, BandCaptions[0], 40, 120, 330, 16, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true, "Header")
	# The list: names from x 41 (cut there), a row every 20 from y 139, 8
	# showing, and the original's scroll bar at (374, 137).
	var list := OriginalIndex.new()
	list.name = "Index"
	list.k = K
	list.position = Vector2(41, 137) * K
	list.size = Vector2(333, 160) * K
	list.font = OUI.Face()
	_indexView.add_child(list)
	var scroll := OUI.ScrollBar12.new()
	scroll.name = "ScrollBar"
	scroll.k = K
	scroll.parts = [OUI.Btn("scroll_up"), OUI.Btn("scroll_down"), OUI.Btn("scroll_thumb_top"), OUI.Btn("scroll_thumb_mid"), OUI.Btn("scroll_thumb_bottom")]
	scroll.position = Vector2(374, 137) * K
	scroll.size = Vector2(OUI.ScrollBar12.W - 1, 160) * K
	_indexView.add_child(scroll)
	list.bar = scroll
	scroll.scrolled.connect(list.scroll_to)
	list.item_activated.connect(func(_i: int) -> void: ViewTopic())
	_index = list

	# ---- Topic view (Fig 3.11) ----
	_topicView = Control.new()
	_topicView.name = "TopicView"
	_topicView.mouse_filter = Control.MOUSE_FILTER_PASS
	_topicView.size = Vector2(FrameW, FrameH) * K
	_topicView.visible = false
	body.add_child(_topicView)
	OUI.Place(_topicView, OUI.Pic("ency_topic_plate"), PlateX, PlateY, "Plate")
	_topicTitle = OUI.Text(_topicView, "", 49, 14, 331, 17, 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true, "Title")
	_topicTitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.position = Vector2(12, 31) * K
	pic.size = Vector2(400, 200) * K
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topicView.add_child(pic)
	_picture = pic
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.position = Vector2(17, 232) * K
	_text.size = Vector2(396, 86) * K
	_text.add_theme_font_override("normal_font", OUI.Face())
	_text.add_theme_font_size_override("normal_font_size", 13 * K)
	_text.add_theme_color_override("default_color", Color.WHITE)
	_text.add_theme_constant_override("line_separation", 0)
	_text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_text.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_topicView.add_child(_text)
	StyleScrollBar(_text.get_v_scroll_bar())

	# ---- the frame over both, its arrows and buttons ----
	# Dragged by where it is drawn; a click on the index inside goes through.
	var frame := OUI.PlaceHit(body, OUI.Pic("frame." + side), 0, 0, "Frame")
	frame.gui_input.connect(OnTitleBarGuiInput)
	if side == "alliance":   # the Alliance's three-socket column over the frame's strip
		var column := OUI.PlaceHit(body, OUI.Pic("ency_side.alliance"), 412, 0, "SideColumn")
		column.gui_input.connect(OnTitleBarGuiInput)
	_arrow_button(_topicView, "ency_prev", 28, Prev)
	_arrow_button(_topicView, "ency_next", 380, Next)
	# The arrows sit on the frame's band: keep the topic view above the frame.
	body.move_child(_topicView, body.get_child_count() - 1)
	_frame_button(body, "ency_close", 0, "Close the %s." % Terms.label("encyclopedia"), CloseWindow)
	_viewTopicBtn = _frame_button(body, "ency_view_topic", 1, "Click here to see the selected topic.", ViewTopic)
	_viewIndexBtn = _frame_button(body, "ency_view_index", 2, "While viewing a topic, click here to come back to the index.", func() -> void: ShowIndex())


## A tab picture as the original draws it: its top 49x41 (the Personnel
## pictures are 57 tall).
static func _tab_picture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var cut := AtlasTexture.new()
	cut.atlas = tex
	cut.region = Rect2(Vector2.ZERO, TabSize * OUI.K)
	return cut


## THE ORIGINAL'S INDEX LIST (TeeJ's screenshots, 0 differing pixels): a
## name every 20 pixels, eight showing, in regular Arial 13 - grey
## (120,120,120), the picked one white, no bar - cut at its left edge; the
## scroll bar (OUI.ScrollBar12) steps a row. It answers the ItemList calls
## this window makes: clear, add_item, select, get_selected_items,
## ensure_current_is_visible, get_item_text, item_count, item_activated.
class OriginalIndex extends Control:
	signal item_activated(index: int)
	const Pitch := 20
	const Shown := 8
	## A name's line starts 3 pixels under its row's top (the text cell's
	## top is 2 under it: 139 against 137).
	const TextTop := 3
	const Grey := Color(120 / 255.0, 120 / 255.0, 120 / 255.0)
	var k: int = 2
	var font: Font
	var bar: Control
	## The names' size (the Personnel Finder's list is smaller, 11).
	var px: float = 13.0
	var _names: Array[String] = []
	var _rows: Array = []
	var _selected: int = -1
	var _first: int = 0
	var item_count: int:
		get:
			return _names.size()

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_CLICK

	func clear() -> void:
		for r in _rows:
			(r as Node).queue_free()
		_rows.clear()
		_names.clear()
		_selected = -1
		_first = 0
		_sync_bar()

	func add_item(text: String) -> int:
		var i: int = _names.size()
		_names.append(text)
		var l := Label.new()
		l.text = text
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", roundi(px * k))
		l.add_theme_color_override("font_color", Grey)
		l.size = Vector2(size.x, Pitch * k)
		l.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				select(i)
				grab_focus()
				if e.double_click:
					item_activated.emit(i))
		add_child(l)
		_rows.append(l)
		_place()
		_sync_bar()
		return i

	func get_item_text(i: int) -> String:
		return _names[i] if i >= 0 and i < _names.size() else ""

	func select(i: int, _single: bool = true) -> void:
		if _selected >= 0 and _selected < _rows.size():
			(_rows[_selected] as Label).add_theme_color_override("font_color", Grey)
		_selected = i
		if i >= 0 and i < _rows.size():
			(_rows[i] as Label).add_theme_color_override("font_color", Color.WHITE)

	func get_selected_items() -> PackedInt32Array:
		return PackedInt32Array([_selected]) if _selected >= 0 else PackedInt32Array()

	func ensure_current_is_visible() -> void:
		if _selected < 0:
			return
		if _selected < _first:
			scroll_to(_selected)
		elif _selected >= _first + Shown:
			scroll_to(_selected - Shown + 1)

	func scroll_to(first: int) -> void:
		_first = clampi(first, 0, maxi(0, _names.size() - Shown))
		_place()
		if bar != null and int(bar.get("first")) != _first:
			bar.call("set_rows", _first, Shown, _names.size())

	func _place() -> void:
		for i in _rows.size():
			(_rows[i] as Control).position = Vector2(0, TextTop + (i - _first) * Pitch) * k

	func _sync_bar() -> void:
		if bar != null:
			bar.call("set_rows", _first, Shown, _names.size())
			# Only when the names run over (TeeJ's Fleet Finder, five fleets:
			# no bar).
			bar.visible = _names.size() > Shown

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and bar != null \
				and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			bar.call("step", -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			accept_event()
		# "Scroll down the list ... by using the cursor keys: Up, Down, Home,
		# or End" (manual p075, Fig. 3.12); Enter opens the one picked.
		if event is InputEventKey and event.pressed and not _names.is_empty():
			var to: int = _selected
			match event.keycode:
				KEY_UP:
					to = maxi(0, _selected - 1)
				KEY_DOWN:
					to = mini(_names.size() - 1, _selected + 1)
				KEY_HOME:
					to = 0
				KEY_END:
					to = _names.size() - 1
				KEY_ENTER, KEY_KP_ENTER:
					if _selected >= 0:
						item_activated.emit(_selected)
					accept_event()
					return
				_:
					return
			select(to)
			ensure_current_is_visible()
			accept_event()


# ---- the window -----------------------------------------------------------

func _build() -> void:
	# Sized to what it holds, not the original's 1000 x 671 frame: a 400 x
	# 200 picture, its particulars and a paragraph (TeeJ, 2026-09-30: "the
	# window is way too big for the content").
	custom_minimum_size = PlainSize
	size = PlainSize
	var area: MarginContainer = get_node("%ContentArea")
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	area.add_child(root)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	# Topic entry box (Fig 3.10).
	var topicRow := HBoxContainer.new()
	var topicLabel := Label.new()
	topicLabel.text = "Topic:"
	topicRow.add_child(topicLabel)
	_topicBox = LineEdit.new()
	_topicBox.placeholder_text = "Enter a topic's name to go directly to that topic"
	_topicBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topicBox.text_changed.connect(JumpTo)
	_topicBox.text_submitted.connect(func(t: String) -> void:
		JumpTo(t)
		if not _inTopic:
			ViewTopic())
	topicRow.add_child(_topicBox)
	main.add_child(topicRow)

	# The database tabs.
	var tabRow := HBoxContainer.new()
	tabRow.add_theme_constant_override("separation", 4)
	for i in Databases.size():
		var b := Button.new()
		b.text = DatabaseName(i)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Tab to show %s%s" % [DatabaseName(i), "" if i == 0 else " database"]
		var db := i
		b.pressed.connect(func() -> void:
			_current = -1
			ShowIndex(db))
		tabRow.add_child(b)
		_tabs.append(b)
	main.add_child(tabRow)

	# Index view.
	_indexView = VBoxContainer.new()
	_indexView.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_index = ItemList.new()
	_index.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_index.item_activated.connect(func(_i: int) -> void: ViewTopic())
	_indexView.add_child(_index)
	main.add_child(_indexView)

	# Topic view (Fig 3.11): arrows and the name, the picture, the text.
	_topicView = VBoxContainer.new()
	_topicView.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_topicView.add_theme_constant_override("separation", 8)
	var titleRow := HBoxContainer.new()
	var prev := Button.new()
	prev.text = "<"
	prev.tooltip_text = "Click here to browse through the Encyclopedia"
	prev.pressed.connect(Prev)
	titleRow.add_child(prev)
	_topicTitle = Label.new()
	_topicTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_topicTitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topicTitle.add_theme_font_size_override("font_size", 20)
	titleRow.add_child(_topicTitle)
	var next := Button.new()
	next.text = ">"
	next.tooltip_text = "Click here to browse through the Encyclopedia"
	next.pressed.connect(Next)
	titleRow.add_child(next)
	_topicView.add_child(titleRow)
	# The page: a sheet (parchment in a pack's look) holding the picture and
	# the particulars side by side, a rule, then the entry's words.
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_sheet.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	page.add_child(head)
	_head = head
	_card = FileCard.new()
	_card.name = "Card"
	_card.custom_minimum_size = CardSize
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_card)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.position = Vector2(18, CardLines)
	lines.size = Vector2(CardSize.x - 36, CardSize.y - CardLines - 8)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(lines)
	_picture = ColorRect.new()
	_picture.name = "PictureBox"
	_picture.color = Color(0, 0, 0, 0)   # the picture fills its box: nothing shows round it
	_picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_picture)
	_factsCol = VBoxContainer.new()
	_factsCol.name = "FactsColumn"
	_factsCol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_factsCol.add_theme_constant_override("separation", 4)
	_factsHead = Label.new()
	_factsHead.text = "PARTICULARS"
	_factsCol.add_child(_factsHead)
	_facts = GridContainer.new()
	_facts.name = "Particulars"
	_facts.columns = 2
	_facts.add_theme_constant_override("h_separation", 14)
	_facts.add_theme_constant_override("v_separation", 3)
	_factsCol.add_child(_facts)
	head.add_child(_factsCol)
	if Look.Active():
		# A mission's database stamped in its corner, as a dispatch's category.
		_stamp = LookDispatch._stamp(true)
		_stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(_stamp)
		_mark = RubberStamp.new()
		_mark.name = "Stamp"
		_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(_mark)
	page.add_child(HSeparator.new())
	_text = RichTextLabel.new()
	_text.name = "Words"
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 120)
	_text.scroll_active = true
	_text.add_theme_font_size_override("normal_font_size", 16)
	page.add_child(_text)
	_topicView.add_child(_sheet)
	_topicView.visible = false
	main.add_child(_topicView)
	_dress_sheet()

	# The right-hand buttons (Fig 3.10): View Topic, View Index, Close.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	_viewTopicBtn = Button.new()
	_viewTopicBtn.text = "View Topic"
	_viewTopicBtn.tooltip_text = "Click here to see the selected topic."
	_viewTopicBtn.pressed.connect(ViewTopic)
	side.add_child(_viewTopicBtn)
	_viewIndexBtn = Button.new()
	_viewIndexBtn.text = "View Index"
	_viewIndexBtn.tooltip_text = "While viewing a topic, click here to come back to the index."
	_viewIndexBtn.pressed.connect(func() -> void: ShowIndex())
	side.add_child(_viewIndexBtn)
	var closeBtn := Button.new()
	closeBtn.text = "Close"
	closeBtn.tooltip_text = "Close the %s." % Terms.label("encyclopedia")
	closeBtn.pressed.connect(CloseWindow)
	side.add_child(closeBtn)
	root.add_child(side)
