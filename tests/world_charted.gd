extends SceneTree
## A PACK'S CHARTED SECTORS (map.json `starts_explored`; TeeJ, 2026-10-03:
## "WWII should start with the whole world charted"). One pack per process:
##
##   .\tools\run-gd.ps1 tests/world_charted.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/world_charted.gd -- --pack=star-wars-rebellion
##
## WWII: every territory - the uninhabited too - is charted for both sides at
## day zero, on every size; charting gives what a Core world's chart gives,
## the facilities, never the forces (a lottery-claimed enemy territory's
## troops stay unknown); and George Marshall in the United States can send
## Espionage and Diplomacy to Canada. Star Wars (no sector flagged): the Rim
## still starts unexplored.

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[world_charted] ok   %s" % what)
	else:
		_fails += 1
		print("[world_charted] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	var id := FactionRegistry.LoadedId()
	var side: Faction = FactionRegistry.Playable[0]

	if id != "ww2":
		MpSetup.reset()
		GameSession.new_game(side.Id, Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 12345)
		_check(_uncharted(side) > 0, "%s: no sector charted by the pack - the Rim starts unexplored (%d worlds)" % [id, _uncharted(side)])
		_done()
		return

	for size in [Enums.GalaxySize.Standard, Enums.GalaxySize.Huge]:
		for seed in [12345, 2]:
			MpSetup.reset()
			GameSession.new_game("allies", Enums.Difficulty.Medium, size, seed)
			var unc := 0
			for f in FactionRegistry.Playable:
				unc += _uncharted(f)
			_check(unc == 0, "size %d, seed %d: every territory charted for both sides (%d not)" % [size, seed, unc])

	MpSetup.reset()
	GameSession.new_game("allies", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 12345)
	var allies: Faction = FactionRegistry.ById("allies")
	var axis: Faction = FactionRegistry.ById("axis")
	var starts: Array = []
	for f in FactionRegistry.Playable:
		for sp in f.StartingPlanets:
			starts.append(sp.Planet)
	var hidden := 0
	var looked := 0
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if p.ControllingFaction == allies or starts.has(p.PackId):
				continue
			looked += 1
			if not IntelManager.Knows(allies, p, Enums.IntelSection.Troopers):
				hidden += 1
	_check(looked > 0 and hidden == looked, "charting shows no forces: troops unknown on all %d territories the Allies neither hold nor start beside (%d hidden)" % [looked, hidden])

	var marshall: Character = Lq.first_or_null(GameState.ActiveRoster, func(c) -> bool: return c.PackId == "marshall")
	var canada: Planet = null
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if p.PackId == "canada":
				canada = p
	var legal: Array = DraggableWindow.LegalMissions([marshall], canada, null, null)
	_check(legal.has(Enums.MissionType.Espionage), "Marshall can send Espionage to Canada (%s)" % str(legal.map(func(t) -> String: return MissionCatalog.DisplayNameFor(t))))
	if canada.ControllingFaction != axis:
		_check(legal.has(Enums.MissionType.Diplomacy), "and Diplomacy, Canada not being enemy-held")
	_done()


func _uncharted(f: Faction) -> int:
	var n := 0
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if not p.ExploredBy(f):
				n += 1
	return n


func _done() -> void:
	print("[world_charted] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
