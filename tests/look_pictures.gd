extends SceneTree
## A LOOK'S PICTURES FILL THEIR SPACE (TeeJ, 2026-09-30, the WWII windows).
## One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_pictures.gd -- --pack=ww2 --seed=12345
##
## - A facility's Status window: its picture fills its box ("it would be nice
##   if the pictures filled up the space without black bars") - the box is the
##   picture's shape, the picture the Encyclopedia plate, drawn smaller.
## - The Defenses window's Personnel tab: each person a card, the portrait over
##   the name, the cards in rows that wrap, a row's cards one height ("better
##   like how SWR shows it").
## A pack without a look has nothing to check.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_pictures] ok   %s" % what)
	else:
		_fails += 1
		print("[look_pictures] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-pictures-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if not Look.Active():
		print("[look_pictures] %s has no look: nothing to check" % FactionRegistry.LoadedId())
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

	# A FACILITY'S STATUS: one of every family the side has, each filling its box.
	var seen := {}
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for fac in p.Facilities:
			if fac.Def == null or seen.has(fac.Family()):
				continue
			seen[fac.Family()] = true
			ui.CloseAllWindows()
			for _i in 2:
				await process_frame
			ui.OpenDefenseFacilityStatusWindow(fac)
			for _i in 3:
				await process_frame
			var w: Node = Lq.first_or_null(ui._openWindows.values(), func(x) -> bool: return x is DefenseFacilityStatusWindow)
			var box: Control = (w.get_node("%IconLabel") as Control).get_parent() if w != null else null
			var pic: TextureRect = box.get_node_or_null("Picture") if box != null else null
			var want: Texture2D = Art.Picture("facilities", fac.Def.Id)
			if want == null:
				want = Art.Portrait("facilities", fac.Def.Id)
			if want == null:
				continue
			var tex_ratio: float = float(want.get_width()) / want.get_height()
			var box_ratio: float = box.size.x / box.size.y if box != null and box.size.y > 0 else 0.0
			_check(pic != null and pic.texture == want and absf(box_ratio - tex_ratio) < 0.02 and box.size.y <= DefenseFacilityStatusWindow.BoxH + 0.5,
				"%s Status: the picture fills its box (%s, picture %.2f:1, box %.2f:1)" % [fac.Name(), str(box.size) if box != null else "none", tex_ratio, box_ratio])

	# THE PERSONNEL TAB: cards.
	var home: Planet = null
	for p in GameState.AllPlanets():
		var ours: int = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached == p).size()
		if p.ControllingFaction == us and ours >= 2 and (home == null or ours > Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached == home).size()):
			home = p
	_check(home != null, "a world of ours with two or more people on it")
	if home != null:
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnDefenseClicked(home)
		for _i in 4:
			await process_frame
		var dw: Node = Lq.first_or_null(ui._openWindows.values(), func(x) -> bool: return x is DefenseWindow)
		var list: Node = dw.get_node("%PersonnelList") if dw != null else null
		var cards: Array = list.find_children("*", "CharacterMenuButton", true, false) if list != null else []
		_check(cards.size() >= 2, "%s: the people are on the Personnel tab (%d)" % [home.Name, cards.size()])
		var bad: Array = []
		for c in cards:
			var b := c as Button
			var who: Character = b.get("CharacterData")
			var portrait: Texture2D = Art.Portrait("characters", who.PackId)
			if not b.has_meta("picture_card") or b.icon != portrait or b.vertical_icon_alignment != VERTICAL_ALIGNMENT_TOP \
					or b.text != who.TitledName() or not b.get_parent() is HFlowContainer:
				bad.append(who.Name)
		_check(bad.is_empty(), "%s: each person a card, the portrait over the name%s" % [home.Name, "" if bad.is_empty() else " - not: " + ", ".join(bad)])
		# A row's cards one height, and three to a row.
		var flow: Node = cards[0].get_parent() if not cards.is_empty() else null
		var tops := {}
		for c in cards:
			var top: float = (c as Control).position.y
			if not tops.has(top):
				tops[top] = []
			tops[top].append((c as Control).size.y)
		var even := true
		for t in tops:
			for h in tops[t]:
				even = even and absf(h - tops[t][0]) < 1.0   # within a pixel
		_check(even, "%s: a row's cards are one height %s" % [home.Name, str(tops)])
		var per_row: int = 0
		for t in tops:
			per_row = maxi(per_row, tops[t].size())
		_check(cards.size() < 3 or per_row == 3, "%s: three cards to a row (%d, the row %.0f px)" % [home.Name, per_row, (flow as Control).size.x if flow != null else 0.0])

	print("[look_pictures] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
