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

const Databases := ["All Databases", "System", "Ship", "Facilities", "Mission", "Troop", "Personnel"]
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
var _tabs: Array[Button] = []
var _index: ItemList
var _indexView: VBoxContainer
var _topicView: VBoxContainer
var _topicTitle: Label
var _picture: ColorRect
var _text: RichTextLabel
var _viewTopicBtn: Button
var _viewIndexBtn: Button


func _ready() -> void:
	super()
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


## The entries of a database (0 = every database, in database order).
func EntriesOf(db: int) -> Array[Entry]:
	var out: Array[Entry] = []
	for e in _entries:
		if db == 0 or e.Database == db:
			out.append(e)
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
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _database
	_indexView.visible = true
	_topicView.visible = false
	_viewTopicBtn.disabled = _shown.is_empty()
	_viewIndexBtn.disabled = true
	(get_node("%TitleBarLabel") as Label).text = " Galactic Encyclopedia - %s" % Databases[_database]


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
	(get_node("%TitleBarLabel") as Label).text = " Galactic Encyclopedia - %s" % e.Name
	Art.Fill(_picture, PictureFor(e))
	_text.text = TextFor(e)
	for i in _tabs.size():
		_tabs[i].button_pressed = i == _database


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
		var side: String = GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else ""
		return Art.MissionPicture(e.Id, side)
	return Art.Picture(e.Kind, e.Id)


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
								lines.append("%s sector" % s.DisplayName)
		KindMission:
			var d: PackDefs.MissionDefPack = MissionCatalog.ById(e.Id)
			if d != null:
				lines.append("Available to: %s" % ", ".join(d.AvailableTo))
	if lines.is_empty():
		lines.append("No description.")
	return "\n".join(lines)


# ---- the window -----------------------------------------------------------

func _build() -> void:
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
		b.text = Databases[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Tab to show %s%s" % [Databases[i], "" if i == 0 else " database"]
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
	_picture = ColorRect.new()
	_picture.color = Color(0.08, 0.1, 0.14, 1)
	_picture.custom_minimum_size = Vector2(800, 400)
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_topicView.add_child(_picture)
	_text = RichTextLabel.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.scroll_active = true
	_text.add_theme_font_size_override("normal_font_size", 15)
	_topicView.add_child(_text)
	_topicView.visible = false
	main.add_child(_topicView)

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
	closeBtn.tooltip_text = "Close the Galactic Encyclopedia."
	closeBtn.pressed.connect(CloseWindow)
	side.add_child(closeBtn)
	root.add_child(side)
