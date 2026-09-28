extends SceneTree
## The watch that can foil a mission is the units DEFENDING the target -
## "Any unit defending a system - fighters, troops, and capital ships - has a
## chance at detecting a mission team" (manual p103) - never the team's own
## side: its fleet over the target, or its regiments there, counted towards
## catching it. (Special Forces detect nothing: the pack's are all 0.)
##
##   .\tools\run-gd.ps1 tests/foil_watch.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[foil_watch] ok   %s" % what)
	else:
		_fails += 1
		print("[foil_watch] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var alliance: Faction = FactionRegistry.ById("alliance")
	var empire: Faction = FactionRegistry.ById("empire")
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == empire and Lq.any(p.Garrison, func(u): return u.Detection > 0))
	_check(target != null, "an Imperial world with a garrison that watches")
	if target == null:
		_finish()
		return
	var defenders := Lq.sum(Lq.where(target.Garrison, func(u): return u.Faction != alliance), func(u): return u.Detection) \
		+ Lq.sum(Lq.where(target.FighterSquadrons, func(u): return u.Faction != alliance), func(u): return u.Detection) \
		+ Lq.sum(Lq.where(target.OrbitingFleets, func(f): return f.Faction != alliance), func(f): return Lq.sum(f.Ships, func(s): return s.Detection))

	# The team's side: a regiment of theirs standing there, beside the team.
	var reg_def = Lq.first_or_null(MilitaryCatalog.All(), func(d): return d.Kind == "troop" and d.stat("detection") > 0)
	var best: Unit = MilitaryCatalog.Create(reg_def, alliance, null)
	MilitaryCatalog.Relocate(best, target)
	var m := Mission.new()
	m.Faction = alliance
	m.Target = target
	m.Team = []
	_check(defenders > 0 and best.Detection > 0 and target.Garrison.has(best), "%s watches (%d); an Alliance %s (Detection %d) stands there too" % [target.Name, defenders, best.Name, best.Detection])

	# An Alliance fleet over the target too.
	var ours: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == alliance and ours == null:
				ours = f
	if ours != null:
		target.OrbitingFleets.append(ours)
	var seen: int = MissionManager.Watch(m)
	_check(seen == defenders, "the watch is the defenders' alone (%d; defenders %d, the team's own %d%s)" % [
		seen, defenders, best.Detection, (", and fleet %s" % ours.Name) if ours != null else ""])
	if ours != null:
		target.OrbitingFleets.erase(ours)
	_finish()


func _finish() -> void:
	print("[foil_watch] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
