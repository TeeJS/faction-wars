class_name TroopFinder
extends DraggableWindow
## THE TROOP FINDER (manual p132 Fig. 3.80; TeeJ's screenshots of both tabs,
## 2026-09-24: "troop info should be renamed Troop Finder and should be
## implemented with the same UI as the original"): the Troop Location field,
## tabs for Alliance and Imperial troops, and every system or fleet holding
## that side's regiments - "results are listed by system or fleet, with a
## count under a Troop icon", the plate's band carrying the side's five icons.
## Display, or a double-click, opens the System window - the System Defenses
## window for a system, the Fleet window for a fleet. Only what we know: all
## of ours; theirs where our intelligence has seen them on a system.
##
## With the art imported it is the original's (src/ui/original_finder.gd);
## without it, a plain list with the same counts.

const OF := preload("res://src/ui/original_finder.gd")
const TabStems := ["finder_tab_rebel", "finder_tab_imperial"]
## The band's five icons per side, left to right (STRATEGY 10540 / 10541,
## matched by eye against the regiments' portraits): the Alliance's army,
## fleet, Mon Calamari, Sullustan and Wookiee regiments; the Empire's army,
## dark trooper, fleet, stormtrooper and war droid regiments.
const Columns := {
	"alliance": ["alliance_army_regiment", "alliance_fleet_regiment", "mon_calamari_regiment", "sullustan_regiment", "wookiee_regiment"],
	"empire": ["imperial_army_regiment", "dark_trooper_regiment", "imperial_fleet_regiment", "stormtrooper_regiment", "war_droid_regiment"],
}
## The band's dotted rules (frame x): each column's left edge.
const ColumnXs := [227, 255, 283, 311, 339]
## The band (plate 100-128) is taller than the other finders': its caption
## from (40, 119), the rows from 142.
const CaptionY := 119
const GridTop := 142

var _o: Dictionary = {}
var _tab: int = 0
var _shown: Array = []
var _plain: Dictionary = {}


## One row: a system or a fleet of the side, and its regiments by type.
class Row:
	var Name: String
	var Where: Planet          # the system (a fleet: where it is)
	var Fleet_: Fleet          # the fleet, when the row is one
	var Counts: Dictionary = {}   # unit id -> regiments


func _ready() -> void:
	super()
	if OF.CanBuild(["finder_troops.alliance", "finder_troops.empire"], TabStems, ["finder_display"]):
		_BuildOriginal()
	else:
		_BuildPlain()
	# The viewer's own side first.
	var mine: int = maxi(0, FactionRegistry.Playable.find(GameSettings.PlayerFaction))
	ShowTab(mine, true)


func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


## The side a tab lists (pack order).
static func SideOf(tab: int) -> Faction:
	return FactionRegistry.Playable[tab] if tab < FactionRegistry.Playable.size() else null


## "Alliance Troops", "Imperial Troops".
static func Caption(tab: int) -> String:
	var f: Faction = SideOf(tab)
	return "%s Troops" % (f.Adjective if f != null else "")


## Every system or fleet with the side's regiments that we know of, by name.
static func RowsFor(side: Faction) -> Array:
	var viewer: Faction = GameSettings.PlayerFaction
	var out: Array = []
	if side == null or GameState.ActiveGalaxy == null:
		return out
	for p in GameState.AllPlanets():
		if side == viewer or IntelManager.IsLive(viewer, p):
			var here := Row.new()
			here.Name = p.Name
			here.Where = p
			for u in p.Troopers():
				if u.Faction == side:
					here.Counts[u.PackId] = int(here.Counts.get(u.PackId, 0)) + 1
			if not here.Counts.is_empty():
				out.append(here)
		else:
			# Theirs on a system, as last seen.
			var view: IntelManager.IntelView = IntelManager.View(viewer, p, Enums.IntelSection.Troopers)
			if view.Known and not view.Lines.is_empty():
				var seen := Row.new()
				seen.Name = p.Name
				seen.Where = p
				for line in view.Lines:
					var id: String = _unit_id_named(str(line))
					if not id.is_empty():
						seen.Counts[id] = int(seen.Counts.get(id, 0)) + 1
				if not seen.Counts.is_empty():
					out.append(seen)
		# Fleets: ours always; theirs only in orbit at a world of ours.
		for f in p.OrbitingFleets:
			if f.Faction != side or (side != viewer and not (IntelManager.IsLive(viewer, p) and f.Status != Enums.Status.Enroute)):
				continue
			var aboard := Row.new()
			aboard.Name = f.Name
			aboard.Where = p
			aboard.Fleet_ = f
			for s in f.Ships:
				var carried: Array = [s] + s.Hangar
				for u in carried:
					if u.Type == Enums.UnitType.Troop:
						aboard.Counts[u.PackId] = int(aboard.Counts.get(u.PackId, 0)) + 1
			if not aboard.Counts.is_empty():
				out.append(aboard)
	out.sort_custom(func(a: Row, b: Row) -> bool: return a.Name.naturalnocasecmp_to(b.Name) < 0)
	return out


## A regiment's pack id from the name a sighting kept ("" when none).
static func _unit_id_named(title: String) -> String:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack == null:
		return ""
	for u in pack.Units:
		if title == u.DisplayName or title.begins_with(u.DisplayName + " "):
			return u.Id
	return ""


## A row's counts in the band's column order for the side's skin.
static func CountsOf(row: Row, skin: String) -> Array:
	var out: Array = []
	for id in Columns.get(skin, []):
		out.append(int(row.Counts.get(id, 0)))
	return out


# ---- the original's ---------------------------------------------------------------

func _BuildOriginal() -> void:
	var tabs: Array = []
	for i in TabStems.size():
		tabs.append([TabStems[i], Caption(i)])
	_o = OF.Build(self, "Troop Finder", "Troop Location", OUI.Pic("finder_troops.alliance"), tabs,
		[["finder_display", "Open the System window for the selected system or fleet."]])
	(_o["header"] as Label).position.y = CaptionY * OUI.K
	OF.UseGrid(_o, GridTop, ColumnXs)
	for i in _o["tabs"].size():
		var tab: int = i
		(_o["tabs"][i] as TextureButton).pressed.connect(func() -> void: ShowTab(tab, true))
	(_o["buttons"]["finder_display"] as TextureButton).pressed.connect(Display)
	(_o["list"] as Control).connect("item_activated", func(_i: int) -> void: Display())
	(_o["field"] as LineEdit).text_changed.connect(func(t: String) -> void: OF.Locate(_o["list"], t))
	(_o["field"] as LineEdit).text_submitted.connect(func(_t: String) -> void: Display())


## Show a side's troops: its plate (the band's icons are the side's), its
## rows.
func ShowTab(tab: int, pick: bool) -> void:
	_tab = tab
	var side: Faction = SideOf(tab)
	_shown = RowsFor(side)
	var skin: String = OUI.Side(side) if side != null else "alliance"
	if _o.is_empty():
		_ShowPlain(skin)
		return
	for i in _o["tabs"].size():
		(_o["tabs"][i] as TextureButton).set_pressed_no_signal(i == tab)
	(_o["plate"] as TextureRect).texture = OUI.Pic("finder_troops." + skin)
	(_o["header"] as Label).text = Caption(tab)
	var grid: Control = _o["list"]
	grid.call("clear")
	for r in _shown:
		grid.call("add_item", (r as Row).Name, CountsOf(r, skin))
	if pick and not _shown.is_empty():
		grid.call("select", 0)
	var typed: String = (_o["field"] as LineEdit).text
	if not typed.strip_edges().is_empty():
		OF.Locate(grid, typed)


func Selected() -> Row:
	var list: Object = _o["list"] if not _o.is_empty() else _plain.get("list")
	if list == null:
		return null
	var picked: PackedInt32Array = list.call("get_selected_items")
	return _shown[picked[0]] if not picked.is_empty() and picked[0] < _shown.size() else null


## "Display or double-click opens the System window": a system's System
## Defenses, a fleet's Fleet window - with the sector - and the Finder
## closes behind them.
func Display() -> void:
	var r: Row = Selected()
	if r == null or r.Where == null or _uiManager == null:
		return
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(r.Where))
	if sector != null:
		_uiManager.OnSectorClicked(sector)
	if r.Fleet_ != null:
		_uiManager.OnFleetClicked(r.Where)
	else:
		_uiManager.OnDefenseClicked(r.Where)
	CloseWindow()


# ---- the plain window ---------------------------------------------------------------

func _BuildPlain() -> void:
	var area: Control = get_node("%ContentArea")
	var box := VBoxContainer.new()
	area.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = "Troop Location"
	row.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var tabs := TabBar.new()
	box.add_child(tabs)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(420, 220)
	box.add_child(list)
	var display := Button.new()
	display.text = "Display"
	box.add_child(display)
	_plain = {"tabs": tabs, "list": list}
	for i in TabStems.size():
		tabs.add_tab(Caption(i))
	tabs.tab_changed.connect(func(i: int) -> void: ShowTab(i, true))
	display.pressed.connect(Display)
	list.item_activated.connect(func(_i: int) -> void: Display())
	field.text_changed.connect(func(t: String) -> void: OF.Locate(list, t))


func _ShowPlain(skin: String) -> void:
	if _plain.is_empty():
		return
	var list: ItemList = _plain["list"]
	list.clear()
	for r in _shown:
		var parts: Array = []
		var counts: Array = CountsOf(r, skin)
		for c in counts.size():
			if counts[c] > 0:
				parts.append("%d %s" % [counts[c], _unit_name(Columns[skin][c])])
		list.add_item("%s  -  %s" % [(r as Row).Name, ", ".join(parts)])


static func _unit_name(id: String) -> String:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack != null:
		for u in pack.Units:
			if u.Id == id:
				return u.DisplayName
	return id
