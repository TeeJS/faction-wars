class_name ResearchManager
extends RefCounted
## backend/ResearchManager.cs - the three R&D tracks (manual p104). THE TECH TREE
## IS IN THE BINARY TABLES: every buildable carries a ResearchOrder and a
## ResearchCost; discoveries come IN ORDER.

static var _points: Dictionary = {}   # faction id -> [ship, troop, facility]

## ⚠ still unsourced: the per-facility passive award.
const PassivePerFacilityPerDay := 1


static func PassiveInterval(f: Faction) -> int:
	return max(1, RuleManager.Get(RuleId.PassiveResearchRateA, f))


static func Bank(f: Faction) -> Array:
	if f == null:
		return [0, 0, 0]
	if not _points.has(f.Id):
		_points[f.Id] = [0, 0, 0]
	return _points[f.Id]


static func PointsIn(f: Faction, track: int) -> int:
	return Bank(f)[track]


## Ships and fighters both "strengthen your fleets", so both are Ship Design.
static func TrackFor(r: PackDefs.UnitDef) -> int:
	if r != null and r.Kind == "troop":
		return Enums.ResearchTrackKind.TroopTraining
	return Enums.ResearchTrackKind.ShipDesign


static func IsUnlocked(f: Faction, track: int, order: int, cost: int) -> bool:
	if order <= 0:
		return true   # available from the start
	return Bank(f)[track] >= cost


static func IsUnlockedUnit(f: Faction, r: PackDefs.UnitDef) -> bool:
	return r == null or IsUnlocked(f, TrackFor(r), r.ResearchOrder, r.ResearchCost)


static func IsUnlockedFacility(f: Faction, r: PackDefs.FacilityDef) -> bool:
	return r == null or IsUnlocked(f, Enums.ResearchTrackKind.FacilityDesign, r.ResearchOrder, r.ResearchCost)


## "Each facility you control contributes slightly to research in its own area".
static func ProcessDay(galaxy: Array, day: int) -> void:
	if galaxy == null:
		return
	for f in FactionRegistry.Playable:
		if day % PassiveInterval(f) != 0:
			continue
		var yards := 0
		var shipyards := 0
		var training := 0
		for s in galaxy:
			for p in s.Planets:
				if p.ControllingFaction != f:
					continue
				yards += p.CountOf("construction_yard")
				shipyards += p.CountOf("shipyard")
				training += p.CountOf("training_facility")
		Award(f, Enums.ResearchTrackKind.FacilityDesign, yards * PassivePerFacilityPerDay, day, true)
		Award(f, Enums.ResearchTrackKind.ShipDesign, shipyards * PassivePerFacilityPerDay, day, true)
		Award(f, Enums.ResearchTrackKind.TroopTraining, training * PassivePerFacilityPerDay, day, true)


## An R&D mission attempt: entries 126 and 127, 1 + rand(0..6). How many new
## designs it brought in.
static func MissionProgress(f: Faction, track: int, day: int, rng: Prng) -> int:
	return Award(f, track, RuleManager.Roll(RuleId.ResearchPointsBase, RuleId.ResearchPointsSpread, rng, f), day, false)


## Bank the points and announce anything the sequence has now reached, in the
## original's words and picture (TEXTSTRA 28744 / 28745, STRATEGY 1017): "<name>
## Research Complete" / "R&D Reports that the <name> is now available for
## manufacture." How many were reached.
static func Award(f: Faction, track: int, points: int, day: int, quiet: bool) -> int:
	if f == null or points <= 0:
		return 0
	var before := Discovered(f, track)
	Bank(f)[track] += points
	var after := Discovered(f, track)
	var reached := 0
	for found in after:
		if before.has(found):
			continue
		reached += 1
		print("[R&D] %s has developed %s." % [f.DisplayName, found])
		if not GameSettings.IsHuman(f):
			continue
		var msg := GameMessage.new("%s Research Complete" % found,
			"R&D Reports that the %s is now available for manufacture." % found,
			Enums.MessageCategory.Manufacturing, day)
		msg.Type = Enums.MessageType.ResearchReport
		msg.Advisor = "research"
		msg.Still = "message.1017"
		msg.Sound = "strategy/1113"
		EventBus.Tell(f, msg)
	# THE LAST OF A TRACK (TEXTSTRA 29208-29211, REBEXE 0x48abb0, STRATEGY 1017 /
	# 1113): "Research Exhausted" / "There are no further advances expected in
	# ship construction." - troop training, facility construction.
	if reached > 0 and GameSettings.IsHuman(f) and after.size() >= Researchable(f, track):
		var done := GameMessage.new("Research Exhausted", "There are no further advances expected in %s." % (
			"facility construction" if track == Enums.ResearchTrackKind.FacilityDesign
			else ("troop training" if track == Enums.ResearchTrackKind.TroopTraining else "ship construction")),
			Enums.MessageCategory.Manufacturing, day)
		done.Type = Enums.MessageType.ResearchReport
		done.Still = "message.1017"
		done.Sound = "strategy/1113"
		EventBus.Tell(f, done)
	return reached


## How many designs this side can reach on a track at all.
static func Researchable(f: Faction, track: int) -> int:
	if track == Enums.ResearchTrackKind.FacilityDesign:
		return Lq.count(FacilityCatalog.All(), func(r) -> bool: return r.ResearchOrder > 0 and r.CanBeBuiltBy(f))
	return Lq.count(MilitaryCatalog.All(), func(r) -> bool:
		return r.ResearchOrder > 0 and MilitaryCatalog.CanBeBuiltBy(r, f) and TrackFor(r) == track)


## Everything this side has reached on a track, by name.
static func Discovered(f: Faction, track: int) -> Array:
	var out := []
	if track == Enums.ResearchTrackKind.FacilityDesign:
		for r in FacilityCatalog.All():
			if r.ResearchOrder > 0 and r.CanBeBuiltBy(f) and IsUnlockedFacility(f, r):
				out.append(r.DisplayName)
		return out
	for r in MilitaryCatalog.All():
		if r.ResearchOrder > 0 and MilitaryCatalog.CanBeBuiltBy(r, f) and TrackFor(r) == track and IsUnlockedUnit(f, r):
			out.append(r.DisplayName)
	return out


static func DebugGrant(f: Faction, track: int, points: int, day: int) -> void:
	Award(f, track, points, day, false)


static func Reset() -> void:
	_points.clear()
