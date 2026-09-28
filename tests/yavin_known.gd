extends SceneTree
## The Empire starts the game knowing who is at Yavin (TeeJ, 2026-09-28: "in
## the original, you always start the game knowing some rebel personnel are at
## Yavin - in ours it's always empty"). The original writes all it seeds on
## Yavin into the Empire's copy too - a snapshot, stale once they leave (the
## Empire's copy in its SAVEGAME.002 and .001). The Alliance gets no such
## look at Coruscant's people.
##
##   .\tools\run-gd.ps1 tests/yavin_known.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[yavin_known] ok   %s" % what)
	else:
		_fails += 1
		print("[yavin_known] FAIL %s" % what)


func _init() -> void:
	await process_frame
	GameSettings.PlayerFaction = FactionRegistry.ById("empire")
	GameSession.new_game("empire", Enums.Difficulty.Easy, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = FactionRegistry.ById("empire")
	var alliance: Faction = FactionRegistry.ById("alliance")
	var yavin: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.PackId == "yavin")
	var coruscant: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.PackId == "coruscant")
	_check(yavin != null and coruscant != null and yavin.ControllingFaction == alliance, "Yavin the Alliance's, Coruscant there")
	if yavin == null or coruscant == null:
		_finish()
		return
	var people: IntelManager.IntelView = IntelManager.View(empire, yavin, Enums.IntelSection.Characters)
	var text := "\n".join(people.Lines)
	var six := ["Leia Organa", "Luke Skywalker", "Han Solo", "Wedge Antilles", "Chewbacca", "Jan Dodonna"]
	_check(people.Known and not people.Live and Lq.all(six, func(n: String) -> bool: return text.contains(n)),
		"the Empire knows Yavin's six from day one (%s)" % text.replace("\n", ", "))
	_check(not text.contains("Mon Mothma"), "not Mon Mothma - she starts at the headquarters")
	var sf: IntelManager.IntelView = IntelManager.View(empire, yavin, Enums.IntelSection.SpecForces)
	_check(sf.Known and not sf.Live and (sf.Lines.size() > 0) == (not yavin.SpecForces().is_empty()),
		"and its Special Forces (%d there: %s)" % [yavin.SpecForces().size(), ", ".join(sf.Lines)])
	var theirs: IntelManager.IntelView = IntelManager.View(alliance, coruscant, Enums.IntelSection.Characters)
	_check(not theirs.Known, "the Alliance knows no one at Coruscant")
	_check(IntelManager.View(empire, yavin, Enums.IntelSection.Troopers).Known, "Yavin's regiments, as before")
	# A snapshot: Leia leaves, the Empire still has her at Yavin.
	var leia: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.PackId == "leia_organa")
	var away: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == alliance and p != yavin)
	if leia != null and away != null:
		MilitaryCatalog.Relocate(leia, away)
		var still := "\n".join(IntelManager.View(empire, yavin, Enums.IntelSection.Characters).Lines)
		_check(still.contains("Leia Organa"), "stale: Leia gone to %s, still listed at Yavin" % away.Name)
	_finish()


func _finish() -> void:
	print("[yavin_known] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
