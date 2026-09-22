extends SceneTree
## characters.json `starts_at` (SCHEMA.md section 7): a character with a
## declared opening world is standing on it at day zero, awaiting orders,
## whatever placement role they also carry. Every WWII leader with one is
## checked by name; Star Wars declares none and must be untouched.
##
##   .\tools\run-gd.ps1 tests/character_starts.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/character_starts.gd              (Star Wars: none declared)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[character_starts] ok   %s" % what)
	else:
		_fails += 1
		print("[character_starts] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game(FactionRegistry.Playable[1].Id, Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)

	var declared := 0
	for c in GameState.ActiveRoster:
		var at_id: String = FactionRegistry.CharacterStartsAt(c.PackId)
		if at_id.is_empty():
			continue
		declared += 1
		var where: String = (c.Attached as Planet).PackId if c.Attached is Planet else "nowhere"
		_check(where == at_id and c.Status == Enums.Status.AwaitingOrders,
			"%s opens at %s awaiting orders (declared %s)" % [c.Name, where, at_id])
		if c.Attached is Planet:
			_check((c.Attached as Planet).ControllingFaction == c.Faction, "%s's opening world is held by %s" % [c.Name, c.Faction.Id])
	if FactionRegistry.LoadedId() == "star-wars-rebellion":
		_check(declared == 0, "Star Wars declares no starts_at (%d)" % declared)
	else:
		_check(declared >= 20, "%d characters declare a start" % declared)

	print("[character_starts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
