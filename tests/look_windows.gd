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
