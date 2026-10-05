extends SceneTree
## NO STAR WARS WORDS IN THE WWII GAME (TeeJ, 2026-09-30: "please review all
## of the WWII game and make sure there is no more wrong terminology used!").
## One pack per process:
##
##   .\tools\run-gd.ps1 tests/ww2_words.gd -Seconds 900 -- --pack=ww2 --seed=12345
##
## Starts a game and reads every word a player can see: the main screen, then
## every window the game opens and every tab of each (their titles, labels,
## buttons, lists, fields' hints, tooltips and menus), the agent's menu and a
## unit's, the Encyclopedia's every entry, and - after sixty days of play -
## every message received. Any Star Wars word (Words) fails, printed with
## where it was seen. A pack whose words ARE Star Wars' has nothing to check.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const LookWindow := preload("res://src/ui/look_window.gd")

## The Star Wars words, each a whole word, any case, but "the Force" - a
## WWII air force or task force is English.
const Words := ["galaxy", "galactic", "planet", "planets", "planetary", "hyperspace", "hyperdrive", "hyper-drive",
	"droid", "droids", "imperial", "empire", "rebel", "rebels", "alliance", "jedi", "sith", "stormtrooper",
	"stormtroopers", "starfighter", "starfighters", "capital ship", "capital ships", "death star", "turbolaser",
	"turbo laser", "ion cannon", "laser", "lasers", "tractor beam", "bounty hunter", "bounty hunters", "holonet",
	"holocube", "transmission", "transmissions", "sensor", "sensors", "parsec", "parsecs", "starship", "starships",
	"orbital", "orbit", "in orbit", "sector", "sectors", "system", "systems", "trooper", "troopers", "shield", "shields",
	"coruscant", "yavin", "endor", "vader", "palpatine", "mothma", "jabba", "skywalker", "sub-light", "sublight",
	# The unit-building facility builds aircraft too: WWII's are War Plants and
	# Arsenals, never shipyards (TeeJ, 2026-10-04).
	"shipyard", "shipyards", "naval yard", "naval yards", "fleet base", "fleet bases", "ship construction"]
const CaseWords := ["the Force"]
## Not the setting's words, so not a leak: the original game's name (the save
## importer's hint), the space bar, English's "message system", and the war's
## own proper names the Encyclopedia's history uses (art/descriptions.json).
const Allowed := ["Star Wars: Rebellion", "Space pause", "message system",
	"Imperial Japanese Army", "Imperial Japanese Navy", "Imperial General Staff", "Imperial German Navy",
	"Imperial Russian Navy", "British Empire", "Empire of Japan", "Dowding system",
	"eastern shipyards", "American shipyards"]

var _fails := 0
var _checks := 0
var _seen: Dictionary = {}      # "word|text" -> first place it was seen
var _rx: RegEx


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ww2_words] ok   %s" % what)
	else:
		_fails += 1
		print("[ww2_words] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-ww2-words-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.LoadedId() == "star-wars-rebellion":
		print("[ww2_words] the Star Wars pack's words are Star Wars': nothing to check")
		quit(0)
		return
	var alts: Array = []
	for w in Words:
		alts.append(RegEx.create_from_string("[\\s\\-]+").sub(w, "[\\s\\-]+", true))
	# The case words keep their case: "(?i)" at the front reaches them too.
	_rx = RegEx.create_from_string("(?i)\\b(" + "|".join(alts) + ")\\b|\\b((?-i:" + "|".join(CaseWords) + "))\\b")
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction

	# The main screen: the bars, the buttons, the sector list, their hints.
	_read(main, "the main screen")

	var home: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction == us and (home == null or p.Facilities.size() > home.Facilities.size()):
			home = p
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us)
	var fac: Facility = Lq.first_or_null(home.Facilities, func(f: Facility) -> bool: return f.Def != null)
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and not f.Ships.is_empty():
				fleet = f
	var ship: Unit = fleet.Ships[0] if fleet != null else null
	var theirs: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction != null and p.ControllingFaction != us)
	var unexplored: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return not p.ExploredBy(us))

	var openers := [
		["Manufacturing", func() -> void: ui.OnEconomyClicked(home)],
		["Defenses", func() -> void: ui.OnDefenseClicked(home)],
		["Fleets", func() -> void: ui.OnFleetClicked(home)],
		["the sector window", func() -> void: ui.OnSectorClicked(sector)],
		["the System window", func() -> void: ui.OnPlanetClicked(home)],
		["an enemy's Defenses", func() -> void: ui.OnDefenseClicked(theirs)],
		["an enemy's Fleets", func() -> void: ui.OnFleetClicked(theirs)],
		["an enemy's System window", func() -> void: ui.OnPlanetClicked(theirs)],
		["an unexplored System window", func() -> void: ui.OnPlanetClicked(unexplored)],
		["a character's Status", func() -> void: ui.OpenCharacterStatusWindow(who)],
		["a facility's Status", func() -> void: ui.OpenDefenseFacilityStatusWindow(fac)],
		["a ship's Status", func() -> void: ui.OpenUnitStatusWindow(ship)],
		["a fleet's Status", func() -> void: ui.OpenFleetStatusWindow(fleet)],
		["the Message Index", func() -> void: ui.OnMessageIndexClicked("All")],
		["the Personnel Finder", func() -> void: ui.OpenPersonnelFinder()],
		["the System Finder", func() -> void: ui.OpenPlanetFinder()],
		["the Fleet Finder", func() -> void: ui.OpenFleetFinder()],
		["the Troop Finder", func() -> void: ui.OpenTroopFinder()],
		["Game Options", func() -> void: ui.OpenGameOptions()],
		["the Overview", func() -> void: ui.OpenGalaxyOverview()],
		["Objectives", func() -> void: ui.OpenObjectives()],
		["the Encyclopedia", func() -> void: ui.OpenEncyclopedia()],
	]
	# An unexplored one only where the pack has one: WWII starts with the whole
	# world charted (map.json starts_explored, #446), so its window is skipped.
	_check(theirs != null, "an enemy's world (%s); an unexplored one: %s" % [theirs.Name if theirs != null else "-", unexplored.Name if unexplored != null else "none, the whole map is charted"])
	for o in openers:
		if (str(o[0]).begins_with("an enemy") and theirs == null) or (str(o[0]).begins_with("an unexplored") and unexplored == null):
			continue
		await _open_and_read(ui, str(o[0]), o[1])

	# The menus: the agent's, and a unit's, a character's, a fleet's.
	_read_menu(ui._AgentPopup(), "the agent's menu")
	for w in [["Fleets", func() -> void: ui.OnFleetClicked(home)], ["Defenses", func() -> void: ui.OnDefenseClicked(home)]]:
		(w[1] as Callable).call()
		for _i in 4:
			await process_frame
		for win in _windows(ui):
			for pm in (win as Node).find_children("*", "PopupMenu", true, false):
				_read_menu(pm, "%s: a right-click menu" % w[0])
		_close(ui)
		for _i in 2:
			await process_frame

	# Every Encyclopedia entry: its name and its words.
	ui.OpenEncyclopedia()
	for _i in 4:
		await process_frame
	var ency: EncyclopediaWindow = Lq.first_or_null(_windows(ui), func(w: Node) -> bool: return w is EncyclopediaWindow)
	var ency_texts := 0
	if ency != null:
		for e in ency.EntriesOf(0):
			ency_texts += 1
			_scan(e.Name, "the Encyclopedia: an entry's name")
			_scan(EncyclopediaWindow.TextFor(e), "the Encyclopedia: %s's text" % e.Name)
	_check(ency_texts > 0, "the Encyclopedia's entries read (%d)" % ency_texts)
	_close(ui)
	for _i in 2:
		await process_frame

	# Sixty days of play, then every message received.
	var engine: StrategicTickManager = main.get("_strategicEngine")
	for _d in 60:
		engine.AdvanceDay()
		await process_frame
	var messages: Array = EventBus.VisibleMessages()
	for m in messages:
		var gm := m as GameMessage
		_scan(gm.Title, "a message's title")
		_scan(gm.Body, "the message \"%s\"" % gm.Title)
	_check(messages.size() > 0, "messages read after sixty days (%d)" % messages.size())

	var words: Dictionary = {}
	for k in _seen:
		words[str(k).get_slice("|", 0)] = int(words.get(str(k).get_slice("|", 0), 0)) + 1
	for k in _seen:
		print("[ww2_words]   %-16s %s  <- %s" % [str(k).get_slice("|", 0), str(k).get_slice("|", 1).replace("\n", " ").left(110), _seen[k]])
	_check(_seen.is_empty(), "no Star Wars word anywhere in the WWII game%s" % ("" if _seen.is_empty() else " - %d places: %s" % [_seen.size(), str(words)]))
	print("[ww2_words] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _open_and_read(ui: UIManager, what: String, open: Callable) -> void:
	var before: Array = _windows(ui)
	open.call()
	for _i in 4:
		await process_frame
	var opened: Array = _windows(ui).filter(func(w: Node) -> bool: return not before.has(w))
	_check(not opened.is_empty(), "%s opened" % what)
	for w in opened:
		var tabs: Array = (w as Node).find_children("*", "TabContainer", true, false)
		_read(w, what)
		for t in tabs:
			var tc := t as TabContainer
			for i in tc.get_tab_count():
				_scan(tc.get_tab_title(i), "%s: a tab's title" % what)
				if tc.is_tab_disabled(i):
					continue
				tc.current_tab = i
				for _i in 3:
					await process_frame
				_read(w, "%s, tab %s" % [what, tc.get_tab_title(i)])
	_close(ui)
	for _i in 3:
		await process_frame


## Every word under `n` a player can see: text, hints, tooltips, menus.
func _read(n: Node, where: String) -> void:
	for c in n.find_children("*", "", true, false):
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree() and not c is PopupMenu:
			continue
		if c is Label:
			_scan((c as Label).text, where)
		elif c is Button:
			_scan((c as Button).text, where)
		elif c is RichTextLabel:
			_scan((c as RichTextLabel).get_parsed_text(), where)
		elif c is LineEdit:
			_scan((c as LineEdit).text, where)
			_scan((c as LineEdit).placeholder_text, where)
		elif c is ItemList:
			for i in (c as ItemList).item_count:
				_scan((c as ItemList).get_item_text(i), where)
		elif c is PopupMenu:
			_read_menu(c, where + ": a menu")
		if c is Control:
			_scan((c as Control).tooltip_text, where + " (a tooltip)")
		if c is Window and not c is PopupMenu:
			_scan((c as Window).title, where)


func _read_menu(pm: PopupMenu, where: String) -> void:
	if pm == null:
		return
	for i in pm.item_count:
		_scan(pm.get_item_text(i), where)
		_scan(pm.get_item_tooltip(i), where + " (a tooltip)")
	for sub in pm.get_children():
		if sub is PopupMenu:
			_read_menu(sub, where)


func _scan(text: String, where: String) -> void:
	if text.strip_edges().is_empty():
		return
	var t: String = text
	for a in Allowed:
		t = t.replace(a, "")
	for m in _rx.search_all(t):
		var word: String = m.get_string().to_lower()
		var key := "%s|%s" % [word, text.strip_edges()]
		if not _seen.has(key):
			_seen[key] = where


func _windows(ui: Node) -> Array:
	var out: Array = []
	for c in ui.get_children():
		if LookWindow.IsWindow(c) and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _close(ui: UIManager) -> void:
	ui.CloseAllWindows()
	for c in ui.get_children():
		if c is GameOptionsWindow or c is GalaxyOverviewWindow or c is ObjectivesWindow:
			c.queue_free()
