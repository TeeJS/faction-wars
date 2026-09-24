class_name FleetFinder
extends DraggableWindow
## THE FLEET FINDER AND THE SHIP FINDER, one dialog (manual p125 Figs.
## 3.68-3.70, p126 Fig. 3.72; TeeJ's screenshots of both, 2026-09-24): the
## Fleet Name field ("Enter fleet name to go directly to that fleet"), tabs
## for all, Alliance and Imperial fleets, the list; down the frame Close,
## Display ("Open Fleet window and Sector window for selected fleet"), "Switch
## to Ship Finder" and "Switch back to Fleet Finder" - the same dialog then
## searching ships. It lists only what we know of (TeeJ: "good reminder we
## only see what we know about"): all of ours, and theirs where our
## intelligence has seen them - the last sighting of each.
##
## With the art imported it is the original's (src/ui/original_finder.gd);
## without it, a plain list with the same contents.

const OF := preload("res://src/ui/original_finder.gd")
const TabStems := ["finder_tab_all", "finder_tab_rebel", "finder_tab_imperial"]

var Ships: bool = false          # the Ship Finder, else the Fleet Finder
var _o: Dictionary = {}
var _tab: int = 0
var _shown: Array = []           # the Entries listed
var _plain: Dictionary = {}      # the plain window's parts


## One line of the list: a fleet or ship we know of, where it is (or was seen).
class Entry:
	var Name: String
	var Side: Faction           # whose it is
	var Where: Planet           # its system (a fleet in hyperspace: its destination)
	var Live: bool              # ours, or in view now; else a sighting


func _ready() -> void:
	super()
	if OF.CanBuild(["finder_fleets." + OF.Side(), "finder_ships." + OF.Side()], TabStems,
			["finder_display", "finder_btn_ships", "finder_btn_fleets"]):
		_BuildOriginal()
	else:
		_BuildPlain()
	ShowTab(0, false)


func Setup(uiManager: UIManager, ships: bool = false) -> void:
	_uiManager = uiManager
	if ships != Ships:
		SetShips(ships)


# ---- what is listed ---------------------------------------------------------------

## Everything the finder knows of, by name: `ships` capital ships, else fleets.
static func Known(ships: bool) -> Array:
	var viewer: Faction = GameSettings.PlayerFaction
	var out: Array = []
	var seen: Dictionary = {}    # a sighted name -> the latest day seen
	if GameState.ActiveGalaxy == null:
		return out
	# Ours are never a sighting: a stale one of a fleet of ours that has
	# since moved must not list it as theirs, somewhere it no longer is.
	var ourNames: Dictionary = {}
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == viewer:
				ourNames[f.Name] = true
				for s in f.Ships:
					ourNames[s.Name] = true
	for p in GameState.AllPlanets():
		var live: bool = IntelManager.IsLive(viewer, p)
		for f in p.OrbitingFleets:
			# Ours wherever they are (in hyperspace, filed at the destination);
			# anyone's in orbit at a world of ours, which we see.
			var ours: bool = f.Faction == viewer
			if not ours and not (live and f.Status != Enums.Status.Enroute):
				continue
			if ships:
				for s in f.Ships:
					if s.Type == Enums.UnitType.CapitalShip:
						out.append(_entry(s.Name, f.Faction, p, true))
			else:
				out.append(_entry(f.Name, f.Faction, p, true))
		if live:
			continue
		# Theirs, as last seen: the sighting of the ships in orbit.
		var view: IntelManager.IntelView = IntelManager.View(viewer, p, Enums.IntelSection.OrbitingShips)
		if not view.Known:
			continue
		var them: Faction = _other(viewer)
		for g in view.Groups:
			if ourNames.has(g.Name):
				continue
			var names: Array = g.Lines if ships else [g.Name]
			for n in names:
				var key: String = str(n)
				if ourNames.has(key):
					continue
				if seen.has(key) and int(seen[key][0]) >= view.Day:
					continue
				if seen.has(key):
					out.erase(seen[key][1])
				var e := _entry(key, them, p, false)
				seen[key] = [view.Day, e]
				out.append(e)
	out.sort_custom(func(a: Entry, b: Entry) -> bool: return a.Name.naturalnocasecmp_to(b.Name) < 0)
	return out


static func _entry(name: String, side: Faction, where: Planet, live: bool) -> Entry:
	var e := Entry.new()
	e.Name = name
	e.Side = side
	e.Where = where
	e.Live = live
	return e


## The other playable side (a sighting names no owner; in a two-sided game
## it is theirs).
static func _other(viewer: Faction) -> Faction:
	for f in FactionRegistry.Playable:
		if f != viewer:
			return f
	return null


## A tab's entries: all, or the first / second playable side's.
func EntriesOn(tab: int) -> Array:
	var all: Array = Known(Ships)
	if tab == 0:
		return all
	var side: Faction = FactionRegistry.Playable[tab - 1] if FactionRegistry.Playable.size() >= tab else null
	return Lq.where(all, func(e: Entry) -> bool: return e.Side == side)


## "All Fleets", "Alliance Fleets", "Imperial Fleets" (the Ship Finder's
## "... Ships").
func Caption(tab: int) -> String:
	var what: String = "Ships" if Ships else "Fleets"
	if tab == 0:
		return "All %s" % what
	var f: Faction = FactionRegistry.Playable[tab - 1] if FactionRegistry.Playable.size() >= tab else null
	return "%s %s" % [f.Adjective if f != null else "", what]


# ---- the original's ---------------------------------------------------------------

func _BuildOriginal() -> void:
	var tabs: Array = []
	for i in TabStems.size():
		tabs.append([TabStems[i], Caption(i)])
	_o = OF.Build(self, "Fleet Finder", "Fleet Name", OUI.Pic("finder_fleets." + OF.Side()), tabs, [
		["finder_display", "Open Fleet window and Sector window for selected fleet."],
		["finder_btn_ships", "Switch to Ship Finder."],
		["finder_btn_fleets", "Switch back to Fleet Finder from Ship Finder."],
	])
	for i in _o["tabs"].size():
		var tab: int = i
		(_o["tabs"][i] as TextureButton).pressed.connect(func() -> void: ShowTab(tab, true))
	(_o["buttons"]["finder_display"] as TextureButton).pressed.connect(Display)
	(_o["buttons"]["finder_btn_ships"] as TextureButton).pressed.connect(func() -> void: SetShips(true))
	(_o["buttons"]["finder_btn_fleets"] as TextureButton).pressed.connect(func() -> void: SetShips(false))
	(_o["list"] as Control).connect("item_activated", func(_i: int) -> void: Display())
	(_o["field"] as LineEdit).text_changed.connect(func(t: String) -> void: OF.Locate(_o["list"], t))
	(_o["field"] as LineEdit).text_submitted.connect(func(_t: String) -> void: Display())
	_Dress()


## The dialog's dress for what it searches: title, label, plate, the lit
## switch.
func _Dress() -> void:
	WindowTitle = "Ship Finder" if Ships else "Fleet Finder"
	if _o.is_empty():
		return
	var body: Control = _o["body"]
	(body.get_node("Title") as Label).text = "Ship Finder" if Ships else "Fleet Finder"
	(body.get_node("NameLabel") as Label).text = "Ship Name" if Ships else "Fleet Name"
	var plate: TextureRect = _o["plate"]
	plate.texture = OUI.Pic(("finder_ships." if Ships else "finder_fleets.") + OF.Side())
	OF.SetCurrent(_o["buttons"]["finder_btn_ships"], Ships)
	OF.SetCurrent(_o["buttons"]["finder_btn_fleets"], not Ships)
	for i in _o["tabs"].size():
		(_o["tabs"][i] as TextureButton).tooltip_text = Caption(i)


## Switch between the Fleet Finder and the Ship Finder.
func SetShips(ships: bool) -> void:
	Ships = ships
	_Dress()
	if not _o.is_empty() or not _plain.is_empty():
		ShowTab(_tab, false)


## Show a tab; one with nothing on it is greyed.
func ShowTab(tab: int, pick: bool) -> void:
	_tab = tab
	_shown = EntriesOn(tab)
	if _o.is_empty():
		_ShowPlain()
		return
	var buttons: Array = _o["tabs"]
	for i in buttons.size():
		var b: TextureButton = buttons[i]
		b.set_pressed_no_signal(i == tab)
		# Never greyed for being empty: the original's Imperial Fleets and
		# Imperial Troops tabs stand normal with nothing on them (TeeJ's
		# screenshots, 2026-09-24).
		b.disabled = false
	(_o["header"] as Label).text = Caption(tab)
	var list: Control = _o["list"]
	list.call("clear")
	for e in _shown:
		list.call("add_item", (e as Entry).Name)
	if pick and not _shown.is_empty():
		list.call("select", 0)
	var typed: String = (_o["field"] as LineEdit).text
	if not typed.strip_edges().is_empty():
		OF.Locate(list, typed)


func Selected() -> Entry:
	var list: Control = _o["list"] if not _o.is_empty() else _plain.get("list")
	if list == null:
		return null
	var picked: PackedInt32Array = list.call("get_selected_items")
	return _shown[picked[0]] if not picked.is_empty() and picked[0] < _shown.size() else null


## "Open Fleet window and Sector window for selected fleet" (Fig. 3.70) -
## where it is, or where it was seen; the Finder closes behind them.
func Display() -> void:
	var e: Entry = Selected()
	if e == null or e.Where == null or _uiManager == null:
		return
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(e.Where))
	if sector != null:
		_uiManager.OnSectorClicked(sector)
	_uiManager.OnFleetClicked(e.Where)
	CloseWindow()


# ---- the plain window ---------------------------------------------------------------

func _BuildPlain() -> void:
	var area: Control = get_node("%ContentArea")
	var box := VBoxContainer.new()
	area.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.name = "NameLabel"
	row.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var tabs := TabBar.new()
	box.add_child(tabs)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(400, 220)
	box.add_child(list)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var display := Button.new()
	display.text = "Display"
	buttons.add_child(display)
	var toggle := Button.new()
	buttons.add_child(toggle)
	_plain = {"label": label, "field": field, "tabs": tabs, "list": list, "toggle": toggle}
	for i in TabStems.size():
		tabs.add_tab(Caption(i))
	tabs.tab_changed.connect(func(i: int) -> void: ShowTab(i, true))
	display.pressed.connect(Display)
	toggle.pressed.connect(func() -> void: SetShips(not Ships))
	list.item_activated.connect(func(_i: int) -> void: Display())
	field.text_changed.connect(func(t: String) -> void: OF.Locate(list, t))


func _ShowPlain() -> void:
	if _plain.is_empty():
		return
	(_plain["label"] as Label).text = "Ship Name" if Ships else "Fleet Name"
	(_plain["toggle"] as Button).text = "Fleet Finder" if Ships else "Ship Finder"
	var tabs: TabBar = _plain["tabs"]
	for i in tabs.tab_count:
		tabs.set_tab_title(i, Caption(i))
	var list: ItemList = _plain["list"]
	list.clear()
	for e in _shown:
		list.add_item((e as Entry).Name)
	(get_node("%TitleBarLabel") as Label).text = " " + ("Ship Finder" if Ships else "Fleet Finder")
