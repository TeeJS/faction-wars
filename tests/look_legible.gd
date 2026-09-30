extends SceneTree
## EVERY WORD IN A LOOK'S WINDOWS CAN BE READ (docs: the WWII windows fix,
## step 1; TeeJ, 2026-09-30: "things are very hard to read"). One pack per
## process:
##
##   .\tools\run-gd.ps1 tests/look_legible.gd -- --pack=ww2 --seed=12345
##
## Opens every window the game opens - and every tab of each - and reads every
## visible piece of text in it: none may be smaller than the look's `small`
## size (13 px), and none may sit at less than 4.5:1 contrast on what is
## behind it (3:1 for a disabled control's). Prints each offender: the window,
## the node, its words, its size and its colours. A pack without a look has
## nothing to check.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const LookWindow := preload("res://src/ui/look_window.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_legible] ok   %s" % what)
	else:
		_fails += 1
		print("[look_legible] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-legible-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if not Look.Active():
		print("[look_legible] %s has no look: nothing to check" % FactionRegistry.LoadedId())
		quit(0)
		return
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
	# The world of ours with the most on it: the headquarters, as a rule.
	var home: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction == us and (home == null or p.Facilities.size() > home.Facilities.size()):
			home = p
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us)
	var fac: Facility = Lq.first_or_null(home.Facilities, func(f: Facility) -> bool: return f.Def != null)

	var openers := [
		["the Encyclopedia", func() -> void: ui.OpenEncyclopedia("characters", who.PackId)],
		["Manufacturing", func() -> void: ui.OnEconomyClicked(home)],
		["Defenses", func() -> void: ui.OnDefenseClicked(home)],
		["Fleets", func() -> void: ui.OnFleetClicked(home)],
		["the sector window", func() -> void: ui.OnSectorClicked(sector)],
		["a character's Status", func() -> void: ui.OpenCharacterStatusWindow(who)],
		["a facility's Status", func() -> void: ui.OpenDefenseFacilityStatusWindow(fac)],
		["the Message Index", func() -> void: ui.OnMessageIndexClicked("All")],
		["the Personnel Finder", func() -> void: ui.OpenPersonnelFinder()],
		["the System Finder", func() -> void: ui.OpenPlanetFinder()],
		["the Fleet Finder", func() -> void: ui.OpenFleetFinder()],
		["the Troop Finder", func() -> void: ui.OpenTroopFinder()],
		["Game Options", func() -> void: ui.OpenGameOptions()],
		["the Galaxy Overview", func() -> void: ui.OpenGalaxyOverview()],
		["Objectives", func() -> void: ui.OpenObjectives()],
	]
	for o in openers:
		var what: String = o[0]
		var before: Array = _windows(ui)
		(o[1] as Callable).call()
		for _i in 4:
			await process_frame
		var opened: Array = _windows(ui).filter(func(w: Node) -> bool: return not before.has(w))
		_check(not opened.is_empty(), "%s opened" % what)
		for w in opened:
			var tabs: Array = (w as Node).find_children("*", "TabContainer", true, false)
			if tabs.is_empty():
				_audit(w, what)
				continue
			# Every tab of every tab set, one at a time.
			for t in tabs:
				var tc := t as TabContainer
				for i in tc.get_tab_count():
					if tc.is_tab_disabled(i):
						continue
					tc.current_tab = i
					for _i in 3:
						await process_frame
					_audit(w, "%s, tab %s" % [what, tc.get_tab_title(i)])
		_close(ui)
		for _i in 3:
			await process_frame
	print("[look_legible] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Every visible piece of text under `w`: its size and its contrast.
func _audit(w: Node, what: String) -> void:
	var floor_px: int = Look.Size("small")
	var bad: Array[String] = []
	var seen := 0
	for n in (w as Node).find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var words := _words(c)
		if words.strip_edges().is_empty() or LookWindow._is_symbol(c):
			continue
		seen += 1
		var size: int = _size(c)
		var fg: Color = _colour(c)
		var bg: Color = LookWindow.Background(c)
		var need: float = 3.0 if (c is BaseButton and (c as BaseButton).disabled) else 4.5
		var ratio: float = Look.Contrast(_over(fg, bg), bg)
		if size < floor_px or ratio < need:
			bad.append("%s \"%s\" %dpx %s on %s = %.1f:1" % [w.get_path_to(c), words.left(40), size, fg.to_html(false), bg.to_html(false), ratio])
	_check(seen > 0 and bad.is_empty(), "%s: %d pieces of text, all %d px or larger at %s:1 or better%s" % [
		what, seen, floor_px, "4.5", "" if bad.is_empty() else "\n      " + "\n      ".join(bad.slice(0, 12)) + ("\n      ... and %d more" % (bad.size() - 12) if bad.size() > 12 else "")])


static func _words(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).text if not (c as LineEdit).text.is_empty() else (c as LineEdit).placeholder_text
	return ""


static func _size(c: Control) -> int:
	if c is RichTextLabel:
		return c.get_theme_font_size("normal_font_size")
	return c.get_theme_font_size("font_size")


static func _colour(c: Control) -> Color:
	if c is RichTextLabel:
		return c.get_theme_color("default_color")
	if c is LineEdit and (c as LineEdit).text.is_empty():
		return c.get_theme_color("font_placeholder_color")
	if c is BaseButton and (c as BaseButton).disabled:
		return c.get_theme_color("font_disabled_color")
	if c is Button and (c as Button).button_pressed and (c as Button).toggle_mode:
		return c.get_theme_color("font_pressed_color")
	return c.get_theme_color("font_color")


## A see-through colour as it lands on `bg`.
static func _over(fg: Color, bg: Color) -> Color:
	return Color(lerpf(bg.r, fg.r, fg.a), lerpf(bg.g, fg.g, fg.a), lerpf(bg.b, fg.b, fg.a), 1.0)


func _windows(ui: UIManager) -> Array:
	var out: Array = []
	for n in ui.get_tree().root.find_children("*", "Control", true, false):
		if LookWindow.IsWindow(n) and (n as Control).is_visible_in_tree():
			out.append(n)
	return out


func _close(ui: UIManager) -> void:
	ui.CloseAllWindows()
	for n in ui.get_tree().root.find_children("*", "Control", true, false):
		if n is GameOptionsWindow or n is GalaxyOverviewWindow or n is ObjectivesWindow:
			n.queue_free()
