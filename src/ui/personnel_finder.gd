class_name PersonnelFinder
extends DraggableWindow
## frontend/PersonnelFinder.cs - the Personnel Finder (manual p039, p045,
## p098-p100; figs 2.31, 2.39, 3.42-3.43).
##
## With the art imported it is the original's (src/ui/original_finder.gd;
## TeeJ's screenshots of both sides' characters and special forces,
## 2026-09-24: "Char Info should be renamed Personnel Finder and should have
## the same UI as the original - note the side buttons for characters and
## Special Forces"): the Name field, a tab per side, and two views switched by
## the frame's buttons - the characters, "Name - Location" in a smaller face,
## and the special forces, a grid of counts per system under each type's icon.
## Display "closes the finder and opens the System window for the selection -
## system defenses, fleet or mission - in which the character appears".

const OF := preload("res://src/ui/original_finder.gd")
const TabStems := ["finder_tab_rebel", "finder_tab_imperial"]
## The special forces band's four icons per side, left to right (STRATEGY
## 10538 / 10539, matched by eye against the portraits). The Empire's bounty
## hunters have no column in the original.
const SpecForceColumns := {
	"alliance": ["bothan_spies", "infiltrators", "guerrillas", "longprobe_y_wing_recon_team"],
	"empire": ["imperial_commandos", "imperial_espionage_droid", "noghri_death_commandos", "imperial_probe_droid"],
}
## Measured on TeeJ's screenshots: the characters' band caption from y 115,
## their names (Arial 11) a row every 20 from 144; the special forces' band
## caption from 119, their grid from 141, a row every 20, eight showing,
## its column rules at x 255 + 28i.
const CaptionY := 115
const ListTop := 144
const SFCaptionY := 119
const SFGridTop := 141
const SFColumnXs := [255, 283, 311, 339]

var _allianceList: VBoxContainer
var _empireList: VBoxContainer
var _searchBar: LineEdit


func _ready() -> void:
	super()   # Retains drag & close functionality
	if OF.CanBuild(["finder_personnel.alliance", "finder_personnel.empire", "finder_specforces.alliance",
			"finder_specforces.empire"], TabStems, ["finder_display", "finder_btn_characters", "finder_btn_specforces"]):
		_BuildOriginal()
		return

	_allianceList = get_node("%AllianceList")
	_empireList = get_node("%EmpireList")

	_searchBar = get_node("%SearchBar")

	# Dynamically update the lists every time the user types a letter!
	_searchBar.text_changed.connect(PopulateLists)

	PopulateLists("")   # Initial load of everyone


## UIManager passes itself in so this window can spawn other windows
func Setup(uiManager: UIManager) -> void:
	_uiManager = uiManager


func PopulateLists(filterText: String) -> void:
	# 1. Clear out the old lists
	for child in _allianceList.get_children():
		child.queue_free()
	for child in _empireList.get_children():
		child.queue_free()

	if GameState.ActiveRoster == null:
		return

	var player: Faction = GameSettings.PlayerFaction
	var lowerFilter: String = filterText.to_lower().strip_edges()

	# --- 2a. OUR OWN SIDE: never fogged from us, so the live location stands. ---
	for c in GameState.ActiveRoster:
		if c.Faction != player:
			continue
		# "NOTE: YOU CANNOT LOCATE LUKE WHEN HE IS AT DAGOBAH, or Han Solo, Luke,
		# Leia, or Chewbacca if they are at Jabba's palace." (p100) Concealment
		# applies to your OWN side; he is simply not findable. Both places count -
		# see Character.IsOffMap.
		if c.IsOffMap():
			continue
		# Not yet recruited: nowhere to be, not listed.
		if c.Attached == null:
			continue
		if not lowerFilter.is_empty() and not c.Name.to_lower().contains(lowerFilter):
			continue
		var loc: String = c.Attached.Name
		_AddCharacterRow(c, "%s - %s" % [c.Name, loc], func() -> void: OnCharacterClicked(c))

	# --- 2b. SOMEBODY ELSE'S SIDE: only where we have actually SEEN them. ---
	# ⚠ THE ENEMY'S ROSTER IS NOT FREE INFORMATION, AND THIS WINDOW WAS GIVING IT
	# AWAY. The old code gated an enemy on Knows() AT THEIR LIVE LOCATION - i.e. "we
	# once scouted the world they happen to stand on TODAY", not "we saw them there"
	# - so a player read "Wedge Antilles - Selonia" off a system their sensors had
	# reported nothing new about in weeks. Fig 3.42's list is a record of SIGHTINGS;
	# this rebuilds it from the dated Characters snapshots, showing each enemy at the
	# world and on the day we last saw them, never their live position.
	var seen: Dictionary = _EnemySightings(player)
	for c in GameState.ActiveRoster:
		if c.Faction == null or c.Faction == player:
			continue
		if not seen.has(c.Name):
			continue
		if not lowerFilter.is_empty() and not c.Name.to_lower().contains(lowerFilter):
			continue
		var where: Planet = seen[c.Name]["planet"]
		var day: int = int(seen[c.Name]["day"])
		_AddCharacterRow(c, "%s - %s (day %d)" % [c.Name, where.Name, day], func() -> void: _OpenDefense(where))


## One clickable, coloured row on the correct side tab.
## NOTE: this panel has exactly two lists bound in the scene, so it is still
## 2-faction-shaped. Routing by pack order removes the hardcoded identity, but a
## 3-4 faction pack needs the tabs built dynamically (PROJECT.md, Phase 3 UI item).
func _AddCharacterRow(c: Character, text: String, onClick: Callable) -> void:
	var charBtn := Button.new()
	charBtn.text = text
	charBtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	charBtn.flat = true
	var nameColor: Color = c.Faction.FactionColor if c.Faction != null else FactionRegistry.Unknown.FactionColor
	charBtn.add_theme_color_override("font_color", nameColor)
	charBtn.add_theme_font_size_override("font_size", 14)
	charBtn.pressed.connect(onClick)
	var side: int = FactionRegistry.OrderOf(c.Faction)
	if side <= 0:
		_allianceList.add_child(charBtn)
	else:
		_empireList.add_child(charBtn)


## name -> {planet, day}: the most recently seen world for each enemy character,
## read from the dated Characters snapshots (our own worlds' live rosters included -
## who stands on a world WE hold is legitimately ours to see). An agent on a mission
## is hidden and never listed (issue #2a / tests/onmission_fog.gd).
func _EnemySightings(player: Faction) -> Dictionary:
	var out: Dictionary = {}
	for p in GameState.AllPlanets():
		var v: IntelManager.IntelView = IntelManager.View(player, p, Enums.IntelSection.Characters)
		if not v.Known:
			continue
		for line in v.Lines:
			var c: Character = _CharForLine(str(line))
			if c == null or c.Faction == player or c.Status == Enums.Status.OnMission:
				continue
			if not out.has(c.Name) or int(out[c.Name]["day"]) < v.Day:
				out[c.Name] = { "planet": p, "day": v.Day }
	return out


## Match a Characters line ("Name" or "Rank Name") back to a roster entry - the
## line always ends with the character's Name (IntelManager.Render, Characters).
func _CharForLine(line: String) -> Character:
	for c in GameState.ActiveRoster:
		if line == c.Name or line.ends_with(" " + c.Name):
			return c
	return null


## Open a world's Defense window - the destination for an enemy we saw there.
func _OpenDefense(planet: Planet) -> void:
	if _uiManager == null:
		return
	_uiManager.OpenWindow(
		"Defense_%s" % planet.Name,
		_uiManager.DefenseWindowTemplate,
		func(window) -> void: window.Populate(planet, _uiManager),
		Vector2(250, 150))


func OnCharacterClicked(character: Character) -> void:
	if character.Attached == null:
		print("%s is currently unassigned or in transit. No location to display." % character.Name)
		return

	# C# Pattern Matching: Safely checks if the Attached Location is a Planet,
	# and if it is, casts it to the variable 'planet' instantly.
	if character.Attached is Planet:
		var planet: Planet = character.Attached as Planet
		# Route through UIManager to spawn the Defense Window
		_uiManager.OpenWindow(
			"Defense_%s" % planet.Name,
			_uiManager.DefenseWindowTemplate,
			func(window) -> void: window.Populate(planet, _uiManager),
			Vector2(250, 150)   # Slightly offset so it doesn't overlap perfectly
		)
	else:
		# TODO: In the future, check `if (character.Attached is Fleet fleet)`
		print("TODO: %s is on %s (Ship/Fleet). Fleet window not yet implemented." % [character.Name, character.Attached.Name])


# ---- the original's ---------------------------------------------------------------

var _o: Dictionary = {}
var _grid: Control = null
var _tab: int = 0
var SpecForces: bool = false     # the special forces view, else the characters
var _shown: Array = []


## One line: a character (with where), or a system / fleet of special forces.
class Entry:
	var Text: String
	var Char: Character
	var Where: Planet
	var Fleet_: Fleet
	var Counts: Dictionary = {}


static func SideOf(tab: int) -> Faction:
	return FactionRegistry.Playable[tab] if tab < FactionRegistry.Playable.size() else null


## "Alliance Personnel", "Imperial Personnel" - on both views.
static func Caption(tab: int) -> String:
	var f: Faction = SideOf(tab)
	return "%s Personnel" % (f.Adjective if f != null else "")


func _BuildOriginal() -> void:
	var tabs: Array = []
	for i in TabStems.size():
		tabs.append([TabStems[i], Caption(i)])
	_o = OF.Build(self, "Personnel Finder", "Name", OUI.Pic("finder_personnel.alliance"), tabs, [
		["finder_display", "Open the System window in which the selection appears."],
		["finder_btn_characters", "Characters."],
		["finder_btn_specforces", "Special Forces."],
	])
	var list: Control = _o["list"]
	list.set("px", 11.0)
	list.position.y = ListTop * OUI.K
	var grid = OF.OriginalGrid.new()
	grid.name = "Grid"
	grid.k = OUI.K
	grid.font = OUI.Face()
	grid.Pitch = 20
	grid.Shown = 8
	grid.NameCap = 7.0
	grid.position = Vector2(OF.ListAt.x, SFGridTop) * OUI.K
	grid.size = OF.ListSize * OUI.K
	for x in SFColumnXs:
		grid.columns.append(float(x) - OF.ListAt.x)
	(_o["body"] as Control).add_child(grid)
	(_o["body"] as Control).move_child(grid, list.get_index())
	_grid = grid
	for i in _o["tabs"].size():
		var tab: int = i
		(_o["tabs"][i] as TextureButton).pressed.connect(func() -> void: ShowTab(tab, true))
	(_o["buttons"]["finder_display"] as TextureButton).pressed.connect(Display)
	(_o["buttons"]["finder_btn_characters"] as TextureButton).pressed.connect(func() -> void: SetSpecForces(false))
	(_o["buttons"]["finder_btn_specforces"] as TextureButton).pressed.connect(func() -> void: SetSpecForces(true))
	list.connect("item_activated", func(_i: int) -> void: Display())
	grid.item_activated.connect(func(_i: int) -> void: Display())
	(_o["field"] as LineEdit).text_changed.connect(func(t: String) -> void: OF.Locate(_Active(), t))
	(_o["field"] as LineEdit).text_submitted.connect(func(_t: String) -> void: Display())
	var mine: int = maxi(0, FactionRegistry.Playable.find(GameSettings.PlayerFaction))
	SetSpecForces(false, mine, false)


## The list or the grid, whichever view is on.
func _Active() -> Control:
	return _grid if SpecForces else _o["list"]


## Switch between the characters and the special forces: the view's plate,
## band, list and lit button; the scroll bar follows the view on show.
func SetSpecForces(on: bool, tab: int = -1, pick: bool = false) -> void:
	SpecForces = on
	var list: Control = _o["list"]
	list.visible = not on
	_grid.visible = on
	var bar: Control = _o["bar"]
	for c in bar.get_signal_connection_list("scrolled"):
		bar.disconnect("scrolled", c["callable"])
	bar.connect("scrolled", _Active().scroll_to)
	list.set("bar", null if on else bar)
	_grid.set("bar", bar if on else null)
	bar.position.y = ((SFGridTop if on else ListTop) + 2) * OUI.K
	(_o["header"] as Label).position.y = (SFCaptionY if on else CaptionY) * OUI.K
	OF.SetCurrent(_o["buttons"]["finder_btn_characters"], not on)
	OF.SetCurrent(_o["buttons"]["finder_btn_specforces"], on)
	ShowTab(_tab if tab < 0 else tab, pick)


## Show a side: its plate for the view, its lines.
func ShowTab(tab: int, pick: bool) -> void:
	_tab = tab
	var side: Faction = SideOf(tab)
	var skin: String = OUI.Side(side) if side != null else "alliance"
	for i in _o["tabs"].size():
		(_o["tabs"][i] as TextureButton).set_pressed_no_signal(i == tab)
	(_o["plate"] as TextureRect).texture = OUI.Pic(("finder_specforces." if SpecForces else "finder_personnel.") + skin)
	(_o["header"] as Label).text = Caption(tab)
	var view: Control = _Active()
	view.call("clear")
	_shown = SpecForceRows(side) if SpecForces else CharactersOf(side)
	for e in _shown:
		var en: Entry = e
		if SpecForces:
			var counts: Array = []
			for id in SpecForceColumns.get(skin, []):
				counts.append(int(en.Counts.get(id, 0)))
			view.call("add_item", en.Text, counts)
		else:
			view.call("add_item", en.Text)
	if pick and not _shown.is_empty():
		view.call("select", 0)
	# The bar only when the view runs over.
	view.call("_sync_bar")
	var typed: String = (_o["field"] as LineEdit).text
	if not typed.strip_edges().is_empty():
		OF.Locate(view, typed)


## A side's characters: ours live ("Name - Location"), theirs where we last
## saw them (the dated Characters sightings, never their live position).
func CharactersOf(side: Faction) -> Array:
	var player: Faction = GameSettings.PlayerFaction
	var out: Array = []
	if side == null:
		return out
	if side == player:
		for c in GameState.ActiveRoster:
			# Only those in play: an undeployed character - not yet recruited -
			# has nowhere to be (MissionManager.Recruitable); the original lists
			# none (TeeJ's screenshot: the eight in play).
			if c.Faction != side or c.IsOffMap() or c.Status == Enums.Status.Dead or c.Attached == null:
				continue
			var e := Entry.new()
			e.Char = c
			e.Text = "%s - %s" % [c.Name, c.Attached.Name if c.Attached != null else "Unknown"]
			e.Where = c.Attached as Planet if c.Attached is Planet else ((c.Attached as Fleet).Attached as Planet if c.Attached is Fleet else null)
			out.append(e)
	else:
		var seen: Dictionary = _EnemySightings(player)
		for c in GameState.ActiveRoster:
			if c.Faction != side or not seen.has(c.Name):
				continue
			var e := Entry.new()
			e.Char = c
			e.Where = seen[c.Name]["planet"]
			e.Text = "%s - %s" % [c.Name, e.Where.Name]
			out.append(e)
	out.sort_custom(func(a: Entry, b: Entry) -> bool: return a.Text.naturalnocasecmp_to(b.Text) < 0)
	return out


## A side's special forces by system or fleet: ours live; theirs as sighted
## on a system, or standing on a world of ours.
static func SpecForceRows(side: Faction) -> Array:
	var viewer: Faction = GameSettings.PlayerFaction
	var out: Array = []
	if side == null or GameState.ActiveGalaxy == null:
		return out
	for p in GameState.AllPlanets():
		var here := Entry.new()
		here.Text = p.Name
		here.Where = p
		if side == viewer or IntelManager.IsLive(viewer, p):
			for u in p.SpecForces():
				if u.Faction == side:
					here.Counts[u.PackId] = int(here.Counts.get(u.PackId, 0)) + 1
		else:
			var view: IntelManager.IntelView = IntelManager.View(viewer, p, Enums.IntelSection.SpecForces)
			if view.Known:
				for line in view.Lines:
					var id: String = TroopFinder._unit_id_named(str(line))
					if not id.is_empty():
						here.Counts[id] = int(here.Counts.get(id, 0)) + 1
		if not here.Counts.is_empty():
			out.append(here)
		for f in p.OrbitingFleets:
			if f.Faction != side or side != viewer:
				continue
			var aboard := Entry.new()
			aboard.Text = f.Name
			aboard.Where = p
			aboard.Fleet_ = f
			for s in f.Ships:
				for u in [s] + s.Hangar:
					if u.Type == Enums.UnitType.SpecForce:
						aboard.Counts[u.PackId] = int(aboard.Counts.get(u.PackId, 0)) + 1
			if not aboard.Counts.is_empty():
				out.append(aboard)
	out.sort_custom(func(a: Entry, b: Entry) -> bool: return a.Text.naturalnocasecmp_to(b.Text) < 0)
	return out


func Selected() -> Entry:
	var picked: PackedInt32Array = _Active().call("get_selected_items")
	return _shown[picked[0]] if not picked.is_empty() and picked[0] < _shown.size() else null


## The System window "in which the character appears": on a mission, the
## Mission window; aboard a fleet, the Fleet window; else System Defenses -
## with the sector - and the Finder closes. An opponent we have no sighting
## of is not listed, so no window appears for one.
func Display() -> void:
	var e: Entry = Selected()
	if e == null or e.Where == null or _uiManager == null:
		return
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(e.Where))
	if sector != null:
		_uiManager.OnSectorClicked(sector)
	var ours: bool = e.Char != null and e.Char.Faction == GameSettings.PlayerFaction
	if e.Fleet_ != null or (ours and e.Char.Attached is Fleet):
		_uiManager.OnFleetClicked(e.Where)
	elif ours and e.Char.Status == Enums.Status.OnMission:
		_uiManager.OnMissionClicked(e.Where)
	else:
		_uiManager.OnDefenseClicked(e.Where)
	CloseWindow()
