class_name CaptivityManager
extends RefCounted
## backend/CaptivityManager.cs - ESCAPE FROM CAPTURE, ESCAPETB.DAT (table id 44).
##   score = prisoner.Combat + prisoner.Espionage - meanGuardCombat - enemyTroopCount
## on a timer of entries 45/46 (a tick is treated as a day).


static func ProcessDay(galaxy: Array, day: int, rng: Prng) -> void:
	var roster := GameState.ActiveRoster
	if roster == null or galaxy == null:
		return
	for prisoner in roster:
		if not prisoner.IsCaptured() or prisoner.Status == Enums.Status.Dead:
			continue
		if not prisoner.CanEscape:
			continue
		if prisoner.AtJabbasPalace:
			continue
		if prisoner.NextEscapeAttemptOn <= 0:
			prisoner.NextEscapeAttemptOn = day + max(1, RuleManager.Roll(RuleId.EscapeTimerBase, RuleId.EscapeTimerSpread, rng, prisoner.Faction))
			continue
		if day < prisoner.NextEscapeAttemptOn:
			continue
		prisoner.NextEscapeAttemptOn = day + max(1, RuleManager.Roll(RuleId.EscapeTimerBase, RuleId.EscapeTimerSpread, rng, prisoner.Faction))
		TryEscape(prisoner, galaxy, day, rng)


static func TryEscape(prisoner: Character, galaxy: Array, day: int, rng: Prng) -> void:
	var captor := prisoner.CapturedBy
	var held := prisoner.Attached

	var guards := Lq.where(GameState.ActiveRoster, func(c):
		return c.Faction == captor and c.Attached != null and c.Attached == held \
			and c.Status != Enums.Status.Dead and not c.IsCaptured())
	var mean_guard := 0 if guards.is_empty() else Lq.sum(guards, func(c): return c.CombatRating) / guards.size()

	var troops := 0
	if held is Planet:
		troops = Lq.count((held as Planet).Garrison, func(u): return u.Type == Enums.UnitType.Troop and u.Faction == captor)

	var score := prisoner.CombatRating + prisoner.EspionageRating - mean_guard - troops
	var chance := MissionTableManager.Lookup(MissionTableManager.Escape, score)
	if chance < 0:
		return
	print("[Captivity] %s tested the bars at %s: score %d (combat %d + espionage %d - guards %d - troops %d) -> %d%%." % [
		prisoner.Name, held.Name if held != null else "captivity", score, prisoner.CombatRating, prisoner.EspionageRating, mean_guard, troops, chance])
	if rng.NextRange(1, 101) > chance:
		return

	var home := HomeFor(prisoner.Faction, galaxy)
	prisoner.CapturedBy = null
	prisoner.NextEscapeAttemptOn = 0
	prisoner.Status = Enums.Status.AwaitingOrders
	prisoner.Attached = home
	print("[Captivity] %s ESCAPED to %s." % [prisoner.Name, home.Name if home != null else "our forces"])

	# "EVASION BONUS" (manual p094), gated on being Force-aware; entry 58.
	if prisoner.IsKnownJedi:
		prisoner.JediLevel += RuleManager.Get(RuleId.OrdinaryMissionForceReward, prisoner.Faction)

	if not GameSettings.IsHuman(prisoner.Faction):
		return
	EventBus.Tell(prisoner.Faction, GameMessage.new("%s has escaped" % prisoner.Name,
		"%s has got out of enemy hands and reached %s." % [prisoner.Name, home.Name if home != null else "our forces"],
		Enums.MessageCategory.Missions, day, home if home is Planet else null, prisoner))


static func HomeFor(f: Faction, galaxy: Array) -> Location:
	if f == null:
		return null
	var worlds := []
	for s in galaxy:
		for p in s.Planets:
			if p.ControllingFaction == f:
				worlds.append(p)
	if worlds.is_empty():
		return null
	var seat: String = f.Hq.Planet if f.Hq != null else ""
	var at_seat: Planet = Lq.first_or_null(worlds, func(p): return p.Name == seat)
	return at_seat if at_seat != null else worlds[0]
