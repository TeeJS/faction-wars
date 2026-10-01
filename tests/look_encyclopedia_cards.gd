extends SceneTree
## THE ENCYCLOPEDIA'S FILE CARDS (src/ui/encyclopedia_window.gd, TeeJ
## 2026-09-30). One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_encyclopedia_cards.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_encyclopedia_cards.gd -- --pack=star-wars-rebellion --seed=12345
##
## A territory, a unit (ship or troop) or a facility: the ruled card on the
## left with the particulars on its lines and no heading, the picture on the
## right, no stamp box. In a look, the database's stamp across the card in
## the side's colour. A person: the picture on the left with the stamp across
## its card, the particulars centred beside it, no stamp box. A mission: as
## before (heading, stamp box). The ships' database is the pack's word:
## "Units" in WWII, "Ship" in Star Wars.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_encyclopedia_cards] ok   %s" % what)
	else:
		_fails += 1
		print("[look_encyclopedia_cards] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-encyclopedia-cards-none"
	StandIns.Enabled = false   # the plain window: Star Wars would otherwise build the original's from stand-ins
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
	ui.OpenEncyclopedia()
	for _i in 3:
		await process_frame
	var w: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var id := FactionRegistry.LoadedId()
	var look := Look.Active()

	_check(w._tabs[2].text == ("Units" if id == "ww2" else "Ship"), "%s: the ships' database is \"%s\"" % [id, w._tabs[2].text])

	# One of each kind the card holds.
	var unit_axis: PackDefs.UnitDef = null
	for u in pack.Units:
		if u.BuildableBy.size() == 1 and unit_axis == null:
			unit_axis = u
	var cases: Array = [
		[EncyclopediaWindow.KindSystem, pack.Map.Planets[0].Id],
		[EncyclopediaWindow.KindUnit, unit_axis.Id],
		[EncyclopediaWindow.KindFacility, pack.Facilities[0].Id],
	]
	for c in cases:
		w.ShowTopic(c[0], c[1])
		await process_frame
		var e: EncyclopediaWindow.Entry = w.CurrentEntry()
		var what := "%s %s" % [c[0], c[1]]
		_check(w._card.visible and w._head.get_child(0) == w._card and w._head.get_child(1) == w._picture, "%s: the card on the left, the picture on the right" % what)
		_check(w._facts.get_parent() == w._card.get_node("Lines") and w._facts.get_child_count() > 0, "%s: the particulars on the card's lines" % what)
		_check(not w._factsHead.visible and not w._factsCol.visible, "%s: no PARTICULARS heading" % what)
		_check(w._stamp == null or not w._stamp.visible, "%s: no stamp box" % what)
		if look:
			_check(w._mark.get_parent() == w._card and w._mark.visible and w._mark.get("Word") == EncyclopediaWindow.DatabaseName(e.Database).to_upper(),
				"%s: the %s stamp across the card" % [what, str(w._mark.get("Word"))])
			var side: Faction = EncyclopediaWindow.SideOf(e)
			var ink: Color = w._mark.get("Ink")
			var want: Color = side.FactionColor.darkened(0.12) if side != null else Look.C("ink_muted")
			_check(ink.r == want.r and ink.g == want.g and ink.b == want.b, "%s: struck in %s" % [what, side.Id if side != null else "the look's ink"])

	# A person.
	var who: PackDefs.CharacterDef = pack.Characters[0]
	w.ShowTopic(EncyclopediaWindow.KindCharacter, who.Id)
	await process_frame
	_check(not w._card.visible and w._factsCol.visible and w._facts.get_parent() == w._factsCol, "a person: the particulars beside the picture, no card")
	_check(w._facts.size_flags_horizontal == Control.SIZE_SHRINK_CENTER and w._factsCol.alignment == BoxContainer.ALIGNMENT_CENTER, "a person: the particulars centred")
	_check(w._stamp == null or not w._stamp.visible, "a person: no stamp box")
	if look and w._picture.visible:
		_check(w._mark.get_parent() == w._picture and w._mark.visible and w._mark.get("Word") == "PERSONNEL", "a person: the PERSONNEL stamp across the picture's card")
		var side: Faction = FactionRegistry.ById(who.FactionId)
		var ink: Color = w._mark.get("Ink")
		_check(ink.r == side.FactionColor.darkened(0.12).r and ink.b == side.FactionColor.darkened(0.12).b, "a person: struck in %s's colour" % side.Id)

	# A mission: as it was.
	var mission: PackDefs.MissionDefPack = null
	for m in pack.Missions:
		if not m.Id.begins_with("unnamed") and mission == null:
			mission = m
	w.ShowTopic(EncyclopediaWindow.KindMission, mission.Id)
	await process_frame
	_check(not w._card.visible and w._factsHead.visible, "a mission: its particulars under their heading")
	if look:
		_check(w._stamp.visible and not w._mark.visible, "a mission: the stamp box, no struck stamp")

	print("[look_encyclopedia_cards] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
