extends SceneTree
## EVERY OTHER WINDOW IN A PACK'S LOOK (look_window.gd Install / DressAny;
## docs/ww2-look-plan.md phase 6). One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_windows.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_windows.gd -- --pack=star-wars-rebellion --seed=12345
##
## With a look, each window the game opens - the Encyclopedia, Manufacturing,
## Defenses, Fleets, the sector window, a Status window, the other three
## finders, Game Options, the Galaxy Overview, Objectives - wears the look, and
## none of the plain windows' own navy, steel-blue or green is left in it, not
## even after it repaints. Without a look (Star Wars, no art set, the
## stand-ins off): every window as it was drawn.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const LookWindow := preload("res://src/ui/look_window.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_windows] ok   %s" % what)
	else:
		_fails += 1
		print("[look_windows] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-windows-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()
	_check(not GameState.ActiveGalaxy.is_empty() and main.get_script() != null and main.has_method("SetSpeed"),
		"%s: the game started (%d theatres)" % [id, GameState.ActiveGalaxy.size()])
	var us: Faction = GameSettings.PlayerFaction
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us)

	var openers := [
		["the Encyclopedia", func() -> void: ui.OpenEncyclopedia()],
		["Manufacturing", func() -> void: ui.OnEconomyClicked(home)],
		["Defenses", func() -> void: ui.OnDefenseClicked(home)],
		["Fleets", func() -> void: ui.OnFleetClicked(home)],
		["the sector window", func() -> void: ui.OnSectorClicked(sector)],
		["a Status window", func() -> void: ui.OpenCharacterStatusWindow(who)],
		["the Personnel Finder", func() -> void: ui.OpenPersonnelFinder()],
		["the Fleet Finder", func() -> void: ui.OpenFleetFinder()],
		["the Troop Finder", func() -> void: ui.OpenTroopFinder()],
		["Game Options", func() -> void: ui.OpenGameOptions()],
		["the Galaxy Overview", func() -> void: ui.OpenGalaxyOverview()],
		["Objectives", func() -> void: ui.OpenObjectives()],
	]
	var plain_seen := 0
	for o in openers:
		var what: String = o[0]
		var before: Array = _windows(ui)
		(o[1] as Callable).call()
		for _i in 3:
			await process_frame
		var opened: Array = _windows(ui).filter(func(w: Node) -> bool: return not before.has(w))
		_check(not opened.is_empty(), "%s: %s opened" % [id, what])
		for w in opened:
			var win := w as Control
			if not Look.Active():
				_check(not win.has_meta("look_dressed") and win.theme == null, "%s: as it was drawn (%s)" % [what, win.name])
				plain_seen += 1 if not _plain_left(win).is_empty() else 0
				continue
			_check(win.has_meta("look_dressed") and win.theme == Look.GetTheme(), "%s wears the look (%s)" % [what, win.name])
			var left: Array = _plain_left(win)
			_check(left.is_empty(), "%s: none of the plain colours left%s" % [what, "" if left.is_empty() else " - " + ", ".join(left.slice(0, 4))])
			if win.has_method("Refresh"):
				win.call("Refresh")
				for _i in 2:
					await process_frame
				left = _plain_left(win)
				_check(left.is_empty(), "%s: repainted, still none%s" % [what, "" if left.is_empty() else " - " + ", ".join(left.slice(0, 4))])
		for w in opened:
			if is_instance_valid(w):
				(w as Node).queue_free()
		for _i in 2:
			await process_frame
	if not Look.Active():
		# The control: the same search finds the plain colours where they are,
		# so "none left" above means none.
		_check(plain_seen >= 6, "%s: the plain colours are found in the windows as drawn (%d)" % [id, plain_seen])

	# The Galaxy Overview goes by the pack's name (TeeJ, 2026-09-30, of the
	# WWII agent's menu: "galaxy is the wrong term here!"): the menu item and
	# the window's title.
	var overview: String = Terms.label("galaxy_overview")
	_check(overview == ("World Overview" if id == "ww2" else "Galaxy Overview"), "%s: the overview is called \"%s\"" % [id, overview])
	var agent: PopupMenu = ui._AgentPopup()
	var item: String = agent.get_item_text(agent.get_item_index(3))
	_check(item == overview, "%s: the agent's menu says \"%s\"" % [id, item])
	ui.OpenGalaxyOverview()
	for _i in 3:
		await process_frame
	var gow: Node = ui.get_node_or_null("GalaxyOverviewWindow")
	var said: Array = gow.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text) if gow != null else []
	_check(said.has(overview), "%s: the overview window's title says \"%s\"" % [id, overview])
	if gow != null:
		gow.queue_free()
	for _i in 2:
		await process_frame

	# The head-to-head screens: the two that open without the relay (Locate
	# Session asks the relay for its games at once - never from a test).
	for path in ["res://src/ui/mp/MultiplayerConfiguration.tscn", "res://src/ui/mp/HostGame.tscn"]:
		var screen: Control = load(path).instantiate()
		root.add_child(screen)
		for _i in 3:
			await process_frame
		var what: String = path.get_file().get_basename()
		if not Look.Active():
			_check(not screen.has_meta("look_dressed"), "%s: %s as it was drawn" % [id, what])
			_check(not _plain_left(screen).is_empty(), "%s: its plain colours are there to find" % what)
		else:
			_check(screen.has_meta("look_dressed"), "%s: %s wears the look" % [id, what])
			var left: Array = _plain_left(screen)
			_check(left.is_empty(), "%s: none of the plain colours left%s" % [what, "" if left.is_empty() else " - " + ", ".join(left.slice(0, 4))])
			var title: Label = screen.find_child("Title", true, false)
			_check(title != null and title.get_theme_font("font") == Look.F("display"), "%s: its title in the display face" % what)
			for b in screen.get_node("%BottomBar").get_children():
				if b is Button:
					_check((b as Button).theme_type_variation == Look.COMMAND, "%s: a command key: %s" % [what, (b as Button).text])
		screen.queue_free()
		await process_frame

	# The System Finder goes by the pack's name (TeeJ, 2026-09-30:
	# "Planetary system finder is wrong for WWII as well").
	var finder_word: String = Terms.label("system_finder")
	_check(finder_word == ("Territory Finder" if id == "ww2" else "Planetary System Finder"), "%s: the finder is called \"%s\"" % [id, finder_word])
	ui.OpenPlanetFinder()
	for _i in 3:
		await process_frame
	var finder: Node = Lq.first_or_null(_windows(ui), func(w: Node) -> bool: return w is PlanetFinder)
	var finder_said: Array = finder.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text.strip_edges()) if finder != null else []
	_check(finder_said.has(finder_word) and not (id == "ww2" and finder_said.any(func(t: String) -> bool: return t.contains("Planetary"))),
		"%s: the finder's title says \"%s\"" % [id, finder_word])

	# The Encyclopedia too (TeeJ, 2026-09-30: "Galactic encyclopedia is also
	# wrong"): its title bar and its close button's hint.
	var ency_word: String = Terms.label("encyclopedia")
	_check(ency_word == ("Encyclopedia" if id == "ww2" else "Galactic Encyclopedia"), "%s: the Encyclopedia is called \"%s\"" % [id, ency_word])
	ui.OpenEncyclopedia()
	for _i in 3:
		await process_frame
	var ency: Node = Lq.first_or_null(_windows(ui), func(w: Node) -> bool: return w is EncyclopediaWindow)
	var bar: Label = ency.get_node_or_null("%TitleBarLabel") if ency != null else null
	var ency_text: Array = []
	if ency != null:
		for c in ency.find_children("*", "Control", true, false):
			ency_text.append((c as Control).tooltip_text)
			if c is Label or c is Button:
				ency_text.append(c.text)
	_check(bar != null and bar.text.strip_edges().begins_with(ency_word + " - ") and not (id == "ww2" and " ".join(ency_text).contains("Galactic")),
		"%s: the Encyclopedia's title says \"%s\"%s" % [id, bar.text.strip_edges() if bar != null else "none", "" if id != "ww2" else ", and no \"Galactic\" anywhere in it"])
	_done()


## The windows open now: the scene windows and the code-built ones.
func _windows(ui: Node) -> Array:
	var out: Array = []
	for c in ui.get_children():
		if LookWindow.IsWindow(c) and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Every place under `n` still in a plain window colour: a backdrop, a font
## override, a panel's fill or edge.
func _plain_left(n: Node) -> Array:
	var out: Array = []
	if n is ColorRect and (n as ColorRect).visible and _is(LookWindow.BG_MAP, (n as ColorRect).color):
		out.append("%s bg" % n.name)
	if n is Control:
		var c := n as Control
		for p in c.get_property_list():
			var name: String = p.name
			if name.begins_with("theme_override_colors/"):
				var key: String = name.get_slice("/", 1)
				if (key.contains("font") or key == "default_color") and not key.contains("outline") and not key.contains("shadow") \
						and c.has_theme_color_override(key):
					if _is(LookWindow.TEXT_MAP, c.get(name)):
						out.append("%s %s" % [n.name, key])
			elif name.begins_with("theme_override_styles/"):
				var sb: Variant = c.get(name)
				if sb is StyleBoxFlat and (_is(LookWindow.BG_MAP, (sb as StyleBoxFlat).bg_color) or _is(LookWindow.EDGE_MAP, (sb as StyleBoxFlat).border_color)):
					out.append("%s %s" % [n.name, name.get_slice("/", 1)])
	for ch in n.get_children():
		out.append_array(_plain_left(ch))
	return out


func _is(table: Array, col: Color) -> bool:
	for row in table:
		var plain: Color = row[0]
		if absf(plain.r - col.r) <= LookWindow.TOLERANCE and absf(plain.g - col.g) <= LookWindow.TOLERANCE and absf(plain.b - col.b) <= LookWindow.TOLERANCE:
			return true
	return false


func _done() -> void:
	print("[look_windows] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
