class_name VictoryManager
extends RefCounted
## backend/VictoryManager.cs - WINNING THE GAME, manual p011, p135-p137, p162.
## A STATE, re-evaluated every day; the one permanent condition is a destroyed
## headquarters.

static var Winner: Faction = null
static var _hq_destroyed: Dictionary = {}   # faction id -> true


static func IsOver() -> bool:
	return Winner != null


static func Reset() -> void:
	Winner = null
	_hq_destroyed.clear()


static func HeadquartersDestroyed(owner: Faction) -> void:
	if owner == null or _hq_destroyed.has(owner.Id):
		return
	_hq_destroyed[owner.Id] = true
	print("[Victory] %s headquarters destroyed - permanently." % owner.DisplayName)
	LoyaltyManager.RebelHeadquartersDestroyed(owner)


static func HasLostHeadquarters(f: Faction) -> bool:
	return f != null and _hq_destroyed.has(f.Id)


## Condition 1: derived from the OPPONENT's headquarters kind.
static func HeadquartersConditionMet(f: Faction, opponent: Faction, galaxy: Array) -> bool:
	if f == null or opponent == null:
		return false
	if opponent.HasHiddenHq():
		return HasLostHeadquarters(opponent)
	var capital: String = opponent.Hq.Planet if opponent.Hq != null else ""
	if capital.is_empty() or galaxy == null:
		return false
	for s in galaxy:
		for p in s.Planets:
			if p.Name == capital:
				return p.ControllingFaction == f
	return false


## Conditions 2 and 3 - "capture AND HOLD".
static func HoldsCaptive(f: Faction, name: String) -> bool:
	var c: Character = Lq.first_or_null(GameState.ActiveRoster, func(x): return x.Name == name)
	return c != null and c.CapturedBy == f


static func CaptureTargets(f: Faction) -> Array:
	if f == null or f.Victory == null:
		return []
	return f.Victory.CaptureCharacters


static func ConditionsMet(f: Faction, galaxy: Array) -> bool:
	var opponent: Faction = Lq.first_or_null(FactionRegistry.Playable, func(o): return o != f)
	if opponent == null:
		return false
	if not HeadquartersConditionMet(f, opponent, galaxy):
		return false
	if GameSettings.HQOnlyVictory:
		return true
	return Lq.all(CaptureTargets(f), func(n): return HoldsCaptive(f, n))


static func ProcessDay(galaxy: Array, day: int) -> void:
	if IsOver():
		return
	for f in FactionRegistry.Playable:
		if not ConditionsMet(f, galaxy):
			continue
		Winner = f
		print("[Victory] %s has met every victory condition on day %d." % [f.DisplayName, day])
		for h in GameSettings.HumanFactions:
			var ours: bool = f == h
			EventBus.Tell(h, GameMessage.new("Victory" if ours else "Defeat",
				("Every victory condition has been met. The %s has won.\n\n%s" % [f.DisplayName, Summary(f, galaxy)]) if ours
				else ("The %s has met every victory condition. We have lost.\n\n%s" % [f.DisplayName, Summary(f, galaxy)]),
				Enums.MessageCategory.Missions, day))
		EventBus.BroadcastChanged()
		return


static func Summary(f: Faction, galaxy: Array) -> String:
	var lines := []
	for row in StatusFor(f, galaxy):
		lines.append("  %s %s" % ["[x]" if row[1] else "[ ]", row[0]])
	return "\n".join(lines)


## THE OBJECTIVES WINDOW'S CONTENT (manual p136-p137): [[label, met], ...]
static func StatusFor(f: Faction, galaxy: Array) -> Array:
	var rows := []
	var opponent: Faction = Lq.first_or_null(FactionRegistry.Playable, func(o): return o != f)
	if f == null or opponent == null:
		return rows
	var viewer_owns := f == GameSettings.PlayerFaction

	var hq := HeadquartersConditionMet(f, opponent, galaxy)
	if opponent.HasHiddenHq():
		rows.append(["Headquarters Destroyed" if hq else ("Destroy Headquarters" if viewer_owns else "Defend Headquarters"), hq])
	else:
		var capital: String = opponent.Hq.Planet if (opponent.Hq != null and not opponent.Hq.Planet.is_empty()) else "capital"
		rows.append([("%s Captured" % capital) if hq else (("Control %s" % capital) if viewer_owns else ("Defend %s" % capital)), hq])

	if GameSettings.HQOnlyVictory:
		return rows

	for name in CaptureTargets(f):
		var held := HoldsCaptive(f, name)
		var surname: String = name.substr(name.rfind(" ") + 1) if name.contains(" ") else name
		rows.append([("%s Captured" % surname) if held else (("Capture %s" % surname) if viewer_owns else ("Defend %s" % surname)), held])
	return rows
